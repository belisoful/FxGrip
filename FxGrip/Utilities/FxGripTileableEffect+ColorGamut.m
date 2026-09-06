/*!
	@file       FxGripTileableEffect+ColorGamut.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+ColorGamut
	@abstract   Implements the working-gamut queries and gamut conversion matrices.
	@discussion Introduced in FxGrip 0.1.0. The working primaries come from the host color-gamut
	            API. The luminance weights and conversion matrices are computed from the primaries
	            through the FxGripColorGamut functions.
*/

#import "FxGripTileableEffect+OOBParameterAccess.h"
#import "FxGripOOBParameterAccess.h"
#import "FxGripColorGamut.h"


/*!
	@abstract	The category exposing the effect's working gamut and color-space conversions.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@implementation FxGripTileableEffect (ColorGamut)

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
