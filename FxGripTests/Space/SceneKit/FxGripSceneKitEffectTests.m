/*!
	@file       FxGripSceneKitEffectTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSceneKitEffectTests
	@abstract   Tests for FxGripSceneKitEffect, the SceneKit engine subclass that builds a per-render scene and delegates to a space backend.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the default and replaceable backend, the per-render scene and camera, the apply hook, the physics-bake backend upgrade, the scene-template round trip, and the per-render installation of inter-particle forces. Stub and hook subclasses stand in for a plugin's own space effect.
*/

#import <XCTest/XCTest.h>
#import <SceneKit/SceneKit.h>
#import <FxGrip/FxGripSceneKitEffect.h>
#import <FxGrip/FxGripSceneKitBackend.h>
#import <FxGrip/FxGripSceneKitPhysicsBackend.h>
#import <FxGrip/FxGripPhysicsSimulationStore.h>
#import <FxGrip/FxGripParticleInteraction.h>
#import <FxGrip/SCNParticleSystem+FxGripInteraction.h>
#import <FxGrip/SCNScene+FxGripInteraction.h>
#import <FxGrip/SCNPhysicsField+FxGripInteraction.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import "FxPlugStub.h"

#pragma mark - Stub backend

@interface FxGripSpaceStubBackend : NSObject <FxGripSceneKitBackend>
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

@interface FxGripSpaceSeamEffect : FxGripSceneKitEffect
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

@interface FxGripSpaceApplyEffect : FxGripSceneKitEffect
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

#pragma mark - Emitter subclass

// Adds one particle system in the apply hook, so the scene-wide interaction has a system to reach.
@interface FxGripSpaceEmitterEffect : FxGripSceneKitEffect
@property (nonatomic, strong) SCNParticleSystem *emittedSystem;
@property (nonatomic, strong) SCNNode *emitterNode;
@property (nonatomic, strong, nullable) FxGripParticleInteraction *systemInteraction;
@end

@implementation FxGripSpaceEmitterEffect
- (void)updateSceneContents:(SCNScene *)scene
				 cameraNode:(SCNNode *)cameraNode
				  fromCoder:(NSCoder *)coder
					 atTime:(CMTime)renderTime
			   cameraMotion:(FxGripCameraMotion)cameraMotion
{
	self.emittedSystem = [SCNParticleSystem particleSystem];
	self.emittedSystem.particleInteraction = self.systemInteraction;
	self.emitterNode = [SCNNode node];
	self.emitterNode.name = @"emitter";
	[self.emitterNode addParticleSystem:self.emittedSystem];
	[scene.rootNode addChildNode:self.emitterNode];
}
@end

#pragma mark - Template subclass

@interface FxGripSpaceTemplateEffect : FxGripSceneKitEffect
@property (nonatomic, strong) SCNNode *templateNode;
@end

@implementation FxGripSpaceTemplateEffect
- (SCNNode *)sceneTemplateNodeAtTime:(CMTime)renderTime { return self.templateNode; }
@end

#pragma mark - Tests

@interface FxGripSceneKitEffectTests : XCTestCase
@property (nonatomic, strong) FxGripSceneKitEffect *effect;
@end

@implementation FxGripSceneKitEffectTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripSceneKitEffect.alloc initWithAPIManager:(id _Nonnull)nil];
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

/*! @abstract The engine-neutral store seam installs on a physics backend and switches it to
	session-cache mode, which is how FxGripPhysicsBake reaches the engine without naming it. */
- (void)testInstallingASimulationStoreReachesThePhysicsBackend
{
	self.effect.physicsBakeEnabled = YES;
	FxGripPhysicsMemoryStore *store = [FxGripPhysicsMemoryStore.alloc init];

	XCTAssertTrue([self.effect installPhysicsSimulationStore:store]);

	FxGripSceneKitPhysicsBackend *backend = (FxGripSceneKitPhysicsBackend *)self.effect.spaceBackend;
	XCTAssertEqualObjects(backend.simulationStore, store);
	XCTAssertEqual(backend.simulationMode, FxGripPhysicsSimulationModeSessionCache);
}

/*! @abstract A backend that does not simulate refuses the store, which leaves the bake inert. */
- (void)testInstallingASimulationStoreRefusesOnAPlainBackend
{
	XCTAssertFalse(self.effect.physicsBakeEnabled);
	FxGripPhysicsMemoryStore *store = [FxGripPhysicsMemoryStore.alloc init];
	XCTAssertFalse([self.effect installPhysicsSimulationStore:store]);
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

#pragma mark Scene-wide particle interaction

// Runs the capture pass on `effect` and returns a decoder over the plugin state it produced.
- (NSCoder *)decoderForCaptureOfEffect:(FxGripSceneKitEffect *)effect
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	NSError *error = nil;
	XCTAssertTrue([effect pluginCoder:archiver atTime:kCMTimeZero quality:(FxQuality)kFxQuality_HIGH error:&error], @"%@", error);
	[archiver finishEncoding];
	NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:nil];
	decoder.requiresSecureCoding = NO;
	return decoder;
}

/*! @abstract The scene-wide interaction travels through plugin state and reaches the rendered scene. */
- (void)testParticleInteractionRoundTripsIntoTheRenderedScene
{
	FxGripSpaceEmitterEffect *effect = [FxGripSpaceEmitterEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	FxGripParticleInteraction *interaction = [FxGripParticleInteraction gravityWithStrength:1.5];
	interaction.softening = 0.3;
	effect.particleInteraction = interaction;
	XCTAssertEqualWithAccuracy(effect.particleInteraction.gravityStrength, 1.5, 1e-9);

	SCNNode *pov = nil;
	SCNScene *scene = [effect buildSceneWithCoder:[self decoderForCaptureOfEffect:effect]
									   sourceTile:nil atTime:kCMTimeZero pointOfView:&pov];
	XCTAssertNotNil(scene.particleInteraction, @"the scene carries the decoded default");
	XCTAssertEqualWithAccuracy(scene.particleInteraction.gravityStrength, 1.5, 1e-9);
	XCTAssertNotNil(effect.emittedSystem.particleInteraction, @"the reconciliation reached the emitter");
	XCTAssertEqualWithAccuracy(effect.emittedSystem.particleInteraction.softening, 0.3, 1e-9);
}

/*! @abstract An effect with no interaction leaves the scene and its particle systems untouched. */
- (void)testNoParticleInteractionLeavesTheSceneBare
{
	FxGripSpaceEmitterEffect *effect = [FxGripSpaceEmitterEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNil(effect.particleInteraction);

	SCNNode *pov = nil;
	SCNScene *scene = [effect buildSceneWithCoder:[self decoderForCaptureOfEffect:effect]
									   sourceTile:nil atTime:kCMTimeZero pointOfView:&pov];
	XCTAssertNil(scene.particleInteraction);
	XCTAssertNil(effect.emittedSystem.particleInteraction);
}

/*! @abstract A system that carries its own interaction keeps it against the scene-wide default. */
- (void)testSystemInteractionOverridesTheSceneDefault
{
	FxGripSpaceEmitterEffect *effect = [FxGripSpaceEmitterEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	effect.particleInteraction = [FxGripParticleInteraction gravityWithStrength:1.5];
	FxGripParticleInteraction *own = [FxGripParticleInteraction gravityWithStrength:9.0];
	effect.systemInteraction = own;

	SCNNode *pov = nil;
	SCNScene *scene = [effect buildSceneWithCoder:[self decoderForCaptureOfEffect:effect]
									   sourceTile:nil atTime:kCMTimeZero pointOfView:&pov];
	XCTAssertEqualWithAccuracy(scene.particleInteraction.gravityStrength, 1.5, 1e-9);
	XCTAssertEqualWithAccuracy(effect.emittedSystem.particleInteraction.gravityStrength, 9.0, 1e-9);
}

/*! @abstract A declared interaction field is recreated each render on its named node, with its sources bound. */
- (void)testParticleInteractionFieldIsInstalledOnItsNamedNode
{
	FxGripSpaceEmitterEffect *effect = [FxGripSpaceEmitterEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	FxGripParticleInteraction *interaction = [FxGripParticleInteraction gravityWithStrength:2.0];
	effect.particleInteractionFields = @{ @"emitter": interaction };

	SCNNode *pov = nil;
	SCNScene *scene = [effect buildSceneWithCoder:[self decoderForCaptureOfEffect:effect]
									   sourceTile:nil atTime:kCMTimeZero pointOfView:&pov];
	XCTAssertNotNil(scene);
	SCNPhysicsField *field = effect.emitterNode.physicsField;
	XCTAssertNotNil(field, @"the named node carries a field");
	XCTAssertEqualWithAccuracy(field.particleInteraction.gravityStrength, 2.0, 1e-9);
	XCTAssertEqual(effect.emittedSystem.boundInteractionField, field, @"the emitter feeds the field");
	XCTAssertTrue(effect.emittedSystem.affectedByPhysicsFields);
}

/*! @abstract A field entry naming a node the scene does not contain is skipped. */
- (void)testUnknownFieldNodeNameIsSkipped
{
	FxGripSpaceEmitterEffect *effect = [FxGripSpaceEmitterEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	effect.particleInteractionFields = @{ @"nosuchnode": [FxGripParticleInteraction gravityWithStrength:2.0] };

	SCNNode *pov = nil;
	SCNScene *scene = [effect buildSceneWithCoder:[self decoderForCaptureOfEffect:effect]
									   sourceTile:nil atTime:kCMTimeZero pointOfView:&pov];
	XCTAssertNotNil(scene);
	XCTAssertNil(effect.emitterNode.physicsField);
	XCTAssertNil(effect.emittedSystem.boundInteractionField);
}

/*! @abstract A system bound to a field is left alone by the scene-wide default. */
- (void)testFieldBoundSystemIsSkippedByTheSceneDefault
{
	FxGripSpaceEmitterEffect *effect = [FxGripSpaceEmitterEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	effect.particleInteractionFields = @{ @"emitter": [FxGripParticleInteraction gravityWithStrength:2.0] };
	effect.particleInteraction = [FxGripParticleInteraction gravityWithStrength:7.0];

	SCNNode *pov = nil;
	SCNScene *scene = [effect buildSceneWithCoder:[self decoderForCaptureOfEffect:effect]
									   sourceTile:nil atTime:kCMTimeZero pointOfView:&pov];
	XCTAssertEqualWithAccuracy(scene.particleInteraction.gravityStrength, 7.0, 1e-9,
							   @"the scene still carries its default");
	XCTAssertNotNil(effect.emittedSystem.boundInteractionField);
	XCTAssertNil(effect.emittedSystem.particleInteraction,
				 @"the default does not displace the field's force");
}

@end

#pragma mark - The render dispatch

/*! Records the scene, point of view, and time the effect hands the backend, and can refuse readiness. */
@interface FxGripSceneKitRecordingBackend : NSObject <FxGripSceneKitBackend>
@property (nonatomic, assign) BOOL ready;
@property (nonatomic, assign) BOOL renderSucceeds;
@property (nonatomic, assign) NSUInteger renderCount;
@property (nonatomic, strong, nullable) SCNScene *lastScene;
@property (nonatomic, strong, nullable) SCNNode *lastPointOfView;
@property (nonatomic, assign) CFTimeInterval lastSeconds;
@end

@implementation FxGripSceneKitRecordingBackend

- (instancetype)init
{
	self = [super init];
	if (self) {
		_ready = YES;
		_renderSucceeds = YES;
		_lastSeconds = -1.0;
	}
	return self;
}

- (BOOL)isReady { return self.ready; }
- (NSString *)backendIdentifier { return @"recording"; }

- (BOOL)renderScene:(SCNScene *)scene
		pointOfView:(SCNNode *)pointOfView
		  toTexture:(id<MTLTexture>)texture
			 atTime:(CFTimeInterval)seconds
			  error:(NSError **)error
{
	self.renderCount += 1;
	self.lastScene = scene;
	self.lastPointOfView = pointOfView;
	self.lastSeconds = seconds;
	return self.renderSucceeds;
}

@end

/*!
	Drives renderSceneFromCoder:sourceTile:toTexture:atTime:error:, which needs a destination Metal
	texture and, for the layer plane, a source FxImageTile. The FxPlugStub test framework supplies
	the tile class that FxPlug's binary-less SDK does not.
*/
@interface FxGripSceneKitEffectRenderTests : XCTestCase
@property (nonatomic, strong) FxGripSceneKitEffect *effect;
@property (nonatomic, strong) FxGripSceneKitRecordingBackend *backend;
@property (nonatomic, strong) id<MTLDevice> device;
@end

@implementation FxGripSceneKitEffectRenderTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripSceneKitEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	self.backend = [FxGripSceneKitRecordingBackend.alloc init];
	self.effect.spaceBackend = self.backend;
	self.device = MTLCreateSystemDefaultDevice();
}

- (void)tearDown
{
	self.effect = nil;
	self.backend = nil;
	self.device = nil;
	[super tearDown];
}

- (NSCoder *)emptyCoder
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
	[archiver finishEncoding];
	NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:nil];
	decoder.requiresSecureCoding = NO;
	return decoder;
}

- (id<MTLTexture>)destinationTexture
{
	MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
																						  width:16 height:16 mipmapped:NO];
	descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	return [self.device newTextureWithDescriptor:descriptor];
}

/*! @abstract A ready backend receives the built scene, its camera as the point of view, and the render time in seconds. */
- (void)testAReadyBackendReceivesTheSceneAndItsCamera
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	NSError *error = nil;

	BOOL rendered = [self.effect renderSceneFromCoder:[self emptyCoder]
										   sourceTile:nil
											toTexture:[self destinationTexture]
											   atTime:CMTimeMake(3, 2)
												error:&error];

	XCTAssertTrue(rendered);
	XCTAssertNil(error);
	XCTAssertEqual(self.backend.renderCount, (NSUInteger)1);
	XCTAssertNotNil(self.backend.lastScene);
	XCTAssertNotNil(self.backend.lastPointOfView, @"the camera node is the point of view");
	XCTAssertEqualWithAccuracy(self.backend.lastSeconds, 1.5, 1e-9);
}

/*! @abstract An invalid render time reaches the backend as zero seconds. */
- (void)testAnInvalidRenderTimeReachesTheBackendAsZero
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	NSError *error = nil;

	XCTAssertTrue([self.effect renderSceneFromCoder:[self emptyCoder]
										 sourceTile:nil
										  toTexture:[self destinationTexture]
											 atTime:kCMTimeInvalid
											  error:&error]);

	XCTAssertEqualWithAccuracy(self.backend.lastSeconds, 0.0, 1e-9);
}

/*! @abstract A backend that is not ready is bypassed for the base class's passthrough. */
- (void)testAnUnreadyBackendFallsBackToThePassthrough
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	self.backend.ready = NO;
	NSError *error = nil;

	BOOL rendered = [self.effect renderSceneFromCoder:[self emptyCoder]
										   sourceTile:nil
											toTexture:[self destinationTexture]
											   atTime:kCMTimeZero
												error:&error];

	XCTAssertTrue(rendered, @"the base passthrough succeeds with no source");
	XCTAssertNil(error);
	XCTAssertEqual(self.backend.renderCount, (NSUInteger)0);
}

/*! @abstract A backend that refuses the frame reports the refusal to the caller. */
- (void)testABackendThatRefusesTheFrameReportsFailure
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	self.backend.renderSucceeds = NO;
	NSError *error = nil;

	XCTAssertFalse([self.effect renderSceneFromCoder:[self emptyCoder]
										  sourceTile:nil
										   toTexture:[self destinationTexture]
											  atTime:kCMTimeZero
											   error:&error]);

	XCTAssertEqual(self.backend.renderCount, (NSUInteger)1);
}

/*! @abstract A source tile becomes a layer plane node in the scene handed to the backend. */
- (void)testASourceTileBecomesALayerPlaneInTheScene
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *source = [FxImageTile stubTileWithPixelBounds:((FxRect){ 0, 0, 16, 16 })
												  pixelFormat:kCVPixelFormatType_64RGBAHalf
													   device:self.device];
	NSError *error = nil;

	XCTAssertTrue([self.effect renderSceneFromCoder:[self emptyCoder]
										 sourceTile:source
										  toTexture:[self destinationTexture]
											 atTime:kCMTimeZero
											  error:&error]);

	__block BOOL foundPlane = NO;
	[self.backend.lastScene.rootNode enumerateChildNodesUsingBlock:^(SCNNode *node, BOOL *stop) {
		if ([node.geometry isKindOfClass:SCNPlane.class]) {
			foundPlane = YES;
			*stop = YES;
		}
	}];
	XCTAssertTrue(foundPlane, @"the source tile is presented as a plane");
}

/*! @abstract Each render builds an independent scene rather than reusing the one before it. */
- (void)testEachRenderBuildsAnIndependentScene
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	id<MTLTexture> texture = [self destinationTexture];

	[self.effect renderSceneFromCoder:[self emptyCoder] sourceTile:nil toTexture:texture atTime:kCMTimeZero error:NULL];
	SCNScene *first = self.backend.lastScene;
	[self.effect renderSceneFromCoder:[self emptyCoder] sourceTile:nil toTexture:texture atTime:kCMTimeZero error:NULL];
	SCNScene *second = self.backend.lastScene;

	XCTAssertEqual(self.backend.renderCount, (NSUInteger)2);
	XCTAssertNotNil(first);
	XCTAssertNotNil(second);
	XCTAssertNotEqual(first, second);
}

@end
