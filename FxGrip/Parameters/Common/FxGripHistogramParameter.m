//
//  FxGripHistogramParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripHistogramParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
#import "NSCoder+FxPlug.h"

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

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	return [effect.apiManager.paramCreateAPIv5 addHistogramWithName: parameter.parameterName
														parameterID: parameter.parameterID
													 parameterFlags: parameter.parameterFlags];
}

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
