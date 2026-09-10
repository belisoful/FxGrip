/*!
	@file       FxGripRealityKitParticleComponentTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitParticleComponentTests
	@abstract   Tests for the particle carrier component and the engine's per-frame particle pass.
	@discussion Introduced in FxGrip 0.1.0. A capturing backend runs the effect's frame builder so the
	            carrier the effect stepped and modeled can be inspected, including how the scene-wide
	            default, the declared fields, and a system's own interaction are applied. The shipped
	            driver renders for the tests that prove the particles reach the tile deterministically.
*/

import AppKit
import CoreMedia
import FxGrip
import Metal
import RealityKit
import XCTest
import simd

@testable import FxGripRealityKit

/// Runs `body` on the main actor and waits, the way the shipped driver does.
private func onMainActorSync<T>(_ body: @MainActor () throws -> T) rethrows -> T {
	if Thread.isMainThread {
		return try MainActor.assumeIsolated(body)
	}
	return try DispatchQueue.main.sync {
		try MainActor.assumeIsolated(body)
	}
}

// MARK: - Doubles

/// Runs the frame builder against a real renderer without drawing, and keeps the frame's root.
private final class CapturingBackend: FxGripRealityKitBackend {

	var isReady: Bool = true
	var backendIdentifier: String = "capturing"
	private(set) var root: Entity?
	private(set) var lastRenderTime: TimeInterval = -1.0
	private var renderer: RealityRenderer?

	func canRender(into texture: any MTLTexture) -> Bool {
		return true
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
			lastRenderTime = seconds
			root = active.entities.first
		}
	}
}

/// Adds particle carriers to each frame from the systems it owns.
private final class ParticleEffect: FxGripRealityKitEffect {

	/// Each entry is a carrier name, its system, and the position it is placed at under `groupName`
	/// when that is set, or directly under the root otherwise.
	struct Carrier {
		var name: String
		var system: FxGripRealityKitParticleSystem
		var position: SIMD3<Float> = .zero
		var grouped: Bool = false
	}

	var carriers: [Carrier] = []
	var groupName = "emitters"
	var useTemplate = false

	@MainActor
	private func build(into parent: Entity) {
		let group = Entity()
		group.name = groupName
		parent.addChild(group)
		for carrier in carriers {
			let entity = Entity.fxgParticleCarrier(carrier.system, name: carrier.name)
			entity.position = carrier.position
			(carrier.grouped ? group : parent).addChild(entity)
		}
	}

	override func updateSceneContents(_ renderer: RealityRenderer,
									  root: Entity,
									  camera: Entity,
									  from coder: NSCoder,
									  at renderTime: CMTime,
									  cameraMotion: FxGripCameraMotion) {
		if !useTemplate {
			build(into: root)
		}
	}

	override func sceneTemplateEntity(at renderTime: CMTime) -> Entity? {
		guard useTemplate else {
			return nil
		}
		let template = Entity()
		build(into: template)
		return template
	}
}

// MARK: - Tests

final class FxGripRealityKitParticleComponentTests: XCTestCase {

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

	/// A decoder over the effect's own capture, which carries its interaction configuration.
	private func capturedDecoder(for effect: FxGripSpaceEffect) throws -> NSCoder {
		let archiver = NSKeyedArchiver(requiringSecureCoding: true)
		try effect.pluginCoder(archiver, at: .zero, quality: UInt(kFxQuality_HIGH))
		archiver.finishEncoding()
		let decoder = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
		decoder.requiresSecureCoding = false
		return decoder
	}

	private func pixels(of texture: any MTLTexture) -> [UInt8] {
		var bytes = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
		texture.getBytes(&bytes,
						 bytesPerRow: texture.width * 4,
						 from: MTLRegionMake2D(0, 0, texture.width, texture.height),
						 mipmapLevel: 0)
		return bytes
	}

	private func centerPixel(of texture: any MTLTexture) -> [UInt8] {
		var pixel = [UInt8](repeating: 0, count: 4)
		let region = MTLRegionMake2D(texture.width / 2, texture.height / 2, 1, 1)
		texture.getBytes(&pixel, bytesPerRow: 4, from: region, mipmapLevel: 0)
		return pixel
	}

	/// Renders off the main thread, where the host calls the render, pumping the main run loop
	/// meanwhile so the driver's main-actor hop can proceed.
	private func renderOffMain(_ effect: FxGripRealityKitEffect,
							   coder: NSCoder,
							   into texture: any MTLTexture,
							   at seconds: Double) throws {
		var thrown: Error?
		let finished = expectation(description: "render finished")
		DispatchQueue.global().async {
			do {
				try effect.renderScene(from: coder,
									   sourceTile: nil,
									   to: texture,
									   at: CMTime(seconds: seconds, preferredTimescale: 600))
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

	/// One still particle system with no emission, so a force is the only thing that moves it.
	private func stillSystem(at position: SIMD3<Float> = .zero) -> FxGripRealityKitParticleSystem {
		let system = FxGripRealityKitParticleSystem()
		var configuration = FxGripRealityKitParticleSystem.Configuration()
		configuration.birthRate = 0.0
		configuration.particleLifeSpan = 100.0
		system.configuration = configuration
		system.setParticles(positions: [position], velocities: [.zero])
		return system
	}

	private func makeEffect(_ backend: any FxGripRealityKitBackend) throws -> ParticleEffect {
		let effect = try XCTUnwrap(ParticleEffect(apiManager: nil))
		effect.realityBackend = backend
		effect.rendersSourceLayerPlane = false
		return effect
	}

	@MainActor
	private func carrier(named name: String, in backend: CapturingBackend) throws -> Entity {
		let root = try XCTUnwrap(backend.root)
		return try XCTUnwrap(root.findEntity(named: name))
	}

	// MARK: The component

	@MainActor
	func testCarrierHoldsItsSystem() {
		let system = FxGripRealityKitParticleSystem()
		let carrier = Entity.fxgParticleCarrier(system, name: "sparks")
		XCTAssertEqual(carrier.name, "sparks")
		XCTAssertTrue(carrier.fxgParticleSystem === system)
		XCTAssertNil(Entity().fxgParticleSystem)
	}

	@MainActor
	func testCloneKeepsTheSameSystem() {
		let system = FxGripRealityKitParticleSystem()
		let carrier = Entity.fxgParticleCarrier(system, name: "sparks")
		let copy = carrier.clone(recursive: true)
		XCTAssertTrue(copy.fxgParticleSystem === system, "the component copies, the system is shared")
	}

	// MARK: The particle pass

	func testCarrierIsSteppedToTheRenderTimeAndModeled() throws {
		let device = try metalDevice()
		let backend = CapturingBackend()
		let effect = try makeEffect(backend)
		let system = FxGripRealityKitParticleSystem()
		effect.carriers = [.init(name: "sparks", system: system)]

		try renderOffMain(effect, coder: try capturedDecoder(for: effect), into: try makeTexture(device), at: 0.5)

		XCTAssertEqual(system.currentStep, 30)
		XCTAssertEqual(system.particleCount, 50, "the default hundred per second, for half a second")
		try onMainActorSync {
			let carrier = try self.carrier(named: "sparks", in: backend)
			let model = try XCTUnwrap(carrier.components[ModelComponent.self])
			XCTAssertNotNil(model.mesh.lowLevelMesh)
			XCTAssertTrue(system.geometry != nil)
		}
	}

	func testTemplateCarrierIsSteppedAndModeled() throws {
		let device = try metalDevice()
		let backend = CapturingBackend()
		let effect = try makeEffect(backend)
		effect.useTemplate = true
		let system = FxGripRealityKitParticleSystem()
		effect.carriers = [.init(name: "sparks", system: system)]

		try renderOffMain(effect, coder: try capturedDecoder(for: effect), into: try makeTexture(device), at: 1.0)

		XCTAssertEqual(system.currentStep, 60)
		try onMainActorSync {
			let carrier = try self.carrier(named: "sparks", in: backend)
			XCTAssertNotNil(carrier.components[ModelComponent.self])
			XCTAssertTrue(carrier.fxgParticleSystem === system)
		}
	}

	func testOutOfOrderRendersLandOnTheSameState() throws {
		let device = try metalDevice()
		let effect = try makeEffect(CapturingBackend())
		let system = FxGripRealityKitParticleSystem()
		system.configuration.particleVelocityVariation = 1.0
		effect.carriers = [.init(name: "sparks", system: system)]
		let coder = try capturedDecoder(for: effect)
		let texture = try makeTexture(device)

		try renderOffMain(effect, coder: coder, into: texture, at: 1.0)
		let late = system.positions
		try renderOffMain(effect, coder: coder, into: texture, at: 0.25)
		try renderOffMain(effect, coder: coder, into: texture, at: 1.0)

		XCTAssertEqual(system.positions, late)
	}

	func testGeometryIsReusedAcrossFrames() throws {
		let device = try metalDevice()
		let effect = try makeEffect(CapturingBackend())
		let system = FxGripRealityKitParticleSystem()
		effect.carriers = [.init(name: "sparks", system: system)]
		let coder = try capturedDecoder(for: effect)
		let texture = try makeTexture(device)

		try renderOffMain(effect, coder: coder, into: texture, at: 0.1)
		let first = onMainActorSync { system.geometry }
		try renderOffMain(effect, coder: coder, into: texture, at: 0.2)
		let second = onMainActorSync { system.geometry }
		XCTAssertTrue(first === second)
	}

	func testGeometryIsReplacedWhenTheCapacityGrows() throws {
		let device = try metalDevice()
		let effect = try makeEffect(CapturingBackend())
		let system = FxGripRealityKitParticleSystem()
		system.configuration.maximumParticleCount = 4
		effect.carriers = [.init(name: "sparks", system: system)]
		let coder = try capturedDecoder(for: effect)
		let texture = try makeTexture(device)

		try renderOffMain(effect, coder: coder, into: texture, at: 0.1)
		let small = onMainActorSync { system.geometry }
		system.configuration.maximumParticleCount = 400
		try renderOffMain(effect, coder: coder, into: texture, at: 0.1)
		let large = onMainActorSync { system.geometry }
		let largeCapacity = onMainActorSync { system.geometry?.capacity }
		XCTAssertFalse(small === large)
		XCTAssertEqual(largeCapacity, 400)
	}

	// MARK: Interactions

	func testSceneWideDefaultAppliesToASystemWithoutItsOwn() throws {
		let device = try metalDevice()
		let effect = try makeEffect(CapturingBackend())
		let left = stillSystem(at: SIMD3<Float>(-1.0, 0.0, 0.0))
		let right = stillSystem(at: SIMD3<Float>(1.0, 0.0, 0.0))
		effect.carriers = [.init(name: "left", system: left), .init(name: "right", system: right)]
		effect.particleInteraction = FxGripParticleInteraction.gravity(withStrength: 1.0)

		try renderOffMain(effect, coder: try capturedDecoder(for: effect), into: try makeTexture(device), at: 1.0 / 60.0)

		// Each carrier runs alone in its own space, so a lone particle feels no force from the other.
		XCTAssertEqual(left.velocities[0], .zero, "one particle alone has nothing to attract it")
		XCTAssertEqual(right.velocities[0], .zero)

		// A system with two particles feels the default.
		let pair = stillSystem()
		pair.setParticles(positions: [SIMD3<Float>(-1.0, 0.0, 0.0), SIMD3<Float>(1.0, 0.0, 0.0)],
						  velocities: [.zero, .zero])
		effect.carriers = [.init(name: "pair", system: pair)]
		try renderOffMain(effect, coder: try capturedDecoder(for: effect), into: try makeTexture(device), at: 1.0 / 60.0)
		XCTAssertGreaterThan(pair.velocities[0].x, 0.0)
		XCTAssertLessThan(pair.velocities[1].x, 0.0)
	}

	func testOwnInteractionWinsOverTheSceneWideDefault() throws {
		let device = try metalDevice()
		let effect = try makeEffect(CapturingBackend())
		let pair = stillSystem()
		pair.setParticles(positions: [SIMD3<Float>(-1.0, 0.0, 0.0), SIMD3<Float>(1.0, 0.0, 0.0)],
						  velocities: [.zero, .zero])
		let off = FxGripParticleInteraction.gravity(withStrength: 1.0)
		off.enabled = false
		pair.particleInteraction = off
		effect.carriers = [.init(name: "pair", system: pair)]
		effect.particleInteraction = FxGripParticleInteraction.gravity(withStrength: 1.0)

		try renderOffMain(effect, coder: try capturedDecoder(for: effect), into: try makeTexture(device), at: 1.0 / 60.0)

		XCTAssertEqual(pair.velocities[0], .zero, "the system's own disabled force is what applies")
	}

	func testDeclaredFieldCoversTheNamedSubtreeInWorldSpace() throws {
		let device = try metalDevice()
		let effect = try makeEffect(CapturingBackend())
		let left = stillSystem()
		let right = stillSystem()
		let outside = stillSystem()
		effect.carriers = [
			.init(name: "left", system: left, position: SIMD3<Float>(-1.0, 0.0, 0.0), grouped: true),
			.init(name: "right", system: right, position: SIMD3<Float>(1.0, 0.0, 0.0), grouped: true),
			.init(name: "outside", system: outside, position: SIMD3<Float>(0.0, 5.0, 0.0), grouped: false),
		]
		effect.particleInteractionFields = ["emitters": FxGripParticleInteraction.gravity(withStrength: 1.0)]

		try renderOffMain(effect, coder: try capturedDecoder(for: effect), into: try makeTexture(device), at: 1.0 / 60.0)

		XCTAssertGreaterThan(left.velocities[0].x, 0.0, "drawn toward the right emitter")
		XCTAssertLessThan(right.velocities[0].x, 0.0)
		XCTAssertEqual(outside.velocities[0], .zero, "outside the field, alone, and unmoved")
	}

	func testFieldNamingAMissingEntityIsSkipped() throws {
		let device = try metalDevice()
		let effect = try makeEffect(CapturingBackend())
		let pair = stillSystem()
		pair.setParticles(positions: [SIMD3<Float>(-1.0, 0.0, 0.0), SIMD3<Float>(1.0, 0.0, 0.0)],
						  velocities: [.zero, .zero])
		effect.carriers = [.init(name: "pair", system: pair)]
		effect.particleInteractionFields = ["nowhere": FxGripParticleInteraction.gravity(withStrength: 1.0)]

		try renderOffMain(effect, coder: try capturedDecoder(for: effect), into: try makeTexture(device), at: 1.0 / 60.0)

		XCTAssertEqual(pair.velocities[0], .zero)
	}

	// MARK: The tile

	func testParticlesReachTheTile() throws {
		let device = try metalDevice()
		let effect = try makeEffect(FxGripRealityKitMetalBackend())
		let system = FxGripRealityKitParticleSystem()
		var configuration = FxGripRealityKitParticleSystem.Configuration()
		configuration.birthRate = 600.0
		configuration.particleLifeSpan = 5.0
		configuration.particleVelocity = 0.0
		configuration.particleSize = 3.0
		configuration.particleColor = SIMD4<Float>(0.0, 1.0, 0.0, 1.0)
		system.configuration = configuration
		effect.carriers = [.init(name: "sparks", system: system, position: SIMD3<Float>(0.0, 0.0, -5.0))]
		let texture = try makeTexture(device)

		try renderOffMain(effect, coder: try capturedDecoder(for: effect), into: texture, at: 0.5)

		let center = centerPixel(of: texture)
		XCTAssertGreaterThan(center[1], 200, "the green particles cover the center: \(center)")
		XCTAssertLessThan(center[0], 30)
		XCTAssertEqual(center[3], 255)
	}

	func testTheSameFrameRendersIdenticalPixels() throws {
		let device = try metalDevice()
		let effect = try makeEffect(FxGripRealityKitMetalBackend())
		let system = FxGripRealityKitParticleSystem()
		var configuration = FxGripRealityKitParticleSystem.Configuration()
		configuration.birthRate = 300.0
		configuration.particleLifeSpan = 3.0
		configuration.particleVelocity = 1.0
		configuration.particleVelocityVariation = 1.0
		configuration.spreadingAngle = 1.0
		configuration.particleSize = 0.3
		configuration.particleColorVariation = SIMD4<Float>(0.5, 0.5, 0.5, 0.0)
		configuration.seed = 11
		system.configuration = configuration
		effect.carriers = [.init(name: "sparks", system: system, position: SIMD3<Float>(0.0, -1.0, -5.0))]
		let coder = try capturedDecoder(for: effect)

		let first = try makeTexture(device)
		try renderOffMain(effect, coder: coder, into: first, at: 1.0)
		let second = try makeTexture(device)
		try renderOffMain(effect, coder: coder, into: second, at: 0.3)
		try renderOffMain(effect, coder: coder, into: second, at: 1.0)

		let firstPixels = pixels(of: first)
		XCTAssertEqual(firstPixels, pixels(of: second))
		XCTAssertTrue(firstPixels.contains { $0 != 0 }, "the frame is not blank")
	}

	func testAPluginMaterialReplacesTheDefault() throws {
		let device = try metalDevice()
		let effect = try makeEffect(FxGripRealityKitMetalBackend())
		let system = FxGripRealityKitParticleSystem()
		var configuration = FxGripRealityKitParticleSystem.Configuration()
		configuration.birthRate = 600.0
		configuration.particleLifeSpan = 5.0
		configuration.particleVelocity = 0.0
		configuration.particleSize = 3.0
		configuration.particleColor = SIMD4<Float>(0.0, 1.0, 0.0, 1.0)
		system.configuration = configuration
		onMainActorSync {
			system.material = UnlitMaterial(color: NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0))
		}
		effect.carriers = [.init(name: "sparks", system: system, position: SIMD3<Float>(0.0, 0.0, -5.0))]
		let texture = try makeTexture(device)

		try renderOffMain(effect, coder: try capturedDecoder(for: effect), into: texture, at: 0.5)

		let center = centerPixel(of: texture)
		XCTAssertGreaterThan(center[0], 200, "the plugin's red material drew: \(center)")
		XCTAssertLessThan(center[1], 30)
	}
}
