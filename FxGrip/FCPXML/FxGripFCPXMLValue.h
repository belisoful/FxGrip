/*!
	@file       FxGripFCPXMLValue.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLValue
	@abstract   Encodes FxPlug parameter values as FCPXML `param` value strings, and back.
	@discussion Introduced in FxGrip 0.1.0. The encodings follow Final Cut Pro's own `param`
	            attributes: a color is `r g b a` (alpha omitted for an RGB parameter), a point is
	            `x y`, a toggle is `0` or `1`, an integer or menu index is a whole number, a float
	            is a decimal, and a string is itself. The preset side uses the encodings
	            ``FxGripPreset`` reads and writes (`red`/`green`/`blue`/`alpha` and `x`/`y`
	            dictionaries, `NSNumber`, `NSString`), so a preset value converts without a host.
	            A custom parameter value is a secure keyed archive carried as base64 in a nested
	            `archive` param, which ``FxGripFCPXMLAPI_v1`` writes and reads.
*/

#ifndef FxGripFCPXMLValue_h
#define FxGripFCPXMLValue_h

#import <Foundation/Foundation.h>
#import <FxGrip/FxGripTypes.h>

NS_ASSUME_NONNULL_BEGIN

/*! The nested param name that carries a custom value's archive. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLValueArchiveParamName;
/*! The `auxValue` that marks a nested archive param. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLValueArchiveMarker;

/*!
	@class      FxGripFCPXMLValue
	@abstract   The parameter value codec between preset encodings and FCPXML strings.
	@discussion Introduced in FxGrip 0.1.0. Every method is a pure class method.
*/
@interface FxGripFCPXMLValue : NSObject

/*!
	@method     stringForValue:type:
	@abstract   The FCPXML string for a preset-encoded value.
	@param      value	An `NSNumber`, `NSString`, or a color or point dictionary.
	@param      type	The parameter type, or `FxParameterType_None` to infer it from the value's shape.
	@return     The string, or nil for a value with no string form (a custom object).
*/
+ (nullable NSString *)stringForValue:(nullable id)value type:(FxParameterType)type;

/*!
	@method     valueForString:type:
	@abstract   The preset-encoded value an FCPXML string carries.
	@param      string	The `value` attribute.
	@param      type	The parameter type that decides the shape; `FxParameterType_None` infers it
				from the token count: one token is a number, two a point, three or four a color,
				anything else a string.
	@return     The value, or nil for an empty string.
*/
+ (nullable id)valueForString:(nullable NSString *)string type:(FxParameterType)type;

/*! The parameter type a preset-encoded value's shape implies, or `FxParameterType_None`. */
+ (FxParameterType)inferredTypeForValue:(nullable id)value;

/*! Numbers joined by single spaces, each with up to fifteen significant digits. */
+ (NSString *)stringForNumbers:(NSArray<NSNumber *> *)numbers;
/*! The numbers a space-separated string holds; empty when any token is not a number. */
+ (NSArray<NSNumber *> *)numbersForString:(nullable NSString *)string;
/*! One number with up to fifteen significant digits; whole numbers write without a fraction. */
+ (NSString *)stringForDouble:(double)value;
/*! A color as `r g b` or `r g b a`; pass `NAN` to omit alpha. */
+ (NSString *)stringForRed:(double)red green:(double)green blue:(double)blue alpha:(double)alpha;
/*! A point as `x y`. */
+ (NSString *)stringForX:(double)x y:(double)y;

/*!
	@method     archiveStringForObject:
	@abstract   A secure keyed archive of an object, base64 encoded.
	@return     The string, or nil when the object cannot be archived.
*/
+ (nullable NSString *)archiveStringForObject:(nullable id<NSSecureCoding>)object;

/*!
	@method     objectForArchiveString:classes:
	@abstract   The object a base64 secure keyed archive holds.
	@param      string	The archive string.
	@param      classes	The classes the archive may contain; nil allows the property-list classes.
	@return     The object, or nil when the archive does not decode.
*/
+ (nullable id)objectForArchiveString:(nullable NSString *)string classes:(nullable NSSet<Class> *)classes;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLValue_h */
