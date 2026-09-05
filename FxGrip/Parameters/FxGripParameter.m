//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

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


@implementation FxGripParameterBase

- (NSInteger)ncPriority:(nullable NSNotificationName)aName
{
	if ([FxGripNotifyAPI_ParameterGetFlagsPreName isEqualToString:aName]) {
		return -17;
	}
	return -19;
}

#include "FxGripParameterBaseLibrary.m"

@synthesize effect = _effect;

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
