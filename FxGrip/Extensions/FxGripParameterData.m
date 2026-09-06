/*!
	@file       FxGripParameterData.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterData
	@abstract   Implements the per-parameter static-property store extension.
	@discussion Introduced in FxGrip 0.1.0. The store captures each parameter's record from the add
	            notification, restores stored app-mask flag bits on a flags read, recaptures flag and
	            menu writes, and persists the store to a hidden custom parameter on flush. Store
	            mutations are synchronized.
*/

#import "FxGripParameterData.h"
#import "FxGripTileableEffect+Notifications.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTileableEffect+Extensions.h"
#import "FxGripTypes.h"
#import "FxGripParameterFlags.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import "FxGrip_ARC.h"

@interface FxGripParameterData ()
{
	BOOL _documentAdded;   // tracked from the AddedToDocument notification
	id _resolveObserver;
}
@end

/*!
	@abstract	The extension that captures and persists per-parameter static properties.
	@discussion	Introduced in FxGrip 0.1.0. The store loads from the document, captures parameter
				records, and flushes to a hidden custom parameter.
*/
@implementation FxGripParameterData

@synthesize isLoaded = _isLoaded;
@synthesize isCacheDirty = _isCacheDirty;

- (instancetype)init
{
	self = [super init];
	if (self) {
		_pData = nil;
		_isLoaded = NO;
		_isCacheDirty = NO;
		
		_parameterID = kFxParameterId_ParameterData;
	}
	return self;
}

- (void)initData
{
	@synchronized (self) {
		_pData = [NSMutableDictionary new];
	}
}

/*! Answers the host's parameter-data-resolve notification with this extension, so the stored
	menus and flags reach a plain host that loads it. */
- (BOOL)extLoadWithEffect:(nonnull id<FxGripTileableEffect>)effect
{
	BOOL loaded = [super extLoadWithEffect:effect];
	if (loaded && _resolveObserver == nil) {
		__weak typeof(self) weakSelf = self;
		_resolveObserver = NARC_RETAIN([self.effect.notifier
			addObserverForName:FxGripTileableEffectResolveParameterDataName
						object:effect
						 queue:nil
					usingBlock:^(NSNotification *note) {
			((NSMutableDictionary *)note.userInfo)[FxGripTileableEffectResolvedObjectKey] = weakSelf;
		}]);
	}
	return loaded;
}

- (void)dealloc
{
	if (_resolveObserver != nil) {
		[self.effect.notifier removeObserver:_resolveObserver];
		NARC_RELEASE(_resolveObserver);
	}
	NARC_RELEASE(_pData);
	
	SUPER_DEALLOC();
}
- (NSDictionary<NSNumber*, NSMutableDictionary<NSString*, id>*>*)data {
	return _pData;
}

- (BOOL)isLoaded
{
	return _pData != NULL;
}

- (FxParameterType)storedType:(FxParameterId)parameterID
{
	NSNumber *pid = @(parameterID);
	
	if (!_pData || !_pData[pid]) {
		return 0;
	}
	
	return ((NSNumber*)_pData[pid][kExtParameterData_Type]).intValue;
}

- (FxParameterFlags)storedFlags:(FxParameterId)parameterID
{
	NSNumber *pid = @(parameterID);
	
	if (!_pData || !_pData[pid]) {
		return 0;
	}
	
	return ((NSNumber*)_pData[pid][kExtParameterData_Flag]).intValue;
}

- (FxParameterId)storedParentId:(FxParameterId)parameterID
{
	NSNumber *pid = @(parameterID);
	
	if (!_pData || !_pData[pid]) {
		return -1;
	}
	
	return ((NSNumber*)_pData[pid][kExtParameterData_SubGroup]).intValue;
}

- (nullable NSArray<NSString*> *)storedMenus:(FxParameterId)parameterID
{
	NSNumber *pid = @(parameterID);
	
	if (!_pData || !_pData[pid]) {
		return NULL;
	}
	
	return _pData[pid][kExtParameterData_MenuItems];
}

- (nullable NSString *)storedSelector:(FxParameterId)parameterID
{
	NSNumber *pid = @(parameterID);
	
	if (!_pData || !_pData[pid]) {
		return NULL;
	}
	
	return _pData[pid][kExtParameterData_Selector];
}


- (void)setObject:(nonnull id)object forKey:(nonnull NSString *)key toParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *record = _pData[@(parameterID)];

	if (!record || [record[key] isEqualTo:object]) {
		return;
	}
	record[key] = object;
	_isCacheDirty = YES;
}

- (nullable id)objectForKey:(nonnull NSString *)key fromParameter:(FxParameterId)parameterID
{
	return _pData[@(parameterID)][key];
}


// Lower numbers run first. ParameterData seeds the store from the add config before the
// parameters are constructed (−20, ahead of the base's −18 capture), and persists on
// flush AFTER the base's −14 flag flush, which re-writes flag words the store must
// capture in the same cycle.
- (NSInteger)ncPriority:(nullable NSNotificationName)aName
{
	NSInteger priority = [super ncPriority:aName];

	if ([FxGripNotifyAPI_ParameterAddName isEqualToString:aName]) {
		return -20;
	} else if ([FxGripTileableEffectAddedToDocumentName isEqualToString:aName]) {
		return -18;
	} else if ([FxGripTileableEffectFlushName isEqualToString:aName]) {
		// After the base flag flush (−14) so flag words it writes are persisted this cycle.
		return -13;
	}

	return priority;
}


/*!
	@method		extAddParameters:
	@abstract	Registers the hidden ParameterData custom parameter that stores the records.
	@discussion	Introduced in FxGrip 0.1.0. The parameter carries no state, is never presented or
				animated, and stays out of the debug view. */
- (void)extAddParameters:(nonnull NSNotification*)notification
{
	NSDictionary *metaData = @{
		kFxParameterProperty_Factory: self,
		@"id": @(kFxParameterId_ParameterData),
		@"name": @"Plugin Parameter Data",
		@"type": kFxParameterType_Custom,
		@"flags": @[kParameterFlagString_DONT_DISPLAY, kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE, // kParameterFlagString_PRESETNOMETA,
					kParameterFlagString_NO_DEBUG, kParameterFlagString_NO_STATE]
	};
	[notification.userInfo.fxEffectParameters addObject:[metaData mutableCopy]];
}



/*!
	@method		extAddedToDocument:
	@abstract	Loads the stored records from the document's custom parameter.
	@discussion	Introduced in FxGrip 0.1.0. The store is loaded only when it was not already seeded
				before the document load. */
- (void)extAddedToDocument:(nonnull NSNotification*)notification
{
	_documentAdded = YES;
	if (!_pData) {
		//_pData = (NSMutableDictionary*)self.value;
		id <NSCopying, NSSecureCoding> object = nil;
		
		[self.effect.apiManager.paramGetAPIv6 getCustomParameterValue:&object fromParameter:self.parameterID atTime:kCMTimeZero];
		_pData = (NSMutableDictionary<NSNumber*, NSMutableDictionary<NSString*, id>*>*)object;
	}
}




// The parameter id and properties are read directly from the nested parameter dictionary:
// the guarded accessors require id+type+name together, which the API payloads do not
// always carry, and the outer dictionary holds only the id and the nested parameter.
- (void)extAPIParameterAdd:(nonnull NSNotification*)notification
{
	NSDictionary *parameter = notification.userInfo.fxParameter;
	NSNumber *pid = parameter[kFxParameterProperty_Id] ?: notification.userInfo[kFxParameterProperty_Id];
	if (!pid) {
		return;
	}

	@synchronized (self) {
		if (!_pData) {
			[self initData];
		}
		_pData[pid] = parameter.mutableCopy;

		_isCacheDirty = YES;
		
		if (!flagCache(_parameterFlags) && self.addedToEffect && _documentAdded) {
			[self extFlush:notification];
		}
	}
}



/*!
	@method		extAPIParameterGetFlags:
	@abstract	Merges the stored app-mask flag bits into the flags reported on a flags read.
	@discussion	Introduced in FxGrip 0.1.0. Returns when the parameter has no stored flags. */
- (void)extAPIParameterGetFlags:(nonnull NSNotification*)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	NSNumber *pid = parameter[kFxParameterProperty_Id];

	if (!pid || !_pData || !_pData[pid] || !_pData[pid][kFxParameterProperty_Flags]) {
		return;
	}
	FxParameterFlags notified = ((NSNumber*)parameter[kFxParameterProperty_Flags]).unsignedIntValue;
	FxParameterFlags stored = ((NSNumber*)_pData[pid][kFxParameterProperty_Flags]).unsignedIntValue;
	parameter[kFxParameterProperty_Flags] = @(notified | (stored & kFxParameterFlag_APP_MASK));
}


/*!
	@method		extAPIParameterSetFlags:
	@abstract	Recaptures a parameter's app-mask flags on a flags write.
	@discussion	Introduced in FxGrip 0.1.0. Temporary flag bits are dropped before storing. */
- (void)extAPIParameterSetFlags:(nonnull NSNotification*)notification
{
	NSDictionary *parameter = notification.userInfo.fxParameter;
	NSNumber *pid = parameter[kFxParameterProperty_Id];

	if (!pid || !_pData || !_pData[pid]) {
		return;
	}
	FxParameterFlags notified = ((NSNumber*)parameter[kFxParameterProperty_Flags]).unsignedIntValue;
	_pData[pid][kFxParameterProperty_Flags] = @(RemoveTempFlags(notified) & kFxParameterFlag_APP_MASK);
	_isCacheDirty = YES;
}


/*! @abstract Recaptures a parameter's menu items on a menu write. */
- (void)extAPIParameterSetMenu:(nonnull NSNotification*)notification
{
	NSDictionary *parameter = notification.userInfo.fxParameter;
	NSNumber *pid = parameter[kFxParameterProperty_Id];

	if (!pid || !_pData || !_pData[pid]) {
		return;
	}

	_pData[pid][kFxParameterProperty_MenuItems] = parameter[kFxParameterProperty_MenuItems];
	_isCacheDirty = YES;
}



// when changing flags.
//

/*!
	@method		extAPIParameterRemove:
	@abstract	Drops a parameter's record and flushes when the instance is live.
	@discussion	Introduced in FxGrip 0.1.0. */
- (void)extAPIParameterRemove:(nonnull NSNotification*)notification
{
	NSNumber *pid = notification.userInfo.fxParameter[kFxParameterProperty_Id];
	
	if (!_pData) {
		return;
	}
	
	@synchronized (self) {
		[_pData removeObjectForKey:pid];
	
		_isCacheDirty = YES;
		
		if (!flagCache(_parameterFlags) && self.addedToEffect && _documentAdded) {
			[self extFlush:notification];
		}
	}
}


/*!
	@method		extFlush:
	@abstract	Persists the store to the custom parameter when it has unsaved changes.
	@discussion	Introduced in FxGrip 0.1.0. Returns when the store is clean or absent. */
- (void)extFlush:(nonnull NSNotification*)notification
{
	@synchronized (self) {
		if (!_isCacheDirty || !_pData) {
			return;
		}
		_isCacheDirty = NO;
		
		[self.effect.apiManager.paramSetAPIv5 setCustomParameterValue:_pData toParameter:self.parameterID atTime:kCMTimeZero];
	}
}

@end




/*!
	@abstract	The effect-side accessors for the parameter data extension.
	@discussion	Introduced in FxGrip 0.1.0. parameterData resolves the loaded extension.
*/
@implementation FxGripTileableEffect (ParameterData)

- (FxGripParameterData*)parameterData
{
	return (FxGripParameterData*)[self extensionForClass:FxGripParameterData.class];
}


- (nonnull FxGripParameterData*)newParameterDataExtension
{
	return [FxGripParameterData.alloc init];
}


@end
