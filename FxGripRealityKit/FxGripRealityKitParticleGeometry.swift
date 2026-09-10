/*!
	@file       FxGripRealityKitParticleGeometry.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitParticleGeometry
	@abstract   The camera-facing quads and per-particle palette that draw an FxGrip particle system.
	@discussion Introduced in FxGrip 0.1.0. RealityKit's stock materials read no per-vertex color and
	            take no per-instance data, so the particles are drawn as a `LowLevelMesh` of billboard
	            quads whose `uv0` addresses one texel of a palette texture per particle. The mesh and
	            the palette are updated in place each frame, so a warm frame allocates nothing on the
	            GPU.
*/

import AppKit
import Foundation
import FxGrip
import Metal
import RealityKit
import simd

/// The mesh and palette that draw one `FxGripRealityKitParticleSystem`.
///
/// Introduced in FxGrip 0.1.0. Each particle is one quad of four vertices facing the camera. A vertex
/// carries its position, the particle's color, the palette texel in `uv0`, and the quad corner in
/// `uv1`. The default material is unlit and reads the palette, which is the only route to a
/// per-particle color through a stock RealityKit material. A `ShaderGraphMaterial` reads the `color`
/// attribute directly, and `uv1` lets it place a sprite on the quad.
///
/// The geometry has a fixed capacity, the most quads it can hold. The engine replaces it when the
/// system's capacity grows.
@MainActor
public final class FxGripRealityKitParticleGeometry {

	/// The most particles the geometry draws.
	public let capacity: Int

	/// The mesh resource the carrying entity's model component uses. It wraps the low-level mesh, so
	/// an in-place update reaches the render without replacing the resource.
	public let meshResource: MeshResource

	/// The palette texture, one texel per particle, the default material reads through `uv0`.
	public let paletteTexture: TextureResource

	/// The unlit material that reads the palette, transparent, drawn from both sides, and without
	/// writing depth so overlapping particles do not cut into each other.
	public let defaultMaterial: UnlitMaterial

	private let mesh: LowLevelMesh
	private let palette: LowLevelTexture
	private let paletteWidth: Int
	private let paletteHeight: Int
	private let staging: any MTLBuffer
	private let queue: any MTLCommandQueue

	/// One vertex, laid out as the mesh descriptor declares. Plain floats keep the stride packed.
	private struct Vertex {
		var px: Float, py: Float, pz: Float
		var r: Float, g: Float, b: Float, a: Float
		var u0: Float, v0: Float
		var u1: Float, v1: Float
	}

	private static let vertexStride = MemoryLayout<Vertex>.stride
	private static let maxPaletteWidth = 4096

	/// Creates geometry for up to `capacity` particles. Throws when RealityKit or Metal refuses.
	public init(capacity: Int) throws {
		let quads = max(1, capacity)
		self.capacity = quads

		guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
			throw FxGripRealityKitError.rendererUnavailable("the process has no Metal device")
		}
		self.queue = queue

		var descriptor = LowLevelMesh.Descriptor()
		descriptor.vertexCapacity = quads * 4
		descriptor.indexCapacity = quads * 6
		descriptor.indexType = .uint32
		descriptor.vertexAttributes = [
			.init(semantic: .position, format: .float3, offset: 0),
			.init(semantic: .color, format: .float4, offset: MemoryLayout<Float>.stride * 3),
			.init(semantic: .uv0, format: .float2, offset: MemoryLayout<Float>.stride * 7),
			.init(semantic: .uv1, format: .float2, offset: MemoryLayout<Float>.stride * 9),
		]
		descriptor.vertexLayouts = [.init(bufferIndex: 0, bufferStride: Self.vertexStride)]
		let mesh = try LowLevelMesh(descriptor: descriptor)
		self.mesh = mesh

		// The index pattern never changes: two triangles per quad, in quad order.
		mesh.withUnsafeMutableIndices { raw in
			let indices = raw.bindMemory(to: UInt32.self)
			for quad in 0 ..< quads {
				let base = UInt32(quad * 4)
				let at = quad * 6
				indices[at] = base
				indices[at + 1] = base + 1
				indices[at + 2] = base + 2
				indices[at + 3] = base
				indices[at + 4] = base + 2
				indices[at + 5] = base + 3
			}
		}
		mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: 6, topology: .triangle,
												 bounds: BoundingBox(min: .zero, max: .zero))])
		self.meshResource = try MeshResource(from: mesh)

		let width = min(quads, Self.maxPaletteWidth)
		let height = (quads + width - 1) / width
		paletteWidth = width
		paletteHeight = height
		var textureDescriptor = LowLevelTexture.Descriptor()
		textureDescriptor.textureType = .type2D
		textureDescriptor.pixelFormat = .rgba32Float
		textureDescriptor.width = width
		textureDescriptor.height = height
		textureDescriptor.mipmapLevelCount = 1
		textureDescriptor.textureUsage = [.shaderRead, .renderTarget]
		let palette = try LowLevelTexture(descriptor: textureDescriptor)
		self.palette = palette
		self.paletteTexture = try TextureResource(from: palette)

		guard let staging = device.makeBuffer(length: width * height * MemoryLayout<SIMD4<Float>>.stride,
											  options: .storageModeShared) else {
			throw FxGripRealityKitError.rendererUnavailable("the palette staging buffer could not be created")
		}
		self.staging = staging

		var material = UnlitMaterial()
		var texture = MaterialParameters.Texture(paletteTexture)
		texture.sampler = MaterialParameters.Texture.Sampler(Self.nearestSampler())
		material.color = UnlitMaterial.BaseColor(tint: fxgRenderableColor(.white), texture: texture)
		material.blending = .transparent(opacity: 1.0)
		material.opacityThreshold = nil
		material.faceCulling = .none
		material.writesDepth = false
		self.defaultMaterial = material
	}

	private static func nearestSampler() -> MTLSamplerDescriptor {
		let sampler = MTLSamplerDescriptor()
		sampler.minFilter = .nearest
		sampler.magFilter = .nearest
		sampler.mipFilter = .notMipmapped
		sampler.sAddressMode = .clampToEdge
		sampler.tAddressMode = .clampToEdge
		return sampler
	}

	// MARK: - The frame update

	/// Rewrites the quads and the palette from the system's current state.
	///
	/// Introduced in FxGrip 0.1.0. Quads face the camera: their right and up axes are the camera's,
	/// carried into the carrying entity's space through the inverse of its world transform, so the
	/// vertices are in the same space the particles simulate in. A system with no live particles
	/// leaves one degenerate quad, which draws nothing.
	///
	/// - Parameters:
	///   - system: The particle system to draw. At most `capacity` particles are drawn.
	///   - cameraTransform: The camera's world transform.
	///   - entityTransform: The carrying entity's world transform.
	public func update(from system: FxGripRealityKitParticleSystem,
					   cameraTransform: simd_float4x4,
					   entityTransform: simd_float4x4) {
		let count = min(system.particleCount, capacity)
		let axes = entityTransform.fxgUpperLeft3x3.inverse
		let right = simd_normalize(axes * cameraTransform.columns.0.xyz)
		let up = simd_normalize(axes * cameraTransform.columns.1.xyz)

		let colors = system.renderedColors
		let sizes = system.renderedSizes
		let width = Float(paletteWidth)
		let height = Float(paletteHeight)
		var lower = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
		var upper = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

		mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
			let vertices = raw.bindMemory(to: Vertex.self)
			for index in 0 ..< max(1, count) {
				let live = index < count
				let center = live ? system.positions[index] : .zero
				let half = live ? sizes[index] * 0.5 : 0.0
				let color = live ? colors[index] : .zero
				let angle = live ? system.angles[index] : 0.0
				let c = cos(angle)
				let s = sin(angle)
				let paletteU = (Float(index % paletteWidth) + 0.5) / width
				let paletteV = (Float(index / paletteWidth) + 0.5) / height

				for corner in 0 ..< 4 {
					let cx: Float = (corner == 1 || corner == 2) ? 1.0 : -1.0
					let cy: Float = (corner >= 2) ? 1.0 : -1.0
					let rx = (cx * c - cy * s) * half
					let ry = (cx * s + cy * c) * half
					let position = center + right * rx + up * ry
					if live {
						lower = simd_min(lower, position)
						upper = simd_max(upper, position)
					}
					vertices[index * 4 + corner] = Vertex(px: position.x, py: position.y, pz: position.z,
														  r: color.x, g: color.y, b: color.z, a: color.w,
														  u0: paletteU, v0: paletteV,
														  u1: cx > 0.0 ? 1.0 : 0.0, v1: cy > 0.0 ? 1.0 : 0.0)
				}
			}
		}

		let bounds = count > 0 ? BoundingBox(min: lower, max: upper) : BoundingBox(min: .zero, max: .zero)
		mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: max(1, count) * 6,
												 topology: .triangle,
												 bounds: bounds)])

		uploadPalette(colors, count: count)
	}

	/// Copies the rendered colors into the palette through a staging buffer and one blit.
	private func uploadPalette(_ colors: [SIMD4<Float>], count: Int) {
		let texels = staging.contents().bindMemory(to: SIMD4<Float>.self, capacity: paletteWidth * paletteHeight)
		for index in 0 ..< min(count, paletteWidth * paletteHeight) {
			texels[index] = colors[index]
		}
		guard let buffer = queue.makeCommandBuffer() else {
			return
		}
		let destination = palette.replace(using: buffer)
		guard let blit = buffer.makeBlitCommandEncoder() else {
			return
		}
		let bytesPerRow = paletteWidth * MemoryLayout<SIMD4<Float>>.stride
		blit.copy(from: staging,
				  sourceOffset: 0,
				  sourceBytesPerRow: bytesPerRow,
				  sourceBytesPerImage: bytesPerRow * paletteHeight,
				  sourceSize: MTLSize(width: paletteWidth, height: paletteHeight, depth: 1),
				  to: destination,
				  destinationSlice: 0,
				  destinationLevel: 0,
				  destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
		blit.endEncoding()
		buffer.commit()
		buffer.waitUntilCompleted()
	}
}
