//
//  SCNLight+FxGrip.m
//  FxGrip
//

#import "SCNLight+FxGrip.h"
#import <simd/simd.h>

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

// A rotation carrying `from` onto `to`. Both are normalized; antiparallel inputs pick an arbitrary
// perpendicular axis, and (near-)parallel inputs return the identity.
static simd_quatf FxGripRotationFromTo(simd_float3 from, simd_float3 to)
{
	simd_quatf identity = simd_quaternion(0.0f, simd_make_float3(0.0f, 1.0f, 0.0f));

	if (simd_length(from) < 1e-6f || simd_length(to) < 1e-6f) {
		return identity;
	}

	simd_float3 f = simd_normalize(from);
	simd_float3 t = simd_normalize(to);
	float d = simd_dot(f, t);

	if (d >= 1.0f - 1e-6f) {
		return identity;
	}
	if (d <= -1.0f + 1e-6f) {
		simd_float3 axis = simd_cross(simd_make_float3(1.0f, 0.0f, 0.0f), f);
		if (simd_length(axis) < 1e-6f) {
			axis = simd_cross(simd_make_float3(0.0f, 1.0f, 0.0f), f);
		}
		return simd_quaternion((float)M_PI, simd_normalize(axis));
	}

	return simd_quaternion(acosf(d), simd_normalize(simd_cross(f, t)));
}

@implementation SCNLight (FxGrip)

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
