/*!
	@file       FxGripRealityKitEffectTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitEffectTests
	@abstract   Unit tests for the RealityKit engine subclass and its render environment.
	@discussion Introduced in FxGrip 0.1.0. These tests run without an FxPlug host, in the pattern the
	            Objective-C Space tests use, and confirm that the Swift module reaches the FxGrip base
	            and that RealityKit renders offscreen in a headless process.
*/

import CoreMedia
import FxGrip
import Metal
import RealityKit
import XCTest

@testable import FxGripRealityKit

final class FxGripRealityKitEffectTests: XCTestCase {

	/// The effect constructs without a host, the way the Objective-C Space tests construct theirs.
	func testEffectInstantiatesWithoutAHost() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		XCTAssertTrue(effect.isKind(of: FxGripSpaceEffect.self))
	}

	/// The engine inherits the base's source-layer-plane default.
	func testEffectInheritsTheBaseDefaults() throws {
		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		XCTAssertTrue(effect.rendersSourceLayerPlane)
	}

	/// With no engine render driver installed, the inherited render succeeds and leaves the
	/// destination untouched, which is the passthrough the base defines for an absent source.
	func testInheritedRenderSucceedsWithNoSource() throws {
		guard let device = MTLCreateSystemDefaultDevice() else {
			throw XCTSkip("No Metal device available")
		}
		let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
																  width: 16,
																  height: 16,
																  mipmapped: false)
		descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
		let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))

		let effect = try XCTUnwrap(FxGripRealityKitEffect(apiManager: nil))
		let coder = NSKeyedArchiver(requiringSecureCoding: false)
		XCTAssertNoThrow(try effect.renderScene(from: coder,
												sourceTile: nil,
												to: texture,
												at: CMTime.zero))
	}

	/// RealityKit's only offscreen renderer constructs in a headless test process, which is the
	/// environment an FxPlug plugin renders in.
	@MainActor
	func testRealityRendererConstructsHeadless() throws {
		XCTAssertNoThrow(try RealityRenderer())
	}
}
