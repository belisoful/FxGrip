/*!
	@file       FxGripHistogramParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripHistogramParameter
	@abstract   Implements the parameter model for a host histogram parameter.
	@discussion Introduced in FxGrip 0.1.0. The class registers a histogram parameter through the parameter-creation API and reads its per-channel levels at a render time. Each read fills storage the caller owns, so concurrent plugin-state calls do not share a histogram.
*/

#import "FxGripHistogramParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "NSCoder+FxPlug.h"

/*!
	@abstract	The parameter model for a host histogram parameter.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a histogram parameter, samples its five channels at a render time, and encodes the histogram into the plugin-state coder.
*/
@implementation FxGripHistogramParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Histogram;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Histogram;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Registers the histogram parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	return [effect.apiManager.paramCreateAPIv5 addHistogramWithName: parameter.parameterName
														parameterID: parameter.parameterID
													 parameterFlags: parameter.parameterFlags];
}

/*!
	@method		getHistogram:atTime:
	@abstract	Reads the histogram levels at a render time into a caller-supplied histogram.
	@param		histogram	The histogram that receives the levels.
	@param		renderTime	The time to sample the parameter at.
	@return		YES when every channel reads.
	@discussion	Introduced in FxGrip 0.1.0. The method starts from kZeroHistogram, so a channel the host refuses keeps the default levels. The method writes only to the supplied histogram and is safe to call concurrently. */
- (BOOL)getHistogram:(FxGripHistogram *_Nonnull)histogram atTime:(CMTime)renderTime
{
	static const FxGripHistogram defaultHistogram = kZeroHistogram;
	*histogram = defaultHistogram;

	BOOL everyChannelRead = YES;
	for (int i = 0; i < 5; i++) {
		FxGripChannelHistogram *channel = &histogram->component[i];
		if ([self.effect.apiManager.paramGetAPIv6 getHistogramBlackIn:&channel->blackIn
															 BlackOut:&channel->blackOut
															  WhiteIn:&channel->whiteIn
															 WhiteOut:&channel->whiteOut
																Gamma:&channel->gamma
														   forChannel:i
														fromParameter:self.parameterID
															   atTime:renderTime]) {
			channel->channel = i;
		} else {
			everyChannelRead = NO;
		}
	}
	return everyChannelRead;
}

/*!
	@method		valueAtTime:
	@abstract	Reads the histogram levels at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		A pointer to the sampled histogram, valid until the enclosing autorelease pool drains.
	@discussion	Introduced in FxGrip 0.1.0. The histogram lives in an autoreleased buffer, so the method is safe to call concurrently. A channel the host refuses keeps the kZeroHistogram levels. Use getHistogram:atTime: to learn whether every channel read. */
-(FxGripHistogram*_Nullable) valueAtTime:(CMTime)renderTime
{
	// The autorelease pool owns the buffer for the lifetime of the returned pointer.
	__autoreleasing NSMutableData *buffer = [NSMutableData dataWithLength:sizeof(FxGripHistogram)];
	FxGripHistogram *histogram = buffer.mutableBytes;
	[self getHistogram:histogram atTime:renderTime];
	return histogram;
}

/*!
	@method		encodeWithCoder:
	@abstract	Encodes the histogram at the coder's render time into the plugin-state coder.
	@param		coder	The coder that receives the histogram.
	@discussion	Introduced in FxGrip 0.1.0. The histogram encodes only when the coder is an FxPlug plugin-state encoder and every channel of this read succeeds. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];

	if (coder.isFxPluginStateEncoder) {
		FxGripHistogram histogram;
		if ([self getHistogram:&histogram atTime:coder.renderTime]) {
			[coder encodeBytes:(void*)&histogram length:sizeof(FxGripHistogram) atIndex:self.parameterID];
		}
	} else {
		// encode meta
	}
}


@end
