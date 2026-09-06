/*!
	@file       FxGripSceneKitPhysicsBackendTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSceneKitPhysicsBackendTests
	@abstract   Tests for FxGripSceneKitPhysicsBackend, the render backend that simulates SceneKit physics to a target time.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the backend identity, the reproducible catch-up simulation of a freely falling body, the recompute mode that re-simulates on every render, and the session cache that replays a memoized pose without further simulation steps.
*/

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

/*! @abstract A backend reports itself ready and identifies as "scenekit-metal-physics". */
- (void)testIdentity
{
	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	XCTAssertTrue(backend.isReady);
	XCTAssertEqualObjects(backend.backendIdentifier, @"scenekit-metal-physics");
}

/*! @abstract Simulating to a target time reproduces the same ball height across fresh scenes, the ball falls under gravity, and a shorter time falls less. */
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

/*! @abstract In the default recompute mode, a second render of the same time doubles the total simulation steps. */
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

/*! @abstract In session-cache mode, a re-rendered time and an earlier memoized time add no simulation steps and replay the computed pose. */
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
