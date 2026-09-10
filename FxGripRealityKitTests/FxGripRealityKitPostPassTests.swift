/*!
	@file       FxGripRealityKitPostPassTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitPostPassTests
	@abstract   Tests for the camera motion-blur and depth-of-field pass and its seam on the effect.
	@discussion Introduced in FxGrip 0.1.0. The pass tests draw synthetic tiles and depth proxies and
	            read pixels back, so each kernel is checked on its own: no motion leaves a tile
	            untouched, rotation smears across an edge, focus keeps its plane sharp and blurs the
	            rest. The effect tests render a real frame through the seam. Every test skips without
	            a Metal device.
*/

import AppKit
import CoreMedia
import FxGrip
import Metal
import RealityKit
import XCTest
import simd

@testable import FxGripRealityKit

/// Renders one unlit box and returns the camera effects a test sets.
private final class EffectsEffect: FxGripRealityKitEffect {

	var effects = FxGripRealityKitCameraEffects.none
	var boxDistance: Float = 5.0
	private(set) var receivedMotion = FxGripCameraMotionZero()

	override func cameraEffects(from coder: NSCoder,
								at renderTime: CMTime,
								cameraMotion: FxGripCameraMotion) -> FxGripRealityKitCameraEffects {
		receivedMotion = cameraMotion
		return effects
	}

	override func updateSceneContents(_ renderer: RealityRenderer,
									  root: Entity,
									  camera: Entity,
									  from coder: NSCoder,
									  at renderTime: CMTime,
									  cameraMotion: FxGripCameraMotion) {
		let box = ModelEntity(mesh: .generateBox(size: 2.0),
							  materials: [UnlitMaterial(color: NSColor(srgbRed: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))])
		box.name = "box"
		box.position = SIMD3<Float>(0.0, 0.0, -boxDistance)
		root.addChild(box)
	}
}

final class FxGripRealityKitPostPassTests: XCTestCase {

	// MARK: - Fixtures

	private func metalDevice() throws -> any MTLDevice {
		guard let device = MTLCreateSystemDefaultDevice() else {
			throw XCTSkip("No Metal device available")
		}
		return device
	}

	private func makeTexture(_ device: any MTLDevice,
							 size: Int = 64,
							 pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> any MTLTexture {
		let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
																  width: size,
																  height: size,
																  mipmapped: false)
		descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
		descriptor.storageMode = .shared
		return try XCTUnwrap(device.makeTexture(descriptor: descriptor))
	}

	/// Fills an 8-bit texture from a per-pixel function.
	private func fill(_ texture: any MTLTexture, _ pixel: (Int, Int) -> [UInt8]) {
		var bytes = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
		for y in 0 ..< texture.height {
			for x in 0 ..< texture.width {
				let value = pixel(x, y)
				let at = (y * texture.width + x) * 4
				bytes.replaceSubrange(at ..< at + 4, with: value)
			}
		}
		texture.replace(region: MTLRegionMake2D(0, 0, texture.width, texture.height),
						mipmapLevel: 0,
						withBytes: bytes,
						bytesPerRow: texture.width * 4)
	}

	/// Fills a float depth proxy from a per-pixel view depth, or nil for "nothing drawn".
	private func fillProxy(_ texture: any MTLTexture, far: Float, _ depth: (Int, Int) -> Float?) {
		var floats = [Float](repeating: 0.0, count: texture.width * texture.height * 4)
		for y in 0 ..< texture.height {
			for x in 0 ..< texture.width {
				let at = (y * texture.width + x) * 4
				if let z = depth(x, y) {
					floats[at] = z / far
					floats[at + 3] = 1.0
				}
			}
		}
		floats.withUnsafeBytes { raw in
			texture.replace(region: MTLRegionMake2D(0, 0, texture.width, texture.height),
							mipmapLevel: 0,
							withBytes: raw.baseAddress!,
							bytesPerRow: texture.width * 16)
		}
	}

	private func pixels(of texture: any MTLTexture) -> [UInt8] {
		var bytes = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
		texture.getBytes(&bytes,
						 bytesPerRow: texture.width * 4,
						 from: MTLRegionMake2D(0, 0, texture.width, texture.height),
						 mipmapLevel: 0)
		return bytes
	}

	private func pixel(_ texture: any MTLTexture, _ x: Int, _ y: Int) -> [UInt8] {
		var value = [UInt8](repeating: 0, count: 4)
		texture.getBytes(&value, bytesPerRow: 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
		return value
	}

	private let red: [UInt8] = [255, 0, 0, 255]
	private let green: [UInt8] = [0, 255, 0, 255]

	/// A tile whose left half is red and right half green.
	private func edgeTile(_ device: any MTLDevice) throws -> any MTLTexture {
		let texture = try makeTexture(device)
		fill(texture) { x, _ in x < 32 ? self.red : self.green }
		return texture
	}

	private func camera(fov: Float = 60.0, far: Float = 100.0) -> FxGripRealityKitPostCamera {
		return FxGripRealityKitPostCamera(projection: FxGripRealityKitEffect.perspective(verticalFieldOfView: fov, aspect: 1.0, near: 0.1, far: far),
										  cameraToWorld: matrix_identity_float4x4,
										  near: 0.1,
										  far: far)
	}

	/// A decoder holding no host state.
	private func emptyDecoder() throws -> NSCoder {
		let archiver = NSKeyedArchiver(requiringSecureCoding: false)
		archiver.finishEncoding()
		let decoder = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
		decoder.requiresSecureCoding = false
		return decoder
	}

	private func renderOffMain(_ effect: FxGripRealityKitEffect, coder: NSCoder, into texture: any MTLTexture) throws {
		var thrown: Error?
		let finished = expectation(description: "render finished")
		DispatchQueue.global().async {
			do {
				try effect.renderScene(from: coder, sourceTile: nil, to: texture, at: .zero)
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

	// MARK: - The camera description

	func testEarlierPoseMovesBackAlongTheVelocity() {
		var camera = camera()
		camera.linearVelocity = SIMD3<Float>(2.0, 0.0, 0.0)
		let earlier = camera.cameraToWorld(secondsEarlier: 0.5)
		XCTAssertEqual(earlier.columns.3.x, -1.0, accuracy: 1e-6)
		XCTAssertEqual(earlier.columns.3.w, 1.0)
	}

	func testEarlierPoseTurnsBackAgainstTheAngularVelocity() {
		var camera = camera()
		camera.angularVelocity = SIMD3<Float>(0.0, .pi, 0.0)
		let earlier = camera.cameraToWorld(secondsEarlier: 0.5)
		// A quarter turn back about Y carries local -Z onto world +X.
		let forward = earlier * SIMD4<Float>(0.0, 0.0, -1.0, 0.0)
		XCTAssertEqual(forward.x, 1.0, accuracy: 1e-5)
		XCTAssertEqual(forward.z, 0.0, accuracy: 1e-5)
		XCTAssertEqual(earlier.columns.3, SIMD4<Float>(0.0, 0.0, 0.0, 1.0), "a turn keeps the position")
	}

	func testFocalPixelsComeFromTheProjection() {
		let camera = camera(fov: 90.0)
		XCTAssertEqual(camera.focalPixels(forHeight: 200), 100.0, accuracy: 1e-3)
	}

	func testEffectsDefaultToNone() {
		XCTAssertTrue(FxGripRealityKitCameraEffects.none.isEmpty)
		XCTAssertFalse(FxGripRealityKitCameraEffects(motionBlur: .init()).isEmpty)
		XCTAssertFalse(FxGripRealityKitCameraEffects(depthOfField: .init(focusDistance: 5.0, aperture: 1.0)).isEmpty)
	}

	// MARK: - Motion blur

	func testPassLoadsItsKernels() throws {
		let device = try metalDevice()
		let pass = try FxGripRealityKitPostPass(device: device)
		XCTAssertEqual(pass.device.registryID, device.registryID)
	}

	func testEmptyEffectsLeaveTheTileUntouched() throws {
		let device = try metalDevice()
		let pass = try FxGripRealityKitPostPass(device: device)
		let tile = try edgeTile(device)
		let before = pixels(of: tile)
		try pass.apply(to: tile, effects: .none, camera: camera(), depthProxy: nil, assumedDepth: 5.0)
		XCTAssertEqual(pixels(of: tile), before)
	}

	func testNoMotionLeavesTheTileUntouched() throws {
		let device = try metalDevice()
		let pass = try FxGripRealityKitPostPass(device: device)
		let tile = try edgeTile(device)
		let before = pixels(of: tile)
		try pass.apply(to: tile,
					   effects: .init(motionBlur: .init()),
					   camera: camera(),
					   depthProxy: nil,
					   assumedDepth: 5.0)
		XCTAssertEqual(pixels(of: tile), before)
	}

	func testRotationSmearsAcrossTheEdge() throws {
		let device = try metalDevice()
		let pass = try FxGripRealityKitPostPass(device: device)
		let tile = try edgeTile(device)
		var camera = camera()
		camera.angularVelocity = SIMD3<Float>(0.0, 2.0, 0.0)
		try pass.apply(to: tile,
					   effects: .init(motionBlur: .init(shutter: 0.1)),
					   camera: camera,
					   depthProxy: nil,
					   assumedDepth: 5.0)

		let atEdge = pixel(tile, 31, 32)
		XCTAssertGreaterThan(atEdge[0], 40, "red mixed at the edge: \(atEdge)")
		XCTAssertGreaterThan(atEdge[1], 40, "green mixed at the edge: \(atEdge)")
		XCTAssertEqual(pixel(tile, 4, 32), red, "far from the edge the tile is unchanged")
		XCTAssertEqual(pixel(tile, 60, 32), green)
	}

	func testTranslationAlongTheViewProducesNoBlurAtTheCenter() throws {
		let device = try metalDevice()
		let pass = try FxGripRealityKitPostPass(device: device)
		let tile = try makeTexture(device)
		fill(tile) { x, y in (x + y) % 2 == 0 ? self.red : self.green }
		var camera = camera()
		camera.linearVelocity = SIMD3<Float>(0.0, 0.0, -3.0)
		try pass.apply(to: tile,
					   effects: .init(motionBlur: .init(shutter: 0.1)),
					   camera: camera,
					   depthProxy: nil,
					   assumedDepth: 5.0)
		// A dolly along the view leaves the center pixel where it was, and blurs the corners.
		let corner = pixel(tile, 2, 2)
		XCTAssertGreaterThan(corner[0], 40, "the corner is a mix: \(corner)")
		XCTAssertGreaterThan(corner[1], 40)
	}

	func testMotionBlurIsDeterministic() throws {
		let device = try metalDevice()
		let pass = try FxGripRealityKitPostPass(device: device)
		var camera = camera()
		camera.angularVelocity = SIMD3<Float>(0.5, 1.0, 0.0)
		camera.linearVelocity = SIMD3<Float>(1.0, 0.0, 0.0)
		let first = try edgeTile(device)
		let second = try edgeTile(device)
		try pass.apply(to: first, effects: .init(motionBlur: .init(shutter: 0.05)), camera: camera, depthProxy: nil, assumedDepth: 5.0)
		try pass.apply(to: second, effects: .init(motionBlur: .init(shutter: 0.05)), camera: camera, depthProxy: nil, assumedDepth: 5.0)
		XCTAssertEqual(pixels(of: first), pixels(of: second))
	}

	// MARK: - Depth of field

	/// A striped tile and a proxy whose left half sits at the focus and right half far behind it.
	private func stripedScene(_ device: any MTLDevice, focus: Float, far: Float) throws -> (tile: any MTLTexture, proxy: any MTLTexture) {
		let tile = try makeTexture(device)
		fill(tile) { _, y in y % 2 == 0 ? self.red : self.green }
		let proxy = try makeTexture(device, pixelFormat: .rgba32Float)
		fillProxy(proxy, far: far) { x, _ in x < 32 ? focus : focus * 4.0 }
		return (tile, proxy)
	}

	func testDepthOfFieldKeepsTheFocusPlaneSharpAndBlursTheRest() throws {
		let device = try metalDevice()
		let pass = try FxGripRealityKitPostPass(device: device)
		let scene = try stripedScene(device, focus: 5.0, far: 100.0)
		try pass.apply(to: scene.tile,
					   effects: .init(depthOfField: .init(focusDistance: 5.0, aperture: 2.0)),
					   camera: camera(),
					   depthProxy: scene.proxy,
					   assumedDepth: 5.0)

		XCTAssertEqual(pixel(scene.tile, 8, 10), red, "in focus, the stripes survive")
		XCTAssertEqual(pixel(scene.tile, 8, 11), green)
		let blurred = pixel(scene.tile, 56, 10)
		XCTAssertGreaterThan(blurred[0], 40, "out of focus, the stripes mix: \(blurred)")
		XCTAssertGreaterThan(blurred[1], 40)
	}

	func testDepthOfFieldWithoutAProxyIsSkipped() throws {
		let device = try metalDevice()
		let pass = try FxGripRealityKitPostPass(device: device)
		let scene = try stripedScene(device, focus: 5.0, far: 100.0)
		let before = pixels(of: scene.tile)
		try pass.apply(to: scene.tile,
					   effects: .init(depthOfField: .init(focusDistance: 5.0, aperture: 2.0)),
					   camera: camera(),
					   depthProxy: nil,
					   assumedDepth: 5.0)
		XCTAssertEqual(pixels(of: scene.tile), before)
	}

	func testUndrawnProxyPixelsTakeTheFarDepth() throws {
		let device = try metalDevice()
		let pass = try FxGripRealityKitPostPass(device: device)
		let tile = try makeTexture(device)
		fill(tile) { _, y in y % 2 == 0 ? self.red : self.green }
		let proxy = try makeTexture(device, pixelFormat: .rgba32Float)
		fillProxy(proxy, far: 100.0) { _, _ in nil }
		try pass.apply(to: tile,
					   effects: .init(depthOfField: .init(focusDistance: 5.0, aperture: 2.0)),
					   camera: camera(),
					   depthProxy: proxy,
					   assumedDepth: 5.0)
		let blurred = pixel(tile, 32, 32)
		XCTAssertGreaterThan(blurred[0], 40, "the background is far from focus and blurs: \(blurred)")
		XCTAssertGreaterThan(blurred[1], 40)
	}

	func testDepthOfFieldIsDeterministic() throws {
		let device = try metalDevice()
		let pass = try FxGripRealityKitPostPass(device: device)
		let first = try stripedScene(device, focus: 5.0, far: 100.0)
		let second = try stripedScene(device, focus: 5.0, far: 100.0)
		let effects = FxGripRealityKitCameraEffects(depthOfField: .init(focusDistance: 5.0, aperture: 2.0))
		try pass.apply(to: first.tile, effects: effects, camera: camera(), depthProxy: first.proxy, assumedDepth: 5.0)
		try pass.apply(to: second.tile, effects: effects, camera: camera(), depthProxy: second.proxy, assumedDepth: 5.0)
		XCTAssertEqual(pixels(of: first.tile), pixels(of: second.tile))
	}

	func testScratchTexturesArePooled() throws {
		let device = try metalDevice()
		let pass = try FxGripRealityKitPostPass(device: device)
		let first = try XCTUnwrap(pass.dequeueScratch(width: 16, height: 16, pixelFormat: .rgba8Unorm))
		pass.enqueueScratch(first)
		let second = try XCTUnwrap(pass.dequeueScratch(width: 16, height: 16, pixelFormat: .rgba8Unorm))
		XCTAssertTrue(first === second)
		let other = try XCTUnwrap(pass.dequeueScratch(width: 16, height: 16, pixelFormat: .rgba32Float))
		XCTAssertFalse(other === second, "a different format is a different texture")
	}

	// MARK: - The seam on the effect

	func testEffectAppliesNoEffectsByDefault() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		XCTAssertTrue(effect.cameraEffects(from: try emptyDecoder(), at: .zero, cameraMotion: FxGripCameraMotionZero()).isEmpty)
		XCTAssertNil(effect.autofocusDistance(from: try emptyDecoder()), "no host layer, no autofocus")
		_ = device
	}

	func testMotionBlurThroughTheEffectChangesTheFrame() throws {
		let device = try metalDevice()
		let plain = try XCTUnwrap(EffectsEffect(apiManager: nil))
		plain.rendersSourceLayerPlane = false
		let blurred = try XCTUnwrap(EffectsEffect(apiManager: nil))
		blurred.rendersSourceLayerPlane = false
		var blur = FxGripRealityKitCameraEffects.MotionBlur(shutter: 0.2, assumedDepth: 5.0)
		blur.maximumPixels = 64.0
		blurred.effects = .init(motionBlur: blur)

		let coder = try emptyDecoder()
		let plainTile = try makeTexture(device)
		try renderOffMain(plain, coder: coder, into: plainTile)
		let blurredTile = try makeTexture(device)
		try renderOffMain(blurred, coder: coder, into: blurredTile)

		// With no host samples the camera motion is zero, so the blur has nothing to do.
		XCTAssertEqual(pixels(of: blurredTile), pixels(of: plainTile))
		XCTAssertEqual(simd_length(blurred.receivedMotion.linearVelocity), 0.0)
	}

	func testDepthOfFieldThroughTheEffectKeepsTheFocusedBoxSharp() throws {
		let device = try metalDevice()
		let plain = try XCTUnwrap(EffectsEffect(apiManager: nil))
		plain.rendersSourceLayerPlane = false
		let focused = try XCTUnwrap(EffectsEffect(apiManager: nil))
		focused.rendersSourceLayerPlane = false
		focused.effects = .init(depthOfField: .init(focusDistance: 5.0, aperture: 4.0))

		let coder = try emptyDecoder()
		let plainTile = try makeTexture(device)
		try renderOffMain(plain, coder: coder, into: plainTile)
		let focusedTile = try makeTexture(device)
		try renderOffMain(focused, coder: coder, into: focusedTile)

		// The box sits at the focus, so its interior is untouched. The background behind it is far
		// out of focus, and the gather lets a tap within a pixel of a silhouette contribute, so the
		// only change is a one-level softening on the box's outline.
		XCTAssertEqual(pixel(focusedTile, 32, 32), pixel(plainTile, 32, 32))
		XCTAssertEqual(pixel(focusedTile, 26, 26), pixel(plainTile, 26, 26))
		let difference = zip(pixels(of: focusedTile), pixels(of: plainTile)).map { abs(Int($0) - Int($1)) }.max() ?? 0
		XCTAssertLessThanOrEqual(difference, 2, "no pixel moves more than a level")
	}

	func testDepthOfFieldThroughTheEffectBlursAnUnfocusedBox() throws {
		let device = try metalDevice()
		let plain = try XCTUnwrap(EffectsEffect(apiManager: nil))
		plain.rendersSourceLayerPlane = false
		let unfocused = try XCTUnwrap(EffectsEffect(apiManager: nil))
		unfocused.rendersSourceLayerPlane = false
		unfocused.effects = .init(depthOfField: .init(focusDistance: 50.0, aperture: 4.0))

		let coder = try emptyDecoder()
		let plainTile = try makeTexture(device)
		try renderOffMain(plain, coder: coder, into: plainTile)
		let blurredTile = try makeTexture(device)
		try renderOffMain(unfocused, coder: coder, into: blurredTile)

		XCTAssertNotEqual(pixels(of: blurredTile), pixels(of: plainTile), "the box is far from the focus and blurs")
		// The blur radius reaches past the box's edge, so the center gathers some background.
		let center = pixel(blurredTile, 32, 32)
		XCTAssertGreaterThan(center[1], 200, "the box interior stays mostly green: \(center)")
		XCTAssertLessThan(center[1], pixel(plainTile, 32, 32)[1], "and is no longer solid")
	}

	func testDepthOfFieldThroughTheEffectIsDeterministic() throws {
		let device = try metalDevice()
		let effect = try XCTUnwrap(EffectsEffect(apiManager: nil))
		effect.rendersSourceLayerPlane = false
		effect.effects = .init(depthOfField: .init(focusDistance: 50.0, aperture: 4.0))
		let coder = try emptyDecoder()
		let first = try makeTexture(device)
		try renderOffMain(effect, coder: coder, into: first)
		let second = try makeTexture(device)
		try renderOffMain(effect, coder: coder, into: second)
		XCTAssertEqual(pixels(of: first), pixels(of: second))
	}
}
