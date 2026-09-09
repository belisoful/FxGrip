/*!
	@file       FxGripParticleInteractionTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripParticleInteractionTests
	@abstract   Tests for the particle interaction value object and the SCNParticleSystem category.
	@discussion Introduced in FxGrip 0.1.0. The value object copies and archives its whole state and
	            maps its accuracy tier to the multipole order. The category installs and removes the
	            force from the pre-dynamics stage, and a gravity interaction bends the particle
	            velocities toward each other, deterministically.
*/

#import <XCTest/XCTest.h>
#import <SceneKit/SceneKit.h>
#import <Metal/Metal.h>
#import <FxGrip/FxGripParticleInteraction.h>
#import <FxGrip/SCNParticleSystem+FxGripInteraction.h>
#import <FxGrip/FxGripParticleSystem.h>
#import <FxGrip/FxGripSceneKitPhysicsBackend.h>

@interface FxGripParticleInteractionTests : XCTestCase
@end

@implementation FxGripParticleInteractionTests

#pragma mark Value object

/*! @abstract The kind is a bit field, so forces combine, and Lorentz is electric and magnetic together. */
- (void)testKindCombines
{
	FxGripParticleInteraction *i = [FxGripParticleInteraction new];
	i.kind = FxGripParticleInteractionKindElectric | FxGripParticleInteractionKindMagnetic;
	XCTAssertTrue(i.kind & FxGripParticleInteractionKindElectric);
	XCTAssertTrue(i.kind & FxGripParticleInteractionKindMagnetic);
	XCTAssertFalse(i.kind & FxGripParticleInteractionKindGravity);
}

/*! @abstract The accuracy tier sets the multipole order and acceptance ratio. */
- (void)testAccuracyMapsToOrder
{
	FxGripParticleInteraction *i = [FxGripParticleInteraction new];
	i.accuracy = FxGripParticleInteractionAccuracyDraft;
	XCTAssertEqual(i.expansionOrder, 2u);
	i.accuracy = FxGripParticleInteractionAccuracyStandard;
	XCTAssertEqual(i.expansionOrder, 4u);
	XCTAssertEqualWithAccuracy(i.theta, 0.5f, 1e-6f);
	i.accuracy = FxGripParticleInteractionAccuracyFine;
	XCTAssertEqual(i.expansionOrder, 6u);
}

/*! @abstract A copy and a secure-coding round trip preserve the whole state. */
- (void)testCopyAndCodingRoundTrip
{
	FxGripParticleInteraction *i = [FxGripParticleInteraction new];
	i.enabled = YES;
	i.kind = FxGripParticleInteractionKindGravity | FxGripParticleInteractionKindMagnetic;
	i.gravityStrength = 6.67e-3;
	i.electricStrength = 2.5;
	i.magneticStrength = 0.3;
	i.softening = 0.05;
	i.accuracy = FxGripParticleInteractionAccuracyFine;

	FxGripParticleInteraction *copy = [i copy];
	XCTAssertEqual(copy.enabled, i.enabled);
	XCTAssertEqual(copy.kind, i.kind);
	XCTAssertEqualWithAccuracy(copy.gravityStrength, i.gravityStrength, 1e-9);
	XCTAssertEqual(copy.accuracy, i.accuracy);

	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:i requiringSecureCoding:YES error:&error];
	XCTAssertNotNil(data, @"%@", error);
	FxGripParticleInteraction *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripParticleInteraction.class fromData:data error:&error];
	XCTAssertNotNil(decoded, @"%@", error);
	XCTAssertEqual(decoded.kind, i.kind);
	XCTAssertEqualWithAccuracy(decoded.softening, i.softening, 1e-9);
	XCTAssertEqualWithAccuracy(decoded.magneticStrength, i.magneticStrength, 1e-9);
	XCTAssertEqual(decoded.accuracy, i.accuracy);
}

#pragma mark Category installation

/*! @abstract Setting an enabled interaction installs a pre-dynamics modifier; nil removes it. */
- (void)testInstallAndRemove
{
	SCNParticleSystem *system = [SCNParticleSystem particleSystem];
	XCTAssertNil(system.particleInteraction);

	system.particleInteraction = [FxGripParticleInteraction gravityWithStrength:1.0];
	XCTAssertNotNil(system.particleInteraction);
	XCTAssertTrue(system.particleInteraction.enabled);

	// A disabled interaction removes the force.
	FxGripParticleInteraction *off = [FxGripParticleInteraction new];
	off.enabled = NO;
	system.particleInteraction = off;
	XCTAssertNotNil(system.particleInteraction);
	XCTAssertFalse(system.particleInteraction.enabled);

	system.particleInteraction = nil;
	XCTAssertNil(system.particleInteraction);
}

/*! @abstract An FxGripParticleSystem archives its interaction, so a system in a template stays configured. */
- (void)testInteractionSurvivesParticleSystemArchive
{
	FxGripParticleSystem *system = [FxGripParticleSystem.alloc init];
	system.seed = 7;
	FxGripParticleInteraction *g = [FxGripParticleInteraction gravityWithStrength:3.0];
	g.softening = 0.2;
	system.particleInteraction = g;

	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:system requiringSecureCoding:YES error:&error];
	XCTAssertNotNil(data, @"%@", error);
	FxGripParticleSystem *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripParticleSystem.class fromData:data error:&error];
	XCTAssertNotNil(decoded, @"%@", error);
	XCTAssertNotNil(decoded.particleInteraction, @"the interaction is restored");
	XCTAssertEqual(decoded.particleInteraction.kind, FxGripParticleInteractionKindGravity);
	XCTAssertEqualWithAccuracy(decoded.particleInteraction.gravityStrength, 3.0, 1e-9);
	XCTAssertEqualWithAccuracy(decoded.particleInteraction.softening, 0.2, 1e-9);
}

#pragma mark Force behavior

// Renders a burst of particles through the deterministic physics backend, with or without a gravity
// interaction installed, and returns the frame. Rendering (not a bare updateAtTime) is what drives
// SceneKit emission, and the backend resets and steps the systems, so the result is reproducible.
- (NSData *)renderWithGravity:(BOOL)gravity size:(NSUInteger)size device:(id<MTLDevice>)device
{
	SCNScene *scene = [SCNScene scene];
	// A deterministic (seeded) particle system, so the only variable between renders is the force.
	FxGripParticleSystem *system = [FxGripParticleSystem.alloc init];
	system.seed = 7;
	// Point emission with a seeded velocity spread: FxGripParticleSystem makes velocity variation
	// deterministic, but not a shape's surface sampling, so a point emitter keeps the burst reproducible
	// while still spreading the particles for the force to act on.
	system.birthRate = 120.0;
	system.loops = NO;
	system.emissionDuration = 0.1;
	system.particleLifeSpan = 100.0;
	system.particleMass = 1.0;
	system.particleVelocity = 4.0;
	system.particleVelocityVariation = 3.0;
	system.spreadingAngle = 0.5;
	system.particleSize = 0.3;
	system.particleColor = [NSColor whiteColor];
	if (gravity) {
		FxGripParticleInteraction *g = [FxGripParticleInteraction gravityWithStrength:0.05];
		g.softening = 0.3;
		system.particleInteraction = g;
	}

	SCNNode *emitter = [SCNNode node];
	[emitter addParticleSystem:system];
	[scene.rootNode addChildNode:emitter];
	SCNNode *cameraNode = [SCNNode node];
	cameraNode.camera = [SCNCamera camera];
	cameraNode.position = SCNVector3Make(0.0, 0.0, 20.0);
	[scene.rootNode addChildNode:cameraNode];

	MTLTextureDescriptor *descriptor =
		[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:size height:size mipmapped:NO];
	descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	descriptor.storageMode = MTLStorageModeShared;
	id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;
	backend.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
	NSError *error = nil;
	XCTAssertTrue([backend renderScene:scene pointOfView:cameraNode toTexture:texture atTime:0.5 error:&error], @"%@", error);

	NSUInteger bytesPerRow = size * 4;
	NSMutableData *pixels = [NSMutableData dataWithLength:bytesPerRow * size];
	[texture getBytes:pixels.mutableBytes bytesPerRow:bytesPerRow fromRegion:MTLRegionMake2D(0, 0, size, size) mipmapLevel:0];
	return pixels;
}

/*! @abstract Gravity changes the rendered frame, so the inter-particle force is actually applied. */
- (void)testGravityChangesTheRender
{
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	if (device == nil) {
		XCTSkip(@"No Metal device available");
	}
	const NSUInteger size = 96;
	NSData *withoutForce = [self renderWithGravity:NO size:size device:device];
	NSData *withGravity = [self renderWithGravity:YES size:size device:device];
	XCTAssertNotEqualObjects(withoutForce, withGravity, @"gravity moves the particles, changing the frame");
}

/*! @abstract Two renders with the same gravity interaction are byte-identical, so the force is deterministic. */
- (void)testGravityIsDeterministic
{
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	if (device == nil) {
		XCTSkip(@"No Metal device available");
	}
	const NSUInteger size = 96;
	NSData *first = [self renderWithGravity:YES size:size device:device];
	NSData *second = [self renderWithGravity:YES size:size device:device];
	XCTAssertEqualObjects(first, second, @"the same gravity interaction reproduces the same frame");
}

@end
