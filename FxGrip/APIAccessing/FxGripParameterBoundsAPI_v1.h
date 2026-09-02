//
//  FxGripParameterBoundsAPI_v1.h
//  FxGrip
//

#ifndef FxGripParameterBoundsAPI_v1_h
#define FxGripParameterBoundsAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import "FxGripCommonAPI.h"

/*!
	@protocol   FxParameterBoundsAPI_v1
	@abstract   Sets one edge of a Float or Int parameter's value or slider range, in the style
				of Apple's FxPlug APIs.
	@discussion Introduced in FxGrip 1.0. FxGrip's own API. Apple's dynamic-parameter API sets a
				parameter's minimum, maximum, and slider range together; these convenience methods
				change one edge and preserve the rest by reading the current range first.
*/
@protocol FxParameterBoundsAPI_v1 <NSObject>

// Float
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatMinimum:(double)min;
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatMaximum:(double)max;
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatMinimum:(double)min maximum:(double)max;
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatSliderMinimum:(double)sliderMin;
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatSliderMaximum:(double)sliderMax;
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatSliderMinimum:(double)sliderMin sliderMaximum:(double)sliderMax;

// Int
- (NSError* _Nullable)setParameter:(UInt32)parameterID intMinimum:(int)min;
- (NSError* _Nullable)setParameter:(UInt32)parameterID intMaximum:(int)max;
- (NSError* _Nullable)setParameter:(UInt32)parameterID intMinimum:(int)min maximum:(int)max;
- (NSError* _Nullable)setParameter:(UInt32)parameterID intSliderMinimum:(int)sliderMin;
- (NSError* _Nullable)setParameter:(UInt32)parameterID intSliderMaximum:(int)sliderMax;
- (NSError* _Nullable)setParameter:(UInt32)parameterID intSliderMinimum:(int)sliderMin sliderMaximum:(int)sliderMax;

@end


/*!
	@interface  FxGripParameterBoundsAPI_v1
	@abstract   FxGrip's implementation of FxParameterBoundsAPI_v1.
	@discussion Introduced in FxGrip 1.0. Reads the current range through Apple's
				FxDynamicParameterAPI_v3 and writes back the full range with one edge changed.
				Vended by FxGripAPIAccessing's parameterBoundsAPIv1. Previously these setters lived
				on the fabricated FxDynamicParameterAPI_v4.
*/
@interface FxGripParameterBoundsAPI_v1 : FxGripCommonAPI <FxParameterBoundsAPI_v1>

@property (assign, readonly) id<FxDynamicParameterAPI_v3> _Nullable api;

- (nullable instancetype)initWithAPI:(id<FxDynamicParameterAPI_v3> _Nullable)api
							  effect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif /* FxGripParameterBoundsAPI_v1_h */
