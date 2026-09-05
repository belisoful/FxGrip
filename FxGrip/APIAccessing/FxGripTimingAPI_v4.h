//
//  FxGripTimingAPI_v4.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripTimingAPI_v4_h
#define FxGripTimingAPI_v4_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameterTagsAPI_v1.h"
#import "FxGripCommonAPI.h"

/*!
	@interface  FxGripParameterTagsAPI_v1
	@abstract   Allows your plugin to create parameters on-the-fly
	@discussion With this API your plugin can create and remove parameters outside of its
				-addParameters method. It can also get and set various properties of parameters
				during run-time, as well, such as the minimum and maximum allowable values.
				NOTE: You should only implement this protocol in plug-ins that use FxPlug 4
				or later. It will not be called in plug-ins that are written with FxPlug 2 or 3.
*/
@interface FxGripTimingAPI_v4 : FxGripCommonAPI<FxTimingAPI_v4>

	@property (assign, readonly) id<FxTimingAPI_v4> _Nonnull api;

- (nullable instancetype)initWithAPI:(id<FxTimingAPI_v4> _Nullable)api effect:(nonnull id<FxGripEffectHost>)effect;

- (void)frameDuration:(CMTime*_Nullable)duration;
- (void)sampleDuration:(CMTime*_Nullable)duration;
- (void)startTimeForEffect:(CMTime*_Nullable)startTime;
- (void)durationTimeForEffect:(CMTime*_Nullable)duration;
- (void)startTimeOfInputToFilter:(CMTime*_Nullable)startTime;
- (void)durationTimeOfInputToFilter:(CMTime*_Nullable)duration;
- (void)startTime:(CMTime*_Nullable)startTime
 ofImageParameter:(UInt32)parameterID;
- (void)durationTime:(CMTime*_Nullable)duration
	ofImageParameter:(UInt32)parameterID;
- (void)inPointTimeOfTimelineForEffect:(CMTime*_Nullable)inPoint;
- (void)outPointTimeOfTimelineForEffect:(CMTime*_Nullable)outPoint;
- (void)timelineTime:(CMTime*_Nullable)timelineTime
	   fromInputTime:(CMTime)time;

- (void)timelineTime:(CMTime*_Nullable)timelineTime
	   fromImageTime:(CMTime)time
	  forParameterID:(UInt32)parameterID;

- (void)inputTime:(CMTime*_Nullable)inputTime
 fromTimelineTime:(CMTime)time;

- (void)imageTime:(CMTime*_Nullable)imageTime
   forParameterID:(UInt32)parameterID
 fromTimelineTime:(CMTime)time;

- (FxFieldOrder)fieldOrderForInputToFilter:(id<FxTileableEffect>_Nonnull)filter;
- (NSUInteger)timelineFpsNumeratorForEffect:(id<FxTileableEffect>_Nonnull)effect;
- (NSUInteger)timelineFpsDenominatorForEffect:(id<FxTileableEffect>_Nonnull)effect;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

