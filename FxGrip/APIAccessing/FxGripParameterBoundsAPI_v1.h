/*!
	@file       FxGripParameterBoundsAPI_v1.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterBoundsAPI_v1
	@abstract   Sets one edge of a Float or Int parameter's value or slider range.
	@discussion Introduced in FxGrip 0.1.0. The API is FxGrip's own. Apple's dynamic-parameter API
	            sets a parameter's minimum, maximum, and slider range together. These convenience
	            methods change one edge and preserve the rest by reading the current range first.
*/

#ifndef FxGripParameterBoundsAPI_v1_h
#define FxGripParameterBoundsAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripCommonAPI.h>

/*!
	@protocol   FxGripParameterBoundsAPI_v1
	@abstract   Sets one edge of a Float or Int parameter's value or slider range, in the style
				of Apple's FxPlug APIs.
	@discussion Introduced in FxGrip 0.1.0. FxGrip's own API. Apple's dynamic-parameter API sets a
				parameter's minimum, maximum, and slider range together; these convenience methods
				change one edge and preserve the rest by reading the current range first.
*/
@protocol FxGripParameterBoundsAPI_v1 <NSObject>

// Float
/*! Sets a Float parameter's minimum, preserving its maximum. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatMinimum:(double)min;
/*! Sets a Float parameter's maximum, preserving its minimum. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatMaximum:(double)max;
/*! Sets both edges of a Float parameter's value range. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatMinimum:(double)min maximum:(double)max;
/*! Sets the left end of a Float parameter's slider track, preserving the right. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatSliderMinimum:(double)sliderMin;
/*! Sets the right end of a Float parameter's slider track, preserving the left. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatSliderMaximum:(double)sliderMax;
/*! Sets both ends of a Float parameter's slider track. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID floatSliderMinimum:(double)sliderMin sliderMaximum:(double)sliderMax;

// Int
/*! Sets an Int parameter's minimum, preserving its maximum. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID intMinimum:(int)min;
/*! Sets an Int parameter's maximum, preserving its minimum. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID intMaximum:(int)max;
/*! Sets both edges of an Int parameter's value range. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID intMinimum:(int)min maximum:(int)max;
/*! Sets the left end of an Int parameter's slider track, preserving the right. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID intSliderMinimum:(int)sliderMin;
/*! Sets the right end of an Int parameter's slider track, preserving the left. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID intSliderMaximum:(int)sliderMax;
/*! Sets both ends of an Int parameter's slider track. Answers the error the host reported, or nil. */
- (NSError* _Nullable)setParameter:(UInt32)parameterID intSliderMinimum:(int)sliderMin sliderMaximum:(int)sliderMax;

@end


/*!
	@interface  FxGripParameterBoundsAPI_v1
	@abstract   FxGrip's implementation of FxGripParameterBoundsAPI_v1.
	@discussion Introduced in FxGrip 0.1.0. Reads the current range through Apple's
				FxDynamicParameterAPI_v3 and writes back the full range with one edge changed.
				Vended by FxGripAPIAccessing's parameterBoundsAPIv1. Previously these setters lived
				on the fabricated FxGripDynamicParameterAPI_v4.
*/
@interface FxGripParameterBoundsAPI_v1 : FxGripCommonAPI <FxGripParameterBoundsAPI_v1>

/*! The host dynamic-parameter API the setters read the current range from and write back to. */
@property (assign, readonly) id<FxDynamicParameterAPI_v3> _Nullable api;

/*!
	@method		initWithAPI:effect:
	@abstract	Wraps a host dynamic-parameter API for an effect.
	@param		api		The host's FxDynamicParameterAPI_v3, or nil when the host vends none.
	@param		effect	The effect whose parameters the bounds apply to.
	@return		The bounds API, or nil when it cannot be built.
*/
- (nullable instancetype)initWithAPI:(id<FxDynamicParameterAPI_v3> _Nullable)api
							  effect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif /* FxGripParameterBoundsAPI_v1_h */
