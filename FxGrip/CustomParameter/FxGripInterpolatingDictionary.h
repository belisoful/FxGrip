/*!
	@file       FxGripInterpolatingDictionary.h
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInterpolatingDictionary
	@abstract   A dictionary custom parameter value that keyframe-interpolates its entries.
	@discussion Introduced in FxGrip 0.1.0. The class subclasses FxGripDictionary and conforms to
	            FxCustomParameterInterpolation_v2, so the host blends the value across keyframes. It
	            interpolates strings, collections, and numbers, and copies everything else. Keys in the
	            exempt-keys array and keys prefixed with an underscore are copied rather than blended.
	            A subclass blends further types through customInterpolateValue:rightValue:path:withWeight:.
*/

#ifndef FxGripInterpolatingDictionary_h
#define FxGripInterpolatingDictionary_h

#import "FxGripDictionary.h"

/*! Key prefix that excludes an entry from interpolation. */
#define kInterpolatingDictionaryNonePrefix @"_"

/*!
	@class      FxGripInterpolatingDictionary
	@abstract	A dictionary custom parameter value that keyframe-interpolates its entries.
	@discussion Introduced in FxGrip 0.1.0. The class holds a custom parameter's values and blends
				between two keyframes. It interpolates strings, collections, and numbers, and copies
				everything else. Keys in the exempt-keys array and keys prefixed with an underscore are
				copied rather than blended. FxPlug types are set and read without translating through
				NSNumber.
 */
@interface FxGripInterpolatingDictionary : FxGripDictionary <FxCustomParameterInterpolation_v2>

/*!
	@method     customInterpolateValue:rightValue:path:withWeight:
	@abstract   The subclass hook for values the base cannot blend.
	@discussion Introduced in FxGrip 0.1.0. The base interpolation calls this for a value
				pair whose class is neither a string, collection, nor number; the base
				returns nil and the caller keeps a copy of the left value. A subclass
				returns the blended value for the classes it understands. `path` is the
				slash-joined key path of the entry.
*/
- (id _Nullable)customInterpolateValue:(id _Nullable)left
							rightValue:(id _Nullable)right
								  path:(NSString *_Nullable)path
							withWeight:(float)weight;

@end

#endif
