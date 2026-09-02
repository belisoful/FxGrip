//
//  FxParameterExtension.m
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxParameterExtension.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Notifications.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import "NSCoder+FxPlug.h"
#import "FxGrip_ARC.h"


#pragma mark -
#pragma mark FxGripExtensionParameter Implementation

@interface FxParameterExtension ()

/*! YES from the first observed parameter add: registration is underway, the ID is frozen. */
@property (nonatomic, assign) BOOL sawParameterAdd;


- (void)notifyGetFlagsPre:(nonnull NSNotification *)notification;
- (void)notifySetFlagsPre:(nonnull NSNotification *)notification;
- (void)notifySetFlags:(nonnull NSNotification *)notification;

@end


@implementation FxParameterExtension
{
	id _parameterAddObserver;
	// Cached at load: self.effect is weak and reads nil during dealloc, so the block
	// observer must be removed through a reference that outlives the effect. The
	// notifier is the process-wide center, so holding it strongly forms no cycle.
	NSPriorityNotificationCenter *_parameterNotifier;
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
	}
	return self;
}

- (void)dealloc
{
	[self removeObservers];
	// removeObserver:self covers selector observers only; the block token is its own
	// observer object and is removed by identity through the cached notifier (self.effect
	// is weak and already nil here).
	[_parameterNotifier removeObserver:_parameterAddObserver];
	_parameterAddObserver = nil;
	NARC_RELEASE(_parameterNotifier);

	SUPER_DEALLOC();
}

- (void)setParameterID:(FxParameterId)parameterID {
	if (!self.sawParameterAdd) {
		_parameterID = parameterID;
	} else {
		NSLog(@"Error: Attempted to change the FxGrip Extension Parameter Id after being added");
	}
}

- (BOOL)extLoadWithEffect:(nonnull id<FxGripTileableEffect>)effect
{
	BOOL success = [super extLoadWithEffect:effect];
	if (success && self.extActive) {
		// this tags the parameter with the extension if it matches.
		_parameterNotifier = NARC_RETAIN(self.effect.notifier);
		__weak typeof(self) weakSelf = self;
		_parameterAddObserver = [_parameterNotifier addObserverForName:FxGripNotifyAPI_ParameterAddPreName object:effect priority:-18 queue:nil usingBlock:^(NSNotification *note) {
			// Registration is underway: the parameter ID is frozen from the first add on.
			weakSelf.sawParameterAdd = YES;
			//Adds the extension key to the parameter
			[weakSelf notifyParameterAddWithExtension:note];
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

#include "../../Parameters/FxParameterBaseLibrary.m"
#include "../../Parameters/FxParameterLibrary.m"


@end
