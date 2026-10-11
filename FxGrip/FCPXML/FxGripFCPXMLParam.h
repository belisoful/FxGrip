/*!
	@file       FxGripFCPXMLParam.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLParam
	@abstract   The `param` element, its keyframe animation, and its fades.
	@discussion Introduced in FxGrip 0.1.0. A `param` carries one parameter of an effect,
	            adjustment, or text style: a `name`, an optional `key` that identifies it
	            independently of localization, a `value`, and an optional `keyframeAnimation` of
	            `keyframe` elements. `fadeIn` and `fadeOut` animate a parameter from and to its
	            minimum. A `param` may nest `param` children.
*/

#ifndef FxGripFCPXMLParam_h
#define FxGripFCPXMLParam_h

#import <FxGrip/FxGripFCPXMLElement.h>

NS_ASSUME_NONNULL_BEGIN

/*! The `interp` value for a linear segment. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLKeyframeInterpolationLinear;
/*! The `interp` value for an eased segment. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLKeyframeInterpolationEase;
/*! The `interp` value for an ease-in segment. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLKeyframeInterpolationEaseIn;
/*! The `interp` value for an ease-out segment. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLKeyframeInterpolationEaseOut;
/*! The `curve` value for a value that changes linearly through the keyframe. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLKeyframeCurveLinear;
/*! The `curve` value for a value that changes smoothly through the keyframe. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLKeyframeCurveSmooth;

/*!
	@class      FxGripFCPXMLKeyframe
	@abstract   A `keyframe`: a value at a time on an animation curve.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLKeyframe : FxGripFCPXMLElement

/*! The keyframe time. */
@property (readwrite) CMTime time;
/*! The value at the time, in the parameter's encoding. */
@property (readwrite, copy, nullable) NSString *value;
/*! The auxiliary value, where the parameter kind carries one. */
@property (readwrite, copy, nullable) NSString *auxValue;
/*! The interpolation to the next keyframe; `linear` when absent. */
@property (readwrite, copy, nullable) NSString *interpolation;
/*! Whether the value changes smoothly through the keyframe; `smooth` when absent. */
@property (readwrite, copy, nullable) NSString *curve;
/*! The value as numbers, where it is a space-separated number list. */
@property (readonly, copy) NSArray<NSNumber *> *numericValue;

/*! A keyframe at a time with a value. */
+ (instancetype)keyframeAtTime:(CMTime)time value:(NSString *)value;

@end

/*!
	@class      FxGripFCPXMLKeyframeAnimation
	@abstract   A `keyframeAnimation`: the keyframes of one parameter.
	@discussion Introduced in FxGrip 0.1.0. Keyframes are kept in time order.
*/
@interface FxGripFCPXMLKeyframeAnimation : FxGripFCPXMLElement

/*! The keyframes, in time order. */
@property (readonly, copy) NSArray<FxGripFCPXMLKeyframe *> *keyframes;

/*! Inserts a keyframe in time order, replacing one at the same time. */
- (void)addKeyframe:(FxGripFCPXMLKeyframe *)keyframe;
/*! Adds a keyframe at a time with a value. */
- (FxGripFCPXMLKeyframe *)addKeyframeAtTime:(CMTime)time value:(NSString *)value;
/*! The keyframe at a time, or nil. */
- (nullable FxGripFCPXMLKeyframe *)keyframeAtTime:(CMTime)time;
/*! The last keyframe at or before a time, or nil. */
- (nullable FxGripFCPXMLKeyframe *)keyframeAtOrBeforeTime:(CMTime)time;
/*! The first keyframe at or after a time, or nil. */
- (nullable FxGripFCPXMLKeyframe *)keyframeAtOrAfterTime:(CMTime)time;
/*! Removes every keyframe. */
- (void)removeAllKeyframes;

@end

/*!
	@class      FxGripFCPXMLFade
	@abstract   A `fadeIn` or `fadeOut`.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLFade : FxGripFCPXMLElement

/*! The fade shape: `linear`, `easeIn`, `easeOut`, or `easeInOut`. */
@property (readwrite, copy, nullable) NSString *type;
/*! The fade duration. */
@property (readwrite) CMTime duration;
/*! YES for a `fadeIn`. */
@property (readonly) BOOL isFadeIn;

/*! A fade-in of a duration. */
+ (instancetype)fadeInWithDuration:(CMTime)duration;
/*! A fade-out of a duration. */
+ (instancetype)fadeOutWithDuration:(CMTime)duration;

@end

/*!
	@class      FxGripFCPXMLParam
	@abstract   A `param`: one parameter's value over time.
	@discussion Introduced in FxGrip 0.1.0. ``FxGripFCPXMLValue`` encodes and decodes the value
				strings for FxPlug parameter types.
*/
@interface FxGripFCPXMLParam : FxGripFCPXMLElement

/*! The parameter's display name. */
@property (readwrite, copy, nullable) NSString *paramName;
/*! The parameter key, which identifies it independently of its localized name. */
@property (readwrite, copy, nullable) NSString *key;
/*! The initial value. */
@property (readwrite, copy, nullable) NSString *value;
/*! The auxiliary value. */
@property (readwrite, copy, nullable) NSString *auxValue;
/*! YES unless `enabled="0"`. */
@property (readwrite) BOOL enabled;

/*! The keyframe animation, or nil. */
@property (readonly, nullable) FxGripFCPXMLKeyframeAnimation *keyframeAnimation;
/*! The fade-in, or nil. */
@property (readonly, nullable) FxGripFCPXMLFade *fadeIn;
/*! The fade-out, or nil. */
@property (readonly, nullable) FxGripFCPXMLFade *fadeOut;
/*! The nested params. */
@property (readonly, copy) NSArray<FxGripFCPXMLParam *> *subparams;

/*! A param with a name, key, and value. */
+ (instancetype)paramWithName:(NSString *)name key:(nullable NSString *)key value:(nullable NSString *)value;

/*! The keyframe animation, created in DTD order when absent. */
- (FxGripFCPXMLKeyframeAnimation *)keyframeAnimationCreatingIfNeeded;
/*! Removes the keyframe animation. */
- (void)removeKeyframeAnimation;
/*! Sets the fade-in, replacing any present; nil removes it. */
- (void)setFadeIn:(nullable FxGripFCPXMLFade *)fade;
/*! Sets the fade-out, replacing any present; nil removes it. */
- (void)setFadeOut:(nullable FxGripFCPXMLFade *)fade;
/*! The nested param with a name, or nil. */
- (nullable FxGripFCPXMLParam *)subparamNamed:(NSString *)name;
/*! The nested param with a key, or nil. */
- (nullable FxGripFCPXMLParam *)subparamWithKey:(NSString *)key;
/*! Appends a nested param. */
- (void)addSubparam:(FxGripFCPXMLParam *)param;

/*!
	@method     valueAtTime:
	@abstract   The value string in force at a time.
	@discussion The keyframe at the time when one exists; otherwise the value interpolated
				between the surrounding keyframes when both are numeric lists of equal length,
				else the nearest earlier keyframe's value, else `value`. Interpolation is linear;
				the `interp` and `curve` attributes are not modeled.
*/
- (nullable NSString *)valueAtTime:(CMTime)time;

/*! YES when the param carries a keyframe animation with at least one keyframe. */
@property (readonly) BOOL isAnimated;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLParam_h */
