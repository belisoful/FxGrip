/*!
	@file       FxGripShaderEffectTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-29
	@header     FxGripShaderEffectTests
	@abstract   Verifies the bridge from shader metadata to the effect's parameters, color space, and render.
	@discussion Introduced in FxGrip 0.1.0. A test effect stages its shader source, registration
	            record, API manager, and host primaries. The tests confirm the lazy single scan, the
	            appended parameter configuration, the processing color info written to the
	            properties, the refusals for a failed scan, an ID collision, and an unregistered type,
	            the lookup of a created parameter by its shader key, the values read from the bound
	            parameters, the plugin state, and the render through the host entry points.
*/

#import <XCTest/XCTest.h>
#import "FxPlugStub.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripShaderEffect.h>
#import <FxGrip/FxGripTileableEffect+Parameters.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripDictionary.h>
#import "FxGripParameterClassTestSupport.h"
#import "FxGripShaderTestSupport.h"

static NSString *FxGripShaderEffectTestSource(NSString *body)
{
	return [NSString stringWithFormat:@"/* FxGripShader\n%@\n*/\nfragment float4 shade() { return 0; }\n", body];
}

/*! Stages the shader source and the registration record, and counts source reads. */
@interface FxGripShaderTestEffect : FxGripShaderEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, copy, nullable) NSString *stagedSource;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *stubPluginProperties;
@property (nonatomic, assign) BOOL stubEffectPropertiesInInfo;
@property (nonatomic, assign) NSUInteger sourceReads;
@property (nonatomic, strong, nullable) FxGripParamClassTestAPIManager *stubAPIManager;
@property (nonatomic, assign) FxColorPrimaries stubColorPrimaries;
@end

@implementation FxGripShaderTestEffect

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
	if (_stubPluginProperties) {
		return _stubPluginProperties;
	}
	return [super pluginProperties];
}

- (BOOL)isEffectPropertiesInInfo
{
	return _stubEffectPropertiesInInfo;
}

- (NSString *)shaderSource
{
	self.sourceReads += 1;
	return self.stagedSource;
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

@interface FxGripShaderEffectTests : XCTestCase
@end

@implementation FxGripShaderEffectTests

- (FxGripShaderTestEffect *)effectWithSource:(nullable NSString *)source
{
	FxGripShaderTestEffect *effect = [[FxGripShaderTestEffect alloc] initWithAPIManager:(id _Nonnull)nil];
	effect.stagedSource = source;
	return effect;
}

- (NSMutableDictionary *)pluginPropertiesDictionary
{
	return [NSMutableDictionary dictionaryWithDictionary:@{
		kProPlugPlugIn_UuidProperty: @"AAAABBBB-CCCC-DDDD-EEEE-FFFF00004444",
		kProPlugPlugIn_ClassNameProperty: @"FxGripShaderTestEffect",
		kProPlugPlugIn_GroupUUIDProperty: @"44440000-FFFF-EEEE-DDDD-CCCCBBBBAAAA",
	}];
}

/*! Posts the creation notification for every record, as the creation API does once the host has created each parameter. */
- (void)createShaderParametersOfEffect:(FxGripShaderTestEffect *)effect
{
	for (NSDictionary *record in effect.shaderMetadata.allParameters) {
		[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName object:effect userInfo:record];
	}
}

- (FxGripParamClassTestRetrievalAPI *)stageRetrievalOnEffect:(FxGripShaderTestEffect *)effect
{
	FxGripParamClassTestAPIManager *manager = [FxGripParamClassTestAPIManager new];
	manager.paramGetAPIv6 = [FxGripParamClassTestRetrievalAPI new];
	manager.paramGetAPIv6.succeeds = YES;
	effect.stubAPIManager = manager;
	return manager.paramGetAPIv6;
}

- (NSString *)gainSource
{
	return FxGripShaderTestSource(
		@"{ parameters: [ { id: 1, type: \"float\", name: \"Gain\", key: \"gain\" } ] }",
		@"struct Uniforms { float gain; };\n"
		@"fragment float4 fxGripShaderFragment(FxGripShaderVertexOut in [[stage_in]],\n"
		@"                                     texture2d<float> source [[texture(0)]],\n"
		@"                                     constant Uniforms &uniforms [[buffer(0)]])\n"
		@"{\n"
		@"    constexpr sampler nearest(filter::nearest);\n"
		@"    float4 color = source.sample(nearest, in.texCoord);\n"
		@"    return float4(color.rgb * uniforms.gain, color.a);\n"
		@"}\n");
}

- (nullable NSData *)pluginStateOfEffect:(FxGripShaderTestEffect *)effect
{
	NSData *state = nil;
	NSError *error = nil;
	XCTAssertTrue([effect pluginState:&state atTime:FxGripParamClassTestTime(0, 1) quality:kFxQuality_HIGH error:&error], @"%@", error);
	return state;
}

- (NSString *)radiusSource
{
	return FxGripShaderEffectTestSource(
		@"{ \"colorSpace\": { \"transfer\": \"gamma\" },"
		@"  \"parameters\": [ { \"id\": 20, \"type\": \"float\", \"name\": \"Radius\", \"key\": \"radius\", \"default\": 4 } ] }");
}

#pragma mark Metadata

/*! @abstract A nil source gives no metadata, no error, and no shader parameters. */
- (void)testANilSourceGivesNoShaderParameters
{
	FxGripShaderTestEffect *effect = [self effectWithSource:nil];

	XCTAssertNil(effect.shaderMetadata);
	XCTAssertNil(effect.shaderMetadataError);
	XCTAssertEqual([effect parametersConfiguration].count, (NSUInteger)0);
	XCTAssertNil([effect shaderParameterForKey:@"radius"]);
}

/*! @abstract The base class supplies no shader source. */
- (void)testTheBaseClassSuppliesNoSource
{
	FxGripShaderEffect *effect = [[FxGripShaderEffect alloc] initWithAPIManager:(id _Nonnull)nil];

	XCTAssertNil([effect shaderSource]);
	XCTAssertNil(effect.shaderMetadata);
}

/*! @abstract The source is scanned once and the metadata is reused. */
- (void)testTheSourceIsScannedOnce
{
	FxGripShaderTestEffect *effect = [self effectWithSource:[self radiusSource]];

	FxGripShaderMetadata *first = effect.shaderMetadata;
	FxGripShaderMetadata *second = effect.shaderMetadata;
	[effect parametersConfiguration];

	XCTAssertNotNil(first);
	XCTAssertEqual(first, second);
	XCTAssertEqual(effect.sourceReads, (NSUInteger)1);
}

/*! @abstract A source that fails to scan keeps the error and gives no metadata. */
- (void)testAFailedScanKeepsItsError
{
	FxGripShaderTestEffect *effect = [self effectWithSource:FxGripShaderEffectTestSource(@"{ \"parameters\": [ { \"id\": 0 } ] }")];

	XCTAssertNil(effect.shaderMetadata);
	XCTAssertEqual(effect.shaderMetadataError.code, (NSInteger)kFxGripError_ShaderMetadataInvalid);
	XCTAssertEqual([effect parametersConfiguration].count, (NSUInteger)0);
}

#pragma mark Configuration

/*! @abstract The shader parameters follow the parameters the registration record declares. */
- (void)testShaderParametersFollowTheDeclaredParameters
{
	FxGripShaderTestEffect *effect = [self effectWithSource:[self radiusSource]];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_ParametersProperty] = @[@{
		kFxParameterProperty_Id: @1,
		kFxParameterProperty_Type: kFxParameterType_Toggle,
		kFxParameterProperty_Name: @"Enabled",
	}];
	effect.stubPluginProperties = properties;

	NSArray<NSDictionary *> *configuration = [effect parametersConfiguration];

	XCTAssertEqualObjects([configuration valueForKey:kFxParameterProperty_Id], (@[@1, @20]));
}

/*! @abstract A clean configuration creates the shader parameters. */
- (void)testACleanConfigurationCreatesTheShaderParameters
{
	FxGripShaderTestEffect *effect = [self effectWithSource:[self radiusSource]];
	NSError *error = nil;

	[effect addParametersWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqualObjects([effect configurationForParameter:20][kFxGripShaderProperty_Key], @"radius");
}

/*! @abstract A failed scan refuses parameter creation with the scan error. */
- (void)testAFailedScanRefusesParameterCreation
{
	FxGripShaderTestEffect *effect = [self effectWithSource:FxGripShaderEffectTestSource(@"{ \"parameters\": [ }")];
	NSError *error = nil;

	XCTAssertFalse([effect addParametersWithError:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderMetadataMalformed);
	XCTAssertEqualObjects(error, effect.shaderMetadataError);
}

/*! @abstract A shader ID that repeats a declared plugin parameter refuses creation. */
- (void)testAnIDCollisionRefusesParameterCreation
{
	FxGripShaderTestEffect *effect = [self effectWithSource:[self radiusSource]];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_ParametersProperty] = @[@{
		kFxParameterProperty_Id: @2,
		kFxParameterProperty_Type: kFxParameterType_Group,
		kFxParameterProperty_Name: @"Group",
		kFxParameterProperty_GroupParameters: @[@{
			kFxParameterProperty_Id: @20,
			kFxParameterProperty_Type: kFxParameterType_Float,
			kFxParameterProperty_Name: @"Nested",
		}],
	}];
	effect.stubPluginProperties = properties;
	NSError *error = nil;

	XCTAssertFalse([effect addParametersWithError:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderMetadataInvalid);
	XCTAssertTrue([error.localizedDescription containsString:@"20"]);
}

/*! @abstract A shader type with no registered parameter class refuses creation. */
- (void)testAnUnregisteredTypeRefusesParameterCreation
{
	FxGripShaderTestEffect *effect = [self effectWithSource:FxGripShaderEffectTestSource(
		@"{ \"parameters\": [ { \"id\": 30, \"type\": \"zzzz\", \"name\": \"Unknown\" } ] }")];
	NSError *error = nil;

	XCTAssertNotNil(effect.shaderMetadata, @"a four-character type passes the hostless scan");
	XCTAssertFalse([effect addParametersWithError:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderMetadataInvalid);
}

#pragma mark Color space

/*! @abstract The declared transfer becomes the processing color info in the properties. */
- (void)testTheDeclaredTransferBecomesTheProcessingColorInfo
{
	FxGripShaderTestEffect *effect = [self effectWithSource:[self radiusSource]];
	NSDictionary *properties = nil;
	NSError *error = nil;

	XCTAssertTrue([effect properties:&properties error:&error]);

	XCTAssertEqual(effect.desiredProcessingColorInfo, (FxImageColorInfo)kFxImageColorInfo_RGB_GAMMA_VIDEO);
	XCTAssertEqualObjects(properties[kFxPropertyKey_DesiredProcessingColorInfo], @(kFxImageColorInfo_RGB_GAMMA_VIDEO));
}

/*! @abstract An effect property in the registration record takes precedence over the shader. */
- (void)testTheRegistrationRecordTakesPrecedenceOverTheShader
{
	FxGripShaderTestEffect *effect = [self effectWithSource:[self radiusSource]];
	NSMutableDictionary *pluginProperties = [self pluginPropertiesDictionary];
	pluginProperties[kProPlugPlugInX_EffectPropertiesProperty] = @{
		kFxPropertyKey_DesiredProcessingColorInfo: @(kFxImageColorInfo_RGB_LINEAR),
	};
	effect.stubPluginProperties = pluginProperties;
	effect.stubEffectPropertiesInInfo = YES;
	NSDictionary *properties = nil;
	NSError *error = nil;

	XCTAssertTrue([effect properties:&properties error:&error]);

	XCTAssertEqual(effect.desiredProcessingColorInfo, (FxImageColorInfo)kFxImageColorInfo_RGB_LINEAR);
}

#pragma mark Parameter lookup

/*! @abstract A created parameter is found by its shader key. */
- (void)testACreatedParameterIsFoundByItsShaderKey
{
	FxGripShaderTestEffect *effect = [self effectWithSource:[self radiusSource]];
	XCTAssertNil([effect shaderParameterForKey:@"radius"], @"no parameter exists before the host creates it");
	// The creation API posts this notification once the host has created the parameter.
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:[effect.shaderMetadata parameterForKey:@"radius"]];

	id<FxGripParameter> parameter = [effect shaderParameterForKey:@"radius"];

	XCTAssertNotNil(parameter);
	XCTAssertEqual(parameter.parameterID, (FxParameterId)20);
	XCTAssertNil([effect shaderParameterForKey:@"missing"]);
}

#pragma mark Pipeline

/*! @abstract The effect adopts the coder-state render path. */
- (void)testTheEffectAdoptsTheCoderStateRenderPath
{
	FxGripShaderTestEffect *effect = [self effectWithSource:nil];

	XCTAssertTrue([effect conformsToProtocol:@protocol(FxGripTileableEffectCoderState)]);
	XCTAssertEqualObjects([effect shaderFragmentFunctionName], kFxGripShaderFragmentFunctionName);
}

/*! @abstract Instances with the same source share one pipeline, and no metadata gives no pipeline. */
- (void)testInstancesShareOnePipelinePerSource
{
	FxGripShaderTestEffect *first = [self effectWithSource:[self gainSource]];
	FxGripShaderTestEffect *second = [self effectWithSource:[self gainSource]];

	XCTAssertNotNil(first.shaderPipeline);
	XCTAssertEqual(first.shaderPipeline, second.shaderPipeline);
	XCTAssertEqualObjects(first.shaderPipeline.fragmentFunctionName, kFxGripShaderFragmentFunctionName);
	XCTAssertNil([self effectWithSource:nil].shaderPipeline);
	XCTAssertNil([self effectWithSource:FxGripShaderEffectTestSource(@"{ \"parameters\": [ }")].shaderPipeline);
}

#pragma mark Values

/*! @abstract Each created keyed parameter contributes its value, and a type with no scalar value contributes none. */
- (void)testEachCreatedParameterContributesItsValue
{
	FxGripShaderTestEffect *effect = [self effectWithSource:FxGripShaderEffectTestSource(
		@"{ parameters: ["
		@"  { id: 1, type: \"float\", name: \"Gain\", key: \"gain\" },"
		@"  { id: 2, type: \"integer\", name: \"Mode\", key: \"MODE\", constant: true },"
		@"  { id: 3, type: \"toggle\", name: \"Invert\", key: \"invert\" },"
		@"  { id: 4, type: \"point\", name: \"Center\", key: \"center\" },"
		@"  { id: 5, type: \"rgb\", name: \"Tint\", key: \"tint\" },"
		@"  { id: 6, type: \"rgba\", name: \"Fill\", key: \"fill\" },"
		@"  { id: 7, type: \"switch\", name: \"Enabled\", key: \"enabled\" },"
		@"  { id: 8, type: \"string\", name: \"Label\", key: \"label\" },"
		@"  { id: 9, type: \"float\", name: \"Unbound\" },"
		@"] }")];
	[self createShaderParametersOfEffect:effect];
	// A custom parameter answers its value only once the host has reported its creation.
	[[effect shaderParameterForKey:@"enabled"] createdWithFlags:0 parentID:0];
	FxGripParamClassTestRetrievalAPI *retrieval = [self stageRetrievalOnEffect:effect];
	retrieval.floatValue = 2.5;
	retrieval.intValue = 7;
	retrieval.boolValue = YES;
	retrieval.x = 5;
	retrieval.y = 6;
	retrieval.red = 0.25;
	retrieval.green = 0.5;
	retrieval.blue = 0.75;
	retrieval.alpha = 1;
	retrieval.customValue = [FxGripDictionary dictionaryWithDictionary:@{ kCustomAPI_BoolKey: @YES }];

	FxGripShaderValues *values = [effect shaderValuesAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(values.keys, (@[@"MODE", @"center", @"enabled", @"fill", @"gain", @"invert", @"tint"]));
	XCTAssertEqualObjects([values componentsForKey:@"gain"], (@[@2.5]));
	XCTAssertEqualObjects([values componentsForKey:@"MODE"], (@[@7]));
	XCTAssertEqualObjects([values componentsForKey:@"invert"], (@[@1]));
	XCTAssertEqualObjects([values componentsForKey:@"center"], (@[@5, @6]));
	XCTAssertEqualObjects([values componentsForKey:@"tint"], (@[@0.25, @0.5, @0.75]));
	XCTAssertEqualObjects([values componentsForKey:@"fill"], (@[@0.25, @0.5, @0.75, @1]));
	XCTAssertEqualObjects([values componentsForKey:@"enabled"], (@[@1]));
}

/*! @abstract A parameter the host has not created contributes no value. */
- (void)testAnUncreatedParameterContributesNoValue
{
	FxGripShaderTestEffect *effect = [self effectWithSource:[self gainSource]];

	XCTAssertEqualObjects([effect shaderValuesAtTime:FxGripParamClassTestTime(0, 1)].keys, @[]);
}

/*! @abstract The plugin state carries the values, the host primaries, and the processing color info. */
- (void)testThePluginStateCarriesTheValuesAndColorSpace
{
	FxGripShaderTestEffect *effect = [self effectWithSource:[self gainSource]];
	[self createShaderParametersOfEffect:effect];
	[self stageRetrievalOnEffect:effect].floatValue = 3;
	effect.stubColorPrimaries = kFxColorPrimaries_Rec2020;
	effect.desiredProcessingColorInfo = kFxImageColorInfo_RGB_GAMMA_VIDEO;

	NSData *state = [self pluginStateOfEffect:effect];
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:state error:NULL];
	FxGripShaderValues *values = [unarchiver decodeObjectOfClass:FxGripShaderValues.class forKey:kFxGripShaderValuesCoderKey];

	XCTAssertEqualObjects([values componentsForKey:@"gain"], (@[@3]));
	XCTAssertEqual([unarchiver decodeIntegerForKey:kFxGripShaderHostPrimariesCoderKey], (NSInteger)kFxColorPrimaries_Rec2020);
	XCTAssertEqual([unarchiver decodeIntegerForKey:kFxGripShaderColorInfoCoderKey], (NSInteger)kFxImageColorInfo_RGB_GAMMA_VIDEO);
}

#pragma mark Render

/*! @abstract The host render entry point draws through the shader with the encoded values. */
- (void)testTheHostRenderDrawsThroughTheShader
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderTestEffect *effect = [self effectWithSource:[self gainSource]];
	[self createShaderParametersOfEffect:effect];
	[self stageRetrievalOnEffect:effect].floatValue = 2;
	NSData *state = [self pluginStateOfEffect:effect];
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.25f, 0.125f, 0.5f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	NSError *error = nil;

	XCTAssertTrue([effect renderDestinationImage:destination sourceImages:@[source] pluginState:state
										  atTime:FxGripParamClassTestTime(0, 1) error:&error], @"%@", error);

	simd_float4 pixel = FxGripShaderTestPixel(destination, 1, 1);
	XCTAssertEqualWithAccuracy(pixel.x, 0.5f, 1e-6f);
	XCTAssertEqualWithAccuracy(pixel.y, 0.25f, 1e-6f);
	XCTAssertEqualWithAccuracy(pixel.z, 1.0f, 1e-6f);
	XCTAssertEqualWithAccuracy(pixel.w, 1.0f, 1e-6f);
}

/*! @abstract An effect with no shader source passes its first source image through. */
- (void)testAnEffectWithoutASourcePassesItsInputThrough
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderTestEffect *effect = [self effectWithSource:nil];
	NSData *state = [self pluginStateOfEffect:effect];
	FxRect bounds = { 0, 0, 2, 2 };
	FxImageTile *source = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.25f, 0.125f, 0.5f, 1.0f));
	FxImageTile *destination = FxGripShaderTestFloatTile(bounds, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	NSError *error = nil;

	XCTAssertTrue([effect renderDestinationImage:destination sourceImages:@[source] pluginState:state
										  atTime:FxGripParamClassTestTime(0, 1) error:&error], @"%@", error);

	XCTAssertEqualWithAccuracy(FxGripShaderTestPixel(destination, 0, 0).z, 0.5f, 1e-6f);
}

/*! @abstract A shader that fails to build fails the host render with the pipeline's error. */
- (void)testAShaderThatFailsToBuildFailsTheHostRender
{
	XCTSkipIf(FxGripShaderTestDevice() == nil, @"No Metal device.");
	FxGripShaderTestEffect *effect = [self effectWithSource:FxGripShaderEffectTestSource(@"{}")];
	NSData *state = [self pluginStateOfEffect:effect];
	FxImageTile *destination = FxGripShaderTestFloatTile((FxRect){ 0, 0, 2, 2 }, simd_make_float4(0.0f, 0.0f, 0.0f, 0.0f));
	NSError *error = nil;

	XCTAssertFalse([effect renderDestinationImage:destination sourceImages:@[] pluginState:state
										   atTime:FxGripParamClassTestTime(0, 1) error:&error]);

	XCTAssertEqual(error.code, (NSInteger)kFxGripError_ShaderCompileFailed);
}

@end
