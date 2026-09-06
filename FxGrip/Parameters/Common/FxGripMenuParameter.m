/*!
	@file       FxGripMenuParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMenuParameter
	@abstract   Implements the parameter model for a host popup menu.
	@discussion Introduced in FxGrip 0.1.0. The class registers a popup menu through the parameter-creation API. The selected index is an integer, and value access comes from FxGripIntParameter. The declared menu entries are parsed once into parameterMenuItems.
*/

#import "FxGripMenuParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"

/*!
	@abstract	The parameter model for a host popup menu.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a popup menu and inherits integer value access from FxGripIntParameter.
*/
@implementation FxGripMenuParameter

/*! @abstract Parses the menu entry titles from the declaration and stores them in parameterMenuItems. */
-(instancetype _Nullable) initWithDictionary:(NSDictionary*)dictionary effect:(nonnull id<FxGripEffectHost>)effect
{
	self = [super initWithDictionary:dictionary effect:effect];
	if(self) {
		_parameterMenuItems = dictionary.parameterMenuItems;
	}
	return self;
}


+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Menu;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Menu;
}


/*!
	@method		addParameter:toEffect:
	@abstract	Registers the popup menu with the effect's host.
	@param		parameter	The parameter configuration dictionary, including the menu entries.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default selected index is 0. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	NSArray<NSString*> *items = parameter.parameterMenuItems;
	
	int defaultValue = 0;
	NSNumber *defaultValueNumber = [parameter valueForKey:kFxParameterProperty_Default];
	if (defaultValueNumber != nil) {
		defaultValue = [defaultValueNumber intValue];
	}
	return [effect.apiManager.paramCreateAPIv5 addPopupMenuWithName: parameter.parameterName
														parameterID: parameter.parameterID
													   defaultValue: defaultValue
														menuEntries: items
													 parameterFlags: parameter.parameterFlags];
}

@end
