/*!
	@file       FxGripTimingAPI_v4.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTimingAPI_v4
	@abstract   The FxGrip wrapper for the host's FxTimingAPI_v4.
	@discussion Introduced in FxGrip 0.1.0. The wrapper mirrors the FxPlug 4 v4 timing protocol and
	            forwards each query to the host API. Every out-parameter query is guarded, so a
	            NULL pointer forwards nothing and leaves the caller's storage untouched. The class
	            mirrors the FxPlug 4 v4 protocol version.
*/

#ifndef FxGripTimingAPI_v4_h
#define FxGripTimingAPI_v4_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameterTagsAPI_v1.h"
#import "FxGripCommonAPI.h"

/*!
	@class		FxGripTimingAPI_v4
	@abstract	FxGrip's wrapper around the host FxTimingAPI_v4.
	@discussion	Introduced in FxGrip 0.1.0. The wrapper forwards frame, sample, effect, input,
				image-parameter, and timeline conversions to the host API, guarding each
				out-parameter against a NULL pointer.
*/
@interface FxGripTimingAPI_v4 : FxGripCommonAPI<FxTimingAPI_v4>

	/*! The wrapped host timing API. */
	@property (assign, readonly) id<FxTimingAPI_v4> _Nonnull api;

/*!
	@method		initWithAPI:effect:
	@abstract	Initializes the timing API wrapper.
	@param		api	The host timing API to wrap.
	@param		effect	The effect host the API queries.
*/
- (nullable instancetype)initWithAPI:(id<FxTimingAPI_v4> _Nullable)api effect:(nonnull id<FxGripEffectHost>)effect;

/*! The duration of a single frame. */
- (void)frameDuration:(CMTime*_Nullable)duration;
/*! The duration of a single sample. */
- (void)sampleDuration:(CMTime*_Nullable)duration;
/*! The effect's start time. */
- (void)startTimeForEffect:(CMTime*_Nullable)startTime;
/*! The effect's duration. */
- (void)durationTimeForEffect:(CMTime*_Nullable)duration;
/*! The start time of the input to the filter. */
- (void)startTimeOfInputToFilter:(CMTime*_Nullable)startTime;
/*! The duration of the input to the filter. */
- (void)durationTimeOfInputToFilter:(CMTime*_Nullable)duration;
/*! The start time of an image parameter's clip. */
- (void)startTime:(CMTime*_Nullable)startTime
 ofImageParameter:(UInt32)parameterID;
/*! The duration of an image parameter's clip. */
- (void)durationTime:(CMTime*_Nullable)duration
	ofImageParameter:(UInt32)parameterID;
/*! The in point of the effect's timeline. */
- (void)inPointTimeOfTimelineForEffect:(CMTime*_Nullable)inPoint;
/*! The out point of the effect's timeline. */
- (void)outPointTimeOfTimelineForEffect:(CMTime*_Nullable)outPoint;
/*! Converts an input time to the timeline's time base. */
- (void)timelineTime:(CMTime*_Nullable)timelineTime
	   fromInputTime:(CMTime)time;

/*! Converts an image parameter's time to the timeline's time base. */
- (void)timelineTime:(CMTime*_Nullable)timelineTime
	   fromImageTime:(CMTime)time
	  forParameterID:(UInt32)parameterID;

/*! Converts a timeline time to the input's time base. */
- (void)inputTime:(CMTime*_Nullable)inputTime
 fromTimelineTime:(CMTime)time;

/*! Converts a timeline time to an image parameter's time base. */
- (void)imageTime:(CMTime*_Nullable)imageTime
   forParameterID:(UInt32)parameterID
 fromTimelineTime:(CMTime)time;

/*! The field order of the input to the filter. */
- (FxFieldOrder)fieldOrderForInputToFilter:(id<FxTileableEffect>_Nonnull)filter;
/*! The timeline frame-rate numerator for the effect. */
- (NSUInteger)timelineFpsNumeratorForEffect:(id<FxTileableEffect>_Nonnull)effect;
/*! The timeline frame-rate denominator for the effect. */
- (NSUInteger)timelineFpsDenominatorForEffect:(id<FxTileableEffect>_Nonnull)effect;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

