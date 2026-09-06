/*!
	@file       FxGripHelpParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripHelpParameter
	@abstract   Implements the parameter model for a host help button.
	@discussion Introduced in FxGrip 0.1.0. The class registers a help button through the parameter-creation API. The default click action opens the plugin's help book named by CFBundleHelpBookName.
*/

#import "FxGripHelpParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripParameterUtility.h"

/*!
	@abstract	The parameter model for a host help button.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a help button whose default click action opens the plugin's help book.
*/
@implementation FxGripHelpParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Help;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Help;
}


/*!
	@method		displayHelp
	@abstract	Opens the plugin's help book to the "Main" anchor.
	@discussion	Introduced in FxGrip 0.1.0. The help book name is read from the main bundle's CFBundleHelpBookName. */
-(void) displayHelp
{
	// Info.plist CFBundleHelpBookName CFAppleHelpAnchor CFBundleHelpBookFolder
	NSString *helpBook = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"Main" inBook:helpBook];
}

/*! @abstract Opens the help book when a click falls through to the default parameter action. */
- (void)defaultParameterAction
{
	[self displayHelp];
}


/*!
	@method		addParameter:toEffect:
	@abstract	Registers the help button with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The button registers the synthesized click selector for the parameter ID. A configuration selector that does not use the click prefix fails registration. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	// The host registers the synthesized selector encoding the parameter ID; clicks
	// dispatch through -[FxGripTileableEffect parameterClicked:]. Without a
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
