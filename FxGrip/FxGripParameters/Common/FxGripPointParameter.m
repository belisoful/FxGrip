//
//  FxGripPointParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripPointParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
#import "NSCoder+FxPlug.h"

@implementation FxGripPointParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Point;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Point;
}


+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect
{
	double defaultXValue = 0.5, defaultYValue = 0.5;
	NSDictionary *pointDict = parameter.parameterDefaultValue;
	if (pointDict) {
		NSNumber *defaultValueNumber = pointDict.parameterDefaultX;
		if (defaultValueNumber != nil) {
			defaultXValue = defaultValueNumber.doubleValue;
		}
		defaultValueNumber = pointDict.parameterDefaultY;
		if (defaultValueNumber != nil) {
			defaultYValue = defaultValueNumber.doubleValue;
		}
	}
	return [effect.apiManager.paramCreateAPIv5 addPointParameterWithName: parameter.parameterName
																  parameterID: parameter.parameterID
																	 defaultX: defaultXValue
																	 defaultY: defaultYValue
															   parameterFlags: parameter.parameterFlags];
}


-(FxGripPoint) valueAtTime:(CMTime)renderTime
{
	FxGripPoint point = {0.0, 0.0};
	if(![self.effect.apiManager.paramGetAPIv6 getXValue:&point.x YValue:&point.y fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return point;
}


- (void)setValue:(FxGripPoint*_Nullable)value atTime:(CMTime)time
{
	if (!value) {
		return;
	}
	[self.effect.apiManager.paramSetAPIv5 setXValue:value->x YValue:value->y toParameter:self.parameterID atTime:time];
}

- (void)setXValue:(double)xValue YValue:(double)yValue atTime:(CMTime)time
{
	[self.effect.apiManager.paramSetAPIv5 setXValue:xValue YValue:yValue toParameter:self.parameterID atTime:time];
}


- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];
	
	if (coder.isFxPluginStateEncoder) {
		FxGripPoint point = [self valueAtTime:coder.renderTime];
		[coder encodeBytes:(void*)&point length:sizeof(point) atIndex:self.parameterID];
	} else {
		// encode meta
	}
}

@end
