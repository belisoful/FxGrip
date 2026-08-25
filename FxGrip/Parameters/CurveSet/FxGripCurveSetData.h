//
//  FxGripCurveSetData.h
//  FxGrip
//

#ifndef FxGripCurveSetData_h
#define FxGripCurveSetData_h

#import "FxGripInterpolatingDictionary.h"
#import "FxGripCurveData.h"

/*!
	@class      FxGripCurveSetData
	@abstract   A filter's full curve set, keyed by mapping name.
	@discussion Introduced in FxGrip 1.0. Keys are the filter family's channel names
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
