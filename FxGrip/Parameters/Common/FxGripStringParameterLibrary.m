/*!
	@file       FxGripStringParameterLibrary.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripStringParameterLibrary
	@abstract   The shared host registration body for the string field parameter class.
	@discussion Introduced in FxGrip 0.1.0. The fragment is textually included inside a string parameter's @implementation when kFxGripLibraryActivator is set. It registers a plain string field with the host.
*/

#if kFxGripLibraryActivator

/*!
	@method		addParameter:toEffect:
	@abstract	Registers the string field with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. A number default is converted to a string. The default value is localized before registration. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	id string = parameter.parameterDefaultValue;
	NSString *value = @"";
	if ([string isKindOfClass:NSString.class]) {
		value = string;
	} else if ([string isKindOfClass:NSNumber.class]) {
		value = [string stringValue];
	}
	value = NSLocalizedString(value, value);
	return [effect.apiManager.paramCreateAPIv5 addStringParameterWithName: parameter.parameterName
																   parameterID: parameter.parameterID
																  defaultValue: value
																parameterFlags: parameter.parameterFlags];
}


#endif
