/*!
	@file       SCNLight+FxGrip.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     SCNLight+FxGrip
	@abstract   Builds a SceneKit light from an FxPlug FxLight.
	@discussion Introduced in FxGrip 0.1.0. This file declares the SCNLight category that maps one
	            FxLightingAPI_v3 FxLight to an SCNLight and to a positioned, oriented SCNNode.
*/

#ifndef SCNLight_FxGrip_h
#define SCNLight_FxGrip_h

#import <SceneKit/SceneKit.h>
#import <FxPlug/FxLightingAPI.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@abstract   Builds a SceneKit light from an FxPlug `FxLight`.
	@discussion Introduced in FxGrip 0.1.0. The `FxLightingAPI_v3` host API reports each scene light as
				an `FxLight` struct. These methods map one `FxLight` to an `SCNLight`, and to an
				`SCNNode` that carries the light at the reported world position and, for directional
				and spot lights, pointed along the reported direction (SceneKit lights emit down the
				node's local -Z axis).

				Type, color, cast-shadows, and spot cone angles map directly. `FxLight.intensity` is a
				unitless brightness multiplier; it maps to `SCNLight.intensity` (lumens, default 1000)
				as `intensity * 1000`, so a unit FxPlug light matches a default SceneKit light. The
				`FxLight` constant/linear/quadratic attenuation model has no direct SceneKit equivalent
				(SceneKit attenuates by start and end distance) and is not mapped; callers that need
				distance falloff set `attenuationStartDistance`/`attenuationEndDistance` on the result.
*/
@interface SCNLight (FxGrip)

/*! An `SCNLight` configured from an `FxLight`. */
+ (instancetype)fxg_lightFromFxLight:(FxLight)light;

/*! An `SCNNode` carrying an `fxg_lightFromFxLight:` light, positioned at the light's world position
	and, for directional and spot lights, oriented so its local -Z axis points along the light's
	direction. */
+ (SCNNode *)fxg_lightNodeFromFxLight:(FxLight)light;

@end

NS_ASSUME_NONNULL_END

#endif /* SCNLight_FxGrip_h */
