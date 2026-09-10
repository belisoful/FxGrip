/*!
	@file       FxGripSceneKitEffect.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSceneKitEffect
	@abstract   Implements the SceneKit 3D Space effect template.
	@discussion Introduced in FxGrip 0.1.0. The capture pass adds any archived scene template to the
	            host state the base encodes. The render pass decodes that state, builds an independent
	            SceneKit scene with a camera node, a lights container, an optional source layer plane,
	            and any authored template, then draws it through the space backend. The template holds
	            no scene state, so concurrent renders never share a scene.
*/

#import "FxGripSceneKitEffect.h"
#import "SCNScene+FxGripInteraction.h"
#import "SCNPhysicsField+FxGripInteraction.h"
#import "SCNParticleSystem+FxGripInteraction.h"
#import "FxGripSceneKitMetalBackend.h"
#import "FxGripSceneKitPhysicsBackend.h"
#import "FxGripPhysicsBake.h"
#import "SCNCamera+FxGrip.h"
#import "SCNLight+FxGrip.h"
#import "NSCoder+FxPlug.h"
#import "FxTileImage+FxGrip.h"
#import "FxGrip_ARC.h"

// The archived scene-template node.
static NSString * const FxGripSceneKitCoderTemplateKey = @"_fxspace_template";

/*!
	@abstract	A tileable-effect template that renders a SceneKit scene through the host 3D camera and lights.
	@discussion	Introduced in FxGrip 0.1.0. The template holds no per-frame scene state and builds a fresh
				scene on each render. A versioned lock-guarded cache archives a static scene template once.
*/
@implementation FxGripSceneKitEffect
{
	id<FxGripSceneKitBackend> _spaceBackend;
	BOOL _userSetBackend;

	// Versioned cache of the archived scene template, so a static template serializes once.
	NSLock *_templateLock;
	NSData *_cachedTemplateData;
	NSInteger _cachedTemplateVersion;
	BOOL _hasCachedTemplate;
}

- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	self = [super initWithAPIManager:apiManager];
	if (self != nil) {
		_spaceBackend = NARC_RETAIN([self defaultSpaceBackend]);
		_templateLock = [[NSLock alloc] init];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_spaceBackend);
	NARC_RELEASE(_templateLock);
	NARC_RELEASE(_cachedTemplateData);
	SUPER_DEALLOC();
}

#pragma mark Backend

// The backend is set at setup, not per frame, and the getter never mutates, so concurrent renders
// read a stable, thread-safe backend.
- (id<FxGripSceneKitBackend>)spaceBackend
{
	return _spaceBackend;
}

/*! @abstract The backend used when none is set: a physics backend when physicsBakeEnabled, otherwise the Metal backend. */
- (id<FxGripSceneKitBackend>)defaultSpaceBackend
{
	if (self.physicsBakeEnabled) {
		return [FxGripSceneKitPhysicsBackend backend];
	}
	return [FxGripSceneKitMetalBackend backend];
}

/*! @abstract Sets the render backend, recording that the plugin set it; nil restores the default backend. */
- (void)setSpaceBackend:(nullable id<FxGripSceneKitBackend>)spaceBackend
{
	_userSetBackend = (spaceBackend != nil);
	id<FxGripSceneKitBackend> replacement = spaceBackend ?: [self defaultSpaceBackend];
	if (_spaceBackend != replacement) {
		NARC_RELEASE(_spaceBackend);
		_spaceBackend = NARC_RETAIN(replacement);
	}
}

/*! @abstract Toggles the physics bake and refreshes the default backend, leaving a plugin-set backend in place. */
- (void)setPhysicsBakeEnabled:(BOOL)physicsBakeEnabled
{
	if (_physicsBakeEnabled == physicsBakeEnabled) {
		return;
	}
	_physicsBakeEnabled = physicsBakeEnabled;
	// Refresh the default backend to match, but never replace one the plugin set itself.
	if (!_userSetBackend) {
		NARC_RELEASE(_spaceBackend);
		_spaceBackend = NARC_RETAIN([self defaultSpaceBackend]);
	}
}

/*!
	@method		installPhysicsSimulationStore:
	@abstract	Backs the SceneKit physics backend with the store and switches it to session-cache mode.
	@discussion	Introduced in FxGrip 0.1.0. Returns NO when the installed backend does not simulate,
				which leaves the bake inert. */
- (BOOL)installPhysicsSimulationStore:(id<FxGripPhysicsSimulationStore>)store
{
	if (![self.spaceBackend isKindOfClass:FxGripSceneKitPhysicsBackend.class]) {
		return NO;
	}
	FxGripSceneKitPhysicsBackend *backend = (FxGripSceneKitPhysicsBackend *)self.spaceBackend;
	backend.simulationStore = store;
	backend.simulationMode = FxGripPhysicsSimulationModeSessionCache;
	return YES;
}

/*! @abstract Adds the physics-bake extension to the loaded set when physicsBakeEnabled. */
- (NSMutableArray<id<FxGripExtension>> *)loadExtensions
{
	NSMutableArray<id<FxGripExtension>> *extensions = [super loadExtensions];
	if (self.physicsBakeEnabled) {
		[extensions addObject:(id<FxGripExtension>)[self newPhysicsBakeExtension]];
	}
	return extensions;
}

#pragma mark Capture (state pass)

/*! @abstract Archives the scene template, when a subclass supplies one, into plugin state. */
- (BOOL)encodeEngineStateIntoCoder:(NSCoder *)coder
							atTime:(CMTime)renderTime
							 error:(NSError * _Nullable *)error
{
	SCNNode *templateNode = [self sceneTemplateNodeAtTime:renderTime];
	if (templateNode != nil) {
		NSData *archived = [self archivedTemplateForNode:templateNode];
		if (archived != nil) {
			[coder encodeObject:archived forKey:FxGripSceneKitCoderTemplateKey];
		}
	}
	return YES;
}

/*! @abstract The default authored-template hook, returning nil; a subclass returns a node subtree to archive. */
- (nullable SCNNode *)sceneTemplateNodeAtTime:(CMTime)renderTime
{
	return nil;
}

/*! @abstract The default scene-template revision, 0; a subclass returns a larger value after mutating the template. */
- (NSInteger)sceneTemplateVersion
{
	return 0;
}

/*! @abstract The cached secure-coding archive of the scene template, re-archived only when the version changes. */
- (nullable NSData *)archivedTemplateForNode:(SCNNode *)node
{
	NSInteger version = [self sceneTemplateVersion];

	[_templateLock lock];
	if (!_hasCachedTemplate || version != _cachedTemplateVersion) {
		NSError *error = nil;
		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:node requiringSecureCoding:YES error:&error];
		if (data != nil) {
			NARC_RELEASE(_cachedTemplateData);
			_cachedTemplateData = NARC_RETAIN(data);
			_cachedTemplateVersion = version;
			_hasCachedTemplate = YES;
		} else {
			NSLog(@"%s Error: could not archive the scene template. %@", __func__, error);
		}
	}
	NSData *result = NARC_RETAIN_AUTORELEASE(_cachedTemplateData);
	[_templateLock unlock];
	return result;
}

#pragma mark Render

/*!
	@method		renderSceneFromCoder:sourceTile:toTexture:atTime:error:
	@abstract	Builds the per-render scene from plugin state and draws it through the backend.
	@discussion	Introduced in FxGrip 0.1.0. When the backend is not ready the base passthrough copies
				the source unchanged. Otherwise the scene is built and drawn through the backend at
				the render time in seconds. */
- (BOOL)renderSceneFromCoder:(NSCoder *)coder
				  sourceTile:(nullable FxImageTile *)sourceTile
				   toTexture:(id<MTLTexture>)texture
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)outError
{
	id<FxGripSceneKitBackend> backend = self.spaceBackend;
	if (!backend.isReady) {
		return [super renderSceneFromCoder:coder sourceTile:sourceTile toTexture:texture atTime:renderTime error:outError];
	}

	SCNNode *pointOfView = nil;
	SCNScene *scene = [self buildSceneWithCoder:coder
									 sourceTile:sourceTile
										 atTime:renderTime
									pointOfView:&pointOfView];

	CFTimeInterval seconds = CMTIME_IS_VALID(renderTime) ? CMTimeGetSeconds(renderTime) : 0.0;
	return [backend renderScene:scene
					pointOfView:pointOfView
					  toTexture:texture
						 atTime:seconds
						  error:outError];
}

#pragma mark Per-render scene construction

/*!
	@method		buildSceneWithCoder:sourceTile:atTime:pointOfView:
	@abstract	Builds a fresh scene from the decoded plugin state and returns its camera as the point of view.
	@discussion	Introduced in FxGrip 0.1.0. Adds a configured camera node, a lights container, an optional
				source layer plane, and any authored template, computes camera motion, then calls
				updateSceneContents:cameraNode:fromCoder:atTime:cameraMotion:. Each call returns an
				independent scene. */
- (SCNScene *)buildSceneWithCoder:(NSCoder *)coder
					   sourceTile:(nullable FxImageTile *)sourceTile
						   atTime:(CMTime)renderTime
					  pointOfView:(SCNNode * _Nullable * _Nullable)outPointOfView
{
	SCNScene *scene = [SCNScene scene];

	SCNNode *cameraNode = [SCNNode node];
	[self configureCameraNode:cameraNode withCoder:coder];
	[scene.rootNode addChildNode:cameraNode];

	SCNNode *lightsNode = [SCNNode node];
	[self addLightsToNode:lightsNode fromCoder:coder];
	[scene.rootNode addChildNode:lightsNode];

	if (self.rendersSourceLayerPlane) {
		SCNNode *plane = [self layerPlaneNodeWithCoder:coder sourceTile:sourceTile];
		if (plane != nil) {
			[scene.rootNode addChildNode:plane];
		}
	}

	SCNNode *templateContent = [self templateContentFromCoder:coder];
	if (templateContent != nil) {
		[scene.rootNode addChildNode:templateContent];
	}

	FxGripCameraMotion motion = [self cameraMotionFromCoder:coder];
	[self updateSceneContents:scene cameraNode:cameraNode fromCoder:coder atTime:renderTime cameraMotion:motion];
	[self applyParticleInteractionToScene:scene fromCoder:coder];

	if (outPointOfView != NULL) {
		*outPointOfView = cameraNode;
	}
	return scene;
}

/*! @abstract The default scene-content hook, a no-op; a subclass adds its own nodes to the per-render scene. */
- (void)updateSceneContents:(SCNScene *)scene
				 cameraNode:(SCNNode *)cameraNode
				  fromCoder:(NSCoder *)coder
					 atTime:(CMTime)renderTime
			   cameraMotion:(FxGripCameraMotion)cameraMotion
{
}

/*! @abstract Configures the camera node from the decoded host focal length, frustum, and camera transform. */
- (void)configureCameraNode:(SCNNode *)cameraNode withCoder:(NSCoder *)coder
{
	double focalLength = [coder decodeFx3DFocalLength];
	double near = [coder decodeFx3DFrustumNear];
	double far = [coder decodeFx3DFrustumFar];

	SCNCamera *camera;
	if (focalLength > 0.0 && far > near) {
		camera = [SCNCamera fxg_cameraWithFocalLength:focalLength nearZ:near farZ:far];
	} else {
		camera = [SCNCamera camera];
	}

	double left = [coder decodeFx3DFrustumLeft];
	double right = [coder decodeFx3DFrustumRight];
	double bottom = [coder decodeFx3DFrustumBottom];
	double top = [coder decodeFx3DFrustumTop];
	if (far > near && right > left && top > bottom) {
		[camera fxg_setProjectionFromFrustumLeft:left right:right bottom:bottom top:top near:near far:far];
	}

	cameraNode.camera = camera;

	simd_float4x4 cameraTransform;
	if ([self decodeCameraTransform:&cameraTransform fromCoder:coder]) {
		cameraNode.simdTransform = cameraTransform;
	}
}

/*! @abstract Decodes each host light and adds an SCNLight node for it under the lights container. */
- (void)addLightsToNode:(SCNNode *)lightsNode fromCoder:(NSCoder *)coder
{
	long count = [coder decodeFxLightCount];
	for (long index = 0; index < count; index++) {
		FxLight light;
		if ([coder decodeFxLight:&light index:index]) {
			[lightsNode addChildNode:[SCNLight fxg_lightNodeFromFxLight:light]];
		}
	}
}

/*! @abstract Builds a unit plane textured with the source tile at the host layer transform, or nil when no source is present. */
- (nullable SCNNode *)layerPlaneNodeWithCoder:(NSCoder *)coder sourceTile:(nullable FxImageTile *)sourceTile
{
	if (sourceTile == nil) {
		return nil;
	}

	SCNPlane *plane = [SCNPlane planeWithWidth:1.0 height:1.0];
	plane.firstMaterial.lightingModelName = SCNLightingModelConstant; // show the image as-is
	plane.firstMaterial.doubleSided = YES;
	plane.firstMaterial.diffuse.contents = [sourceTile metalTextureForDevice:sourceTile.device];

	SCNNode *node = [SCNNode nodeWithGeometry:plane];
	simd_float4x4 layerTransform;
	if ([self decodeLayerTransform:&layerTransform fromCoder:coder]) {
		node.simdTransform = layerTransform;
	}
	return node;
}

/*!
	@method		applyParticleInteractionToScene:fromCoder:
	@abstract	Restores the scene-wide default inter-particle force and installs it on the scene.
	@discussion	Introduced in FxGrip 0.1.0. Runs after the subclass has added its own content, so a
				system created in updateSceneContents: is reconciled along with one decoded from the
				template. A system that carries its own interaction keeps it. */
- (void)applyParticleInteractionToScene:(SCNScene *)scene fromCoder:(NSCoder *)coder
{
	// Fields first: a system they bind is then skipped by the scene-wide default.
	[self installParticleInteractionFieldsInScene:scene fromCoder:coder];

	FxGripParticleInteraction *interaction = [self decodeParticleInteractionFromCoder:coder];
	if (interaction == nil) {
		return;
	}
	scene.particleInteraction = interaction;
	[scene fxgrip_reconcileParticleInteractions];
}

/*!
	@method		installParticleInteractionFieldsInScene:fromCoder:
	@abstract	Recreates each declared interaction field on its named node and binds its sources.
	@discussion	Introduced in FxGrip 0.1.0. A physics field's evaluation block does not survive an
				archive, so the field is built fresh every render from the decoded configuration. An
				entry naming a node the scene does not contain is skipped. */
- (void)installParticleInteractionFieldsInScene:(SCNScene *)scene fromCoder:(NSCoder *)coder
{
	NSDictionary<NSString *, FxGripParticleInteraction *> *configurations = [self decodeParticleInteractionFieldsFromCoder:coder];
	if (configurations == nil) {
		return;
	}
	// Sorted, so the fields install in the same order every render whatever the dictionary's own is.
	for (NSString *name in [configurations.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
		SCNNode *node = [scene.rootNode childNodeWithName:name recursively:YES];
		if (node == nil && [scene.rootNode.name isEqualToString:name]) {
			node = scene.rootNode;
		}
		if (node == nil) {
			continue;
		}
		SCNPhysicsField *field = [SCNPhysicsField particleInteractionFieldWithInteraction:configurations[name]];
		node.physicsField = field;
		[field bindParticleInteractionToParticleSystemsInNode:node];
	}
}

/*! @abstract Unarchives the scene-template node subtree from plugin state, or nil when none is stored. */
- (nullable SCNNode *)templateContentFromCoder:(NSCoder *)coder
{
	NSData *archived = nil;
	@try {
		archived = [coder decodeObjectOfClass:NSData.class forKey:FxGripSceneKitCoderTemplateKey];
	} @catch (NSException *exception) {
		archived = nil;
	}
	if (archived == nil) {
		return nil;
	}

	NSError *error = nil;
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archived error:&error];
	if (unarchiver == nil) {
		NSLog(@"%s Error: could not open the scene template archive. %@", __func__, error);
		return nil;
	}
	// The archive is FxGrip's own, so decode without the secure-coding class allowlist.
	unarchiver.requiresSecureCoding = NO;

	SCNNode *node = nil;
	@try {
		node = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
	} @catch (NSException *exception) {
		node = nil;
	}
	[unarchiver finishDecoding];
	NARC_AUTORELEASE(unarchiver);

	return [node isKindOfClass:SCNNode.class] ? node : nil;
}

@end
