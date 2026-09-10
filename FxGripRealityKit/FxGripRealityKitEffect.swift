/*!
	@file       FxGripRealityKitEffect.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitEffect
	@abstract   The RealityKit engine subclass of the 3D Space effect base.
	@discussion Introduced in FxGrip 0.1.0. This file declares the base that a RealityKit plugin
	            subclasses. RealityKit publishes no Objective-C interface, so this engine is written
	            in Swift and reaches FxGrip through the FxGrip module.
*/

import AppKit
import CoreMedia
import Foundation
import FxGrip
import Metal
import RealityKit
import simd

/// A 3D Space effect that renders a RealityKit scene through the host camera and lights.
///
/// Introduced in FxGrip 0.1.0. `FxGripSpaceEffect` captures the host camera, the host lights, and
/// the view-matrix samples that carry camera velocity into plugin state, then hands each frame to
/// its engine subclass. This class is the RealityKit engine. `FxGripSceneKitEffect` is the SceneKit
/// engine, and the two share that base.
///
/// The engine is Swift because RealityKit is Swift. `RealityFoundation` publishes no Objective-C
/// interface, and the headers in `RealityKit.framework` are Metal shader headers. A plugin that
/// subclasses this class is therefore a Swift plugin. A plugin that needs Objective-C subclasses
/// `FxGripSceneKitEffect` instead.
///
/// The deployment floor is macOS 15, the release that introduced `RealityRenderer`, which is the
/// only offscreen render path RealityKit offers. FxGrip itself runs on macOS 13.5, so a plugin that
/// links this module raises its own floor to macOS 15.
///
/// A plugin contributes through two hooks and touches neither Metal nor the tile.
///
/// - `encodeSceneParameters(into:at:)`, inherited from the base, runs in the capture pass where the
///   host parameter APIs are valid.
/// - `updateSceneContents(_:root:camera:from:at:cameraMotion:)` runs in the render pass on the main
///   actor and adds the plugin's entities to the frame.
///
/// A plugin that already holds an authored entity returns it from `sceneTemplateEntity(at:)` instead,
/// and FxGrip clones it into every frame.
///
/// Particles are FxGrip-owned. An entity that carries an `FxGripRealityKitParticleComponent` is
/// stepped deterministically to the frame's time after the apply hook runs, under the inter-particle
/// force the base's `particleInteraction` and `particleInteractionFields` describe, and drawn through
/// `FxGripRealityKitParticleGeometry`. RealityKit's own `ParticleEmitterComponent` still renders, but
/// it has no seed and no per-particle state, so it neither reproduces a frame nor carries a force.
///
/// Camera motion blur and depth of field are a Metal pass over the drawn tile, because RealityKit
/// on macOS has neither as a camera component. A plugin turns them on by returning settings from
/// `cameraEffects(from:at:cameraMotion:)`.
@objc(FxGripRealityKitEffect)
open class FxGripRealityKitEffect: FxGripSpaceEffect {

	/// Guards `storedBackend` against the host's concurrent renders.
	private let backendLock = NSLock()
	private var storedBackend: (any FxGripRealityKitBackend)?

	/// The driver that renders the frame into the tile.
	///
	/// Introduced in FxGrip 0.1.0. Defaults to `defaultRealityBackend()`. The driver is shared across
	/// concurrent renders and serializes internally.
	open var realityBackend: any FxGripRealityKitBackend {
		get {
			backendLock.lock()
			defer { backendLock.unlock() }
			if let storedBackend {
				return storedBackend
			}
			let created = defaultRealityBackend()
			storedBackend = created
			return created
		}
		set {
			backendLock.lock()
			defer { backendLock.unlock() }
			storedBackend = newValue
			userSetBackend = true
		}
	}

	/// The driver used when none is set. A subclass overrides it to change the default engine.
	///
	/// Introduced in FxGrip 0.1.0. Defaults to an `FxGripRealityKitMetalBackend`, or to an
	/// `FxGripRealityKitPhysicsBackend` when `physicsBakeEnabled` is set.
	open func defaultRealityBackend() -> any FxGripRealityKitBackend {
		if physicsBakeEnabled {
			let backend = FxGripRealityKitPhysicsBackend()
			backend.simulationMode = .sessionCache
			return backend
		}
		return FxGripRealityKitMetalBackend()
	}

	/// Whether the plugin installed its own driver, which the bake flag must never replace.
	private var userSetBackend = false

	/// Runs a deterministic physics simulation and persists the bake with the document.
	///
	/// Introduced in FxGrip 0.1.0. Defaults to false. Set it at setup, before rendering. When set,
	/// `defaultRealityBackend()` becomes an `FxGripRealityKitPhysicsBackend` in session-cache mode,
	/// and the effect loads an `FxGripPhysicsBake` extension that backs the driver's store with the
	/// document, so the simulation fills lazily as frames render and survives a reopen. A driver the
	/// plugin installed itself is left in place.
	open var physicsBakeEnabled: Bool = false {
		didSet {
			guard physicsBakeEnabled != oldValue else {
				return
			}
			backendLock.lock()
			let replace = !userSetBackend
			if replace {
				storedBackend = nil
			}
			backendLock.unlock()
		}
	}

	/// Backs the physics driver with the store and switches it to session-cache mode.
	///
	/// Introduced in FxGrip 0.1.0. Returns false when the installed driver does not simulate, which
	/// leaves the bake inert. `FxGripPhysicsBake` calls this when it loads.
	open override func installPhysicsSimulationStore(_ store: any FxGripPhysicsSimulationStore) -> Bool {
		guard let physics = realityBackend as? FxGripRealityKitPhysicsBackend else {
			return false
		}
		physics.simulationStore = store
		physics.simulationMode = .sessionCache
		return true
	}

	/// Adds the physics-bake extension to the loaded set when `physicsBakeEnabled` is set.
	open override func loadExtensions() -> NSMutableArray? {
		let extensions = super.loadExtensions() ?? NSMutableArray()
		if physicsBakeEnabled {
			extensions.add(newPhysicsBakeExtension())
		}
		return extensions
	}

	// MARK: - The render seam

	/// Builds the frame from plugin state and draws it into the destination tile.
	///
	/// Introduced in FxGrip 0.1.0. A driver that is not ready, or that cannot reach the tile's Metal
	/// device, falls through to the base, which copies the source unchanged. A driver failure becomes
	/// an `NSError` in the host's error domain, through the base's `spaceError(reason:)`.
	open override func renderScene(from coder: NSCoder,
								   sourceTile: FxImageTile?,
								   to texture: any MTLTexture,
								   at renderTime: CMTime) throws {
		let backend = realityBackend
		guard backend.isReady, backend.canRender(into: texture) else {
			try super.renderScene(from: coder, sourceTile: sourceTile, to: texture, at: renderTime)
			return
		}

		let seconds = CMTimeGetSeconds(renderTime)
		let motion = cameraMotion(from: coder)
		let effects = cameraEffects(from: coder, at: renderTime, cameraMotion: motion)
		do {
			try backend.render(into: texture, atTime: seconds) { renderer in
				try self.buildFrame(renderer, from: coder, sourceTile: sourceTile, at: renderTime)
			}
			if !effects.isEmpty {
				try applyCameraEffects(effects, to: texture, from: coder, at: renderTime, cameraMotion: motion)
			}
		} catch {
			throw self.spaceError(withReason: error.localizedDescription)
		}
	}

	/// Assembles one frame's entities in the renderer, from the decoded plugin state.
	///
	/// Introduced in FxGrip 0.1.0. Everything hangs off a single root, which is the one entity the
	/// renderer's collection holds, so a plugin sees a scene graph shaped like SceneKit's. The frame
	/// is rebuilt from the coder on every render and shares nothing with the render before it.
	@MainActor
	private func buildFrame(_ renderer: RealityRenderer,
							from coder: NSCoder,
							sourceTile: FxImageTile?,
							at renderTime: CMTime,
							depthProxy: FxGripRealityKitPostCamera? = nil) throws {
		let root = Entity()
		root.name = FxGripRealityKitEntityName.root

		let camera = Entity.fxgHostCamera(projection: decodedProjection(from: coder),
										  frustum: decodedFrustum(from: coder),
										  transform: decodedCameraTransform(from: coder))
		root.addChild(camera)

		for light in decodedLights(from: coder) {
			root.addChild(light)
		}

		if rendersSourceLayerPlane, let sourceTile {
			if let plane = try layerPlane(for: sourceTile, from: coder) {
				root.addChild(plane)
			}
		}

		if let template = sceneTemplateEntity(at: renderTime) {
			// Cloning is what gives each frame its own copy, the way decoding an archive does for
			// the SceneKit engine. RealityKit entities carry no NSSecureCoding.
			let copy = template.clone(recursive: true)
			copy.name = FxGripRealityKitEntityName.template
			root.addChild(copy)
		}

		renderer.entities.replaceAll([root])
		renderer.activeCamera = camera

		updateSceneContents(renderer,
							root: root,
							camera: camera,
							from: coder,
							at: renderTime,
							cameraMotion: cameraMotion(from: coder))

		try updateParticleSystems(in: root, camera: camera, from: coder, at: CMTimeGetSeconds(renderTime))

		if let depthProxy {
			encodeDepthProxy(in: root, camera: depthProxy)
		}
	}

	// MARK: - Plugin seams

	/// Adds the plugin's entities to the frame. The default does nothing.
	///
	/// Introduced in FxGrip 0.1.0. FxGrip has already added the camera, the lights, and the source
	/// layer plane under `root`, and has set `camera` as the frame's active camera. A subclass adds
	/// its own entities as children of `root`, reads its parameters back from `coder`, and adjusts
	/// `camera` when it needs to. The frame is exclusive to this render, so entities are created here
	/// while meshes and materials are cached on the plugin and reused.
	///
	/// The hook runs on the main actor, because RealityKit's scene graph is main-actor isolated.
	/// `renderer` is supplied for the frame-wide settings a plugin may need, such as image-based
	/// lighting.
	@MainActor
	open func updateSceneContents(_ renderer: RealityRenderer,
								  root: Entity,
								  camera: Entity,
								  from coder: NSCoder,
								  at renderTime: CMTime,
								  cameraMotion: FxGripCameraMotion) {
	}

	/// An authored entity FxGrip clones into every frame. The default returns nil.
	///
	/// Introduced in FxGrip 0.1.0. A subclass returns a subtree of its own content, without the camera
	/// or lights, to have FxGrip add an independent copy to each frame. The apply hook still runs
	/// afterward, so a static template combines with per-frame adjustments found by name on the copy.
	///
	/// The SceneKit engine archives its template into plugin state, because `SCNNode` conforms to
	/// `NSSecureCoding`. A RealityKit `Entity` does not, so the template is held on the effect and
	/// cloned instead. Cloning happens inside the driver's render lock, so a shared template is safe
	/// under the host's concurrent rendering.
	@MainActor
	open func sceneTemplateEntity(at renderTime: CMTime) -> Entity? {
		return nil
	}

	// MARK: - Camera effects

	/// The motion blur and depth of field applied to the frame after RealityKit draws it. The
	/// default applies neither.
	///
	/// Introduced in FxGrip 0.1.0. RealityKit on macOS has no motion-blur or depth-of-field camera
	/// component, so the engine applies both as a Metal pass over the tile. A subclass returns the
	/// settings for the frame, reading its own parameters from `coder`. `cameraMotion` is the camera's
	/// linear and angular velocity, and `autofocusDistance(from:)` is the distance to the layer, so
	/// the two host-derived quantities the SceneKit engine feeds its camera reach the same seam here.
	///
	/// Depth of field costs a second frame, drawn as a depth proxy with one view depth per entity.
	open func cameraEffects(from coder: NSCoder,
							at renderTime: CMTime,
							cameraMotion: FxGripCameraMotion) -> FxGripRealityKitCameraEffects {
		return .none
	}

	/// The autofocus distance: from the host camera to the host layer's origin, in world units.
	///
	/// Introduced in FxGrip 0.1.0. Returns nil when the coder holds no camera or no layer transform.
	/// The SceneKit engine's plugins compute the same distance with `FxGripFocusDistance`.
	open func autofocusDistance(from coder: NSCoder) -> Float? {
		guard let camera = decodedCameraTransform(from: coder),
			  let layer = decodedLayerTransform(from: coder) else {
			return nil
		}
		return FxGripFocusDistance(FxGripTransformPosition(camera), FxGripTransformPosition(layer))
	}

	/// The post-pass, created on first use for the tile's device and shared across renders.
	private let postPassLock = NSLock()
	private var storedPostPass: FxGripRealityKitPostPass?

	/// The post-pass for `device`, created once.
	open func postPass(for device: any MTLDevice) throws -> FxGripRealityKitPostPass {
		postPassLock.lock()
		defer { postPassLock.unlock() }
		if let pass = storedPostPass, pass.device.registryID == device.registryID {
			return pass
		}
		let pass = try FxGripRealityKitPostPass(device: device)
		storedPostPass = pass
		return pass
	}

	/// Renders the depth proxy when depth of field is on, then runs the pass over the tile.
	private func applyCameraEffects(_ effects: FxGripRealityKitCameraEffects,
									to texture: any MTLTexture,
									from coder: NSCoder,
									at renderTime: CMTime,
									cameraMotion: FxGripCameraMotion) throws {
		let pass = try postPass(for: texture.device)
		let camera = postCamera(from: coder, cameraMotion: cameraMotion)
		let autofocus = autofocusDistance(from: coder)
		let assumedDepth = effects.depthOfField?.focusDistance ?? autofocus ?? camera.far * 0.5

		var proxy: (any MTLTexture)? = nil
		if effects.depthOfField != nil {
			guard let scratch = pass.dequeueScratch(width: texture.width, height: texture.height, pixelFormat: .rgba32Float) else {
				throw FxGripRealityKitError.renderFailed("the depth proxy could not be created")
			}
			proxy = scratch
			pass.clear(scratch)
			try realityBackend.render(into: scratch, atTime: CMTimeGetSeconds(renderTime)) { renderer in
				try self.buildFrame(renderer, from: coder, sourceTile: nil, at: renderTime, depthProxy: camera)
			}
		}
		defer {
			if let proxy {
				pass.enqueueScratch(proxy)
			}
		}
		try pass.apply(to: texture, effects: effects, camera: camera, depthProxy: proxy, assumedDepth: assumedDepth)
	}

	/// The frame's camera for the pass, from the decoded host state. A frame without a host camera
	/// gets RealityKit's default perspective at the origin.
	private func postCamera(from coder: NSCoder, cameraMotion: FxGripCameraMotion) -> FxGripRealityKitPostCamera {
		let frustum = decodedFrustum(from: coder)
		let near = Float(frustum?.near ?? 0.1)
		let far = Float(frustum?.far ?? 1000.0)
		let projection = decodedProjection(from: coder)
			?? Self.perspective(verticalFieldOfView: Float(frustum?.verticalFieldOfViewInDegrees ?? 60.0),
								aspect: 1.0, near: near, far: far)
		return FxGripRealityKitPostCamera(projection: projection,
										  cameraToWorld: decodedCameraTransform(from: coder) ?? matrix_identity_float4x4,
										  linearVelocity: cameraMotion.linearVelocity,
										  angularVelocity: cameraMotion.angularVelocity,
										  near: near,
										  far: far)
	}

	/// A Metal-convention perspective projection, depth in [0, 1].
	static func perspective(verticalFieldOfView degrees: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
		let y = 1.0 / tan(degrees * .pi / 360.0)
		let x = y / aspect
		let z = far / (near - far)
		return simd_float4x4(columns: (SIMD4<Float>(x, 0.0, 0.0, 0.0),
									   SIMD4<Float>(0.0, y, 0.0, 0.0),
									   SIMD4<Float>(0.0, 0.0, z, -1.0),
									   SIMD4<Float>(0.0, 0.0, z * near, 0.0)))
	}

	/// Replaces every model's materials with a flat tint that encodes its origin's view depth.
	///
	/// The tint is the depth over the far distance, written in sRGB so RealityKit's linearization
	/// hands the kernel the linear fraction. A particle carrier loses its model and takes the
	/// background depth, because its palette texture would multiply the tint.
	@MainActor
	private func encodeDepthProxy(in root: Entity, camera: FxGripRealityKitPostCamera) {
		let worldToCamera = camera.cameraToWorld.inverse
		var stack: [Entity] = [root]
		while let entity = stack.popLast() {
			stack.append(contentsOf: entity.children)
			guard var model = entity.components[ModelComponent.self] else {
				continue
			}
			if entity.components[FxGripRealityKitParticleComponent.self] != nil {
				entity.components.remove(ModelComponent.self)
				continue
			}
			let origin = entity.transformMatrix(relativeTo: nil).columns.3
			let depth = -(worldToCamera * origin).z
			let fraction = min(max(depth / camera.far, 0.0), 1.0)
			let encoded = CGFloat(Self.sRGBEncoded(fraction))
			var material = UnlitMaterial(color: NSColor(srgbRed: encoded, green: encoded, blue: encoded, alpha: 1.0))
			material.blending = .opaque
			model.materials = [any Material](repeating: material, count: max(1, model.materials.count))
			entity.components.set(model)
		}
	}

	/// The sRGB transfer of a linear value, so a tint decodes to that linear value.
	static func sRGBEncoded(_ linear: Float) -> Float {
		if linear <= 0.0031308 {
			return linear * 12.92
		}
		return 1.055 * pow(linear, 1.0 / 2.4) - 0.055
	}

	// MARK: - Particles

	/// Steps every FxGrip particle system in the frame to the render time and installs its geometry.
	///
	/// Introduced in FxGrip 0.1.0. Runs after the apply hook, so a carrier the hook created is
	/// stepped along with one cloned from the template. The effect's inter-particle configuration is
	/// applied here, the way the SceneKit engine applies it to a scene.
	///
	/// - A field the effect declares covers the carriers in the named entity's subtree, and those
	///   carriers share one force evaluated in world space.
	/// - A carrier outside every field runs under its system's own interaction, or under the
	///   scene-wide default when it has none, in its own space.
	/// - A carrier inside a field whose system carries its own interaction keeps its own.
	///
	/// Fields install in name order, so a carrier under two named entities goes to the first.
	@MainActor
	private func updateParticleSystems(in root: Entity, camera: Entity, from coder: NSCoder, at seconds: TimeInterval) throws {
		let carriers = particleCarriers(in: root)
		if carriers.isEmpty {
			return
		}

		var fields: [FxGripRealityKitParticleField] = []
		var claimed = Set<ObjectIdentifier>()

		if let configurations = decodeParticleInteractionFields(from: coder) {
			for name in configurations.keys.sorted() {
				guard let owner = root.name == name ? root : root.findEntity(named: name) else {
					continue
				}
				let members = carriers.filter { carrier in
					guard !claimed.contains(ObjectIdentifier(carrier)),
						  let system = carrier.fxgParticleSystem,
						  system.particleInteraction == nil else {
						return false
					}
					return carrier.fxgIsSelfOrDescendant(of: owner)
				}
				if members.isEmpty {
					continue
				}
				let field = FxGripRealityKitParticleField(interaction: configurations[name])
				field.members = members.compactMap { carrier in
					guard let system = carrier.fxgParticleSystem else {
						return nil
					}
					claimed.insert(ObjectIdentifier(carrier))
					return FxGripRealityKitParticleField.Member(system: system,
																transform: carrier.transformMatrix(relativeTo: nil))
				}
				fields.append(field)
			}
		}

		let sceneDefault = decodeParticleInteraction(from: coder)
		for carrier in carriers where !claimed.contains(ObjectIdentifier(carrier)) {
			guard let system = carrier.fxgParticleSystem else {
				continue
			}
			let field = FxGripRealityKitParticleField(interaction: system.particleInteraction ?? sceneDefault)
			field.members = [FxGripRealityKitParticleField.Member(system: system)]
			fields.append(field)
		}

		for field in fields {
			field.advance(to: seconds)
		}

		let cameraTransform = camera.transformMatrix(relativeTo: nil)
		for carrier in carriers {
			guard let system = carrier.fxgParticleSystem else {
				continue
			}
			let geometry = try particleGeometry(for: system)
			geometry.update(from: system,
							cameraTransform: cameraTransform,
							entityTransform: carrier.transformMatrix(relativeTo: nil))
			carrier.components.set(ModelComponent(mesh: geometry.meshResource,
												  materials: [system.material ?? geometry.defaultMaterial]))
		}
	}

	/// Every carrier under `root`, in traversal order, which is the order fields concatenate them.
	@MainActor
	private func particleCarriers(in root: Entity) -> [Entity] {
		var found: [Entity] = []
		collectParticleCarriers(root, into: &found)
		return found
	}

	@MainActor
	private func collectParticleCarriers(_ entity: Entity, into found: inout [Entity]) {
		if entity.components[FxGripRealityKitParticleComponent.self] != nil {
			found.append(entity)
		}
		for child in entity.children {
			collectParticleCarriers(child, into: &found)
		}
	}

	/// The system's geometry, created on first use and replaced when its capacity is outgrown.
	@MainActor
	private func particleGeometry(for system: FxGripRealityKitParticleSystem) throws -> FxGripRealityKitParticleGeometry {
		if let geometry = system.geometry, geometry.capacity >= system.capacity {
			return geometry
		}
		let geometry = try FxGripRealityKitParticleGeometry(capacity: system.capacity)
		system.geometry = geometry
		return geometry
	}

	// MARK: - Decoding

	private func decodedProjection(from coder: NSCoder) -> simd_float4x4? {
		var matrix = matrix_identity_float4x4
		return decodeProjectionMatrix(&matrix, from: coder) ? matrix : nil
	}

	private func decodedCameraTransform(from coder: NSCoder) -> simd_float4x4? {
		var transform = matrix_identity_float4x4
		return decodeCameraTransform(&transform, from: coder) ? transform : nil
	}

	private func decodedLayerTransform(from coder: NSCoder) -> simd_float4x4? {
		var transform = matrix_identity_float4x4
		return decodeLayerTransform(&transform, from: coder) ? transform : nil
	}

	private func decodedFrustum(from coder: NSCoder) -> FxGripHostFrustum? {
		let frustum = FxGripHostFrustum(left: coder.decodeFx3DFrustumLeft(),
										right: coder.decodeFx3DFrustumRight(),
										bottom: coder.decodeFx3DFrustumBottom(),
										top: coder.decodeFx3DFrustumTop(),
										near: coder.decodeFx3DFrustumNear(),
										far: coder.decodeFx3DFrustumFar())
		return frustum.isUsable ? frustum : nil
	}

	@MainActor
	private func decodedLights(from coder: NSCoder) -> [Entity] {
		var lights: [Entity] = []
		let count = coder.decodeFxLightCount()
		for index in 0 ..< max(0, count) {
			var light = FxLight()
			if coder.decode(&light, index: index), let entity = Entity.fxgLight(from: light) {
				lights.append(entity)
			}
		}
		return lights
	}

	// MARK: - The source layer plane

	/// Wraps the source tile's Metal texture as a RealityKit texture and builds the layer plane.
	///
	/// Introduced in FxGrip 0.1.0. RealityKit accepts no Metal texture directly, so the tile is
	/// copied into a `LowLevelTexture`, which a `TextureResource` then wraps. The copy is a GPU blit
	/// on a pooled queue from `FxGripMTLDeviceCache`.
	@MainActor
	private func layerPlane(for sourceTile: FxImageTile, from coder: NSCoder) throws -> ModelEntity? {
		guard let device = MTLCreateSystemDefaultDevice(),
			  let source = sourceTile.metalTexture(for: device) else {
			return nil
		}
		guard let resource = try textureResource(from: source, tile: sourceTile) else {
			return nil
		}
		return Entity.fxgLayerPlane(texture: resource, transform: decodedLayerTransform(from: coder))
	}

	@MainActor
	private func textureResource(from source: any MTLTexture, tile: FxImageTile) throws -> TextureResource? {
		var descriptor = LowLevelTexture.Descriptor()
		descriptor.textureType = .type2D
		descriptor.pixelFormat = source.pixelFormat
		descriptor.width = source.width
		descriptor.height = source.height
		descriptor.mipmapLevelCount = 1
		descriptor.textureUsage = [.shaderRead, .renderTarget]

		let lowLevel = try LowLevelTexture(descriptor: descriptor)

		guard let queue = FxGripMTLDeviceCache.commandQueue(for: tile) ?? source.device.makeCommandQueue(),
			  let buffer = queue.makeCommandBuffer() else {
			return nil
		}
		let destination = lowLevel.replace(using: buffer)
		guard let blit = buffer.makeBlitCommandEncoder() else {
			return nil
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
		buffer.commit()
		buffer.waitUntilCompleted()

		return try TextureResource(from: lowLevel)
	}
}
