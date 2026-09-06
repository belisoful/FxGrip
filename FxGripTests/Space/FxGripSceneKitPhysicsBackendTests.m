//
//  FxGripSceneKitPhysicsBackendTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <SceneKit/SceneKit.h>
#import <simd/simd.h>
#import <FxGrip/FxGripSceneKitPhysicsBackend.h>

@interface FxGripSceneKitPhysicsBackendTests : XCTestCase
@property (nonatomic, strong) id<MTLDevice> device;
@end

@implementation FxGripSceneKitPhysicsBackendTests

- (void)setUp
{
	[super setUp];
	self.device = MTLCreateSystemDefaultDevice();
}

- (id<MTLTexture>)tinyTarget
{
	MTLTextureDescriptor *descriptor =
		[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:8 height:8 mipmapped:NO];
	descriptor.usage = MTLTextureUsageRenderTarget;
	descriptor.storageMode = MTLStorageModeShared;
	return [self.device newTextureWithDescriptor:descriptor];
}

// A fresh scene each call: a freely falling dynamic sphere (no floor, no collisions) plus a camera.
- (SCNScene *)fallingSceneWithBall:(SCNNode **)outBall pointOfView:(SCNNode **)outPOV
{
	SCNScene *scene = [SCNScene scene];

	SCNNode *ball = [SCNNode nodeWithGeometry:[SCNSphere sphereWithRadius:1.0]];
	ball.name = @"ball"; // the session cache keys body transforms by node name
	ball.position = SCNVector3Make(0.0, 10.0, 0.0);
	ball.physicsBody = [SCNPhysicsBody bodyWithType:SCNPhysicsBodyTypeDynamic shape:nil];
	[scene.rootNode addChildNode:ball];

	SCNNode *cameraNode = [SCNNode node];
	cameraNode.camera = [SCNCamera camera];
	cameraNode.position = SCNVector3Make(0.0, 5.0, 30.0);
	[scene.rootNode addChildNode:cameraNode];

	if (outBall != NULL) { *outBall = ball; }
	if (outPOV != NULL) { *outPOV = cameraNode; }
	return scene;
}

- (float)ballHeightAfterSimulatingTo:(CFTimeInterval)seconds withBackend:(FxGripSceneKitPhysicsBackend *)backend
{
	SCNNode *ball = nil;
	SCNNode *pov = nil;
	SCNScene *scene = [self fallingSceneWithBall:&ball pointOfView:&pov];

	NSError *error = nil;
	BOOL ok = [backend renderScene:scene pointOfView:pov toTexture:[self tinyTarget] atTime:seconds error:&error];
	XCTAssertTrue(ok, @"render failed: %@", error);

	return ball.presentationNode.simdWorldPosition.y;
}

- (void)testIdentity
{
	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	XCTAssertTrue(backend.isReady);
	XCTAssertEqualObjects(backend.backendIdentifier, @"scenekit-metal-physics");
}

- (void)testCatchUpSimulationIsReproducibleAndAdvances
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 120.0;

	// Same target time, two independent fresh scenes: the result must reproduce.
	float halfFirst = [self ballHeightAfterSimulatingTo:0.5 withBackend:backend];
	float halfSecond = [self ballHeightAfterSimulatingTo:0.5 withBackend:backend];
	XCTAssertEqualWithAccuracy(halfFirst, halfSecond, 1e-3, @"the same frame reproduces the same result");

	// Physics actually ran: the ball fell from its start height.
	XCTAssertLessThan(halfFirst, 10.0f, @"the ball fell under gravity");

	// A shorter time falls less, and rendering the earlier time after the later one is unaffected.
	float quarter = [self ballHeightAfterSimulatingTo:0.25 withBackend:backend];
	XCTAssertGreaterThan(quarter, halfFirst, @"less time simulated means the ball has fallen less");
}

- (void)testRecomputeModeReSimulatesEveryRender
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 120.0; // Recompute is the default mode

	[self ballHeightAfterSimulatingTo:0.5 withBackend:backend];
	NSUInteger afterFirst = backend.totalSimulationSteps;
	[self ballHeightAfterSimulatingTo:0.5 withBackend:backend];
	NSUInteger afterSecond = backend.totalSimulationSteps;

	XCTAssertGreaterThan(afterFirst, 0u);
	XCTAssertEqual(afterSecond, afterFirst * 2, @"recompute mode simulates again on the second render");
}

- (void)testSessionCacheHitSkipsSimulationAndMatchesTheComputedResult
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 120.0;
	backend.simulationMode = FxGripPhysicsSimulationModeSessionCache;

	float first = [self ballHeightAfterSimulatingTo:0.5 withBackend:backend];
	NSUInteger afterFirst = backend.totalSimulationSteps;
	XCTAssertGreaterThan(afterFirst, 0u, @"the first render simulated the trajectory");

	float second = [self ballHeightAfterSimulatingTo:0.5 withBackend:backend];
	NSUInteger afterSecond = backend.totalSimulationSteps;

	XCTAssertEqual(afterSecond, afterFirst, @"a cache hit runs no further simulation steps");
	XCTAssertEqualWithAccuracy(second, first, 1e-4, @"the replayed pose equals the computed pose");

	// An earlier step was memoized during the first render, so it is a hit too.
	[self ballHeightAfterSimulatingTo:0.25 withBackend:backend];
	XCTAssertEqual(backend.totalSimulationSteps, afterFirst, @"an earlier memoized step also hits");
}

@end
