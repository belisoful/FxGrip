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
#import "FxGripParameterUtility.h"

@implementation FxGripHelpParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Help;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Help;
}


-(void) displayHelp
{
	// Info.plist CFBundleHelpBookName CFAppleHelpAnchor CFBundleHelpBookFolder
	NSString *helpBook = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"Main" inBook:helpBook];
}

- (void)defaultParameterAction
{
	[self displayHelp];
}


+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	// The host registers the synthesized selector encoding the parameter ID; clicks
	// dispatch through -[FxTileableEffectBase parameterClicked:]. Without a
	// configuration-declared "selector" hook the click falls through to
	// defaultParameterAction, which opens the help book.
	NSString *declaredSelector = parameter.parameterSelector;
	if (declaredSelector && ![declaredSelector.lowercaseString hasPrefix:kFxParameterProperty_SelectorPrefix]) {
		return NO;
	}
	SEL selector = NSSelectorFromString([FxGripParameterUtility clickSelectorNameForParameter:parameter.parameterID]);
	return [effect.apiManager.paramCreateAPIv5 addHelpButtonWithName: parameter.parameterName
														 parameterID: parameter.parameterID
															selector: selector
													  parameterFlags: parameter.parameterFlags];
}


@end
