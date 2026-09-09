/*!
	@file       SCNPhysicsField+FxGripInteractionTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     SCNPhysicsField+FxGripInteractionTests
	@abstract   Tests for the inter-particle force shaped as a SceneKit physics field.
	@discussion Introduced in FxGrip 0.1.0. The facade is checked at both seams: the factory and the
	            binding that installs the companion modifier, and the rendered result, where an
	            attractive field draws a burst of particles into a tighter cloud than the same burst
	            with no field, reproducibly.
*/

#import <XCTest/XCTest.h>
#import <SceneKit/SceneKit.h>
#import <Metal/Metal.h>
#import <FxGrip/FxGripParticleInteraction.h>
#import <FxGrip/SCNPhysicsField+FxGripInteraction.h>
#import <FxGrip/SCNParticleSystem+FxGripInteraction.h>
#import <FxGrip/FxGripParticleSystem.h>
#import <FxGrip/FxGripSceneKitPhysicsBackend.h>
#import "../../../FxGrip/Space/SceneKit/FxGripInteractionFieldState.h"

@interface SCNPhysicsField_FxGripInteractionTests : XCTestCase
@property (nonatomic, strong) id<MTLDevice> device;
@end

@implementation SCNPhysicsField_FxGripInteractionTests

- (void)setUp
{
	[super setUp];
	self.device = MTLCreateSystemDefaultDevice();
}

#pragma mark Factory and binding

/*! @abstract The factory returns a field that carries a copy of the configuration. */
- (void)testFactoryCarriesTheInteraction
{
	FxGripParticleInteraction *config = [FxGripParticleInteraction gravityWithStrength:2.5];
	config.softening = 0.4;
	SCNPhysicsField *field = [SCNPhysicsField particleInteractionFieldWithInteraction:config];
	XCTAssertNotNil(field);
	XCTAssertNotNil(field.particleInteraction);
	XCTAssertEqual(field.particleInteraction.kind, FxGripParticleInteractionKindGravity);
	XCTAssertEqualWithAccuracy(field.particleInteraction.gravityStrength, 2.5, 1e-9);
	XCTAssertEqualWithAccuracy(field.particleInteraction.softening, 0.4, 1e-9);
	// Mutating the caller's configuration afterwards does not reach the field.
	config.gravityStrength = 99.0;
	XCTAssertEqualWithAccuracy(field.particleInteraction.gravityStrength, 2.5, 1e-9);
}

/*! @abstract Any other physics field is not a particle interaction field and cannot be bound. */
- (void)testOtherFieldsAreNotInteractionFields
{
	SCNPhysicsField *drag = [SCNPhysicsField dragField];
	XCTAssertNil(drag.particleInteraction);
	SCNParticleSystem *system = [SCNParticleSystem particleSystem];
	XCTAssertFalse([drag bindParticleInteractionToParticleSystem:system]);
	XCTAssertFalse(system.affectedByPhysicsFields);
}

/*! @abstract Binding makes the system respond to fields, records the field, and installs the modifier. */
- (void)testBindingPreparesTheSystem
{
	SCNPhysicsField *field =
		[SCNPhysicsField particleInteractionFieldWithInteraction:[FxGripParticleInteraction gravityWithStrength:1.0]];
	SCNParticleSystem *system = [SCNParticleSystem particleSystem];
	system.affectedByPhysicsFields = NO;
	XCTAssertNil(system.boundInteractionField);

	XCTAssertTrue([field bindParticleInteractionToParticleSystem:system]);
	XCTAssertTrue(system.affectedByPhysicsFields);
	XCTAssertEqual(system.boundInteractionField, field);

	// Binding twice replaces the modifier rather than stacking a second one.
	XCTAssertTrue([field bindParticleInteractionToParticleSystem:system]);
	XCTAssertEqual(system.boundInteractionField, field);

	[field unbindParticleInteractionFromParticleSystem:system];
	XCTAssertNil(system.boundInteractionField);
	XCTAssertTrue(system.affectedByPhysicsFields, @"unbinding leaves the system responding to other fields");
}

/*! @abstract Several systems feed one field, and each keeps its place in the bind order. */
- (void)testSeveralSystemsFeedOneField
{
	SCNPhysicsField *field =
		[SCNPhysicsField particleInteractionFieldWithInteraction:[FxGripParticleInteraction gravityWithStrength:1.0]];
	SCNParticleSystem *first = [SCNParticleSystem particleSystem];
	SCNParticleSystem *second = [SCNParticleSystem particleSystem];

	XCTAssertTrue([field bindParticleInteractionToParticleSystem:first]);
	XCTAssertTrue([field bindParticleInteractionToParticleSystem:second]);
	XCTAssertEqual(first.boundInteractionField, field);
	XCTAssertEqual(second.boundInteractionField, field);

	[field unbindParticleInteractionFromParticleSystem:first];
	XCTAssertNil(first.boundInteractionField);
	XCTAssertEqual(second.boundInteractionField, field, @"the other system stays bound");
}

/*! @abstract Binding a system to a second field detaches it from the first. */
- (void)testBindingToAnotherFieldMovesTheSystem
{
	SCNPhysicsField *first =
		[SCNPhysicsField particleInteractionFieldWithInteraction:[FxGripParticleInteraction gravityWithStrength:1.0]];
	SCNPhysicsField *second =
		[SCNPhysicsField particleInteractionFieldWithInteraction:[FxGripParticleInteraction gravityWithStrength:2.0]];
	SCNParticleSystem *system = [SCNParticleSystem particleSystem];

	XCTAssertTrue([first bindParticleInteractionToParticleSystem:system]);
	XCTAssertTrue([second bindParticleInteractionToParticleSystem:system]);
	XCTAssertEqual(system.boundInteractionField, second);
	XCTAssertEqual([FxGripInteractionFieldState stateForPhysicsField:first].boundSystems.count, 0u,
				   @"the first field no longer counts the system as a source");
	XCTAssertEqualObjects([FxGripInteractionFieldState stateForPhysicsField:second].boundSystems, @[system]);
}

/*! @abstract Binding a node reaches the systems on it and its descendants, skipping self-acting ones. */
- (void)testBindingANodeReachesItsSubtree
{
	SCNPhysicsField *field =
		[SCNPhysicsField particleInteractionFieldWithInteraction:[FxGripParticleInteraction gravityWithStrength:1.0]];

	SCNNode *root = [SCNNode node];
	SCNParticleSystem *onRoot = [SCNParticleSystem particleSystem];
	[root addParticleSystem:onRoot];

	SCNNode *child = [SCNNode node];
	SCNParticleSystem *onChild = [SCNParticleSystem particleSystem];
	[child addParticleSystem:onChild];
	[root addChildNode:child];

	SCNNode *grandchild = [SCNNode node];
	SCNParticleSystem *selfActing = [SCNParticleSystem particleSystem];
	selfActing.particleInteraction = [FxGripParticleInteraction gravityWithStrength:5.0];
	[grandchild addParticleSystem:selfActing];
	[child addChildNode:grandchild];

	XCTAssertEqual([field bindParticleInteractionToParticleSystemsInNode:root], 2u);
	XCTAssertEqual(onRoot.boundInteractionField, field);
	XCTAssertEqual(onChild.boundInteractionField, field);
	XCTAssertNil(selfActing.boundInteractionField, @"a system with its own interaction is left alone");
}

#pragma mark Rendered behavior

// Renders a seeded burst through the deterministic physics backend, optionally under an attractive
// particle interaction field, and returns the root-mean-square radius of the cloud at the last step.
// Rendering is what drives emission, and the backend resets and replays fixed steps, so the value is
// reproducible.
- (double)cloudRadiusWithField:(BOOL)useField gravity:(CGFloat)gravity
{
	__block double lastRadius = 0.0;

	SCNScene *scene = [SCNScene scene];
	FxGripParticleSystem *system = [FxGripParticleSystem.alloc init];
	system.seed = 11;
	system.birthRate = 200.0;
	system.loops = NO;
	system.emissionDuration = 0.05;
	system.particleLifeSpan = 100.0;
	system.particleMass = 1.0;
	system.particleVelocity = 5.0;
	system.particleVelocityVariation = 2.0;
	system.spreadingAngle = 1.0;
	system.particleSize = 0.2;
	system.particleColor = NSColor.whiteColor;

	// A reader at the last stage, so it sees the positions the step settled on.
	[system addModifierForProperties:@[SCNParticlePropertyPosition]
							 atStage:SCNParticleModifierStagePostCollision
						   withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride,
									   NSInteger start, NSInteger end, float deltaTime) {
		double sum = 0.0;
		for (NSInteger i = start; i < end; i++) {
			const float *p = (const float *)((uintptr_t)data[0] + dataStride[0] * (NSUInteger)i);
			sum += (double)p[0] * p[0] + (double)p[1] * p[1] + (double)p[2] * p[2];
		}
		lastRadius = end > start ? sqrt(sum / (double)(end - start)) : 0.0;
	}];

	SCNNode *emitter = [SCNNode node];
	[emitter addParticleSystem:system];
	[scene.rootNode addChildNode:emitter];

	if (useField) {
		FxGripParticleInteraction *config = [FxGripParticleInteraction gravityWithStrength:gravity];
		config.softening = 0.5;
		SCNPhysicsField *field = [SCNPhysicsField particleInteractionFieldWithInteraction:config];
		XCTAssertTrue([field bindParticleInteractionToParticleSystem:system]);
		SCNNode *fieldNode = [SCNNode node];
		fieldNode.physicsField = field;
		[scene.rootNode addChildNode:fieldNode];
	}

	SCNNode *cameraNode = [SCNNode node];
	cameraNode.camera = [SCNCamera camera];
	cameraNode.position = SCNVector3Make(0.0, 0.0, 20.0);
	[scene.rootNode addChildNode:cameraNode];

	MTLTextureDescriptor *descriptor =
		[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:64 height:64 mipmapped:NO];
	descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	descriptor.storageMode = MTLStorageModeShared;

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;
	backend.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
	NSError *error = nil;
	XCTAssertTrue([backend renderScene:scene
						   pointOfView:cameraNode
							 toTexture:[self.device newTextureWithDescriptor:descriptor]
								atTime:1.0
								 error:&error], @"%@", error);
	return lastRadius;
}

/*! @abstract An attractive interaction field pulls the burst into a tighter cloud than no field does. */
- (void)testFieldDrawsTheCloudTogether
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}
	const double freeRadius = [self cloudRadiusWithField:NO gravity:0.0];
	const double heldRadius = [self cloudRadiusWithField:YES gravity:3.0];
	XCTAssertGreaterThan(freeRadius, 0.0, @"the burst emitted and spread");
	XCTAssertLessThan(heldRadius, freeRadius, @"mutual gravity holds the cloud in");
}

/*! @abstract Two renders under the same interaction field settle on the same cloud, bit for bit. */
- (void)testFieldIsDeterministic
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}
	const double first = [self cloudRadiusWithField:YES gravity:3.0];
	const double second = [self cloudRadiusWithField:YES gravity:3.0];
	XCTAssertEqual(first, second, @"the field reproduces the same simulation");
}

@end
