/*!
	@file       FxGripTileableEffect+ColorGamut.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+ColorGamut
	@abstract   The category that reports the effect's working color gamut and gamut math.
	@discussion Introduced in FxGrip 0.1.0. The category reads the host color-gamut API to report
	            the working primaries, and derives the luminance weights, RGB-to-XYZ and
	            XYZ-to-RGB matrices, and gamut-conversion matrices for that gamut. It also reports
	            whether the effect's color parameters are on the gamma or linear curve, from the
	            effect's desired processing color info.
*/

#ifndef FxGripTileableEffect_ColorGamut_h
#define FxGripTileableEffect_ColorGamut_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import "FxGripTileableEffect.h"

/*!
	@abstract	The category exposing the effect's working gamut and color-space conversions.
	@discussion	Introduced in FxGrip 0.1.0. The working primaries come from the host color-gamut
				API and default to Rec. 709 when the API is unavailable.
*/
@interface FxGripTileableEffect (ColorGamut)

/*!
 * @property		colorPrimaries
 * @abstract		gets the colorGamutAPIv2 colorPrimaries.
 * @discussion		If the property cannot get the api, returns `kFxColorPrimaries_Rec709`
 */
@property (readonly, assign) FxColorPrimaries colorPrimaries;

/*!
 * @property		isRec2020Gamut
 * @abstract		returns YES if the gamut is wide rec2020.
 */
@property (readonly, assign) BOOL isRec2020Gamut;

/*!
 * @property		isRec709Gamut
 * @abstract		returns YES if the gamut is narrow rec709.
 */
@property (readonly, assign) BOOL isRec709Gamut;

/*!
 * @property		isGammaColorParameters
 * @abstract		returns YES if the parameters are on the gamma curve.
 */
@property (readonly, assign) BOOL isGammaColorParameters;

/*!
 * @property		isLinearColorParameters
 * @abstract		returns YES if the parameters are on a linear curve.
 */
@property (readonly, assign) BOOL isLinearColorParameters;

/*! The luminance weights for the working gamut (colorPrimaries). */
@property (readonly, assign) simd_float3 colorLuminanceWeights;

/*! The RGB-to-CIE-XYZ matrix for the working gamut. */
@property (readonly, assign) simd_float3x3 rgbToXYZMatrix;

/*! The CIE-XYZ-to-RGB matrix for the working gamut. */
@property (readonly, assign) simd_float3x3 xyzToRGBMatrix;

/*! The matrix converting linear RGB in the working gamut to the target gamut. */
- (simd_float3x3)gamutMatrixToPrimaries:(FxColorPrimaries)target;

/*! The matrix converting linear RGB in the source gamut to the working gamut. */
- (simd_float3x3)gamutMatrixFromPrimaries:(FxColorPrimaries)source;

@end

#endif /* ProjectProperties */
