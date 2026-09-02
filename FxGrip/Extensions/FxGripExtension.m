//
//  FxGripExtension.m
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Extensions.h"
#import "FxGripTileableEffect+Notifications.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxParameterExtension.h"
#import "FxGripParameterUtility.h"


#pragma mark -
#pragma mark FxGripExtension Implementation

const NSInteger FxGripExtensionDefaultPriority = 10;


@implementation FxGripExtensionBase

@synthesize extActive = _extActive;
@synthesize effect = _effect;
@synthesize extKey = _extKey;
@synthesize extKeyIndex = _extKeyIndex;
@synthesize extIncludeWhenDisabled = _extIncludeWhenDisabled;
@synthesize extDefaultPriority = _extDefaultPriority;
@synthesize extIndividuate = _extIndividuate;

- (nullable id)init
{
	self = [super init];
	if (self) {
		_extActive = YES;
		_effect = NULL;
		_extKey = self.className;
		_extKeyIndex = -1;
		_extIncludeWhenDisabled = NO;
		_extDefaultPriority = FxGripExtensionDefaultPriority;
		_extIndividuate = NO;
	}
	return self;
}

- (void)setExtActive:(BOOL)active
{
	if (self.effect.addedToDocument) {
		NSLog(@"Error: cannot set extension active after being added to the document. Set this before FxTileableEffect::pluginInstanceAddedToDocument is signaled");
		return;
	}
	_extActive = active;
}

// -20 is the highest priority, 10 is normal, 20 is lowest priority
//	other values are OK, but not officially supported and may lead to unknown behavior.
- (NSInteger)ncPriority:(nullable NSNotificationName)aName
{
	return _extDefaultPriority;
}



- (NSUInteger)extensionCount
{
	return [self.effect.effectBase extensionsForClass:self.class].count;
}


/*!
	Applies the load index to the extension key. Every instance after the first gets the
	index appended so instances of one class never share a key; `extIndividuate` forces
	the suffix for the first instance too.
*/
- (void)applyKeyIndex:(NSInteger)index
{
	_extKeyIndex = index;
	if (index > 0 || self.extIndividuate) {
		_extKey = [_extKey stringByAppendingFormat:@"%ld", (long)index];
	}
}


- (BOOL)extLoadWithIndex:(NSInteger)index
{
	[self applyKeyIndex:index];
	return self.extIncludeWhenDisabled;
}


- (BOOL)extLoadWithEffect:(nonnull id<FxGripTileableEffect>)effect index:(NSInteger)index
{
	[self applyKeyIndex:index];
	return [self extLoadWithEffect:effect];
}

- (BOOL)extLoadWithEffect:(nonnull id<FxGripTileableEffect>)effect
{
	_effect = effect;
	
	if (!self.extActive) {
		return self.extIncludeWhenDisabled;
	}
	
	NSDictionary *methods = @{
		
	//Effect Notifications
		FxGripTileableEffectInitName: NSStringFromSelector(@selector(extInit:)),
		
		FxGripTileableEffectPropertiesName: NSStringFromSelector(@selector(extProperties:)),
		FxGripTileableEffectAddParametersName: NSStringFromSelector(@selector(extAddParameters:)),
		FxGripTileableEffectFinishInitialSetupName: NSStringFromSelector(@selector(extFinishInitialSetup:)),
		FxGripTileableEffectAddedToDocumentName: NSStringFromSelector(@selector(extAddedToDocument:)),
		
		FxGripTileableEffectParameterChangedName: NSStringFromSelector(@selector(extParameterChanged:)),
		FxGripTileableEffectParameterClickedName: NSStringFromSelector(@selector(extParameterClicked:)),
		FxGripTileableEffectFlushName: NSStringFromSelector(@selector(extFlush:)),
		
		FxGripTileableEffectPluginStateName: NSStringFromSelector(@selector(extPluginState:)),
		FxGripTileableEffectDestinationImageRectName: NSStringFromSelector(@selector(extDestinationRect:)),
		FxGripTileableEffectSourceTileRectName: NSStringFromSelector(@selector(extSourceRect:)),
		FxGripTileableEffectScheduleInputsName: NSStringFromSelector(@selector(extSchedule:)),
		FxGripTileableEffectRenderDestinationImageName: NSStringFromSelector(@selector(extRenderDestinationImage:)),
		
		FxGripTileableEffectRemovedFromDocumentName: NSStringFromSelector(@selector(extRemovedFromDocument:)),
		FxGripTileableEffectUnloadName: NSStringFromSelector(@selector(extUnload:)),
		
		
	//API Notifications
	//	Creation
		FxGripNotifyAPI_ParameterAddPreName:  NSStringFromSelector(@selector(extAPIParameterAddPre:)),
		FxGripNotifyAPI_ParameterAddName:  NSStringFromSelector(@selector(extAPIParameterAdd:)),
		FxGripNotifyAPI_ParameterStartGroupName:  NSStringFromSelector(@selector(extAPIParameterStartGroup:)),
		FxGripNotifyAPI_ParameterEndGroupName:  NSStringFromSelector(@selector(extAPIParameterEndGroup:)),
		
	//	Dynamic
		FxGripNotifyAPI_ParameterRemoveName:  NSStringFromSelector(@selector(extAPIParameterRemove:)),
		FxGripNotifyAPI_ParameterGetNameName:  NSStringFromSelector(@selector(extAPIParameterGetName:)),
		FxGripNotifyAPI_ParameterSetNamePreName: NSStringFromSelector(@selector(extAPIParameterSetNamePre:)),
		FxGripNotifyAPI_ParameterSetNameName:  NSStringFromSelector(@selector(extAPIParameterSetName:)),
		FxGripNotifyAPI_ParameterGetTypeName:  NSStringFromSelector(@selector(extAPIParameterGetType:)),
	
		FxGripNotifyAPI_ParameterSetFloatBoundsName:  NSStringFromSelector(@selector(extAPIParameterSetFloatBounds:)),
		FxGripNotifyAPI_ParameterSetIntBoundsName:  NSStringFromSelector(@selector(extAPIParameterSetIntBounds:)),
		FxGripNotifyAPI_ParameterGetMenuName:  NSStringFromSelector(@selector(extAPIParameterGetMenu:)),
		FxGripNotifyAPI_ParameterSetMenuPreName:  NSStringFromSelector(@selector(extAPIParameterSetMenuPre:)),
		FxGripNotifyAPI_ParameterSetMenuName:  NSStringFromSelector(@selector(extAPIParameterSetMenu:)),
		
	//	Get API
		FxGripNotifyAPI_ParameterGetFlagsPreName:  NSStringFromSelector(@selector(extAPIParameterGetFlagsPre:)),
		FxGripNotifyAPI_ParameterGetFlagsName:  NSStringFromSelector(@selector(extAPIParameterGetFlags:)),
		FxGripNotifyAPI_ParameterGetStringValueName:  NSStringFromSelector(@selector(extAPIParameterGetStringValue:)),
	
	//	Set API
		FxGripNotifyAPI_ParameterSetBoolName:  NSStringFromSelector(@selector(extAPIParameterSetBool:)),
		FxGripNotifyAPI_ParameterSetCustomValueName:  NSStringFromSelector(@selector(extAPIParameterSetCustomValue:)),
		FxGripNotifyAPI_ParameterSetFloatName:  NSStringFromSelector(@selector(extAPIParameterSetFloat:)),
		FxGripNotifyAPI_ParameterSetHistogramName:  NSStringFromSelector(@selector(extAPIParameterSetHistogram:)),
		FxGripNotifyAPI_ParameterSetIntName:  NSStringFromSelector(@selector(extAPIParameterSetInt:)),
		FxGripNotifyAPI_ParameterSetFlagsPreName:  NSStringFromSelector(@selector(extAPIParameterSetFlagsPre:)),
		FxGripNotifyAPI_ParameterSetFlagsName:  NSStringFromSelector(@selector(extAPIParameterSetFlags:)),
		FxGripNotifyAPI_ParameterSetPathIDName:  NSStringFromSelector(@selector(extAPIParameterSetPathID:)),
		FxGripNotifyAPI_ParameterSetRGBAName:  NSStringFromSelector(@selector(extAPIParameterSetRGBA:)),
		FxGripNotifyAPI_ParameterSetRGBName:  NSStringFromSelector(@selector(extAPIParameterSetRGB:)),
		FxGripNotifyAPI_ParameterSetStringValuePreName:  NSStringFromSelector(@selector(extAPIParameterSetStringValuePre:)),
		FxGripNotifyAPI_ParameterSetStringValueName:  NSStringFromSelector(@selector(extAPIParameterSetStringValue:)),
		FxGripNotifyAPI_ParameterSetXYName:  NSStringFromSelector(@selector(extAPIParameterSetXY:))
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


@implementation FxGripExtension
@end

