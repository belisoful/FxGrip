/*!
	@file       FxGripParticleSystemTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParticleSystemTests
	@abstract   Tests for FxGripParticleSystem, the deterministic SCNParticleSystem subclass.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the class is a drop-in SCNParticleSystem, copies properties from a source system, and drives every reimplemented variation from its seed. A seed reproduces its rendered frame, and different seeds diverge.
*/

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <SceneKit/SceneKit.h>
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

- (SCNScene *)particleSceneWithSeed:(uint32_t)seed pointOfView:(SCNNode **)outPOV
{
	SCNScene *scene = [SCNScene scene];

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
	SCNNode *pov = nil;
	SCNScene *scene = [self particleSceneWithSeed:seed pointOfView:&pov];
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

@end
