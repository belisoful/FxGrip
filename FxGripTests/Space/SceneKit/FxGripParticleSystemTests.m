/*!
	@file       FxGripParticleSystemTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParticleSystemTests
	@abstract   Tests for FxGripParticleSystem, the deterministic SCNParticleSystem subclass.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the class is a drop-in SCNParticleSystem, copies properties from a source system, and drives every reimplemented variation from its seed. A seed reproduces its rendered frame, different seeds diverge, and a secure-coding round trip preserves the seeded variation. A spreading angle at or past the cap keeps the particles bounded.
*/

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <SceneKit/SceneKit.h>
#import <simd/simd.h>
#import <FxGrip/FxGripParticleSystem.h>
#import <FxGrip/FxGripSceneKitPhysicsBackend.h>

@interface FxGripParticleSystemTests : XCTestCase
@property (nonatomic, strong) id<MTLDevice> device;
@end

@implementation FxGripParticleSystemTests

- (void)setUp
{
	[super setUp];
	self.device = MTLCreateSystemDefaultDevice();
}

/*! @abstract FxGripParticleSystem is a kind of SCNParticleSystem, so it substitutes for the stock system on an SCNNode. */
- (void)testIsDropInSubclassOfSCNParticleSystem
{
	FxGripParticleSystem *system = [FxGripParticleSystem.alloc init];
	XCTAssertTrue([system isKindOfClass:SCNParticleSystem.class]);
}

/*! @abstract -initWithParticleSystem: copies the source system's birth rate and particle life span onto the new instance. */
- (void)testInitWithParticleSystemCopiesProperties
{
	SCNParticleSystem *source = [SCNParticleSystem particleSystem];
	source.birthRate = 321.0;
	source.particleLifeSpan = 4.0;
	source.emittingDirection = SCNVector3Make(0.0, 1.0, 0.0);

	FxGripParticleSystem *copy = [FxGripParticleSystem.alloc initWithParticleSystem:source];
	XCTAssertEqualWithAccuracy(copy.birthRate, 321.0, 1e-6);
	XCTAssertEqualWithAccuracy(copy.particleLifeSpan, 4.0, 1e-6);
}

- (id<MTLTexture>)renderTargetOfSize:(NSUInteger)size
{
	MTLTextureDescriptor *descriptor =
		[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:size height:size mipmapped:NO];
	descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	descriptor.storageMode = MTLStorageModeShared;
	return [self.device newTextureWithDescriptor:descriptor];
}

- (FxGripParticleSystem *)particleSystemWithSeed:(uint32_t)seed
{
	FxGripParticleSystem *particles = [FxGripParticleSystem.alloc init];
	particles.seed = seed;
	particles.birthRate = 400.0;
	particles.emissionDuration = 1.0;
	particles.loops = YES;
	particles.particleLifeSpan = 2.0;
	particles.particleVelocity = 6.0;
	particles.emittingDirection = SCNVector3Make(0.0, 1.0, 0.0);
	particles.acceleration = SCNVector3Make(0.0, -9.8, 0.0);
	particles.particleColor = [NSColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
	particles.particleSize = 0.3;
	// Every reimplemented variation, all driven deterministically by the seed.
	particles.particleVelocityVariation = 4.0;
	particles.spreadingAngle = 0.6;
	particles.particleSizeVariation = 0.2;
	particles.particleLifeSpanVariation = 0.5;
	particles.particleAngleVariation = 1.0;
	particles.particleColorVariation = SCNVector4Make(0.5, 0.5, 0.5, 0.0);
	return particles;
}

- (SCNScene *)sceneWithParticleSystem:(SCNParticleSystem *)particles pointOfView:(SCNNode **)outPOV
{
	SCNScene *scene = [SCNScene scene];

	SCNNode *emitter = [SCNNode node];
	[emitter addParticleSystem:particles];
	[scene.rootNode addChildNode:emitter];

	SCNNode *cameraNode = [SCNNode node];
	cameraNode.camera = [SCNCamera camera];
	cameraNode.position = SCNVector3Make(0.0, 2.0, 20.0);
	[scene.rootNode addChildNode:cameraNode];

	if (outPOV != NULL) { *outPOV = cameraNode; }
	return scene;
}

- (NSData *)renderSeed:(uint32_t)seed withBackend:(FxGripSceneKitPhysicsBackend *)backend size:(NSUInteger)size
{
	return [self renderParticleSystem:[self particleSystemWithSeed:seed] withBackend:backend size:size];
}

- (NSData *)renderParticleSystem:(SCNParticleSystem *)particles withBackend:(FxGripSceneKitPhysicsBackend *)backend size:(NSUInteger)size
{
	SCNNode *pov = nil;
	SCNScene *scene = [self sceneWithParticleSystem:particles pointOfView:&pov];
	id<MTLTexture> texture = [self renderTargetOfSize:size];

	NSError *error = nil;
	XCTAssertTrue([backend renderScene:scene pointOfView:pov toTexture:texture atTime:0.5 error:&error], @"%@", error);

	NSUInteger bytesPerRow = size * 4;
	NSMutableData *pixels = [NSMutableData dataWithLength:bytesPerRow * size];
	[texture getBytes:pixels.mutableBytes bytesPerRow:bytesPerRow fromRegion:MTLRegionMake2D(0, 0, size, size) mipmapLevel:0];
	return pixels;
}

/*! @abstract Two renders that share a seed produce byte-identical frames. */
- (void)testSameSeedRendersIdenticalPixels
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;
	backend.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

	const NSUInteger size = 64;
	NSData *first = [self renderSeed:7 withBackend:backend size:size];
	NSData *second = [self renderSeed:7 withBackend:backend size:size];

	XCTAssertEqualObjects(first, second, @"the same seed reproduces the same frame");
}

/*! @abstract Two renders with different seeds produce different frames. */
- (void)testDifferentSeedsProduceDifferentFrames
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;
	backend.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

	const NSUInteger size = 64;
	NSData *seven = [self renderSeed:7 withBackend:backend size:size];
	NSData *eight = [self renderSeed:8 withBackend:backend size:size];

	XCTAssertNotEqualObjects(seven, eight, @"a different seed varies the simulation");
}

- (FxGripParticleSystem *)roundTripThroughSecureArchive:(FxGripParticleSystem *)particles
{
	NSError *error = nil;
	NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:particles requiringSecureCoding:YES error:&error];
	XCTAssertNotNil(archive, @"%@", error);
	FxGripParticleSystem *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripParticleSystem.class fromData:archive error:&error];
	XCTAssertNotNil(decoded, @"%@", error);
	return decoded;
}

/*! @abstract A secure-coding round trip returns an FxGripParticleSystem with the same seed. */
- (void)testSecureCodingRoundTripPreservesClassAndSeed
{
	FxGripParticleSystem *decoded = [self roundTripThroughSecureArchive:[self particleSystemWithSeed:42]];
	XCTAssertTrue([decoded isMemberOfClass:FxGripParticleSystem.class]);
	XCTAssertEqual(decoded.seed, 42u);
}

/*! @abstract A decoded system renders the same frame as the system it was archived from, so the captured variation and birth block survive the archive. */
- (void)testSecureCodingRoundTripRendersIdenticalPixels
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;
	backend.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

	const NSUInteger size = 64;
	NSData *original = [self renderParticleSystem:[self particleSystemWithSeed:7] withBackend:backend size:size];
	NSData *decoded = [self renderParticleSystem:[self roundTripThroughSecureArchive:[self particleSystemWithSeed:7]] withBackend:backend size:size];
	XCTAssertEqualObjects(original, decoded, @"the archive preserves the seeded variation");

	FxGripParticleSystem *unvaried = [self particleSystemWithSeed:7];
	unvaried.particleVelocityVariation = 0.0;
	unvaried.spreadingAngle = 0.0;
	NSData *withoutVariation = [self renderParticleSystem:unvaried withBackend:backend size:size];
	XCTAssertNotEqualObjects(original, withoutVariation, @"the variation is visible, so its survival is what the identical frame proves");
}

/*! @abstract -copy returns an FxGripParticleSystem with the same seed, so a copied system stays the deterministic subclass. */
- (void)testCopyPreservesClassAndSeed
{
	FxGripParticleSystem *copy = [[self particleSystemWithSeed:7] copy];
	XCTAssertTrue([copy isMemberOfClass:FxGripParticleSystem.class]);
	XCTAssertEqual(copy.seed, 7u);
}

/*! @abstract A copied system renders the same frame as its source, so -copy reinstalls the seeded variation and birth block that SCNParticleSystem's own copy drops. */
- (void)testCopyRendersIdenticalPixels
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;
	backend.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

	const NSUInteger size = 64;
	NSData *original = [self renderParticleSystem:[self particleSystemWithSeed:7] withBackend:backend size:size];
	NSData *copied = [self renderParticleSystem:[[self particleSystemWithSeed:7] copy] withBackend:backend size:size];
	XCTAssertEqualObjects(original, copied, @"a copy preserves the seeded variation");
}

#pragma mark Spreading angle

// Renders a burst at the given spreading angle and returns the largest particle velocity magnitude
// and position magnitude seen across the simulation. A post-dynamics modifier samples the live
// particle buffers, which is the only way to observe particle state from outside the system.
- (void)renderSpreadingAngle:(CGFloat)angle
				 maxVelocity:(float *)outMaxVelocity
				 maxPosition:(float *)outMaxPosition
{
	FxGripParticleSystem *particles = [FxGripParticleSystem.alloc init];
	particles.seed = 7;
	particles.birthRate = 200.0;
	particles.emissionDuration = 0.1;
	particles.loops = NO;
	particles.particleLifeSpan = 100.0;
	particles.particleVelocity = 6.0;
	particles.particleSize = 0.3;
	particles.particleColor = [NSColor whiteColor];
	particles.emittingDirection = SCNVector3Make(0.0, 1.0, 0.0);
	particles.spreadingAngle = angle;

	__block float maxVelocity = 0.0f;
	__block float maxPosition = 0.0f;
	[particles addModifierForProperties:@[SCNParticlePropertyPosition, SCNParticlePropertyVelocity]
								atStage:SCNParticleModifierStagePostDynamics
							  withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride,
										  NSInteger start, NSInteger end, float deltaTime) {
		for (NSInteger i = start; i < end; i++) {
			const float *p = (const float *)((uintptr_t)data[0] + dataStride[0] * (NSUInteger)i);
			const float *v = (const float *)((uintptr_t)data[1] + dataStride[1] * (NSUInteger)i);
			maxPosition = MAX(maxPosition, simd_length(simd_make_float3(p[0], p[1], p[2])));
			maxVelocity = MAX(maxVelocity, simd_length(simd_make_float3(v[0], v[1], v[2])));
		}
	}];

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;
	backend.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
	[self renderParticleSystem:particles withBackend:backend size:64];

	*outMaxVelocity = maxVelocity;
	*outMaxPosition = maxPosition;
}

/*!
	@abstract	A spreading angle just under pi produces finite, bounded particle velocities and positions.
	@discussion	The seeded spread scales the birth velocity by the tangent of the half-angle, which
				diverges as the angle approaches pi. The capped angle keeps the tangent under 64, so a
				particle velocity of 6 stays under 6 * 64 * sqrt(3), and the positions stay in the range
				that velocity reaches over the rendered interval. */
- (void)testSpreadingAngleNearPiKeepsParticlesBounded
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}

	float maxVelocity = 0.0f;
	float maxPosition = 0.0f;
	[self renderSpreadingAngle:3.14159 maxVelocity:&maxVelocity maxPosition:&maxPosition];

	XCTAssertGreaterThan(maxVelocity, 0.0f, @"the render emitted particles, so the bounds mean something");
	XCTAssertTrue(isfinite(maxVelocity), @"a pi spread gives a finite birth velocity");
	XCTAssertTrue(isfinite(maxPosition));
	XCTAssertLessThan(maxVelocity, 1000.0f, @"the capped half-angle tangent bounds the birth velocity");
	XCTAssertLessThan(maxPosition, 1000.0f, @"a bounded velocity keeps the particles near the emitter");
}

/*! @abstract Every spreading angle at or past the cap spreads the same, so the cap holds for any angle above it. */
- (void)testSpreadingAnglesAboveTheCapSpreadIdentically
{
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}

	float nearPiVelocity = 0.0f, nearPiPosition = 0.0f;
	float pastPiVelocity = 0.0f, pastPiPosition = 0.0f;
	[self renderSpreadingAngle:3.14159 maxVelocity:&nearPiVelocity maxPosition:&nearPiPosition];
	[self renderSpreadingAngle:4.0 * M_PI maxVelocity:&pastPiVelocity maxPosition:&pastPiPosition];

	XCTAssertEqualWithAccuracy(pastPiVelocity, nearPiVelocity, 1e-3);
	XCTAssertEqualWithAccuracy(pastPiPosition, nearPiPosition, 1e-3);
}

@end
