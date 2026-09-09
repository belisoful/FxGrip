/*!
	@file       SCNLight+FxGripTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     SCNLight+FxGripTests
	@abstract   Tests for the SCNLight+FxGrip category that maps an FxLight to an SCNLight and node.
	@discussion Introduced in FxGrip 0.1.0. The tests cover light-type mapping, intensity scaling to lumens, color and shadow passthrough, spot cone-angle conversion to degrees, node positioning, and directional aiming of local -z along the light direction.
*/

#import <XCTest/XCTest.h>
#import <SceneKit/SceneKit.h>
#import <simd/simd.h>
#import <FxPlug/FxLightingAPI.h>
#import <FxGrip/SCNLight+FxGrip.h>

@interface SCNLight_FxGripTests : XCTestCase
@end

@implementation SCNLight_FxGripTests

static FxLight MakeLight(FxLightType type)
{
	FxLight light = {0};
	light.version = kFxLight_V3;
	light.lightType = type;
	light.intensity = 1.0f;
	light.color = NSColor.whiteColor;
	return light;
}

/*! @abstract Each FxLightType maps to its corresponding SCNLight type. */
- (void)testTypeMapping
{
	XCTAssertEqualObjects([SCNLight fxg_lightFromFxLight:MakeLight(kFxLightType_Ambient)].type, SCNLightTypeAmbient);
	XCTAssertEqualObjects([SCNLight fxg_lightFromFxLight:MakeLight(kFxLightType_Directional)].type, SCNLightTypeDirectional);
	XCTAssertEqualObjects([SCNLight fxg_lightFromFxLight:MakeLight(kFxLightType_Point)].type, SCNLightTypeOmni);
	XCTAssertEqualObjects([SCNLight fxg_lightFromFxLight:MakeLight(kFxLightType_Spot)].type, SCNLightTypeSpot);
}

/*! @abstract The FxLight intensity scales to SCNLight lumens, with 0.5 mapping to 500. */
- (void)testIntensityScalesToLumens
{
	FxLight light = MakeLight(kFxLightType_Point);
	light.intensity = 0.5f;
	XCTAssertEqualWithAccuracy([SCNLight fxg_lightFromFxLight:light].intensity, 500.0, 1e-3);
}

/*! @abstract The FxLight color passes through to the SCNLight color. */
- (void)testColorPassesThrough
{
	FxLight light = MakeLight(kFxLightType_Point);
	light.color = NSColor.redColor;
	XCTAssertEqualObjects([SCNLight fxg_lightFromFxLight:light].color, NSColor.redColor);
}

/*! @abstract An FxLight that casts shadows produces an SCNLight that casts a shadow. */
- (void)testCastsShadow
{
	FxLight light = MakeLight(kFxLightType_Spot);
	light.castsShadows = YES;
	XCTAssertTrue([SCNLight fxg_lightFromFxLight:light].castsShadow);
}

/*! @abstract Spot cutoff and penumbra angles in radians convert to the SCNLight outer and inner angles in degrees. */
- (void)testSpotConeAnglesConvertToDegrees
{
	FxLight light = MakeLight(kFxLightType_Spot);
	light.spotCutoff = (float)(M_PI / 4.0);        // 45 degrees
	light.spotPenumbraCutoff = (float)(M_PI / 6.0); // 30 degrees
	SCNLight *scnLight = [SCNLight fxg_lightFromFxLight:light];
	XCTAssertEqualWithAccuracy(scnLight.spotOuterAngle, 45.0, 1e-3);
	XCTAssertEqualWithAccuracy(scnLight.spotInnerAngle, 30.0, 1e-3);
}

/*! @abstract +fxg_lightNodeFromFxLight: returns a node carrying the light at the FxLight position. */
- (void)testNodeCarriesLightAtPosition
{
	FxLight light = MakeLight(kFxLightType_Point);
	light.position = (FxPoint3D){ 2.0, 3.0, 4.0 };
	SCNNode *node = [SCNLight fxg_lightNodeFromFxLight:light];

	XCTAssertNotNil(node.light);
	XCTAssertEqualWithAccuracy(node.simdPosition.x, 2.0f, 1e-5);
	XCTAssertEqualWithAccuracy(node.simdPosition.y, 3.0f, 1e-5);
	XCTAssertEqualWithAccuracy(node.simdPosition.z, 4.0f, 1e-5);
}

/*! @abstract A directional light node orients so that local -z points along the FxLight direction. */
- (void)testDirectionalNodeAimsLocalMinusZAlongDirection
{
	FxLight light = MakeLight(kFxLightType_Directional);
	light.direction = (FxPoint3D){ 1.0, 0.0, 0.0 };
	SCNNode *node = [SCNLight fxg_lightNodeFromFxLight:light];

	simd_float3 aimed = simd_act(node.simdOrientation, simd_make_float3(0.0f, 0.0f, -1.0f));
	XCTAssertEqualWithAccuracy(aimed.x, 1.0f, 1e-4);
	XCTAssertEqualWithAccuracy(aimed.y, 0.0f, 1e-4);
	XCTAssertEqualWithAccuracy(aimed.z, 0.0f, 1e-4);
}

@end
