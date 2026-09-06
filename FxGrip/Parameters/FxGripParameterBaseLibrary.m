/*!
	@file       FxGripParameterBaseLibrary.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterBaseLibrary
	@abstract   The FxGripParameterBase method bodies shared by the base and by parameter extensions.
	@discussion Introduced in FxGrip 0.1.0. FxGripParameter.m includes this fragment into
	            FxGripParameterBase, and FxGripParameterExtension includes it as well. It holds
	            the notification wiring, the boolean flag accessors, the state test, and the
	            name, type, flags, and plugin-state coding methods. ncPriority: is defined by
	            each including class, not here.
*/

@synthesize error = _error;

@synthesize parameterName = _parameterName;
@synthesize parameterID = _parameterID;
@synthesize parameterFlags = _parameterFlags;
@synthesize parameterParentID = _parameterParentID;

@synthesize addedToEffect = _addedToEffect;
@synthesize parameterCurrentFlags = _parameterCurrentFlags;

// The center holds selector observers weakly; the effect's parameters dictionary keeps
// the parameter alive, and dealloc removes the registrations.
- (void)installNotifications
{
	[self.effect.notifier addObserver:self selector:@selector(notifyGetFlagsPre:) name:FxGripNotifyAPI_ParameterGetFlagsPreName object:self.effect];
	[self.effect.notifier addObserver:self selector:@selector(notifySetFlagsPre:) name:FxGripNotifyAPI_ParameterSetFlagsPreName object:self.effect];
	[self.effect.notifier addObserver:self selector:@selector(notifySetFlags:) name:FxGripNotifyAPI_ParameterSetFlagsName object:self.effect];
}

- (void)removeObservers
{
	[self.effect.notifier removeObserver:self];
}

// ncPriority: is NOT defined here: FxGripParameterExtension includes this fragment and must
// keep FxGripExtension's implementation. FxGripParameterBase defines its own in FxGripParameter.m.

// Direct key: thin payloads cannot satisfy the guarded parameterID accessor.
- (BOOL)notificationTargetsReceiver:(nonnull NSNotification *)notification
{
	return [@(_parameterID) isEqual:notification.userInfo.fxParameter[kFxParameterProperty_Id]];
}

/*!
	@method		notifyGetFlagsPre:
	@abstract	Serves a flag read from the cache before the host reads them.
	@discussion	Introduced in FxGrip 0.1.0. Answers with the cached flags, and marks the result
				handled, while the parameter caches or is not yet added to the effect. */
// get on cache returns cache
- (void)notifyGetFlagsPre:(nonnull NSNotification *)notification
{
	if (![self notificationTargetsReceiver:notification]) {
		return;
	}
	if (self.flagCaching || !_addedToEffect) {
		notification.userInfo.mutableFxParameter.parameterFlags = _parameterFlags;
		notification.mutableUserInfo.fxResult = @YES;
	}
}

/*!
	@method		notifySetFlagsPre:
	@abstract	Absorbs a flag write into the cache before the host applies it.
	@discussion	Introduced in FxGrip 0.1.0. A write with the cache bit set stores the flags with
				the cache-dirty bit and marks the result handled; a plain write clears the
				cache-dirty bit and continues to the host. */
// set on cache, sets the cache
- (void)notifySetFlagsPre:(nonnull NSNotification *)notification
{
	if (![self notificationTargetsReceiver:notification]) {
		return;
	}
	FxParameterFlags flags = ((NSNumber*)notification.userInfo.fxParameter[kFxParameterProperty_Flags]).unsignedIntValue;
	if (flagCache(flags)) {
		_parameterFlags = UnsavingFlags(flags | kFxParameterFlag_CACHEDIRTY);
		notification.mutableUserInfo.fxResult = @YES;
	} else {
		notification.userInfo.mutableFxParameter.parameterFlags = flags & ~(kFxParameterFlag_CACHEDIRTY);
	}
}

/*!
	@method		notifySetFlags:
	@abstract	Commits a saving flag write into the parameter's stored flags.
	@discussion	Introduced in FxGrip 0.1.0. A write with the saving bit set becomes the
				parameter's current and stored flags, with the saving and cache-dirty bits
				cleared. */
- (void)notifySetFlags:(nonnull NSNotification *)notification
{
	if (![self notificationTargetsReceiver:notification]) {
		return;
	}
	FxParameterFlags flags = ((NSNumber*)notification.userInfo.fxParameter[kFxParameterProperty_Flags]).unsignedIntValue;
	if (flagSaving(flags)) {
		_parameterCurrentFlags = _parameterFlags = UnsavingFlags(flags) & (~kFxParameterFlag_CACHEDIRTY);
	}
}




- (BOOL)flagHidden {
	return flagHidden(_parameterFlags);
}

- (void)setFlagHidden:(BOOL)hidden {
	if (hidden != flagHidden(_parameterFlags)) {
		[self setParameterFlags:_parameterFlags ^ kFxParameterFlag_HIDDEN];
	}
}


- (BOOL)flagDisabled {
	return flagDisabled(self.parameterFlags);
}

- (void)setFlagDisabled:(BOOL)disabled {
	if (disabled != flagDisabled(_parameterFlags)) {
		[self setParameterFlags:_parameterFlags ^ kFxParameterFlag_DISABLED];
	}
}


- (BOOL)flagDontDisplayInDashboard {
	return flagDontDisplay(_parameterFlags);
}

- (void)setFlagDontDisplayInDashboard:(BOOL)dontDisplayInDashboard {
	if (dontDisplayInDashboard != flagDontDisplay(_parameterFlags)) {
		[self setParameterFlags:_parameterFlags ^ kFxParameterFlag_DONT_DISPLAY_IN_DASHBOARD];
	}
}




- (BOOL)flagInvalid {
	return flagInvalid(_parameterFlags);
}

- (void)setFlagInvalid:(BOOL)invalid {
	if (invalid != flagInvalid(_parameterFlags)) {
		[self setParameterFlags:_parameterFlags ^ kFxParameterFlag_INVALID];
	}
}


- (BOOL)flagNoState {
	return flagNoState(_parameterFlags);
}

- (void)setFlagNoState:(BOOL)noState {
	if (noState != flagNoState(_parameterFlags)) {
		[self setParameterFlags:_parameterFlags ^ kFxParameterFlag_NOSTATE];
	}
}


- (BOOL)flagNoDebug {
	return flagNoDebug(_parameterFlags);
}

- (void)setFlagNoDebug:(BOOL)noDebug {
	if (noDebug != flagNoDebug(_parameterFlags)) {
		[self setParameterFlags:_parameterFlags ^ kFxParameterFlag_NO_DEBUG];
	}
}


- (BOOL)flagInDebugMode {
	return flagInDebugMode(_parameterFlags);
}

- (void)setFlagInDebugMode:(BOOL)inDebugMode {
	if (inDebugMode != flagInDebugMode(_parameterFlags)) {
		[self setParameterFlags:_parameterFlags ^ kFxParameterFlag_IN_DEBUG_MODE];
	}
}


- (BOOL)flagHiddenProxy {
	return flagHiddenProxy(_parameterFlags);
}

- (void)setFlagHiddenProxy:(BOOL)hiddenProxy {
	if (hiddenProxy != flagHiddenProxy(_parameterFlags)) {
		[self setParameterFlags:_parameterFlags ^ kFxParameterFlag_HIDDEN_PROXY];
	}
}


- (BOOL)flagCaching {
	return flagCache(_parameterFlags);
}

- (void)setFlagCaching:(BOOL)caching {
	if (caching != flagCache(_parameterFlags)) {
		[self setParameterFlags:_parameterFlags ^ kFxParameterFlag_CACHE];
	}
}



- (BOOL)flagCacheDirty {
	return flagCacheDirty(_parameterFlags);
}


// Define all the flags here
#define flagMethodBody(flagType) -(BOOL) flagType {return flagType(self.parameterFlags);}

flagMethodBody(flagIsDefault)

/*!
	@method		hasState
	@abstract	Answers whether the parameter contributes to the plugin state.
	@return		YES when the parameter is a state parameter and neither it nor any ancestor sets
				the no-state flag.
	@discussion	Introduced in FxGrip 0.1.0. The walk climbs the parent chain through the effect's
				indexed access. */
- (BOOL)hasState
{
	if (![self conformsToProtocol:@protocol(FxGripStateParameter)]) {
		return NO;
	}
	id<FxGripParameterBase> param = self;
	FxParameterId parentId = 0;
	do {
		if (param.flagNoState) {
			return NO;
		}
		if ((parentId = param.parameterParentID)
			&& [self.effect respondsToSelector:@selector(objectAtIndexedSubscript:)]) {
			param = self.effect[parentId];
		} else {
			param = nil;
		}
	} while (param != nil);
	
	return YES;
}


/*! @abstract Reads the parameter's name from the host through the dynamic parameter API. */
- (NSString*_Nonnull)parameterName
{
	NSString *pName = nil;
	NSError *error = [self.effect.apiManager.dynamicParamAPIv3 parameter:_parameterID name:&pName];
	if (error) {
		NSLog(@"Error: could not get the name of parameter #%d", _parameterID);
	}
	_parameterName = pName;
	return _parameterName;
}


- (void)setParameterName:(NSString*_Nonnull)name
{
	_parameterName = name;
	if (!_addedToEffect) {
		return;
	}
	_error = [self.effect.apiManager.dynamicParamAPIv3 setParameter:_parameterID name:_parameterName];
}



+ (nullable NSString *)parameterTypeString
{
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
									   reason:@" Subclasses must override - (NSString*)parameterTypeString"
									 userInfo:nil];
}

// Subclasses must Override
+ (FxParameterType)parameterType
{
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
									   reason:@" Subclasses must override - (FxParameterType)parameterType"
									 userInfo:nil];
}

- (FxParameterType)parameterType
{
	return self.class.parameterType;
}

/*! @abstract Reads the parameter's live flags from the host, or the invalid flag on failure. */
- (FxParameterFlags)parameterFlags
{
	FxParameterFlags flags = 0;
	if (![self.effect.apiManager.paramGetAPIv6 getParameterFlags:&flags fromParameter:_parameterID]) {
		return kFxParameterFlag_INVALID;
	}
	return flags;
}

- (void)setParameterFlags:(FxParameterFlags)flags
{
	[self.effect.apiManager.paramSetAPIv5 setParameterFlags:flags toParameter:_parameterID];
}


+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"Error: Subclasses must override %s", __func__]
								 userInfo:nil];
}

/*!
	@method		parameterFlush
	@abstract	Writes the cached flags to the host and clears the cache bit.
	@discussion	Introduced in FxGrip 0.1.0. Runs only while the parameter caches. */
- (void)parameterFlush
{
	if (self.flagCaching) {
		_parameterFlags &= ~kFxParameterFlag_CACHE;
		[self.effect.apiManager.paramSetAPIv5 setParameterFlags:_parameterFlags toParameter:_parameterID];
	}
	
	// If the value is cached, save
	/*
	NSMutableDictionary *paramData = __parameters[pid];
	FxParameterFlags flags = paramData.parameterFlags;
	int pidInt = [pid intValue];
	
	//Update the values
	if (flags & kFxParameterFlag_CACHEDIRTY) {
		flags &= ~kFxParameterFlag_CACHEDIRTY;
		id newValue = [paramData objectForKey:kFxMetaProperty_ParamValue];
		NSFxTime *newValueTime = [paramData objectForKey:kFxMetaProperty_ParamValueTime];
		if (newValue) {
			[paramData removeObjectForKey:kFxMetaProperty_ParamValue];
			if (newValueTime)
				[FxGripPreset setParameterValue:newValue toParameter:pidInt atTime:newValueTime.time withAPI:paramSetAPIv5];
		}
		if (newValueTime) {
			[paramData removeObjectForKey:kFxMetaProperty_ParamValueTime];
		}
	} */
}


/*!
	@method		createdWithFlags:parentID:
	@abstract	Records that the host created the parameter, storing its flags and parent.
	@discussion	Introduced in FxGrip 0.1.0. Runs once; a second call is ignored. */
- (void)createdWithFlags:(FxParameterFlags)flags parentID:(FxParameterId)parentID
{
	if (!_addedToEffect) {
		_addedToEffect = YES;
		self.parameterFlags = SavingFlags(flags);
		_parameterParentID = parentID;
	}
}


- (void)setParameterParentID:(FxParameterId)parentID
{
	_parameterParentID = parentID;
}


- (void)timelineTime:(nonnull CMTime*)timelineTime
	   fromImageTime:(CMTime)time
{
	[self.effect.apiManager.timingAPIv4 timelineTime:timelineTime fromImageTime:time forParameterID:_parameterID];
}

- (void)imageTime:(nonnull CMTime*)imageTime
 fromTimelineTime:(CMTime)time
{
	[self.effect.apiManager.timingAPIv4 imageTime:imageTime forParameterID:_parameterID fromTimelineTime:time];
}



/*!
	@method		encodeWithCoder:
	@abstract	Encodes the parameter type into the plugin state.
	@discussion	Introduced in FxGrip 0.1.0. The type is written under the parameter's type key
				only for a plugin-state encoder, and only in a debug build. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	if (coder.isFxPluginStateEncoder) {
#if DEBUG
		[coder encodeInt:(int)self.parameterType forKey:[NSString stringWithFormat:@"%d%@", _parameterID, kFxGripPluginStateParameterTypeString]];
#endif
	} else {
		// encode meta
	}
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{	
	return self;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

