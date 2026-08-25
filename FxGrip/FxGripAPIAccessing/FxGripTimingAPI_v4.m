//
//  MasterFXAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripTimingAPI_v4.h"
#import "FxTileableEffectBase.h"

@implementation FxGripTimingAPI_v4

#define hasMeta(returnValue) { if (!FxGripHostHasMeta(_effect)) return (returnValue); }

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
