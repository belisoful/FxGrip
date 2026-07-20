//
//  FxGripExtension.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxExtension.h"
#import "FxTileableEffectBase.h"
#import "FxTileableEffectBase+Notifications.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxParameterExtension.h"
#import "FxGripParameterUtility.h"
/*
#import <CoreMedia/CoreMedia.h>
#import "GuruFxTileableEffect.h"
#import "GuruFxTileableEffect+Extensions.h"
#import "FxGripInterpolatingDictionary.h"
#import "NSCoder+FxPlug.h"*/


#pragma mark -
#pragma mark FxExtension Implementation

const NSInteger FxExtensionDefaultPriority = 10;


@implementation FxExtensionBase

@synthesize extActive = _extActive;
@synthesize effect = _effect;
@synthesize extKey = _extKey;
@synthesize extKeyIndex = _extKeyIndex;
@synthesize extIncludeWhenDisabled = _extIncludeWhenDisabled;
@synthesize extDefaultPriority = _extDefaultPriority;
@synthesize extIndividuate = _extIndividuate;

- (nullable id)init
{
	//self = [super init];
	if (self) {
		_extActive = YES;
		_effect = NULL;
		_extKey = self.className;
		_extKeyIndex = -1;
		_extIncludeWhenDisabled = NO;
		_extDefaultPriority = FxExtensionDefaultPriority;
		_extIndividuate = NO;
	}
	return self;
}

// -20 is the highest priority, 10 is normal, 20 is lowest priority
//	other values are OK, but not officially supported and may lead to unknown behavior.
- (NSInteger)ncPriority:(nullable NSNotificationName)aName
{
	return _extDefaultPriority;
}



- (BOOL)extLoadWithIndex:(NSInteger)index
{
	_extKeyIndex = index;
	if (_extIndividuate) {
		_extKey = [_extKey stringByAppendingFormat:@"%ld", (long)_extKeyIndex];
	}
	return self.extIncludeWhenDisabled;
}


- (BOOL)extLoadWithEffect:(nonnull id<FxTileableEffectBase>)effect atIndex:(NSInteger)index
{
	_extKeyIndex = index;
	if (_extIndividuate) {
		_extKey = [_extKey stringByAppendingFormat:@"%ld", (long)_extKeyIndex];
	}
	return [self extLoadWithEffect:effect];
}

- (BOOL)extLoadWithEffect:(nonnull id<FxTileableEffectBase>)effect
{
	_effect = effect;
	
	if (!self.extActive) {
		return self.extIncludeWhenDisabled;
	}
	
	NSDictionary *methods = @{
		
	//Effect Notifications
		FxTileableEffectInitName: NSStringFromSelector(@selector(extInit:)),
		
		FxTileableEffectPropertiesName: NSStringFromSelector(@selector(extProperties:)),
		FxTileableEffectAddParametersName: NSStringFromSelector(@selector(extAddParameters:)),
		FxTileableEffectFinishInitialSetupName: NSStringFromSelector(@selector(extFinishInitialSetup:)),
		FxTileableEffectAddedToDocumentName: NSStringFromSelector(@selector(extAddedToDocument:)),
		
		FxTileableEffectParameterChangedName: NSStringFromSelector(@selector(extParameterChanged:)),
		FxTileableEffectFlushName: NSStringFromSelector(@selector(extFlush:)),
		
		FxTileableEffectPluginStateName: NSStringFromSelector(@selector(extPluginState:)),
		FxTileableEffectDestinationImageRectName: NSStringFromSelector(@selector(extDestinationRect:)),
		FxTileableEffectSourceTileRectName: NSStringFromSelector(@selector(extSourceRect:)),
		FxTileableEffectScheduleInputsName: NSStringFromSelector(@selector(extSchedule:)),
		FxTileableEffectRenderDestinationImageName: NSStringFromSelector(@selector(extRenderDestinationImage:)),
		
		FxTileableEffectRemovedFromDocumentName: NSStringFromSelector(@selector(extRemovedFromDocument:)),
		FxTileableEffectUnloadName: NSStringFromSelector(@selector(extUnload:)),
		
		
	//API Notifications
	//	Creation
		FxNotifyAPI_ParameterAddPreName:  NSStringFromSelector(@selector(extAPIParameterAddPre:)),
		FxNotifyAPI_ParameterAddName:  NSStringFromSelector(@selector(extAPIParameterAdd:)),
		FxNotifyAPI_ParameterStartGroupName:  NSStringFromSelector(@selector(extAPIParameterStartGroup:)),
		FxNotifyAPI_ParameterEndGroupName:  NSStringFromSelector(@selector(extAPIParameterEndGroup:)),
		
	//	Dynamic
		FxNotifyAPI_ParameterRemoveName:  NSStringFromSelector(@selector(extAPIParameterRemove:)),
		FxNotifyAPI_ParameterGetNameName:  NSStringFromSelector(@selector(extAPIParameterGetName:)),
		FxNotifyAPI_ParameterSetNamePreName: NSStringFromSelector(@selector(extAPIParameterSetNamePre:)),
		FxNotifyAPI_ParameterSetNameName:  NSStringFromSelector(@selector(extAPIParameterSetName:)),
		FxNotifyAPI_ParameterGetTypeName:  NSStringFromSelector(@selector(extAPIParameterGetType:)),
	
		FxNotifyAPI_ParameterSetFloatBoundsName:  NSStringFromSelector(@selector(extAPIParameterSetFloatBounds:)),
		FxNotifyAPI_ParameterSetIntBoundsName:  NSStringFromSelector(@selector(extAPIParameterSetIntBounds:)),
		FxNotifyAPI_ParameterGetMenuName:  NSStringFromSelector(@selector(extAPIParameterGetMenu:)),
		FxNotifyAPI_ParameterSetMenuPreName:  NSStringFromSelector(@selector(extAPIParameterSetMenuPre:)),
		FxNotifyAPI_ParameterSetMenuName:  NSStringFromSelector(@selector(extAPIParameterSetMenu:)),
		
	//	Get API
		FxNotifyAPI_ParameterGetFlagsPreName:  NSStringFromSelector(@selector(extAPIParameterGetFlagsPre:)),
		FxNotifyAPI_ParameterGetFlagsName:  NSStringFromSelector(@selector(extAPIParameterGetFlags:)),
		FxNotifyAPI_ParameterGetStringValueName:  NSStringFromSelector(@selector(extAPIParameterGetStringValue:)),
	
	//	Set API
		FxNotifyAPI_ParameterSetBoolName:  NSStringFromSelector(@selector(extAPIParameterSetBool:)),
		FxNotifyAPI_ParameterSetCustomValueName:  NSStringFromSelector(@selector(extAPIParameterSetCustomValue:)),
		FxNotifyAPI_ParameterSetFloatName:  NSStringFromSelector(@selector(extAPIParameterSetFloat:)),
		FxNotifyAPI_ParameterSetHistogramName:  NSStringFromSelector(@selector(extAPIParameterSetHistogram:)),
		FxNotifyAPI_ParameterSetIntName:  NSStringFromSelector(@selector(extAPIParameterSetInt:)),
		FxNotifyAPI_ParameterSetFlagsPreName:  NSStringFromSelector(@selector(extAPIParameterSetFlagsPre:)),
		FxNotifyAPI_ParameterSetFlagsName:  NSStringFromSelector(@selector(extAPIParameterSetFlags:)),
		FxNotifyAPI_ParameterSetPathIDName:  NSStringFromSelector(@selector(extAPIParameterSetPathID:)),
		FxNotifyAPI_ParameterSetRGBAName:  NSStringFromSelector(@selector(extAPIParameterSetRGBA:)),
		FxNotifyAPI_ParameterSetRGBName:  NSStringFromSelector(@selector(extAPIParameterSetRGB:)),
		FxNotifyAPI_ParameterSetStringValuePreName:  NSStringFromSelector(@selector(extAPIParameterSetStringValuePre:)),
		FxNotifyAPI_ParameterSetStringValueName:  NSStringFromSelector(@selector(extAPIParameterSetStringValue:)),
		FxNotifyAPI_ParameterSetXYName:  NSStringFromSelector(@selector(extAPIParameterSetXY:))
	};
	
	[methods enumerateKeysAndObjectsUsingBlock:^(NSString* notificationName, NSString* selectorString, BOOL *stop) {
		
		SEL selector = NSSelectorFromString(selectorString);
		if ([self respondsToSelector:selector]) {
			[effect.notifier addObserver:self selector:selector name:notificationName object:effect];
		}
	}];
	
	return YES;
}

@end


@implementation FxExtension
@end

