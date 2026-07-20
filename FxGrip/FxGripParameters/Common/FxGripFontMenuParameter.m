//
//  FxGripFontMenuParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripFontMenuParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"

@implementation FxGripFontMenuParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_FontMenu;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_FontMenu;
}

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect
{
	NSString *fontName = parameter.parameterDefaultValue;
	if (fontName == nil) {
		fontName = effect.defaultFontName;
	}
	return [effect.apiManager.paramCreateAPIv5 addFontMenuWithName: parameter.parameterName
													   parameterID: parameter.parameterID
														  fontName: fontName
													parameterFlags: parameter.parameterFlags];
}

-(NSString*_Nullable) valueAtTime:(CMTime)renderTime
{
	NSString* fontNameValue = nil;
	if(![self.effect.apiManager.paramGetAPIv6 getFontName:&fontNameValue fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return fontNameValue;
}

@end
