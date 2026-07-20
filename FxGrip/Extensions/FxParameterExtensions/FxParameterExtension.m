//
//  FxGripExtension.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxParameterExtension.h"
#import "FxTileableEffectBase.h"
#import "FxTileableEffectBase+Notifications.h"
#import "NSDictionary+FxTileableEffect.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import "NSCoder+FxPlug.h"
#import "FxGrip_ARC.h"
/*
#import <CoreMedia/CoreMedia.h>
#import "GuruFxTileableEffect.h"
#import "GuruFxTileableEffect+Extensions.h"
#import "FxGripInterpolatingDictionary.h"
#import "NSCoder+FxPlug.h"*/


#pragma mark -
#pragma mark FxGripExtensionParameter Implementation

@implementation FxParameterExtension
{
	id _notifierObservers[kFxParameterInnerNotificationCount + 1];
}

@synthesize customView;

- (instancetype _Nullable)init
{
	self = [super init];
	if (self) {
		_addedToEffect = NO;
		
		_parameterName = nil;
		_parameterID = 0;
		_parameterParentID = 0;
		_parameterCurrentFlags = _parameterFlags = 0;
		
		_notifierObservers[kFxParameterInnerNotificationCount] = nil;
		
	}
	return self;
}

- (void)dealloc
{
	[self removeObservers];
	
	SUPER_DEALLOC();
}

- (void)setParameterID:(FxParameterId)parameterID {
	if (!self.effect.addedParameters) {
		_parameterID = parameterID;
	} else {
		NSLog(@"Error: Attempted to change the FxGrip Extension Parameter Id after being added");
	}
}

- (BOOL)extLoadWithEffect:(nonnull id<FxTileableEffectBase>)effect
{
	BOOL success = [super extLoadWithEffect:effect];
	if (success && self.extActive) {
		// this tags the parameter with the extension if it matches.
		_notifierObservers[kFxParameterInnerNotificationCount] = [self.effect.notifier addObserverForName:FxNotifyAPI_ParameterAddPreName object:effect priority:-18 queue:nil usingBlock:^(NSNotification *note) {
			//Adds the extension key to the parameter
			[self notifyParameterAddWithExtension:note];
		}];
	}
	return success;
}

- (nullable id) parameterForDictionary:(nonnull NSDictionary *)data
{
	_addedToEffect = YES;
	
	_parameterName = data.parameterName;
	_parameterID = data.parameterID;
	_parameterParentID = data.parameterParentID;
	_parameterCurrentFlags = _parameterFlags = data.parameterFlags;
	
	return self;
}


- (BOOL)startChangedTime:(CMTime)time error:(NSError * _Nullable * _Nullable)error
{
	return YES;
}

- (BOOL)endChangedTime:(CMTime)time error:(NSError * _Nullable * _Nullable)error
{
	return YES;
}


- (void)notifyParameterAddWithExtension:(NSNotification*)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	if (parameter.parameterID != _parameterID) {
		return;
	}
	
	if (!parameter.parameterExtensionKey) {
		parameter[kFxParameterProperty_ExtensionKey] = self.extKey;
	}
	
	if ([self conformsToProtocol:@protocol(FxParameterFactory)]) {
		parameter[kFxParameterProperty_Factory] = self;
	}
}

#include "../../FxGripParameters/FxParameterBaseLibrary.m"
#include "../../FxGripParameters/FxParameterLibrary.m"


@end
