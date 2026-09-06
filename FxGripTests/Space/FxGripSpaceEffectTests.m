//
//  FxGripSpaceEffectTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <SceneKit/SceneKit.h>
#import <FxGrip/FxGripSpaceEffect.h>
#import <FxGrip/FxGripSpaceBackend.h>
#import <FxGrip/FxGripSceneKitPhysicsBackend.h>

#pragma mark - Stub backend

@interface FxGripSpaceStubBackend : NSObject <FxGripSpaceBackend>
@end

@implementation FxGripSpaceStubBackend
- (BOOL)isReady { return YES; }
- (NSString *)backendIdentifier { return @"stub"; }
- (BOOL)renderScene:(SCNScene *)scene
		pointOfView:(SCNNode *)pointOfView
		  toTexture:(id<MTLTexture>)texture
			 atTime:(CFTimeInterval)seconds
			  error:(NSError **)error { return YES; }
@end

#pragma mark - Seam subclass

@interface FxGripSpaceSeamEffect : FxGripSpaceEffect
@property (nonatomic, assign) BOOL seamCalled;
@end

@implementation FxGripSpaceSeamEffect
- (BOOL)encodeSceneParametersIntoCoder:(NSCoder *)coder atTime:(CMTime)renderTime error:(NSError **)error
{
	self.seamCalled = YES;
	[coder encodeInteger:42 forKey:@"customValue"];
	return YES;
}
@end

#pragma mark - Apply-hook subclass

@interface FxGripSpaceApplyEffect : FxGripSpaceEffect
@property (nonatomic, weak) SCNNode *receivedCameraNode;
@property (nonatomic, assign) BOOL applyCalled;
@end

@implementation FxGripSpaceApplyEffect
- (void)updateSceneContents:(SCNScene *)scene
				 cameraNode:(SCNNode *)cameraNode
				  fromCoder:(NSCoder *)coder
					 atTime:(CMTime)renderTime
			   cameraMotion:(FxGripCameraMotion)cameraMotion
{
	self.applyCalled = YES;
	self.receivedCameraNode = cameraNode;
}
@end

#pragma mark - Template subclass

@interface FxGripSpaceTemplateEffect : FxGripSpaceEffect
@property (nonatomic, strong) SCNNode *templateNode;
@end

@implementation FxGripSpaceTemplateEffect
- (SCNNode *)sceneTemplateNodeAtTime:(CMTime)renderTime { return self.templateNode; }
@end

#pragma mark - Tests

@interface FxGripSpaceEffectTests : XCTestCase
@property (nonatomic, strong) FxGripSpaceEffect *effect;
@end

@implementation FxGripSpaceEffectTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripSpaceEffect.alloc initWithAPIManager:(id _Nonnull)nil];
}

- (void)testDefaultBackendIsSceneKitMetal
{
	XCTAssertEqualObjects(self.effect.spaceBackend.backendIdentifier, @"scenekit-metal");
	XCTAssertEqualObjects([self.effect defaultSpaceBackend].backendIdentifier, @"scenekit-metal");
}

- (void)testBackendCanBeSetAndResetToDefault
{
	self.effect.spaceBackend = [FxGripSpaceStubBackend.alloc init];
	XCTAssertEqualObjects(self.effect.spaceBackend.backendIdentifier, @"stub");

	self.effect.spaceBackend = nil;
	XCTAssertEqualObjects(self.effect.spaceBackend.backendIdentifier, @"scenekit-metal");
}

- (void)testRendersSourceLayerPlaneDefaultsYes
{
	XCTAssertTrue(self.effect.rendersSourceLayerPlane);
}

- (void)testNeedsFullBufferForWholeFrameRender
{
	XCTAssertTrue(self.effect.needsFullBuffer);
}

- (NSCoder *)emptyDecoder
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	[archiver finishEncoding];
	NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:nil];
	decoder.requiresSecureCoding = NO;
	return decoder;
}

- (void)testBuildSceneReturnsIndependentScenesEachWithACamera
{
	SCNNode *pov1 = nil;
	SCNScene *scene1 = [self.effect buildSceneWithCoder:[self emptyDecoder] sourceTile:nil atTime:kCMTimeZero pointOfView:&pov1];
	SCNNode *pov2 = nil;
	SCNScene *scene2 = [self.effect buildSceneWithCoder:[self emptyDecoder] sourceTile:nil atTime:kCMTimeZero pointOfView:&pov2];

	XCTAssertNotNil(scene1);
	XCTAssertNotNil(scene2);
	XCTAssertNotEqual(scene1, scene2, @"each render must get its own scene, not a shared instance");
	XCTAssertNotEqual(pov1, pov2);

	XCTAssertNotNil(pov1.camera);
	XCTAssertEqualObjects(pov1.parentNode, scene1.rootNode);
	// camera node + lights container; no plane because there is no source tile
	XCTAssertEqual(scene1.rootNode.childNodes.count, 2u);
}

- (void)testApplyHookReceivesThePointOfViewCameraNode
{
	FxGripSpaceApplyEffect *effect = [FxGripSpaceApplyEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	SCNNode *pov = nil;
	[effect buildSceneWithCoder:[self emptyDecoder] sourceTile:nil atTime:kCMTimeZero pointOfView:&pov];

	XCTAssertTrue(effect.applyCalled);
	XCTAssertNotNil(effect.receivedCameraNode.camera);
	XCTAssertEqualObjects(effect.receivedCameraNode, pov, @"the hook's camera node is the render point of view");
}

- (void)testCaptureInvokesSceneParametersSeamAndEncodesIntoState
{
	FxGripSpaceSeamEffect *effect = [FxGripSpaceSeamEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	NSKeyedArchiver *coder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];

	NSError *error = nil;
	BOOL ok = [effect pluginCoder:coder atTime:kCMTimeZero quality:(FxQuality)kFxQuality_HIGH error:&error];
	XCTAssertTrue(ok);
	XCTAssertTrue(effect.seamCalled, @"pluginCoder: must call the scene-parameters seam");

	[coder finishEncoding];
	NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:coder.encodedData error:nil];
	decoder.requiresSecureCoding = NO;
	XCTAssertEqual([decoder decodeIntegerForKey:@"customValue"], 42);
}

- (void)testDefaultSceneParametersSeamIsNoOp
{
	NSKeyedArchiver *coder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	NSError *error = nil;
	BOOL ok = [self.effect encodeSceneParametersIntoCoder:coder atTime:kCMTimeZero error:&error];
	XCTAssertTrue(ok);
	XCTAssertNil(error);
}

- (void)testPhysicsBakeDisabledByDefaultUsesPlainMetalBackend
{
	XCTAssertFalse(self.effect.physicsBakeEnabled);
	XCTAssertFalse([self.effect.spaceBackend isKindOfClass:FxGripSceneKitPhysicsBackend.class]);
	XCTAssertEqualObjects(self.effect.spaceBackend.backendIdentifier, @"scenekit-metal");
}

- (void)testEnablingPhysicsBakeUpgradesTheDefaultBackend
{
	self.effect.physicsBakeEnabled = YES;
	XCTAssertTrue([self.effect.spaceBackend isKindOfClass:FxGripSceneKitPhysicsBackend.class]);
}

- (void)testEnablingPhysicsBakeKeepsAUserSetBackend
{
	FxGripSpaceStubBackend *stub = [FxGripSpaceStubBackend.alloc init];
	self.effect.spaceBackend = stub;
	self.effect.physicsBakeEnabled = YES;
	XCTAssertEqualObjects(self.effect.spaceBackend, stub, @"a plugin's own backend is not replaced");
}

- (void)testSceneTemplateSerializesAndRecreatesAnIndependentCopy
{
	FxGripSpaceTemplateEffect *effect = [FxGripSpaceTemplateEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	SCNNode *content = [SCNNode node];
	content.name = @"authored";
	SCNNode *box = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:1.0 height:1.0 length:1.0 chamferRadius:0.0]];
	box.name = @"box";
	[content addChildNode:box];
	effect.templateNode = content;

	// Capture archives the template into plugin state.
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	NSError *error = nil;
	XCTAssertTrue([effect pluginCoder:archiver atTime:kCMTimeZero quality:(FxQuality)kFxQuality_HIGH error:&error]);
	[archiver finishEncoding];

	// Render recreates it in the per-render scene.
	NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:nil];
	decoder.requiresSecureCoding = NO;
	SCNNode *pov = nil;
	SCNScene *scene = [effect buildSceneWithCoder:decoder sourceTile:nil atTime:kCMTimeZero pointOfView:&pov];

	SCNNode *recreated = [scene.rootNode childNodeWithName:@"authored" recursively:YES];
	XCTAssertNotNil(recreated, @"the authored template is recreated in the render scene");
	XCTAssertNotEqual(recreated, content, @"the recreated node is an independent copy");
	XCTAssertNotNil([scene.rootNode childNodeWithName:@"box" recursively:YES], @"the child geometry survived");
}

@end
