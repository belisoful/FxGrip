//
//  FxGripOOBParameterAccess.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxTileableEffectBase_ColorGamut_h
#define FxTileableEffectBase_ColorGamut_h

#import <Foundation/Foundation.h>
#import "FxTileableEffectBase.h"

@interface FxTileableEffectBase (ColorGamut)

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

@end

#endif /* ProjectProperties */
