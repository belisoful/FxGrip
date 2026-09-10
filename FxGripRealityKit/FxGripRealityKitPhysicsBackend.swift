/*!
	@file       FxGripRealityKitPhysicsBackend.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitPhysicsBackend
	@abstract   A RealityKit render driver that advances physics deterministically by fixed-step
	            catch-up.
	@discussion Introduced in FxGrip 0.1.0. This file holds the RealityKit counterpart of
	            `FxGripSceneKitPhysicsBackend`. It shares the engine-neutral store protocol and mode
	            enum with the SceneKit engine, and differs only in how a frame is stepped and how a
	            body's pose is read and replayed.
*/

import Foundation
import FxGrip
import Metal
import RealityKit
import simd

/// The fixed physics step a driver uses when none is set.
private let FxGripRealityKitDefaultTimeStep: TimeInterval = 1.0 / 60.0

/// Draws a RealityKit frame whose physics has been advanced deterministically.
///
/// Introduced in FxGrip 0.1.0. The host renders frames out of order and re-renders them, so a
/// stateful simulation cannot step once per render. This driver instead simulates from a fixed start
/// to the requested frame on every render, in fixed steps, so a frame's pose is a function of its
/// time and nothing else.
///
/// Two RealityKit facts shape it, both verified rather than assumed.
///
/// - `RealityRenderer.update(_:)` advances physics by the delta it is given → the driver owns the
///   simulation clock and steps it. `PhysicsSimulationComponent.clock` plays no part.
/// - A body simulates only when its entity also carries a `CollisionComponent` → a body without one
///   never moves, whatever its mass or mode.
///
/// RealityKit writes a simulated pose straight back to the entity's transform, so a pose is read
/// with `transformMatrix(relativeTo:)` and replayed by setting it. The SceneKit engine reads a
/// separate presentation node instead.
///
/// In session-cache mode each step's poses are memoized in `simulationStore`, and a later render of
/// a cached step replays the poses instead of simulating. Replay switches each body to kinematic so
/// the solver holds the pose it was given.
open class FxGripRealityKitPhysicsBackend: FxGripRealityKitMetalBackend {

	/// The time the simulation starts from, in the effect's render-time seconds. Defaults to zero.
	public var simulationStartTime: TimeInterval = 0.0

	/// The fixed physics step, in seconds. Defaults to 1/60. A smaller step is more accurate and
	/// costs more per frame. Changing it clears the cache, whose keys are step indices.
	public var timeStep: TimeInterval = FxGripRealityKitDefaultTimeStep {
		didSet {
			if timeStep != oldValue {
				resetSimulationCache()
			}
		}
	}

	/// How simulated state is supplied. Defaults to `.recompute`.
	public var simulationMode: FxGripPhysicsSimulationMode = .recompute

	/// Where session-cache mode memoizes each step. Defaults to an in-memory store, which lasts for
	/// the session. `FxGripPhysicsBake` replaces it with a document-backed store.
	public var simulationStore: any FxGripPhysicsSimulationStore = FxGripPhysicsMemoryStore()

	/// How many fixed steps this driver has simulated. A cache hit adds none, which is what proves a
	/// replay skipped the simulation.
	public private(set) var totalSimulationSteps: Int = 0

	public override init() {
		super.init()
	}

	open override var backendIdentifier: String {
		return "realitykit-metal-physics"
	}

	/// Discards every memoized step. Call it when the frame's bodies or initial conditions change,
	/// because the cache is keyed by step index and assumes a stable scene.
	public func resetSimulationCache() {
		simulationStore.invalidate()
		totalSimulationSteps = 0
	}

	// MARK: - The simulation

	/// Advances the frame to the step nearest `seconds` by fixed-step catch-up.
	///
	/// Introduced in FxGrip 0.1.0. The target grid-aligns to a step index, so a rendered pose matches
	/// its cached step exactly rather than landing between two. In session-cache mode a cached step
	/// replays without simulating.
	@MainActor
	open override func advanceSimulation(_ renderer: RealityRenderer, toTime seconds: TimeInterval) throws {
		let step = timeStep > 0.0 ? timeStep : FxGripRealityKitDefaultTimeStep
		let start = simulationStartTime
		let target = max(seconds, start)

		let stepIndex = max(0, Int((target - start) / step + 0.5))
		let caching = (simulationMode == .sessionCache)

		let bodies = simulationBodies(in: renderer)
		if bodies.isEmpty {
			return
		}

		if caching, let cached = simulationStore.transforms(forStep: stepIndex) {
			apply(cached, to: bodies)
			return
		}

		if caching {
			simulationStore.setTransforms(capture(from: bodies), forStep: 0)
		}

		guard stepIndex > 0 else {
			return
		}
		for index in 1 ... stepIndex {
			try renderer.update(step)
			totalSimulationSteps += 1
			if caching {
				simulationStore.setTransforms(capture(from: bodies), forStep: index)
			}
		}
	}

	// MARK: - Bodies

	/// Every named entity in the frame that carries a physics body.
	///
	/// An unnamed body is skipped, because the store is keyed by name and a frame is rebuilt for each
	/// render. A plugin names the bodies it wants cached.
	@MainActor
	private func simulationBodies(in renderer: RealityRenderer) -> [Entity] {
		var found: [Entity] = []
		for root in renderer.entities {
			collectBodies(root, into: &found)
		}
		// Sorted, so capture and replay visit the same order whatever the frame's build order was.
		return found.sorted { $0.name < $1.name }
	}

	@MainActor
	private func collectBodies(_ entity: Entity, into found: inout [Entity]) {
		if entity.components[PhysicsBodyComponent.self] != nil, !entity.name.isEmpty {
			found.append(entity)
		}
		for child in entity.children {
			collectBodies(child, into: &found)
		}
	}

	@MainActor
	private func capture(from bodies: [Entity]) -> [String: Data] {
		var transforms: [String: Data] = [:]
		for body in bodies {
			var matrix = body.transformMatrix(relativeTo: nil)
			transforms[body.name] = withUnsafeBytes(of: &matrix) { Data($0) }
		}
		return transforms
	}

	/// Places each body at its stored pose and holds it there.
	///
	/// A dynamic body would be pulled off the replayed pose by the next solver step, so a replayed
	/// body becomes kinematic, which RealityKit leaves exactly where it is put.
	@MainActor
	private func apply(_ transforms: [String: Data], to bodies: [Entity]) {
		for body in bodies {
			guard let data = transforms[body.name], data.count == MemoryLayout<simd_float4x4>.size else {
				continue
			}
			var matrix = matrix_identity_float4x4
			_ = withUnsafeMutableBytes(of: &matrix) { data.copyBytes(to: $0) }
			if var component = body.components[PhysicsBodyComponent.self] {
				component.mode = .kinematic
				body.components.set(component)
			}
			body.setTransformMatrix(matrix, relativeTo: nil)
		}
	}
}
