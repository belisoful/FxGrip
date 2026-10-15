/*!
	@file       FxGripKernelPipelineTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripKernelPipelineTests
	@abstract   Verifies the kernel pipeline's binding table, uniform packing, constant cache, and compute dispatch.
	@discussion Introduced in FxGrip 0.1.0. The packing and signature tests need no device. The
	            pipeline tests compile the checked-in Metal source of the fixture kernels and skip on
	            a machine with no Metal device. The render tests dispatch into RGBA32Float stub tiles
	            and read the output back as exact floats. The end-to-end test runs slangc on the
	            fixture against the shipped GripKernel.slang when FXGRIP_SLANGC or the PATH names
	            it, and skips otherwise.
*/

#import <XCTest/XCTest.h>
#import "FxPlugStub.h"
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripColorGamut.h>
#import <FxGrip/FxGripKernelPipeline.h>
#import "FxGripShaderTestSupport.h"
#import "FxGripKernelTestSupport.h"

static float FxGripKernelReadFloat(NSData *data, NSUInteger offset)
{
	float value = 0.0f;
	[data getBytes:&value range:NSMakeRange(offset, sizeof(value))];
	return value;
}

static float FxGripKernelEncodeSRGB(float value)
{
	float magnitude = fabsf(value);
	float encoded = magnitude <= 0.0031308f ? magnitude * 12.92f : 1.055f * powf(magnitude, 1.0f / 2.4f) - 0.055f;
	return copysignf(encoded, value);
}

static float FxGripKernelDecodeSRGB(float value)
{
	float magnitude = fabsf(value);
	float decoded = magnitude <= 0.04045f ? magnitude / 12.92f : powf((magnitude + 0.055f) / 1.055f, 2.4f);
	return copysignf(decoded, value);
}

static simd_float3 FxGripKernelEncodeSRGB3(simd_float3 value)
{
	return simd_make_float3(FxGripKernelEncodeSRGB(value.x), FxGripKernelEncodeSRGB(value.y), FxGripKernelEncodeSRGB(value.z));
}

static simd_float3 FxGripKernelDecodeSRGB3(simd_float3 value)
{
	return simd_make_float3(FxGripKernelDecodeSRGB(value.x), FxGripKernelDecodeSRGB(value.y), FxGripKernelDecodeSRGB(value.z));
}

/*! A float tile with a uniform pixel scale and its inverse, as the host delivers a proxy-resolution tile. */
static FxImageTile *FxGripKernelScaledTile(FxRect bounds, double scaleX, double scaleY, simd_float4 fill)
{
	FxImageTile *tile = FxGripShaderTestFloatTile(bounds, fill);
	tile.pixelTransform = [FxMatrix44 stubMatrixWithScaleX:scaleX scaleY:scaleY translationX:0.0 translationY:0.0];
	tile.inversePixelTransform = [FxMatrix44 stubMatrixWithScaleX:1.0 / scaleX scaleY:1.0 / scaleY translationX:0.0 translationY:0.0];
	return tile;
}

@interface FxGripKernelPipelineTests : XCTestCase
@end

@implementation FxGripKernelPipelineTests

- (FxGripShaderValues *)valuesWithComponents:(NSDictionary<NSString *, NSArray<NSNumber *> *> *)components
{
	FxGripShaderValues *values = [FxGripShaderValues new];
	for (NSString *key in components) {
		[values setComponents:components[key] forKey:key];
	}
	return values;
}

/*! The inspect kernel's values with MODE set and every other binding at a recognizable value. */
- (FxGripShaderValues *)inspectValuesForMode:(NSInteger)mode
{
	return [self valuesWithComponents:@{
		@"MODE": @[@(mode)], @"TAPS": @[@1], @"FILL": @[@0.75],
		@"radius": @[@8], @"gain": @[@2], @"center": @[@5, @6], @"invert": @[@1], @"count": @[@7],
		@"level": @[@0.5], @"small": @[@40000], @"byte": @[@300],
	}];
}

- (FxGripKernelPipeline *)pipelineNamed:(NSString *)name
{
	FxGripKernelPipeline *pipeline = FxGripKernelTestPipeline(name, nil, nil, nil);
	XCTAssertNotNil(pipeline);
	return pipeline;
}

/*! The blur fixture's pipeline with metadata scanned from another block, for binding failures. */
- (FxGripKernelPipeline *)blurPipelineWithMetadataBody:(NSString *)body
{
	NSError *error = nil;
	FxGripShaderMetadata *metadata = [FxGripShaderMetadata metadataWithSource:FxGripShaderTestSource(body, @"") error:&error];
	XCTAssertNotNil(metadata, @"%@", error);
	return FxGripKernelTestPipeline(@"GripBlur", nil, nil, metadata);
}

- (NSError *)stateFailureOfPipeline:(FxGripKernelPipeline *)pipeline values:(FxGripShaderValues *)values code:(NSInteger)code
{
	NSError *error = nil;
	XCTAssertNil([pipeline stateForDevice:FxGripShaderTestDevice() values:values error:&error]);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, code, @"%@", error);
	return error;
}

- (BOOL)renderPipeline:(FxGripKernelPipeline *)pipeline
		   destination:(FxImageTile *)destination
			   sources:(NSArray<FxImageTile *> *)sources
		 keyedTextures:(nullable NSDictionary<NSString *, id<MTLTexture>> *)keyedTextures
				values:(FxGripShaderValues *)values
		 hostPrimaries:(FxColorPrimaries)hostPrimaries
			 colorInfo:(FxImageColorInfo)colorInfo
{
	NSError *error = nil;
	BOOL rendered = [pipeline renderDestinationImage:destination sourceImages:sources keyedTextures:keyedTextures
											  values:values hostPrimaries:hostPrimaries colorInfo:colorInfo error:&error];
	XCTAssertTrue(rendered, @"%@", error);
	return rendered;
}

/*! Renders the inspect kernel, whose primaries are rec2020, under a rec2020 host with linear images. */
- (void)renderInspectMode:(NSInteger)mode destination:(FxImageTile *)destination sources:(NSArray<FxImageTile *> *)sources
{
	[self renderPipeline:[self pipelineNamed:@"GripInspect"] destination:destination sources:sources keyedTextures:nil
				  values:[self inspectValuesForMode:mode] hostPrimaries:kFxColorPrimaries_Rec2020 colorInfo:kFxImageColorInfo_RGB_LINEAR];
}

- (void)assertPixel:(simd_float4)pixel equals:(simd_float4)expected accuracy:(float)accuracy
{
	XCTAssertEqualWithAccuracy(pixel.x, expected.x, accuracy);
	XCTAssertEqualWithAccuracy(pixel.y, expected.y, accuracy);
	XCTAssertEqualWithAccuracy(pixel.z, expected.z, accuracy);
	XCTAssertEqualWithAccuracy(pixel.w, expected.w, accuracy);
}

/*! A 4×1 RGBA32Float texture holding the given samples. */
- (id<MTLTexture>)rampTextureWithSamples:(const simd_float4 *)samples
{
	MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:4 height:1 mipmapped:NO];
	id<MTLTexture> texture = [FxGripShaderTestDevice() newTextureWithDescriptor:descriptor];
	[texture replaceRegion:MTLRegionMake2D(0, 0, 4, 1) mipmapLevel:0 withBytes:samples bytesPerRow:4 * sizeof(simd_float4)];
	return texture;
}

#pragma mark Signature and sharing

/*! @abstract The signature lists the constant keys sorted, each with its components, as the fragment pipeline's does. */
- (void)testTheConstantSignatureListsSortedKeysWithComponents
{
	FxGripKernelPipeline *pipeline = [self pipelineNamed:@"GripBlur"];

	XCTAssertEqualObjects(([pipeline constantSignatureForValues:[self valuesWithComponents:@{ @"TAPS": @[@5], @"INVERT": @[@1], @"radius": @[@3] }]]), @"INVERT=1;TAPS=5");
	XCTAssertEqualObjects([pipeline constantSignatureForValues:[FxGripShaderValues new]], @"INVERT=;TAPS=");
}

/*! @abstract The shared pipeline is one object per Metal source and metadata. */
- (void)testTheSharedPipelineIsOnePerSourceAndMetadata
{
	NSString *metal = FxGripKernelTestMetalSource(@"GripBlur");
	FxGripKernelLayout *layout = FxGripKernelTestLayout(@"GripBlur", NULL);
	FxGripShaderMetadata *metadata = FxGripKernelTestMetadata(@"GripBlur", NULL);
	FxGripShaderMetadata *other = FxGripKernelTestMetadata(@"GripInspect", NULL);

	FxGripKernelPipeline *first = [FxGripKernelPipeline sharedPipelineWithMetalSource:metal layout:layout metadata:metadata];
	FxGripKernelPipeline *second = [FxGripKernelPipeline sharedPipelineWithMetalSource:[metal mutableCopy] layout:layout metadata:metadata];
	FxGripKernelPipeline *otherMetadata = [FxGripKernelPipeline sharedPipelineWithMetalSource:metal layout:layout metadata:other];

	XCTAssertEqual(first, second);
	XCTAssertNotEqual(first, otherMetadata);
	XCTAssertEqual(first.layout, layout);
	XCTAssertEqualObjects(first.metalSource, metal);
}

/*! @abstract The conversion runs only for declared primaries that differ from the host's. */
- (void)testTheConversionRunsOnlyForDifferingDeclaredPrimaries
{
	FxGripKernelPipeline *rec709 = [self pipelineNamed:@"GripBlur"];
	FxGripKernelPipeline *rec2020 = [self pipelineNamed:@"GripInspect"];
	FxGripKernelPipeline *host = [self blurPipelineWithMetadataBody:@"{ colorSpace: { primaries: \"host\" } }"];

	XCTAssertFalse([rec709 convertsFromHostPrimaries:kFxColorPrimaries_Rec709]);
	XCTAssertTrue([rec709 convertsFromHostPrimaries:kFxColorPrimaries_Rec2020]);
	XCTAssertTrue([rec2020 convertsFromHostPrimaries:kFxColorPrimaries_Rec709]);
	XCTAssertFalse([rec2020 convertsFromHostPrimaries:kFxColorPrimaries_Rec2020]);
	XCTAssertFalse([host convertsFromHostPrimaries:kFxColorPrimaries_Rec709]);
}

#pragma mark Uniform packing

/*! @abstract The packed uniforms struct holds each bound value at its JSON offset and zero elsewhere. */
- (void)testTheUniformsPackEachValueAtItsJSONOffset
{
	FxGripKernelPipeline *pipeline = [self pipelineNamed:@"GripBlur"];
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"radius": @[@2], @"tint": @[@0.25, @0.5, @0.75], @"TAPS": @[@3] }];

	NSData *data = [pipeline uniformDataForValues:values];

	XCTAssertEqual(data.length, (NSUInteger)48);
	XCTAssertEqual(FxGripKernelReadFloat(data, 0), 2.0f);
	XCTAssertEqual(FxGripKernelReadFloat(data, 16), 0.25f);
	XCTAssertEqual(FxGripKernelReadFloat(data, 20), 0.5f);
	XCTAssertEqual(FxGripKernelReadFloat(data, 24), 0.75f);
	XCTAssertEqual(FxGripKernelReadFloat(data, 28), 0.0f, @"the vector's padding stays zero");
	XCTAssertEqual(FxGripKernelReadFloat(data, 32), 0.0f, @"a member with no parameter stays zero");
	XCTAssertEqual(((const uint8_t *)data.bytes)[40], (uint8_t)0);
}

/*! @abstract Integer, bool, half, and narrow members convert the value as the fragment path does. */
- (void)testNarrowMembersConvertTheValue
{
	FxGripKernelPipeline *pipeline = [self pipelineNamed:@"GripInspect"];
	FxGripShaderValues *values = [self valuesWithComponents:@{
		@"center": @[@5], @"invert": @[@0.25], @"count": @[@-5], @"level": @[@0.5], @"small": @[@40000], @"byte": @[@300],
	}];

	NSData *data = [pipeline uniformDataForValues:values];
	const uint8_t *bytes = data.bytes;
	uint32_t count = 1;
	__fp16 level = 0;
	int16_t small = 0;
	memcpy(&count, bytes + 20, sizeof(count));
	memcpy(&level, bytes + 24, sizeof(level));
	memcpy(&small, bytes + 26, sizeof(small));

	XCTAssertEqual(data.length, (NSUInteger)40);
	XCTAssertEqual(FxGripKernelReadFloat(data, 8), 5.0f);
	XCTAssertEqual(FxGripKernelReadFloat(data, 12), 0.0f, @"a missing component stays zero");
	XCTAssertEqual(bytes[16], (uint8_t)1);
	XCTAssertEqual(count, (uint32_t)0);
	XCTAssertEqual((float)level, 0.5f);
	XCTAssertEqual(small, (int16_t)INT16_MAX);
	XCTAssertEqual(bytes[28], (uint8_t)UINT8_MAX);
}

/*! @abstract A kernel with no uniforms buffer packs no data. */
- (void)testAKernelWithoutUniformsPacksNoData
{
	NSData *layoutData = FxGripKernelTestEditedLayoutData(@"GripBlur", ^(NSMutableDictionary *root) {
		[root[@"parameters"] removeObjectAtIndex:0];
	});
	FxGripKernelPipeline *pipeline = FxGripKernelTestPipeline(@"GripBlur", nil, layoutData, nil);

	XCTAssertNil([pipeline uniformDataForValues:[self valuesWithComponents:@{ @"radius": @[@2] }]]);
}

#pragma mark Binding failures

/*! @abstract A member whose component count differs from its parameter's refuses the state. */
- (void)testAMismatchedMemberRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelPipeline *pipeline = [self blurPipelineWithMetadataBody:@"{ parameters: [ { id: 1, type: \"rgb\", name: \"Radius\", key: \"radius\" } ] }"];

	NSError *error = [self stateFailureOfPipeline:pipeline values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];

	XCTAssertTrue([error.localizedDescription containsString:@"radius"]);
}

/*! @abstract A member bound to a parameter type with no scalar value, or an array member bound by key, refuses the state. */
- (void)testANonScalarBindingRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelPipeline *string = [self blurPipelineWithMetadataBody:@"{ parameters: [ { id: 1, type: \"string\", name: \"Radius\", key: \"radius\" } ] }"];
	NSData *swapped = FxGripKernelTestEditedLayoutData(@"GripBlur", ^(NSMutableDictionary *root) {
		// The tile's struct, renamed, reads as the uniforms, so its array member is bound by key.
		root[@"parameters"][1][@"type"][@"elementType"][@"name"] = @"Tile";
		[root[@"parameters"] removeObjectAtIndex:0];
	});
	FxGripShaderMetadata *textures = [FxGripShaderMetadata metadataWithSource:FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"float\", name: \"Textures\", key: \"textures\" } ] }", @"") error:NULL];
	FxGripKernelPipeline *array = FxGripKernelTestPipeline(@"GripBlur", nil, swapped, textures);

	[self stateFailureOfPipeline:string values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];
	NSError *error = [self stateFailureOfPipeline:array values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];
	XCTAssertTrue([error.localizedDescription containsString:@"textures"]);
}

/*! @abstract A texture named by a scalar parameter's key, or the destination named by any key, refuses the state. */
- (void)testAScalarKeyOnATextureRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelPipeline *scalar = [self blurPipelineWithMetadataBody:@"{ parameters: [ { id: 1, type: \"float\", name: \"Matte\", key: \"matte\" } ] }"];
	FxGripKernelPipeline *destination = [self blurPipelineWithMetadataBody:@"{ parameters: [ { id: 1, type: \"imageref\", name: \"Out\", key: \"destination\" } ] }"];

	[self stateFailureOfPipeline:scalar values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];
	NSError *error = [self stateFailureOfPipeline:destination values:[FxGripShaderValues new] code:kFxGripError_ShaderBindingInvalid];
	XCTAssertTrue([error.localizedDescription containsString:@"destination"]);
}

/*! @abstract A constant parameter with more than one component refuses the state. */
- (void)testAVectorConstantParameterRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelPipeline *pipeline = [self blurPipelineWithMetadataBody:
		@"{ parameters: [ { id: 1, type: \"rgb\", name: \"Taps\", key: \"TAPS\", constant: true, allowContinuousConstant: true } ] }"];

	NSError *error = [self stateFailureOfPipeline:pipeline values:[self valuesWithComponents:@{ @"TAPS": @[@1, @0, @0] }] code:kFxGripError_ShaderBindingInvalid];

	XCTAssertTrue([error.localizedDescription containsString:@"TAPS"]);
}

/*! @abstract A constant whose type in the JSON differs from the compiled function's refuses the state. */
- (void)testAStaleConstantTypeRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSData *layoutData = FxGripKernelTestEditedLayoutData(@"GripBlur", ^(NSMutableDictionary *root) {
		for (NSMutableDictionary *parameter in root[@"parameters"]) {
			if ([parameter[@"name"] isEqualToString:@"TAPS"]) {
				parameter[@"type"][@"scalarType"] = @"bool";
			}
		}
	});
	FxGripKernelPipeline *pipeline = FxGripKernelTestPipeline(@"GripBlur", nil, layoutData, nil);

	NSError *error = [self stateFailureOfPipeline:pipeline values:[self valuesWithComponents:@{ @"TAPS": @[@3] }] code:kFxGripError_ShaderBindingInvalid];

	XCTAssertTrue([error.localizedDescription containsString:@"rebuild"]);
}

/*! The blur fixture's Metal source with the default stripped from the TAPS constant, so Metal reports it required. */
- (NSString *)blurMetalSourceRequiringTaps
{
	NSString *source = FxGripKernelTestMetalSource(@"GripBlur");
	NSString *required = [source stringByReplacingOccurrencesOfString:@"is_function_constant_defined(fc_TAPS_0) ? fc_TAPS_0 : int(9)" withString:@"fc_TAPS_0"];
	XCTAssertNotEqualObjects(required, source, @"the fixture declares the TAPS default the test strips");
	return required;
}

/*! @abstract A required function constant with no value refuses the state. */
- (void)testARequiredConstantWithoutAValueRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelPipeline *pipeline = FxGripKernelTestPipeline(@"GripBlur", [self blurMetalSourceRequiringTaps], nil, nil);

	NSError *error = [self stateFailureOfPipeline:pipeline values:[self valuesWithComponents:@{ @"INVERT": @[@0] }] code:kFxGripError_ShaderBindingInvalid];

	XCTAssertTrue([error.localizedDescription containsString:@"TAPS"]);
}

/*! @abstract A required function constant that no constant parameter binds refuses the state. */
- (void)testAnUnboundRequiredConstantRefusesTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderMetadata *metadata = [FxGripShaderMetadata metadataWithSource:FxGripShaderTestSource(
		@"{ parameters: [ { id: 2, type: \"integer\", name: \"Taps\", key: \"TAPS\" } ] }", @"") error:NULL];
	FxGripKernelPipeline *pipeline = FxGripKernelTestPipeline(@"GripBlur", [self blurMetalSourceRequiringTaps], nil, metadata);

	NSError *error = [self stateFailureOfPipeline:pipeline values:[self valuesWithComponents:@{ @"TAPS": @[@1] }] code:kFxGripError_ShaderBindingInvalid];

	XCTAssertTrue([error.localizedDescription containsString:@"TAPS"]);
}

#pragma mark Compilation

/*! @abstract A Metal source that fails to compile fails the state, names the Slang line, and is cached. */
- (void)testACompileFailureIsReportedAndCached
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *broken = [FxGripKernelTestMetalSource(@"GripBlur") stringByReplacingOccurrencesOfString:@"float4 color_0 = sum_0" withString:@"float4 color_0 = nothing"];
	FxGripKernelPipeline *pipeline = FxGripKernelTestPipeline(@"GripBlur", broken, nil, nil);
	NSError *first = nil;
	NSError *second = nil;

	XCTAssertNil([pipeline libraryForDevice:FxGripShaderTestDevice() error:&first]);
	XCTAssertNil([pipeline libraryForDevice:FxGripShaderTestDevice() error:&second]);

	XCTAssertEqual(first.code, (NSInteger)kFxGripError_ShaderCompileFailed);
	XCTAssertEqual(first, second);
	XCTAssertNotNil(first.userInfo[NSUnderlyingErrorKey]);
	XCTAssertTrue([first.localizedDescription containsString:@"GripBlur.slang:58"], @"%@", first.localizedDescription);
}

/*! @abstract A layout whose entry point is not in the library fails the state. */
- (void)testAMissingEntryPointFailsTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSData *layoutData = FxGripKernelTestEditedLayoutData(@"GripBlur", ^(NSMutableDictionary *root) {
		root[@"entryPoints"][0][@"name"] = @"otherKernel";
	});
	FxGripKernelPipeline *pipeline = FxGripKernelTestPipeline(@"GripBlur", nil, layoutData, nil);

	NSError *error = [self stateFailureOfPipeline:pipeline values:[FxGripShaderValues new] code:kFxGripError_ShaderCompileFailed];

	XCTAssertTrue([error.localizedDescription containsString:@"otherKernel"]);
}

/*! @abstract A threadgroup larger than the pipeline allows fails the state. */
- (void)testAnOversizedThreadgroupFailsTheState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSData *layoutData = FxGripKernelTestEditedLayoutData(@"GripBlur", ^(NSMutableDictionary *root) {
		root[@"entryPoints"][0][@"threadGroupSize"] = @[@1024, @1024, @1];
	});
	FxGripKernelPipeline *pipeline = FxGripKernelTestPipeline(@"GripBlur", nil, layoutData, nil);

	[self stateFailureOfPipeline:pipeline values:[FxGripShaderValues new] code:kFxGripError_ShaderCompileFailed];
}

/*! @abstract Equal constant values reuse one state, and a new value builds another. */
- (void)testStatesAreCachedPerConstantSet
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelPipeline *pipeline = [self pipelineNamed:@"GripBlur"];
	id<MTLDevice> device = FxGripShaderTestDevice();
	NSError *error = nil;

	FxGripKernelPipelineState *five = [pipeline stateForDevice:device values:[self valuesWithComponents:@{ @"TAPS": @[@5], @"radius": @[@1] }] error:&error];
	FxGripKernelPipelineState *fiveAgain = [pipeline stateForDevice:device values:[self valuesWithComponents:@{ @"TAPS": @[@5], @"radius": @[@9] }] error:NULL];
	FxGripKernelPipelineState *three = [pipeline stateForDevice:device values:[self valuesWithComponents:@{ @"TAPS": @[@3] }] error:NULL];

	XCTAssertNotNil(five, @"%@", error);
	XCTAssertEqual(five, fiveAgain, @"a uniform value does not key the cache");
	XCTAssertNotEqual(five, three);
	XCTAssertEqualObjects(five.constantSignature, @"INVERT=;TAPS=5");
	XCTAssertNotNil(five.computePipelineState);
}

/*! @abstract The cache keeps its limit of states and rebuilds the oldest one after eviction. */
- (void)testTheStateCacheEvictsTheOldestState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelPipeline *pipeline = [self pipelineNamed:@"GripInspect"];
	id<MTLDevice> device = FxGripShaderTestDevice();
	FxGripKernelPipelineState *(^stateAt)(NSUInteger) = ^FxGripKernelPipelineState *(NSUInteger fill) {
		return [pipeline stateForDevice:device values:[self valuesWithComponents:@{ @"FILL": @[@(fill)] }] error:NULL];
	};

	FxGripKernelPipelineState *oldest = stateAt(0);
	for (NSUInteger fill = 1; fill < kFxGripShaderPipelineStateCacheLimit; fill++) {
		stateAt(fill);
	}
	XCTAssertEqual(stateAt(0), oldest, @"the cache holds its limit");
	FxGripKernelPipelineState *newest = stateAt(kFxGripShaderPipelineStateCacheLimit);

	XCTAssertEqual(stateAt(kFxGripShaderPipelineStateCacheLimit), newest);
	XCTAssertNotEqual(stateAt(0), oldest, @"the oldest state is evicted and rebuilt");
}

#pragma mark Rendering

/*! @abstract The worked example renders its tint over a one-tap sample, multiplied by the keyed matte's alpha. */
- (void)testTheBlurKernelRendersTintOverTheSource
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 4, 4 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.8f, 0.8f, 0.8f, 1.0f));
	FxImageTile *matte = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.5f));
	matte.parameterID = 12;
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"radius": @[@0], @"TAPS": @[@1], @"INVERT": @[@0], @"tint": @[@1, @0.5, @0.25] }];

	[self renderPipeline:[self pipelineNamed:@"GripBlur"] destination:destination sources:@[source, matte] keyedTextures:nil
				  values:values hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 2, 1) equals:simd_make_float4(0.4f, 0.2f, 0.1f, 1.0f) accuracy:1e-5f];
}

/*! @abstract The INVERT constant specializes the kernel. */
- (void)testTheConstantValueSpecializesTheKernel
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.8f, 0.6f, 0.4f, 1.0f));
	FxImageTile *matte = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f));
	matte.parameterID = 12;
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"radius": @[@0], @"TAPS": @[@1], @"INVERT": @[@1], @"tint": @[@1, @1, @1] }];

	[self renderPipeline:[self pipelineNamed:@"GripBlur"] destination:destination sources:@[source, matte] keyedTextures:nil
				  values:values hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 0) equals:simd_make_float4(0.2f, 0.4f, 0.6f, 1.0f) accuracy:1e-5f];
}

/*! @abstract A keyed image whose parameter supplies no tile binds transparent black. */
- (void)testAKeyedImageWithoutATileBindsTransparentBlack
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.8f, 0.6f, 0.4f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(1.0f, 1.0f, 1.0f, 1.0f));
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"radius": @[@0], @"TAPS": @[@1], @"INVERT": @[@0], @"tint": @[@1, @1, @1] }];

	[self renderPipeline:[self pipelineNamed:@"GripBlur"] destination:destination sources:@[source] keyedTextures:nil
				  values:values hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 1, 1) equals:simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f) accuracy:1e-6f];
}

/*! @abstract A pixelUnits uniform and constant scale by the destination's horizontal pixel scale, and other values do not. */
- (void)testPixelUnitValuesScaleToTheDestination
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxImageTile *destination = FxGripKernelScaledTile((FxRect){ 0, 0, 2, 2 }, 0.5, 0.5, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"MODE": @[@0], @"radius": @[@8], @"gain": @[@8], @"TAPS": @[@8] }];

	[self renderPipeline:[self pipelineNamed:@"GripInspect"] destination:destination sources:@[] keyedTextures:nil
				  values:values hostPrimaries:kFxColorPrimaries_Rec2020 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 1, 1) equals:simd_make_float4(4.0f, 8.0f, 4.0f, 1.0f) accuracy:1e-6f];
	XCTAssertEqualObjects([values componentsForKey:@"radius"], (@[@8]), @"the render scales a copy of the values");
}

/*! @abstract gripImagePixel is the destination pixel center in image space, y up, and the tile carries the pixel scale. */
- (void)testTheTileCarriesTheImagePixelAndThePixelScale
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxImageTile *destination = FxGripKernelScaledTile((FxRect){ 10, 20, 14, 24 }, 0.5, 0.25, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderInspectMode:1 destination:destination sources:@[]];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 0) equals:simd_make_float4(10.5f, 23.5f, 0.5f, 0.25f) accuracy:1e-4f];
	[self assertPixel:FxGripShaderTestPixel(destination, 3, 3) equals:simd_make_float4(13.5f, 20.5f, 0.5f, 0.25f) accuracy:1e-4f];
}

/*! @abstract gripTexCoord maps a destination pixel into each source by its own bounds and through a proxy pixel transform. */
- (void)testTheTileMapsEachSourceByItsOwnBounds
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxImageTile *first = FxGripShaderTestFloatTile((FxRect){ 0, 0, 8, 8 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxImageTile *second = FxGripShaderTestFloatTile((FxRect){ 2, 2, 6, 6 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxImageTile *destination = FxGripKernelScaledTile((FxRect){ 0, 0, 4, 4 }, 0.5, 0.5, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderInspectMode:2 destination:destination sources:@[first, second]];

	// Destination pixel (1, 2) has its center at (1.5, 1.5); image space (3, 3); texture 0 covers 0 through 8 and texture 1 covers 2 through 6.
	[self assertPixel:FxGripShaderTestPixel(destination, 1, 2) equals:simd_make_float4(0.375f, 0.625f, 0.25f, 0.75f) accuracy:1e-5f];
}

/*! @abstract Each unkeyed texture takes the source images in declaration order, sampled through the bilinear sampler. */
- (void)testUnkeyedTexturesTakeTheSourcesInDeclarationOrder
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *first = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.75f, 0.5f, 0.25f, 1.0f));
	FxImageTile *second = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.25f, 0.25f, 0.25f, 0.5f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderInspectMode:3 destination:destination sources:@[first, second]];

	[self assertPixel:FxGripShaderTestPixel(destination, 1, 0) equals:simd_make_float4(0.5f, 0.25f, 0.0f, 0.5f) accuracy:1e-6f];
}

/*! @abstract A source texture past the last source image binds transparent black. */
- (void)testATexturePastTheSourcesBindsTransparentBlack
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *first = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.75f, 0.5f, 0.25f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderInspectMode:3 destination:destination sources:@[first]];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 1) equals:simd_make_float4(0.75f, 0.5f, 0.25f, 1.0f) accuracy:1e-6f];
}

/*! @abstract The uniforms reach the kernel with the documented conversions. */
- (void)testTheUniformsReachTheKernel
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *center = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxImageTile *narrow = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderInspectMode:4 destination:center sources:@[]];
	[self renderInspectMode:5 destination:narrow sources:@[]];

	[self assertPixel:FxGripShaderTestPixel(center, 0, 0) equals:simd_make_float4(5.0f, 6.0f, 1.0f, 7.0f) accuracy:1e-6f];
	[self assertPixel:FxGripShaderTestPixel(narrow, 1, 1) equals:simd_make_float4(0.5f, (float)INT16_MAX, 255.0f, 0.0f) accuracy:1e-6f];
}

/*! @abstract A keyed image maps by its own bounds, a keyed gradient binds its texture, and textureCount counts the destination. */
- (void)testKeyedImageAndGradientBindByName
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *first = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f));
	FxImageTile *mask = FxGripShaderTestFloatTile((FxRect){ 0, 0, 4, 4 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderTestFillTile(mask, ^simd_float4(NSUInteger column, NSUInteger row) {
		return simd_make_float4((float)column, (float)row, 0.0f, 1.0f);
	});
	mask.parameterID = 13;
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	const simd_float4 samples[4] = { { 0, 0, 0.1f, 1 }, { 0, 0, 0.2f, 1 }, { 0, 0, 0.3f, 1 }, { 0, 0, 0.4f, 1 } };

	[self renderPipeline:[self pipelineNamed:@"GripInspect"] destination:destination sources:@[first, mask]
		   keyedTextures:@{ @"ramp": [self rampTextureWithSamples:samples] }
				  values:[self inspectValuesForMode:6] hostPrimaries:kFxColorPrimaries_Rec2020 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	// Destination pixel (1, 0) is image pixel (1.5, 1.5), which is mask texel column 1, row 2 of its 4×4 tile; the mask is texture 3 and the destination 4.
	[self assertPixel:FxGripShaderTestPixel(destination, 1, 0) equals:simd_make_float4(1.0f, 2.0f, 0.3f, 5.0f) accuracy:1e-6f];
}

/*! @abstract A float constant reaches the kernel through the signature. */
- (void)testAFloatConstantReachesTheKernel
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderInspectMode:8 destination:destination sources:@[]];

	[self assertPixel:FxGripShaderTestPixel(destination, 1, 1) equals:simd_make_float4(0.75f, 0.75f, 0.75f, 0.75f) accuracy:1e-6f];
}

/*! @abstract A destination whose texture allows no shader write receives the kernel's output through a blit. */
- (void)testAReadOnlyDestinationReceivesTheOutputThroughABlit
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 3, 3 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	id<MTLTexture> backing = [destination metalTextureForDevice:FxGripShaderTestDevice()];
	MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:backing.pixelFormat width:3 height:3 mipmapped:NO];
	descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
	id<MTLTexture> readOnly = [FxGripShaderTestDevice() newTextureWithDescriptor:descriptor];
	destination.stubTexture = readOnly;

	[self renderInspectMode:8 destination:destination sources:@[]];

	simd_float4 pixel = 0.0f;
	[readOnly getBytes:&pixel bytesPerRow:sizeof(pixel) fromRegion:MTLRegionMake2D(2, 2, 1, 1) mipmapLevel:0];
	[self assertPixel:pixel equals:simd_make_float4(0.75f, 0.75f, 0.75f, 0.75f) accuracy:1e-6f];
}

/*! @abstract Concurrent renders with different constant sets each draw their own value. */
- (void)testConcurrentRendersDrawTheirOwnConstants
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelPipeline *pipeline = [self pipelineNamed:@"GripInspect"];
	const NSUInteger renders = 16;
	NSMutableArray<FxImageTile *> *destinations = [NSMutableArray array];
	for (NSUInteger index = 0; index < renders; index++) {
		[destinations addObject:FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(-1.0f, -1.0f, -1.0f, -1.0f))];
	}
	__block NSUInteger failures = 0;
	NSLock *failuresLock = [NSLock new];

	dispatch_apply(renders, DISPATCH_APPLY_AUTO, ^(size_t index) {
		FxGripShaderValues *values = [self valuesWithComponents:@{ @"MODE": @[@8], @"FILL": @[@((double)(index % 4))] }];
		if (![pipeline renderDestinationImage:destinations[index] sourceImages:@[] values:values
								hostPrimaries:kFxColorPrimaries_Rec2020 colorInfo:kFxImageColorInfo_RGB_LINEAR error:NULL]) {
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

/*! @abstract A rec2020 kernel under a rec709 host sees converted input and its output converts back. */
- (void)testARec2020KernelConvertsUnderARec709Host
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(1.0f, 0.0f, 0.0f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	simd_float3x3 toKernel = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec709, kFxColorPrimaries_Rec2020);
	simd_float3x3 toHost = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec2020, kFxColorPrimaries_Rec709);
	float kernelRed = simd_mul(toKernel, simd_make_float3(1.0f, 0.0f, 0.0f)).x;
	simd_float3 expected = simd_mul(toHost, simd_make_float3(kernelRed, 0.0f, 0.0f));

	[self renderPipeline:[self pipelineNamed:@"GripInspect"] destination:destination sources:@[source] keyedTextures:nil
				  values:[self inspectValuesForMode:7] hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	XCTAssertLessThan(kernelRed, 0.9f, @"the kernel sees rec2020 red, which is less saturated");
	[self assertPixel:FxGripShaderTestPixel(destination, 1, 1) equals:simd_make_float4(expected.x, expected.y, expected.z, 1.0f) accuracy:1e-4f];
}

/*! @abstract Matching primaries render with no conversion. */
- (void)testMatchingPrimariesRenderUnconverted
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(1.0f, 0.0f, 0.0f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));

	[self renderInspectMode:7 destination:destination sources:@[source]];

	[self assertPixel:FxGripShaderTestPixel(destination, 0, 0) equals:simd_make_float4(1.0f, 0.0f, 0.0f, 1.0f) accuracy:1e-6f];
}

/*! @abstract A gamma image is unpremultiplied, decoded, converted, encoded, and premultiplied again. */
- (void)testAGammaImageConvertsInLinearLight
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 2, 2 };
	float alpha = 0.5f;
	simd_float3 straight = simd_make_float3(0.8f, 0.4f, 0.2f);
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(straight * alpha, alpha));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	simd_float3x3 toKernel = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec709, kFxColorPrimaries_Rec2020);
	simd_float3x3 toHost = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec2020, kFxColorPrimaries_Rec709);
	simd_float3 inKernel = FxGripKernelEncodeSRGB3(simd_mul(toKernel, FxGripKernelDecodeSRGB3(straight)));
	simd_float3 expected = FxGripKernelEncodeSRGB3(simd_mul(toHost, FxGripKernelDecodeSRGB3(simd_make_float3(inKernel.x, 0.0f, 0.0f))));

	[self renderPipeline:[self pipelineNamed:@"GripInspect"] destination:destination sources:@[source] keyedTextures:nil
				  values:[self inspectValuesForMode:7] hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_GAMMA_VIDEO];

	[self assertPixel:FxGripShaderTestPixel(destination, 1, 0) equals:simd_make_float4(expected * alpha, alpha) accuracy:1e-4f];
}

#pragma mark Render failures

/*! @abstract A destination tile with no device fails the render. */
- (void)testADestinationWithoutADeviceFailsTheRender
{
	FxGripKernelPipeline *pipeline = [self pipelineNamed:@"GripBlur"];
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
	FxGripKernelPipeline *pipeline = [self pipelineNamed:@"GripBlur"];
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxImageTile *source = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 2, 2 }];
	NSError *error = nil;

	XCTAssertFalse([pipeline renderDestinationImage:destination sourceImages:@[source] values:[self valuesWithComponents:@{ @"TAPS": @[@1] }]
									  hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR error:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderRenderFailed);
}

/*! @abstract A pipeline failure fails the render with the pipeline's error. */
- (void)testAPipelineFailureFailsTheRender
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelPipeline *pipeline = FxGripKernelTestPipeline(@"GripBlur", @"not metal", nil, nil);
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	NSError *error = nil;

	XCTAssertFalse([pipeline renderDestinationImage:destination sourceImages:@[] values:[FxGripShaderValues new]
									  hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR error:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderCompileFailed);
}

#pragma mark Toolchain

/*! @abstract The framework ships GripKernel.slang as a resource that declares the module. */
- (void)testTheFrameworkShipsTheKernelModule
{
	NSURL *module = FxGripKernelTestModuleURL();
	NSString *source = module != nil ? [NSString stringWithContentsOfURL:module encoding:NSUTF8StringEncoding error:NULL] : nil;

	XCTAssertNotNil(source);
	XCTAssertTrue([source containsString:@"module GripKernel;"]);
	XCTAssertTrue([source containsString:@"public struct GripTile"]);
	XCTAssertTrue([source containsString:@"public float2 gripTexCoord(GripTile tile, uint index, float2 imagePixel)"]);
}

/*! @abstract slangc compiles the fixture against the shipped module with the documented command, and the output renders. */
- (void)testSlangcBuildsTheFixtureAgainstTheShippedModule
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	NSString *slangc = FxGripKernelTestSlangcPath();
	XCTSkipIf(slangc == nil, @"No slangc: set FXGRIP_SLANGC or add slangc to the PATH.");
	NSURL *module = FxGripKernelTestModuleURL();
	XCTAssertNotNil(module);
	NSURL *directory = [NSFileManager.defaultManager.temporaryDirectory URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:NULL];
	NSURL *kernel = [directory URLByAppendingPathComponent:@"GripBlur.slang"];
	XCTAssertTrue([FxGripKernelTestSlangSource(@"GripBlur") writeToURL:kernel atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
	NSURL *metal = [directory URLByAppendingPathComponent:@"GripBlur.metal"];
	NSURL *json = [directory URLByAppendingPathComponent:@"GripBlur.json"];

	NSTask *task = [NSTask new];
	task.executableURL = [NSURL fileURLWithPath:slangc];
	task.currentDirectoryURL = directory;
	task.arguments = @[@"-I", module.URLByDeletingLastPathComponent.path, @"GripBlur.slang",
					   @"-target", @"metal", @"-entry", @"fxGripKernel", @"-stage", @"compute",
					   @"-line-directive-mode", @"standard", @"-reflection-json", json.path, @"-o", metal.path];
	NSPipe *output = [NSPipe pipe];
	task.standardError = output;
	task.standardOutput = output;
	NSError *launchError = nil;
	XCTAssertTrue([task launchAndReturnError:&launchError], @"%@", launchError);
	[task waitUntilExit];
	NSString *diagnostics = [[NSString alloc] initWithData:[output.fileHandleForReading readDataToEndOfFile] encoding:NSUTF8StringEncoding];
	XCTAssertEqual(task.terminationStatus, 0, @"%@", diagnostics);

	NSError *error = nil;
	FxGripKernelLayout *layout = [FxGripKernelLayout layoutWithContentsOfURL:json error:&error];
	XCTAssertNotNil(layout, @"%@", error);
	XCTAssertEqualObjects(layout.entryPointName, @"fxGripKernel");
	XCTAssertEqual(layout.tileBufferIndex, (NSUInteger)1);
	NSString *metalSource = [NSString stringWithContentsOfURL:metal encoding:NSUTF8StringEncoding error:&error];
	XCTAssertNotNil(metalSource, @"%@", error);
	FxGripKernelPipeline *pipeline = [[FxGripKernelPipeline alloc] initWithMetalSource:metalSource layout:layout
																			  metadata:FxGripKernelTestMetadata(@"GripBlur", NULL)];
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.8f, 0.8f, 0.8f, 1.0f));
	FxImageTile *matte = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f));
	matte.parameterID = 12;
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	FxGripShaderValues *values = [self valuesWithComponents:@{ @"radius": @[@0], @"TAPS": @[@1], @"INVERT": @[@0], @"tint": @[@1, @0.5, @0.25] }];

	[self renderPipeline:pipeline destination:destination sources:@[source, matte] keyedTextures:nil
				  values:values hostPrimaries:kFxColorPrimaries_Rec709 colorInfo:kFxImageColorInfo_RGB_LINEAR];

	[self assertPixel:FxGripShaderTestPixel(destination, 1, 1) equals:simd_make_float4(0.8f, 0.4f, 0.2f, 1.0f) accuracy:1e-5f];
	[NSFileManager.defaultManager removeItemAtURL:directory error:NULL];
}

@end
