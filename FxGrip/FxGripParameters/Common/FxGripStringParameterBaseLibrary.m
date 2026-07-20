
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


- (NSString*_Nullable)stringValue
{
	if (!self.addedToEffect) {
		return NULL;
	}
	NSString* strValue = nil;
	if(![self.effect.apiManager.paramGetAPIv6 getStringParameterValue:&strValue fromParameter:self.parameterID]) {
		_error = [NSError errorWithDomain:FxPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return strValue;
}

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


- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];
	
	if (coder.isFxPluginStateEncoder) {
		[coder encodeObject:[self valueAtTime:coder.renderTime] atIndex:self.parameterID];
	} else {
		// encode meta
	}
}

