//
//  FxGripOOBParameterAccess.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxTileableEffectBase+OOBParameterAccess.h"
#import "FxGripOOBParameterAccess.h"
#import "FxGripColorGamut.h"


@implementation FxTileableEffectBase (ColorGamut)

- (FxColorPrimaries)colorPrimaries
{
	id<FxColorGamutAPI_v2> colorGamut = [self.apiManager colorGamutAPIv2];
	
	if (!colorGamut)
		return kFxColorPrimaries_Rec709;
	
	return [colorGamut colorPrimaries];
}

- (BOOL)isRec2020Gamut
{
	return self.colorPrimaries == kFxColorPrimaries_Rec2020;
}

- (BOOL)isRec709Gamut
{
	return self.colorPrimaries == kFxColorPrimaries_Rec709;
}

- (BOOL)isGammaColorParameters
{
	//	 desiredProcessingColorInfo is set in method `properties:error`
	return self.desiredProcessingColorInfo == kFxImageColorInfo_RGB_GAMMA_VIDEO;
}

- (BOOL)isLinearColorParameters
{
	//	 desiredProcessingColorInfo is set in method `properties:error`
	return self.desiredProcessingColorInfo == kFxImageColorInfo_RGB_LINEAR;
}

- (simd_float3)colorLuminanceWeights
{
	return FxGripLuminanceWeights(self.colorPrimaries);
}

- (simd_float3x3)rgbToXYZMatrix
{
	return FxGripRGBToXYZMatrix(self.colorPrimaries);
}

- (simd_float3x3)xyzToRGBMatrix
{
	return FxGripXYZToRGBMatrix(self.colorPrimaries);
}

- (simd_float3x3)gamutMatrixToPrimaries:(FxColorPrimaries)target
{
	return FxGripGamutConversionMatrix(self.colorPrimaries, target);
}

- (simd_float3x3)gamutMatrixFromPrimaries:(FxColorPrimaries)source
{
	return FxGripGamutConversionMatrix(source, self.colorPrimaries);
}

@end
