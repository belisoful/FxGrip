/*!
	@file       Entity+FxGrip.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     Entity+FxGrip
	@abstract   The bridge from the FxPlug host's camera, lights, and layer into RealityKit entities.
	@discussion Introduced in FxGrip 0.1.0. These builders are the RealityKit counterpart of the
	            `SCNCamera(FxGrip)` and `SCNLight(FxGrip)` categories that serve the SceneKit engine.
	            Each takes values the base has already decoded and returns an entity, so the mapping
	            stays a pure function of the host state.
*/

import AppKit
import CoreGraphics
import Foundation
import FxGrip
import Metal
import RealityKit
import simd

/// The RealityKit intensity that stands for a host light of unit intensity.
///
/// Introduced in FxGrip 0.1.0. The host reports intensity as a multiplier where one is the scene's
/// nominal brightness. Each RealityKit light component carries its own default in physical units, so
/// a host intensity of one maps to that default and the mapping preserves the host's meaning. The
/// SceneKit engine follows the same rule against SceneKit's thousand-lumen default.
private enum FxGripLightReferenceIntensity {
	static let directional: Float = 2145.7078
	static let point: Float = 26963.76
	static let spot: Float = 6740.94
}

@available(macOS 15.0, *)
extension Entity {

	// MARK: - Camera

	/// A camera entity for the host camera.
	///
	/// Introduced in FxGrip 0.1.0. The host reports its projection through `Fx3DAPI_v5` in the Metal
	/// clip convention, which is RealityKit's own, so the matrix drives a
	/// `ProjectiveTransformCameraComponent` unchanged and the render matches the host frustum exactly,
	/// including an asymmetric one.
	///
	/// - projection non-nil → a projective-transform camera carrying the host matrix.
	/// - projection nil, frustum usable → a perspective camera whose vertical field of view and clip
	///   planes come from the frustum.
	/// - neither → a perspective camera with RealityKit's defaults.
	///
	/// `transform` is the camera-to-world transform the base decodes by inverting the host view
	/// matrix. A nil transform leaves the entity at the origin.
	public static func fxgHostCamera(projection: simd_float4x4?,
									 frustum: FxGripHostFrustum?,
									 transform: simd_float4x4?) -> Entity {
		let camera = Entity()
		camera.name = FxGripRealityKitEntityName.camera

		if let projection {
			camera.components.set(ProjectiveTransformCameraComponent(projectionMatrix: projection))
		} else if let frustum, frustum.isUsable {
			var component = PerspectiveCameraComponent()
			component.near = Float(frustum.near)
			component.far = Float(frustum.far)
			component.fieldOfViewInDegrees = frustum.verticalFieldOfViewInDegrees
			camera.components.set(component)
		} else {
			camera.components.set(PerspectiveCameraComponent())
		}

		if let transform {
			camera.transform = Transform(matrix: transform)
		}
		return camera
	}

	// MARK: - Lights

	/// A light entity for one host light, or nil for a light RealityKit does not represent.
	///
	/// Introduced in FxGrip 0.1.0. Type, color, and shadow casting map directly. Intensity scales by
	/// the reference intensity of the matching RealityKit component, so a host intensity of one gives
	/// RealityKit's default brightness. Spot cone angles convert from radians to degrees. A
	/// directional or spot light is oriented so its local -Z axis points along the host direction,
	/// which is the axis RealityKit lights emit along.
	///
	/// The host's ambient light has no RealityKit counterpart. RealityKit expresses ambient
	/// illumination through an image-based light on the renderer, so an ambient host light returns
	/// nil and an engine that needs it sets `RealityRenderer.lighting` instead.
	public static func fxgLight(from light: FxLight) -> Entity? {
		// FxLight.color is __unsafe_unretained, so Swift sees it as an unmanaged reference.
		let color = fxgRenderableColor(light.color?.takeUnretainedValue() ?? NSColor.white)
		let entity = Entity()
		entity.name = FxGripRealityKitEntityName.light

		switch light.lightType {
		case kFxLightType_Directional:
			var component = DirectionalLightComponent(color: color,
													  intensity: light.intensity * FxGripLightReferenceIntensity.directional)
			component.isRealWorldProxy = false
			entity.components.set(component)
			entity.components.set(DirectionalLightComponent.Shadow())

		case kFxLightType_Point:
			entity.components.set(PointLightComponent(color: color,
													  intensity: light.intensity * FxGripLightReferenceIntensity.point))

		case kFxLightType_Spot:
			entity.components.set(SpotLightComponent(color: color,
													 intensity: light.intensity * FxGripLightReferenceIntensity.spot,
													 innerAngleInDegrees: Float(light.spotPenumbraCutoff) * 180.0 / .pi,
													 outerAngleInDegrees: Float(light.spotCutoff) * 180.0 / .pi))
			entity.components.set(SpotLightComponent.Shadow())

		default:
			return nil
		}

		entity.position = SIMD3<Float>(Float(light.position.x), Float(light.position.y), Float(light.position.z))

		if light.lightType == kFxLightType_Directional || light.lightType == kFxLightType_Spot {
			let direction = SIMD3<Float>(Float(light.direction.x), Float(light.direction.y), Float(light.direction.z))
			entity.orientation = FxGripRotationFromTo(SIMD3<Float>(0.0, 0.0, -1.0), direction)
		}

		return entity
	}

	// MARK: - The source layer plane

	/// A plane carrying the source tile at the host layer transform.
	///
	/// Introduced in FxGrip 0.1.0. The plane is one unit square and unlit, so the image reaches the
	/// tile with the host's own values and the layer transform supplies the scale. The counterpart in
	/// the SceneKit engine is the constant-lit `SCNPlane` the layer node carries.
	public static func fxgLayerPlane(texture: TextureResource, transform: simd_float4x4?) -> ModelEntity {
		var material = UnlitMaterial()
		material.color = UnlitMaterial.BaseColor(tint: fxgRenderableColor(.white), texture: .init(texture))
		material.opacityThreshold = nil

		let plane = ModelEntity(mesh: .generatePlane(width: 1.0, height: 1.0), materials: [material])
		plane.name = FxGripRealityKitEntityName.layerPlane
		if let transform {
			plane.transform = Transform(matrix: transform)
		}
		return plane
	}
}

/// The same color in sRGB.
///
/// Introduced in FxGrip 0.1.0. RealityKit resolves a color's gamut from its `CGColorSpace`, so the
/// host color is converted to sRGB first and the gamut RealityKit sees is defined rather than
/// dependent on the display. A color that cannot convert falls back to white.
func fxgRenderableColor(_ color: NSColor) -> NSColor {
	if let converted = color.usingColorSpace(.sRGB) {
		return converted
	}
	return NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
}

/// The names FxGrip gives the entities it creates for a frame.
///
/// Introduced in FxGrip 0.1.0. A plugin finds FxGrip's own entities by name inside the apply hook,
/// the way a SceneKit plugin finds a node by name.
public enum FxGripRealityKitEntityName {
	/// The frame's root, the one entity FxGrip puts in the renderer's collection.
	public static let root = "FxGripRoot"
	/// The host camera, which is the frame's active camera.
	public static let camera = "FxGripCamera"
	/// A host light. Every light FxGrip creates carries this name.
	public static let light = "FxGripLight"
	/// The plane carrying the source tile.
	public static let layerPlane = "FxGripLayerPlane"
	/// The container holding the plugin's authored template, cloned for this frame.
	public static let template = "FxGripTemplate"
}

/// The host camera frustum, as the capture pass recorded it.
///
/// Introduced in FxGrip 0.1.0. The engine uses it when the host reports no projection matrix.
public struct FxGripHostFrustum {

	/// The left clip plane, at the near distance.
	public var left: Double
	/// The right clip plane, at the near distance.
	public var right: Double
	/// The bottom clip plane, at the near distance.
	public var bottom: Double
	/// The top clip plane, at the near distance.
	public var top: Double
	/// The near clip distance.
	public var near: Double
	/// The far clip distance.
	public var far: Double

	/// Creates a frustum from its six planes. An asymmetric left and right, or bottom and top,
	/// describes an off-center projection, which the host reports for a shifted camera.
	public init(left: Double, right: Double, bottom: Double, top: Double, near: Double, far: Double) {
		self.left = left
		self.right = right
		self.bottom = bottom
		self.top = top
		self.near = near
		self.far = far
	}

	/// Whether the frustum has a positive span on every axis and so describes a real view.
	public var isUsable: Bool {
		return right > left && top > bottom && far > near && near > 0.0
	}

	/// The vertical field of view the frustum subtends at the near plane, in degrees.
	public var verticalFieldOfViewInDegrees: Float {
		guard isUsable else {
			return 0.0
		}
		let radians = atan(top / near) - atan(bottom / near)
		return Float(radians * 180.0 / .pi)
	}
}
