//
//  FxGripInterpolatingDictionary.m
//  PlugIn
//
//  Created by Apple on 10/22/18.
//  Copyright © 2019-2023 Apple Inc. All rights reserved.
//
// @todo interpolation style, ease in, ease out, s-curve
//    		make a prefix or postfix to skip interpolation

#import "FxGripInterpolatingDictionary.h"
#import "FxGrip_ARC.h"

@implementation FxGripInterpolatingDictionary


#pragma mark -
#pragma mark Custom Parameter Interpolation



- (NSObject<NSSecureCoding, NSCopying>*)interpolateBetween:(NSObject<NSSecureCoding, NSCopying>*)rightValue
												withWeight:(float)weight
{
	FxGripInterpolatingDictionary*	rightValues = (FxGripInterpolatingDictionary*)rightValue;
	
	//Start with all the exempt keys from the left
	FxGripInterpolatingDictionary*	result = [FxGripInterpolatingDictionary.alloc initWithCapacity:[self count]];
	
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

- (id)interpolateValue:(id)left rightValue:(id)right withWeight:(float)weight
{
	return [self interpolateValue:left rightValue:right path:nil withWeight:weight];
}

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
				result = [NSNumber numberWithInt:(SInt32)(round(((double)[right int32Value] - (double)[left int32Value]) * weight) + [left int32Value]) ];
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

- (NSMutableArray*)exemptKeys
{
	NSMutableArray *exemptKeys = [self objectForKey:kCustomAPI_ExemptKeysKey];
	
	if (!exemptKeys) {
		exemptKeys = [NSMutableArray arrayWithCapacity:1];
	}
	if (exemptKeys && ![exemptKeys isKindOfClass:[NSMutableArray class]]) {
		if ([exemptKeys isKindOfClass:[NSArray class]]) {
			exemptKeys = [NSMutableArray arrayWithArray:exemptKeys];
		} else {
			id priorValue = exemptKeys;
			exemptKeys = [NSMutableArray arrayWithCapacity:2];
			[exemptKeys addObject:priorValue];
		}
	}
	if (![exemptKeys containsObject:kCustomAPI_ExemptKeysKey]) {
		[exemptKeys addObject:kCustomAPI_ExemptKeysKey];
	}
	if (![exemptKeys containsObject:kCustomAPI_LastChangedKey]) {
		[exemptKeys addObject:kCustomAPI_LastChangedKey];
	}
	[self setObject:exemptKeys forKey:kCustomAPI_ExemptKeysKey];
	return exemptKeys;
}

- (id)customInterpolateValue:(id)left rightValue:(id)right path:(NSString*)path withWeight:(float)weight
{
	return nil;
}



@end
