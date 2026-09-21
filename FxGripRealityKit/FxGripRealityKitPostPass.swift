/*!
	@file       FxGripRealityKitPostPass.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitPostPass
	@abstract   Camera motion blur and depth of field for the RealityKit engine, as a Metal pass over
	            the rendered tile.
	@discussion Introduced in FxGrip 0.1.0. RealityKit on macOS offers neither effect as a camera
	            component, and `RealityRenderer` publishes no depth buffer. This file declares the
	            per-frame effect settings, the camera description the pass reprojects with, and the
	            pass itself, which runs the kernels in `FxGripRealityKitPostPass.metal` over the tile.
*/

import Foundation
import Metal
import simd

/// The camera effects applied to one frame after RealityKit draws it.
///
/// Introduced in FxGrip 0.1.0. A plugin returns one of these from
/// `FxGripRealityKitEffect.cameraEffects(from:at:cameraMotion:)`. Both effects default to off.
public struct FxGripRealityKitCameraEffects: Equatable {

	/// Blur along the camera's own motion over the shutter, reprojected through the camera pose one
	/// shutter earlier.
	///
	/// Without a depth buffer the reprojection assumes every pixel lies at `assumedDepth`. Rotation
	/// blur is exact at every depth; translation blur is exact at the assumed depth and approximate
	/// elsewhere.
	public struct MotionBlur: Equatable {

		/// The exposure, in seconds. The blur spans the camera's displacement over this interval,
		/// centered on the frame. Defaults to 1/48, a 180-degree shutter at 24 frames per second.
		public var shutter: Float = 1.0 / 48.0

		/// The view depth the reprojection assumes, in world units. Nil takes the depth-of-field
		/// focus distance when one is set, and the layer distance otherwise.
		public var assumedDepth: Float? = nil

		/// Taps along the blur. Defaults to 16.
		public var sampleCount: Int = 16

		/// The longest blur, in pixels. Defaults to 64.
		public var maximumPixels: Float = 64.0

		/// Creates motion-blur settings from a shutter interval and an optional assumed depth.
		public init(shutter: Float = 1.0 / 48.0, assumedDepth: Float? = nil) {
			self.shutter = shutter
			self.assumedDepth = assumedDepth
		}
	}

	/// A thin-lens defocus driven by a depth proxy the engine renders for the frame.
	///
	/// The proxy holds one view depth per entity, the depth of its origin, so the blur is exact for
	/// an entity that lies in a plane facing the camera and approximate across one that recedes.
	/// Particle carriers are left out of the proxy and take the background depth.
	public struct DepthOfField: Equatable {

		/// The view depth in sharp focus, in world units.
		public var focusDistance: Float

		/// The lens aperture diameter, in world units. A larger aperture defocuses faster with
		/// distance from the focus.
		public var aperture: Float

		/// The widest blur radius, in pixels. Defaults to 24.
		public var maximumRadius: Float = 24.0

		/// Taps in the gather disc. Defaults to 24.
		public var sampleCount: Int = 24

		/// Creates depth-of-field settings from a focus distance and an aperture.
		public init(focusDistance: Float, aperture: Float) {
			self.focusDistance = focusDistance
			self.aperture = aperture
		}
	}

	/// The motion-blur settings, or nil to leave camera motion blur off.
	public var motionBlur: MotionBlur? = nil
	/// The depth-of-field settings, or nil to leave depth of field off.
	public var depthOfField: DepthOfField? = nil

	/// No effect on either count.
	public static let none = FxGripRealityKitCameraEffects()

	/// True when neither effect is set, which lets the engine skip the post pass entirely.
	public var isEmpty: Bool {
		return motionBlur == nil && depthOfField == nil
	}

	/// Creates a camera-effects set. Omitting both gives the same result as ``none``.
	public init(motionBlur: MotionBlur? = nil, depthOfField: DepthOfField? = nil) {
		self.motionBlur = motionBlur
		self.depthOfField = depthOfField
	}
}

/// The camera a post-pass reprojects with: the frame's projection, pose, and clip range.
///
/// Introduced in FxGrip 0.1.0. `FxGripRealityKitEffect` builds one from the decoded host state and
/// the camera motion. The pose one shutter earlier is the current pose moved back by the linear
/// velocity and turned back by the angular velocity.
public struct FxGripRealityKitPostCamera {

	/// The projection, in the Metal clip convention.
	public var projection: simd_float4x4

	/// The camera-to-world transform.
	public var cameraToWorld: simd_float4x4

	/// World units per second.
	public var linearVelocity: SIMD3<Float>

	/// Radians per second, as the rotation axis scaled by angular speed.
	public var angularVelocity: SIMD3<Float>

	/// The near clip distance.
	public var near: Float

	/// The far clip distance, which also scales the depth proxy.
	public var far: Float

	/// Creates the post-pass camera from a frame's projection, pose, motion, and clip range.
	public init(projection: simd_float4x4,
				cameraToWorld: simd_float4x4,
				linearVelocity: SIMD3<Float> = .zero,
				angularVelocity: SIMD3<Float> = .zero,
				near: Float = 0.1,
				far: Float = 1000.0) {
		self.projection = projection
		self.cameraToWorld = cameraToWorld
		self.linearVelocity = linearVelocity
		self.angularVelocity = angularVelocity
		self.near = near
		self.far = far
	}

	/// The camera-to-world transform `seconds` before the frame.
	public func cameraToWorld(secondsEarlier seconds: Float) -> simd_float4x4 {
		var earlier = cameraToWorld
		let angle = simd_length(angularVelocity) * seconds
		if angle > 1e-7 {
			let axis = simd_normalize(angularVelocity)
			let rotation = simd_float4x4(simd_quatf(angle: -angle, axis: axis))
			let position = cameraToWorld.columns.3
			var rotated = rotation * cameraToWorld
			rotated.columns.3 = position
			earlier = rotated
		}
		earlier.columns.3 -= SIMD4<Float>(linearVelocity * seconds, 0.0)
		return earlier
	}

	/// The focal length in pixels for a frame `height` pixels tall.
	public func focalPixels(forHeight height: Int) -> Float {
		return projection.columns.1.y * Float(height) * 0.5
	}
}

/// The uniforms the motion-blur kernel reads. Matches `FxGripMotionBlurUniforms` in Metal.
struct FxGripRealityKitMotionBlurUniforms {
	var inverseProjection: simd_float4x4
	var cameraToWorld: simd_float4x4
	var previousViewProjection: simd_float4x4
	var assumedDepth: Float
	var sampleCount: UInt32
	var maximumPixels: Float
	var padding: Float = 0.0
}

/// The uniforms the depth-of-field kernel reads. Matches `FxGripDepthOfFieldUniforms` in Metal.
struct FxGripRealityKitDepthOfFieldUniforms {
	var focusDistance: Float
	var aperture: Float
	var focalPixels: Float
	var farDistance: Float
	var maximumRadius: Float
	var sampleCount: UInt32
	var padding: SIMD2<Float> = .zero
}

/// Runs the camera-effect kernels over a rendered tile.
///
/// Introduced in FxGrip 0.1.0. The pass owns its pipelines and a pool of scratch textures, and is
/// safe to share across the host's concurrent renders. Each call copies the tile into scratch, runs
/// the enabled kernels, and copies the result back, so the tile's own usage flags do not matter.
/// Depth of field runs first and motion blur second.
public final class FxGripRealityKitPostPass {

	/// The Metal device the pass runs on.
	public let device: any MTLDevice

	private let queue: any MTLCommandQueue
	private let motionBlurPipeline: any MTLComputePipelineState
	private let depthOfFieldPipeline: any MTLComputePipelineState
	private let poolLock = NSLock()
	private var pool: [any MTLTexture] = []

	/// Creates the pass on `device`, compiling the kernels from the module's Metal library.
	public init(device: any MTLDevice) throws {
		self.device = device
		guard let queue = device.makeCommandQueue() else {
			throw FxGripRealityKitError.rendererUnavailable("the post-pass command queue could not be created")
		}
		self.queue = queue
		let library: any MTLLibrary
		do {
			library = try device.makeDefaultLibrary(bundle: Bundle(for: FxGripRealityKitPostPass.self))
		} catch {
			throw FxGripRealityKitError.rendererUnavailable("the post-pass Metal library is missing: \(error.localizedDescription)")
		}
		guard let blur = library.makeFunction(name: "fxgMotionBlur"),
			  let depth = library.makeFunction(name: "fxgDepthOfField") else {
			throw FxGripRealityKitError.rendererUnavailable("the post-pass kernels are missing from the Metal library")
		}
		motionBlurPipeline = try device.makeComputePipelineState(function: blur)
		depthOfFieldPipeline = try device.makeComputePipelineState(function: depth)
	}

	// MARK: - Scratch textures

	/// A private texture of the given size and format, from the pool or newly made.
	public func dequeueScratch(width: Int, height: Int, pixelFormat: MTLPixelFormat) -> (any MTLTexture)? {
		poolLock.lock()
		defer { poolLock.unlock() }
		if let index = pool.firstIndex(where: { $0.width == width && $0.height == height && $0.pixelFormat == pixelFormat }) {
			return pool.remove(at: index)
		}
		let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
																  width: width,
																  height: height,
																  mipmapped: false)
		descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
		descriptor.storageMode = .private
		return device.makeTexture(descriptor: descriptor)
	}

	/// Returns a scratch texture to the pool.
	public func enqueueScratch(_ texture: any MTLTexture) {
		poolLock.lock()
		defer { poolLock.unlock() }
		if pool.count < 8 {
			pool.append(texture)
		}
	}

	/// Clears `texture` to transparent black through a render pass, so a private texture needs no
	/// CPU access.
	public func clear(_ texture: any MTLTexture) {
		guard let buffer = queue.makeCommandBuffer() else {
			return
		}
		let pass = MTLRenderPassDescriptor()
		pass.colorAttachments[0].texture = texture
		pass.colorAttachments[0].loadAction = .clear
		pass.colorAttachments[0].storeAction = .store
		pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
		buffer.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
		buffer.commit()
		buffer.waitUntilCompleted()
	}

	// MARK: - The pass

	/// Applies `effects` to `texture` in place and waits for the GPU.
	///
	/// - Parameters:
	///   - texture: The rendered tile, read and overwritten.
	///   - effects: What to apply. An empty value returns at once.
	///   - camera: The frame's camera, for reprojection and the circle of confusion.
	///   - depthProxy: The depth proxy the engine rendered, required for depth of field. Depth of
	///     field is skipped without one.
	///   - assumedDepth: The depth motion blur assumes when its own is nil.
	public func apply(to texture: any MTLTexture,
					  effects: FxGripRealityKitCameraEffects,
					  camera: FxGripRealityKitPostCamera,
					  depthProxy: (any MTLTexture)?,
					  assumedDepth: Float) throws {
		let blur = effects.motionBlur
		let depthOfField = depthProxy == nil ? nil : effects.depthOfField
		if blur == nil && depthOfField == nil {
			return
		}
		guard let front = dequeueScratch(width: texture.width, height: texture.height, pixelFormat: texture.pixelFormat),
			  let back = dequeueScratch(width: texture.width, height: texture.height, pixelFormat: texture.pixelFormat) else {
			throw FxGripRealityKitError.renderFailed("the post-pass scratch textures could not be created")
		}
		defer {
			enqueueScratch(front)
			enqueueScratch(back)
		}
		guard let buffer = queue.makeCommandBuffer() else {
			throw FxGripRealityKitError.renderFailed("the post-pass command buffer could not be created")
		}

		var source = front
		var destination = back
		Self.copy(texture, to: source, in: buffer)

		if let depthOfField, let depthProxy {
			var uniforms = FxGripRealityKitDepthOfFieldUniforms(
				focusDistance: depthOfField.focusDistance,
				aperture: depthOfField.aperture,
				focalPixels: camera.focalPixels(forHeight: texture.height),
				farDistance: camera.far,
				maximumRadius: depthOfField.maximumRadius,
				sampleCount: UInt32(max(1, depthOfField.sampleCount)))
			try encode(depthOfFieldPipeline, source: source, destination: destination, extra: depthProxy,
					   uniforms: &uniforms, in: buffer)
			swap(&source, &destination)
		}

		if let blur {
			let earlier = camera.cameraToWorld(secondsEarlier: blur.shutter)
			var uniforms = FxGripRealityKitMotionBlurUniforms(
				inverseProjection: camera.projection.inverse,
				cameraToWorld: camera.cameraToWorld,
				previousViewProjection: camera.projection * earlier.inverse,
				assumedDepth: max(blur.assumedDepth ?? assumedDepth, camera.near),
				sampleCount: UInt32(max(1, blur.sampleCount)),
				maximumPixels: max(0.0, blur.maximumPixels))
			try encode(motionBlurPipeline, source: source, destination: destination, extra: nil,
					   uniforms: &uniforms, in: buffer)
			swap(&source, &destination)
		}

		Self.copy(source, to: texture, in: buffer)
		buffer.commit()
		buffer.waitUntilCompleted()
		if let error = buffer.error {
			throw FxGripRealityKitError.renderFailed("the post-pass failed: \(error.localizedDescription)")
		}
	}

	private func encode<Uniforms>(_ pipeline: any MTLComputePipelineState,
								  source: any MTLTexture,
								  destination: any MTLTexture,
								  extra: (any MTLTexture)?,
								  uniforms: inout Uniforms,
								  in buffer: any MTLCommandBuffer) throws {
		guard let encoder = buffer.makeComputeCommandEncoder() else {
			throw FxGripRealityKitError.renderFailed("the post-pass encoder could not be created")
		}
		encoder.setComputePipelineState(pipeline)
		encoder.setTexture(source, index: 0)
		encoder.setTexture(destination, index: 1)
		if let extra {
			encoder.setTexture(extra, index: 2)
		}
		withUnsafeBytes(of: &uniforms) { bytes in
			encoder.setBytes(bytes.baseAddress!, length: MemoryLayout<Uniforms>.stride, index: 0)
		}
		let threads = MTLSize(width: 8, height: 8, depth: 1)
		let groups = MTLSize(width: (destination.width + 7) / 8, height: (destination.height + 7) / 8, depth: 1)
		encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
		encoder.endEncoding()
	}

	private static func copy(_ source: any MTLTexture, to destination: any MTLTexture, in buffer: any MTLCommandBuffer) {
		guard let blit = buffer.makeBlitCommandEncoder() else {
			return
		}
		blit.copy(from: source,
				  sourceSlice: 0,
				  sourceLevel: 0,
				  sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
				  sourceSize: MTLSize(width: min(source.width, destination.width),
									  height: min(source.height, destination.height),
									  depth: 1),
				  to: destination,
				  destinationSlice: 0,
				  destinationLevel: 0,
				  destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
		blit.endEncoding()
	}
}
