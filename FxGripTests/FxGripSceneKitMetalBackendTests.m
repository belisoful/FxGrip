//
//  FxGripSceneKitMetalBackendTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <SceneKit/SceneKit.h>
#import <FxGrip/FxGripSceneKitMetalBackend.h>

@interface FxGripSceneKitMetalBackendTests : XCTestCase
@property (nonatomic, strong) id<MTLDevice> device;
@end

@implementation FxGripSceneKitMetalBackendTests

- (void)setUp
{
	[super setUp];
	self.device = MTLCreateSystemDefaultDevice();
}

- (id<MTLTexture>)renderTargetOfSize:(NSUInteger)size
{
	MTLTextureDescriptor *descriptor =
		[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
														   width:size
														  height:size
													   mipmapped:NO];
	descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	descriptor.storageMode = MTLStorageModeShared;
	return [self.device newTextureWithDescriptor:descriptor];
}

- (SCNScene *)sceneWithPlaneColor:(NSColor *)color pointOfView:(SCNNode **)outPointOfView
{
	SCNScene *scene = [SCNScene scene];

	SCNPlane *plane = [SCNPlane planeWithWidth:500.0 height:500.0];
	plane.firstMaterial.diffuse.contents = color;
	plane.firstMaterial.lightingModelName = SCNLightingModelConstant; // no lights needed
	plane.firstMaterial.doubleSided = YES;
	[scene.rootNode addChildNode:[SCNNode nodeWithGeometry:plane]];

	SCNCamera *camera = [SCNCamera camera];
	camera.zNear = 1.0;
	camera.zFar = 1000.0;
	SCNNode *cameraNode = [SCNNode node];
	cameraNode.camera = camera;
	cameraNode.position = SCNVector3Make(0.0, 0.0, 100.0);
	[scene.rootNode addChildNode:cameraNode];

	if (outPointOfView != NULL) {
		*outPointOfView = cameraNode;
	}
	return scene;
}

- (void)readCenterRGBA:(uint8_t[4])out ofTexture:(id<MTLTexture>)texture
{
	NSUInteger size = texture.width;
	NSUInteger bytesPerRow = size * 4;
	uint8_t *pixels = malloc(bytesPerRow * size);
	[texture getBytes:pixels bytesPerRow:bytesPerRow fromRegion:MTLRegionMake2D(0, 0, size, size) mipmapLevel:0];
	memcpy(out, pixels + (size / 2) * bytesPerRow + (size / 2) * 4, 4);
	free(pixels);
}

- (void)testBackendIdentity
{
	FxGripSceneKitMetalBackend *backend = [FxGripSceneKitMetalBackend backend];
	XCTAssertTrue(backend.isReady);
	XCTAssertEqualObjects(backend.backendIdentifier, @"scenekit-metal");
}

- (void)testMissingTextureFails
{
	FxGripSceneKitMetalBackend *backend = [FxGripSceneKitMetalBackend backend];
	NSError *error = nil;
	BOOL ok = [backend renderScene:[SCNScene scene] pointOfView:nil toTexture:nil atTime:0.0 error:&error];
	XCTAssertFalse(ok);
	XCTAssertNotNil(error);
}

- (void)testRendersSceneGeometryIntoTexture
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}

	const NSUInteger size = 32;
	id<MTLTexture> texture = [self renderTargetOfSize:size];
	XCTAssertNotNil(texture);

	SCNNode *cameraNode = nil;
	SCNScene *scene = [self sceneWithPlaneColor:NSColor.redColor pointOfView:&cameraNode];

	FxGripSceneKitMetalBackend *backend = [FxGripSceneKitMetalBackend backend];
	backend.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0); // opaque black background

	NSError *error = nil;
	BOOL ok = [backend renderScene:scene pointOfView:cameraNode toTexture:texture atTime:0.0 error:&error];
	XCTAssertTrue(ok, @"render failed: %@", error);

	uint8_t rgba[4];
	[self readCenterRGBA:rgba ofTexture:texture];

	// The red plane fills the view, so the center is strongly red rather than the black clear.
	XCTAssertGreaterThan(rgba[0], 100, @"center should be red (r=%d g=%d b=%d)", rgba[0], rgba[1], rgba[2]);
	XCTAssertGreaterThan((int)rgba[0] - (int)rgba[1], 50);
	XCTAssertGreaterThan((int)rgba[0] - (int)rgba[2], 50);
}

- (void)testConcurrentRendersProduceIndependentResults
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}

	const NSUInteger size = 32;
	id<MTLTexture> redTexture = [self renderTargetOfSize:size];
	id<MTLTexture> greenTexture = [self renderTargetOfSize:size];

	SCNNode *redPOV = nil;
	SCNNode *greenPOV = nil;
	SCNScene *redScene = [self sceneWithPlaneColor:NSColor.redColor pointOfView:&redPOV];
	SCNScene *greenScene = [self sceneWithPlaneColor:NSColor.greenColor pointOfView:&greenPOV];

	FxGripSceneKitMetalBackend *backend = [FxGripSceneKitMetalBackend backend];
	backend.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

	// Two renders in flight at once must each get their own renderer from the pool.
	dispatch_queue_t queue = dispatch_queue_create("fxgrip.space.concurrency", DISPATCH_QUEUE_CONCURRENT);
	dispatch_group_t group = dispatch_group_create();
	__block BOOL redOK = NO;
	__block BOOL greenOK = NO;
	for (NSUInteger iteration = 0; iteration < 8; iteration++) {
		dispatch_group_async(group, queue, ^{
			redOK = [backend renderScene:redScene pointOfView:redPOV toTexture:redTexture atTime:0.0 error:nil];
		});
		dispatch_group_async(group, queue, ^{
			greenOK = [backend renderScene:greenScene pointOfView:greenPOV toTexture:greenTexture atTime:0.0 error:nil];
		});
	}
	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
	XCTAssertTrue(redOK);
	XCTAssertTrue(greenOK);

	uint8_t red[4];
	uint8_t green[4];
	[self readCenterRGBA:red ofTexture:redTexture];
	[self readCenterRGBA:green ofTexture:greenTexture];

	XCTAssertGreaterThan((int)red[0] - (int)red[1], 50, @"red target stayed red (r=%d g=%d b=%d)", red[0], red[1], red[2]);
	XCTAssertGreaterThan((int)green[1] - (int)green[0], 50, @"green target stayed green (r=%d g=%d b=%d)", green[0], green[1], green[2]);
}

@end
