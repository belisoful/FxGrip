/*!
	@file       FxGripAnalysis.m
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripAnalysis
	@abstract   Implements the per-frame analysis storage extension.
	@discussion Introduced in FxGrip 0.1.0. The extension registers the hidden AnalysisData custom
	            parameter, resolves its FxGripFrameData from the document, and attaches the project
	            media cache after each load so large per-frame records spill to disk.
*/

#import "FxGripAnalysis.h"
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
	@abstract	The extension that owns the effect's per-frame analysis storage.
	@discussion	Introduced in FxGrip 0.1.0. The frame data is created on demand and reloaded from the
				document when the effect is added.
*/
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

/*! @abstract The per-frame analysis store, created on demand with the project media cache attached. */
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
	@abstract	Registers the hidden AnalysisData custom parameter.
	@discussion	Introduced in FxGrip 0.1.0. The parameter carries no state, is never presented or
				animated, and stays out of presets; its frame data is machine-local cache-backed. */
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

/*!
	@method		extAddedToDocument:
	@abstract	Loads the stored frame data from the document and reattaches the media cache.
	@discussion	Introduced in FxGrip 0.1.0. The custom parameter value replaces the in-memory store
				when it decodes to an FxGripFrameData. The cache is transient, so it is re-resolved
				after every document load. */
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
	@abstract	The effect-side accessors for the analysis extension and its frame data.
	@discussion	Introduced in FxGrip 0.1.0. analysisData resolves the loaded extension's store.
*/
@implementation FxGripTileableEffect (Analysis)

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
