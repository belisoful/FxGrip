
+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Toggle;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Toggle;
}

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


- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];
	
	if (coder.isFxPluginStateEncoder) {
		[coder encodeBool:[self valueAtTime:coder.renderTime] atIndex:self.parameterID];
	} else {
		// encode meta
	}
}

