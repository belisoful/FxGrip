/*!
	@file       FxGripInterpolatingDictionary.m
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInterpolatingDictionary
	@abstract   Implements keyframe interpolation over a dictionary custom parameter value.
	@discussion Introduced in FxGrip 0.1.0. The interpolation walks the two values in parallel by key,
	            blending strings, collections, and numbers, and copying everything the base cannot blend.
	            Number blending preserves the CFNumber type of the left value.
*/

#import "FxGripInterpolatingDictionary.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	A dictionary custom parameter value that keyframe-interpolates its entries.
	@discussion	Introduced in FxGrip 0.1.0. Entries whose key is exempt or underscore-prefixed are copied;
				the rest are blended by type. A subclass extends blending through customInterpolateValue:.
*/
@implementation FxGripInterpolatingDictionary

// The secure unarchiver requires every concrete class to answer classForCoder itself;
// an inherited override fails the possibly-altered-archive check.
- (Class)classForCoder
{
	return self.class;
}


#pragma mark -
#pragma mark Custom Parameter Interpolation



/*!
	@method		interpolateBetween:withWeight:
	@abstract	Blends the receiver toward another instance at a weight, producing a new instance.
	@discussion	Introduced in FxGrip 0.1.0. The FxCustomParameterInterpolation_v2 entry point. Keys
				prefixed with the none-prefix are skipped. The result is the receiver's own class.
	@param		rightValue	The value at the later keyframe.
	@param		weight		The blend weight from 0 (receiver) to 1 (rightValue).
	@result		A new interpolated instance.
*/
- (NSObject<NSSecureCoding, NSCopying>*)interpolateBetween:(NSObject<NSSecureCoding, NSCopying>*)rightValue
												withWeight:(float)weight
{
	FxGripInterpolatingDictionary*	rightValues = (FxGripInterpolatingDictionary*)rightValue;
	
	//Start with all the exempt keys from the left
	// self.class, so a subclass interpolates into its own kind.
	FxGripInterpolatingDictionary*	result = [[self.class alloc] initWithCapacity:[self count]];
	
	// Interpolate the keys
	for(id key in [self allKeys]) {
		if ([key hasPrefix:kInterpolatingDictionaryNonePrefix]) {
			continue;
		}
		id weighted = [self interpolateValue:[self objectForKey:key] rightValue:[rightValues objectForKey:key] withWeight:weight];
		if (weighted) {
			[result setObject:weighted forKey:key];
			weighted = nil;
		}
	}
	
	return NARC_AUTORELEASE(result);
}

/*! @abstract Blends two values at a weight, with no key path. */
- (id)interpolateValue:(id)left rightValue:(id)right withWeight:(float)weight
{
	return [self interpolateValue:left rightValue:right path:nil withWeight:weight];
}

/*!
	@method		interpolateValue:rightValue:path:withWeight:
	@abstract	Blends two values at a weight, recursing into collections by key path.
	@discussion	Introduced in FxGrip 0.1.0. Values of different classes return nil. Strings and
				exempt-path values are copied. Arrays and dictionaries blend element by element,
				skipping none-prefixed keys. Numbers blend in the left value's CFNumber type; a
				char or 8-bit integer, which represents a boolean, is copied. Other classes defer
				to customInterpolateValue:rightValue:path:withWeight:, then fall back to a copy.
	@param		path	The slash-joined key path of the entry.
	@result		The blended value, or a copy when the value cannot be blended.
*/
- (id)interpolateValue:(id)left rightValue:(id)right path:(NSString*)path withWeight:(float)weight
{
	if ([left class] != [right class]) {
		return nil;
	}
	
	if ([left isKindOfClass:[NSString class]] || [self.exemptKeys containsObject:path]) {
		return NARC_AUTORELEASE([left copy]);
	}
	
	if (!path) {
		path = @"";
	}
	if (![path hasSuffix:@"/"]) {
		path = [path stringByAppendingString:@"/"];
	}
	
	if ([left isKindOfClass:[NSArray class]]) {
		NSMutableArray *result = [NSMutableArray arrayWithCapacity:[left count]];
		
		NSEnumerator *leftEnumerator = [left objectEnumerator];
		NSEnumerator *rightEnumerator = [right objectEnumerator];
		id leftObject;
		int i = 0;
		while (leftObject = [leftEnumerator nextObject]) {
			id rightObject = [rightEnumerator nextObject];
			NSString * newPath = [path stringByAppendingString:[[NSNumber numberWithInt:i] stringValue]];
			id weightedObject = [self interpolateValue:leftObject rightValue:rightObject path:newPath withWeight:weight];
			if (weightedObject) {
				[result addObject:weightedObject];
			}
			i++;
		}
		
		return result;
	}
	if ([left isKindOfClass:[NSDictionary class]]) {
		NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[left count]];
		
		NSEnumerator *enumerator = [left keyEnumerator];
		id key;
		while (key = [enumerator nextObject]) {
			if ([key hasPrefix:kInterpolatingDictionaryNonePrefix]) {
				continue;
			}
			id leftObject = [left objectForKey:key];
			id rightObject = [right objectForKey:key];
			NSString *newPath = [path stringByAppendingString:[key isKindOfClass:[NSString class]] ? key : [key stringValue]];
			id weightedObject = [self interpolateValue:leftObject rightValue:rightObject path:newPath withWeight:weight];
			if (weightedObject) {
				[result setObject:weightedObject forKey:key];
			}
		}
		
		return result;
	}
	if ([left isKindOfClass:[NSNumber class]]) {
		CFNumberType numberType = CFNumberGetType((CFNumberRef)left);
		
		NSNumber *result = nil;
		switch (numberType) {
			case kCFNumberCharType:
			case kCFNumberSInt8Type: //Boolean is char.
				result = left;//[NSNumber numberWithChar:(char)(round(([right charValue] - [left charValue]) * weight) + [left charValue]) ];
				break;
			case kCFNumberShortType:
			case kCFNumberSInt16Type:
				result = [NSNumber numberWithShort:(short)(round(((double)[right shortValue] - (double)[left shortValue]) * weight) + [left shortValue]) ];
				break;
			case kCFNumberSInt32Type:
				result = [NSNumber numberWithInt:(SInt32)(round(((double)[right intValue] - (double)[left intValue]) * weight) + [left intValue]) ];
				break;
			case kCFNumberIntType:
				result = [NSNumber numberWithInt:(int)(round(((double)[right intValue] - (double)[left intValue]) * weight) + [left intValue]) ];
				break;
			case kCFNumberSInt64Type:
			case kCFNumberLongType:
			case kCFNumberCFIndexType:
			case kCFNumberNSIntegerType:
				result = [NSNumber numberWithLong:(long)(round(((double)[right longValue] - (double)[left longValue]) * weight) + [left longValue]) ];
				break;
			case kCFNumberLongLongType:
				result = [NSNumber numberWithLongLong:(long long)(round(((double)[right longLongValue] - (double)[left longLongValue]) * weight) + [left longLongValue]) ];
				break;
				
			case kCFNumberFloat32Type:
			case kCFNumberFloatType:
#if !CGFLOAT_IS_DOUBLE
			case kCFNumberCGFloatType:
#endif
				result = [NSNumber numberWithFloat:(float)(([right floatValue] - [left floatValue]) * weight + [left floatValue]) ];
				break;
			case kCFNumberFloat64Type:
			case kCFNumberDoubleType:
#if CGFLOAT_IS_DOUBLE
			case kCFNumberCGFloatType:
#endif
				result = [NSNumber numberWithDouble:(double)(([right doubleValue] - [left doubleValue]) * weight + [left doubleValue]) ];
				break;
		}
		return result;
	}
	
	id result = [self customInterpolateValue:left rightValue:right path:path withWeight:weight];
	if (result) {
		return result;
	}
	
	return NARC_AUTORELEASE([left copy]);
}

// exemptKeys is inherited from FxGripDictionary.

/*!
	@method		customInterpolateValue:rightValue:path:withWeight:
	@abstract	The subclass hook for values the base cannot blend.
	@discussion	Introduced in FxGrip 0.1.0. The base returns nil, so the caller copies the left value.
				A subclass returns the blended value for the classes it understands.
*/
- (id)customInterpolateValue:(id)left rightValue:(id)right path:(NSString*)path withWeight:(float)weight
{
	return nil;
}



@end
