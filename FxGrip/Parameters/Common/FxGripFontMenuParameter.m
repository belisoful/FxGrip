/*!
	@file       FxGripFontMenuParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripFontMenuParameter
	@abstract   Implements the parameter model for a host font menu.
	@discussion Introduced in FxGrip 0.1.0. The class registers a font menu through the parameter-creation API and reads the selected font name at a render time. The host's parameter-policy observers resolve the declared font before registration.
*/

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

/*!
	@abstract	The parameter model for a host font menu.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a font menu and reads the selected font name at a render time.
*/
@implementation FxGripFontMenuParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_FontMenu;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_FontMenu;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Registers the font menu with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default font name falls back to kFxParameterType_FontNameDefault when the declaration sets none. */
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

/*!
	@method		valueAtTime:
	@abstract	Reads the selected font name at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The font name, or nil when FxParameterRetrievalAPI_v6 is unavailable.
	@discussion	Introduced in FxGrip 0.1.0. A retrieval failure sets the parameter's error. */
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
