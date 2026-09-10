/*!
	@file       FxGripRealityKitPhysicsBackendTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitPhysicsBackendTests
	@abstract   Unit tests for the deterministic RealityKit physics driver.
	@discussion Introduced in FxGrip 0.1.0. The tests simulate a free-falling body through real
	            renders and read its pose back, which is the only way to confirm a simulation is
	            deterministic. They skip when the machine has no Metal device.
*/

import AppKit
import FxGrip
import Metal
import RealityKit
import XCTest
import simd

@testable import FxGripRealityKit

/// Carries the frame's body out of the scene builder so a test can read its simulated pose.
private final class BodyBox {
	var body: Entity?
}

@MainActor
final class FxGripRealityKitPhysicsBackendTests: XCTestCase {

	// MARK: - Fixtures

	private func metalDevice() throws -> any MTLDevice {
		guard let device = MTLCreateSystemDefaultDevice() else {
			throw XCTSkip("No Metal device available")
		}
		return device
	}

	private func makeTexture(_ device: any MTLDevice, size: Int = 32) throws -> any MTLTexture {
		let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
																  width: size,
																  height: size,
																  mipmapped: false)
		descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
		descriptor.storageMode = .shared
		return try XCTUnwrap(device.makeTexture(descriptor: descriptor))
	}

	/// One body falling under gravity from the origin, with no floor.
	///
	/// A RealityKit body simulates only when its entity also carries a `CollisionComponent`, so the
	/// ball has one. Without it the body never moves, whatever its mass or mode.
	private func fallingScene(_ box: BodyBox, named name: String = "ball") -> FxGripRealityKitSceneBuilder {
		return { renderer in
			let root = Entity()
			root.name = "root"
			var simulation = PhysicsSimulationComponent()
			simulation.gravity = SIMD3<Float>(0.0, -9.8, 0.0)
			root.components.set(simulation)

			let ball = ModelEntity(mesh: .generateSphere(radius: 0.5))
			ball.name = name
			ball.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.5)]))
			ball.components.set(PhysicsBodyComponent(shapes: [.generateSphere(radius: 0.5)],
													 mass: 1.0,
													 mode: .dynamic))
			root.addChild(ball)

			let camera = Entity()
			camera.components.set(PerspectiveCameraComponent())
			camera.position = SIMD3<Float>(0.0, 0.0, 5.0)
			root.addChild(camera)

			renderer.entities.replaceAll([root])
			renderer.activeCamera = camera
			box.body = ball
		}
	}

	/// Renders off the main thread, which is where the FxPlug host calls the render, and pumps the
	/// main run loop meanwhile so the driver's main-actor hop can proceed.
	private func renderOffMain(_ backend: FxGripRealityKitMetalBackend,
							   into texture: any MTLTexture,
							   atTime seconds: TimeInterval,
							   scene: @escaping FxGripRealityKitSceneBuilder) throws {
		var thrown: Error?
		let finished = expectation(description: "render finished")
		DispatchQueue.global().async {
			do {
				try backend.render(into: texture, atTime: seconds, scene: scene)
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

	/// The height of the frame's body after a render at `seconds`.
	private func fallenHeight(_ backend: FxGripRealityKitPhysicsBackend,
							  at seconds: TimeInterval,
							  device: any MTLDevice) throws -> Float {
		let box = BodyBox()
		try renderOffMain(backend, into: try makeTexture(device), atTime: seconds, scene: fallingScene(box))
		return try XCTUnwrap(box.body).position(relativeTo: nil).y
	}

	// MARK: - Identity

	func testPhysicsBackendIdentifiesItself() throws {
		_ = try metalDevice()
		XCTAssertEqual(FxGripRealityKitPhysicsBackend().backendIdentifier, "realitykit-metal-physics")
	}

	func testDefaultsAreRecomputeAtSixtyHertz() {
		let backend = FxGripRealityKitPhysicsBackend()
		XCTAssertEqual(backend.simulationMode, .recompute)
		XCTAssertEqual(backend.timeStep, 1.0 / 60.0, accuracy: 1e-9)
		XCTAssertEqual(backend.simulationStartTime, 0.0)
		XCTAssertEqual(backend.totalSimulationSteps, 0)
	}

	// MARK: - Determinism

	/// The same frame time renders the same pose every time, which is what lets the host re-render a
	/// frame and reorder its renders.
	func testSameFrameTimeReproducesTheSamePose() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitPhysicsBackend()

		let first = try fallenHeight(backend, at: 0.5, device: device)
		let second = try fallenHeight(backend, at: 0.5, device: device)

		XCTAssertEqual(first, second, accuracy: 1e-4, "a re-render must reproduce the pose")
		XCTAssertLessThan(first, -0.5, "the body should have fallen: \(first)")
		XCTAssertGreaterThan(first, -10.0, "the body should not have fallen absurdly far: \(first)")
	}

	/// A later frame has fallen further, so the simulation genuinely advances with time.
	func testLaterFrameHasFallenFurther() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitPhysicsBackend()

		let quarter = try fallenHeight(backend, at: 0.25, device: device)
		let half = try fallenHeight(backend, at: 0.5, device: device)

		XCTAssertLessThan(half, quarter, "0.5s should be lower than 0.25s: \(half) vs \(quarter)")
	}

	/// Frames render out of order in a host, so an earlier frame rendered after a later one still
	/// gives the earlier pose.
	func testOutOfOrderRendersGiveEachFrameItsOwnPose() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitPhysicsBackend()

		let halfFirst = try fallenHeight(backend, at: 0.5, device: device)
		let quarterAfter = try fallenHeight(backend, at: 0.25, device: device)
		let halfAgain = try fallenHeight(backend, at: 0.5, device: device)

		XCTAssertGreaterThan(quarterAfter, halfFirst)
		XCTAssertEqual(halfFirst, halfAgain, accuracy: 1e-4)
	}

	/// Recompute mode simulates the whole span on every render, so the step count keeps climbing.
	func testRecomputeModeResimulatesEveryRender() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitPhysicsBackend()
		XCTAssertEqual(backend.simulationMode, .recompute)

		_ = try fallenHeight(backend, at: 0.5, device: device)
		let afterFirst = backend.totalSimulationSteps
		_ = try fallenHeight(backend, at: 0.5, device: device)
		let afterSecond = backend.totalSimulationSteps

		XCTAssertGreaterThan(afterFirst, 0)
		XCTAssertEqual(afterSecond, afterFirst * 2, "recompute mode simulates the span again")
	}

	// MARK: - The session cache

	/// A cached step replays without simulating, and the replayed pose matches the simulated one.
	func testSessionCacheHitSkipsTheSimulationAndMatchesThePose() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitPhysicsBackend()
		backend.simulationMode = .sessionCache

		let simulated = try fallenHeight(backend, at: 0.5, device: device)
		let afterFirst = backend.totalSimulationSteps
		XCTAssertGreaterThan(afterFirst, 0)

		let replayed = try fallenHeight(backend, at: 0.5, device: device)

		XCTAssertEqual(backend.totalSimulationSteps, afterFirst, "a cache hit simulates nothing")
		XCTAssertEqual(replayed, simulated, accuracy: 1e-4, "the replayed pose matches the simulated one")
	}

	/// An earlier step is cached by the run that passed through it, so it replays too.
	func testAnEarlierStepAlsoReplaysFromTheCache() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitPhysicsBackend()
		backend.simulationMode = .sessionCache

		_ = try fallenHeight(backend, at: 0.5, device: device)
		let afterFirst = backend.totalSimulationSteps

		let earlier = try fallenHeight(backend, at: 0.25, device: device)

		XCTAssertEqual(backend.totalSimulationSteps, afterFirst, "the earlier step was already cached")
		XCTAssertLessThan(earlier, 0.0)
	}

	/// Clearing the cache makes the next render simulate again.
	func testResettingTheCacheForcesAResimulation() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitPhysicsBackend()
		backend.simulationMode = .sessionCache

		_ = try fallenHeight(backend, at: 0.5, device: device)
		backend.resetSimulationCache()
		XCTAssertEqual(backend.totalSimulationSteps, 0)

		_ = try fallenHeight(backend, at: 0.5, device: device)
		XCTAssertGreaterThan(backend.totalSimulationSteps, 0)
	}

	/// Changing the step invalidates the cache, whose keys are step indices.
	func testChangingTheTimeStepClearsTheCache() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitPhysicsBackend()
		backend.simulationMode = .sessionCache

		_ = try fallenHeight(backend, at: 0.5, device: device)
		XCTAssertGreaterThan(backend.totalSimulationSteps, 0)

		backend.timeStep = 1.0 / 120.0
		XCTAssertEqual(backend.totalSimulationSteps, 0, "a new step grid means a new cache")
	}

	/// The store is a seam: an effect's bake replaces it with a document-backed one.
	func testTheSimulationStoreIsReplaceable() throws {
		let backend = FxGripRealityKitPhysicsBackend()
		let store = FxGripPhysicsMemoryStore()
		backend.simulationStore = store
		XCTAssertTrue(backend.simulationStore === store)
	}

	// MARK: - Naming

	/// The store is keyed by name, so an unnamed body is skipped rather than cached under a key that
	/// would collide with another frame's body.
	func testUnnamedBodiesAreNotCached() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitPhysicsBackend()
		backend.simulationMode = .sessionCache

		let box = BodyBox()
		try renderOffMain(backend, into: try makeTexture(device), atTime: 0.5, scene: fallingScene(box, named: ""))

		XCTAssertNil(backend.simulationStore.transforms(forStep: 0),
					 "an unnamed body leaves nothing to cache")
	}

	// MARK: - No bodies

	/// A frame with no physics body renders without simulating anything.
	func testFrameWithoutBodiesSimulatesNothing() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitPhysicsBackend()

		try renderOffMain(backend, into: try makeTexture(device), atTime: 0.5) { renderer in
			let root = Entity()
			let camera = Entity()
			camera.components.set(PerspectiveCameraComponent())
			camera.position = SIMD3<Float>(0.0, 0.0, 5.0)
			root.addChild(camera)
			renderer.entities.replaceAll([root])
			renderer.activeCamera = camera
		}

		XCTAssertEqual(backend.totalSimulationSteps, 0)
	}
}
