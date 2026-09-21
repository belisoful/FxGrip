/*!
	@file       FxGripRealityKitMetalBackend.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitMetalBackend
	@abstract   The shipped RealityKit render driver, which draws through RealityRenderer into an
	            FxPlug tile.
	@discussion Introduced in FxGrip 0.1.0. This file holds the driver that connects RealityKit's
	            offscreen renderer to the FxPlug tile, including the main-actor scheduling the
	            renderer requires and the serialization that concurrent host renders require.
*/

import CoreGraphics
import Foundation
import Metal
import RealityKit

/// Draws a RealityKit frame into an FxPlug tile through `RealityRenderer`.
///
/// Introduced in FxGrip 0.1.0. `RealityRenderer` is the only offscreen render path RealityKit
/// publishes. Two of its properties shape this driver.
///
/// - The renderer, its entity collection, and `updateAndRender` are main-actor isolated → every
///   frame is built and submitted on the main actor, and the calling thread waits.
/// - `RealityRenderer` takes no Metal device and draws on the system default device → a destination
///   tile on a second GPU is unreachable, and `canRender(into:)` reports that before a render begins.
///
/// The host renders frames concurrently, out of order, and re-renders them. RealityKit offers no way
/// to hold more than one scene in a renderer, so a frame owns the renderer for its duration and the
/// driver serializes renders behind a lock. The main actor is occupied only while the frame is built
/// and submitted; the GPU work runs with the main actor free, and the calling thread waits on the
/// renderer's completion callback.
///
/// The driver clears the renderer at the start of every frame, so no state survives from the frame
/// before, which is what the host's out-of-order rendering requires.
open class FxGripRealityKitMetalBackend: NSObject, FxGripRealityKitBackend {

	/// A frame that does not complete within this many seconds fails rather than blocking the host
	/// render thread indefinitely. Defaults to thirty seconds.
	public var renderTimeout: TimeInterval = 30.0

	/// Composites the frame over the destination texture's existing contents instead of clearing it.
	///
	/// Defaults to false, which clears to transparent black. Set it when the destination already
	/// holds content the frame draws over, such as a source tile blitted before the render.
	public var preservesDestinationContents: Bool = false

	/// The Metal device RealityKit draws on, which is the system default.
	private let device: (any MTLDevice)?

	/// Serializes renders. A frame holds the renderer from the moment it is built until the GPU
	/// signals completion.
	private let renderLock = NSLock()

	/// Created lazily on the main actor, and touched only there.
	private var renderer: RealityRenderer?

	public override init() {
		self.device = MTLCreateSystemDefaultDevice()
		super.init()
	}

	/// True once the renderer exists and the driver can draw a frame.
	public var isReady: Bool {
		return device != nil
	}

	/// The driver's name, which a plug-in reads to tell which engine drew a frame.
	public var backendIdentifier: String {
		return "realitykit-metal"
	}

	/// Whether the driver can draw into a texture.
	///
	/// `RealityRenderer` takes no Metal device and draws on the system default device, so a tile
	/// on a second GPU is unreachable. The effect falls back to the passthrough when this is false.
	public func canRender(into texture: any MTLTexture) -> Bool {
		guard let device else {
			return false
		}
		return texture.device.registryID == device.registryID
	}

	/// Draws one frame into a texture, building the scene through the supplied closure.
	///
	/// The build and the submission run on the main actor while the calling thread waits, because
	/// RealityKit's entity graph is main-actor isolated. Renders serialize behind a lock, since
	/// RealityKit holds one scene per renderer.
	public func render(into texture: any MTLTexture,
					   atTime seconds: TimeInterval,
					   scene: FxGripRealityKitSceneBuilder) throws {
		guard let device else {
			throw FxGripRealityKitError.rendererUnavailable("the process has no Metal device")
		}
		guard canRender(into: texture) else {
			throw FxGripRealityKitError.deviceMismatch(expected: device.name,
													   found: texture.device.name)
		}

		renderLock.lock()
		defer { renderLock.unlock() }

		let completion = DispatchSemaphore(value: 0)
		try Self.onMainActor {
			try self.submitFrame(into: texture, atTime: seconds, scene: scene) {
				completion.signal()
			}
		}

		if completion.wait(timeout: .now() + renderTimeout) == .timedOut {
			throw FxGripRealityKitError.renderFailed("the frame did not complete within \(renderTimeout) seconds")
		}
	}

	// MARK: - The main-actor half

	/// Clears the renderer, builds the frame, and submits it. Returns once the frame is submitted,
	/// which releases the main actor for the duration of the GPU work.
	@MainActor
	private func submitFrame(into texture: any MTLTexture,
							 atTime seconds: TimeInterval,
							 scene: FxGripRealityKitSceneBuilder,
							 onComplete: @escaping @Sendable () -> Void) throws {
		let renderer = try mainActorRenderer()

		renderer.entities.removeAll()
		renderer.activeCamera = nil
		// The FxPlug tile holds linear light, so the renderer's display tone map stays off.
		renderer.cameraSettings.isToneMappingEnabled = false
		renderer.cameraSettings.colorBackground = preservesDestinationContents
			? .outputTexture()
			: .color(Self.transparentBlack)

		try scene(renderer)

		guard renderer.activeCamera != nil else {
			throw FxGripRealityKitError.missingCamera
		}

		try advanceSimulation(renderer, toTime: seconds)

		let output: RealityRenderer.CameraOutput
		do {
			output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
		} catch {
			throw FxGripRealityKitError.renderFailed("the destination texture was rejected: \(error.localizedDescription)")
		}

		do {
			try renderer.updateAndRender(deltaTime: 0.0,
										 cameraOutput: output,
										 onComplete: { _ in onComplete() })
		} catch {
			throw FxGripRealityKitError.renderFailed(error.localizedDescription)
		}
	}

	/// Advances the frame's simulation to `seconds` before it is drawn. The default does nothing.
	///
	/// Introduced in FxGrip 0.1.0. The shipped driver renders a frame exactly as the scene builder
	/// left it. `FxGripRealityKitPhysicsBackend` overrides this to run a deterministic fixed-step
	/// catch-up. The counterpart in the SceneKit engine is
	/// `advanceSimulationForScene:renderer:toTime:`.
	@MainActor
	open func advanceSimulation(_ renderer: RealityRenderer, toTime seconds: TimeInterval) throws {
	}

	@MainActor
	private func mainActorRenderer() throws -> RealityRenderer {
		if let renderer {
			return renderer
		}
		do {
			let created = try RealityRenderer()
			renderer = created
			return created
		} catch {
			throw FxGripRealityKitError.rendererUnavailable(error.localizedDescription)
		}
	}

	// MARK: - Utilities

	private static let transparentBlack = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)

	/// Runs `body` on the main actor and waits for it.
	///
	/// The host calls the render on a background thread, which takes the dispatch path. A call that
	/// is already on the main thread runs inline, because dispatching to the main queue from the main
	/// thread deadlocks.
	private static func onMainActor<T>(_ body: @MainActor () throws -> T) rethrows -> T {
		if Thread.isMainThread {
			return try MainActor.assumeIsolated(body)
		}
		return try DispatchQueue.main.sync {
			try MainActor.assumeIsolated(body)
		}
	}
}
