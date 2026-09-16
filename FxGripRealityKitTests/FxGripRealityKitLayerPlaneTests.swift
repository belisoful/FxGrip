/*!
	@file       FxGripRealityKitLayerPlaneTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripRealityKitLayerPlaneTests
	@abstract   Unit tests for the source layer plane, the layer transform, and the error descriptions.
	@discussion Introduced in FxGrip 0.1.0. The layer plane is built only when the host supplies a
	            source tile. FxPlug ships no binary, so FxImageTile did not exist in the test process
	            and this path never ran; the FxPlugStub test framework supplies the class, and these
	            tests drive the frame with a real IOSurface-backed tile. The remaining cases cover the
	            plane factory directly and the localized description of each engine error.
*/

import CoreMedia
import CoreVideo
import FxGrip
import FxPlugStub
import Metal
import RealityKit
import XCTest
import simd

@testable import FxGripRealityKit

/// Runs `body` on the main actor and waits, the way the shipped driver does. The host calls a render
/// from a background thread, so a test double must make the same hop.
private func runOnMainActor<T>(_ body: @MainActor () throws -> T) rethrows -> T {
	if Thread.isMainThread {
		return try MainActor.assumeIsolated(body)
	}
	return try DispatchQueue.main.sync {
		try MainActor.assumeIsolated(body)
	}
}

final class FxGripRealityKitLayerPlaneTests: XCTestCase {

	// MARK: - Helpers

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

	/// A tile backed by a real IOSurface on the given device, the shape the host hands the effect.
	private func makeSourceTile(_ device: any MTLDevice, size: Int32 = 32) throws -> FxImageTile {
		let bounds = FxRect(left: 0, bottom: 0, right: size, top: size)
		return try XCTUnwrap(FxImageTile.stubTile(withPixelBounds: bounds,
												  pixelFormat: OSType(kCVPixelFormatType_64RGBAHalf),
												  device: device))
	}

	private func emptyDecoder() throws -> NSCoder {
		let archiver = NSKeyedArchiver(requiringSecureCoding: false)
		archiver.finishEncoding()
		let decoder = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
		decoder.requiresSecureCoding = false
		return decoder
	}

	/// A decoder carrying a model matrix, which the effect reads as the layer transform.
	private func decoderCarryingLayerTransform() throws -> NSCoder {
		let archiver = NSKeyedArchiver(requiringSecureCoding: false)
		var stored: Matrix44Data = ((2.0, 0.0, 0.0, 0.0),
									(0.0, 3.0, 0.0, 0.0),
									(0.0, 0.0, 1.0, 0.0),
									(5.0, 7.0, 0.0, 1.0))
		archiver.encodeMatrix44Data(&stored,
									forKey: FxGrip3DCoderCurrentTimeKey + FxGrip3DCoderModelMatrixKey)
		archiver.finishEncoding()
		let decoder = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
		decoder.requiresSecureCoding = false
		return decoder
	}

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

	private func layerPlane(in root: Entity?) -> Entity? {
		root?.children.first { $0.name == FxGripRealityKitEntityName.layerPlane }
	}

	// MARK: - The frame's layer plane

	/// A frame built without a source tile carries no layer plane.
	func testAFrameWithoutASourceTileHasNoLayerPlane() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let backend = LayerPlaneCapturingBackend()
		effect.realityBackend = backend

		try renderOffMain(effect, coder: try emptyDecoder(), into: try makeTexture(device))

		XCTAssertEqual(backend.renderCount, 1)
		XCTAssertNil(layerPlane(in: backend.root))
	}

	/// A source tile becomes an unlit one-unit plane hanging off the frame root.
	func testASourceTileBecomesTheLayerPlane() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let backend = LayerPlaneCapturingBackend()
		effect.realityBackend = backend
		let tile = try makeSourceTile(device)

		try renderOffMain(effect, coder: try emptyDecoder(), sourceTile: tile, into: try makeTexture(device))

		let plane = try XCTUnwrap(layerPlane(in: backend.root), "the source tile builds a layer plane")
		XCTAssertTrue(plane.parent === backend.root)
		XCTAssertTrue(plane is ModelEntity)
		XCTAssertFalse(tile.stubRequestedDevices.isEmpty, "the plane reads the tile's Metal texture")
	}

	/// With no layer transform in the coder, the plane keeps the identity transform.
	func testTheLayerPlaneWithoutATransformStaysAtTheIdentity() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let backend = LayerPlaneCapturingBackend()
		effect.realityBackend = backend

		try renderOffMain(effect, coder: try emptyDecoder(),
						  sourceTile: try makeSourceTile(device), into: try makeTexture(device))

		let plane = try XCTUnwrap(layerPlane(in: backend.root))
		XCTAssertEqual(plane.transform.matrix, matrix_identity_float4x4)
	}

	/// The host's model matrix reaches the plane as its transform, transposed into simd's columns.
	func testTheLayerPlaneTakesTheHostLayerTransform() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let backend = LayerPlaneCapturingBackend()
		effect.realityBackend = backend

		try renderOffMain(effect, coder: try decoderCarryingLayerTransform(),
						  sourceTile: try makeSourceTile(device), into: try makeTexture(device))

		let plane = try XCTUnwrap(layerPlane(in: backend.root))
		let matrix = plane.transform.matrix
		XCTAssertEqual(matrix.columns.0.x, 2.0, accuracy: 1e-6)
		XCTAssertEqual(matrix.columns.1.y, 3.0, accuracy: 1e-6)

		// The host stores row-major with translation in row 3; simd puts it in column 3.
		XCTAssertEqual(matrix.columns.3.x, 5.0, accuracy: 1e-6)
		XCTAssertEqual(matrix.columns.3.y, 7.0, accuracy: 1e-6)
	}

	/// A tile whose texture cannot be reached leaves the frame without a plane and still renders.
	func testATileWithNoTextureLeavesTheFrameWithoutAPlane() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let backend = LayerPlaneCapturingBackend()
		effect.realityBackend = backend
		let tile = FxImageTile.stubTile(withPixelBounds: FxRect(left: 0, bottom: 0, right: 32, top: 32))
		tile.stubTextureProvider = { _ in nil }

		try renderOffMain(effect, coder: try emptyDecoder(), sourceTile: tile, into: try makeTexture(device))

		XCTAssertEqual(backend.renderCount, 1, "the frame still renders")
		XCTAssertNil(layerPlane(in: backend.root))
	}

	/// Each render rebuilds the plane rather than reusing the entity from the render before it.
	func testEachRenderBuildsAFreshLayerPlane() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let backend = LayerPlaneCapturingBackend()
		effect.realityBackend = backend
		let tile = try makeSourceTile(device)
		let texture = try makeTexture(device)

		try renderOffMain(effect, coder: try emptyDecoder(), sourceTile: tile, into: texture)
		let first = try XCTUnwrap(layerPlane(in: backend.root))
		try renderOffMain(effect, coder: try emptyDecoder(), sourceTile: tile, into: texture)
		let second = try XCTUnwrap(layerPlane(in: backend.root))

		XCTAssertEqual(backend.renderCount, 2)
		XCTAssertFalse(first === second)
	}

	// MARK: - The plane factory

	/// fxgLayerPlane names the plane, carries one material, and applies a transform when given one.
	func testTheLayerPlaneFactoryAppliesItsTransform() throws {
		let device = try metalDevice()
		let resource = try runOnMainActor { try TextureResource(image: try self.makeCGImage(), options: .init(semantic: .color)) }
		var transform = matrix_identity_float4x4
		transform.columns.3 = SIMD4<Float>(1.0, 2.0, 3.0, 1.0)

		let plane = try runOnMainActor { Entity.fxgLayerPlane(texture: resource, transform: transform) }
		let untransformed = try runOnMainActor { Entity.fxgLayerPlane(texture: resource, transform: nil) }

		XCTAssertEqual(plane.name, FxGripRealityKitEntityName.layerPlane)
		XCTAssertEqual(plane.model?.materials.count, 1)
		XCTAssertEqual(plane.transform.matrix.columns.3, SIMD4<Float>(1.0, 2.0, 3.0, 1.0))
		XCTAssertEqual(untransformed.transform.matrix, matrix_identity_float4x4)
	}

	private func makeCGImage(size: Int = 4) throws -> CGImage {
		let space = CGColorSpaceCreateDeviceRGB()
		let context = try XCTUnwrap(CGContext(data: nil, width: size, height: size,
											  bitsPerComponent: 8, bytesPerRow: size * 4,
											  space: space,
											  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
		context.setFillColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
		context.fill(CGRect(x: 0, y: 0, width: size, height: size))
		return try XCTUnwrap(context.makeImage())
	}

	// MARK: - Error descriptions

	/// Every engine error describes itself, naming the values it carries.
	func testEveryErrorDescribesItself() throws {
		let unavailable = FxGripRealityKitError.rendererUnavailable("no device")
		let mismatch = FxGripRealityKitError.deviceMismatch(expected: "Apple M1", found: "Radeon")
		let missingCamera = FxGripRealityKitError.missingCamera
		let failed = FxGripRealityKitError.renderFailed("timed out")

		XCTAssertEqual(unavailable.errorDescription,
					   "the RealityKit renderer is unavailable: no device")
		XCTAssertEqual(mismatch.errorDescription,
					   "the destination tile is on Metal device Radeon, and the RealityKit renderer draws on Apple M1")
		XCTAssertEqual(missingCamera.errorDescription, "the frame set no active camera")
		XCTAssertEqual(failed.errorDescription, "the RealityKit render failed: timed out")
	}

	/// The errors carry their description through LocalizedError, which is what the host reads.
	func testTheErrorsCarryTheirDescriptionAsLocalizedErrors() throws {
		let error: any Error = FxGripRealityKitError.missingCamera

		XCTAssertEqual(error.localizedDescription, "the frame set no active camera")
	}
}

/// Captures the frame the effect assembles without drawing it.
private final class LayerPlaneCapturingBackend: FxGripRealityKitBackend {

	var isReady: Bool = true
	var backendIdentifier: String = "layer-plane-capturing"

	private(set) var renderCount = 0
	private(set) var root: Entity?

	private var renderer: RealityRenderer?

	func canRender(into texture: any MTLTexture) -> Bool {
		return true
	}

	func render(into texture: any MTLTexture,
				atTime seconds: TimeInterval,
				scene: FxGripRealityKitSceneBuilder) throws {
		try runOnMainActor {
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
			root = active.entities.first
		}
	}
}
