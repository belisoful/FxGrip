/*!
	@file       FxGripGradientParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripGradientParameterTests
	@abstract   Tests FxGripGradientParameter: its FxPlug type identity, the name-ID-flags
	            payload it hands the creation API, and the plugin-state round trip.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the flag forwarding, the
	            host-refusal result, the sample count and depth the value read asks of the
	            retrieval API, the bytes it encodes into a plugin-state coder, the gradient the
	            NSCoder category decodes back, and the Metal texture it builds from the samples.
*/

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <Metal/Metal.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripGradientParameter.h>
#import <FxGrip/NSCoder+FxPlug.h>

typedef void *(*FxGripGradientTestCreateDevice)(void);

static const FxParameterId kGradientTestParameter = 51;

@interface FxGripGradientParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripGradientParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamClassTestEffect.alloc init];
}

- (void)tearDown
{
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSDictionary *)call
{
	return self.effect.creationCall;
}

- (BOOL)add:(Class)parameterClass type:(NSString *)type extra:(NSDictionary *)extra
{
	NSDictionary *config = FxGripParamClassTestConfig(kGradientTestParameter, type, @"Levels", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (FxGripGradientParameter *)makeGradientParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kGradientTestParameter, kFxParameterType_Gradient, @"Levels", nil);
	return [FxGripGradientParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

/*! @abstract The class reports the FxPlug gradient type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripGradientParameter.parameterType, FxParameterType_Gradient);
	XCTAssertEqualObjects(FxGripGradientParameter.parameterTypeString, kFxParameterType_Gradient);
}

#pragma mark Creation payload

/*! @abstract A gradient hands the creation call only the name, ID, and flags. */
- (void)testGradientForwardsOnlyTheNameIDAndFlags
{
	XCTAssertTrue([self add:FxGripGradientParameter.class type:kFxParameterType_Gradient extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"gradient",
										@"name": @"Levels",
										@"id": @(kGradientTestParameter),
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract A gradient carries the declared flag into the flag bitmask sent to the host. */
- (void)testGradientCarriesTheConfiguredFlags
{
	NSArray *declared = @[kParameterFlagString_HIDDEN];
	NSDictionary *extra = @{kFxParameterProperty_Flags: declared};

	XCTAssertTrue([self add:FxGripGradientParameter.class type:kFxParameterType_Gradient extra:extra]);

	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_HIDDEN));
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripGradientParameter.class type:kFxParameterType_Gradient extra:nil]);
}

#pragma mark Values

/*! @abstract -valueAtTime: asks the retrieval API for the configured sample count and depth. */
- (void)testGradientValueAtTimeAsksForTheConfiguredSampleCountAndDepth
{
	FxGripGradientParameter *parameter = [self makeGradientParameter];
	parameter.samples = 8;
	parameter.byteDepth = 4;
	parameter.fxDepth = kFxDepth_FLOAT32;

	FxGripGradient *gradient = [parameter valueAtTime:FxGripParamClassTestTime(2, 30)];

	XCTAssertTrue(gradient != NULL);
	XCTAssertEqual(gradient->count, (NSUInteger)8);
	XCTAssertEqual(gradient->depth, kFxDepth_FLOAT32);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"gradient");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"samples"], @8);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"depth"], @(kFxDepth_FLOAT32));
}

/*! @abstract -valueAtTime: returns NULL when the retrieval read fails. */
- (void)testGradientValueAtTimeIsNullWhenTheReadFails
{
	FxGripGradientParameter *parameter = [self makeGradientParameter];
	parameter.samples = 4;
	parameter.byteDepth = 4;
	parameter.fxDepth = kFxDepth_FLOAT32;
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	XCTAssertTrue([parameter valueAtTime:FxGripParamClassTestTime(0, 1)] == NULL);
}

/*! @abstract A second value read reuses the parameter and issues a fresh retrieval read. */
- (void)testRepeatedGradientReadsReplaceTheBuffer
{
	FxGripGradientParameter *parameter = [self makeGradientParameter];
	parameter.samples = 4;
	parameter.byteDepth = 1;
	parameter.fxDepth = kFxDepth_UINT8;

	[parameter valueAtTime:FxGripParamClassTestTime(0, 1)];
	FxGripGradient *second = [parameter valueAtTime:FxGripParamClassTestTime(1, 30)];

	XCTAssertTrue(second != NULL);
	XCTAssertEqual(self.effect.apiManager.paramGetAPIv6.reads.count, (NSUInteger)2);
}

#pragma mark Plugin state

/*! Encodes the parameter into a plugin-state coder at a render time and returns the archive. */
- (NSData *)encodedStateForParameter:(FxGripGradientParameter *)parameter atTime:(CMTime)time
{
	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:NO];
	archiver.renderTime = time;
	[parameter encodeWithCoder:archiver];
	[archiver finishEncoding];
	return archiver.encodedData;
}

/*! Reopens an archive as a plugin-state coder at the same render time. */
- (NSKeyedUnarchiver *)stateCoderForData:(NSData *)data atTime:(CMTime)time
{
	NSError *error = nil;
	NSKeyedUnarchiver *unarchiver = [NSKeyedUnarchiver.alloc initForReadingFromData:data error:&error];
	XCTAssertNil(error);
	unarchiver.requiresSecureCoding = NO;
	unarchiver.renderTime = time;
	return unarchiver;
}

- (FxGripGradientParameter *)parameterWithSamples:(uint)samples
										 fxDepth:(FxDepth)depth
											fill:(unsigned char)fill
{
	FxGripGradientParameter *parameter = [self makeGradientParameter];
	parameter.samples = samples;
	parameter.fxDepth = depth;
	parameter.byteDepth = bytesFromFxDepth(depth);
	self.effect.apiManager.paramGetAPIv6.gradientFill = fill;
	return parameter;
}

- (id<MTLDevice>)metalDevice
{
	FxGripGradientTestCreateDevice create =
		(FxGripGradientTestCreateDevice)dlsym(RTLD_DEFAULT, "MTLCreateSystemDefaultDevice");
	if (create == NULL) {
		return nil;
	}
	return (__bridge_transfer id<MTLDevice>)create();
}

/*! @abstract A plain coder, which is no plugin-state encoder, reads no gradient from the host. */
- (void)testAPlainCoderEncodesNoGradient
{
	FxGripGradientParameter *parameter = [self parameterWithSamples:4 fxDepth:kFxDepth_FLOAT32 fill:0];
	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:NO];

	[parameter encodeWithCoder:archiver];

	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.reads, @[], @"no sample read");
}

/*! @abstract A plugin-state coder samples the gradient at its own render time and encodes the header and samples. */
- (void)testAPluginStateCoderEncodesTheSampledGradient
{
	FxGripGradientParameter *parameter = [self parameterWithSamples:8 fxDepth:kFxDepth_FLOAT32 fill:0x3F];

	NSData *data = [self encodedStateForParameter:parameter atTime:FxGripParamClassTestTime(21, 30)];

	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"gradient");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @21);
	XCTAssertGreaterThan(data.length, (NSUInteger)0);
}

/*! @abstract The decoded gradient carries the sample count and depth the parameter encoded. */
- (void)testTheDecodedGradientCarriesTheEncodedCountAndDepth
{
	FxGripGradientParameter *parameter = [self parameterWithSamples:8 fxDepth:kFxDepth_FLOAT32 fill:0x3F];
	CMTime time = FxGripParamClassTestTime(21, 30);
	NSData *data = [self encodedStateForParameter:parameter atTime:time];

	FxGripGradient *gradient = [[self stateCoderForData:data atTime:time]
								decodeGradientAtIndex:kGradientTestParameter];

	XCTAssertTrue(gradient != NULL);
	XCTAssertEqual(gradient->count, (NSUInteger)8);
	XCTAssertEqual(gradient->depth, kFxDepth_FLOAT32);
	// The stub host fills every component byte with the same value, so each float reads back the same.
	XCTAssertEqualWithAccuracy(gradient->samples[0].r, gradient->samples[7].a, 1e-12);
}

/*! @abstract An eight-bit gradient round-trips its sample bytes through the coder. */
- (void)testAnEightBitGradientRoundTripsItsSampleBytes
{
	FxGripGradientParameter *parameter = [self parameterWithSamples:5 fxDepth:kFxDepth_UINT8 fill:0xA5];
	CMTime time = FxGripParamClassTestTime(3, 24);
	NSData *data = [self encodedStateForParameter:parameter atTime:time];

	FxGripGradientUInt8 *gradient =
		(FxGripGradientUInt8 *)[[self stateCoderForData:data atTime:time]
								decodeGradientAtIndex:kGradientTestParameter];

	XCTAssertTrue(gradient != NULL);
	XCTAssertEqual(gradient->count, (NSUInteger)5);
	XCTAssertEqual(gradient->depth, kFxDepth_UINT8);
	XCTAssertEqual(gradient->samples[0].r, (unsigned char)0xA5);
	XCTAssertEqual(gradient->samples[0].a, (unsigned char)0xA5);
	// The sample payload the host wrote is four packed bytes per sample; read it as bytes,
	// because sizeof(FxGripUChar4) is not the packed sample stride.
	const unsigned char *payload = (const unsigned char *)gradient->samples;
	for (NSUInteger byte = 0; byte < 4 * 5; byte++) {
		XCTAssertEqual(payload[byte], (unsigned char)0xA5, @"byte %lu", (unsigned long)byte);
	}
}

/*! @abstract A coder that is no plugin-state encoder decodes no gradient. */
- (void)testAPlainCoderDecodesNoGradient
{
	FxGripGradientParameter *parameter = [self parameterWithSamples:4 fxDepth:kFxDepth_UINT8 fill:0x11];
	CMTime time = FxGripParamClassTestTime(0, 1);
	NSData *data = [self encodedStateForParameter:parameter atTime:time];
	NSError *error = nil;
	NSKeyedUnarchiver *unarchiver = [NSKeyedUnarchiver.alloc initForReadingFromData:data error:&error];
	unarchiver.requiresSecureCoding = NO;

	XCTAssertTrue([unarchiver decodeGradientAtIndex:kGradientTestParameter] == NULL);
}

/*! @abstract The decoded gradient builds a one-pixel-tall texture as wide as the sample count. */
- (void)testTheDecodedGradientBuildsAMatchingMetalTexture
{
	id<MTLDevice> device = [self metalDevice];
	if (device == nil) {
		XCTSkip(@"no Metal device on this machine");
	}
	FxGripGradientParameter *parameter = [self parameterWithSamples:6 fxDepth:kFxDepth_UINT8 fill:0x7F];
	CMTime time = FxGripParamClassTestTime(9, 30);
	NSData *data = [self encodedStateForParameter:parameter atTime:time];

	id<MTLTexture> texture = [[self stateCoderForData:data atTime:time]
							  decodeGradientAtIndex:kGradientTestParameter device:device];

	XCTAssertNotNil(texture);
	XCTAssertEqual(texture.width, (NSUInteger)6);
	XCTAssertEqual(texture.height, (NSUInteger)1);
	XCTAssertEqual(texture.pixelFormat, MTLPixelFormatRGBA8Unorm);
}

/*! @abstract A float gradient builds a float texture of the matching pixel format. */
- (void)testAFloatGradientBuildsAFloatTexture
{
	id<MTLDevice> device = [self metalDevice];
	if (device == nil) {
		XCTSkip(@"no Metal device on this machine");
	}
	FxGripGradientParameter *parameter = [self parameterWithSamples:4 fxDepth:kFxDepth_FLOAT32 fill:0x00];
	CMTime time = FxGripParamClassTestTime(1, 30);
	NSData *data = [self encodedStateForParameter:parameter atTime:time];

	id<MTLTexture> texture = [[self stateCoderForData:data atTime:time]
							  decodeGradientAtIndex:kGradientTestParameter device:device];

	XCTAssertNotNil(texture);
	XCTAssertEqual(texture.pixelFormat, MTLPixelFormatRGBA32Float);
	XCTAssertEqual(texture.width, (NSUInteger)4);
}

@end
