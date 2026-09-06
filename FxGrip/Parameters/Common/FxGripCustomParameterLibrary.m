/*!
	@file       FxGripCustomParameterLibrary.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCustomParameterLibrary
	@abstract   The shared method bodies for the custom parameter classes.
	@discussion Introduced in FxGrip 0.1.0. The fragment is textually included inside a custom parameter's @implementation when kFxGripLibraryActivator is set. It supplies the type identifiers, host registration, value access, and state encoding common to the custom parameter classes.
*/

#if kFxGripLibraryActivator


@synthesize dataClasses = _dataClasses;



+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Custom;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Custom;
}


/*!
	@method		addParameter:toEffect:
	@abstract	Registers the custom parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default value is an empty mutable dictionary. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{ /*
	NSObject<NSSecureCoding, NSCopying, NSObject> *customDefaultValue = nil;
	NSString *customClassStr = nil;//_data.parameterCustomClass;
	NSObject *defaultData = nil;//_data.parameterDefaultValue;
	if (defaultData) {
		if ([defaultData isMemberOfClass:[NSDictionary class]] || [defaultData isMemberOfClass:[NSMutableDictionary class]])
			customClassStr = [FxGripInterpolatingDictionary className];
		else {
			customDefaultValue = (NSObject<NSSecureCoding, NSCopying, NSObject>*)defaultData;
			customClassStr = [defaultData className];
		}
	} else if (!customClassStr) { // default to the FxGripInterpolatingDictionary
		customClassStr = [FxGripInterpolatingDictionary className];
	}
	
	Class customClass = NSClassFromString(customClassStr);
	if (customClass) {
		if ([customClass conformsToProtocol:@protocol(NSSecureCoding)]) {
			if ([customClass conformsToProtocol:@protocol(NSCopying)]) {
				if (customDefaultValue) {
					if ([customDefaultValue isKindOfClass: FxGripInterpolatingDictionary.class]) {
						[((FxGripInterpolatingDictionary*)customDefaultValue).data mergeEntriesFromDictionary:(NSDictionary*)defaultData];
					}
					if (![defaultData isMemberOfClass:customClass] &&
						[customDefaultValue isKindOfClass:[NSMutableDictionary class]] &&
						[defaultData isKindOfClass:[NSDictionary class]]) {
						[(NSMutableDictionary*)customDefaultValue mergeEntriesFromDictionary:(NSDictionary*)defaultData];
					}
				} else {
					
					customDefaultValue = [[[customClass alloc] init] autorelease];
				}
				
				[self.effect initializeCustomData:&customDefaultValue parameterID:self.parameterID];
			} else {
				NSLog(@"FxGripTileableEffect(%llu)::__func__ - ERROR: Custom Class \"%@\" does not conform to NSCopying", self.effect.apiManager.sessionID, customClassStr);
			}
		} else {
			NSLog(@"FxGripTileableEffect(%llu)::__func__ - ERROR: Custom Class \"%@\" does not conform to NSSecureCoding", self.effect.apiManager.sessionID, customClassStr);
		}
	} else {
		NSLog(@"FxGripTileableEffect(%llu)::__func__ - ERROR: Custom Class \"%@\" was not found", self.effect.apiManager.sessionID, customClassStr);
	}
   */
	
	
	/*if (self.hasMeta && paramData.parameterCustomClasses) {
		//Make the Meta Parameter
		((NSMutableDictionary*)self.meta.data[kFxMetaProperty_Parameters])[@(parameterID)] = [NSMutableDictionary dictionaryWithCapacity:10];
		
		// pre-install the custom classes from initial parameters
		((NSDictionary*)self.meta.data[kFxMetaProperty_Parameters])[@(parameterID)][kFxMetaProperty_ParamCustomClasses] = paramData.parameterCustomClasses;
	}*/
	NSObject<NSSecureCoding, NSCopying, NSObject> *customDefaultValue = NSMutableDictionary.new;
	
	
	return [effect.apiManager.paramCreateAPIv5 addCustomParameterWithName: parameter.parameterName
															  parameterID: parameter.parameterID
															 defaultValue: customDefaultValue
														   parameterFlags: parameter.parameterFlags];
}


/*!
	@method		valueAtTime:
	@abstract	Reads the custom value at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The custom value, or NULL when the parameter is not added to an effect or the retrieval API is unavailable.
	@discussion	Introduced in FxGrip 0.1.0. A retrieval failure sets the parameter's error. */
-(id<NSSecureCoding, NSCopying> _Nullable) valueAtTime:(CMTime)renderTime
{
	if (!self.addedToEffect) {
		return NULL;
	}
	id<NSSecureCoding, NSCopying> customValue = nil;
	if(![self.effect.apiManager.paramGetAPIv6 getCustomParameterValue:(NSObject<NSSecureCoding, NSCopying>**)&customValue fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxGripPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];;
	}
	return customValue;
}

/*!
	@method		setValue:atTime:
	@abstract	Writes the custom value at a render time.
	@param		value		The custom value to set.
	@param		renderTime	The time to set the value at.
	@discussion	Introduced in FxGrip 0.1.0. A setting failure sets the parameter's error. */
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value atTime:(CMTime)renderTime
{
	if(![self.effect.apiManager.paramSetAPIv6 setCustomParameterValue:(NSObject<NSSecureCoding, NSCopying>*)value toParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxGripPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];;
	}
}

-(id<NSSecureCoding, NSCopying> _Nullable) value
{
	return [self valueAtTime:kCMTimeZero];
}

- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value
{
	[self setValue:value atTime:kCMTimeZero];
}


/*!
	@method		encodeWithCoder:
	@abstract	Encodes the custom value at the coder's render time into the plugin-state coder.
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

#endif
