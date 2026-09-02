//
//  FxGripOOBParameterAccess.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripTileableEffect_ColorGamut_h
#define FxGripTileableEffect_ColorGamut_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import "FxGripTileableEffect.h"

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
