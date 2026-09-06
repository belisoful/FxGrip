/*!
	@file       FxGripParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameter
	@abstract   Implements the parameter model root classes FxGripParameterBase and FxGripParameter.
	@discussion Introduced in FxGrip 0.1.0. FxGripParameterBase stores the parameter dictionary,
	            observes the effect's flag notifications to serve and cache flag reads and
	            writes, and encodes the parameter type into the plugin state. FxGripParameter
	            adds the custom-view surface and the secure-coding allow-list. The flag accessor
	            and value-access method bodies are split into FxGripParameterBaseLibrary.m and
	            FxGripParameterLibrary.m, which this file includes.
*/

#import "FxGripParameter.h"
#import "FxGripParameterFlags.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripAPIAccessing.h"
#import "FxGripTileableEffect.h"
#import <BEFoundation/NSCoder+AtIndex.h>
#import "NSCoder+FxPlug.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import "FxGrip_ARC.h"

#pragma mark -
#pragma mark FxGripParameter Implementation


@interface FxGripParameterBase ()

- (void)notifyGetFlagsPre:(nonnull NSNotification *)notification;
- (void)notifySetFlagsPre:(nonnull NSNotification *)notification;
- (void)notifySetFlags:(nonnull NSNotification *)notification;

@end


/*!
	@abstract	The concrete root of the parameter model.
	@discussion	Introduced in FxGrip 0.1.0. The initializer keeps the parameter dictionary and
				installs the flag observers. The class serves flag reads from a cache while the
				parameter caches, and writes flags back through the effect's parameter APIs.
*/
@implementation FxGripParameterBase

/*! The priority the flag observers register at on the effect's notifier. */
- (NSInteger)ncPriority:(nullable NSNotificationName)aName
{
	if ([FxGripNotifyAPI_ParameterGetFlagsPreName isEqualToString:aName]) {
		return -17;
	}
	return -19;
}

#include "FxGripParameterBaseLibrary.m"

@synthesize effect = _effect;

/*!
	@method		initWithDictionary:effect:
	@abstract	Initializes the parameter from its dictionary and owning effect.
	@discussion	Introduced in FxGrip 0.1.0. Returns nil when the dictionary's parameter type does
				not match the receiver's class. The dictionary is kept directly when it is
				mutable, and copied otherwise. The initializer installs the flag observers. */
-(instancetype _Nullable) initWithDictionary:(NSDictionary*)dictionary effect:(nonnull id<FxGripEffectHost>)effect
{
	self = [super init];
	if(self) {
		if (self.parameterType != dictionary.parameterType)
			return nil;
		
		_effect = effect;
		_addedToEffect = YES;
		
		_parameterName = dictionary.parameterName;
		if (!_parameterName)
			_parameterName = @"";
		
		_parameterID = dictionary.parameterID;
		_parameterParentID = dictionary.parameterParentID;
		_parameterCurrentFlags = _parameterFlags = dictionary.parameterFlags;
		
		if ([dictionary isKindOfClass:NSMutableDictionary.class]) {
			_data = (NSMutableDictionary*)dictionary;
		} else {
			_data = dictionary.mutableCopy;
		}

		[self installNotifications];
	}
	return self;
}
- (void)dealloc
{
	[self removeObservers];
	SUPER_DEALLOC();
}

- (nonnull NSString *)extKey {
	return @"";
}

- (BOOL)startChangedTime:(CMTime)time
				   error:(NSError * _Nullable * _Nullable)error
{
	//[self setParameterTargetPreset:paramID atTime:time options:PresetAll ^ PresetName];
	
	//Message the parameter Selector
	/*if ([parameter respondsToSelector:@selector(parameterSelector)]) {
		SEL selector = parameter.parameterSelector;
		if (selector) {
			FxGripManagedSelector func = (FxGripManagedSelector) objc_msgSend;
			NSObject* object = parameter.parameterSelectorObject;
			if (!object) {
				object = self;
			}
			if ([object respondsToSelector:selector]) {
				success = func(self, selector, paramID, time, error);
			} else {
				NSLog(@"Error: The selector %@ was not found on object %@", NSStringFromSelector(selector), object.className);
				success = NO;
			}
		}
	}*/
	return YES;
}


- (BOOL)endChangedTime:(CMTime)time
				   error:(NSError * _Nullable * _Nullable)error
{
	//Preset name before resetValue
	/*   [self setParameterTargetPreset:paramID atTime:time options:PresetName];
	   
	   
	   // Parameter gets reset to its resetValue when selected.
	   id resetValue = paramData.parameterResetValue;
	   
	   if (resetValue)
		   [self setParameter:paramID value:resetValue atTime:time];*/
	return YES;
}




- (SEL _Nullable)parameterSelector
{
	NSString *paramSelector = _data.parameterSelector;
	if (!paramSelector) {
		return nil;
	}
	if (![paramSelector hasPrefix:kFxParameterProperty_ManagePrefix]) {
		NSLog(@"Error: Cannot execute %@ because it did not have prefx '%@'.", paramSelector, kFxParameterProperty_ManagePrefix);
		return nil;
	}
	return NSSelectorFromString([paramSelector stringByAppendingString:@":atTime:error:"]);
}


- (BOOL)addTags
{/*
	NSArray *paramTags = self.parameterTags;
	if (paramTags) {
		if (paramTagsAPI == nil) { // Lazy Load
			paramTagsAPI = _apiManager.paramTagsAPIv1;
		}
		if (paramTagsAPI) {
			if ([paramTags isKindOfClass:[NSString class]]) {
				paramTags = ((NSString*)paramTags).splitByHumanDividers;
			}
			[paramTagsAPI setTags:paramTags toParameter:parameterID];
		} else {
			NSLog(@"FxGripTileableEffect(%llu)::generateParameters ERROR - Parameter (#%d) could not get the ParamTagsAPI", _apiManager.sessionID, parameterID);
			
		}
	}*/
	return YES;
}


@end




/*!
	@abstract	The concrete root of a leaf parameter that carries a value and an optional view.
	@discussion	Introduced in FxGrip 0.1.0. The base returns no view and no custom value classes;
				a parameter class with custom UI overrides. The value-access method bodies come
				from the included FxGripParameterLibrary.m.
*/
@implementation FxGripParameter

@synthesize customView;

- (NSView *_Nullable)newParameterView
{
	return nil;
}

- (void)attachCustomView:(NSView *_Nullable)view
{
	customView = view;
}

+ (NSSet<Class> *_Nullable)customValueClasses
{
	return nil;
}

#include "FxGripParameterLibrary.m"


@end
