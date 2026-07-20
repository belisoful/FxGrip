//
//  FxGripDebugMenu.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripParameterData.h"
#import "FxTileableEffectBase+Notifications.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxTileableEffectBase+Extensions.h"
#import "FxGripTypes.h"
#import "FxGripParameterFlags.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import "FxGrip_ARC.h"

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

- (void)dealloc
{
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
	NSNumber *pid = @(parameterID);
	
	if ([_pData [pid][key] isEqualTo:object]) {
		return;
	}
	_pData[pid][key] = object;
	_isCacheDirty = YES;
}

- (nullable id)objectForKey:(nonnull NSString *)key fromParameter:(FxParameterId)parameterID
{
	return _pData[@(parameterID)][key];
}


// extProcessParameters gets lowest priority, we want it to be last.
- (NSInteger)ncPriority:(nullable NSNotificationName)aName
{
	NSInteger priority = [super ncPriority:aName];
	
	if ([FxNotifyAPI_ParameterAddName isEqualToString:aName]) {
		return -20;
	} else if ([FxTileableEffectAddedToDocumentName isEqualToString:aName]) {
		return -18;
	} else if ([FxTileableEffectFlushName isEqualToString:aName]) {
		
		return -15;
	}
	
	return priority;
}


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



- (void)extAddedToDocument:(nonnull NSNotification*)notification
{
	if (!_pData) {
		//_pData = (NSMutableDictionary*)self.value;
		id <NSCopying, NSSecureCoding> object = nil;
		
		[self.effect.apiManager.paramGetAPIv6 getCustomParameterValue:&object fromParameter:self.parameterID atTime:kCMTimeZero];
		_pData = (NSMutableDictionary<NSNumber*, NSMutableDictionary<NSString*, id>*>*)object;
	}
}




- (void)extAPIParameterAdd:(nonnull NSNotification*)notification
{
	NSDictionary *parameter = notification.userInfo;
	
	NSNumber *pid = @(parameter.parameterID);
	
	@synchronized (self) {
		if (!_pData) {
			[self initData];
		}
		_pData[pid] = parameter.mutableCopy;
	
		_isCacheDirty = YES;
		
		if (!flagCache(_parameterFlags) && self.addedToEffect && self.effect.addedToDocument) {
			[self extFlush:notification];
		}
	}
}



- (void)extAPIParameterGetFlags:(nonnull NSNotification*)notification
{
	NSMutableDictionary *parameter = notification.mutableUserInfo;
	
	NSNumber *pid = @(parameter.parameterID);
	if (!_pData || !_pData[pid] || !_pData[pid][kFxParameterProperty_Flags]) {
		return;
	}
	parameter[kFxParameterProperty_Flags] = @(parameter.parameterFlags | (_pData[pid].parameterFlags & kFxParameterFlag_APP_MASK));
}


- (void)extAPIParameterSetFlags:(nonnull NSNotification*)notification
{
	NSMutableDictionary *parameter = notification.mutableUserInfo;
	
	NSNumber *pid = @(parameter.parameterID);
	
	if (!_pData || !_pData[pid]) {
		return;
	}
	
	_pData[pid][kFxParameterProperty_Flags] = @(RemoveTempFlags(parameter.parameterFlags) & kFxParameterFlag_APP_MASK);
}


- (void)extAPIParameterSetMenu:(nonnull NSNotification*)notification
{
	NSNumber *pid = notification.userInfo.fxParameter[kFxParameterProperty_Id];
	
	if (!_pData || !_pData[pid]) {
		return;
	}
	
	_pData[pid][kFxParameterProperty_MenuItems] = notification.userInfo.fxParameter.parameterMenuItems;
}



// when changing flags.
// 

- (void)extAPIParameterRemove:(nonnull NSNotification*)notification
{
	NSNumber *pid = notification.userInfo.fxParameter[kFxParameterProperty_Id];
	
	if (!_pData) {
		return;
	}
	
	@synchronized (self) {
		[_pData removeObjectForKey:pid];
	
		_isCacheDirty = YES;
		
		if (!flagCache(_parameterFlags) && self.addedToEffect && self.effect.addedToDocument) {
			[self extFlush:notification];
		}
	}
}


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




@implementation FxTileableEffectBase (ParameterData)

- (FxGripParameterData*)parameterData
{
	return (FxGripParameterData*)[self extensionForClass:FxGripParameterData.class];
}


- (nonnull FxGripParameterData*)newParameterDataExtension
{
	return [FxGripParameterData.alloc init];
}


@end
