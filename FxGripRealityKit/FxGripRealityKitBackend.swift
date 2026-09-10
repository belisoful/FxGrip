/*!
	@file       FxGripRealityKitBackend.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitBackend
	@abstract   The render-driver seam for the RealityKit engine.
	@discussion Introduced in FxGrip 0.1.0. This file declares the protocol a RealityKit render driver
	            adopts to draw a scene into an FxPlug tile's Metal texture, the closure that builds the
	            scene, and the errors a driver reports.
*/

import Foundation
import Metal
import RealityKit

/// Populates a renderer with the entities and the active camera for one frame.
///
/// Introduced in FxGrip 0.1.0. RealityKit's scene graph is main-actor isolated, so a frame is built
/// where it is rendered rather than handed over as a finished tree. A backend calls this closure on
/// the main actor with a renderer whose entities are already cleared, and the closure appends the
/// frame's entities and sets `activeCamera`.
///
/// The closure runs inside the backend's render lock, so it holds the renderer exclusively for the
/// duration of the frame.
public typealias FxGripRealityKitSceneBuilder = @MainActor (RealityRenderer) throws -> Void

/// A failure raised by a RealityKit render driver.
///
/// Introduced in FxGrip 0.1.0. `FxGripRealityKitEffect` converts these into the `NSError` the FxPlug
/// host expects, through the base's `spaceError(reason:)`.
public enum FxGripRealityKitError: Error, LocalizedError {

	/// RealityKit's renderer could not be created, or the process has no Metal device.
	case rendererUnavailable(String)

	/// The destination tile is on a Metal device the renderer does not draw to.
	///
	/// `RealityRenderer` takes no device and draws on the system default device. A destination
	/// texture on a second GPU is unreachable, and the effect falls back to the passthrough.
	case deviceMismatch(expected: String, found: String)

	/// The frame carried no active camera. A scene builder sets `activeCamera` on every frame.
	case missingCamera

	/// RealityKit rejected the frame, or the frame did not complete.
	case renderFailed(String)

	public var errorDescription: String? {
		switch self {
		case let .rendererUnavailable(reason):
			return "the RealityKit renderer is unavailable: \(reason)"
		case let .deviceMismatch(expected, found):
			return "the destination tile is on Metal device \(found), and the RealityKit renderer draws on \(expected)"
		case .missingCamera:
			return "the frame set no active camera"
		case let .renderFailed(reason):
			return "the RealityKit render failed: \(reason)"
		}
	}
}

/// Renders a RealityKit frame into a Metal texture for the 3D Space subsystem.
///
/// Introduced in FxGrip 0.1.0. The seam matches `FxGripSceneKitBackend`, which serves the SceneKit
/// engine, and differs where the two engines differ. RealityKit builds its scene on the main actor
/// rather than accepting a finished graph, so this protocol takes a builder closure. Both carry the
/// render time, because a frame's simulated state is a function of that time and nothing else.
///
/// The host renders frames concurrently on many threads. An implementation is called from those
/// threads and serializes internally.
public protocol FxGripRealityKitBackend: AnyObject {

	/// YES when the backend can render.
	var isReady: Bool { get }

	/// A short stable identifier for the engine, for logging and selection.
	var backendIdentifier: String { get }

	/// Whether this backend draws to the texture's Metal device.
	func canRender(into texture: any MTLTexture) -> Bool

	/// Builds one frame through `scene` and draws it into `texture`, returning once the GPU is done.
	///
	/// - Parameters:
	///   - texture: The destination, which is the FxPlug tile's Metal texture.
	///   - seconds: The effect's render time. The shipped driver renders the frame as built and does
	///     not read it; a driver that simulates uses it to decide how far to advance.
	///   - scene: Populates the renderer on the main actor.
	func render(into texture: any MTLTexture,
				atTime seconds: TimeInterval,
				scene: FxGripRealityKitSceneBuilder) throws
}
