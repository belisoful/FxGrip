/*!
	@file       FxGripRealityKitMetalBackendTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitMetalBackendTests
	@abstract   Unit tests for the RealityKit render driver, including GPU readback and concurrency.
	@discussion Introduced in FxGrip 0.1.0. The tests render real frames and read the destination
	            texture back, which is the only way to confirm a render driver works. They skip when
	            the machine has no Metal device.
*/

import AppKit
import CoreMedia
import FxGrip
import Metal
import RealityKit
import XCTest

@testable import FxGripRealityKit

final class FxGripRealityKitMetalBackendTests: XCTestCase {

	// MARK: - Fixtures

	/// The pixel formats `FxGripMTLDeviceCache` maps FxPlug tiles onto.
	private static let tilePixelFormats: [(MTLPixelFormat, String)] = [
		(.rgba16Float, "RGBA16Float"),
		(.bgra8Unorm, "BGRA8Unorm"),
		(.rgba8Unorm, "RGBA8Unorm"),
		(.rgba16Unorm, "RGBA16Unorm"),
	]

	private func metalDevice() throws -> any MTLDevice {
		guard let device = MTLCreateSystemDefaultDevice() else {
			throw XCTSkip("No Metal device available")
		}
		return device
	}

	private func makeTexture(_ device: any MTLDevice,
							 format: MTLPixelFormat = .rgba8Unorm,
							 size: Int = 64) throws -> any MTLTexture {
		let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format,
																  width: size,
																  height: size,
																  mipmapped: false)
		descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
		descriptor.storageMode = .shared
		return try XCTUnwrap(device.makeTexture(descriptor: descriptor))
	}

	/// The pixel at the texture's center, as four 8-bit components in the texture's own channel order.
	private func centerPixel(of texture: any MTLTexture) -> [UInt8] {
		var pixel = [UInt8](repeating: 0, count: 4)
		let region = MTLRegionMake2D(texture.width / 2, texture.height / 2, 1, 1)
		texture.getBytes(&pixel, bytesPerRow: 4, from: region, mipmapLevel: 0)
		return pixel
	}

	private func fill(_ texture: any MTLTexture, with pixel: [UInt8]) {
		let count = texture.width * texture.height
		var bytes = [UInt8]()
		bytes.reserveCapacity(count * 4)
		for _ in 0 ..< count {
			bytes.append(contentsOf: pixel)
		}
		let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
		bytes.withUnsafeBytes { raw in
			texture.replace(region: region,
							mipmapLevel: 0,
							withBytes: raw.baseAddress!,
							bytesPerRow: texture.width * 4)
		}
	}

	/// A frame holding one unlit box of `color`, filling the center of the view.
	private func boxScene(_ color: NSColor, size: Float = 4.0) -> FxGripRealityKitSceneBuilder {
		return { renderer in
			let box = ModelEntity(mesh: .generateBox(size: size),
								  materials: [UnlitMaterial(color: color)])
			let camera = PerspectiveCamera()
			camera.position = SIMD3<Float>(0.0, 0.0, 5.0)
			renderer.entities.replaceAll([box, camera])
			renderer.activeCamera = camera
		}
	}

	/// Renders off the main thread, which is where the FxPlug host calls the render, and pumps the
	/// main run loop meanwhile so the driver's main-actor hop can proceed.
	private func renderOffMain(_ backend: FxGripRealityKitMetalBackend,
							   into texture: any MTLTexture,
							   atTime seconds: TimeInterval = 0.0,
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

	// MARK: - Readiness

	func testBackendReportsItsIdentityAndReadiness() throws {
		_ = try metalDevice()
		let backend = FxGripRealityKitMetalBackend()
		XCTAssertEqual(backend.backendIdentifier, "realitykit-metal")
		XCTAssertTrue(backend.isReady)
	}

	/// RealityRenderer takes no Metal device and draws on the system default, so a tile on that
	/// device is renderable and the driver says so before a frame begins.
	func testCanRenderAcceptsTheSystemDefaultDevice() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitMetalBackend()
		let texture = try makeTexture(device)
		XCTAssertTrue(backend.canRender(into: texture))
	}

	// MARK: - Drawing

	func testRendersAKnownColorIntoTheDestination() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitMetalBackend()
		let texture = try makeTexture(device)

		try renderOffMain(backend, into: texture, scene: boxScene(.red))

		let pixel = centerPixel(of: texture)
		XCTAssertGreaterThan(pixel[0], 200, "red channel: \(pixel)")
		XCTAssertLessThan(pixel[1], 60, "green channel: \(pixel)")
		XCTAssertLessThan(pixel[2], 60, "blue channel: \(pixel)")
		XCTAssertGreaterThan(pixel[3], 200, "alpha channel: \(pixel)")
	}

	/// A frame with no active camera fails rather than drawing an arbitrary view.
	func testFrameWithoutACameraFails() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitMetalBackend()
		let texture = try makeTexture(device)

		XCTAssertThrowsError(try renderOffMain(backend, into: texture) { renderer in
			let box = ModelEntity(mesh: .generateBox(size: 1.0))
			renderer.entities.replaceAll([box])
		}) { error in
			guard case FxGripRealityKitError.missingCamera = error else {
				return XCTFail("expected missingCamera, got \(error)")
			}
		}
	}

	/// An error thrown by the scene builder reaches the caller instead of being swallowed.
	func testSceneBuilderErrorPropagates() throws {
		struct Boom: Error {}
		let device = try metalDevice()
		let backend = FxGripRealityKitMetalBackend()
		let texture = try makeTexture(device)

		XCTAssertThrowsError(try renderOffMain(backend, into: texture) { _ in
			throw Boom()
		}) { error in
			XCTAssertTrue(error is Boom, "got \(error)")
		}
	}

	/// The driver leaves RealityKit's display tone map off, so a saturated color reaches the tile at
	/// full intensity. A tone-mapped render rolls the highlight off and lands below full scale.
	func testToneMappingIsOffSoSaturatedColorSurvives() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitMetalBackend()
		let texture = try makeTexture(device)

		try renderOffMain(backend, into: texture, scene: boxScene(.white))

		let pixel = centerPixel(of: texture)
		XCTAssertEqual(pixel[0], 255, "red channel rolled off: \(pixel)")
		XCTAssertEqual(pixel[1], 255, "green channel rolled off: \(pixel)")
		XCTAssertEqual(pixel[2], 255, "blue channel rolled off: \(pixel)")
	}

	// MARK: - The tile's pixel formats

	/// Every pixel format `FxGripMTLDeviceCache` produces for an FxPlug tile is a format RealityKit
	/// accepts as a render destination. RGBA16Float is the common case in a host.
	func testRendersIntoEveryTilePixelFormat() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitMetalBackend()

		for (format, name) in Self.tilePixelFormats {
			let texture = try makeTexture(device, format: format)
			XCTAssertNoThrow(try renderOffMain(backend, into: texture, scene: boxScene(.red)),
							 "format \(name) was rejected")
		}
	}

	// MARK: - Background handling

	/// The default clears the destination, so content already in the texture does not survive.
	func testClearBackgroundReplacesTheDestinationContents() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitMetalBackend()
		let texture = try makeTexture(device)
		fill(texture, with: [0, 0, 255, 255])

		// A box too small to reach the corner leaves the corner to the background.
		try renderOffMain(backend, into: texture, scene: boxScene(.red, size: 1.0))

		var corner = [UInt8](repeating: 0, count: 4)
		texture.getBytes(&corner, bytesPerRow: 4, from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0)
		XCTAssertLessThan(corner[2], 60, "the prior blue should be cleared: \(corner)")
	}

	/// Setting the flag composites the frame over what the texture already holds, which is what an
	/// effect needs when the source tile is placed before the render.
	func testPreservingDestinationContentsKeepsThePriorPixels() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitMetalBackend()
		backend.preservesDestinationContents = true
		let texture = try makeTexture(device)
		fill(texture, with: [0, 0, 255, 255])

		try renderOffMain(backend, into: texture, scene: boxScene(.red, size: 1.0))

		var corner = [UInt8](repeating: 0, count: 4)
		texture.getBytes(&corner, bytesPerRow: 4, from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0)
		XCTAssertGreaterThan(corner[2], 200, "the prior blue should survive: \(corner)")

		let center = centerPixel(of: texture)
		XCTAssertGreaterThan(center[0], 200, "the box should still draw: \(center)")
	}

	// MARK: - Concurrency

	/// The host renders frames concurrently on many threads. Each render owns the renderer for its
	/// duration, so every destination keeps the color its own frame drew.
	func testConcurrentRendersKeepTheirOwnColors() throws {
		let device = try metalDevice()
		let backend = FxGripRealityKitMetalBackend()

		let count = 16
		var textures: [any MTLTexture] = []
		for _ in 0 ..< count {
			textures.append(try makeTexture(device, size: 32))
		}

		let finished = expectation(description: "all renders finished")
		finished.expectedFulfillmentCount = count
		let failures = NSMutableArray()

		for index in 0 ..< count {
			let texture = textures[index]
			let color: NSColor = index.isMultiple(of: 2) ? .red : .green
			DispatchQueue.global().async {
				do {
					try backend.render(into: texture, atTime: 0.0, scene: self.boxScene(color))
				} catch {
					synchronized(failures) { failures.add("\(index): \(error)") }
				}
				finished.fulfill()
			}
		}
		wait(for: [finished], timeout: 300.0)
		XCTAssertEqual(failures.count, 0, "render failures: \(failures)")

		for index in 0 ..< count {
			let pixel = centerPixel(of: textures[index])
			if index.isMultiple(of: 2) {
				XCTAssertGreaterThan(pixel[0], 200, "texture \(index) should be red: \(pixel)")
				XCTAssertLessThan(pixel[1], 60, "texture \(index) should be red: \(pixel)")
			} else {
				XCTAssertGreaterThan(pixel[1], 100, "texture \(index) should be green: \(pixel)")
				XCTAssertLessThan(pixel[0], 60, "texture \(index) should be green: \(pixel)")
			}
		}
	}
}

/// Runs `body` while holding `object`'s monitor, the Swift equivalent of an `@synchronized` block.
private func synchronized<T>(_ object: AnyObject, _ body: () throws -> T) rethrows -> T {
	objc_sync_enter(object)
	defer { objc_sync_exit(object) }
	return try body()
}
