

#if kFxGripLibraryActivator

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect
{
	id string = parameter.parameterDefaultValue;
	NSString *value = @"";
	if (string && [string isKindOfClass:NSNumber.class]) {
		value = [string stringValue];
	}
	value = NSLocalizedString(value, value);
	return [effect.apiManager.paramCreateAPIv5 addStringParameterWithName: parameter.parameterName
																   parameterID: parameter.parameterID
																  defaultValue: value
																parameterFlags: parameter.parameterFlags];
}


#endif
