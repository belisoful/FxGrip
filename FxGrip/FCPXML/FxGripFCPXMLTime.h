/*!
	@file       FxGripFCPXMLTime.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLTime
	@abstract   Converts between FCPXML time strings and CMTime.
	@discussion Introduced in FxGrip 0.1.0. FCPXML writes a time as a rational number of seconds
	            with an `s` suffix: `"1001/30000s"`, `"5s"`, `"0s"`. The numerator is 64-bit and
	            the denominator 32-bit, which is the CMTime layout. Every method is a pure class
	            method with no host dependency.
*/

#ifndef FxGripFCPXMLTime_h
#define FxGripFCPXMLTime_h

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripFCPXMLTime
	@abstract   Parses and formats FCPXML rational time strings.
	@discussion Introduced in FxGrip 0.1.0. A parsed time keeps the denominator the string
				carries. A formatted time is reduced to lowest terms and written as a whole
				number of seconds when the denominator reduces to one.
*/
@interface FxGripFCPXMLTime : NSObject

/*!
	@method     timeFromString:
	@abstract   The time a string encodes, or `kCMTimeInvalid`.
	@discussion Accepts an optional sign, a numerator, an optional `/denominator`, and an
				optional `s` suffix, with surrounding whitespace. A zero or negative
				denominator, a value outside 64 bits, or any other text returns
				`kCMTimeInvalid`.
*/
+ (CMTime)timeFromString:(nullable NSString *)string;

/*!
	@method     getTime:fromString:
	@abstract   Parses a string into a time out-parameter.
	@return     YES when the string encodes a time.
*/
+ (BOOL)getTime:(CMTime *)time fromString:(nullable NSString *)string;

/*!
	@method     stringFromTime:
	@abstract   The FCPXML string for a time, reduced to lowest terms.
	@discussion A time whose reduced denominator is one writes as `"Ns"`. A negative time
				carries a leading minus sign. An invalid or indefinite time returns nil.
*/
+ (nullable NSString *)stringFromTime:(CMTime)time;

/*!
	@method     stringFromSeconds:timescale:
	@abstract   The FCPXML string for a number of seconds, rounded to a timescale.
*/
+ (NSString *)stringFromSeconds:(double)seconds timescale:(int32_t)timescale;

/*!
	@method     reducedTime:
	@abstract   The time with its value and timescale divided by their greatest common divisor.
	@discussion An invalid time returns unchanged. A zero value reduces to timescale one.
*/
+ (CMTime)reducedTime:(CMTime)time;

/*!
	@method     time:alignedToFrameDuration:
	@abstract   The time rounded down to a whole number of frames.
	@discussion The result is expressed as a multiple of the frame duration in the frame
				duration's own timescale, so it writes as the rational Final Cut Pro expects for
				that frame rate. An invalid time or a non-positive frame duration returns the
				time unchanged.
*/
+ (CMTime)time:(CMTime)time alignedToFrameDuration:(CMTime)frameDuration;

/*!
	@method     isTimeString:
	@abstract   YES when the string parses as a time.
*/
+ (BOOL)isTimeString:(nullable NSString *)string;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLTime_h */
