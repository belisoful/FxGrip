/*!
	@file       FxGripPointParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPointParameter
	@abstract   Implements the parameter model for a host point parameter.
	@discussion Introduced in FxGrip 0.1.0. The class registers a point parameter through the parameter-creation API and reads and writes its X and Y at a render time. It parses the declaration's FxGripPointOptions at initialization for the on-screen control.
*/

#import "FxGripPointParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "NSCoder+FxPlug.h"

/*!
	@abstract	The parameter model for a host point parameter.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a point parameter, reads and writes its X and Y at a render time, and encodes the point into the plugin-state coder.
*/
@implementation FxGripPointParameter

@synthesize options = _options;

/*!
	@method		initWithDictionary:effect:
	@abstract	Initializes the parameter and parses its on-screen control options.
	@param		dictionary	The parameter configuration dictionary.
	@param		effect		The host that owns the parameter. */
-(instancetype _Nullable) initWithDictionary:(NSDictionary*)dictionary effect:(nonnull id<FxGripEffectHost>)effect
{
	self = [super initWithDictionary:dictionary effect:effect];
	if (self != nil) {
		_options = [FxGripPointOptions.alloc initWithConfiguration:dictionary];
	}
	return self;
}

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Point;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Point;
}


/*!
	@method		addParameter:toEffect:
	@abstract	Registers the point parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default X and Y are 0.5. The default reader accepts the dictionary, array, and string default shapes. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	double defaultXValue = 0.5, defaultYValue = 0.5;
	// parameterDefaultX/Y read the parameter record and accept the dictionary, array,
	// and string default shapes.
	if (parameter.parameterDefaultValue != nil || parameter[kFxParameterProperty_X] != nil || parameter[kFxParameterProperty_Y] != nil) {
		defaultXValue = parameter.parameterDefaultX.doubleValue;
		defaultYValue = parameter.parameterDefaultY.doubleValue;
	}
	return [effect.apiManager.paramCreateAPIv5 addPointParameterWithName: parameter.parameterName
																  parameterID: parameter.parameterID
																	 defaultX: defaultXValue
																	 defaultY: defaultYValue
															   parameterFlags: parameter.parameterFlags];
}


/*!
	@method		valueAtTime:
	@abstract	Reads the point at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The point, or the origin when FxParameterRetrievalAPI_v6 is unavailable.
	@discussion	Introduced in FxGrip 0.1.0. A retrieval failure sets the parameter's error. */
-(FxGripPoint) valueAtTime:(CMTime)renderTime
{
	FxGripPoint point = {0.0, 0.0};
	if(![self.effect.apiManager.paramGetAPIv6 getXValue:&point.x YValue:&point.y fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxGripPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return point;
}


/*!
	@method		setValue:atTime:
	@abstract	Writes the point at a time.
	@param		value	The point to set. A NULL value performs no write.
	@param		time	The time to set the point at. */
- (void)setValue:(FxGripPoint*_Nullable)value atTime:(CMTime)time
{
	if (!value) {
		return;
	}
	[self.effect.apiManager.paramSetAPIv5 setXValue:value->x YValue:value->y toParameter:self.parameterID atTime:time];
}

/*! @abstract Writes the X and Y components at a time through FxParameterSettingAPI_v5. */
- (void)setXValue:(double)xValue YValue:(double)yValue atTime:(CMTime)time
{
	[self.effect.apiManager.paramSetAPIv5 setXValue:xValue YValue:yValue toParameter:self.parameterID atTime:time];
}


/*!
	@method		encodeWithCoder:
	@abstract	Encodes the point at the coder's render time into the plugin-state coder.
	@param		coder	The coder that receives the point.
	@discussion	Introduced in FxGrip 0.1.0. The point encodes only when the coder is an FxPlug plugin-state encoder. */
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
