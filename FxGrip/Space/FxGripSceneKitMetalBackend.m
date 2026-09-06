/*!
	@file       FxGripSceneKitMetalBackend.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSceneKitMetalBackend
	@abstract   Implements the shipped SceneKit-over-Metal space backend.
	@discussion Introduced in FxGrip 0.1.0. A render borrows a free SCNRenderer for its device, sets the
	            scene and point of view, builds a render pass whose color attachment is the destination
	            texture and whose depth attachment comes from the device cache, draws synchronously
	            through a cached command queue, waits for completion, and returns the renderer. Renderers
	            are pooled per device so concurrent renders never share one.
*/

#import "FxGripSceneKitMetalBackend.h"
#import "FxGripMTLDeviceCache.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The shipped FxGripSpaceBackend: a Metal SCNRenderer driving a scene into a tile texture.
	@discussion	Introduced in FxGrip 0.1.0. The renderer pool and command queue are keyed by Metal device.
*/
@implementation FxGripSceneKitMetalBackend
{
	// Free renderers per device. A render borrows one for its exclusive use and returns it, so
	// concurrent renders never share a renderer (setting scene + renderAtTime is stateful).
	NSMutableDictionary<NSNumber *, NSMutableArray<SCNRenderer *> *> *_freeRenderers;
	NSLock *_rendererLock;
}

+ (instancetype)backend
{
	return NARC_AUTORELEASE([[self alloc] init]);
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_freeRenderers = [NSMutableDictionary dictionary];
		_rendererLock = [[NSLock alloc] init];
		_clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_freeRenderers);
	NARC_RELEASE(_rendererLock);
	SUPER_DEALLOC();
}

- (BOOL)isReady
{
	return YES;
}

- (NSString *)backendIdentifier
{
	return @"scenekit-metal";
}

/*! @abstract The default simulation hook, a no-op; a stateful subclass overrides it. */
- (void)advanceSimulationForScene:(SCNScene *)scene
						renderer:(SCNRenderer *)renderer
						  toTime:(CFTimeInterval)seconds
{
}

/*! @abstract Takes a free renderer for `device` from the pool, or creates one when the pool is empty. */
- (SCNRenderer *)borrowRendererForDevice:(id<MTLDevice>)device
{
	NSNumber *key = @(device.registryID);
	SCNRenderer *renderer = nil;

	[_rendererLock lock];
	NSMutableArray<SCNRenderer *> *pool = _freeRenderers[key];
	renderer = pool.lastObject;
	if (renderer != nil) {
		[pool removeLastObject];
	}
	[_rendererLock unlock];

	if (renderer == nil) {
		renderer = [SCNRenderer rendererWithDevice:device options:nil];
	}
	return renderer;
}

/*! @abstract Clears the renderer's scene and point of view, then returns it to the device's pool. */
- (void)returnRenderer:(SCNRenderer *)renderer forDevice:(id<MTLDevice>)device
{
	renderer.scene = nil;
	renderer.pointOfView = nil;

	NSNumber *key = @(device.registryID);
	[_rendererLock lock];
	NSMutableArray<SCNRenderer *> *pool = _freeRenderers[key];
	if (pool == nil) {
		pool = [NSMutableArray array];
		_freeRenderers[key] = pool;
	}
	[pool addObject:renderer];
	[_rendererLock unlock];
}

- (void)setError:(NSError * _Nullable *)outError code:(NSInteger)code reason:(NSString *)reason
{
	if (outError != NULL) {
		*outError = [NSError errorWithDomain:FxGripPlugErrorDomain
										code:code
									userInfo:@{ NSLocalizedDescriptionKey: reason }];
	}
}

/*!
	@method		renderScene:pointOfView:toTexture:atTime:error:
	@abstract	Draws `scene` through `pointOfView` into `texture` at `seconds`.
	@return		YES on success; NO with an error set when the scene, texture, or command queue is missing.
	@discussion	Introduced in FxGrip 0.1.0. The depth texture and command queue come from the device cache
				for the texture's device. advanceSimulationForScene:renderer:toTime: runs after the scene
				and point of view are set and before the draw. The draw is synchronous. */
- (BOOL)renderScene:(SCNScene *)scene
		pointOfView:(nullable SCNNode *)pointOfView
		  toTexture:(id<MTLTexture>)texture
			 atTime:(CFTimeInterval)seconds
			  error:(NSError * _Nullable *)outError
{
	if (scene == nil) {
		[self setError:outError code:kFxGripError_SpaceMissingScene reason:@"no scene to render"];
		return NO;
	}
	if (texture == nil) {
		[self setError:outError code:kFxGripError_SpaceRenderFailure reason:@"no destination texture to render into"];
		return NO;
	}

	id<MTLDevice> device = texture.device;

	FxRect bounds = { 0, 0, (SInt32)texture.width, (SInt32)texture.height };
	id<MTLTexture> depth = [FxGripMTLDeviceCache depthTexture:bounds forDevice:device];

	MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
	pass.colorAttachments[0].texture = texture;
	pass.colorAttachments[0].loadAction = MTLLoadActionClear;
	pass.colorAttachments[0].clearColor = self.clearColor;
	pass.colorAttachments[0].storeAction = MTLStoreActionStore;
	if (depth != nil) {
		pass.depthAttachment.texture = depth;
		pass.depthAttachment.loadAction = MTLLoadActionClear;
		pass.depthAttachment.clearDepth = 1.0;
		pass.depthAttachment.storeAction = MTLStoreActionDontCare;
	}

	FxGripMTLDeviceCache *deviceCache = FxGripMTLDeviceCache.deviceCache;
	FxGripMTLDeviceCacheItem *item = [deviceCache deviceWithRegistryID:device.registryID];
	id<MTLCommandQueue> commandQueue = item != nil ? [item getNextFreeCommandQueue] : [device newCommandQueue];
	if (commandQueue == nil) {
		[self setError:outError code:kFxGripError_SpaceRenderFailure reason:@"no command queue for the destination texture"];
		return NO;
	}

	SCNRenderer *renderer = [self borrowRendererForDevice:device];
	renderer.scene = scene;
	renderer.pointOfView = pointOfView;

	[self advanceSimulationForScene:scene renderer:renderer toTime:seconds];

	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
	[renderer renderAtTime:seconds
				  viewport:CGRectMake(0.0, 0.0, texture.width, texture.height)
			 commandBuffer:commandBuffer
			passDescriptor:pass];
	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];

	[self returnRenderer:renderer forDevice:device];
	if (item != nil) {
		[deviceCache returnCommandQueueToCache:commandQueue];
	}
	return YES;
}

@end
