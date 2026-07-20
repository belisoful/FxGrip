//
//  FxGripHelpParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripHelpParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"

@implementation FxGripHelpParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Help;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Help;
}


// @todo: This is the default "help" button action: open the "HelpBook"
-(void) displayHelp
{
	// Info.plist CFBundleHelpBookName CFAppleHelpAnchor CFBundleHelpBookFolder
	NSString *helpBook = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"Main" inBook:helpBook];
}


+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect
{
	BOOL success = NO;
	NSString *selector = [parameter valueForKey:kFxParameterProperty_Selector];
	if (selector == nil) {
		selector = @"";
	}
	if ([selector.lowercaseString hasPrefix:kFxParameterProperty_SelectorPrefix]) {
		success = [effect.apiManager.paramCreateAPIv5 addHelpButtonWithName: parameter.parameterName
											parameterID: parameter.parameterID
											   selector:NSSelectorFromString(selector) //selector needs to use FxCustomParameterActionAPI_v4 to access parameters
										 parameterFlags:parameter.parameterFlags];
	} else {
		//errorReason = @"Incorrrect selector prefix.  Must start with 'click' for security reasons";
		success = NO;
	}
	return success;
}


@end
