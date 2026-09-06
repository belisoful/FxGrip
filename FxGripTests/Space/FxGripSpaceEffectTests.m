/*!
	@file       FxGripSpaceEffectTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSpaceEffectTests
	@abstract   Tests for FxGripSpaceEffect, the base effect that builds a per-render SceneKit scene and delegates to a space backend.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the default and replaceable backend, the whole-frame render flags, the per-render scene and camera, the scene-parameter capture seam, the apply hook, the physics-bake backend upgrade, and the scene-template round trip. Stub and hook subclasses stand in for a plugin's own space effect.
*/

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

/*! @abstract A fresh effect's space backend and default backend both identify as "scenekit-metal". */
- (void)testDefaultBackendIsSceneKitMetal
{
	XCTAssertEqualObjects(self.effect.spaceBackend.backendIdentifier, @"scenekit-metal");
	XCTAssertEqualObjects([self.effect defaultSpaceBackend].backendIdentifier, @"scenekit-metal");
}

/*! @abstract Setting a backend replaces the default, and setting it to nil restores the "scenekit-metal" default. */
- (void)testBackendCanBeSetAndResetToDefault
{
	self.effect.spaceBackend = [FxGripSpaceStubBackend.alloc init];
	XCTAssertEqualObjects(self.effect.spaceBackend.backendIdentifier, @"stub");

	self.effect.spaceBackend = nil;
	XCTAssertEqualObjects(self.effect.spaceBackend.backendIdentifier, @"scenekit-metal");
}

/*! @abstract An effect renders the source layer plane by default. */
- (void)testRendersSourceLayerPlaneDefaultsYes
{
	XCTAssertTrue(self.effect.rendersSourceLayerPlane);
}

/*! @abstract An effect needs the full buffer, since it renders the whole frame. */
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

/*! @abstract Each -buildSceneWithCoder: call returns its own scene and point-of-view camera node, parented to that scene's root with a camera container and lights but no source plane. */
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

/*! @abstract The update-scene apply hook fires during -buildSceneWithCoder: and receives the render point-of-view camera node. */
- (void)testApplyHookReceivesThePointOfViewCameraNode
{
	FxGripSpaceApplyEffect *effect = [FxGripSpaceApplyEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	SCNNode *pov = nil;
	[effect buildSceneWithCoder:[self emptyDecoder] sourceTile:nil atTime:kCMTimeZero pointOfView:&pov];

	XCTAssertTrue(effect.applyCalled);
	XCTAssertNotNil(effect.receivedCameraNode.camera);
	XCTAssertEqualObjects(effect.receivedCameraNode, pov, @"the hook's camera node is the render point of view");
}

/*! @abstract -pluginCoder: calls the scene-parameters seam, whose encoded value is recoverable from the plugin state. */
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

/*! @abstract The base -encodeSceneParametersIntoCoder: succeeds and reports no error without encoding anything. */
- (void)testDefaultSceneParametersSeamIsNoOp
{
	NSKeyedArchiver *coder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	NSError *error = nil;
	BOOL ok = [self.effect encodeSceneParametersIntoCoder:coder atTime:kCMTimeZero error:&error];
	XCTAssertTrue(ok);
	XCTAssertNil(error);
}

/*! @abstract Physics bake is off by default, so the backend is the plain "scenekit-metal" backend and not the physics subclass. */
- (void)testPhysicsBakeDisabledByDefaultUsesPlainMetalBackend
{
	XCTAssertFalse(self.effect.physicsBakeEnabled);
	XCTAssertFalse([self.effect.spaceBackend isKindOfClass:FxGripSceneKitPhysicsBackend.class]);
	XCTAssertEqualObjects(self.effect.spaceBackend.backendIdentifier, @"scenekit-metal");
}

/*! @abstract Enabling physics bake upgrades the default backend to FxGripSceneKitPhysicsBackend. */
- (void)testEnablingPhysicsBakeUpgradesTheDefaultBackend
{
	self.effect.physicsBakeEnabled = YES;
	XCTAssertTrue([self.effect.spaceBackend isKindOfClass:FxGripSceneKitPhysicsBackend.class]);
}

/*! @abstract Enabling physics bake leaves a plugin's own explicitly set backend in place. */
- (void)testEnablingPhysicsBakeKeepsAUserSetBackend
{
	FxGripSpaceStubBackend *stub = [FxGripSpaceStubBackend.alloc init];
	self.effect.spaceBackend = stub;
	self.effect.physicsBakeEnabled = YES;
	XCTAssertEqualObjects(self.effect.spaceBackend, stub, @"a plugin's own backend is not replaced");
}

/*! @abstract A scene template captured into plugin state is recreated in the per-render scene as an independent copy that keeps its child geometry. */
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
