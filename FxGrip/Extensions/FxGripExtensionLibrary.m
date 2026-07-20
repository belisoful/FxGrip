
#if kFxGripLibraryActivator

-(NSString*_Nonnull)extKey
{
	return [self className];
}

// -20 is the highest priority, 10 is normal, 20 is lowest priority
//	other values are OK, but not officially supported and may lead to unknown behavior.
- (NSInteger)ncPriority:(nullable NSNotificationName)aName
{
	return _extDefaultPriority;
}

- (void)setExtActive:(BOOL)active
{
	if (self.effect.addedToDocument) {
		NSLog(@"Error: cannot set extension active after being added to the document.  Set this before FxTileableEffect::pluginInstanceAddedToDocument is signaled");
		return;
	}
	_extActive = active;
}

- (BOOL)extLoadWithEffect:(GuruFxTileableEffect* _Nonnull) effect
{
#ifndef kExtensionSkipEffect
	_effect = effect;
#endif
	
	if (!self.extActive) {
		return YES;
	}
	
	NSDictionary *methods = @{
		kExtensionsInitName: NSStringFromSelector(@selector(_extNameCaller:)),
		kExtensionsProcessParametersName: NSStringFromSelector(@selector(_extNameCaller1:)),
		kExtensionsAddParameterName: NSStringFromSelector(@selector(_extNameCaller1:)),
		kExtensionsFinishInitialSetupName: NSStringFromSelector(@selector(_extNameCaller:)),
		kExtensionsAddedToDocumentName: NSStringFromSelector(@selector(_extNameCaller:)),
		
		kExtensionsGetParameterTypeName: NSStringFromSelector(@selector(_extGetType:)),
		
		kExtensionsParameterGetFlagsName: NSStringFromSelector(@selector(_extChangeFlags:)),
		kExtensionsParameterSetFlagsPreName: NSStringFromSelector(@selector(_extChangeFlags:)),
		kExtensionsParameterSetFlagsName: NSStringFromSelector(@selector(_extSetFlags:)),
		
		kExtensionsGetParameterNameName: NSStringFromSelector(@selector(_extChangeParam0Pid:)),
		kExtensionsSetParameterNamePreName: NSStringFromSelector(@selector(_extChangeParam0Pid:)),
		kExtensionsSetParameterNameName: NSStringFromSelector(@selector(_extSetIdParam:)),
		
		kExtensionsGetParameterStringValueName: NSStringFromSelector(@selector(_extChangeParam0Pid:)),
		kExtensionsSetParameterStringValuePreName: NSStringFromSelector(@selector(_extChangeParam0Pid:)),
		
		kExtensionsGetParameterMenuName: NSStringFromSelector(@selector(_extChangeParam0Pid:)),
		kExtensionsSetParameterMenuItemPreName: NSStringFromSelector(@selector(_extChangeParam0Pid:)),
		kExtensionsSetParameterMenuName: NSStringFromSelector(@selector(_extSetMenuEntries:)),
		
		kExtensionsParameterChangedName: NSStringFromSelector(@selector(_extParameterChanged:)),
		
		kExtensionsRemoveParameterName: NSStringFromSelector(@selector(_extParamID:)),
		
		kExtensionsFlushName: NSStringFromSelector(@selector(_extNameCaller:)),
		kExtensionsRemovedFromDocumentName: NSStringFromSelector(@selector(_extNameCaller:)),
		kExtensionsUnloadName: NSStringFromSelector(@selector(_extNameCaller:)),
		
		kExtensionsParameterTypeForStringName: NSStringFromSelector(@selector(_extChangeParam0IntResult:)),
		kExtensionsParameterClassForTypeName: NSStringFromSelector(@selector(_extChangeParam0IntResult:))
		
	};
	
	[methods enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSString* obj, BOOL *stop) {
		
		SEL selector = NSSelectorFromString(key);
		if ([self respondsToSelector:selector]) {
		 [effect.notifier addObserver:self selector:NSSelectorFromString(obj) name:key object:effect];
	 }
	}];
	
	return YES;
}

- (void)_extNameCaller:(nonnull NSNotification*)notification
{
	NSNotificationName name = notification.name;
	if (!name) {
		return;
	}
	
	SEL selector = NSSelectorFromString(name);
	if (!selector) {
		return;
	}
	
	[self performSelector:selector];
}


- (void)_extNameCaller1:(nonnull NSNotification*)notification
{
	NSNotificationName name = notification.name;
	if (!name) {
		return;
	}
	
	SEL selector = NSSelectorFromString(name);
	if (!selector) {
		return;
	}
	
	[self performSelector:selector withObject:notification.userInfo[kExtensionsParameter0Name]];
}


- (void)_extParamID:(nonnull NSNotification*)notification
{
	NSNotificationName name = notification.name;
	if (!name) {
		return;
	}
	
	SEL selector = NSSelectorFromString(name);
	if (!selector) {
		return;
	}
	
	FxParameterId pid = ((NSNumber*)notification.userInfo[kExtensionsParameterIDName]).intValue;
	void (*method)(id, SEL, FxParameterId) = (void *)[self methodForSelector:selector];
	
	method(self, selector, pid);
}

//  for   - (FxParameterType)extGetParameterType:(FxParameterId)parameterID;
- (void)_extGetType:(nonnull NSNotification*)notification
{
	NSNotificationName name = notification.name;
	if (!name) {
		return;
	}
	
	SEL selector = NSSelectorFromString(name);
	if (!selector) {
		return;
	}
	
	FxParameterId pid = ((NSNumber*)notification.userInfo[kExtensionsParameterIDName]).intValue;
	FxParameterType (*method)(id, SEL, FxParameterId) = (void *)[self methodForSelector:selector];
	
	FxParameterType type = method(self, selector, pid);
	if (type != FxParameterType_None)
		((NSMutableDictionary*)notification.userInfo)[kExtensionsReturnValueName] = @(type);
}


- (void)_extChangeFlags:(nonnull NSNotification*)notification
{
	NSNotificationName name = notification.name;
	if (!name) {
		return;
	}
	
	SEL selector = NSSelectorFromString(name);
	if (!selector) {
		return;
	}
	FxParameterId pid = ((NSNumber*)notification.userInfo[kExtensionsParameterIDName]).intValue;
	FxParameterFlags flags = ((NSNumber*)notification.userInfo[kExtensionsParameterFlagsName]).unsignedIntValue;
	FxParameterFlags ogFlags = flags;
	
	void (*method)(id, SEL, FxParameterFlags*, FxParameterId) = (void *)[self methodForSelector:selector];
	
	method(self, selector, &flags, pid);
	
	if ([notification.userInfo isKindOfClass:NSMutableDictionary.class]) {
		if (ogFlags != flags) {
			((NSMutableDictionary*)notification.userInfo)[kExtensionsParameterFlagsName] = @(flags);
		}
	} else {
		NSLog(@"Warning: %s notification.userInfo must be NSMutableDictionary to pass along the Error", __func__);
	}
}

- (void)_extSetFlags:(nonnull NSNotification*)notification
{
	NSNotificationName name = notification.name;
	if (!name) {
		return;
	}
	
	SEL selector = NSSelectorFromString(name);
	if (!selector) {
		return;
	}
	FxParameterId pid = ((NSNumber*)notification.userInfo[kExtensionsParameterIDName]).intValue;
	FxParameterFlags flags = ((NSNumber*)notification.userInfo[kExtensionsParameterFlagsName]).unsignedIntValue;
	
	void (*method)(id, SEL, FxParameterFlags, FxParameterId) = (void *)[self methodForSelector:selector];
	
	method(self, selector, flags, pid);
}

// Any function in the form of "- (void)aMethod:(NSString**)strPtr parameterID:(FxParameterId)id"
- (void)_extChangeParam0IntResult:(nonnull NSNotification*)notification
{
	NSNotificationName name = notification.name;
	if (!name) {
		return;
	}
	
	SEL selector = NSSelectorFromString(name);
	if (!selector) {
		return;
	}
	id param0 = (NSString*)notification.userInfo[kExtensionsParameter0Name];
	
	int (*method)(id, SEL, id) = (void *)[self methodForSelector:selector];
	
	int result = method(self, selector, param0);
	
	if ([notification.userInfo isKindOfClass:NSMutableDictionary.class]) {
		if (result) {
			((NSMutableDictionary*)notification.userInfo)[kExtensionsReturnValueName] = @(result);
		}
	} else {
		NSLog(@"Warning: %s notification.userInfo must be NSMutableDictionary to pass along the new name", __func__);
	}
}

// Any function in the form of "- (void)aMethod:(NSString**)strPtr parameterID:(FxParameterId)id"
- (void)_extChangeParam0Pid:(nonnull NSNotification*)notification
{
	NSNotificationName name = notification.name;
	if (!name) {
		return;
	}
	
	SEL selector = NSSelectorFromString(name);
	if (!selector) {
		return;
	}
	FxParameterId pid = ((NSNumber*)notification.userInfo[kExtensionsParameterIDName]).intValue;
	id param0 = (NSString*)notification.userInfo[kExtensionsParameter0Name];
	id ogPName = param0;
	
	void (*method)(id, SEL, id*, FxParameterId) = (void *)[self methodForSelector:selector];
	
	method(self, selector, &param0, pid);
	
	if ([notification.userInfo isKindOfClass:NSMutableDictionary.class]) {
		if (ogPName != param0) {
			((NSMutableDictionary*)notification.userInfo)[kExtensionsParameter0Name] = param0;
		}
	} else {
		NSLog(@"Warning: %s notification.userInfo must be NSMutableDictionary to pass along the new name", __func__);
	}
}

// Any function in the form of "- (void)aMethod:(NSString*)strPtr parameterID:(FxParameterId)id"
- (void)_extSetIdParam:(nonnull NSNotification*)notification
{
	NSNotificationName name = notification.name;
	if (!name) {
		return;
	}
	
	SEL selector = NSSelectorFromString(name);
	if (!selector) {
		return;
	}
	FxParameterId pid = ((NSNumber*)notification.userInfo[kExtensionsParameterIDName]).intValue;
	id pname = (NSString*)notification.userInfo[kExtensionsParameter0Name];
	
	void (*method)(id, SEL, id, FxParameterId) = (void *)[self methodForSelector:selector];
	
	method(self, selector, pname, pid);
}




- (void)_extSetMenuEntries:(nonnull NSNotification*)notification
{
	NSNotificationName name = notification.name;
	if (!name) {
		return;
	}
	
	SEL selector = NSSelectorFromString(name);
	if (!selector) {
		return;
	}
	NSArray<NSString*>* newEntries = (NSArray<NSString*>*)notification.userInfo[kExtensionsMenuEntriesName];
	UInt32 defaultValue = ((NSNumber*)notification.userInfo[kExtensionsDefaultName]).unsignedIntValue;
	FxParameterId pid = ((NSNumber*)notification.userInfo[kExtensionsParameterIDName]).intValue;
	
	id (*method)(id, SEL, NSArray<NSString*>*, UInt32, FxParameterId) = (void *)[self methodForSelector:selector];
	
	method(self, selector, newEntries, defaultValue, pid);
}



- (void)_extParameterChanged:(nonnull NSNotification*)notification
{
	FxParameterId paramID = ((NSNumber*)notification.userInfo[kExtensionsParameterIDName]).intValue;
	CMTime time = CMTimeMakeFromDictionary((__bridge CFDictionaryRef) notification.userInfo[kExtensionsAtTimeName]);
	NSError *error = notification.userInfo[kExtensionsErrorName];
	if (error && error == (NSError*)[NSNull null]) {
		error = nil;
	}
	[(id<FxGripExtensionProtocol>)self extParameterChanged:paramID
					   atTime:time
						error:&error];
	if (!error) {
		error = (NSError*)[NSNull null];
	}

	if ([notification.userInfo isKindOfClass:NSMutableDictionary.class]) {
		((NSMutableDictionary*)notification.userInfo)[kExtensionsErrorName] = error;
	} else {
		NSLog(@"Warning: %s notification.userInfo must be NSMutableDictionary to pass along the Error", __func__);
		if (error) {
			NSLog(@"Error: The error could not be passed up due to the warning- %@", error);
		}
	}
}



- (void)_extRenderDestinationImage:(nonnull NSNotification*)notification
{
	FxImageTile	*destinationImage = notification.userInfo[kExtensionsParameter0Name];
	NSArray<FxImageTile *> *sourceImages = notification.userInfo[kExtensionsParameter1Name];
	id pluginState = notification.userInfo[kExtensionsParameter2Name];
	CMTime renderTime = CMTimeMakeFromDictionary((__bridge CFDictionaryRef) notification.userInfo[kExtensionsAtTimeName]);
	NSError *outError = notification.userInfo[kExtensionsErrorName];
	
	if (outError == (NSError*)[NSNull null]) {
		outError = nil;
	}
	
	BOOL success = [(id<FxGripExtensionProtocol>)self extRenderDestinationImage:destinationImage
												   sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
													pluginState:(id _Nullable)pluginState   //NSData or NSKeyedUnarchiver
														 atTime:(CMTime)renderTime
														  error:&outError];
	if (!outError) {
		outError = (NSError*)[NSNull null];
	}

	if ([notification.userInfo isKindOfClass:NSMutableDictionary.class]) {
		((NSMutableDictionary*)notification.userInfo)[kExtensionsErrorName] = outError;
		((NSMutableDictionary*)notification.userInfo)[kExtensionsReturnValueName] = @(success);
	} else {
		NSLog(@"Warning: %s notification.userInfo must be NSMutableDictionary to pass along the Error", __func__);
		if (outError) {
			NSLog(@"Error: The error could not be passed up due to the warning- %@", outError);
		}
	}
}


#endif
