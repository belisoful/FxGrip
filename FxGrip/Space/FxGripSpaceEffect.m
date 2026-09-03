//
//  FxGripSpaceEffect.m
//  FxGrip
//

#import "FxGripSpaceEffect.h"
#import "FxGripSceneKitMetalBackend.h"
#import "SCNCamera+FxGrip.h"
#import "SCNLight+FxGrip.h"
#import "NSCoder+FxPlug.h"
#import "FxGripMTLDeviceCache.h"
#import "FxTileImage+FxGrip.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"
#import <FxPlug/Fx3DAPI.h>
#import <FxPlug/FxLightingAPI.h>

// Distinct coder key prefixes for the view-matrix samples one frame on each side of the render time.
static NSString * const FxGripSpaceCoderPrevKey = @"_fxspace_prev";
static NSString * const FxGripSpaceCoderNextKey = @"_fxspace_next";

// The archived scene-template node.
static NSString * const FxGripSpaceCoderTemplateKey = @"_fxspace_template";

static simd_float4x4 FxGripMatrixFromCoderData(Matrix44Data *data)
{
	matrix_float4x4 m;
	[NSCoder floatMatrix:&m fromDoubleMatrix:data];
	return m;
}

@implementation FxGripSpaceEffect
{
	id<FxGripSpaceBackend> _spaceBackend;

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
		_rendersSourceLayerPlane = YES;
		_spaceBackend = NARC_RETAIN([self defaultSpaceBackend]);
		_templateLock = [[NSLock alloc] init];
		self.needsFullBuffer = YES; // a 3D render projects the whole frame, not a sub-tile
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
- (id<FxGripSpaceBackend>)spaceBackend
{
	return _spaceBackend;
}

- (id<FxGripSpaceBackend>)defaultSpaceBackend
{
	return [FxGripSceneKitMetalBackend backend];
}

- (void)setSpaceBackend:(nullable id<FxGripSpaceBackend>)spaceBackend
{
	id<FxGripSpaceBackend> replacement = spaceBackend ?: [self defaultSpaceBackend];
	if (_spaceBackend != replacement) {
		NARC_RELEASE(_spaceBackend);
		_spaceBackend = NARC_RETAIN(replacement);
	}
}

#pragma mark Capture (state pass)

- (BOOL)pluginCoder:(NSCoder *)coder
			 atTime:(CMTime)renderTime
			quality:(FxQuality)qualityLevel
			  error:(NSError * _Nullable *)outError
{
	id<Fx3DAPI_v5> space = self.apiManager.spaceAPIv5;
	if (space != nil) {
		[coder encodeFx3DAPI:space];

		CMTime frameDuration = self.frameDuration;
		if (CMTIME_IS_VALID(frameDuration) && CMTimeGetSeconds(frameDuration) > 0.0) {
			[coder encodeFx3DAPI:space atTime:CMTimeSubtract(renderTime, frameDuration) forKey:FxGripSpaceCoderPrevKey];
			[coder encodeFx3DAPI:space atTime:CMTimeAdd(renderTime, frameDuration) forKey:FxGripSpaceCoderNextKey];
		}
	}

	id<FxLightingAPI_v3> lighting = self.apiManager.lightingAPIv3;
	if (lighting != nil) {
		[coder encodeFxLightingAPI:lighting];
	}

	SCNNode *templateNode = [self sceneTemplateNodeAtTime:renderTime];
	if (templateNode != nil) {
		NSData *archived = [self archivedTemplateForNode:templateNode];
		if (archived != nil) {
			[coder encodeObject:archived forKey:FxGripSpaceCoderTemplateKey];
		}
	}

	return [self encodeSceneParametersIntoCoder:coder atTime:renderTime error:outError];
}

- (BOOL)encodeSceneParametersIntoCoder:(NSCoder *)coder
								atTime:(CMTime)renderTime
								 error:(NSError * _Nullable *)error
{
	return YES;
}

- (nullable SCNNode *)sceneTemplateNodeAtTime:(CMTime)renderTime
{
	return nil;
}

- (NSInteger)sceneTemplateVersion
{
	return 0;
}

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

#pragma mark Geometry callbacks

- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *)sourceImages
			destinationImage:(FxImageTile *)destinationImage
				 pluginCoder:(NSCoder *)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)outError
{
	*destinationImageRect = destinationImage.imagePixelBounds;
	return YES;
}

- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
	  sourceImageIndex:(NSUInteger)sourceImageIndex
		  sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
	  destinationImage:(FxImageTile *)destinationImage
		   pluginCoder:(NSCoder *)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable *)outError
{
	if (sourceImageIndex < sourceImages.count) {
		*sourceTileRect = sourceImages[sourceImageIndex].imagePixelBounds;
	} else {
		*sourceTileRect = destinationTileRect;
	}
	return YES;
}

#pragma mark Render

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *)sourceImages
				   pluginCoder:(NSCoder *)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable *)outError
{
	FxImageTile *sourceTile = sourceImages.firstObject;
	id<MTLTexture> destinationTexture = [destinationImage metalTextureForDevice:destinationImage.device];
	if (destinationTexture == nil) {
		[self setSpaceError:outError reason:@"the destination tile has no Metal texture"];
		return NO;
	}

	id<FxGripSpaceBackend> backend = self.spaceBackend;
	if (!backend.isReady) {
		// The backend cannot render; show the source unchanged rather than failing the render.
		return sourceTile != nil ? [self blitTile:sourceTile toTexture:destinationTexture error:outError] : YES;
	}

	SCNNode *pointOfView = nil;
	SCNScene *scene = [self buildSceneWithCoder:pluginCoder
									sourceTile:sourceTile
										atTime:renderTime
								   pointOfView:&pointOfView];

	CFTimeInterval seconds = CMTIME_IS_VALID(renderTime) ? CMTimeGetSeconds(renderTime) : 0.0;
	return [backend renderScene:scene
					pointOfView:pointOfView
					  toTexture:destinationTexture
						 atTime:seconds
						  error:outError];
}

#pragma mark Per-render scene construction

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

	if (outPointOfView != NULL) {
		*outPointOfView = cameraNode;
	}
	return scene;
}

- (void)updateSceneContents:(SCNScene *)scene
				 cameraNode:(SCNNode *)cameraNode
				  fromCoder:(NSCoder *)coder
					 atTime:(CMTime)renderTime
			   cameraMotion:(FxGripCameraMotion)cameraMotion
{
}

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

	Matrix44Data *viewData = [coder decodeFx3DViewMatrixData];
	if (viewData != NULL) {
		// The host view matrix maps world to camera; the node transform is its inverse.
		cameraNode.simdTransform = simd_inverse(FxGripMatrixFromCoderData(viewData));
	}
}

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
	Matrix44Data *modelData = [coder decodeFx3DModelMatrixData];
	if (modelData != NULL) {
		node.simdTransform = FxGripMatrixFromCoderData(modelData);
	}
	return node;
}

- (FxGripCameraMotion)cameraMotionFromCoder:(NSCoder *)coder
{
	Matrix44Data *prevData = [coder decodeFx3DViewMatrixData:FxGripSpaceCoderPrevKey];
	Matrix44Data *nextData = [coder decodeFx3DViewMatrixData:FxGripSpaceCoderNextKey];
	if (prevData == NULL || nextData == NULL) {
		return FxGripCameraMotionZero();
	}

	simd_float4x4 previous = simd_inverse(FxGripMatrixFromCoderData(prevData));
	simd_float4x4 next = simd_inverse(FxGripMatrixFromCoderData(nextData));
	CMTime frameDuration = self.frameDuration;
	float dt = CMTIME_IS_VALID(frameDuration) ? (float)CMTimeGetSeconds(frameDuration) : 0.0f;

	return FxGripCameraMotionCentral(previous, next, dt);
}

- (nullable SCNNode *)templateContentFromCoder:(NSCoder *)coder
{
	NSData *archived = nil;
	@try {
		archived = [coder decodeObjectOfClass:NSData.class forKey:FxGripSpaceCoderTemplateKey];
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

#pragma mark Passthrough

- (BOOL)blitTile:(FxImageTile *)sourceTile toTexture:(id<MTLTexture>)destinationTexture error:(NSError * _Nullable *)outError
{
	id<MTLTexture> sourceTexture = [sourceTile metalTextureForDevice:sourceTile.device];
	if (sourceTexture == nil) {
		return YES;
	}

	FxGripMTLDeviceCache *deviceCache = FxGripMTLDeviceCache.deviceCache;
	FxGripMTLDeviceCacheItem *item = [deviceCache deviceWithRegistryID:destinationTexture.device.registryID];
	id<MTLCommandQueue> commandQueue = item != nil ? [item getNextFreeCommandQueue] : [destinationTexture.device newCommandQueue];
	if (commandQueue == nil) {
		[self setSpaceError:outError reason:@"no command queue for the passthrough copy"];
		return NO;
	}

	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
	id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
	MTLSize size = MTLSizeMake(MIN(sourceTexture.width, destinationTexture.width),
							   MIN(sourceTexture.height, destinationTexture.height),
							   1);
	[blit copyFromTexture:sourceTexture
			  sourceSlice:0
			  sourceLevel:0
			 sourceOrigin:MTLOriginMake(0, 0, 0)
			   sourceSize:size
				toTexture:destinationTexture
		 destinationSlice:0
		 destinationLevel:0
		destinationOrigin:MTLOriginMake(0, 0, 0)];
	[blit endEncoding];
	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];

	if (item != nil) {
		[deviceCache returnCommandQueueToCache:commandQueue];
	}
	return YES;
}

- (void)setSpaceError:(NSError * _Nullable *)outError reason:(NSString *)reason
{
	if (outError != NULL) {
		*outError = [NSError errorWithDomain:FxGripPlugErrorDomain
										code:kFxGripError_SpaceRenderFailure
									userInfo:@{ NSLocalizedDescriptionKey: reason }];
	}
}

@end
