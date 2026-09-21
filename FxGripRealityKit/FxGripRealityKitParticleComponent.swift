/*!
	@file       FxGripRealityKitParticleComponent.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitParticleComponent
	@abstract   The component that places an FxGrip particle system on an entity.
	@discussion Introduced in FxGrip 0.1.0. The engine finds every entity in a frame that carries this
	            component, steps its system to the frame's time, and installs the system's geometry as
	            the entity's model. This file declares the component and the entity convenience that
	            creates a carrier.
*/

import Foundation
import RealityKit

/// Marks an entity as the carrier of an `FxGripRealityKitParticleSystem`.
///
/// Introduced in FxGrip 0.1.0. The system is a reference the plugin owns across frames; the entity
/// is rebuilt each frame, by the apply hook or by cloning the template. The particles simulate in the
/// carrier's space, so the carrier's transform is the emitter transform.
///
/// The engine gives the carrier a `ModelComponent` each frame. A model the plugin set on the carrier
/// is replaced.
public struct FxGripRealityKitParticleComponent: Component {

	/// The particle system this entity carries.
	public var system: FxGripRealityKitParticleSystem

	/// Wraps a particle system so an entity carries it into the frame.
	public init(system: FxGripRealityKitParticleSystem) {
		Self.registerComponent()
		self.system = system
	}
}

extension Entity {

	/// An entity that carries `system`, named `name`.
	///
	/// Introduced in FxGrip 0.1.0. The name is what the effect's `particleInteractionFields` refer to,
	/// and what a plugin finds the carrier by after a template is cloned.
	@MainActor
	public static func fxgParticleCarrier(_ system: FxGripRealityKitParticleSystem, name: String = "") -> Entity {
		let entity = Entity()
		entity.name = name
		entity.components.set(FxGripRealityKitParticleComponent(system: system))
		return entity
	}

	/// The particle system this entity carries, or nil.
	@MainActor
	public var fxgParticleSystem: FxGripRealityKitParticleSystem? {
		return components[FxGripRealityKitParticleComponent.self]?.system
	}

	/// Whether `ancestor` is this entity or one of its ancestors.
	@MainActor
	func fxgIsSelfOrDescendant(of ancestor: Entity) -> Bool {
		var current: Entity? = self
		while let entity = current {
			if entity === ancestor {
				return true
			}
			current = entity.parent
		}
		return false
	}
}
