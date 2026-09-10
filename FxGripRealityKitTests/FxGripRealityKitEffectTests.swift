/*!
	@file       FxGripRealityKitEffectTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitEffectTests
	@abstract   Unit tests for the RealityKit engine subclass, its seams, and its render path.
	@discussion Introduced in FxGrip 0.1.0. These tests run without an FxPlug host, in the pattern the
	            Objective-C Space tests use. A capturing backend runs the frame builder without drawing
	            so the assembled frame can be inspected, and the shipped driver renders for the tests
	            that read pixels back.
*/

import AppKit
import CoreMedia
import FxGrip
import Metal
import RealityKit
import XCTest
import simd

@testable import FxGripRealityKit

/// Runs `body` on the main actor and waits, the way the shipped driver does. The host calls a render
/// from a background thread, so a test double must make the same hop.
private func onMainActorSync<T>(_ body: @MainActor () throws -> T) rethrows -> T {
	if Thread.isMainThread {
		return try MainActor.assumeIsolated(body)
	}
	return try DispatchQueue.main.sync {
		try MainActor.assumeIsolated(body)
	}
}


// MARK: - Doubles

/// Runs the frame builder against a real renderer without drawing, so a test can inspect the frame.
private final class CapturingBackend: FxGripRealityKitBackend {

	var isReady: Bool = true
	var canRenderResult: Bool = true
	var backendIdentifier: String = "capturing"

	private(set) var renderCount = 0
	private(set) var topLevelEntityCount = 0
	private(set) var root: Entity?
	private(set) var activeCamera: Entity?
	private(set) var lastRenderTime: TimeInterval = -1.0

	private var renderer: RealityRenderer?

	func canRender(into texture: any MTLTexture) -> Bool {
		return canRenderResult
	}

	func render(into texture: any MTLTexture,
				atTime seconds: TimeInterval,
				scene: FxGripRealityKitSceneBuilder) throws {
		try onMainActorSync {
			let active: RealityRenderer
			if let renderer {
				active = renderer
			} else {
				active = try RealityRenderer()
				renderer = active
			}
			active.entities.removeAll()
			active.activeCamera = nil

			try scene(active)

			renderCount += 1
			lastRenderTime = seconds
			topLevelEntityCount = active.entities.count
			root = active.entities.first
			activeCamera = active.activeCamera
		}
	}
}

/// Fails every frame, so the effect's error mapping can be observed.
private final class FailingBackend: FxGripRealityKitBackend {
	struct Failure: Error, LocalizedError {
		var errorDescription: String? { return "the driver said no" }
	}

	var isReady: Bool = true
	var backendIdentifier: String = "failing"
	private(set) var renderCount = 0

	func canRender(into texture: any MTLTexture) -> Bool {
		return true
	}

	func render(into texture: any MTLTexture,
				atTime seconds: TimeInterval,
				scene: FxGripRealityKitSceneBuilder) throws {
		renderCount += 1
		throw Failure()
	}
}

/// Records the apply hook and adds one unlit box in front of the host camera.
private final class BoxEffect: FxGripRealityKitEffect {

	var applyCalled = false
	var receivedRootName: String?
	var receivedCameraName: String?
	var receivedCameraIsActive = false
	var boxColor: NSColor = NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)

	override func updateSceneContents(_ renderer: RealityRenderer,
									  root: Entity,
									  camera: Entity,
									  from coder: NSCoder,
									  at renderTime: CMTime,
									  cameraMotion: FxGripCameraMotion) {
		applyCalled = true
		receivedRootName = root.name
		receivedCameraName = camera.name
		receivedCameraIsActive = (renderer.activeCamera === camera)

		let box = ModelEntity(mesh: .generateBox(size: 4.0),
							  materials: [UnlitMaterial(color: boxColor)])
		box.position = SIMD3<Float>(0.0, 0.0, -5.0)
		root.addChild(box)
	}
}

/// Supplies an authored template that FxGrip clones into every frame.
private final class TemplateEffect: FxGripRealityKitEffect {

	var template: Entity?

	override func sceneTemplateEntity(at renderTime: CMTime) -> Entity? {
		if let template {
			return template
		}
		let authored = ModelEntity(mesh: .generateBox(size: 4.0),
								   materials: [UnlitMaterial(color: fxgRenderableColor(.red))])
		authored.position = SIMD3<Float>(0.0, 0.0, -5.0)
		template = authored
		return authored
	}
}

/// Carries stored properties with defaults, to prove a Swift subclass is initialized.
private final class StoredPropertyEffect: FxGripRealityKitEffect {
	var flag: Bool = true
	var count: Int = 42
	var text: String = "set"
	var color: NSColor = NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
	var boxed: NSNumber = NSNumber(value: 7)
}

// MARK: - Tests

final class FxGripRealityKitEffectTests: XCTestCase {

	// MARK: Fixtures

	private func metalDevice() throws -> any MTLDevice {
		guard let device = MTLCreateSystemDefaultDevice() else {
			throw XCTSkip("No Metal device available")
		}
		return device
	}

	private func makeTexture(_ device: any MTLDevice, size: Int = 64) throws -> any MTLTexture {
		let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
																  width: size,
																  height: size,
																  mipmapped: false)
		descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
		descriptor.storageMode = .shared
		return try XCTUnwrap(device.makeTexture(descriptor: descriptor))
	}

	/// A decoder holding no host state, the way the Objective-C Space tests build one.
	private func emptyDecoder() throws -> NSCoder {
		let archiver = NSKeyedArchiver(requiringSecureCoding: false)
		archiver.finishEncoding()
		let decoder = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
		decoder.requiresSecureCoding = false
		return decoder
	}

	private func centerPixel(of texture: any MTLTexture) -> [UInt8] {
		var pixel = [UInt8](repeating: 0, count: 4)
		let region = MTLRegionMake2D(texture.width / 2, texture.height / 2, 1, 1)
		texture.getBytes(&pixel, bytesPerRow: 4, from: region, mipmapLevel: 0)
		return pixel
	}

	/// Renders off the main thread, which is where the FxPlug host calls the render, pumping the main
	/// run loop meanwhile so the driver's main-actor hop can proceed.
	private func renderOffMain(_ effect: FxGripRealityKitEffect,
							   coder: NSCoder,
							   sourceTile: FxImageTile? = nil,
							   into texture: any MTLTexture,
							   at renderTime: CMTime = CMTime.zero) throws {
		var thrown: Error?
		let finished = expectation(description: "render finished")
		DispatchQueue.global().async {
			do {
				try effect.renderScene(from: coder, sourceTile: sourceTile, to: texture, at: renderTime)
			} catch {
				thrown = error
			}
			finished.fulfill()
		}
		wait(for: [finished], timeout: 120.0)
		if let thrown {
			throw thrown
		}
	}

	// MARK: The class itself

	func testEffectInstantiatesWithoutAHost() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		XCTAssertTrue(effect.isKind(of: FxGripSpaceEffect.self))
	}

	func testEffectInheritsTheBaseDefaults() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		XCTAssertTrue(effect.rendersSourceLayerPlane)
	}

	/// RealityKit's only offscreen renderer constructs in a headless test process, which is the
	/// environment an FxPlug plugin renders in.
	@MainActor
	func testRealityRendererConstructsHeadless() throws {
		XCTAssertNoThrow(try RealityRenderer())
	}

	// MARK: Swift subclass initialization

	/// A Swift subclass's stored-property defaults are applied when the host constructs the effect.
	///
	/// The FxPlug host builds an effect through `initWithAPIManager:`. Swift applies a subclass's
	/// property defaults only when the initializer it inherits is a designated one, so
	/// `FxGripTileableEffect` declares it as such. Without that, every stored property in a Swift
	/// plugin reads as zeroed memory, and an object-typed one crashes the first thing that uses it.
	func testSwiftSubclassStoredPropertiesAreInitialized() throws {
		let effect = try XCTUnwrap(StoredPropertyEffect(apiManager: nil))

		XCTAssertTrue(effect.flag)
		XCTAssertEqual(effect.count, 42)
		XCTAssertEqual(effect.text, "set")
		XCTAssertEqual(effect.boxed, NSNumber(value: 7))
		XCTAssertEqual(effect.color.numberOfComponents, 4, "a zeroed color reports no components")
		XCTAssertNotNil(effect.color.cgColor.colorSpace)
	}

	/// The same holds for an effect built with a bare `init`, which delegates to the designated one.
	func testBareInitAlsoInitializesTheSwiftSubclass() throws {
		let effect = try XCTUnwrap(StoredPropertyEffect())
		XCTAssertEqual(effect.count, 42)
		XCTAssertNotNil(effect.color.cgColor.colorSpace)
	}

	// MARK: The backend property

	func testDefaultBackendIsTheShippedMetalDriver() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		XCTAssertEqual(effect.realityBackend.backendIdentifier, "realitykit-metal")
	}

	func testDefaultBackendIsCreatedOnceAndReused() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		XCTAssertTrue(effect.realityBackend === effect.realityBackend)
	}

	func testBackendCanBeReplaced() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let stub = CapturingBackend()
		effect.realityBackend = stub
		XCTAssertEqual(effect.realityBackend.backendIdentifier, "capturing")
	}

	// MARK: The physics bake

	/// The bake is off by default, so the effect renders through the plain driver.
	func testPhysicsBakeIsOffByDefault() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		XCTAssertFalse(effect.physicsBakeEnabled)
		XCTAssertEqual(effect.realityBackend.backendIdentifier, "realitykit-metal")
	}

	/// Enabling the bake upgrades the default driver to the simulating one, in session-cache mode.
	func testEnablingTheBakeUpgradesTheDefaultDriver() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		effect.physicsBakeEnabled = true

		XCTAssertEqual(effect.realityBackend.backendIdentifier, "realitykit-metal-physics")
		let physics = try XCTUnwrap(effect.realityBackend as? FxGripRealityKitPhysicsBackend)
		XCTAssertEqual(physics.simulationMode, .sessionCache)
	}

	/// A driver the plugin installed itself is never replaced by the bake flag.
	func testEnablingTheBakeKeepsADriverThePluginSet() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let stub = CapturingBackend()
		effect.realityBackend = stub

		effect.physicsBakeEnabled = true

		XCTAssertTrue(effect.realityBackend === stub)
	}

	/// The engine-neutral store seam reaches the physics driver, which is how `FxGripPhysicsBake`
	/// installs a document-backed store without naming the engine.
	func testInstallingASimulationStoreReachesThePhysicsDriver() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		effect.physicsBakeEnabled = true
		let store = FxGripPhysicsMemoryStore()

		XCTAssertTrue(effect.installPhysicsSimulationStore(store))

		let physics = try XCTUnwrap(effect.realityBackend as? FxGripRealityKitPhysicsBackend)
		XCTAssertTrue(physics.simulationStore === store)
		XCTAssertEqual(physics.simulationMode, .sessionCache)
	}

	/// A driver that does not simulate refuses the store, which leaves the bake inert.
	func testInstallingASimulationStoreRefusesOnThePlainDriver() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		XCTAssertFalse(effect.installPhysicsSimulationStore(FxGripPhysicsMemoryStore()))
	}

	// MARK: Falling back to the passthrough

	/// A driver that is not ready leaves the frame to the base, which copies the source unchanged.
	func testUnreadyBackendFallsBackToThePassthrough() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let stub = CapturingBackend()
		stub.isReady = false
		effect.realityBackend = stub

		try renderOffMain(effect, coder: try emptyDecoder(), into: try makeTexture(device))

		XCTAssertEqual(stub.renderCount, 0, "an unready driver must not be asked to draw")
	}

	/// A driver that cannot reach the tile's Metal device also falls back, which is the second-GPU case.
	func testBackendThatCannotReachTheDeviceFallsBack() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let stub = CapturingBackend()
		stub.canRenderResult = false
		effect.realityBackend = stub

		try renderOffMain(effect, coder: try emptyDecoder(), into: try makeTexture(device))

		XCTAssertEqual(stub.renderCount, 0)
	}

	/// A driver failure reaches the host as an error in FxGrip's space-render domain.
	func testBackendFailureBecomesAHostError() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let stub = FailingBackend()
		effect.realityBackend = stub

		// Compared against an error the base itself makes, so the test carries no copy of the code.
		let reference = effect.spaceError(withReason: "reference") as NSError

		XCTAssertThrowsError(try renderOffMain(effect, coder: try emptyDecoder(), into: try makeTexture(device))) { error in
			let nsError = error as NSError
			XCTAssertEqual(nsError.domain, reference.domain)
			XCTAssertEqual(nsError.code, reference.code)
			XCTAssertTrue(nsError.localizedDescription.contains("the driver said no"),
						  "the driver's reason should survive: \(nsError.localizedDescription)")
		}
		XCTAssertEqual(stub.renderCount, 1)
	}

	// MARK: The assembled frame

	/// FxGrip puts a single root in the renderer, carrying the host camera, and makes that camera the
	/// frame's active camera.
	func testFrameHasOneRootCarryingTheActiveCamera() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let stub = CapturingBackend()
		effect.realityBackend = stub

		try renderOffMain(effect, coder: try emptyDecoder(), into: try makeTexture(device))

		XCTAssertEqual(stub.renderCount, 1)
		XCTAssertEqual(stub.topLevelEntityCount, 1, "the renderer holds one root")
		XCTAssertEqual(stub.root?.name, FxGripRealityKitEntityName.root)
		XCTAssertEqual(stub.activeCamera?.name, FxGripRealityKitEntityName.camera)
		XCTAssertTrue(stub.activeCamera?.parent === stub.root, "the camera hangs off the frame root")
	}

	/// A frame is rebuilt from the coder every render and shares no entities with the render before it.
	func testEachRenderBuildsItsOwnFrame() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let stub = CapturingBackend()
		effect.realityBackend = stub

		try renderOffMain(effect, coder: try emptyDecoder(), into: try makeTexture(device))
		let first = stub.root
		try renderOffMain(effect, coder: try emptyDecoder(), into: try makeTexture(device))
		let second = stub.root

		XCTAssertNotNil(first)
		XCTAssertNotNil(second)
		XCTAssertFalse(first === second, "each render must get its own frame, not a shared one")
	}

	/// The effect hands the driver its render time, which is what a simulating driver needs to know
	/// how far to advance.
	func testEffectPassesItsRenderTimeToTheDriver() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let stub = CapturingBackend()
		effect.realityBackend = stub

		try renderOffMain(effect,
						  coder: try emptyDecoder(),
						  into: try makeTexture(device),
						  at: CMTime(seconds: 1.5, preferredTimescale: 600))

		XCTAssertEqual(stub.lastRenderTime, 1.5, accuracy: 1e-6)
	}

	/// With no source tile there is no layer plane, whatever the flag says.
	func testNoSourceTileMeansNoLayerPlane() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let stub = CapturingBackend()
		effect.realityBackend = stub
		XCTAssertTrue(effect.rendersSourceLayerPlane)

		try renderOffMain(effect, coder: try emptyDecoder(), into: try makeTexture(device))

		XCTAssertNil(stub.root?.findEntity(named: FxGripRealityKitEntityName.layerPlane))
	}

	// MARK: The apply hook

	func testApplyHookReceivesTheFrameRootAndActiveCamera() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(BoxEffect(apiManager: nil))
		let stub = CapturingBackend()
		effect.realityBackend = stub

		try renderOffMain(effect, coder: try emptyDecoder(), into: try makeTexture(device))

		XCTAssertTrue(effect.applyCalled)
		XCTAssertEqual(effect.receivedRootName, FxGripRealityKitEntityName.root)
		XCTAssertEqual(effect.receivedCameraName, FxGripRealityKitEntityName.camera)
		XCTAssertTrue(effect.receivedCameraIsActive, "the hook's camera is the frame's active camera")
	}

	// MARK: The template

	/// FxGrip clones the authored template into every frame, so the plugin's own entity is never
	/// adopted by a frame and each frame holds its own copy.
	func testTemplateIsClonedIntoEveryFrame() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(TemplateEffect(apiManager: nil))
		let stub = CapturingBackend()
		effect.realityBackend = stub

		try renderOffMain(effect, coder: try emptyDecoder(), into: try makeTexture(device))
		let firstCopy = stub.root?.findEntity(named: FxGripRealityKitEntityName.template)
		try renderOffMain(effect, coder: try emptyDecoder(), into: try makeTexture(device))
		let secondCopy = stub.root?.findEntity(named: FxGripRealityKitEntityName.template)

		XCTAssertNotNil(firstCopy)
		XCTAssertNotNil(secondCopy)
		XCTAssertFalse(firstCopy === secondCopy, "each frame gets its own copy")
		XCTAssertFalse(firstCopy === effect.template, "the plugin's template is never adopted by a frame")
		XCTAssertNil(effect.template?.parent, "the plugin's template stays unparented")
	}

	// MARK: Drawing

	/// The whole seam end to end: the effect's render builds the frame, drives the shipped driver, and
	/// the plugin's entity reaches the tile.
	func testApplyHookEntitiesReachTheTile() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(BoxEffect(apiManager: nil))
		let texture = try makeTexture(device)

		try renderOffMain(effect, coder: try emptyDecoder(), into: texture)

		let pixel = centerPixel(of: texture)
		XCTAssertGreaterThan(pixel[0], 200, "the plugin's red box should reach the tile: \(pixel)")
		XCTAssertLessThan(pixel[1], 60, "\(pixel)")
		XCTAssertLessThan(pixel[2], 60, "\(pixel)")
	}

	/// The template route reaches the tile as well, without an apply hook.
	func testTemplateEntitiesReachTheTile() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(TemplateEffect(apiManager: nil))
		let texture = try makeTexture(device)

		try renderOffMain(effect, coder: try emptyDecoder(), into: texture)

		let pixel = centerPixel(of: texture)
		XCTAssertGreaterThan(pixel[0], 200, "the authored template should reach the tile: \(pixel)")
	}
}
