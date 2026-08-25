/*
 *   Copyright (c) 2015 - 2017 Kulykov Oleh <info@resident.name>
 *
 *   Permission is hereby granted, free of charge, to any person obtaining a copy
 *   of this software and associated documentation files (the "Software"), to deal
 *   in the Software without restriction, including without limitation the rights
 *   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *   copies of the Software, and to permit persons to whom the Software is
 *   furnished to do so, subject to the following conditions:
 *
 *   The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *   THE SOFTWARE.
 */
/*
 *   Updated 2025 by belisoful <belisoful@icloud.com> for new functionality
 *   and conformance.
 */


#import <Foundation/Foundation.h>


/**
 @brief Mutable version of the NSNumber.
 @detailed
 <li> This class inherits all @b NSNumber protocols and overrides required methods for duplicate @b NSNumber read functionality.
 @code
	NSNumber * number = (NSNumber *)[[NSMutableNumber alloc] initWithInt:0];
	// use actual number NSMutableNumber class as NSNumber, of course read only
 @endcode
 <li> All getters are thread safe. Can be used for cross-thread synchronization. Used recursive mutex for get/set values.
 <li> Same hash method as on @b NSNumber object - required for using as key with key/value coding classes.
 <li> A genuine @b NSNumber subclass: kinship, toll-free bridging to @b CFNumberRef, symmetric
 equality with plain @b NSNumber values, and inherited API such as @b decimalValue all work.
 @code
	NSMutableNumber * mutableNumber = [[NSMutableNumber alloc] init];
	[mutableNumber isKindOfClass:[NSNumber class]]; // YES, is kind of class
	[mutableNumber isKindOfClass:[NSMutableNumber class]]; // YES, is kind of class
	[@0 isEqual:mutableNumber]; // YES, equality is symmetric
 @endcode
 <li> Archiving routes through @b encodeWithCoder: (see @b classForCoder), so a keyed archive
 round-trips as @b NSMutableNumber rather than flattening to an immutable plist number.
 An archivable subclass must declare its own
 @code
	- (Class)classForCoder { return [self class]; }
	- (Class)classForKeyedArchiver { return [self class]; }
 @endcode
 because @b NSKeyedUnarchiver rejects subclasses of plist types whose coder-class methods are inherited.
 <li> Can be compared with self(eg. @b NSMutableNumber) or @b NSNumber class.
 Comparison checks both numbers for real, signed and unsigned value and selects required method for comparing between values.
 @code
	[[NSMutableNumber numberWithBool:NO] isEqual:[NSNumber numberWithBool:NO]]; // YES, equal
	[[NSMutableNumber numberWithBool:YES] isEqual:[NSNumber numberWithFloat:1]]; // YES, equal
	[[NSMutableNumber numberWithDouble:DBL_MAX] isEqual:[NSNumber numberWithDouble:DBL_MAX]]; // YES, equal
	[[NSMutableNumber numberWithChar:CHAR_MIN] isEqual:[NSNumber numberWithInteger:CHAR_MIN]]; // YES, equal
	[[NSMutableNumber numberWithUnsignedShort:USHRT_MAX] isEqual:[NSNumber numberWithInt:USHRT_MAX]]; // YES, equal
 @endcode
 <li> Works with maximum and minimum type value ranges.
 @code
	[[NSMutableNumber numberWithInt:INT_MIN] isEqual:[NSNumber numberWithInt:INT_MIN]]; // YES, equal
	[[NSMutableNumber numberWithInteger:NSIntegerMin] isEqual:[NSNumber numberWithInteger:NSIntegerMin]]; // YES, equal
	[[NSMutableNumber numberWithUnsignedInteger:NSUIntegerMax] isEqual:[NSNumber numberWithUnsignedInteger:NSUIntegerMax]]; // YES, equal
	[[NSMutableNumber numberWithUnsignedLongLong:ULONG_LONG_MAX] isEqual:[NSNumber numberWithUnsignedLongLong:ULONG_LONG_MAX]]; // YES, equal
 @endcode
 <li> Internal logic implemented with C++. Same performance as standard @b NSNumber (see time tests) and minimum amount of memory for storing values(eg. unions).
 <li> @b NSNumber can be compared with this class via additional number comparator method @b isEqualToNumber:
 */
@interface NSMutableNumber : NSNumber <NSCopying, NSMutableCopying, NSSecureCoding>


/**
 @brief Nonatomic getter for the objCType string generated with `\@encode` during assigning value.
 */
@property (nonatomic, assign, readonly) const char * _Nonnull objCType;


/**
 @brief Initialize number object with ponter to the value and `\@encode` value type.
 @param value Pointer to the value, should not be nil.
 @param type Type string, returned by the `\@encode`, should not be nil.
 @warning Used assert for track nullability of the parameters.
 */
- (nonnull instancetype) initWithBytes:(nonnull const void *) value objCType:(nonnull const char *) type;


/**
 @brief Initialize number with decoder.
 @warning If there is no decoder - nil result.
 @param decoder Decoder object. Should not be nil.
 @return Initialized number object or nil.
 */
- (nullable instancetype) initWithCoder:(nullable NSCoder *) decoder;


/**
 @brief Initialize number with default zero int value.
 */
- (nonnull instancetype) init;


/**
 @brief Initialize number object with char value.
 */
- (nonnull NSMutableNumber *) initWithChar:(char) value;


/**
 @brief Initialize number object with unsigned char value.
 */
- (nonnull NSMutableNumber *) initWithUnsignedChar:(unsigned char) value;


/**
 @brief Initialize number object with short value.
 */
- (nonnull NSMutableNumber *) initWithShort:(short) value;


/**
 @brief Initialize number object with unsigned short value.
 */
- (nonnull NSMutableNumber *) initWithUnsignedShort:(unsigned short) value;


/**
 @brief Initialize number object with unichar value.
 */
- (nonnull NSMutableNumber *) initWithUnichar:(unichar) value;


/**
 @brief Initialize number object with int value.
 */
- (nonnull NSMutableNumber *) initWithInt:(int) value;


/**
 @brief Initialize number object with unsigned int value.
 */
- (nonnull NSMutableNumber *) initWithUnsignedInt:(unsigned int) value;


/**
 @brief Initialize number object with long value.
 */
- (nonnull NSMutableNumber *) initWithLong:(long) value;


/**
 @brief Initialize number object with unsigned long value.
 */
- (nonnull NSMutableNumber *) initWithUnsignedLong:(unsigned long) value;


/**
 @brief Initialize number object with long long value.
 */
- (nonnull NSMutableNumber *) initWithLongLong:(long long) value;


/**
 @brief Initialize number object with unsigned long long value.
 */
- (nonnull NSMutableNumber *) initWithUnsignedLongLong:(unsigned long long) value;


/**
 @brief Initialize number object with float value.
 */
- (nonnull NSMutableNumber *) initWithFloat:(float) value;


/**
 @brief Initialize number object with double value.
 */
- (nonnull NSMutableNumber *) initWithDouble:(double) value;


/**
 @brief Initialize number object with BOOL value.
 */
- (nonnull NSMutableNumber *) initWithBool:(BOOL) value;


/**
 @brief Initialize number object with NSInteger value.
 */
- (nonnull NSMutableNumber *) initWithInteger:(NSInteger) value;


/**
 @brief Initialize number object with NSUInteger value.
 */
- (nonnull NSMutableNumber *) initWithUnsignedInteger:(NSUInteger) value;



/**
 @brief Thread safe getter and setter for the value casted to char type.
 */
@property (atomic, assign, readwrite) char charValue;


/**
 @brief Thread safe getter and setter for the value casted to unsigned char type.
 */
@property (atomic, assign, readwrite) unsigned char unsignedCharValue;


/**
 @brief Thread safe getter and setter for the value casted to short type.
 */
@property (atomic, assign, readwrite) short shortValue;


/**
 @brief Thread safe getter and setter for the value casted to unsigned short type.
 */
@property (atomic, assign, readwrite) unsigned short unsignedShortValue;


/**
 @brief Thread safe getter and setter for the value casted to unichar type.
 */
@property (atomic, assign, readwrite) unichar unicharValue;


/**
 @brief Thread safe getter and setter for the value casted to int type.
 */
@property (atomic, assign, readwrite) int intValue;


/**
 @brief Thread safe getter and setter for the value casted to unsigned int type.
 */
@property (atomic, assign, readwrite) unsigned int unsignedIntValue;


/**
 @brief Thread safe getter and setter for the value casted to long type.
 */
@property (atomic, assign, readwrite) long longValue;


/**
 @brief Thread safe getter and setter for the value casted to unsigned long type.
 */
@property (atomic, assign, readwrite) unsigned long unsignedLongValue;


/**
 @brief Thread safe getter and setter for the value casted to long long type.
 */
@property (atomic, assign, readwrite) long long longLongValue;


/**
 @brief Thread safe getter and setter for the value casted to unsigned long long type.
 */
@property (atomic, assign, readwrite) unsigned long long unsignedLongLongValue;


/**
 @brief Thread safe getter and setter for the value casted to float type.
 */
@property (atomic, assign, readwrite) float floatValue;


/**
 @brief Thread safe getter and setter for the value casted to double type.
 */
@property (atomic, assign, readwrite) double doubleValue;


/**
 @brief Thread safe getter and setter for the value casted to BOOL type.
 @detailed @b NO means a 0 value of any type; @b YES means any other value, including NaN.
 */
@property (atomic, assign, readwrite) BOOL boolValue;


/**
 @brief Thread safe getter and setter for the value casted to NSInteger type.
 */
@property (atomic, assign, readwrite) NSInteger integerValue;


/**
 @brief Thread safe getter and setter for the value casted to NSUInteger type.
 */
@property (atomic, assign, readwrite) NSUInteger unsignedIntegerValue;


/**
 @brief Thread safe getter for the value presented as string.
 */
@property (atomic, copy, readonly) NSString * _Nonnull stringValue;


/**
 @brief Copy number value to the some holder pointer.
 @param value Pointer value to the buffer. Should not be nil. Buffer size should equal or greater than the size type of the number.
 @warning Used assert for track nullability of the parameter.
 */
- (void) getValue:(nonnull void *) value;


/**
 @brief Compare with other number object.
 @param object The number object. Supports @b NSNumber and @b NSMutableNumber object classes.
 @return Comparison result or @b NSOrderedDescending if parameter is nil or unsupported.
 @warning If parameter is nil or has an unsupported class type then the result is @b NSOrderedDescending because
 left operand is greater than the right, which is nil or unsupported.
 */
- (NSComparisonResult) compare:(nullable id) object;


/**
 @brief Check is number value is equal to the value of the another number object.
 @detailed Used @b compare: method for check.
 @param number Other number object or nil.
 @return YES - result of the @b compare: method is @b NSOrderedSame , otherwise NO.
 */
- (BOOL) isEqualToNumber:(nullable id) number;


/**
 @brief Converts and return value to string presentation.
 @param locale Unused parameter, cause of using @b snprintf function which gets system locale.
 */
- (nonnull NSString *) descriptionWithLocale:(nullable id) locale;


/**
 @brief Creates immutable copy of the number.
 Result class type is @b NSNumber object.
 */
- (nonnull NSNumber *) copy;


/**
 @brief Creates an immutable copy of the number.
 Result class type is @b NSNumber object.
 */
- (nonnull NSNumber *) copyWithZone:(nullable NSZone *) zone;


/**
 @brief Creates a mutable copy of the number.
 Result class type is @b NSMutableNumber object.
 */
- (nonnull NSMutableNumber *) mutableCopy;


/**
 @brief Creates a mutable copy of the number.
 Result class type is @b NSMutableNumber object.
 */
- (nonnull NSMutableNumber *) mutableCopyWithZone:(nullable NSZone *) zone;


/**
 @brief Creates immutable copy of the number.
 Result class type is @b NSNumber object.
 */
- (nonnull NSNumber *) immutableCopy;


/**
 @brief Thread safe bitwise NOT NSMutableNumber.
 */
@property (readonly) NSMutableNumber * _Nonnull bitNot;


/**
 @brief Thread safe bitwise NOT unsigned long long value.
 */
@property (nonatomic, assign, readwrite) unsigned long long bitNotValue;


/**
 @brief Adds 1 to the NSMutableNumber as a new number.
 */
@property (readonly) NSMutableNumber * _Nonnull plusOne;


/**
 @brief Subtracts 1 from the NSMutableNumber as a new number.
 */
@property (readonly) NSMutableNumber * _Nonnull subtractOne;


/**
 @brief Adds 1 to the NSMutableNumber.
 @return Returns self for chaining.
 */
- (nonnull NSMutableNumber *) addOne;


/**
 @brief Subtracts 1 from the NSMutableNumber.
 @return Returns self for chaining.
 */
- (nonnull NSMutableNumber *) minusOne;


/**
 @brief Compares the number to -1.
 */
@property(readonly) BOOL isNegativeOne;


/**
 @brief Compares the number to 0.
 */
@property(readonly) BOOL isZero;


/**
 @brief Compares the number to 0.
 */
@property(readonly) BOOL isPositiveZero;


/**
 @brief Compares the number to -0.0.
 */
@property(readonly) BOOL isNegativeZero;


/**
 @brief Compares the number to 1.
 */
@property(readonly) BOOL isOne;


/**
 @brief Compares the number to 2.
 */
@property(readonly) BOOL isTwo;


/**
 @brief Compares the number to 3.
 */
@property(readonly) BOOL isThree;


/**
 @brief Compares the number to 4.
 */
@property(readonly) BOOL isFour;


/**
 @brief Compares the number to 5.
 */
@property(readonly) BOOL isFive;


/**
 @brief Returns true if the number is Not A Number.
 */
@property(readonly) BOOL isNotANumber;


/**
 @brief Returns true if the number is positive Infinity.
 */
@property(readonly) BOOL isInfinity;


/**
 @brief Returns true if the number is negative Infinity.
 */
@property(readonly) BOOL isNegativeInfinity;

@end


/**
 @brief Static creating methods which using typed initializers.
 */
@interface NSMutableNumber(NSMutableNumberCreation)
/**
 @brief Thread safe INFINITY.
 */
@property (class, copy, readonly) NSMutableNumber * _Nonnull infinity;

/**
 @brief Thread safe -INFINITY.  `negativeInfinity` is already used as a define
 */
@property (class, copy, readonly) NSMutableNumber * _Nonnull minusInfinity;

/**
 @brief Thread safe NaN.
 */
@property (class, copy, readonly) NSMutableNumber * _Nonnull notANumber;

/**
 @brief Thread safe zero.
 */
@property (class, copy, readonly) NSMutableNumber * _Nonnull zero;

/**
 @brief Thread safe negative zero as a double.
 */
@property (class, copy, readonly) NSMutableNumber * _Nonnull negativeZero;

/**
 @brief Thread safe one.
 */
@property (class, copy, readonly) NSMutableNumber * _Nonnull one;

+ (nonnull NSMutableNumber *) numberWithChar:(char) number;
+ (nonnull NSMutableNumber *) numberWithUnsignedChar:(unsigned char) number;
+ (nonnull NSMutableNumber *) numberWithShort:(short) number;
+ (nonnull NSMutableNumber *) numberWithUnsignedShort:(unsigned short) number;
+ (nonnull NSMutableNumber *) numberWithInt:(int) number;
+ (nonnull NSMutableNumber *) numberWithUnsignedInt:(unsigned int) number;
+ (nonnull NSMutableNumber *) numberWithUnichar:(unichar) number;
+ (nonnull NSMutableNumber *) numberWithLong:(long) number;
+ (nonnull NSMutableNumber *) numberWithUnsignedLong:(unsigned long) number;
+ (nonnull NSMutableNumber *) numberWithLongLong:(long long) number;
+ (nonnull NSMutableNumber *) numberWithUnsignedLongLong:(unsigned long long) number;
+ (nonnull NSMutableNumber *) numberWithFloat:(float) number;
+ (nonnull NSMutableNumber *) numberWithDouble:(double) number;
+ (nonnull NSMutableNumber *) numberWithBool:(BOOL) number;
+ (nonnull NSMutableNumber *) numberWithInteger:(NSInteger) number;
+ (nonnull NSMutableNumber *) numberWithUnsignedInteger:(NSUInteger) number;

@end




@interface NSNumber(NSNumberAlignmentExtension) <NSMutableCopying>

/**
 @brief Thread safe INFINITY.
 */
@property (class, copy, readonly) NSNumber * _Nonnull infinity;

/**
 @brief Thread safe -INFINITY.  negativeInfinite is already taken.
 */
@property (class, copy, readonly) NSNumber * _Nonnull minusInfinity;

/**
 @brief Thread safe NaN.
 */
@property (class, copy, readonly) NSNumber * _Nonnull notANumber;

/**
 @brief Thread safe zero.
 */
@property (class, copy, readonly) NSNumber * _Nonnull zero;

/**
 @brief Thread safe zero.
 */
@property (class, copy, readonly) NSNumber * _Nonnull negativeZero;

/**
 @brief Thread safe one.
 */
@property (class, copy, readonly) NSNumber * _Nonnull one;


/**
 @brief new number object with unichar.
 */
+ (nonnull NSNumber *) numberWithUnichar:(unichar) number;


/**
 @brief Initialize number object with unichar.
 */
- (nullable id) initWithUnichar:(unichar) number;


/**
 @brief Thread safe getter and setter for the value casted to unichar.
 */
@property (readonly) unichar unicharValue;


/**
 @brief Thread safe bit NOT.
 */
@property (readonly) NSNumber * _Nonnull bitNot;


/**
 @brief Thread safe bit Not long long value.
 */
@property (atomic, assign, readonly) unsigned long long bitNotValue;


/**
 @brief Adds 1 to the NSNumber.
 */
@property (readonly) NSNumber * _Nonnull plusOne;


/**
 @brief Subtracts 1 from the NSNumber.
 */
@property (readonly) NSNumber * _Nonnull subtractOne;


/**
 @brief Compares the number to -1.
 */
@property(readonly) BOOL isNegativeOne;


/**
 @brief Compares the number to 0.
 */
@property(readonly) BOOL isZero;


/**
 @brief Compares the number to 0.
 */
@property(readonly) BOOL isPositiveZero;


/**
 @brief Compares the number to -0.0.
 */
@property(readonly) BOOL isNegativeZero;


/**
 @brief Compares the number to 1.
 */
@property(readonly) BOOL isOne;


/**
 @brief Compares the number to 2.
 */
@property(readonly) BOOL isTwo;


/**
 @brief Compares the number to 3.
 */
@property(readonly) BOOL isThree;


/**
 @brief Compares the number to 4.
 */
@property(readonly) BOOL isFour;


/**
 @brief Compares the number to 5.
 */
@property(readonly) BOOL isFive;


/**
 @brief Returns true if the number is Not A Number.
 */
@property(readonly) BOOL isNotANumber;


/**
 @brief Returns true if the number is positive Infinity.
 */
@property(readonly) BOOL isInfinity;


/**
 @brief Returns true if the number is negative Infinity.
 */
@property(readonly) BOOL isNegativeInfinity;


/**
 @brief Number category with overrided @b mutableCopyWithZone method,
 which returns @b NSMutableNumber object.
 */

@end
