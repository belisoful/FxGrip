/*!
	@file       FxGripCurveSetData.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCurveSetData
	@abstract   The custom value that holds a filter's full set of curves.
	@discussion Introduced in FxGrip 0.1.0. The value maps each channel name to an
	            FxGripCurveData. An absent key stands for the mapping's neutral curve, so only
	            edited curves are stored. Keyframing blends two sets curve-aware.
*/

#ifndef FxGripCurveSetData_h
#define FxGripCurveSetData_h

#import "FxGripInterpolatingDictionary.h"
#import "FxGripCurveData.h"

/*!
	@class      FxGripCurveSetData
	@abstract   A filter's full curve set, keyed by mapping name.
	@discussion Introduced in FxGrip 0.1.0. Keys are the filter family's channel names
				(`luma`, `red`, `hueVsHue`, `satVsLuma`, `alphaVsAlpha`, ...); values
				are FxGripCurveData. An absent key means the mapping's neutral curve,
				so only edited curves are stored and documents stay small.

				Host keyframing interpolates two sets through the inherited machinery;
				curve values blend curve-aware: two curves with matching point counts,
				role, and domain interpolate pairwise, and any mismatch blends the two
				evaluated curves on a 33-sample grid, so a point added mid-animation
				cannot drop the curve. Scalar companions (mix, biases, enables) belong
				in native FxPlug parameters, not in this set.
*/
@interface FxGripCurveSetData : FxGripInterpolatingDictionary

/*! The stored curve, or nil when the mapping is neutral. */
- (nullable FxGripCurveData *)curveForKey:(nonnull NSString *)key;

/*! Stores a curve; a nil or identity curve removes the key. */
- (void)setCurve:(nullable FxGripCurveData *)curve forKey:(nonnull NSString *)key;

- (void)removeCurveForKey:(nonnull NSString *)key;

/*! The mapping names with stored curves, sorted. */
- (nonnull NSArray<NSString *> *)curveKeys;

@end

#endif /* FxGripCurveSetData_h */
