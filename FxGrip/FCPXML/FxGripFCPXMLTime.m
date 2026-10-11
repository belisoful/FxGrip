/*!
	@file       FxGripFCPXMLTime.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLTime
	@abstract   Converts between FCPXML time strings and CMTime.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLTime.h.
*/

#import <FxGrip/FxGripFCPXMLTime.h>

static int64_t FxGripFCPXMLGCD(int64_t a, int64_t b)
{
	a = llabs(a);
	b = llabs(b);
	while (b != 0) {
		int64_t remainder = a % b;
		a = b;
		b = remainder;
	}
	return a;
}

@implementation FxGripFCPXMLTime

+ (CMTime)timeFromString:(NSString *)string
{
	CMTime time = kCMTimeInvalid;
	[self getTime:&time fromString:string];
	return time;
}

+ (BOOL)getTime:(CMTime *)time fromString:(NSString *)string
{
	if (time == NULL) {
		return NO;
	}
	*time = kCMTimeInvalid;
	if (![string isKindOfClass:NSString.class]) {
		return NO;
	}
	NSString *trimmed = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
	if ([trimmed hasSuffix:@"s"]) {
		trimmed = [trimmed substringToIndex:trimmed.length - 1];
	}
	if (trimmed.length == 0) {
		return NO;
	}

	NSScanner *scanner = [NSScanner scannerWithString:trimmed];
	scanner.charactersToBeSkipped = nil;
	long long numerator = 0;
	if (![scanner scanLongLong:&numerator]) {
		return NO;
	}
	long long denominator = 1;
	if (![scanner isAtEnd]) {
		if (![scanner scanString:@"/" intoString:NULL] || ![scanner scanLongLong:&denominator]) {
			return NO;
		}
	}
	if (![scanner isAtEnd] || denominator <= 0 || denominator > INT32_MAX) {
		return NO;
	}
	*time = CMTimeMake(numerator, (int32_t)denominator);
	return YES;
}

+ (NSString *)stringFromTime:(CMTime)time
{
	if (!CMTIME_IS_NUMERIC(time)) {
		return nil;
	}
	CMTime reduced = [self reducedTime:time];
	if (reduced.timescale == 1) {
		return [NSString stringWithFormat:@"%llds", reduced.value];
	}
	return [NSString stringWithFormat:@"%lld/%ds", reduced.value, reduced.timescale];
}

+ (NSString *)stringFromSeconds:(double)seconds timescale:(int32_t)timescale
{
	if (timescale <= 0) {
		timescale = 1;
	}
	CMTime time = CMTimeMakeWithSeconds(seconds, timescale);
	return [self stringFromTime:time] ?: @"0s";
}

+ (CMTime)reducedTime:(CMTime)time
{
	if (!CMTIME_IS_NUMERIC(time) || time.timescale <= 0) {
		return time;
	}
	if (time.value == 0) {
		return CMTimeMake(0, 1);
	}
	int64_t divisor = FxGripFCPXMLGCD(time.value, time.timescale);
	if (divisor <= 1) {
		return time;
	}
	return CMTimeMake(time.value / divisor, (int32_t)(time.timescale / divisor));
}

+ (CMTime)time:(CMTime)time alignedToFrameDuration:(CMTime)frameDuration
{
	if (!CMTIME_IS_NUMERIC(time) || !CMTIME_IS_NUMERIC(frameDuration)
		|| CMTimeCompare(frameDuration, kCMTimeZero) <= 0) {
		return time;
	}
	// Exact integer arithmetic: frames = floor(time / frameDuration).
	CMTime converted = CMTimeConvertScale(time, frameDuration.timescale, kCMTimeRoundingMethod_RoundTowardZero);
	int64_t frames = converted.value / frameDuration.value;
	if (converted.value < 0 && converted.value % frameDuration.value != 0) {
		frames -= 1;
	}
	return CMTimeMake(frames * frameDuration.value, frameDuration.timescale);
}

+ (BOOL)isTimeString:(NSString *)string
{
	CMTime time;
	return [self getTime:&time fromString:string];
}

@end
