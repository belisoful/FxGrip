/*!
	@file       FxGripHistogramParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripHistogramParameter
	@abstract   Implements the parameter model for a host histogram parameter.
	@discussion Introduced in FxGrip 0.1.0. The class registers a histogram parameter through the parameter-creation API and reads its per-channel levels at a render time. A per-channel bitmask records which channels read successfully.
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
{
	FxGripHistogram	_histogram;
	NSUInteger		_goodBits;
	NSUInteger		_errorBits;
}

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
	@method		valueAtTime:
	@abstract	Reads the histogram levels at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		A pointer to the sampled histogram owned by the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The method reads five channels and records the success or failure of each in a per-channel bitmask. */
-(FxGripHistogram*_Nullable) valueAtTime:(CMTime)renderTime
{
	static const FxGripHistogram defaultHistogram = kZeroHistogram;
	_errorBits = _goodBits = 0;
	
	_histogram = defaultHistogram;
	
	for(int i = 0; i < 5; i++) {
		if([self.effect.apiManager.paramGetAPIv6 getHistogramBlackIn:&_histogram.component[i].blackIn
								   BlackOut:&_histogram.component[i].blackOut
									WhiteIn:&_histogram.component[i].whiteIn
								   WhiteOut:&_histogram.component[i].whiteOut
									  Gamma:&_histogram.component[i].gamma
								 forChannel:i fromParameter:self.parameterID atTime:renderTime]) {
			_histogram.component[i].channel = i;
			_goodBits |= 1 << i;
		} else {
			_errorBits |= 1 << i;
		}
	}
	
	return &_histogram;
}


/*!
	@method		encodeWithCoder:
	@abstract	Encodes the histogram at the coder's render time into the plugin-state coder.
	@param		coder	The coder that receives the histogram.
	@discussion	Introduced in FxGrip 0.1.0. The histogram encodes only when the coder is an FxPlug plugin-state encoder and every channel read successfully. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];

	if (coder.isFxPluginStateEncoder) {
		if (!_errorBits) {
			FxGripHistogram *histogram = [self valueAtTime:coder.renderTime];
		 [coder encodeBytes:(void*)histogram length:sizeof(FxGripHistogram) atIndex:self.parameterID];
	 }
	} else {
		// encode meta
	}
}


@end
