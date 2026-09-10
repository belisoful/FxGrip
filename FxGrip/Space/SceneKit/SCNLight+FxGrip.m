/*!
	@file       SCNLight+FxGrip.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     SCNLight+FxGrip
	@abstract   Implements the SceneKit light construction from an FxPlug FxLight.
	@discussion Introduced in FxGrip 0.1.0. The type map converts an FxLightType to an SCNLightType, and a
	            rotation helper orients directional and spot lights so the node's local -Z axis points
	            along the light's direction. Intensity is scaled to SceneKit's lumen default.
*/

#import "SCNLight+FxGrip.h"
#import <FxGrip/FxGripSpaceMotion.h>
#import <simd/simd.h>

/*! Maps an FxLightType to the matching SCNLightType, defaulting to omni. */
static SCNLightType FxGripSCNLightType(FxLightType type)
{
	switch (type) {
		case kFxLightType_Ambient:     return SCNLightTypeAmbient;
		case kFxLightType_Directional: return SCNLightTypeDirectional;
		case kFxLightType_Point:       return SCNLightTypeOmni;
		case kFxLightType_Spot:        return SCNLightTypeSpot;
		default:                       return SCNLightTypeOmni;
	}
}

/*!
	@abstract	Builds a SceneKit light from an FxPlug FxLight.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@implementation SCNLight (FxGrip)

/*!
	@method		fxg_lightFromFxLight:
	@abstract	An SCNLight configured from an FxLight.
	@discussion	Introduced in FxGrip 0.1.0. Type, color, and cast-shadows map directly; intensity is scaled
				by 1000 to SceneKit's lumen default; spot cone angles convert from radians to degrees. */
+ (instancetype)fxg_lightFromFxLight:(FxLight)light
{
	SCNLight *scnLight = [SCNLight light];
	scnLight.type = FxGripSCNLightType(light.lightType);
	scnLight.color = light.color ?: NSColor.whiteColor;
	scnLight.intensity = light.intensity * 1000.0;
	scnLight.castsShadow = light.castsShadows;

	if (light.lightType == kFxLightType_Spot) {
		scnLight.spotInnerAngle = light.spotPenumbraCutoff * 180.0 / M_PI;
		scnLight.spotOuterAngle = light.spotCutoff * 180.0 / M_PI;
	}

	return scnLight;
}

/*!
	@method		fxg_lightNodeFromFxLight:
	@abstract	An SCNNode carrying the light at the reported world position.
	@discussion	Introduced in FxGrip 0.1.0. Directional and spot lights are oriented so the node's local
				-Z axis points along the light's direction. */
+ (SCNNode *)fxg_lightNodeFromFxLight:(FxLight)light
{
	SCNNode *node = [SCNNode node];
	node.light = [self fxg_lightFromFxLight:light];
	node.simdPosition = simd_make_float3((float)light.position.x, (float)light.position.y, (float)light.position.z);

	if (light.lightType == kFxLightType_Directional || light.lightType == kFxLightType_Spot) {
		simd_float3 direction = simd_make_float3((float)light.direction.x, (float)light.direction.y, (float)light.direction.z);
		node.simdOrientation = FxGripRotationFromTo(simd_make_float3(0.0f, 0.0f, -1.0f), direction);
	}

	return node;
}

@end
