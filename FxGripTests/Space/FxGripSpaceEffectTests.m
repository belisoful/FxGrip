/*!
	@file       FxGripSpaceEffectTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripSpaceEffectTests
	@abstract   Tests for FxGripSpaceEffect, the engine-neutral base of a 3D Space effect.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the whole-frame render flags, the capture
	            ordering of the engine and plugin hooks, the inter-particle force round trip through
	            plugin state, and the decode helpers on a coder that holds no host state. Hook
	            subclasses stand in for an engine and for a plugin; no render engine is imported.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripSpaceEffect.h>
#import <FxGrip/FxGripParticleInteraction.h>
#import <FxGrip/FxGripErrors.h>

#pragma mark - Hook subclass

// Records the order in which the engine hook and the plugin seam run.
@interface FxGripSpaceHookEffect : FxGripSpaceEffect
@property (nonatomic, strong) NSMutableArray<NSString *> *calls;
@property (nonatomic, assign) BOOL engineFails;
@end

@implementation FxGripSpaceHookEffect
- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	self = [super initWithAPIManager:apiManager];
	if (self != nil) {
		_calls = [NSMutableArray array];
	}
	return self;
}
- (BOOL)encodeEngineStateIntoCoder:(NSCoder *)coder atTime:(CMTime)renderTime error:(NSError **)error
{
	[self.calls addObject:@"engine"];
	[coder encodeInteger:7 forKey:@"engineValue"];
	return !self.engineFails;
}
- (BOOL)encodeSceneParametersIntoCoder:(NSCoder *)coder atTime:(CMTime)renderTime error:(NSError **)error
{
	[self.calls addObject:@"plugin"];
	[coder encodeInteger:42 forKey:@"customValue"];
	return YES;
}
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

// Runs the capture pass on `effect` and returns a decoder over the plugin state it produced.
- (NSCoder *)decoderForCaptureOfEffect:(FxGripSpaceEffect *)effect
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	NSError *error = nil;
	XCTAssertTrue([effect pluginCoder:archiver atTime:kCMTimeZero quality:(FxQuality)kFxQuality_HIGH error:&error], @"%@", error);
	[archiver finishEncoding];
	NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:nil];
	decoder.requiresSecureCoding = NO;
	return decoder;
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

/*! @abstract The base capture hooks succeed and report no error without encoding anything. */
- (void)testDefaultHooksAreNoOps
{
	NSKeyedArchiver *coder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	NSError *error = nil;
	XCTAssertTrue([self.effect encodeSceneParametersIntoCoder:coder atTime:kCMTimeZero error:&error]);
	XCTAssertTrue([self.effect encodeEngineStateIntoCoder:coder atTime:kCMTimeZero error:&error]);
	XCTAssertNil(error);
}

/*! @abstract -pluginCoder: runs the engine hook before the plugin seam, and both values reach the plugin state. */
- (void)testCaptureRunsEngineHookThenPluginSeam
{
	FxGripSpaceHookEffect *effect = [FxGripSpaceHookEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	NSCoder *decoder = [self decoderForCaptureOfEffect:effect];

	XCTAssertEqualObjects(effect.calls, (@[@"engine", @"plugin"]));
	XCTAssertEqual([decoder decodeIntegerForKey:@"engineValue"], 7);
	XCTAssertEqual([decoder decodeIntegerForKey:@"customValue"], 42);
}

/*! @abstract A failing engine hook fails the capture and skips the plugin seam. */
- (void)testFailingEngineHookStopsTheCapture
{
	FxGripSpaceHookEffect *effect = [FxGripSpaceHookEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	effect.engineFails = YES;
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	NSError *error = nil;

	XCTAssertFalse([effect pluginCoder:archiver atTime:kCMTimeZero quality:(FxQuality)kFxQuality_HIGH error:&error]);
	XCTAssertEqualObjects(effect.calls, @[@"engine"]);
}

/*! @abstract The scene-wide interaction and the field configurations round-trip through plugin state. */
- (void)testParticleInteractionsRoundTripThroughPluginState
{
	FxGripParticleInteraction *interaction = [FxGripParticleInteraction gravityWithStrength:1.5];
	interaction.softening = 0.3;
	self.effect.particleInteraction = interaction;
	self.effect.particleInteractionFields = @{ @"emitter": [FxGripParticleInteraction gravityWithStrength:2.0] };

	NSCoder *decoder = [self decoderForCaptureOfEffect:self.effect];
	FxGripParticleInteraction *decoded = [self.effect decodeParticleInteractionFromCoder:decoder];
	XCTAssertEqualWithAccuracy(decoded.gravityStrength, 1.5, 1e-9);
	XCTAssertEqualWithAccuracy(decoded.softening, 0.3, 1e-9);

	NSDictionary<NSString *, FxGripParticleInteraction *> *fields = [self.effect decodeParticleInteractionFieldsFromCoder:decoder];
	XCTAssertEqual(fields.count, 1u);
	XCTAssertEqualWithAccuracy(fields[@"emitter"].gravityStrength, 2.0, 1e-9);
}

/*! @abstract An effect with no interactions leaves nothing in plugin state for the decoders to find. */
- (void)testNoParticleInteractionsDecodeToNil
{
	NSCoder *decoder = [self decoderForCaptureOfEffect:self.effect];
	XCTAssertNil([self.effect decodeParticleInteractionFromCoder:decoder]);
	XCTAssertNil([self.effect decodeParticleInteractionFieldsFromCoder:decoder]);
}

/*! @abstract Without host state the transform decoders return NO and leave the output untouched. */
- (void)testTransformDecodersReportAbsentHostState
{
	NSCoder *decoder = [self decoderForCaptureOfEffect:self.effect];
	simd_float4x4 transform = matrix_identity_float4x4;
	transform.columns[3].x = 5.0f;

	XCTAssertFalse([self.effect decodeCameraTransform:&transform fromCoder:decoder]);
	XCTAssertFalse([self.effect decodeLayerTransform:&transform fromCoder:decoder]);
	XCTAssertEqual(transform.columns[3].x, 5.0f, @"an absent matrix leaves the output unchanged");
}

/*! @abstract Without the view-matrix samples the camera motion is zero. */
- (void)testCameraMotionIsZeroWithoutSamples
{
	NSCoder *decoder = [self decoderForCaptureOfEffect:self.effect];
	FxGripCameraMotion motion = [self.effect cameraMotionFromCoder:decoder];
	XCTAssertEqual(simd_length(motion.linearVelocity), 0.0f);
	XCTAssertEqual(simd_length(motion.angularVelocity), 0.0f);
}

/*! @abstract The space error carries the space-render code and the reason. */
- (void)testSpaceErrorCarriesCodeAndReason
{
	NSError *error = [self.effect spaceErrorWithReason:@"why"];
	XCTAssertNotNil(error.domain);
	XCTAssertEqual(error.code, kFxGripError_SpaceRenderFailure);
	XCTAssertEqualObjects(error.localizedDescription, @"why");
}

@end
