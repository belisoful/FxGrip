/*!
	@file       FxGripRealityKitParticleSystem.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitParticleSystem
	@abstract   A deterministic, FxGrip-owned particle system for the RealityKit engine.
	@discussion Introduced in FxGrip 0.1.0. RealityKit's `ParticleEmitterComponent` exposes no seed
	            and no per-particle state, so it cannot reproduce a frame the host renders out of order
	            and it cannot carry an inter-particle force. This file declares the particle system
	            FxGrip simulates itself on the CPU: seeded the way `FxGripParticleSystem` is in the
	            SceneKit engine, stepped on a fixed grid, and coupled through the same Fast Multipole
	            Method core. The geometry that draws it lives in `FxGripRealityKitParticleGeometry`.
*/

import Foundation
import FxGrip
import RealityKit
import simd

/// The fixed step a particle system uses when none is set.
private let FxGripRealityKitParticleDefaultTimeStep: TimeInterval = 1.0 / 60.0

/// A seeded, fixed-step particle system that FxGrip simulates itself.
///
/// Introduced in FxGrip 0.1.0. The system holds its particles as plain arrays and steps them from a
/// fixed start on a fixed grid, so the state at step *k* is a function of the configuration, the seed,
/// and *k*. A render that asks for a later step resumes from the current one; a render that asks for
/// an earlier step, or that follows a configuration change, restarts from zero. Either way the state
/// a frame sees is the state the same step sequence produces from an empty system, which is what the
/// host's out-of-order rendering requires.
///
/// Per-particle variation comes from `FxGripParticleRand`, keyed by the seed and the particle's birth
/// index, so the same seed gives the same particles in this engine and in the SceneKit engine.
///
/// The particles simulate in the space of the entity that carries the system, so a moving emitter
/// carries its particles with it. An inter-particle force is evaluated by `FxGripRealityKitParticleField`,
/// which the engine forms for each frame from the system's own `particleInteraction`, the fields the
/// effect declares, and the scene-wide default.
///
/// The class is not thread-safe. The engine steps it inside the render driver's lock, and a plugin
/// that steps it directly does so from one thread at a time.
public final class FxGripRealityKitParticleSystem {

	// MARK: - Configuration

	/// The emission and particle parameters. Every value is held constant across the simulated span.
	///
	/// Introduced in FxGrip 0.1.0. The host supplies a frame's parameter values and nothing about
	/// earlier frames, so a change to any value restarts the simulation from zero with the new value
	/// in force throughout. Angles are radians. Colors are linear RGBA in [0, 1].
	public struct Configuration: Equatable {

		/// Particles born per second while emitting. Defaults to 100.
		public var birthRate: Float = 100.0

		/// How long one emission lasts, in seconds. Defaults to 1.
		public var emissionDuration: Float = 1.0

		/// The pause between emissions when looping, in seconds. Defaults to 0.
		public var idleDuration: Float = 0.0

		/// Whether emission repeats after the duration and idle. Defaults to true.
		public var loops: Bool = true

		/// The particle life, in seconds. Defaults to 1.
		public var particleLifeSpan: Float = 1.0

		/// The seeded spread of the life, in seconds. Defaults to 0.
		public var particleLifeSpanVariation: Float = 0.0

		/// The birth speed along `emittingDirection`. Defaults to 1.
		public var particleVelocity: Float = 1.0

		/// The seeded spread of the birth velocity, per axis. Defaults to 0.
		public var particleVelocityVariation: Float = 0.0

		/// The birth direction, normalized on use. Defaults to +Y.
		public var emittingDirection: SIMD3<Float> = SIMD3<Float>(0.0, 1.0, 0.0)

		/// The full-cone spreading angle around the direction, in radians. Defaults to 0. Capped at
		/// `FxGripParticleMaxSpreadAngle`, short of pi.
		public var spreadingAngle: Float = 0.0

		/// The half extents of the box particles are born in, around the emitter origin. Defaults to
		/// zero, a point emitter.
		public var emitterExtent: SIMD3<Float> = .zero

		/// The constant acceleration applied to every particle. Defaults to zero.
		public var acceleration: SIMD3<Float> = .zero

		/// The fraction of velocity removed per second. Defaults to 0.
		public var dampingFactor: Float = 0.0

		/// The particle size, the side of its billboard quad. Defaults to 0.1.
		public var particleSize: Float = 0.1

		/// The seeded spread of the size. Defaults to 0.
		public var particleSizeVariation: Float = 0.0

		/// The size at the end of the life, interpolated linearly from the birth size. Nil keeps the
		/// birth size. Defaults to nil.
		public var particleSizeAtEnd: Float? = nil

		/// The particle color, linear RGBA. Defaults to opaque white.
		public var particleColor: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)

		/// The seeded spread of the color, per channel. Defaults to zero.
		public var particleColorVariation: SIMD4<Float> = .zero

		/// The color at the end of the life, interpolated linearly from the birth color. Nil keeps the
		/// birth color. Defaults to nil.
		public var particleColorAtEnd: SIMD4<Float>? = nil

		/// The birth rotation of the quad in its billboard plane, in radians. Defaults to 0.
		public var particleAngle: Float = 0.0

		/// The seeded spread of the birth rotation, in radians. Defaults to 0.
		public var particleAngleVariation: Float = 0.0

		/// The rotation rate of the quad, in radians per second. Defaults to 0.
		public var particleAngularVelocity: Float = 0.0

		/// The mass an inter-particle force reads. Defaults to 1. A non-positive mass is treated as 1.
		public var particleMass: Float = 1.0

		/// The charge an inter-particle force reads. Defaults to 0.
		public var particleCharge: Float = 0.0

		/// The most particles alive at once. Zero, the default, derives the bound from the birth rate
		/// and the longest life. A birth beyond the bound is dropped.
		public var maximumParticleCount: Int = 0

		/// The seed for the per-particle variation. The same seed reproduces the same particles.
		public var seed: UInt32 = 0

		public init() {
		}
	}

	/// The system's parameters. Setting a different value restarts the simulation.
	public var configuration = Configuration() {
		didSet {
			if configuration != oldValue {
				reset()
			}
		}
	}

	/// The fixed simulation step, in seconds. Defaults to 1/60. Changing it restarts the simulation.
	public var timeStep: TimeInterval = FxGripRealityKitParticleDefaultTimeStep {
		didSet {
			if timeStep != oldValue {
				reset()
			}
		}
	}

	/// The render time the simulation starts from, in seconds. Defaults to zero. Changing it restarts
	/// the simulation.
	public var simulationStartTime: TimeInterval = 0.0 {
		didSet {
			if simulationStartTime != oldValue {
				reset()
			}
		}
	}

	/// The inter-particle force this system carries, or nil for none.
	///
	/// Introduced in FxGrip 0.1.0. A system's own interaction wins over a field the effect declares
	/// and over the scene-wide default. The value is copied. Changing it restarts the simulation,
	/// because the force shapes every step.
	public var particleInteraction: FxGripParticleInteraction? {
		get {
			return storedInteraction
		}
		set {
			storedInteraction = newValue?.copy() as? FxGripParticleInteraction
		}
	}
	private var storedInteraction: FxGripParticleInteraction?

	// MARK: - State

	/// The positions of the live particles, in the carrying entity's space.
	public private(set) var positions: [SIMD3<Float>] = []

	/// The velocities of the live particles.
	public private(set) var velocities: [SIMD3<Float>] = []

	/// The ages of the live particles, in seconds.
	public private(set) var ages: [Float] = []

	/// The lives of the live particles, in seconds.
	public private(set) var lifeSpans: [Float] = []

	/// The birth sizes of the live particles.
	public private(set) var sizes: [Float] = []

	/// The birth colors of the live particles.
	public private(set) var colors: [SIMD4<Float>] = []

	/// The current quad rotations of the live particles, in radians.
	public private(set) var angles: [Float] = []

	/// The birth indices of the live particles, which key their seeded variation.
	public private(set) var birthIndices: [UInt32] = []

	/// The number of live particles.
	public var particleCount: Int {
		return positions.count
	}

	/// The step the state corresponds to. Zero is the empty system at `simulationStartTime`.
	public private(set) var currentStep: Int = 0

	/// How many fixed steps this system has simulated in total. A render that resumes adds only the
	/// steps it advances, which is what proves a resume skipped nothing and repeated nothing.
	public private(set) var totalSimulationSteps: Int = 0

	/// The most particles the system holds, from `maximumParticleCount` or derived from the birth
	/// rate and the longest life. At least one.
	public var capacity: Int {
		let configured = configuration.maximumParticleCount
		if configured > 0 {
			return configured
		}
		let longestLife = max(0.0, configuration.particleLifeSpan + abs(configuration.particleLifeSpanVariation))
		let derived = Int((max(0.0, configuration.birthRate) * longestLife).rounded(.up)) + 16
		return max(1, derived)
	}

	private var birthCounter: UInt32 = 0
	private var birthAccumulator: Double = 0.0

	/// Hand-set particles that every restart reinstalls, so they are the initial condition.
	private struct InitialParticles {
		var positions: [SIMD3<Float>]
		var velocities: [SIMD3<Float>]
		var ages: [Float]
		var lifeSpans: [Float]
		var sizes: [Float]
		var colors: [SIMD4<Float>]
		var angles: [Float]
	}
	private var initialParticles: InitialParticles?

	/// What the last step was computed under, so a resume is refused when anything differs.
	var lastStepContext: FxGripRealityKitParticleStepContext?

	/// The FMM context and gather buffers, created on first use and reused.
	let solver = FxGripRealityKitParticleSolver()

	/// The geometry that draws this system, created by the engine on the main actor and reused.
	@MainActor
	var geometry: FxGripRealityKitParticleGeometry?

	/// The material the engine applies to the geometry, or nil for the default unlit material that
	/// reads the per-particle palette.
	///
	/// Introduced in FxGrip 0.1.0. The mesh carries the particle color in its `color` attribute, the
	/// palette texel in `uv0`, and the quad corner in `uv1`, so a `ShaderGraphMaterial` that reads any
	/// of them works here.
	@MainActor
	public var material: (any Material)?

	public init() {
	}

	// MARK: - Stepping

	/// The grid step nearest `seconds`, never negative.
	public func stepIndex(for seconds: TimeInterval) -> Int {
		let step = timeStep > 0.0 ? timeStep : FxGripRealityKitParticleDefaultTimeStep
		let target = max(seconds, simulationStartTime)
		return max(0, Int((target - simulationStartTime) / step + 0.5))
	}

	/// The step length in seconds, which is `timeStep` or the default when that is not positive.
	var effectiveTimeStep: Float {
		return Float(timeStep > 0.0 ? timeStep : FxGripRealityKitParticleDefaultTimeStep)
	}

	/// Returns the system to step zero: empty, or holding the particles `setParticles` installed.
	public func reset() {
		positions.removeAll(keepingCapacity: true)
		velocities.removeAll(keepingCapacity: true)
		ages.removeAll(keepingCapacity: true)
		lifeSpans.removeAll(keepingCapacity: true)
		sizes.removeAll(keepingCapacity: true)
		colors.removeAll(keepingCapacity: true)
		angles.removeAll(keepingCapacity: true)
		birthIndices.removeAll(keepingCapacity: true)
		birthCounter = 0
		birthAccumulator = 0.0
		currentStep = 0
		lastStepContext = nil
		if let initial = initialParticles {
			positions = initial.positions
			velocities = initial.velocities
			ages = initial.ages
			lifeSpans = initial.lifeSpans
			sizes = initial.sizes
			colors = initial.colors
			angles = initial.angles
			birthIndices = (0 ..< initial.positions.count).map { UInt32($0) }
			birthCounter = UInt32(initial.positions.count)
		}
	}

	/// Advances the system alone, under its own interaction, to the step nearest `seconds`.
	///
	/// Introduced in FxGrip 0.1.0. The engine forms fields for a frame and advances those instead;
	/// this is the entry point for a plugin or a test that drives one system directly.
	public func advance(to seconds: TimeInterval) {
		advance(toStep: stepIndex(for: seconds))
	}

	/// Advances the system alone, under its own interaction, to `step`.
	public func advance(toStep step: Int) {
		let field = FxGripRealityKitParticleField(interaction: particleInteraction)
		field.members = [FxGripRealityKitParticleField.Member(system: self, transform: matrix_identity_float4x4)]
		field.advance(toStep: step)
	}

	// MARK: - One step, in three parts

	/// Ages the live particles, drops the dead, and births the step's new particles.
	func beginStep(_ dt: Float, stepStartTime: Float) {
		ageAndCompact(dt)
		emit(dt, stepStartTime: stepStartTime)
	}

	/// Applies the constant acceleration and damping, then integrates positions and rotations.
	func integrate(_ dt: Float) {
		let acceleration = configuration.acceleration
		let damping = max(0.0, 1.0 - configuration.dampingFactor * dt)
		let spin = configuration.particleAngularVelocity * dt
		for index in positions.indices {
			var velocity = velocities[index] + acceleration * dt
			velocity *= damping
			velocities[index] = velocity
			positions[index] += velocity * dt
			angles[index] += spin
		}
	}

	private func ageAndCompact(_ dt: Float) {
		var write = 0
		for read in positions.indices {
			let age = ages[read] + dt
			if age >= lifeSpans[read] {
				continue
			}
			if write != read {
				positions[write] = positions[read]
				velocities[write] = velocities[read]
				lifeSpans[write] = lifeSpans[read]
				sizes[write] = sizes[read]
				colors[write] = colors[read]
				angles[write] = angles[read]
				birthIndices[write] = birthIndices[read]
			}
			ages[write] = age
			write += 1
		}
		if write < positions.count {
			positions.removeLast(positions.count - write)
			velocities.removeLast(velocities.count - write)
			ages.removeLast(ages.count - write)
			lifeSpans.removeLast(lifeSpans.count - write)
			sizes.removeLast(sizes.count - write)
			colors.removeLast(colors.count - write)
			angles.removeLast(angles.count - write)
			birthIndices.removeLast(birthIndices.count - write)
		}
	}

	private func isEmitting(at time: Float) -> Bool {
		let config = configuration
		if config.emissionDuration <= 0.0 {
			return false
		}
		if !config.loops {
			return time < config.emissionDuration
		}
		let period = config.emissionDuration + max(0.0, config.idleDuration)
		let phase = time - period * (time / period).rounded(.down)
		return phase < config.emissionDuration
	}

	private func emit(_ dt: Float, stepStartTime: Float) {
		let config = configuration
		guard config.birthRate > 0.0, isEmitting(at: stepStartTime) else {
			return
		}
		birthAccumulator += Double(config.birthRate) * Double(dt)
		let births = Int(birthAccumulator.rounded(.down))
		birthAccumulator -= Double(births)
		if births <= 0 {
			return
		}

		let limit = capacity
		let seed = config.seed
		let direction = simd_length(config.emittingDirection) > 0.0
			? simd_normalize(config.emittingDirection)
			: SIMD3<Float>(0.0, 1.0, 0.0)
		let baseVelocity = direction * config.particleVelocity
		let spreadTangent = FxGripParticleSpreadTangent(Double(config.spreadingAngle))
		let speed = simd_length(baseVelocity)

		for _ in 0 ..< births {
			if positions.count >= limit {
				return
			}
			let pid = birthCounter
			birthCounter &+= 1

			var velocity = baseVelocity + FxGripParticleRand3(pid, seed, 0) * config.particleVelocityVariation
			if spreadTangent > 0.0 {
				velocity += FxGripParticleRand3(pid, seed, 3) * (speed * spreadTangent)
			}
			let size = max(0.0, config.particleSize + FxGripParticleRand(pid, seed, 6) * config.particleSizeVariation)
			let life = max(0.001, config.particleLifeSpan + FxGripParticleRand(pid, seed, 7) * config.particleLifeSpanVariation)
			let jitter = SIMD4<Float>(FxGripParticleRand(pid, seed, 8), FxGripParticleRand(pid, seed, 9),
									  FxGripParticleRand(pid, seed, 10), FxGripParticleRand(pid, seed, 11))
			let color = simd_clamp(config.particleColor + jitter * config.particleColorVariation,
								   SIMD4<Float>(repeating: 0.0), SIMD4<Float>(repeating: 1.0))
			let angle = config.particleAngle + FxGripParticleRand(pid, seed, 12) * config.particleAngleVariation
			let position = FxGripParticleRand3(pid, seed, 13) * config.emitterExtent

			positions.append(position)
			velocities.append(velocity)
			ages.append(0.0)
			lifeSpans.append(life)
			sizes.append(size)
			colors.append(color)
			angles.append(angle)
			birthIndices.append(pid)
		}
	}

	// MARK: - Rendered values

	/// The fraction of each particle's life that has passed, in [0, 1).
	public var lifeFractions: [Float] {
		var fractions = [Float](repeating: 0.0, count: ages.count)
		for index in ages.indices {
			let life = lifeSpans[index]
			fractions[index] = life > 0.0 ? min(1.0, ages[index] / life) : 1.0
		}
		return fractions
	}

	/// The size each particle draws at, with the end size interpolated in when one is set.
	public var renderedSizes: [Float] {
		guard let end = configuration.particleSizeAtEnd else {
			return sizes
		}
		let fractions = lifeFractions
		var rendered = sizes
		for index in rendered.indices {
			rendered[index] = simd_mix(sizes[index], end, fractions[index])
		}
		return rendered
	}

	/// The color each particle draws with, with the end color interpolated in when one is set.
	public var renderedColors: [SIMD4<Float>] {
		guard let end = configuration.particleColorAtEnd else {
			return colors
		}
		let fractions = lifeFractions
		var rendered = colors
		for index in rendered.indices {
			rendered[index] = simd_mix(colors[index], end, SIMD4<Float>(repeating: fractions[index]))
		}
		return rendered
	}

	/// Installs particles by hand as the system's initial condition and restarts from them.
	///
	/// Introduced in FxGrip 0.1.0. Every array is the same length; an omitted array takes the
	/// configuration's value. The particles are the state at step zero, so every restart, including a
	/// rewind, reinstalls them, and the emitter adds its own births on top. Empty arrays clear them.
	public func setParticles(positions: [SIMD3<Float>],
							 velocities: [SIMD3<Float>],
							 ages: [Float]? = nil,
							 lifeSpans: [Float]? = nil,
							 sizes: [Float]? = nil,
							 colors: [SIMD4<Float>]? = nil,
							 angles: [Float]? = nil) {
		let count = positions.count
		precondition(velocities.count == count, "velocities must match positions")
		if count == 0 {
			initialParticles = nil
		} else {
			initialParticles = InitialParticles(
				positions: positions,
				velocities: velocities,
				ages: ages ?? [Float](repeating: 0.0, count: count),
				lifeSpans: lifeSpans ?? [Float](repeating: configuration.particleLifeSpan, count: count),
				sizes: sizes ?? [Float](repeating: configuration.particleSize, count: count),
				colors: colors ?? [SIMD4<Float>](repeating: configuration.particleColor, count: count),
				angles: angles ?? [Float](repeating: configuration.particleAngle, count: count))
		}
		reset()
	}

	/// Adds `delta` to each particle's velocity. Used by the field to apply the step's force.
	func applyVelocityDeltas(_ deltas: [SIMD3<Float>]) {
		for index in velocities.indices where index < deltas.count {
			velocities[index] += deltas[index]
		}
	}

	/// Marks the state as the result of `step` computed under `context`.
	func commit(step: Int, context: FxGripRealityKitParticleStepContext, stepped: Int) {
		currentStep = step
		lastStepContext = context
		totalSimulationSteps += stepped
	}
}

// MARK: - The step context

/// What a step was computed under. A resume is valid only when the next step's context matches.
///
/// Introduced in FxGrip 0.1.0. The interaction, the field's membership in order, and the member
/// transforms all shape a step, so a system whose last step used a different context restarts.
struct FxGripRealityKitParticleStepContext: Equatable {

	struct Interaction: Equatable {
		var kind: UInt
		var gravity: Double
		var electric: Double
		var magnetic: Double
		var softening: Double
		var order: UInt32
		var theta: Float

		init?(_ interaction: FxGripParticleInteraction?) {
			guard let interaction, interaction.enabled, interaction.kind.rawValue != 0 else {
				return nil
			}
			kind = interaction.kind.rawValue
			gravity = Double(interaction.gravityStrength)
			electric = Double(interaction.electricStrength)
			magnetic = Double(interaction.magneticStrength)
			softening = Double(interaction.softening)
			order = interaction.expansionOrder
			theta = interaction.theta
		}
	}

	var interaction: Interaction?
	var members: [ObjectIdentifier]
	var transforms: [simd_float4x4]
	var timeStep: TimeInterval
	var startTime: TimeInterval
}

// MARK: - The field

/// The inter-particle force over one or more particle systems, evaluated once per step.
///
/// Introduced in FxGrip 0.1.0. This is the RealityKit counterpart of the SceneKit interaction physics
/// field: every member system's particles are sources, every member's particles are targets, and one
/// Fast Multipole evaluation per step serves them all. A field of one member is a system under its
/// own force.
///
/// Members simulate in their own entity's space, so a field over several members gathers their
/// particles into world space through the transforms it is given and maps the resulting accelerations
/// back. A field of one member evaluates in that member's own space, so a moving emitter does not
/// change its particles' mutual force.
///
/// The field steps its members in lockstep. A member whose state was computed under a different
/// context, or that sits at a different step from the others, restarts every member from zero, so the
/// state a frame sees is always the state one step sequence produces.
public final class FxGripRealityKitParticleField {

	/// One member system and the transform that places its space in the field's space.
	public struct Member {
		public var system: FxGripRealityKitParticleSystem
		public var transform: simd_float4x4

		public init(system: FxGripRealityKitParticleSystem, transform: simd_float4x4 = matrix_identity_float4x4) {
			self.system = system
			self.transform = transform
		}
	}

	/// The force configuration, or nil for no force, in which case the field only steps its members.
	public var interaction: FxGripParticleInteraction?

	/// The member systems, in the order their particles are concatenated. The order decides the
	/// summation order and therefore the exact result.
	public var members: [Member] = []

	public init(interaction: FxGripParticleInteraction?) {
		self.interaction = interaction?.copy() as? FxGripParticleInteraction
	}

	/// Advances every member to the step nearest `seconds` on the first member's grid.
	public func advance(to seconds: TimeInterval) {
		guard let first = members.first else {
			return
		}
		advance(toStep: first.system.stepIndex(for: seconds))
	}

	/// Advances every member to `step`, resuming when every member's last step matches this field.
	public func advance(toStep target: Int) {
		guard let first = members.first else {
			return
		}
		let systems = members.map { $0.system }
		let context = FxGripRealityKitParticleStepContext(interaction: .init(interaction),
														   members: systems.map { ObjectIdentifier($0) },
														   transforms: members.map { $0.transform },
														   timeStep: first.system.timeStep,
														   startTime: first.system.simulationStartTime)

		var from = first.system.currentStep
		let resumable = systems.allSatisfy { $0.lastStepContext == context && $0.currentStep == from }
		if !resumable || target < from {
			systems.forEach { $0.reset() }
			from = 0
		}

		let dt = first.system.effectiveTimeStep
		let start = Float(first.system.simulationStartTime)
		if from < target {
			for step in from ..< target {
				let stepStart = start + Float(step) * dt
				for system in systems {
					system.beginStep(dt, stepStartTime: stepStart)
				}
				applyInteraction(dt)
				for system in systems {
					system.integrate(dt)
				}
			}
		}
		for system in systems {
			system.commit(step: target, context: context, stepped: max(0, target - from))
		}
	}

	// MARK: - The force

	/// Adds one step's inter-particle acceleration to every member's velocities.
	///
	/// Gravity uses each source's mass and each receiver's G. Electric uses each source's charge and
	/// each receiver's -k·q/m. Both are the same softened Laplace field over different source
	/// strengths, so each enabled one is one evaluation. Magnetic is a Biot-Savart evaluation over the
	/// charges, and the acceleration is (magnetic·q/m)·(v × B).
	private func applyInteraction(_ dt: Float) {
		guard let config = interaction, config.enabled, config.kind.rawValue != 0 else {
			return
		}
		let kind = config.kind
		let solver = members[0].system.solver
		let uniform = members.count == 1
		let total = members.reduce(0) { $0 + $1.system.particleCount }
		guard total > 1, solver.ensureCapacity(total) else {
			return
		}

		// Gather positions, velocities, masses, and charges into the field's space.
		var offset = 0
		for member in members {
			let system = member.system
			let count = system.particleCount
			let config = system.configuration
			let mass = config.particleMass > 0.0 ? config.particleMass : 1.0
			let rotation = uniform ? matrix_identity_float3x3 : member.transform.fxgUpperLeft3x3
			for index in 0 ..< count {
				var p = system.positions[index]
				var v = system.velocities[index]
				if !uniform {
					p = (member.transform * SIMD4<Float>(p, 1.0)).xyz
					v = rotation * v
				}
				solver.x[offset + index] = p.x
				solver.y[offset + index] = p.y
				solver.z[offset + index] = p.z
				solver.vx[offset + index] = v.x
				solver.vy[offset + index] = v.y
				solver.vz[offset + index] = v.z
				solver.mass[offset + index] = mass
				solver.charge[offset + index] = config.particleCharge
			}
			offset += count
		}

		var parameters = FxGripFMMDefaultParameters()
		parameters.expansionOrder = config.expansionOrder
		parameters.theta = config.theta
		parameters.softening = Float(config.softening)
		let n = UInt32(total)

		for index in 0 ..< total {
			solver.ax[index] = 0.0
			solver.ay[index] = 0.0
			solver.az[index] = 0.0
		}

		if kind.contains(.gravity), config.gravityStrength != 0.0 {
			solver.evaluateField(&parameters, n, strengths: solver.mass)
			let g = Float(config.gravityStrength)
			for index in 0 ..< total {
				solver.ax[index] += g * solver.fx[index]
				solver.ay[index] += g * solver.fy[index]
				solver.az[index] += g * solver.fz[index]
			}
		}

		if kind.contains(.electric), config.electricStrength != 0.0 {
			solver.evaluateField(&parameters, n, strengths: solver.charge)
			let k = Float(config.electricStrength)
			for index in 0 ..< total {
				let coupling = -k * solver.charge[index] / solver.mass[index]
				solver.ax[index] += coupling * solver.fx[index]
				solver.ay[index] += coupling * solver.fy[index]
				solver.az[index] += coupling * solver.fz[index]
			}
		}

		if kind.contains(.magnetic), config.magneticStrength != 0.0 {
			solver.evaluateBiotSavart(&parameters, n)
			let m = Float(config.magneticStrength)
			for index in 0 ..< total {
				let coupling = m * solver.charge[index] / solver.mass[index]
				let velocity = SIMD3<Float>(solver.vx[index], solver.vy[index], solver.vz[index])
				let field = SIMD3<Float>(solver.fx[index], solver.fy[index], solver.fz[index])
				let force = simd_cross(velocity, field) * coupling
				solver.ax[index] += force.x
				solver.ay[index] += force.y
				solver.az[index] += force.z
			}
		}

		// Scatter the accelerations back into each member's space as velocity deltas.
		offset = 0
		for member in members {
			let system = member.system
			let count = system.particleCount
			let inverse = uniform ? matrix_identity_float3x3 : member.transform.fxgUpperLeft3x3.inverse
			var deltas = [SIMD3<Float>](repeating: .zero, count: count)
			for index in 0 ..< count {
				var a = SIMD3<Float>(solver.ax[offset + index], solver.ay[offset + index], solver.az[offset + index])
				if !uniform {
					a = inverse * a
				}
				deltas[index] = a * dt
			}
			system.applyVelocityDeltas(deltas)
			offset += count
		}
	}
}

// MARK: - The solver

/// The Fast Multipole context and the gather buffers one field evaluation uses.
///
/// Introduced in FxGrip 0.1.0. Buffers grow monotonically, so a warm step allocates nothing. The
/// context is not thread-safe, which matches the system it belongs to.
final class FxGripRealityKitParticleSolver {

	private var context: OpaquePointer?
	private(set) var capacity = 0

	var x: [Float] = [], y: [Float] = [], z: [Float] = []
	var vx: [Float] = [], vy: [Float] = [], vz: [Float] = []
	var mass: [Float] = [], charge: [Float] = []
	var fx: [Float] = [], fy: [Float] = [], fz: [Float] = []
	var ax: [Float] = [], ay: [Float] = [], az: [Float] = []

	deinit {
		FxGripFMMContextDestroy(context)
	}

	func ensureCapacity(_ n: Int) -> Bool {
		if context == nil {
			context = FxGripFMMContextCreate()
		}
		guard context != nil else {
			return false
		}
		if n <= capacity {
			return true
		}
		let grown = [Float](repeating: 0.0, count: n)
		x = grown; y = grown; z = grown
		vx = grown; vy = grown; vz = grown
		mass = grown; charge = grown
		fx = grown; fy = grown; fz = grown
		ax = grown; ay = grown; az = grown
		capacity = n
		return true
	}

	/// Evaluates the softened Laplace field of `strengths` at every source, into fx, fy, fz.
	func evaluateField(_ parameters: inout FxGripFMMParameters, _ n: UInt32, strengths: [Float]) {
		FxGripFMMEvaluateField(context, &parameters, n, x, y, z, strengths, &fx, &fy, &fz)
	}

	/// Evaluates the magnetic field of the moving charges at every source, into fx, fy, fz.
	func evaluateBiotSavart(_ parameters: inout FxGripFMMParameters, _ n: UInt32) {
		FxGripFMMEvaluateBiotSavart(context, &parameters, n, x, y, z, charge, vx, vy, vz, &fx, &fy, &fz)
	}
}

extension simd_float4x4 {
	/// The rotation-and-scale part of the transform.
	var fxgUpperLeft3x3: simd_float3x3 {
		return simd_float3x3(columns.0.xyz, columns.1.xyz, columns.2.xyz)
	}
}

extension SIMD4 where Scalar == Float {
	var xyz: SIMD3<Float> {
		return SIMD3<Float>(x, y, z)
	}
}
