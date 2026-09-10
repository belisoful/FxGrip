/*!
	@file       FxGripRealityKitParticleSystemTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitParticleSystemTests
	@abstract   Unit tests for the FxGrip-owned particle system, its field, and its geometry.
	@discussion Introduced in FxGrip 0.1.0. The simulation tests need no GPU: they count births,
	            deaths, and emission windows, prove that a resume and a rewind land on the state a
	            fresh run produces, and check each inter-particle force against its closed form on
	            two particles. The geometry tests skip when the machine has no Metal device.
*/

import FxGrip
import Metal
import RealityKit
import XCTest
import simd

@testable import FxGripRealityKit

final class FxGripRealityKitParticleSystemTests: XCTestCase {

	// MARK: - Fixtures

	private func makeSystem(_ configure: (inout FxGripRealityKitParticleSystem.Configuration) -> Void = { _ in }) -> FxGripRealityKitParticleSystem {
		let system = FxGripRealityKitParticleSystem()
		var configuration = FxGripRealityKitParticleSystem.Configuration()
		configuration.birthRate = 60.0
		configuration.particleLifeSpan = 1.0
		configuration.particleVelocity = 2.0
		configure(&configuration)
		system.configuration = configuration
		return system
	}

	/// Two still particles on the x axis, two units apart, under no emission.
	private func pairSystem(charge: Float = 0.0, velocities: [SIMD3<Float>]? = nil) -> FxGripRealityKitParticleSystem {
		let system = makeSystem {
			$0.birthRate = 0.0
			$0.particleLifeSpan = 100.0
			$0.particleCharge = charge
		}
		system.setParticles(positions: [SIMD3<Float>(-1.0, 0.0, 0.0), SIMD3<Float>(1.0, 0.0, 0.0)],
							velocities: velocities ?? [.zero, .zero])
		return system
	}

	private func interaction(_ kind: FxGripParticleInteractionKind, enabled: Bool = true) -> FxGripParticleInteraction {
		let interaction = FxGripParticleInteraction()
		interaction.enabled = enabled
		interaction.kind = kind
		return interaction
	}

	// MARK: - Emission

	func testEmptyAtStepZero() {
		let system = makeSystem()
		XCTAssertEqual(system.particleCount, 0)
		XCTAssertEqual(system.currentStep, 0)
		system.advance(toStep: 0)
		XCTAssertEqual(system.particleCount, 0)
	}

	func testBirthsFollowTheBirthRate() {
		let system = makeSystem()
		system.advance(toStep: 30)
		XCTAssertEqual(system.particleCount, 30, "sixty per second for half a second")
		XCTAssertEqual(system.birthIndices, Array(0 ..< 30))
	}

	func testParticlesDieAtTheEndOfTheirLife() {
		let system = makeSystem { $0.particleLifeSpan = 0.5 }
		system.advance(toStep: 60)
		XCTAssertTrue((29 ... 31).contains(system.particleCount), "found \(system.particleCount)")
		XCTAssertTrue(system.ages.allSatisfy { $0 < 0.5 })
	}

	func testEmissionStopsWithoutLoops() {
		let system = makeSystem {
			$0.emissionDuration = 0.5
			$0.loops = false
			$0.particleLifeSpan = 10.0
		}
		system.advance(toStep: 120)
		XCTAssertEqual(system.particleCount, 30)
	}

	func testIdleDurationPausesEmission() {
		let system = makeSystem {
			$0.emissionDuration = 0.5
			$0.idleDuration = 0.5
			$0.particleLifeSpan = 10.0
		}
		system.advance(toStep: 120)
		XCTAssertEqual(system.particleCount, 60, "two half-second bursts in two seconds")
	}

	func testCapacityBoundsTheLiveParticles() {
		let system = makeSystem {
			$0.birthRate = 6000.0
			$0.maximumParticleCount = 10
		}
		system.advance(toStep: 10)
		XCTAssertEqual(system.particleCount, 10)
		XCTAssertEqual(system.capacity, 10)
	}

	func testDerivedCapacityCoversTheLongestLife() {
		let system = makeSystem {
			$0.birthRate = 100.0
			$0.particleLifeSpan = 2.0
			$0.particleLifeSpanVariation = 0.5
		}
		XCTAssertGreaterThanOrEqual(system.capacity, 250)
	}

	func testParticlesAreBornInTheEmitterExtent() {
		let system = makeSystem { $0.emitterExtent = SIMD3<Float>(1.0, 2.0, 0.0) }
		system.advance(toStep: 1)
		let position = try! XCTUnwrap(system.positions.first)
		XCTAssertLessThanOrEqual(abs(position.x), 1.0)
		XCTAssertLessThanOrEqual(abs(position.y), 2.0)
		XCTAssertEqual(position.z, 0.0)
	}

	// MARK: - Determinism

	func testSameSeedReproducesTheState() {
		let a = makeSystem { $0.particleVelocityVariation = 1.0; $0.seed = 7 }
		let b = makeSystem { $0.particleVelocityVariation = 1.0; $0.seed = 7 }
		a.advance(toStep: 90)
		b.advance(toStep: 90)
		XCTAssertEqual(a.positions, b.positions)
		XCTAssertEqual(a.velocities, b.velocities)
	}

	func testDifferentSeedsDiverge() {
		let a = makeSystem { $0.particleVelocityVariation = 1.0; $0.seed = 7 }
		let b = makeSystem { $0.particleVelocityVariation = 1.0; $0.seed = 8 }
		a.advance(toStep: 30)
		b.advance(toStep: 30)
		XCTAssertNotEqual(a.positions, b.positions)
	}

	func testResumeMatchesAFreshRun() {
		let resumed = makeSystem { $0.particleVelocityVariation = 1.0; $0.acceleration = SIMD3<Float>(0.0, -9.8, 0.0) }
		let fresh = makeSystem { $0.particleVelocityVariation = 1.0; $0.acceleration = SIMD3<Float>(0.0, -9.8, 0.0) }
		resumed.advance(toStep: 30)
		resumed.advance(toStep: 90)
		fresh.advance(toStep: 90)
		XCTAssertEqual(resumed.positions, fresh.positions)
		XCTAssertEqual(resumed.totalSimulationSteps, 90, "a resume steps only the gap")
	}

	func testRewindRestartsFromZero() {
		let rewound = makeSystem { $0.particleVelocityVariation = 1.0 }
		let fresh = makeSystem { $0.particleVelocityVariation = 1.0 }
		rewound.advance(toStep: 90)
		rewound.advance(toStep: 30)
		fresh.advance(toStep: 30)
		XCTAssertEqual(rewound.positions, fresh.positions)
		XCTAssertEqual(rewound.currentStep, 30)
		XCTAssertEqual(rewound.totalSimulationSteps, 120)
	}

	func testConfigurationChangeRestarts() {
		let system = makeSystem()
		system.advance(toStep: 50)
		system.configuration.birthRate = 30.0
		XCTAssertEqual(system.currentStep, 0)
		XCTAssertEqual(system.particleCount, 0)
	}

	func testUnchangedConfigurationKeepsTheState() {
		let system = makeSystem()
		system.advance(toStep: 50)
		let same = system.configuration
		system.configuration = same
		XCTAssertEqual(system.currentStep, 50)
	}

	func testTimeStepAndStartTimeShapeTheGrid() {
		let system = makeSystem()
		system.timeStep = 0.1
		system.simulationStartTime = 1.0
		XCTAssertEqual(system.stepIndex(for: 0.5), 0, "before the start is step zero")
		XCTAssertEqual(system.stepIndex(for: 1.0), 0)
		XCTAssertEqual(system.stepIndex(for: 1.54), 5, "nearest step")
		XCTAssertEqual(system.stepIndex(for: 1.56), 6)
		XCTAssertEqual(system.stepIndex(for: 2.0), 10)
	}

	func testHandSetParticlesSurviveARestart() {
		let system = pairSystem()
		system.advance(toStep: 10)
		system.advance(toStep: 5)
		XCTAssertEqual(system.particleCount, 2)
		XCTAssertEqual(system.positions[0].x, -1.0, "still particles under no force stay put")
	}

	// MARK: - Forces

	func testGravityPullsTheParticlesTogether() {
		let system = pairSystem()
		system.particleInteraction = interaction(.gravity)
		system.advance(toStep: 1)

		// a = G·m·d / (d² + ε²)^{3/2} with d = 2, m = 1, ε = 0.01; the step adds a·dt.
		let expected = Float(2.0 / pow(4.0 + 0.0001, 1.5) / 60.0)
		XCTAssertEqual(system.velocities[0].x, expected, accuracy: expected * 1e-3)
		XCTAssertEqual(system.velocities[1].x, -expected, accuracy: expected * 1e-3)
		XCTAssertEqual(system.velocities[0].y, 0.0)
	}

	func testGravityStrengthScalesTheForce() {
		let weak = pairSystem()
		weak.particleInteraction = FxGripParticleInteraction.gravity(withStrength: 1.0)
		let strong = pairSystem()
		strong.particleInteraction = FxGripParticleInteraction.gravity(withStrength: 3.0)
		weak.advance(toStep: 1)
		strong.advance(toStep: 1)
		XCTAssertEqual(strong.velocities[0].x, 3.0 * weak.velocities[0].x, accuracy: 1e-6)
	}

	func testElectricRepelsLikeCharges() {
		let system = pairSystem(charge: 1.0)
		system.particleInteraction = interaction(.electric)
		system.advance(toStep: 1)
		XCTAssertLessThan(system.velocities[0].x, 0.0)
		XCTAssertGreaterThan(system.velocities[1].x, 0.0)
	}

	func testElectricDoesNothingWithoutCharge() {
		let system = pairSystem(charge: 0.0)
		system.particleInteraction = interaction(.electric)
		system.advance(toStep: 1)
		XCTAssertEqual(system.velocities[0], .zero)
	}

	func testMagneticAttractsParallelCurrents() {
		let system = makeSystem {
			$0.birthRate = 0.0
			$0.particleLifeSpan = 100.0
			$0.particleCharge = 1.0
		}
		let along = SIMD3<Float>(1.0, 0.0, 0.0)
		system.setParticles(positions: [SIMD3<Float>(0.0, -1.0, 0.0), SIMD3<Float>(0.0, 1.0, 0.0)],
							velocities: [along, along])
		system.particleInteraction = interaction(.magnetic)
		system.advance(toStep: 1)
		XCTAssertGreaterThan(system.velocities[0].y, 0.0, "the lower charge is drawn up")
		XCTAssertLessThan(system.velocities[1].y, 0.0, "the upper charge is drawn down")
	}

	func testDisabledInteractionAppliesNoForce() {
		let system = pairSystem()
		system.particleInteraction = interaction(.gravity, enabled: false)
		system.advance(toStep: 1)
		XCTAssertEqual(system.velocities[0], .zero)
	}

	func testInteractionIsCopiedIn() {
		let system = pairSystem()
		let source = interaction(.gravity)
		system.particleInteraction = source
		source.enabled = false
		XCTAssertTrue(try XCTUnwrap(system.particleInteraction).enabled)
	}

	func testForceIsDeterministicAcrossRuns() {
		let a = makeSystem { $0.particleVelocityVariation = 1.0; $0.emitterExtent = SIMD3<Float>(repeating: 1.0) }
		let b = makeSystem { $0.particleVelocityVariation = 1.0; $0.emitterExtent = SIMD3<Float>(repeating: 1.0) }
		a.particleInteraction = FxGripParticleInteraction.gravity(withStrength: 0.5)
		b.particleInteraction = FxGripParticleInteraction.gravity(withStrength: 0.5)
		a.advance(toStep: 60)
		b.advance(toStep: 60)
		XCTAssertEqual(a.positions, b.positions)
		XCTAssertNotEqual(a.velocities, makeSystemWithoutForce().velocities, "the force changed the run")
	}

	private func makeSystemWithoutForce() -> FxGripRealityKitParticleSystem {
		let system = makeSystem { $0.particleVelocityVariation = 1.0; $0.emitterExtent = SIMD3<Float>(repeating: 1.0) }
		system.advance(toStep: 60)
		return system
	}

	// MARK: - Fields

	func testFieldOverTwoSystemsEvaluatesInWorldSpace() {
		let left = makeSystem { $0.birthRate = 0.0; $0.particleLifeSpan = 100.0 }
		let right = makeSystem { $0.birthRate = 0.0; $0.particleLifeSpan = 100.0 }
		left.setParticles(positions: [.zero], velocities: [.zero])
		right.setParticles(positions: [.zero], velocities: [.zero])

		let field = FxGripRealityKitParticleField(interaction: interaction(.gravity))
		field.members = [
			.init(system: left, transform: simd_float4x4(translation: SIMD3<Float>(-1.0, 0.0, 0.0))),
			.init(system: right, transform: simd_float4x4(translation: SIMD3<Float>(1.0, 0.0, 0.0))),
		]
		field.advance(toStep: 1)

		XCTAssertGreaterThan(left.velocities[0].x, 0.0, "the left emitter's particle is drawn right")
		XCTAssertLessThan(right.velocities[0].x, 0.0)
		XCTAssertEqual(left.currentStep, 1)
		XCTAssertEqual(right.currentStep, 1)
	}

	func testFieldMapsTheForceBackThroughTheMemberRotation() {
		let left = makeSystem { $0.birthRate = 0.0; $0.particleLifeSpan = 100.0 }
		let right = makeSystem { $0.birthRate = 0.0; $0.particleLifeSpan = 100.0 }
		left.setParticles(positions: [.zero], velocities: [.zero])
		right.setParticles(positions: [.zero], velocities: [.zero])

		// The left emitter is turned a quarter turn about Y, so world +X is its local +Z.
		var leftTransform = simd_float4x4(simd_quatf(angle: .pi / 2.0, axis: SIMD3<Float>(0.0, 1.0, 0.0)))
		leftTransform.columns.3 = SIMD4<Float>(-1.0, 0.0, 0.0, 1.0)
		let field = FxGripRealityKitParticleField(interaction: interaction(.gravity))
		field.members = [
			.init(system: left, transform: leftTransform),
			.init(system: right, transform: simd_float4x4(translation: SIMD3<Float>(1.0, 0.0, 0.0))),
		]
		field.advance(toStep: 1)

		XCTAssertEqual(left.velocities[0].x, 0.0, accuracy: 1e-6)
		XCTAssertGreaterThan(left.velocities[0].z, 0.0)
	}

	func testFieldRestartsMembersWhoseHistoryDiffers() {
		let a = makeSystem()
		let b = makeSystem()
		a.advance(toStep: 30)

		let field = FxGripRealityKitParticleField(interaction: nil)
		field.members = [.init(system: a), .init(system: b)]
		field.advance(toStep: 40)

		XCTAssertEqual(a.totalSimulationSteps, 70, "thirty alone, then a restart to forty")
		XCTAssertEqual(b.totalSimulationSteps, 40)
		XCTAssertEqual(a.positions.count, b.positions.count)
	}

	func testFieldResumesWhenNothingChanged() {
		let a = makeSystem()
		let b = makeSystem()
		let field = FxGripRealityKitParticleField(interaction: interaction(.gravity))
		field.members = [.init(system: a), .init(system: b)]
		field.advance(toStep: 30)
		field.advance(toStep: 45)
		XCTAssertEqual(a.totalSimulationSteps, 45)
		XCTAssertEqual(b.totalSimulationSteps, 45)
	}

	func testSystemAdvancedAloneAfterAFieldRestarts() {
		let a = makeSystem()
		let b = makeSystem()
		let field = FxGripRealityKitParticleField(interaction: nil)
		field.members = [.init(system: a), .init(system: b)]
		field.advance(toStep: 30)
		a.advance(toStep: 40)
		XCTAssertEqual(a.totalSimulationSteps, 70, "leaving the field is a different history")
	}

	func testEmptyFieldDoesNothing() {
		let field = FxGripRealityKitParticleField(interaction: interaction(.gravity))
		field.advance(toStep: 10)
		field.advance(to: 1.0)
	}

	// MARK: - Rendered values

	func testSizeAndColorInterpolateOverLife() {
		let system = makeSystem {
			$0.birthRate = 0.0
			$0.particleLifeSpan = 1.0
			$0.particleSize = 2.0
			$0.particleSizeAtEnd = 0.0
			$0.particleColor = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
			$0.particleColorAtEnd = SIMD4<Float>(1.0, 0.0, 0.0, 0.0)
		}
		system.setParticles(positions: [.zero], velocities: [.zero])
		system.advance(toStep: 30)
		XCTAssertEqual(system.renderedSizes[0], 1.0, accuracy: 0.05)
		XCTAssertEqual(system.renderedColors[0].w, 0.5, accuracy: 0.05)
		XCTAssertEqual(system.renderedColors[0].x, 1.0, accuracy: 1e-6)
	}

	func testSpreadingAngleAtPiStaysFinite() {
		let system = makeSystem { $0.spreadingAngle = .pi; $0.particleVelocity = 1.0 }
		system.advance(toStep: 30)
		XCTAssertEqual(system.particleCount, 30)
		for velocity in system.velocities {
			XCTAssertTrue(velocity.x.isFinite && velocity.y.isFinite && velocity.z.isFinite)
			XCTAssertLessThan(simd_length(velocity), 200.0)
		}
	}

	func testDampingSlowsParticles() {
		let free = pairSystem(velocities: [SIMD3<Float>(1.0, 0.0, 0.0), .zero])
		let damped = pairSystem(velocities: [SIMD3<Float>(1.0, 0.0, 0.0), .zero])
		damped.configuration.dampingFactor = 5.0
		free.advance(toStep: 30)
		damped.advance(toStep: 30)
		XCTAssertLessThan(damped.positions[0].x, free.positions[0].x)
	}

	// MARK: - Geometry

	private func requireMetal() throws {
		guard MTLCreateSystemDefaultDevice() != nil else {
			throw XCTSkip("No Metal device available")
		}
	}

	@MainActor
	func testGeometryHoldsFourVerticesAndSixIndicesPerParticle() throws {
		try requireMetal()
		let geometry = try FxGripRealityKitParticleGeometry(capacity: 8)
		let mesh = try XCTUnwrap(geometry.meshResource.lowLevelMesh)
		XCTAssertEqual(mesh.vertexCapacity, 32)
		XCTAssertEqual(mesh.indexCapacity, 48)

		let system = makeSystem()
		system.advance(toStep: 3)
		geometry.update(from: system, cameraTransform: matrix_identity_float4x4, entityTransform: matrix_identity_float4x4)
		XCTAssertEqual(mesh.parts.count, 1)
		XCTAssertEqual(mesh.parts[0].indexCount, 18)
	}

	@MainActor
	func testEmptySystemLeavesOneDegenerateQuad() throws {
		try requireMetal()
		let geometry = try FxGripRealityKitParticleGeometry(capacity: 4)
		let system = makeSystem()
		geometry.update(from: system, cameraTransform: matrix_identity_float4x4, entityTransform: matrix_identity_float4x4)
		let mesh = try XCTUnwrap(geometry.meshResource.lowLevelMesh)
		XCTAssertEqual(mesh.parts[0].indexCount, 6)
		XCTAssertEqual(mesh.parts[0].bounds.min, .zero)
		XCTAssertEqual(mesh.parts[0].bounds.max, .zero)
	}

	@MainActor
	func testQuadsFaceTheCamera() throws {
		try requireMetal()
		let geometry = try FxGripRealityKitParticleGeometry(capacity: 2)
		let system = makeSystem { $0.birthRate = 0.0; $0.particleSize = 2.0 }
		system.setParticles(positions: [SIMD3<Float>(0.0, 0.0, -5.0)], velocities: [.zero])

		// A camera turned a quarter turn about Y looks along -X, so its quads spread in Z and Y.
		let turned = simd_float4x4(simd_quatf(angle: .pi / 2.0, axis: SIMD3<Float>(0.0, 1.0, 0.0)))
		geometry.update(from: system, cameraTransform: turned, entityTransform: matrix_identity_float4x4)
		let mesh = try XCTUnwrap(geometry.meshResource.lowLevelMesh)
		var xs: [Float] = []
		var zs: [Float] = []
		mesh.withUnsafeBytes(bufferIndex: 0) { raw in
			let stride = mesh.descriptor.vertexLayouts[0].bufferStride
			for corner in 0 ..< 4 {
				let base = corner * stride
				xs.append(raw.load(fromByteOffset: base, as: Float.self))
				zs.append(raw.load(fromByteOffset: base + 8, as: Float.self))
			}
		}
		XCTAssertEqual(xs.max()! - xs.min()!, 0.0, accuracy: 1e-5, "no spread along the view direction")
		XCTAssertEqual(zs.max()! - zs.min()!, 2.0, accuracy: 1e-5, "one unit each side of the particle")
		XCTAssertEqual(mesh.parts[0].bounds.min.z, -6.0, accuracy: 1e-5)
		XCTAssertEqual(mesh.parts[0].bounds.max.z, -4.0, accuracy: 1e-5)
	}

	@MainActor
	func testGeometryCarriesTheParticleColorAndPaletteCoordinate() throws {
		try requireMetal()
		let geometry = try FxGripRealityKitParticleGeometry(capacity: 2)
		let system = makeSystem { $0.birthRate = 0.0 }
		system.setParticles(positions: [.zero, SIMD3<Float>(1.0, 0.0, 0.0)],
							velocities: [.zero, .zero],
							colors: [SIMD4<Float>(1.0, 0.0, 0.0, 1.0), SIMD4<Float>(0.0, 1.0, 0.0, 0.5)])
		geometry.update(from: system, cameraTransform: matrix_identity_float4x4, entityTransform: matrix_identity_float4x4)
		let mesh = try XCTUnwrap(geometry.meshResource.lowLevelMesh)
		mesh.withUnsafeBytes(bufferIndex: 0) { raw in
			let stride = mesh.descriptor.vertexLayouts[0].bufferStride
			let second = 4 * stride
			XCTAssertEqual(raw.load(fromByteOffset: second + 12, as: Float.self), 0.0)
			XCTAssertEqual(raw.load(fromByteOffset: second + 16, as: Float.self), 1.0)
			XCTAssertEqual(raw.load(fromByteOffset: second + 24, as: Float.self), 0.5)
			XCTAssertEqual(raw.load(fromByteOffset: second + 28, as: Float.self), 0.75, "the second palette texel of two")
			XCTAssertEqual(raw.load(fromByteOffset: second + 36, as: Float.self), 0.0, "the first corner")
		}
	}
}

private extension simd_float4x4 {
	init(translation: SIMD3<Float>) {
		self = matrix_identity_float4x4
		columns.3 = SIMD4<Float>(translation, 1.0)
	}
}
