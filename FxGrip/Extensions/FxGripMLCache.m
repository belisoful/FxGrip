/*!
	@file       FxGripMLCache.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMLCache
	@abstract   Implements the per-frame inference cache extension.
	@discussion Introduced in FxGrip 0.1.0. The extension registers the hidden MLCache custom
	            parameter, resolves its FxGripFrameData from the document, and reattaches the project
	            media cache after each load.
*/

#import "FxGripMLCache.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripTileableEffect+Extensions.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTypes.h"
#import "FxGripParameterFlags.h"
#import "FxGripAPIAccessing.h"
#import "FxGripImageBuffer.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import "FxGrip_ARC.h"

/*!
	@abstract	The extension that owns an ML effect's per-frame inference cache.
	@discussion	Introduced in FxGrip 0.1.0. The frame data is created on demand and reloaded from the
				document when the effect is added.
*/
@implementation FxGripMLCache
{
	FxGripFrameData *_frameData;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_parameterID = kFxParameterId_MLCache;
	}
	return self;
}

- (NSSet *)dataClasses
{
	NSMutableSet *classes = [super.dataClasses mutableCopy];
	[classes addObject:FxGripFrameData.class];
	[classes addObject:FxGripImageBuffer.class];
	[classes unionSet:FxGripFrameData.classesForParameter.set];
	return classes;
}

- (FxGripFrameData *)frameData
{
	if (_frameData == nil) {
		_frameData = [FxGripFrameData.alloc init];
		[_frameData attachProjectMediaCacheForEffect:self.effect];
	}
	return _frameData;
}

/*!
	@method		extAddParameters:
	@abstract	Registers the hidden MLCache custom parameter.
	@discussion	Introduced in FxGrip 0.1.0. The parameter carries no state, is never presented or
				animated, and stays out of presets; its frame data is machine-local cache-backed. */
// The hidden MLCache parameter carries no state, is never presented or animated, and stays
// out of presets; its FrameData is machine-local cache-backed.
- (void)extAddParameters:(nonnull NSNotification*)notification
{
	NSDictionary *cacheParameter = @{
		kFxParameterProperty_Factory: self,
		kFxParameterProperty_Id: @(kFxParameterId_MLCache),
		kFxParameterProperty_Name: @"ML Cache",
		kFxParameterProperty_Type: kFxParameterType_Custom,
		kFxParameterProperty_Flags: @[kParameterFlagString_DONT_DISPLAY, kParameterFlagString_HIDDEN,
									  kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOVALUE,
									  kParameterFlagString_NO_DEBUG, kParameterFlagString_NO_STATE]
	};
	[notification.userInfo.fxEffectParameters addObject:[cacheParameter mutableCopy]];
}

/*!
	@method		extAddedToDocument:
	@abstract	Loads the cached frame data from the document and reattaches the media cache.
	@discussion	Introduced in FxGrip 0.1.0. The cache is transient, so it is re-resolved after every
				document load. */
- (void)extAddedToDocument:(nonnull NSNotification*)notification
{
	NSObject<NSCopying, NSSecureCoding> *object = nil;
	[self.effect.apiManager.paramGetAPIv6 getCustomParameterValue:&object
													fromParameter:self.parameterID
														   atTime:kCMTimeZero];
	if ([object isKindOfClass:FxGripFrameData.class]) {
		_frameData = (FxGripFrameData*)object;
	} else if (_frameData == nil) {
		_frameData = [FxGripFrameData.alloc init];
	}
	// The cache is transient (never encoded), so re-resolve it after every document load.
	[_frameData attachProjectMediaCacheForEffect:self.effect];
}

@end


/*!
	@abstract	The effect-side accessors for the ML cache extension and its frame data.
	@discussion	Introduced in FxGrip 0.1.0. mlCacheData resolves the loaded extension's cache.
*/
@implementation FxGripTileableEffect (MLCache)

- (nullable FxGripFrameData *)mlCacheData
{
	FxGripMLCache *cache = (FxGripMLCache*)[self extensionForClass:FxGripMLCache.class];
	return cache.frameData;
}

- (BOOL)hasMLCache
{
	return [self extensionForClass:FxGripMLCache.class] != nil;
}

- (nonnull FxGripMLCache *)newMLCacheExtension
{
	return [FxGripMLCache.alloc init];
}

@end
