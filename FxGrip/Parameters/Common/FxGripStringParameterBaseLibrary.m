/*!
	@file       FxGripStringParameterBaseLibrary.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripStringParameterBaseLibrary
	@abstract   The shared method bodies for the base string parameter class.
	@discussion Introduced in FxGrip 0.1.0. The fragment is textually included inside FxGripStringParameterBase's @implementation. It supplies the type identifiers, string value access, and state encoding common to the string parameter classes.
*/

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_String;
}


+ (FxParameterType)parameterType
{
	return FxParameterType_String;
}


-(NSString*_Nullable)valueAtTime:(CMTime)renderTime
{
	return [self stringValue];
}

- (void)setValue:(NSString*_Nullable)value atTime:(CMTime)time
{
	[self setStringValue:value];
}


/*!
	@method		stringValue
	@abstract	Reads the current string value from the host.
	@return		The string value, or NULL when the parameter is not added to an effect or the retrieval API is unavailable.
	@discussion	Introduced in FxGrip 0.1.0. A retrieval failure sets the parameter's error. */
- (NSString*_Nullable)stringValue
{
	if (!self.addedToEffect) {
		return NULL;
	}
	NSString* strValue = nil;
	if(![self.effect.apiManager.paramGetAPIv6 getStringParameterValue:&strValue fromParameter:self.parameterID]) {
		_error = [NSError errorWithDomain:FxGripPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return strValue;
}

/*!
	@method		setStringValue:
	@abstract	Writes the string value to the host.
	@param		value	The string to set. A nil value stores an empty string.
	@discussion	Introduced in FxGrip 0.1.0. The write performs no work until the parameter is added to an effect. */
- (void)setStringValue:(nullable NSString *)value
{
	if (!self.addedToEffect) {
		return;
	}
	
	if (!value) {
		value = @"";
	}
	
	[self.effect.apiManager.paramSetAPIv5 setStringParameterValue:value toParameter:self.parameterID];
}


/*!
	@method		encodeWithCoder:
	@abstract	Encodes the string value at the coder's render time into the plugin-state coder.
	@param		coder	The coder that receives the value.
	@discussion	Introduced in FxGrip 0.1.0. The value encodes only when the coder is an FxPlug plugin-state encoder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];

	if (coder.isFxPluginStateEncoder) {
		[coder encodeObject:[self valueAtTime:coder.renderTime] atIndex:self.parameterID];
	} else {
		// encode meta
	}
}

