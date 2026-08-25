//
//  FxGripMLCache.m
//  FxGrip
//

#import "FxGripMLCache.h"
#import "FxTileableEffectBase+Notifications.h"
#import "FxTileableEffectBase+Extensions.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxGripTypes.h"
#import "FxParameterFlags.h"
#import "FxGripAPIAccessing.h"
#import "FxGripImageBuffer.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import "FxGrip_ARC.h"

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


@implementation FxTileableEffectBase (MLCache)

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
