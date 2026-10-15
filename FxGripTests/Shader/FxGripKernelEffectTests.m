/*!
	@file       FxGripKernelEffectTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripKernelEffectTests
	@abstract   Verifies the bridge from a Slang kernel to the effect's parameters, plugin state, and render.
	@discussion Introduced in FxGrip 0.1.0. A test effect names a fixture kernel by URL, so the
	            effect reads the Metal source and the reflection JSON beside it. The tests confirm
	            the parameters scanned from the Slang source, the plugin state round trip, the
	            failures for a missing or invalid build output, and the render through the host
	            entry point.
*/

#import <XCTest/XCTest.h>
#import "FxPlugStub.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripKernelEffect.h>
#import <FxGrip/FxGripTileableEffect+Parameters.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/NSCoder+FxPlug.h>
#import <BEFoundation/NSCoder+AtIndex.h>
#import "FxGripParameterClassTestSupport.h"
#import "FxGripShaderTestSupport.h"
#import "FxGripKernelTestSupport.h"

/*! Stages the kernel's URL or sources and the API manager. */
@interface FxGripKernelTestEffect : FxGripKernelEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, copy, nullable) NSURL *stagedURL;
@property (nonatomic, copy, nullable) NSString *stagedMetalSource;
@property (nonatomic, copy, nullable) NSData *stagedLayoutData;
@property (nonatomic, assign) BOOL overridesSources;
@property (nonatomic, strong, nullable) FxGripParamClassTestAPIManager *stubAPIManager;
@property (nonatomic, assign) FxColorPrimaries stubColorPrimaries;
@end

@implementation FxGripKernelTestEffect

- (id)effectBase
{
	return self;
}

- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		_privateNotifier = (NSNotificationCenter *)FxGripParamClassTestMakePriorityCenter();
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

- (NSDictionary<NSString *, id> *)pluginProperties
{
	return @{
		kProPlugPlugIn_UuidProperty: @"AAAABBBB-CCCC-DDDD-EEEE-FFFF00005555",
		kProPlugPlugIn_ClassNameProperty: @"FxGripKernelTestEffect",
		kProPlugPlugIn_GroupUUIDProperty: @"55550000-FFFF-EEEE-DDDD-CCCCBBBBAAAA",
	};
}

- (NSURL *)kernelURL
{
	return self.stagedURL;
}

- (NSString *)kernelMetalSource
{
	return self.overridesSources ? self.stagedMetalSource : [super kernelMetalSource];
}

- (NSData *)kernelLayoutData
{
	return self.overridesSources ? self.stagedLayoutData : [super kernelLayoutData];
}

- (id<FxGripAPIAccessing>)apiManager
{
	if (_stubAPIManager) {
		return (id<FxGripAPIAccessing>)_stubAPIManager;
	}
	return [super apiManager];
}

- (FxColorPrimaries)colorPrimaries
{
	return self.stubColorPrimaries;
}

@end

@interface FxGripKernelEffectTests : XCTestCase
@end

@implementation FxGripKernelEffectTests

- (FxGripKernelTestEffect *)effectWithKernel:(nullable NSString *)name
{
	FxGripKernelTestEffect *effect = [[FxGripKernelTestEffect alloc] initWithAPIManager:(id _Nonnull)nil];
	effect.stagedURL = name != nil ? FxGripKernelTestFixtureURL(name, @"slang") : nil;
	effect.stubColorPrimaries = kFxColorPrimaries_Rec709;
	return effect;
}

/*! The blur effect with the Metal source and reflection JSON staged in place of the files beside the kernel. */
- (FxGripKernelTestEffect *)blurEffectWithMetalSource:(nullable NSString *)metalSource layoutData:(nullable NSData *)layoutData
{
	FxGripKernelTestEffect *effect = [self effectWithKernel:@"GripBlur"];
	effect.overridesSources = YES;
	effect.stagedMetalSource = metalSource;
	effect.stagedLayoutData = layoutData;
	return effect;
}

/*! Posts the creation notification for every record, as the creation API does once the host has created each parameter. */
- (void)createParametersOfEffect:(FxGripKernelTestEffect *)effect
{
	for (NSDictionary *record in effect.shaderMetadata.allParameters) {
		[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName object:effect userInfo:record];
	}
}

- (FxGripParamClassTestRetrievalAPI *)stageRetrievalOnEffect:(FxGripKernelTestEffect *)effect
{
	FxGripParamClassTestAPIManager *manager = [FxGripParamClassTestAPIManager new];
	manager.paramGetAPIv6 = [FxGripParamClassTestRetrievalAPI new];
	manager.paramGetAPIv6.succeeds = YES;
	effect.stubAPIManager = manager;
	return manager.paramGetAPIv6;
}

- (nullable NSData *)pluginStateOfEffect:(FxGripKernelTestEffect *)effect
{
	NSData *state = nil;
	NSError *error = nil;
	XCTAssertTrue([effect pluginState:&state atTime:FxGripParamClassTestTime(0, 1) quality:kFxQuality_HIGH error:&error], @"%@", error);
	return state;
}

#pragma mark Sources

/*! @abstract The base class names no kernel and supplies no sources. */
- (void)testTheBaseClassNamesNoKernel
{
	FxGripKernelEffect *effect = [[FxGripKernelEffect alloc] initWithAPIManager:(id _Nonnull)nil];

	XCTAssertNil([effect kernelURL]);
	XCTAssertNil([effect kernelSource]);
	XCTAssertNil([effect kernelMetalSource]);
	XCTAssertNil([effect kernelLayoutData]);
	XCTAssertNil(effect.shaderMetadata);
	XCTAssertNil(effect.kernelLayout);
	XCTAssertNil(effect.kernelPipeline);
	XCTAssertNil(effect.kernelError);
	XCTAssertTrue([effect conformsToProtocol:@protocol(FxGripTileableEffectCoderState)]);
}

/*! @abstract The effect reads the Slang source, the Metal source, and the reflection JSON beside the kernel URL. */
- (void)testTheEffectReadsTheThreeFilesBesideTheKernel
{
	FxGripKernelTestEffect *effect = [self effectWithKernel:@"GripBlur"];

	XCTAssertEqualObjects([effect kernelSource], FxGripKernelTestSlangSource(@"GripBlur"));
	XCTAssertEqualObjects([effect shaderSource], FxGripKernelTestSlangSource(@"GripBlur"));
	XCTAssertEqualObjects([effect kernelMetalSource], FxGripKernelTestMetalSource(@"GripBlur"));
	XCTAssertEqualObjects([effect kernelLayoutData], FxGripKernelTestLayoutData(@"GripBlur"));
}

/*! @abstract The metadata is scanned from the Slang source, and the kernel pipeline replaces the shader pipeline. */
- (void)testTheMetadataComesFromTheSlangSourceAndTheKernelPipelineRenders
{
	FxGripKernelTestEffect *effect = [self effectWithKernel:@"GripBlur"];

	XCTAssertNotNil(effect.shaderMetadata);
	XCTAssertEqualObjects([effect.shaderMetadata.allParameters valueForKey:kFxParameterProperty_Id], (@[@1, @2, @3, @10, @11, @12]));
	XCTAssertEqual(effect.shaderMetadata.primaries, FxGripShaderPrimariesRec709);
	XCTAssertNil(effect.shaderPipeline);
	XCTAssertNotNil(effect.kernelPipeline);
	XCTAssertEqualObjects(effect.kernelLayout.entryPointName, @"fxGripKernel");
	XCTAssertEqual(effect.kernelPipeline.layout, effect.kernelLayout);
	XCTAssertNil(effect.kernelError);
}

/*! @abstract Instances with the same kernel share one pipeline. */
- (void)testInstancesShareOnePipelinePerKernel
{
	FxGripKernelTestEffect *first = [self effectWithKernel:@"GripBlur"];
	FxGripKernelTestEffect *second = [self effectWithKernel:@"GripBlur"];

	XCTAssertEqual(first.kernelPipeline, second.kernelPipeline);
	XCTAssertNotEqual(first.kernelPipeline, [self effectWithKernel:@"GripInspect"].kernelPipeline);
}

/*! @abstract A missing Metal source or reflection JSON sets kernelError and leaves the parameters intact. */
- (void)testAMissingBuildOutputSetsTheKernelError
{
	FxGripKernelTestEffect *noMetal = [self blurEffectWithMetalSource:nil layoutData:FxGripKernelTestLayoutData(@"GripBlur")];
	FxGripKernelTestEffect *noLayout = [self blurEffectWithMetalSource:FxGripKernelTestMetalSource(@"GripBlur") layoutData:nil];
	NSError *error = nil;

	XCTAssertNil(noMetal.kernelPipeline);
	XCTAssertEqual(noMetal.kernelError.code, (NSInteger)kFxGripError_ShaderCompileFailed);
	XCTAssertNil(noLayout.kernelPipeline);
	XCTAssertEqual(noLayout.kernelError.code, (NSInteger)kFxGripError_KernelLayoutMalformed);
	XCTAssertNotNil(noMetal.shaderMetadata);
	XCTAssertTrue([noMetal addParametersWithError:&error], @"%@", error);
}

/*! @abstract An invalid reflection JSON sets kernelError with the layout's error. */
- (void)testAnInvalidLayoutSetsTheKernelError
{
	NSData *invalid = FxGripKernelTestEditedLayoutData(@"GripBlur", ^(NSMutableDictionary *root) { root[@"entryPoints"] = @[]; });
	FxGripKernelTestEffect *effect = [self blurEffectWithMetalSource:FxGripKernelTestMetalSource(@"GripBlur") layoutData:invalid];

	XCTAssertNil(effect.kernelLayout);
	XCTAssertEqual(effect.kernelError.code, (NSInteger)kFxGripError_KernelLayoutInvalid);
}

#pragma mark Parameters

/*! @abstract A clean configuration creates the kernel's parameters with their keys. */
- (void)testACleanConfigurationCreatesTheKernelParameters
{
	FxGripKernelTestEffect *effect = [self effectWithKernel:@"GripBlur"];
	NSError *error = nil;

	XCTAssertTrue([effect addParametersWithError:&error], @"%@", error);

	XCTAssertEqualObjects([effect configurationForParameter:1][kFxGripShaderProperty_Key], @"radius");
	XCTAssertEqualObjects([effect configurationForParameter:2][kFxGripShaderProperty_Key], @"TAPS");
	XCTAssertEqualObjects([effect configurationForParameter:12][kFxGripShaderProperty_Key], @"matte");
	XCTAssertEqualObjects([[effect parametersConfiguration] valueForKey:kFxParameterProperty_Id], (@[@1, @2, @3, @10, @12]));
}

/*! @abstract A created parameter is found by its key. */
- (void)testACreatedParameterIsFoundByItsKey
{
	FxGripKernelTestEffect *effect = [self effectWithKernel:@"GripBlur"];
	[self createParametersOfEffect:effect];

	XCTAssertEqual([effect shaderParameterForKey:@"tint"].parameterID, (FxParameterId)11);
	XCTAssertNil([effect shaderParameterForKey:@"destination"]);
}

/*! @abstract The declared transfer becomes the processing color info in the properties. */
- (void)testTheDeclaredTransferBecomesTheProcessingColorInfo
{
	FxGripKernelTestEffect *effect = [self effectWithKernel:@"GripBlur"];
	NSDictionary *properties = nil;
	NSError *error = nil;

	XCTAssertTrue([effect properties:&properties error:&error]);

	XCTAssertEqual(effect.desiredProcessingColorInfo, (FxImageColorInfo)kFxImageColorInfo_RGB_LINEAR);
	XCTAssertNil(properties[kFxPropertyKey_DesiredProcessingColorInfo], @"linear is the host's default, which the properties omit");
}

#pragma mark Plugin state

/*! @abstract The plugin state carries the values, the host primaries, and the processing color info, and the render decodes them. */
- (void)testThePluginStateRoundTripsTheValuesAndColorSpace
{
	FxGripKernelTestEffect *effect = [self effectWithKernel:@"GripBlur"];
	[self createParametersOfEffect:effect];
	FxGripParamClassTestRetrievalAPI *retrieval = [self stageRetrievalOnEffect:effect];
	retrieval.floatValue = 3;
	retrieval.intValue = 5;
	retrieval.boolValue = YES;
	retrieval.red = 0.25;
	retrieval.green = 0.5;
	retrieval.blue = 0.75;
	effect.stubColorPrimaries = kFxColorPrimaries_Rec2020;
	effect.desiredProcessingColorInfo = kFxImageColorInfo_RGB_GAMMA_VIDEO;

	NSData *state = [self pluginStateOfEffect:effect];
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:state error:NULL];
	FxGripShaderValues *values = [unarchiver decodeObjectOfClass:FxGripShaderValues.class forKey:kFxGripShaderValuesCoderKey];

	XCTAssertEqualObjects(values.keys, (@[@"INVERT", @"TAPS", @"radius", @"tint"]));
	XCTAssertEqualObjects([values componentsForKey:@"radius"], (@[@3]));
	XCTAssertEqualObjects([values componentsForKey:@"TAPS"], (@[@5]));
	XCTAssertEqualObjects([values componentsForKey:@"INVERT"], (@[@1]));
	XCTAssertEqualObjects([values componentsForKey:@"tint"], (@[@0.25, @0.5, @0.75]));
	XCTAssertEqual([unarchiver decodeIntegerForKey:kFxGripShaderHostPrimariesCoderKey], (NSInteger)kFxColorPrimaries_Rec2020);
	XCTAssertEqual([unarchiver decodeIntegerForKey:kFxGripShaderColorInfoCoderKey], (NSInteger)kFxImageColorInfo_RGB_GAMMA_VIDEO);
}

/*! @abstract An effect whose build output is missing still encodes its state, so the render reports the kernel error. */
- (void)testAnEffectWithAKernelErrorStillEncodesItsState
{
	FxGripKernelTestEffect *effect = [self blurEffectWithMetalSource:nil layoutData:nil];
	[self createParametersOfEffect:effect];
	[self stageRetrievalOnEffect:effect].floatValue = 2;

	NSData *state = [self pluginStateOfEffect:effect];
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:state error:NULL];

	XCTAssertEqualObjects([[unarchiver decodeObjectOfClass:FxGripShaderValues.class forKey:kFxGripShaderValuesCoderKey] componentsForKey:@"radius"], (@[@2]));
}

#pragma mark Render

/*! @abstract The host render entry point dispatches the kernel with the encoded values and the keyed image. */
- (void)testTheHostRenderDispatchesTheKernel
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelTestEffect *effect = [self effectWithKernel:@"GripBlur"];
	[self createParametersOfEffect:effect];
	FxGripParamClassTestRetrievalAPI *retrieval = [self stageRetrievalOnEffect:effect];
	retrieval.floatValue = 0;
	retrieval.intValue = 1;
	retrieval.boolValue = NO;
	retrieval.red = 1;
	retrieval.green = 0.5;
	retrieval.blue = 0.25;
	NSData *state = [self pluginStateOfEffect:effect];
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.8f, 0.8f, 0.8f, 1.0f));
	FxImageTile *matte = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.5f));
	matte.parameterID = 12;
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	NSError *error = nil;

	XCTAssertTrue(([effect renderDestinationImage:destination sourceImages:@[source, matte] pluginState:state
										  atTime:FxGripParamClassTestTime(0, 1) error:&error]), @"%@", error);

	simd_float4 pixel = FxGripShaderTestPixel(destination, 1, 1);
	XCTAssertEqualWithAccuracy(pixel.x, 0.4f, 1e-5f);
	XCTAssertEqualWithAccuracy(pixel.y, 0.2f, 1e-5f);
	XCTAssertEqualWithAccuracy(pixel.z, 0.1f, 1e-5f);
	XCTAssertEqualWithAccuracy(pixel.w, 1.0f, 1e-5f);
}

/*! @abstract The render binds a keyed gradient decoded from the plugin state the gradient parameter encodes. */
- (void)testTheRenderBindsAGradientFromThePluginState
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelTestEffect *effect = [self effectWithKernel:@"GripInspect"];
	CMTime time = FxGripParamClassTestTime(0, 1);
	NSMutableData *gradient = [NSMutableData dataWithLength:sizeof(FxGripGradientHeader) + 3 * sizeof(simd_float4)];
	FxGripGradientFloat *samples = gradient.mutableBytes;
	samples->count = 3;
	samples->depth = kFxDepth_FLOAT32;
	samples->samples[2] = (FxGripFloat4){ .r = 0.25f, .g = 0.5f, .b = 0.75f, .a = 1.0f };
	FxGripShaderValues *values = [FxGripShaderValues new];
	[values setDouble:6 forKey:@"MODE"];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	archiver.renderTime = time;
	[archiver encodeObject:values forKey:kFxGripShaderValuesCoderKey];
	[archiver encodeInteger:kFxColorPrimaries_Rec2020 forKey:kFxGripShaderHostPrimariesCoderKey];
	[archiver encodeInteger:kFxImageColorInfo_RGB_LINEAR forKey:kFxGripShaderColorInfoCoderKey];
	[archiver encodeBytes:gradient.bytes length:gradient.length atIndex:12];
	[archiver finishEncoding];
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	NSError *error = nil;

	XCTAssertTrue([effect renderDestinationImage:destination sourceImages:@[] pluginState:archiver.encodedData
										  atTime:time error:&error], @"%@", error);

	simd_float4 pixel = FxGripShaderTestPixel(destination, 0, 0);
	XCTAssertEqualWithAccuracy(pixel.z, 0.75f, 1e-6f, @"the ramp's third sample");
	XCTAssertEqualWithAccuracy(pixel.w, 5.0f, 1e-6f, @"the destination at texture 4 counts");
}

/*! @abstract An effect with no kernel passes its first source image through. */
- (void)testAnEffectWithoutAKernelPassesItsInputThrough
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelTestEffect *effect = [self effectWithKernel:nil];
	NSData *state = [self pluginStateOfEffect:effect];
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.25f, 0.125f, 0.5f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	NSError *error = nil;

	XCTAssertTrue([effect renderDestinationImage:destination sourceImages:@[source] pluginState:state
										  atTime:FxGripParamClassTestTime(0, 1) error:&error], @"%@", error);

	XCTAssertEqualWithAccuracy(FxGripShaderTestPixel(destination, 0, 0).z, 0.5f, 1e-6f);
}

/*! @abstract An effect whose build output is missing fails the host render with the kernel error. */
- (void)testAMissingBuildOutputFailsTheHostRender
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelTestEffect *effect = [self blurEffectWithMetalSource:nil layoutData:nil];
	NSData *state = [self pluginStateOfEffect:effect];
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	NSError *error = nil;

	XCTAssertFalse([effect renderDestinationImage:destination sourceImages:@[] pluginState:state
										   atTime:FxGripParamClassTestTime(0, 1) error:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderCompileFailed);
}

/*! @abstract A kernel whose Metal source fails to compile fails the host render with the pipeline's error. */
- (void)testABrokenKernelFailsTheHostRender
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripKernelTestEffect *effect = [self blurEffectWithMetalSource:@"not metal" layoutData:FxGripKernelTestLayoutData(@"GripBlur")];
	NSData *state = [self pluginStateOfEffect:effect];
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	NSError *error = nil;

	XCTAssertFalse([effect renderDestinationImage:destination sourceImages:@[] pluginState:state
										   atTime:FxGripParamClassTestTime(0, 1) error:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderCompileFailed);
}

@end
