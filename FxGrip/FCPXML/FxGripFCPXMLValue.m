/*!
	@file       FxGripFCPXMLValue.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLValue
	@abstract   Encodes FxPlug parameter values as FCPXML `param` value strings, and back.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLValue.h.
*/

#import <FxGrip/FxGripFCPXMLValue.h>

NSString *const FxGripFCPXMLValueArchiveParamName = @"archive";
NSString *const FxGripFCPXMLValueArchiveMarker = @"NSKeyedArchiver";

@implementation FxGripFCPXMLValue

#pragma mark - Numbers

+ (NSString *)stringForDouble:(double)value
{
	if (value == (double)(long long)value && fabs(value) < 1e15) {
		return [NSString stringWithFormat:@"%lld", (long long)value];
	}
	return [NSString stringWithFormat:@"%.15g", value];
}

+ (NSString *)stringForNumbers:(NSArray<NSNumber *> *)numbers
{
	NSMutableArray *tokens = [NSMutableArray arrayWithCapacity:numbers.count];
	for (NSNumber *number in numbers) {
		[tokens addObject:[self stringForDouble:number.doubleValue]];
	}
	return [tokens componentsJoinedByString:@" "];
}

+ (NSArray<NSNumber *> *)numbersForString:(NSString *)string
{
	if (![string isKindOfClass:NSString.class]) {
		return @[];
	}
	NSMutableArray *numbers = [NSMutableArray array];
	NSLocale *posix = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
	for (NSString *token in [string componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]) {
		if (token.length == 0) {
			continue;
		}
		NSScanner *scanner = [NSScanner scannerWithString:token];
		scanner.locale = posix;
		double value = 0;
		if (![scanner scanDouble:&value] || !scanner.isAtEnd) {
			return @[];
		}
		[numbers addObject:@(value)];
	}
	return numbers;
}

+ (NSString *)stringForRed:(double)red green:(double)green blue:(double)blue alpha:(double)alpha
{
	if (isnan(alpha)) {
		return [self stringForNumbers:@[@(red), @(green), @(blue)]];
	}
	return [self stringForNumbers:@[@(red), @(green), @(blue), @(alpha)]];
}

+ (NSString *)stringForX:(double)x y:(double)y
{
	return [self stringForNumbers:@[@(x), @(y)]];
}

#pragma mark - Shapes

+ (FxParameterType)inferredTypeForValue:(id)value
{
	if ([value isKindOfClass:NSString.class]) {
		return FxParameterType_String;
	}
	if ([value isKindOfClass:NSDictionary.class]) {
		NSDictionary *dictionary = value;
		if (dictionary[kFxParameterProperty_Red] != nil) {
			return dictionary[kFxParameterProperty_Alpha] != nil ? FxParameterType_RGBA : FxParameterType_RGB;
		}
		if (dictionary[kFxParameterProperty_X] != nil) {
			return FxParameterType_Point;
		}
		return FxParameterType_Custom;
	}
	if ([value isKindOfClass:NSNumber.class]) {
		return FxParameterType_Float;
	}
	return FxParameterType_None;
}

static double FxGripFCPXMLComponent(NSDictionary *dictionary, NSString *key)
{
	id value = dictionary[key];
	return [value isKindOfClass:NSNumber.class] ? [value doubleValue] : 0;
}

+ (NSString *)stringForValue:(id)value type:(FxParameterType)type
{
	if (value == nil) {
		return nil;
	}
	if (type == FxParameterType_None) {
		type = [self inferredTypeForValue:value];
	}
	switch (type) {
		case FxParameterType_RGBA:
		case FxParameterType_RGB: {
			if (![value isKindOfClass:NSDictionary.class]) {
				return nil;
			}
			NSDictionary *color = value;
			double alpha = NAN;
			if (type == FxParameterType_RGBA || color[kFxParameterProperty_Alpha] != nil) {
				alpha = color[kFxParameterProperty_Alpha] ? FxGripFCPXMLComponent(color, kFxParameterProperty_Alpha) : 1;
			}
			return [self stringForRed:FxGripFCPXMLComponent(color, kFxParameterProperty_Red)
								green:FxGripFCPXMLComponent(color, kFxParameterProperty_Green)
								 blue:FxGripFCPXMLComponent(color, kFxParameterProperty_Blue)
								alpha:alpha];
		}
		case FxParameterType_Point: {
			if (![value isKindOfClass:NSDictionary.class]) {
				return nil;
			}
			return [self stringForX:FxGripFCPXMLComponent(value, kFxParameterProperty_X)
								  y:FxGripFCPXMLComponent(value, kFxParameterProperty_Y)];
		}
		case FxParameterType_String:
		case FxParameterType_FontMenu:
			return [value isKindOfClass:NSString.class] ? value : [value description];
		case FxParameterType_Toggle:
			return [value isKindOfClass:NSNumber.class] ? ([value boolValue] ? @"1" : @"0") : nil;
		case FxParameterType_Int:
		case FxParameterType_Menu:
			return [value isKindOfClass:NSNumber.class] ? [NSString stringWithFormat:@"%lld", [value longLongValue]] : nil;
		case FxParameterType_Custom:
			return nil;
		default:
			if ([value isKindOfClass:NSNumber.class]) {
				return [self stringForDouble:[value doubleValue]];
			}
			if ([value isKindOfClass:NSString.class]) {
				return value;
			}
			return nil;
	}
}

+ (id)valueForString:(NSString *)string type:(FxParameterType)type
{
	if (![string isKindOfClass:NSString.class] || string.length == 0) {
		return nil;
	}
	NSArray<NSNumber *> *numbers = [self numbersForString:string];
	if (type == FxParameterType_None) {
		switch (numbers.count) {
			case 1: type = FxParameterType_Float; break;
			case 2: type = FxParameterType_Point; break;
			case 3: type = FxParameterType_RGB; break;
			case 4: type = FxParameterType_RGBA; break;
			default: type = FxParameterType_String; break;
		}
	}
	switch (type) {
		case FxParameterType_RGBA:
		case FxParameterType_RGB: {
			if (numbers.count < 3) {
				return nil;
			}
			NSMutableDictionary *color = [NSMutableDictionary dictionaryWithDictionary:@{
				kFxParameterProperty_Red: numbers[0], kFxParameterProperty_Green: numbers[1],
				kFxParameterProperty_Blue: numbers[2]}];
			if (type == FxParameterType_RGBA) {
				color[kFxParameterProperty_Alpha] = numbers.count > 3 ? numbers[3] : @1;
			} else if (numbers.count > 3) {
				color[kFxParameterProperty_Alpha] = numbers[3];
			}
			return color;
		}
		case FxParameterType_Point:
			if (numbers.count < 2) {
				return nil;
			}
			return @{kFxParameterProperty_X: numbers[0], kFxParameterProperty_Y: numbers[1]};
		case FxParameterType_String:
		case FxParameterType_FontMenu:
			return string;
		case FxParameterType_Toggle: {
			if (numbers.count == 1) {
				return @(numbers[0].doubleValue != 0);
			}
			if ([string caseInsensitiveCompare:@"true"] == NSOrderedSame || [string caseInsensitiveCompare:@"yes"] == NSOrderedSame) {
				return @YES;
			}
			if ([string caseInsensitiveCompare:@"false"] == NSOrderedSame || [string caseInsensitiveCompare:@"no"] == NSOrderedSame) {
				return @NO;
			}
			return nil;
		}
		case FxParameterType_Int:
		case FxParameterType_Menu:
			return numbers.count == 1 ? @((int)llround(numbers[0].doubleValue)) : nil;
		case FxParameterType_Custom:
			return nil;
		default:
			return numbers.count == 1 ? numbers[0] : nil;
	}
}

#pragma mark - Archives

+ (NSString *)archiveStringForObject:(id<NSSecureCoding>)object
{
	if (object == nil) {
		return nil;
	}
	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:&error];
	return data ? [data base64EncodedStringWithOptions:0] : nil;
}

+ (id)objectForArchiveString:(NSString *)string classes:(NSSet<Class> *)classes
{
	if (string.length == 0) {
		return nil;
	}
	NSData *data = [[NSData alloc] initWithBase64EncodedString:string options:NSDataBase64DecodingIgnoreUnknownCharacters];
	if (data == nil) {
		return nil;
	}
	NSSet<Class> *allowed = classes ?: [NSSet setWithArray:@[NSDictionary.class, NSArray.class, NSString.class,
															 NSNumber.class, NSData.class, NSDate.class, NSNull.class]];
	NSError *error = nil;
	return [NSKeyedUnarchiver unarchivedObjectOfClasses:allowed fromData:data error:&error];
}

@end
