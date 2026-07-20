//
//  FxGripOOBParameterAccess.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxTileableEffectBase+OOBParameterAccess.h"
#import "FxGripOOBParameterAccess.h"


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

@end
