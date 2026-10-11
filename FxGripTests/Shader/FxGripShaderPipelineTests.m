/*!
	@file       FxGripShaderPipelineTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripShaderPipelineTests
	@abstract   Verifies the shader value snapshot, the reflected uniform and texture layout, the constant cache, and the render.
	@discussion Introduced in FxGrip 0.1.0. The value tests need no device. The pipeline tests compile
	            real Metal shaders and skip on a machine with no Metal device. The render tests draw
	            into RGBA32Float stub tiles and read the output back as exact floats. A pipeline whose
	            state build blocks on a semaphore shows that a build runs outside the cache lock.
*/

#import <XCTest/XCTest.h>
#import "FxPlugStub.h"
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripColorGamut.h>
#import <FxGrip/FxGripShaderPipeline.h>
#import "FxGripShaderTestSupport.h"

/*! A shader with a float, an rgb, and a point uniform, an integer constant, and an unbound struct member. */
static NSString *FxGripShaderPipelineGainSource(void)
{
	return FxGripShaderTestSource(
		@"{ parameters: ["
		@"  { id: 1, type: \"float\", name: \"Gain\", key: \"gain\" },"
		@"  { id: 2, type: \"rgb\", name: \"Tint\", key: \"tint\" },"
		@"  { id: 3, type: \"point\", name: \"Center\", key: \"center\" },"
		@"  { id: 4, type: \"integer\", name: \"Mode\", key: \"MODE\", constant: true },"
		@"] }",
		@"constant int MODE [[function_constant(0)]];\n"
		@"struct Uniforms { float gain; float3 tint; float2 center; float unbound; };\n"
		@"fragment float4 fxGripShaderFragment(FxGripShaderVertexOut in [[stage_in]],\n"
		@"                                     texture2d<float> source [[texture(0)]],\n"
		@"                                     constant Uniforms &uniforms [[buffer(0)]])\n"
		@"{\n"
		@"    constexpr sampler nearest(filter::nearest);\n"
		@"    float4 color = source.sample(nearest, in.texCoord);\n"
		@"    if (MODE == 1) {\n"
		@"        return float4(uniforms.tint, 1.0);\n"
		@"    }\n"
		@"    return float4(color.rgb * uniforms.gain, color.a);\n"
		@"}\n");
}

/*! A shader whose fragment function returns the given Metal expression and reads no uniforms. */
static NSString *FxGripShaderPipelineExpressionSource(NSString *colorSpace, NSString *expression)
{
	return FxGripShaderTestSource(
		[NSString stringWithFormat:@"{ colorSpace: %@ }", colorSpace],
		[NSString stringWithFormat:
			@"fragment float4 fxGripShaderFragment(FxGripShaderVertexOut in [[stage_in]],\n"
			@"                                     texture2d<float> source [[texture(0)]])\n"
			@"{\n"
			@"    constexpr sampler nearest(filter::nearest);\n"
			@"    float4 color = source.sample(nearest, in.texCoord);\n"
			@"    return %@;\n"
			@"}\n", expression]);
}

static float FxGripShaderPipelineReadFloat(NSData *data, NSUInteger offset)
{
	float value = 0.0f;
	[data getBytes:&value range:NSMakeRange(offset, sizeof(value))];
	return value;
}

static float FxGripShaderPipelineEncodeSRGB(float value)
{
	float magnitude = fabsf(value);
	float encoded = magnitude <= 0.0031308f ? magnitude * 12.92f : 1.055f * powf(magnitude, 1.0f / 2.4f) - 0.055f;
	return copysignf(encoded, value);
}

static float FxGripShaderPipelineDecodeSRGB(float value)
{
	float magnitude = fabsf(value);
	float decoded = magnitude <= 0.04045f ? magnitude / 12.92f : powf((magnitude + 0.055f) / 1.055f, 2.4f);
	return copysignf(decoded, value);
}

static simd_float3 FxGripShaderPipelineEncodeSRGB3(simd_float3 value)
{
	return simd_make_float3(FxGripShaderPipelineEncodeSRGB(value.x), FxGripShaderPipelineEncodeSRGB(value.y), FxGripShaderPipelineEncodeSRGB(value.z));
}

static simd_float3 FxGripShaderPipelineDecodeSRGB3(simd_float3 value)
{
	return simd_make_float3(FxGripShaderPipelineDecodeSRGB(value.x), FxGripShaderPipelineDecodeSRGB(value.y), FxGripShaderPipelineDecodeSRGB(value.z));
}

/*! A shader whose fragment function reads the tile description and returns the given Metal expression. */
static NSString *FxGripShaderPipelineTileSource(NSString *metadataBody, NSString *textures, NSString *expression)
{
	return FxGripShaderTestSource(metadataBody, [NSString stringWithFormat:
		@"fragment float4 fxGripShaderFragment(FxGripShaderVertexOut in [[stage_in]],\n"
		@"                                     %@\n"
		@"                                     constant FxGripShaderTile &tile [[buffer(1)]])\n"
		@"{\n"
		@"    constexpr sampler nearest(filter::nearest);\n"
		@"    return %@;\n"
		@"}\n", textures, expression]);
}

/*! A float tile with a uniform pixel scale and its inverse, as the host delivers a proxy-resolution tile. */
static FxImageTile *FxGripShaderPipelineScaledTile(FxRect bounds, double scaleX, double scaleY, simd_float4 fill)
{
	FxImageTile *tile = FxGripShaderTestFloatTile(bounds, fill);
	tile.pixelTransform = [FxMatrix44 stubMatrixWithScaleX:scaleX scaleY:scaleY translationX:0.0 translationY:0.0];
	tile.inversePixelTransform = [FxMatrix44 stubMatrixWithScaleX:1.0 / scaleX scaleY:1.0 / scaleY translationX:0.0 translationY:0.0];
	return tile;
}

/*! The pipeline's private state build, exposed so a subclass can block it. */
@interface FxGripShaderPipeline (FxGripShaderPipelineTesting)
- (nullable FxGripShaderPipelineState *)buildStateForDevice:(id<MTLDevice>)device
												pixelFormat:(MTLPixelFormat)pixelFormat
													 values:(FxGripShaderValues *)values
												  signature:(NSString *)signature
													  error:(NSError **)error;
@end

/*! Counts state builds, and holds the build of one signature until the test releases it. */
@interface FxGripShaderBlockingPipeline : FxGripShaderPipeline
@property (nonatomic, copy) NSString *blockedSignature;
@property (nonatomic, strong) dispatch_semaphore_t entered;
@property (nonatomic, strong) dispatch_semaphore_t released;
@property (nonatomic, strong) NSCountedSet<NSString *> *builds;
@end

@implementation FxGripShaderBlockingPipeline

- (nullable FxGripShaderPipelineState *)buildStateForDevice:(id<MTLDevice>)device
												pixelFormat:(MTLPixelFormat)pixelFormat
													 values:(FxGripShaderValues *)values
												  signature:(NSString *)signature
													  error:(NSError **)error
{
	@synchronized (self.builds) {
		[self.builds addObject:signature];
	}
	if ([signature isEqualToString:self.blockedSignature]) {
		dispatch_semaphore_signal(self.entered);
		dispatch_semaphore_wait(self.released, DISPATCH_TIME_FOREVER);
	}
	return [super buildStateForDevice:device pixelFormat:pixelFormat values:values signature:signature error:error];
}

@end

@interface FxGripShaderPipelineTests : XCTestCase
@end

@implementation FxGripShaderPipelineTests

- (FxGripShaderPipeline *)pipelineWithSource:(NSString *)source
{
	NSError *error = nil;
	FxGripShaderMetadata *metadata = [FxGripShaderMetadata metadataWithSource:source error:&error];
	XCTAssertNotNil(metadata, @"%@", error);
	return [[FxGripShaderPipeline alloc] initWithSource:source metadata:metadata fragmentFunctionName:kFxGripShaderFragmentFunctionName];
}

- (FxGripShaderValues *)valuesWithComponents:(NSDictionary<NSString *, NSArray<NSNumber *> *> *)components
{
	FxGripShaderValues *values = [FxGripShaderValues new];
	for (NSString *key in components) {
		[values setComponents:components[key] forKey:key];
	}
	return values;
}

- (nullable FxGripShaderPipelineState *)stateForSource:(NSString *)source
												values:(FxGripShaderValues *)values
												 error:(NSError **)error
{
	return [[self pipelineWithSource:source] stateForDevice:FxGripShaderTestDevice()
											   pixelFormat:MTLPixelFormatRGBA32Float
													values:values
													 error:error];
}

- (NSError *)stateFailureForSource:(NSString *)source values:(FxGripShaderValues *)values code:(NSInteger)code
{
	NSError *error = nil;
	XCTAssertNil([self stateForSource:source values:values error:&error]);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, code, @"%@", error);
	return error;
}

- (BOOL)renderSource:(NSString *)source
		 destination:(FxImageTile *)destination
			 sources:(NSArray<FxImageTile *> *)sources
			  values:(FxGripShaderValues *)values
	   hostPrimaries:(FxColorPrimaries)hostPrimaries
		   colorInfo:(FxImageColorInfo)colorInfo
{
	NSError *error = nil;
	BOOL rendered = [[self pipelineWithSource:source] renderDestinationImage:destination
																sourceImages:sources
																	  values:values
															   hostPrimaries:hostPrimaries
																   colorInfo:colorInfo
																	   error:&error];
	XCTAssertTrue(rendered, @"%@", error);
	return rendered;
}

- (void)assertPixel:(simd_float4)pixel equals:(simd_float4)expected accuracy:(float)accuracy
{
	XCTAssertEqualWithAccuracy(pixel.x, expected.x, accuracy);
	XCTAssertEqualWithAccuracy(pixel.y, expected.y, accuracy);
	XCTAssertEqualWithAccuracy(pixel.z, expected.z, accuracy);
	XCTAssertEqualWithAccuracy(pixel.w, expected.w, accuracy);
}

#pragma mark Values

/*! @abstract A snapshot keeps up to four components per key, sorted by key, and an empty array removes the key. */
- (void)testValuesKeepUpToFourComponentsPerKey
{
	FxGripShaderValues *values = [FxGripShaderValues new];

	[values setComponents:@[@1, @2, @3, @4, @5] forKey:@"wide"];
	[values setDouble:0.5 forKey:@"alpha"];
	[values setComponents:@[@9] forKey:@"removed"];
	[values setComponents:@[] forKey:@"removed"];

	XCTAssertEqualObjects(values.keys, (@[@"alpha", @"wide"]));
	XCTAssertEqualObjects([values componentsForKey:@"wide"], (@[@1, @2, @3, @4]));
	XCTAssertEqualObjects([values componentsForKey:@"alpha"], (@[@0.5]));
	XCTAssertNil([values componentsForKey:@"removed"]);
}

/*! @abstract A snapshot survives a secure-coding round trip. */
- (void)testValuesSurviveASecureCodingRoundTrip
{
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"gain": @[@2], @"tint": @[@0.25, @0.5, @0.75] }];
	NSError *error = nil;

	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:values requiringSecureCoding:YES error:&error];
	FxGripShaderValues *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripShaderValues.class fromData:data error:&error];

	XCTAssertNotNil(decoded, @"%@", error);
	XCTAssertEqualObjects(decoded.keys, (@[@"gain", @"tint"]));
	XCTAssertEqualObjects([decoded componentsForKey:@"tint"], (@[@0.25, @0.5, @0.75]));
}

/*! @abstract Decoding drops an entry whose value is not an array of numbers. */
- (void)testDecodingDropsAMalformedEntry
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	[archiver encodeObject:@{ @"good": @[@1], @"text": @"one", @"mixed": @[@1, @"two"] } forKey:@"components"];
	[archiver finishEncoding];
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];

	FxGripShaderValues *decoded = [[FxGripShaderValues alloc] initWithCoder:unarchiver];

	XCTAssertEqualObjects(decoded.keys, (@[@"good"]));
}

/*! @abstract Each scalar parameter type binds its documented number of components. */
- (void)testComponentCountsFollowTheParameterType
{
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_Float), (NSUInteger)1);
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_Percent), (NSUInteger)1);
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_Angle), (NSUInteger)1);
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_Int), (NSUInteger)1);
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_Menu), (NSUInteger)1);
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_Toggle), (NSUInteger)1);
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_Switch), (NSUInteger)1);
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_Point), (NSUInteger)2);
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_RGB), (NSUInteger)3);
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_RGBA), (NSUInteger)4);
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_Gradient), (NSUInteger)0);
	XCTAssertEqual(FxGripShaderComponentCountForType(FxParameterType_String), (NSUInteger)0);
}

#pragma mark Constant signature

/*! @abstract The signature lists the constant keys sorted, each with its components. */
- (void)testTheConstantSignatureListsSortedKeysWithComponents
{
	FxGripShaderPipeline *pipeline = [self pipelineWithSource:FxGripShaderTestSource(
		@"{ parameters: ["
		@"  { id: 1, type: \"rgb\", name: \"Tint\", key: \"TINT\", constant: true, allowContinuousConstant: true },"
		@"  { id: 2, type: \"integer\", name: \"Mode\", key: \"MODE\", constant: true },"
		@"  { id: 3, type: \"float\", name: \"Gain\", key: \"gain\" },"
		@"] }", @"")];
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"TINT": @[@0.25, @0.5, @1], @"MODE": @[@2], @"gain": @[@3] }];

	XCTAssertEqualObjects([pipeline constantSignatureForValues:values], @"MODE=2;TINT=0.25,0.5,1");
	XCTAssertEqualObjects([pipeline constantSignatureForValues:[FxGripShaderValues new]], @"MODE=;TINT=");
}

/*! @abstract A shader with no constants has an empty signature. */
- (void)testAShaderWithoutConstantsHasAnEmptySignature
{
	FxGripShaderPipeline *pipeline = [self pipelineWithSource:FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"float\", name: \"Gain\", key: \"gain\" } ] }", @"")];

	XCTAssertEqualObjects([pipeline constantSignatureForValues:[self valuesWithComponents:@{ @"gain": @[@1] }]], @"");
}

#pragma mark Primaries

/*! @abstract The conversion runs only for declared primaries that differ from the host's. */
- (void)testTheConversionRunsOnlyForDifferingDeclaredPrimaries
{
	FxGripShaderPipeline *host = [self pipelineWithSource:FxGripShaderTestSource(@"{ colorSpace: { primaries: \"host\" } }", @"")];
	FxGripShaderPipeline *rec709 = [self pipelineWithSource:FxGripShaderTestSource(@"{ colorSpace: { primaries: \"rec709\" } }", @"")];
	FxGripShaderPipeline *rec2020 = [self pipelineWithSource:FxGripShaderTestSource(@"{ colorSpace: { primaries: \"rec2020\" } }", @"")];

	XCTAssertFalse([host convertsFromHostPrimaries:kFxColorPrimaries_Rec709]);
	XCTAssertFalse([host convertsFromHostPrimaries:kFxColorPrimaries_Rec2020]);
	XCTAssertFalse([rec709 convertsFromHostPrimaries:kFxColorPrimaries_Rec709]);
	XCTAssertTrue([rec709 convertsFromHostPrimaries:kFxColorPrimaries_Rec2020]);
	XCTAssertTrue([rec2020 convertsFromHostPrimaries:kFxColorPrimaries_Rec709]);
	XCTAssertFalse([rec2020 convertsFromHostPrimaries:kFxColorPrimaries_Rec2020]);
}

#pragma mark Sharing

/*! @abstract The shared pipeline is one object per source and fragment function name. */
- (void)testTheSharedPipelineIsOnePerSourceAndFunction
{
	NSString *source = FxGripShaderPipelineGainSource();
	FxGripShaderMetadata *metadata = [FxGripShaderMetadata metadataWithSource:source error:NULL];

	FxGripShaderPipeline *first = [FxGripShaderPipeline sharedPipelineWithSource:source metadata:metadata fragmentFunctionName:@"one"];
	FxGripShaderPipeline *second = [FxGripShaderPipeline sharedPipelineWithSource:[source mutableCopy] metadata:metadata fragmentFunctionName:@"one"];
	FxGripShaderPipeline *other = [FxGripShaderPipeline sharedPipelineWithSource:source metadata:metadata fragmentFunctionName:@"two"];

	XCTAssertEqual(first, second);
	XCTAssertNotEqual(first, other);
	XCTAssertEqualObjects(other.fragmentFunctionName, @"two");
}

/*! @abstract The prelude declares the vertex output and ends by restoring the source's line numbers. */
- (void)testThePreludeRestoresTheSourceLineNumbers
{
	NSString *prelude = FxGripShaderPipeline.preludeSource;

	XCTAssertTrue([prelude containsString:@"struct FxGripShaderVertexOut"]);
	XCTAssertTrue([prelude containsString:kFxGripShaderVertexFunctionName]);
	XCTAssertTrue([prelude hasSuffix:@"#line 1\n"]);
}

#pragma mark Compilation

/*! @abstract A compiler error reports the line in the shader's own source. */
- (void)testACompilerErrorReportsTheSourcesOwnLine
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = @"// line 1\n// line 2\nthis is not metal;\n";
	FxGripShaderPipeline *pipeline = [self pipelineWithSource:source];
	NSError *error = nil;

	XCTAssertNil([pipeline libraryForDevice:FxGripShaderTestDevice() error:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderCompileFailed);
	XCTAssertNotNil(error.userInfo[NSUnderlyingErrorKey]);
	XCTAssertTrue([error.localizedDescription containsString:@":3:"], @"%@", error.localizedDescription);
}

/*! @abstract The library compiles once per device, and a compile failure is kept and returned again. */
- (void)testTheLibraryAndItsFailureAreCachedPerDevice
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderPipeline *pipeline = [self pipelineWithSource:FxGripShaderPipelineGainSource()];
	FxGripShaderPipeline *broken = [self pipelineWithSource:@"broken"];
	NSError *firstError = nil;
	NSError *secondError = nil;

	id<MTLLibrary> first = [pipeline libraryForDevice:FxGripShaderTestDevice() error:NULL];
	id<MTLLibrary> second = [pipeline libraryForDevice:FxGripShaderTestDevice() error:NULL];
	[broken libraryForDevice:FxGripShaderTestDevice() error:&firstError];
	[broken libraryForDevice:FxGripShaderTestDevice() error:&secondError];

	XCTAssertNotNil(first);
	XCTAssertEqual(first, second);
	XCTAssertNotNil(firstError);
	XCTAssertEqual(firstError, secondError);
}

/*! @abstract A source without the named fragment function fails to build a state. */
- (void)testAMissingFragmentFunctionFailsTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderTestSource(@"{}", @"fragment float4 other() { return 0.0; }\n");

	NSError *error = [self stateFailureForSource:source values:[FxGripShaderValues new] code:kFxGripError_ShaderCompileFailed];

	XCTAssertTrue([error.localizedDescription containsString:kFxGripShaderFragmentFunctionName]);
}

/*! @abstract The worked example in the Shaders DocC article compiles and binds as documented. */
- (void)testTheDocumentedExampleCompilesAndBinds
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"radius": @[@8], @"TAPS": @[@9], @"tint": @[@1, @1, @1] }];
	NSError *error = nil;

	FxGripShaderPipelineState *state = [self stateForSource:FxGripShaderTestDocumentedExampleSource() values:values error:&error];

	XCTAssertNotNil(state, @"%@", error);
	XCTAssertEqualObjects(state.constantSignature, @"TAPS=9");
	XCTAssertEqualObjects(state.uniformOffsets, (@{ @"radius": @0, @"tint": @16 }));
	XCTAssertEqual(state.uniformLength, (NSUInteger)32);
}

/*! @abstract The documented example renders its tint over a one-tap sample. */
- (void)testTheDocumentedExampleRenders
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 4, 4 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.8f, 0.8f, 0.8f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"radius": @[@0], @"TAPS": @[@1], @"tint": @[@1, @0.5, @0.25] }];

	[self renderSource:FxGripShaderTestDocumentedExampleSource() destination:destination sources:@[source]
				values:values hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 2, 1) equals:simd_make_float4(0.8f, 0.4f, 0.2f, 1.0f) accuracy:1e-5f];
}

#pragma mark Uniform layout

/*! @abstract Reflection places each member by key, whatever the declared order, and leaves an unbound member out. */
- (void)testReflectionPlacesEachUniformMemberByKey
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"MODE": @[@0] }];
	NSError *error = nil;

	FxGripShaderPipelineState *state = [self stateForSource:FxGripShaderPipelineGainSource() values:values error:&error];

	XCTAssertNotNil(state, @"%@", error);
	XCTAssertEqualObjects(state.uniformOffsets, (@{ @"gain": @0, @"tint": @16, @"center": @32 }));
	XCTAssertEqual(state.uniformLength, (NSUInteger)48);
}

/*! @abstract The packed uniform struct holds each value at its member's offset and zero elsewhere. */
- (void)testTheUniformStructPacksEachValueAtItsOffset
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderValues *values = [self valuesWithComponents:@{
		@"MODE": @[@0], @"gain": @[@2], @"tint": @[@0.25, @0.5, @0.75], @"center": @[@3],
	}];
	FxGripShaderPipelineState *state = [self stateForSource:FxGripShaderPipelineGainSource() values:values error:NULL];

	NSData *data = [state uniformDataForValues:values];

	XCTAssertEqual(data.length, (NSUInteger)48);
	XCTAssertEqual(FxGripShaderPipelineReadFloat(data, 0), 2.0f);
	XCTAssertEqual(FxGripShaderPipelineReadFloat(data, 16), 0.25f);
	XCTAssertEqual(FxGripShaderPipelineReadFloat(data, 20), 0.5f);
	XCTAssertEqual(FxGripShaderPipelineReadFloat(data, 24), 0.75f);
	XCTAssertEqual(FxGripShaderPipelineReadFloat(data, 32), 3.0f);
	XCTAssertEqual(FxGripShaderPipelineReadFloat(data, 36), 0.0f, @"a missing component stays zero");
	XCTAssertEqual(FxGripShaderPipelineReadFloat(data, 40), 0.0f, @"an unbound member stays zero");
}

/*! @abstract Integer members round and clamp, a bool member stores nonzero as one, and a half member stores the value. */
- (void)testIntegerBoolAndHalfMembersConvertTheValue
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderTestSource(
		@"{ parameters: ["
		@"  { id: 1, type: \"integer\", name: \"Taps\", key: \"taps\" },"
		@"  { id: 2, type: \"integer\", name: \"Count\", key: \"count\" },"
		@"  { id: 3, type: \"toggle\", name: \"Invert\", key: \"invert\" },"
		@"  { id: 4, type: \"float\", name: \"Level\", key: \"level\" },"
		@"  { id: 5, type: \"integer\", name: \"Small\", key: \"small\" },"
		@"  { id: 6, type: \"integer\", name: \"Byte\", key: \"byte\" },"
		@"] }",
		@"struct Uniforms { int taps; uint count; bool invert; half level; short small; uchar byte; };\n"
		@"fragment float4 fxGripShaderFragment(constant Uniforms &u [[buffer(0)]])\n"
		@"{\n"
		@"    return float4(float(u.taps) + float(u.count) + float(u.invert) + float(u.level) + float(u.small) + float(u.byte));\n"
		@"}\n");
	FxGripShaderValues *values = [self valuesWithComponents:@{
		@"taps": @[@2.6], @"count": @[@-5], @"invert": @[@0.25], @"level": @[@0.5], @"small": @[@40000], @"byte": @[@300],
	}];
	NSError *error = nil;
	FxGripShaderPipelineState *state = [self stateForSource:source values:values error:&error];
	XCTAssertNotNil(state, @"%@", error);

	NSData *data = [state uniformDataForValues:values];
	const uint8_t *bytes = data.bytes;
	int32_t taps = 0;
	uint32_t count = 1;
	__fp16 level = 0;
	int16_t small = 0;
	memcpy(&taps, bytes + state.uniformOffsets[@"taps"].unsignedIntegerValue, sizeof(taps));
	memcpy(&count, bytes + state.uniformOffsets[@"count"].unsignedIntegerValue, sizeof(count));
	memcpy(&level, bytes + state.uniformOffsets[@"level"].unsignedIntegerValue, sizeof(level));
	memcpy(&small, bytes + state.uniformOffsets[@"small"].unsignedIntegerValue, sizeof(small));

	XCTAssertEqual(taps, 3);
	XCTAssertEqual(count, (uint32_t)0);
	XCTAssertEqual(bytes[state.uniformOffsets[@"invert"].unsignedIntegerValue], (uint8_t)1);
	XCTAssertEqual((float)level, 0.5f);
	XCTAssertEqual(small, (int16_t)INT16_MAX);
	XCTAssertEqual(bytes[state.uniformOffsets[@"byte"].unsignedIntegerValue], (uint8_t)UINT8_MAX);
}

/*! @abstract A member whose component count differs from its parameter's refuses the state. */
- (void)testAMismatchedMemberRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"rgb\", name: \"Tint\", key: \"tint\" } ] }",
		@"struct Uniforms { float tint; };\n"
		@"fragment float4 fxGripShaderFragment(constant Uniforms &u [[buffer(0)]]) { return float4(u.tint); }\n");

	NSError *error = [self stateFailureForSource:source values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];

	XCTAssertTrue([error.localizedDescription containsString:@"tint"]);
}

/*! @abstract An array member bound by key refuses the state. */
- (void)testAnArrayMemberRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"float\", name: \"Gain\", key: \"gain\" } ] }",
		@"struct Uniforms { float gain[2]; };\n"
		@"fragment float4 fxGripShaderFragment(constant Uniforms &u [[buffer(0)]]) { return float4(u.gain[0]); }\n");

	[self stateFailureForSource:source values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];
}

/*! @abstract A member bound to a parameter type with no scalar value refuses the state. */
- (void)testAMemberBoundToANonScalarTypeRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"string\", name: \"Label\", key: \"label\" } ] }",
		@"struct Uniforms { float label; };\n"
		@"fragment float4 fxGripShaderFragment(constant Uniforms &u [[buffer(0)]]) { return float4(u.label); }\n");

	[self stateFailureForSource:source values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];
}

/*! @abstract A uniform buffer that is not a struct refuses the state. */
- (void)testANonStructUniformBufferRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"float\", name: \"Gain\", key: \"gain\" } ] }",
		@"fragment float4 fxGripShaderFragment(constant float &gain [[buffer(0)]]) { return float4(gain); }\n");

	[self stateFailureForSource:source values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];
}

/*! @abstract A fragment function that reads no uniform buffer has no uniform data. */
- (void)testAFunctionWithoutUniformsHasNoUniformData
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderPipelineExpressionSource(@"{}", @"color");
	NSError *error = nil;

	FxGripShaderPipelineState *state = [self stateForSource:source values:[FxGripShaderValues new] error:&error];

	XCTAssertNotNil(state, @"%@", error);
	XCTAssertEqual(state.uniformLength, (NSUInteger)0);
	XCTAssertNil([state uniformDataForValues:[FxGripShaderValues new]]);
}

#pragma mark Function constants

/*! @abstract Equal constant values reuse one state, and a new value builds another. */
- (void)testStatesAreCachedPerConstantSet
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderPipeline *pipeline = [self pipelineWithSource:FxGripShaderPipelineGainSource()];
	id<MTLDevice> device = FxGripShaderTestDevice();

	FxGripShaderPipelineState *zero = [pipeline stateForDevice:device pixelFormat:MTLPixelFormatRGBA32Float
														values:[self valuesWithComponents:@{ @"MODE": @[@0], @"gain": @[@1] }] error:NULL];
	FxGripShaderPipelineState *zeroAgain = [pipeline stateForDevice:device pixelFormat:MTLPixelFormatRGBA32Float
															 values:[self valuesWithComponents:@{ @"MODE": @[@0], @"gain": @[@5] }] error:NULL];
	FxGripShaderPipelineState *one = [pipeline stateForDevice:device pixelFormat:MTLPixelFormatRGBA32Float
													   values:[self valuesWithComponents:@{ @"MODE": @[@1] }] error:NULL];
	FxGripShaderPipelineState *otherFormat = [pipeline stateForDevice:device pixelFormat:MTLPixelFormatBGRA8Unorm
															   values:[self valuesWithComponents:@{ @"MODE": @[@0] }] error:NULL];

	XCTAssertNotNil(zero);
	XCTAssertEqual(zero, zeroAgain, @"a uniform value does not key the cache");
	XCTAssertNotEqual(zero, one);
	XCTAssertNotEqual(zero, otherFormat);
	XCTAssertEqualObjects(zero.constantSignature, @"MODE=0");
	XCTAssertEqualObjects(one.constantSignature, @"MODE=1");
}

/*! @abstract The cache keeps its limit of states and rebuilds the oldest one after eviction. */
- (void)testTheStateCacheEvictsTheOldestState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderPipeline *pipeline = [self pipelineWithSource:FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"float\", name: \"Level\", key: \"LEVEL\", constant: true, allowContinuousConstant: true } ] }",
		@"constant float LEVEL [[function_constant(0)]];\n"
		@"fragment float4 fxGripShaderFragment() { return float4(LEVEL); }\n")];
	id<MTLDevice> device = FxGripShaderTestDevice();
	FxGripShaderPipelineState *(^stateAt)(NSUInteger) = ^FxGripShaderPipelineState *(NSUInteger level) {
		return [pipeline stateForDevice:device pixelFormat:MTLPixelFormatRGBA32Float
								 values:[self valuesWithComponents:@{ @"LEVEL": @[@(level)] }] error:NULL];
	};

	FxGripShaderPipelineState *oldest = stateAt(0);
	for (NSUInteger level = 1; level < kFxGripShaderPipelineStateCacheLimit; level++) {
		stateAt(level);
	}
	XCTAssertEqual(stateAt(0), oldest, @"the cache holds its limit");
	FxGripShaderPipelineState *newest = stateAt(kFxGripShaderPipelineStateCacheLimit);

	XCTAssertEqual(stateAt(kFxGripShaderPipelineStateCacheLimit), newest);
	XCTAssertNotEqual(stateAt(0), oldest, @"the oldest state is evicted and rebuilt");
}

/*! @abstract The constant value specializes the fragment function. */
- (void)testTheConstantValueSpecializesTheFunction
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.5f, 0.25f, 0.125f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"MODE": @[@1], @"gain": @[@2], @"tint": @[@0.1, @0.2, @0.3] }];

	[self renderSource:FxGripShaderPipelineGainSource() destination:destination sources:@[source]
				values:values hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 0) equals:simd_make_float4(0.1f, 0.2f, 0.3f, 1.0f) accuracy:1e-6f];
}

/*! @abstract A required function constant with no value refuses the state. */
- (void)testARequiredConstantWithoutAValueRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");

	NSError *error = [self stateFailureForSource:FxGripShaderPipelineGainSource() values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];

	XCTAssertTrue([error.localizedDescription containsString:@"MODE"]);
}

/*! @abstract A required function constant that no constant parameter binds refuses the state. */
- (void)testAnUnboundRequiredConstantRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"integer\", name: \"Mode\", key: \"MODE\" } ] }",
		@"constant int MODE [[function_constant(0)]];\n"
		@"fragment float4 fxGripShaderFragment() { return float4(float(MODE)); }\n");

	NSError *error = [self stateFailureForSource:source values:[self valuesWithComponents:@{ @"MODE": @[@1] }] code:kFxGripError_ShaderBindingInvalid];

	XCTAssertTrue([error.localizedDescription containsString:@"MODE"]);
}

/*! @abstract An optional function constant with no value builds the state, and the shader sees it undefined. */
- (void)testAnOptionalConstantWithoutAValueStaysUndefined
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"toggle\", name: \"Fast\", key: \"FAST\", constant: true } ] }",
		@"constant bool FAST [[function_constant(0)]];\n"
		@"constant bool FAST_DEFINED = is_function_constant_defined(FAST);\n"
		@"fragment float4 fxGripShaderFragment() { return FAST_DEFINED ? float4(1.0) : float4(0.5); }\n");
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderSource:source destination:destination sources:@[]
				values:[FxGripShaderValues new] hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	XCTAssertEqual(FxGripShaderTestPixel(destination, 0, 0).x, 0.5f);
}

/*! @abstract A function constant whose component count differs from its parameter's refuses the state. */
- (void)testAMismatchedConstantRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"rgb\", name: \"Tint\", key: \"TINT\", constant: true, allowContinuousConstant: true } ] }",
		@"constant float TINT [[function_constant(0)]];\n"
		@"fragment float4 fxGripShaderFragment() { return float4(TINT); }\n");
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"TINT": @[@1, @0, @0] }];

	NSError *error = [self stateFailureForSource:source values:values code:kFxGripError_ShaderBindingInvalid];

	XCTAssertTrue([error.localizedDescription containsString:@"TINT"]);
}

/*! @abstract A vector function constant receives every component. */
- (void)testAVectorConstantReceivesEveryComponent
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"rgba\", name: \"Fill\", key: \"FILL\", constant: true, allowContinuousConstant: true } ] }",
		@"constant float4 FILL [[function_constant(0)]];\n"
		@"fragment float4 fxGripShaderFragment() { return FILL; }\n");
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderSource:source destination:destination sources:@[]
				values:[self valuesWithComponents:@{ @"FILL": @[@0.1, @0.2, @0.3, @0.4] }]
		 hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 1, 1) equals:simd_make_float4(0.1f, 0.2f, 0.3f, 0.4f) accuracy:1e-6f];
}

#pragma mark Rendering

/*! @abstract The uniforms reach the fragment function. */
- (void)testTheUniformsReachTheFragmentFunction
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 4, 4 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.5f, 0.25f, 0.125f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"MODE": @[@0], @"gain": @[@2] }];

	[self renderSource:FxGripShaderPipelineGainSource() destination:destination sources:@[source]
				values:values hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 3, 3) equals:simd_make_float4(1.0f, 0.5f, 0.25f, 1.0f) accuracy:1e-6f];
}

/*! @abstract imagePixel is the destination pixel center in image space, with y increasing upward. */
- (void)testImagePixelIsTheDestinationPixelInImageSpace
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *source = FxGripShaderPipelineExpressionSource(@"{}", @"float4(in.imagePixel, 0.0, 1.0)");
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 10, 20, 14, 24 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderSource:source destination:destination sources:@[]
				values:[FxGripShaderValues new] hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 0) equals:simd_make_float4(10.5f, 23.5f, 0.0f, 1.0f) accuracy:1e-4f];
	[self assertPixel:FxGripShaderTestPixel(destination, 3, 3) equals:simd_make_float4(13.5f, 20.5f, 0.0f, 1.0f) accuracy:1e-4f];
}

/*! @abstract texCoord maps a destination pixel to the same image pixel of source texture 0. */
- (void)testTexCoordMapsTheDestinationIntoTheSourceTile
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderPipelineExpressionSource(@"{}", @"color");
	FxImageTile *source = FxGripShaderTestFloatTile((FxRect){ 0, 0, 8, 8 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderTestFillTile(source, ^simd_float4(NSUInteger column, NSUInteger row) {
		return simd_make_float4((float)column, (float)row, 0.0f, 1.0f);
	});
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 2, 2, 6, 6 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderSource:shader destination:destination sources:@[source]
				values:[FxGripShaderValues new] hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 0) equals:simd_make_float4(2.0f, 2.0f, 0.0f, 1.0f) accuracy:1e-6f];
	[self assertPixel:FxGripShaderTestPixel(destination, 3, 3) equals:simd_make_float4(5.0f, 5.0f, 0.0f, 1.0f) accuracy:1e-6f];
}

/*! @abstract Each source image binds at the texture index of its position. */
- (void)testEachSourceImageBindsAtItsIndex
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderTestSource(@"{}",
		@"fragment float4 fxGripShaderFragment(FxGripShaderVertexOut in [[stage_in]],\n"
		@"                                     texture2d<float> first [[texture(0)]],\n"
		@"                                     texture2d<float> second [[texture(1)]])\n"
		@"{\n"
		@"    constexpr sampler nearest(filter::nearest);\n"
		@"    return first.sample(nearest, in.texCoord) - second.sample(nearest, in.texCoord);\n"
		@"}\n");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *first = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.75f, 0.5f, 0.25f, 1.0f));
	FxImageTile *second = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.25f, 0.25f, 0.25f, 0.5f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderSource:shader destination:destination sources:@[first, second]
				values:[FxGripShaderValues new] hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 1, 0) equals:simd_make_float4(0.5f, 0.25f, 0.0f, 0.5f) accuracy:1e-6f];
}

/*! @abstract A uniform struct larger than the inline limit binds through a buffer. */
- (void)testALargeUniformStructBindsThroughABuffer
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"float\", name: \"Gain\", key: \"gain\" } ] }",
		@"struct Uniforms { float4 padding[300]; float gain; };\n"
		@"fragment float4 fxGripShaderFragment(constant Uniforms &u [[buffer(0)]]) { return float4(u.gain + u.padding[7].x); }\n");
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderSource:shader destination:destination sources:@[]
				values:[self valuesWithComponents:@{ @"gain": @[@0.75] }]
		 hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 1) equals:simd_make_float4(0.75f, 0.75f, 0.75f, 0.75f) accuracy:1e-6f];
}

/*! @abstract Concurrent renders with different constant sets each draw their own value. */
- (void)testConcurrentRendersDrawTheirOwnConstants
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderPipeline *pipeline = [self pipelineWithSource:FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"integer\", name: \"Level\", key: \"LEVEL\", constant: true } ] }",
		@"constant int LEVEL [[function_constant(0)]];\n"
		@"fragment float4 fxGripShaderFragment() { return float4(float(LEVEL)); }\n")];
	const NSUInteger renders = 16;
	NSMutableArray<FxImageTile *> *destinations = [NSMutableArray array];
	for (NSUInteger index = 0; index < renders; index++) {
		[destinations addObject:FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(-1.0f, -1.0f, -1.0f, -1.0f))];
	}
	__block NSUInteger failures = 0;
	NSLock *failuresLock = [NSLock new];

	dispatch_apply(renders, DISPATCH_APPLY_AUTO, ^(size_t index) {
		FxGripShaderValues *values = [FxGripShaderValues new];
		[values setDouble:(double)(index % 4) forKey:@"LEVEL"];
		if (![pipeline renderDestinationImage:destinations[index] sourceImages:@[] values:values
								hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR error:NULL]) {
			[failuresLock lock];
			failures += 1;
			[failuresLock unlock];
		}
	});

	XCTAssertEqual(failures, (NSUInteger)0);
	for (NSUInteger index = 0; index < renders; index++) {
		XCTAssertEqual(FxGripShaderTestPixel(destinations[index], 0, 0).x, (float)(index % 4));
	}
}

#pragma mark Primaries conversion

/*! @abstract A rec2020 shader under a rec709 host sees converted input and its output converts back. */
- (void)testARec2020ShaderConvertsUnderARec709Host
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderPipelineExpressionSource(@"{ primaries: \"rec2020\" }", @"float4(color.r, 0.0, 0.0, color.a)");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(1.0f, 0.0f, 0.0f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	simd_float3x3 toShader = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec709, kFxColorPrimaries_Rec2020);
	simd_float3x3 toHost = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec2020, kFxColorPrimaries_Rec709);
	float shaderRed = simd_mul(toShader, simd_make_float3(1.0f, 0.0f, 0.0f)).x;
	simd_float3 expected = simd_mul(toHost, simd_make_float3(shaderRed, 0.0f, 0.0f));

	[self renderSource:shader destination:destination sources:@[source]
				values:[FxGripShaderValues new] hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	XCTAssertLessThan(shaderRed, 0.9f, @"the shader sees rec2020 red, which is less saturated");
	[self assertPixel:FxGripShaderTestPixel(destination, 1, 1) equals:simd_make_float4(expected.x, expected.y, expected.z, 1.0f) accuracy:1e-4f];
}

/*! @abstract Matching primaries render with no conversion. */
- (void)testMatchingPrimariesRenderUnconverted
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderPipelineExpressionSource(@"{ primaries: \"rec2020\" }", @"float4(color.r, 0.0, 0.0, color.a)");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(1.0f, 0.0f, 0.0f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderSource:shader destination:destination sources:@[source]
				values:[FxGripShaderValues new] hostPrimaries:kFxColorPrimaries_Rec2020 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 0) equals:simd_make_float4(1.0f, 0.0f, 0.0f, 1.0f) accuracy:1e-6f];
}

/*! @abstract A gamma image is unpremultiplied, decoded, converted, encoded, and premultiplied again. */
- (void)testAGammaImageConvertsInLinearLight
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderPipelineExpressionSource(@"{ transfer: \"gamma\", primaries: \"rec709\" }", @"float4(color.r, 0.0, 0.0, color.a)");
	FxRect bounds = { 0, 0, 2, 2 };
	float alpha = 0.5f;
	simd_float3 straight = simd_make_float3(0.8f, 0.4f, 0.2f);
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(straight * alpha, alpha));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	simd_float3x3 toShader = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec2020, kFxColorPrimaries_Rec709);
	simd_float3x3 toHost = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec709, kFxColorPrimaries_Rec2020);
	simd_float3 inShader = FxGripShaderPipelineEncodeSRGB3(simd_mul(toShader, FxGripShaderPipelineDecodeSRGB3(straight)));
	simd_float3 shaderOutput = simd_make_float3(inShader.x, 0.0f, 0.0f);
	simd_float3 expected = FxGripShaderPipelineEncodeSRGB3(simd_mul(toHost, FxGripShaderPipelineDecodeSRGB3(shaderOutput)));

	[self renderSource:shader destination:destination sources:@[source]
				values:[FxGripShaderValues new] hostPrimaries:kFxColorPrimaries_Rec2020 colorInfo:kFxImageColorInfo_RGB_GAMMA_VIDEO];

	[self assertPixel:FxGripShaderTestPixel(destination, 1, 0) equals:simd_make_float4(expected * alpha, alpha) accuracy:1e-4f];
}

#pragma mark Render failures

/*! @abstract A destination tile with no device fails the render. */
- (void)testADestinationWithoutADeviceFailsTheRender
{
	FxGripShaderPipeline *pipeline = [self pipelineWithSource:FxGripShaderPipelineExpressionSource(@"{}", @"color")];
	FxImageTile *destination = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 2, 2 }];
	NSError *error = nil;

	XCTAssertFalse([pipeline renderDestinationImage:destination sourceImages:@[] values:[FxGripShaderValues new]
									  hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR error:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderRenderFailed);
}

/*! @abstract A source tile with no texture fails the render. */
- (void)testASourceWithoutATextureFailsTheRender
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderPipeline *pipeline = [self pipelineWithSource:FxGripShaderPipelineExpressionSource(@"{}", @"color")];
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxImageTile *source = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 2, 2 }];
	NSError *error = nil;

	XCTAssertFalse([pipeline renderDestinationImage:destination sourceImages:@[source] values:[FxGripShaderValues new]
									  hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR error:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderRenderFailed);
}

/*! @abstract A pipeline failure fails the render with the pipeline's error. */
- (void)testAPipelineFailureFailsTheRender
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderPipeline *pipeline = [self pipelineWithSource:@"fragment float4 other() { return 0.0; }\n"];
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	NSError *error = nil;

	XCTAssertFalse([pipeline renderDestinationImage:destination sourceImages:@[] values:[FxGripShaderValues new]
									  hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR error:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderCompileFailed);
}

#pragma mark Texture coordinates

/*! @abstract The tile maps a destination pixel into each source of its own bounds. */
- (void)testTheTileMapsEachSourceByItsOwnBounds
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderPipelineTileSource(@"{}",
		@"texture2d<float> first [[texture(0)]], texture2d<float> second [[texture(1)]],",
		@"float4(second.sample(nearest, fxGripShaderTexCoord(tile, 1u, in.imagePixel)).rg, float(tile.textureCount), 1.0)");
	FxImageTile *first = FxGripShaderTestFloatTile((FxRect){ 2, 2, 6, 6 }, simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f));
	FxImageTile *second = FxGripShaderTestFloatTile((FxRect){ 0, 0, 8, 8 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderTestFillTile(second, ^simd_float4(NSUInteger column, NSUInteger row) {
		return simd_make_float4((float)column, (float)row, 0.0f, 1.0f);
	});
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 2, 2, 6, 6 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderSource:shader destination:destination sources:@[first, second]
				values:[FxGripShaderValues new] hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 0) equals:simd_make_float4(2.0f, 2.0f, 2.0f, 1.0f) accuracy:1e-6f];
	[self assertPixel:FxGripShaderTestPixel(destination, 3, 3) equals:simd_make_float4(5.0f, 5.0f, 2.0f, 1.0f) accuracy:1e-6f];
}

/*! @abstract A source at full resolution maps through the destination's proxy pixel transform. */
- (void)testAFullResolutionSourceMapsThroughAProxyDestination
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderPipelineTileSource(@"{}",
		@"texture2d<float> source [[texture(0)]],",
		@"float4(fxGripShaderTexCoord(tile, 0u, in.imagePixel), in.texCoord)");
	FxImageTile *source = FxGripShaderTestFloatTile((FxRect){ 0, 0, 8, 8 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxImageTile *destination = FxGripShaderPipelineScaledTile((FxRect){ 0, 0, 4, 4 }, 0.5, 0.5, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderSource:shader destination:destination sources:@[source]
				values:[FxGripShaderValues new] hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	// Destination pixel (1, 2) has its center at (1.5, 1.5); image space (3, 3); source pixel (3, 3), so u = 3/8 and v = (8 - 3)/8.
	[self assertPixel:FxGripShaderTestPixel(destination, 1, 2) equals:simd_make_float4(0.375f, 0.625f, 0.375f, 0.625f) accuracy:1e-5f];
}

/*! @abstract The tile carries the destination's pixels per image-space unit along each axis. */
- (void)testTheTileCarriesThePixelScale
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderPipelineTileSource(@"{}", @"", @"float4(tile.pixelScale, 0.0, 1.0)");
	FxImageTile *destination = FxGripShaderPipelineScaledTile((FxRect){ 0, 0, 2, 2 }, 0.5, 0.25, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderSource:shader destination:destination sources:@[]
				values:[FxGripShaderValues new] hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 0) equals:simd_make_float4(0.5f, 0.25f, 0.0f, 1.0f) accuracy:1e-6f];
}

/*! @abstract A pixelUnits uniform and constant scale by the destination's horizontal pixel scale, and other values do not. */
- (void)testPixelUnitValuesScaleToTheDestination
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderTestSource(
		@"{ parameters: ["
		@"  { id: 1, type: \"float\", name: \"Radius\", key: \"radius\", pixelUnits: true },"
		@"  { id: 2, type: \"float\", name: \"Gain\", key: \"gain\" },"
		@"  { id: 3, type: \"integer\", name: \"Taps\", key: \"TAPS\", constant: true, pixelUnits: true },"
		@"] }",
		@"constant int TAPS [[function_constant(0)]];\n"
		@"struct Uniforms { float radius; float gain; };\n"
		@"fragment float4 fxGripShaderFragment(constant Uniforms &u [[buffer(0)]]) { return float4(u.radius, u.gain, float(TAPS), 1.0); }\n");
	FxImageTile *destination = FxGripShaderPipelineScaledTile((FxRect){ 0, 0, 2, 2 }, 0.5, 0.5, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"radius": @[@8], @"gain": @[@8], @"TAPS": @[@8] }];

	[self renderSource:shader destination:destination sources:@[]
				values:values hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 1, 1) equals:simd_make_float4(4.0f, 8.0f, 4.0f, 1.0f) accuracy:1e-6f];
	XCTAssertEqualObjects([values componentsForKey:@"radius"], (@[@8]), @"the render scales a copy of the values");
}

#pragma mark Keyed textures

/*! An image parameter keyed "mask" and a gradient parameter keyed "ramp", read through texture indexes 4 and 5. */
static NSString *FxGripShaderPipelineKeyedTextureSource(NSString *colorSpace, NSString *expression)
{
	return FxGripShaderPipelineTileSource(
		[NSString stringWithFormat:@"{ colorSpace: %@, parameters: ["
			@"  { id: 5, type: \"imageref\", name: \"Mask\", key: \"mask\" },"
			@"  { id: 6, type: \"gradient\", name: \"Ramp\", key: \"ramp\" },"
			@"] }", colorSpace],
		@"texture2d<float> source [[texture(0)]], texture2d<float> mask [[texture(4)]], texture2d<float> ramp [[texture(5)]],",
		expression);
}

/*! A 4×1 RGBA32Float texture holding the given samples. */
- (id<MTLTexture>)rampTextureWithSamples:(const simd_float4 *)samples
{
	MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:4 height:1 mipmapped:NO];
	id<MTLTexture> texture = [FxGripShaderTestDevice() newTextureWithDescriptor:descriptor];
	[texture replaceRegion:MTLRegionMake2D(0, 0, 4, 1) mipmapLevel:0 withBytes:samples bytesPerRow:4 * sizeof(simd_float4)];
	return texture;
}

/*! @abstract Reflection reports the texture index of each keyed texture argument. */
- (void)testReflectionReportsEachKeyedTextureIndex
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderPipelineKeyedTextureSource(@"{}", @"mask.sample(nearest, in.texCoord) + ramp.read(uint2(0, 0)) + source.sample(nearest, in.texCoord)");
	NSError *error = nil;

	FxGripShaderPipelineState *state = [self stateForSource:shader values:[FxGripShaderValues new] error:&error];

	XCTAssertNotNil(state, @"%@", error);
	XCTAssertEqualObjects(state.textureIndexes, (@{ @"mask": @4, @"ramp": @5 }));
}

/*! @abstract An image parameter's tile binds to its keyed argument and maps by its own bounds, and a gradient binds its texture. */
- (void)testKeyedImageAndGradientBindByKey
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderPipelineKeyedTextureSource(@"{}",
		@"float4(mask.sample(nearest, fxGripShaderTexCoord(tile, 4u, in.imagePixel)).rg, ramp.read(uint2(2, 0)).b, float(tile.textureCount))");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f));
	FxImageTile *mask = FxGripShaderTestFloatTile((FxRect){ 0, 0, 4, 4 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderTestFillTile(mask, ^simd_float4(NSUInteger column, NSUInteger row) {
		return simd_make_float4((float)column, (float)row, 0.0f, 1.0f);
	});
	mask.parameterID = 5;
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	const simd_float4 samples[4] = { { 0, 0, 0.1f, 1 }, { 0, 0, 0.2f, 1 }, { 0, 0, 0.3f, 1 }, { 0, 0, 0.4f, 1 } };
	NSError *error = nil;

	BOOL rendered = [[self pipelineWithSource:shader] renderDestinationImage:destination
																sourceImages:@[source, mask]
															   keyedTextures:@{ @"ramp": [self rampTextureWithSamples:samples] }
																	  values:[FxGripShaderValues new]
															   hostPrimaries:kFxColorPrimaries_Rec709
																   colorInfo:kFxImageColorInfo_RGB_LINEAR
																	   error:&error];

	XCTAssertTrue(rendered, @"%@", error);
	// Destination pixel (1, 0) is image pixel (1.5, 1.5), which is mask texel column 1, row 2 of its 4×4 tile.
	[self assertPixel:FxGripShaderTestPixel(destination, 1, 0) equals:simd_make_float4(1.0f, 2.0f, 0.3f, 6.0f) accuracy:1e-6f];
}

/*! @abstract A keyed argument whose parameter supplies no image binds transparent black. */
- (void)testAKeyedArgumentWithoutAnImageBindsTransparentBlack
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderPipelineKeyedTextureSource(@"{}",
		@"mask.sample(nearest, in.texCoord) + ramp.read(uint2(0, 0)) + float4(0.0, 0.0, 0.0, 0.25)");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(1.0f, 1.0f, 1.0f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(1.0f, 1.0f, 1.0f, 1.0f));

	[self renderSource:shader destination:destination sources:@[source]
				values:[FxGripShaderValues new] hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 0) equals:simd_make_float4(0.0f, 0.0f, 0.0f, 0.25f) accuracy:1e-6f];
}

/*! @abstract A keyed gradient converts with the sources when the primaries differ. */
- (void)testAKeyedGradientConvertsWithTheSources
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderPipelineKeyedTextureSource(@"{ primaries: \"rec2020\" }", @"float4(ramp.read(uint2(0, 0)).r, 0.0, 0.0, 1.0)");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	const simd_float4 red[4] = { { 1, 0, 0, 1 }, { 1, 0, 0, 1 }, { 1, 0, 0, 1 }, { 1, 0, 0, 1 } };
	simd_float3x3 toShader = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec709, kFxColorPrimaries_Rec2020);
	simd_float3x3 toHost = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec2020, kFxColorPrimaries_Rec709);
	simd_float3 expected = simd_mul(toHost, simd_make_float3(simd_mul(toShader, simd_make_float3(1.0f, 0.0f, 0.0f)).x, 0.0f, 0.0f));
	NSError *error = nil;

	XCTAssertTrue([[self pipelineWithSource:shader] renderDestinationImage:destination
															  sourceImages:@[source]
															 keyedTextures:@{ @"ramp": [self rampTextureWithSamples:red] }
																	values:[FxGripShaderValues new]
															 hostPrimaries:kFxColorPrimaries_Rec709
																 colorInfo:kFxImageColorInfo_RGB_LINEAR
																	 error:&error], @"%@", error);

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 1) equals:simd_make_float4(expected.x, expected.y, expected.z, 1.0f) accuracy:1e-4f];
}

/*! @abstract A texture argument named by a scalar parameter's key refuses the state. */
- (void)testAScalarKeyOnATextureRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"float\", name: \"Gain\", key: \"gain\" } ] }",
		@"fragment float4 fxGripShaderFragment(texture2d<float> gain [[texture(0)]]) { return gain.read(uint2(0, 0)); }\n");

	[self stateFailureForSource:shader values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];
}

/*! @abstract An image key on a texture argument that is not a texture2d refuses the state. */
- (void)testAnImageKeyOnANonTexture2DRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *shader = FxGripShaderTestSource(
		@"{ parameters: [ { id: 5, type: \"imageref\", name: \"Mask\", key: \"mask\" } ] }",
		@"fragment float4 fxGripShaderFragment(texture1d<float> mask [[texture(0)]]) { return mask.read(0u); }\n");

	NSError *error = [self stateFailureForSource:shader values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];

	XCTAssertTrue([error.localizedDescription containsString:@"mask"]);
}

#pragma mark Concurrent builds

- (FxGripShaderBlockingPipeline *)blockingPipeline
{
	NSString *source = FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"integer\", name: \"Level\", key: \"LEVEL\", constant: true } ] }",
		@"constant int LEVEL [[function_constant(0)]];\n"
		@"fragment float4 fxGripShaderFragment() { return float4(float(LEVEL)); }\n");
	FxGripShaderMetadata *metadata = [FxGripShaderMetadata metadataWithSource:source error:NULL];
	FxGripShaderBlockingPipeline *pipeline = [[FxGripShaderBlockingPipeline alloc] initWithSource:source
																						 metadata:metadata
																			 fragmentFunctionName:kFxGripShaderFragmentFunctionName];
	pipeline.blockedSignature = @"LEVEL=1";
	pipeline.entered = dispatch_semaphore_create(0);
	pipeline.released = dispatch_semaphore_create(0);
	pipeline.builds = [NSCountedSet set];
	return pipeline;
}

- (FxGripShaderValues *)levelValues:(NSInteger)level
{
	return [self valuesWithComponents:@{ @"LEVEL": @[@(level)] }];
}

/*! @abstract Another constant set builds and returns while one build is still in progress. */
- (void)testAnotherStateBuildsWhileOneBuildIsInProgress
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderBlockingPipeline *pipeline = [self blockingPipeline];
	id<MTLDevice> device = FxGripShaderTestDevice();
	XCTestExpectation *blockedDone = [self expectationWithDescription:@"the blocked build finishes"];
	__block FxGripShaderPipelineState *blocked = nil;
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		blocked = [pipeline stateForDevice:device pixelFormat:MTLPixelFormatRGBA32Float values:[self levelValues:1] error:NULL];
		[blockedDone fulfill];
	});
	XCTAssertEqual(dispatch_semaphore_wait(pipeline.entered, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0L);

	XCTestExpectation *otherDone = [self expectationWithDescription:@"another constant set builds"];
	__block FxGripShaderPipelineState *other = nil;
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		other = [pipeline stateForDevice:device pixelFormat:MTLPixelFormatRGBA32Float values:[self levelValues:2] error:NULL];
		[otherDone fulfill];
	});
	XCTWaiterResult otherResult = [XCTWaiter waitForExpectations:@[otherDone] timeout:10.0];
	dispatch_semaphore_signal(pipeline.released);
	[self waitForExpectations:@[blockedDone] timeout:10.0];

	XCTAssertEqual(otherResult, XCTWaiterResultCompleted, @"the other build waited for the blocked one");
	XCTAssertNotNil(other);
	XCTAssertNotNil(blocked);
}

/*! @abstract Concurrent requests for one constant set wait for a single build and share its state. */
- (void)testConcurrentRequestsForOneStateShareOneBuild
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderBlockingPipeline *pipeline = [self blockingPipeline];
	id<MTLDevice> device = FxGripShaderTestDevice();
	const NSUInteger requests = 4;
	NSMutableArray *states = [NSMutableArray array];
	NSLock *statesLock = [NSLock new];
	dispatch_group_t group = dispatch_group_create();
	for (NSUInteger index = 0; index < requests; index++) {
		dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
			FxGripShaderPipelineState *state = [pipeline stateForDevice:device pixelFormat:MTLPixelFormatRGBA32Float values:[self levelValues:1] error:NULL];
			[statesLock lock];
			[states addObject:state ?: NSNull.null];
			[statesLock unlock];
		});
	}
	XCTAssertEqual(dispatch_semaphore_wait(pipeline.entered, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0L);
	dispatch_semaphore_signal(pipeline.released);
	XCTAssertEqual(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0L);

	XCTAssertEqual([pipeline.builds countForObject:@"LEVEL=1"], (NSUInteger)1);
	XCTAssertEqual(states.count, requests);
	XCTAssertEqual([NSSet setWithArray:states].count, (NSUInteger)1);
	XCTAssertFalse([states containsObject:NSNull.null]);
}

@end
