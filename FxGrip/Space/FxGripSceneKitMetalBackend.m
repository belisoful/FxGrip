//
//  FxGripSceneKitMetalBackend.m
//  FxGrip
//

#import "FxGripSceneKitMetalBackend.h"
#import "FxGripMTLDeviceCache.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"

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
