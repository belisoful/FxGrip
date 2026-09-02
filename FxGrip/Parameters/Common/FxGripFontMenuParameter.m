//
//  FxGripFontMenuParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripFontMenuParameter.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripAPINotifications.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"

/*! The declared configuration with a mutable default, run through the host's parameter-policy
	observers. */
static NSMutableDictionary *FxGripPolicyResolvedConfiguration(NSDictionary *parameter,
															  id<FxGripEffectHost> effect)
{
	NSMutableDictionary *config = parameter.mutableCopy;
	NSDictionary *declared = [parameter valueForKey:kFxParameterProperty_Default];
	if ([declared isKindOfClass:NSDictionary.class]) {
		config[kFxParameterProperty_Default] = [declared mutableCopy];
	}
	[effect.notifier postNotificationName:FxGripTileableEffectParameterPolicyName
								   object:effect
								 userInfo:@{FxGripNotifyAPI_ParameterKey: config}];
	return config;
}

@implementation FxGripFontMenuParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_FontMenu;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_FontMenu;
}

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	// The host's policy observers resolve the font (the effect base fills its default font).
	NSMutableDictionary *config = FxGripPolicyResolvedConfiguration(parameter, effect);
	NSString *fontName = config.parameterDefaultValue;
	if (![fontName isKindOfClass:NSString.class] || fontName.length == 0) {
		fontName = kFxParameterType_FontNameDefault;
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
		_error = [NSError errorWithDomain:FxGripPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return fontNameValue;
}

@end
