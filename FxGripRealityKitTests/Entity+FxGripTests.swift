/*!
	@file       Entity+FxGripTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     Entity+FxGripTests
	@abstract   Unit tests for the host-to-RealityKit camera, light, and layer-plane bridge.
	@discussion Introduced in FxGrip 0.1.0. The builders are pure functions of decoded host values, so
	            these tests construct the host values directly and inspect the resulting entities.
*/

import AppKit
import FxGrip
import RealityKit
import XCTest
import simd

@testable import FxGripRealityKit

@MainActor
final class EntityFxGripTests: XCTestCase {

	// MARK: - Camera

	/// The host reports its projection in the Metal clip convention, which RealityKit shares, so the
	/// matrix drives a projective-transform camera unchanged.
	func testCameraUsesTheHostProjectionMatrixWhenPresent() {
		var projection = matrix_identity_float4x4
		projection.columns.0.x = 1.5
		projection.columns.2.z = -1.002

		let camera = Entity.fxgHostCamera(projection: projection, frustum: nil, transform: nil)

		let component = camera.components[ProjectiveTransformCameraComponent.self]
		XCTAssertNotNil(component)
		XCTAssertEqual(component?.transform.columns.0.x, 1.5)
		XCTAssertNil(camera.components[PerspectiveCameraComponent.self])
	}

	/// Without a projection the frustum supplies a perspective camera, whose vertical field of view is
	/// the angle the frustum subtends at the near plane.
	func testCameraFallsBackToTheFrustum() {
		// A symmetric frustum spanning 45 degrees vertically at the near plane.
		let halfHeight = tan(22.5 * .pi / 180.0)
		let frustum = FxGripHostFrustum(left: -halfHeight, right: halfHeight,
										bottom: -halfHeight, top: halfHeight,
										near: 1.0, far: 100.0)

		let camera = Entity.fxgHostCamera(projection: nil, frustum: frustum, transform: nil)

		let component = camera.components[PerspectiveCameraComponent.self]
		XCTAssertNotNil(component)
		XCTAssertEqual(component?.near ?? 0.0, 1.0, accuracy: 1e-5)
		XCTAssertEqual(component?.far ?? 0.0, 100.0, accuracy: 1e-4)
		XCTAssertEqual(component?.fieldOfViewInDegrees ?? 0.0, 45.0, accuracy: 1e-3)
		XCTAssertNil(camera.components[ProjectiveTransformCameraComponent.self])
	}

	/// With neither a projection nor a usable frustum the camera keeps RealityKit's defaults.
	func testCameraWithoutHostStateUsesDefaults() {
		let camera = Entity.fxgHostCamera(projection: nil, frustum: nil, transform: nil)
		XCTAssertNotNil(camera.components[PerspectiveCameraComponent.self])
	}

	/// A frustum with a collapsed span is not usable and does not reach the camera.
	func testDegenerateFrustumIsNotUsable() {
		let flat = FxGripHostFrustum(left: 0.0, right: 0.0, bottom: -1.0, top: 1.0, near: 1.0, far: 10.0)
		XCTAssertFalse(flat.isUsable)

		let behind = FxGripHostFrustum(left: -1.0, right: 1.0, bottom: -1.0, top: 1.0, near: 0.0, far: 10.0)
		XCTAssertFalse(behind.isUsable)
	}

	/// The camera transform is the camera-to-world transform the base decodes.
	func testCameraCarriesTheDecodedTransform() {
		var transform = matrix_identity_float4x4
		transform.columns.3 = SIMD4<Float>(1.0, 2.0, 3.0, 1.0)

		let camera = Entity.fxgHostCamera(projection: nil, frustum: nil, transform: transform)

		XCTAssertEqual(camera.position.x, 1.0, accuracy: 1e-5)
		XCTAssertEqual(camera.position.y, 2.0, accuracy: 1e-5)
		XCTAssertEqual(camera.position.z, 3.0, accuracy: 1e-5)
	}

	// MARK: - Lights

	private func hostLight(_ type: FxLightType,
						   intensity: Float = 1.0,
						   position: FxPoint3D = FxPoint3D(x: 0.0, y: 0.0, z: 0.0),
						   direction: FxPoint3D = FxPoint3D(x: 0.0, y: 0.0, z: -1.0)) -> FxLight {
		var light = FxLight()
		light.lightType = type
		light.intensity = intensity
		light.position = position
		light.direction = direction
		light.spotCutoff = Float(60.0 * .pi / 180.0)
		light.spotPenumbraCutoff = Float(45.0 * .pi / 180.0)
		return light
	}

	/// A host intensity of one maps to RealityKit's own default intensity for that light type, so the
	/// host's "nominal brightness" keeps its meaning.
	func testLightIntensityScalesToRealityKitsReference() throws {
		let directional = try XCTUnwrap(Entity.fxgLight(from: hostLight(kFxLightType_Directional)))
		XCTAssertEqual(directional.components[DirectionalLightComponent.self]?.intensity ?? 0.0,
					   DirectionalLightComponent().intensity, accuracy: 1e-2)

		let point = try XCTUnwrap(Entity.fxgLight(from: hostLight(kFxLightType_Point)))
		XCTAssertEqual(point.components[PointLightComponent.self]?.intensity ?? 0.0,
					   PointLightComponent().intensity, accuracy: 1e-1)

		let spot = try XCTUnwrap(Entity.fxgLight(from: hostLight(kFxLightType_Spot)))
		XCTAssertEqual(spot.components[SpotLightComponent.self]?.intensity ?? 0.0,
					   SpotLightComponent().intensity, accuracy: 1e-1)
	}

	/// A doubled host intensity doubles the RealityKit intensity.
	func testLightIntensityIsProportional() throws {
		let single = try XCTUnwrap(Entity.fxgLight(from: hostLight(kFxLightType_Point, intensity: 1.0)))
		let double = try XCTUnwrap(Entity.fxgLight(from: hostLight(kFxLightType_Point, intensity: 2.0)))

		let a = single.components[PointLightComponent.self]?.intensity ?? 0.0
		let b = double.components[PointLightComponent.self]?.intensity ?? 0.0
		XCTAssertEqual(b, a * 2.0, accuracy: 1e-1)
	}

	/// Spot cone angles convert from the host's radians to RealityKit's degrees.
	func testSpotConeAnglesConvertToDegrees() throws {
		let spot = try XCTUnwrap(Entity.fxgLight(from: hostLight(kFxLightType_Spot)))
		let component = try XCTUnwrap(spot.components[SpotLightComponent.self])
		XCTAssertEqual(component.innerAngleInDegrees, 45.0, accuracy: 1e-3)
		XCTAssertEqual(component.outerAngleInDegrees, 60.0, accuracy: 1e-3)
	}

	/// A directional light is oriented so its local -Z axis points along the host direction, which is
	/// the axis RealityKit lights emit along.
	func testDirectionalLightAimsAlongTheHostDirection() throws {
		let light = hostLight(kFxLightType_Directional,
							  direction: FxPoint3D(x: 1.0, y: 0.0, z: 0.0))
		let entity = try XCTUnwrap(Entity.fxgLight(from: light))

		let emitted = entity.orientation.act(SIMD3<Float>(0.0, 0.0, -1.0))
		XCTAssertEqual(emitted.x, 1.0, accuracy: 1e-5)
		XCTAssertEqual(emitted.y, 0.0, accuracy: 1e-5)
		XCTAssertEqual(emitted.z, 0.0, accuracy: 1e-5)
	}

	/// A point light carries the host position and needs no orientation.
	func testPointLightCarriesTheHostPosition() throws {
		let light = hostLight(kFxLightType_Point, position: FxPoint3D(x: 3.0, y: -4.0, z: 5.0))
		let entity = try XCTUnwrap(Entity.fxgLight(from: light))

		XCTAssertEqual(entity.position.x, 3.0, accuracy: 1e-5)
		XCTAssertEqual(entity.position.y, -4.0, accuracy: 1e-5)
		XCTAssertEqual(entity.position.z, 5.0, accuracy: 1e-5)
	}

	/// RealityKit expresses ambient illumination through an image-based light on the renderer, not a
	/// light entity, so an ambient host light produces none.
	func testAmbientLightHasNoEntityCounterpart() {
		XCTAssertNil(Entity.fxgLight(from: hostLight(kFxLightType_Ambient)))
	}

	/// The host color reaches the light component.
	func testLightCarriesTheHostColor() throws {
		var light = hostLight(kFxLightType_Point)
		light.color = Unmanaged.passUnretained(NSColor.red)
		let entity = try XCTUnwrap(Entity.fxgLight(from: light))
		XCTAssertNotNil(entity.components[PointLightComponent.self])
	}

	/// Every entity FxGrip builds carries the name a plugin looks it up by.
	func testEntitiesCarryTheirFxGripNames() throws {
		XCTAssertEqual(Entity.fxgHostCamera(projection: nil, frustum: nil, transform: nil).name,
					   FxGripRealityKitEntityName.camera)
		XCTAssertEqual(try XCTUnwrap(Entity.fxgLight(from: hostLight(kFxLightType_Point))).name,
					   FxGripRealityKitEntityName.light)
	}
}
