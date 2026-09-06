/*!
	@file       FxGripTimingAPI_v4.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTimingAPI_v4
	@abstract   Implements the timing wrapper over the host FxTimingAPI_v4.
	@discussion Introduced in FxGrip 0.1.0. Each out-parameter query forwards to the host API only
	            when the caller's pointer is non-NULL. The frame-rate, field-order, and conversion
	            queries forward directly.
*/

#import "FxGripTimingAPI_v4.h"
#import "FxGripTileableEffect.h"

/*!
	@abstract	FxGrip's wrapper around the host FxTimingAPI_v4.
	@discussion	Introduced in FxGrip 0.1.0. Forwards timing queries to the host API, guarding each
				out-parameter against a NULL pointer.
*/
@implementation FxGripTimingAPI_v4

#define hasMeta(returnValue) { if (!self.hostHasMeta) return (returnValue); }

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPI:(id<FxTimingAPI_v4> _Nullable)api
							  effect:(id<FxGripEffectHost>)effect
{
	self = [super initWithEffect:effect];
	
	if (self != nil)
	{
		_api = api;
	}
	return self;
}

- (void)frameDuration:(CMTime*)duration
{
	if (duration)
		[_api frameDuration:duration];
}

- (void)sampleDuration:(CMTime*)duration
{
	if (duration)
		[_api sampleDuration:duration];
}

- (void)startTimeForEffect:(CMTime*)startTime
{
	if (startTime)
		[_api startTimeForEffect:startTime];
}


- (void)durationTimeForEffect:(CMTime*)duration
{
	if (duration)
		[_api durationTimeForEffect:duration];
}


- (void)startTimeOfInputToFilter:(CMTime*)startTime
{
	if (startTime)
		[_api startTimeOfInputToFilter:startTime];
}


- (void)durationTimeOfInputToFilter:(CMTime*)duration
{
	if (duration)
		[_api durationTimeOfInputToFilter:duration];
}


- (void)startTime:(CMTime*)startTime
 ofImageParameter:(UInt32)parameterID
{
	if (startTime)
		[_api startTime:startTime ofImageParameter:parameterID];
}


- (void)durationTime:(CMTime*)duration
	ofImageParameter:(UInt32)parameterID
{
	if (duration)
		[_api durationTime:duration ofImageParameter:parameterID];
}


- (void)inPointTimeOfTimelineForEffect:(CMTime*)inPoint
{
	if (inPoint)
		[_api inPointTimeOfTimelineForEffect:inPoint];
}


- (void)outPointTimeOfTimelineForEffect:(CMTime*)outPoint
{
	if (outPoint)
		[_api outPointTimeOfTimelineForEffect:outPoint];
}


- (void)timelineTime:(CMTime*)timelineTime
	   fromInputTime:(CMTime)time
{
	if (timelineTime)
		[_api timelineTime:timelineTime fromInputTime:time];
}


- (void)timelineTime:(CMTime*)timelineTime
	   fromImageTime:(CMTime)time
	  forParameterID:(UInt32)parameterID
{
	if (timelineTime)
		[_api timelineTime:timelineTime
			 fromImageTime:time
			forParameterID:parameterID];
}


- (void)inputTime:(CMTime*)inputTime
 fromTimelineTime:(CMTime)time
{
	if (inputTime)
  	 [_api inputTime:inputTime fromTimelineTime:time];
}


- (void)imageTime:(CMTime*)imageTime
   forParameterID:(UInt32)parameterID
 fromTimelineTime:(CMTime)time
{
	if (imageTime)
		[_api imageTime:imageTime forParameterID:parameterID fromTimelineTime:time];
}


- (FxFieldOrder)fieldOrderForInputToFilter:(id<FxTileableEffect>)filter
{
	return [_api fieldOrderForInputToFilter:filter];
}


- (NSUInteger)timelineFpsNumeratorForEffect:(id<FxTileableEffect>)effect
{
	return [_api timelineFpsNumeratorForEffect:effect];
}


- (NSUInteger)timelineFpsDenominatorForEffect:(id<FxTileableEffect>)effect
{
	return [_api timelineFpsDenominatorForEffect:effect];
}


@end
