/*!
	@file       FxGripShaderEffectTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-29
	@header     FxGripShaderEffectTests
	@abstract   Verifies the bridge from shader metadata to the effect's parameters and color space.
	@discussion Introduced in FxGrip 0.1.0. A test effect stages its shader source and registration
	            record. The tests confirm the lazy single scan, the appended parameter
	            configuration, the processing color info written to the properties, the refusals
	            for a failed scan, an ID collision, and an unregistered type, and the lookup of a
	            created parameter by its shader key.
*/

#import <XCTest/XCTest.h>
#import "FxPlugStub.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripShaderEffect.h>
#import <FxGrip/FxGripTileableEffect+Parameters.h>
#import <FxGrip/FxGripAPINotifications.h>
#import "FxGripParameterClassTestSupport.h"

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

@end
