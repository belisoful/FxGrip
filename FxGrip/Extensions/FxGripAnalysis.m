//
//  FxGripAnalysis.m
//  FxGrip
//
//  Copyright © 2026 Belisoful All rights reserved.
//

#import "FxGripAnalysis.h"
#import "FxTileableEffectBase+Notifications.h"
#import "FxTileableEffectBase+Extensions.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxGripTypes.h"
#import "FxParameterFlags.h"
#import "FxGripAPIAccessing.h"
#import "FxGripImageBuffer.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import "FxGrip_ARC.h"

@implementation FxGripAnalysis
{
	FxGripFrameData *_frameData;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_parameterID = kFxParameterId_AnalysisData;
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

// The hidden AnalysisData parameter carries no state, is never presented or animated, and
// stays out of presets; its FrameData is machine-local cache-backed.
- (void)extAddParameters:(nonnull NSNotification*)notification
{
	NSDictionary *analysisParameter = @{
		kFxParameterProperty_Factory: self,
		kFxParameterProperty_Id: @(kFxParameterId_AnalysisData),
		kFxParameterProperty_Name: @"Analysis Data",
		kFxParameterProperty_Type: kFxParameterType_Custom,
		kFxParameterProperty_Flags: @[kParameterFlagString_DONT_DISPLAY, kParameterFlagString_HIDDEN,
									  kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOVALUE,
									  kParameterFlagString_NO_DEBUG, kParameterFlagString_NO_STATE]
	};
	[notification.userInfo.fxEffectParameters addObject:[analysisParameter mutableCopy]];
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


@implementation FxTileableEffectBase (Analysis)

- (nullable FxGripFrameData *)analysisData
{
	FxGripAnalysis *analysis = (FxGripAnalysis*)[self extensionForClass:FxGripAnalysis.class];
	return analysis.frameData;
}

- (BOOL)hasAnalysis
{
	return [self extensionForClass:FxGripAnalysis.class] != nil;
}

- (nonnull FxGripAnalysis *)newAnalysisExtension
{
	return [FxGripAnalysis.alloc init];
}

@end
