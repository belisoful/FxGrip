/*!
	@file       FxGripToggleParameterLibrary.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripToggleParameterLibrary
	@abstract   The shared method bodies for the toggle parameter class.
	@discussion Introduced in FxGrip 0.1.0. The fragment is textually included inside FxGripToggleParameter's @implementation. It supplies the type identifiers, host registration, boolean value access, and state encoding for the toggle button.
*/

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Toggle;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Toggle;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Registers the toggle button with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default value is NO. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	BOOL value = NO;
	NSNumber *number = parameter.parameterDefaultValue;
	if (number != nil) {
		value = [number boolValue];
	}
	return [effect.apiManager.paramCreateAPIv5 addToggleButtonWithName: parameter.parameterName
																parameterID: parameter.parameterID
															   defaultValue: value
															 parameterFlags: parameter.parameterFlags];
}


/*!
	@method		valueAtTime:
	@abstract	Reads the boolean value at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The boolean value, or NO when FxParameterRetrievalAPI_v6 is unavailable.
	@discussion	Introduced in FxGrip 0.1.0. A retrieval failure sets the parameter's error. */
- (BOOL)valueAtTime:(CMTime)renderTime
{
	BOOL boolValue = NO;
	if(![self.effect.apiManager.paramGetAPIv6 getBoolValue:&boolValue fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxGripPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return boolValue;
}


/*! @abstract Writes the boolean value at a time through FxParameterSettingAPI_v5. */
- (void)setValue:(BOOL)value atTime:(CMTime)time
{
	[self.effect.apiManager.paramSetAPIv5 setBoolValue:value toParameter:self.parameterID atTime:time];
}



- (BOOL)boolValue
{
	return [self valueAtTime:kCMTimeZero];
}


- (void)setBoolValue:(BOOL)value
{
	[self setValue:value atTime:kCMTimeZero];
}


/*!
	@method		encodeWithCoder:
	@abstract	Encodes the boolean value at the coder's render time into the plugin-state coder.
	@param		coder	The coder that receives the value.
	@discussion	Introduced in FxGrip 0.1.0. The value encodes only when the coder is an FxPlug plugin-state encoder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];

	if (coder.isFxPluginStateEncoder) {
		[coder encodeBool:[self valueAtTime:coder.renderTime] atIndex:self.parameterID];
	} else {
		// encode meta
	}
}

