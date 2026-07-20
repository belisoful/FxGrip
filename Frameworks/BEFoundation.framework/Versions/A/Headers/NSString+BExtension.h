/*!
 @header		NSString+BExtension.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		`NSString` Category extension to provide numeric and date validation.
 @discussion	This category adds methods for checking if the NSString is a digit, integer, floating point
				number, or has a specific date or time.
*/

#ifndef NSString_BExtension_h
#define NSString_BExtension_h

#import <Foundation/Foundation.h>

/*!
 @category		BExtension
 @abstract		Adds numeric checking and date/time checking.
 @discussion	This category adds methods to `NSString` for checking
 whether the string contains specific types of data (e.g., digits, integers, floats, dates, and times). These
 methods validate or convert strings based on their content.

 It also adds `stringValue` to mimic NSNumber for consistency in reading plist Dictionaries.
 
 The following methods are provided by this category:
 
 `-stringValue`: Returns the string representation of the receiver, similar to `NSNumber`'s `stringValue`.
 
 `-isDigits`: Checks if the string consists only of digits.
 
 `-isIntValue`: Checks if the string can be interpreted as an integer.
 
 `-isIntegerValue`: Similar to `-isIntValue`, checks if the string can be interpreted as a valid integer.
 
 `-isLongLongValue`: Checks if the string can be interpreted as a valid `long long` integer.
 
 `-isUnsignedLongLongValue`: Checks if the string can be interpreted as a valid unsigned `long long` integer.
 
 `-isFloatValue`: Checks if the string can be interpreted as a valid float.
 
 `-isDoubleValue`: Checks if the string can be interpreted as a valid double.
 
 `-isSystemDateTimeValue`: Checks if the string is a valid system date time.
 
 `-isSystemDateValue`: Checks if the string is a valid system date.
 
 `-isSystemTimeValue`: Checks if the string is a valid system time.
 
 `-dateWithStyle:`: Parses the string as a date of a given style (returns the NSDate or nil).

 `-timeWithStyle:`: Parses the string as a time of a given style (returns the NSDate or nil).

 `-dateWithStyle:timeStyle:`: Parses the string as a date and time of given styles.

 `-dateWithFormat:`: Parses the string against an NSDateFormatter format string.
 
 And in NSMutableString:
 
 `-deleteAtIndex:`: Deletes the character at an index.
 
 These methods aim to make string parsing and validation easier, especially in scenarios where the format or
 content of the string matters, such as user input validation or conversion tasks.

 @code
	if (@"42".isIntegerValue) { NSInteger n = @"42".integerValue; }   // YES
	BOOL allDigits = @"007".isDigits;                                 // YES (no sign/decimal)

	NSString *greeting = [@"world" stringByPrependingString:@"hello "]; // "hello world"
	NSString *line = [@"\n" stringByPrependingFormat:@"item %d", 3];    // "item 3\n"

	NSMutableString *m = @"bar".mutableCopy;
	[m prependString:@"foo"];   // "foobar"
	[m deleteAtIndex:0];        // "oobar"
 @endcode
 */
@interface NSString (BExtension)

/*!
 @property		stringValue
 @abstract		Returns the string.
 @discussion	This method provides compatibility with `[NSNumber stringValue]`, specifically for
				reading plist in a more standardized way.
 @result		Returns the receiver itself.
 */
@property (readonly, strong, nonatomic, nonnull) NSString* stringValue;

/*!
 @property		isDigits
 @abstract		Checks if the string is all digits.
 @result		Returns `YES`  if all digits.
 */
@property (readonly, assign, nonatomic) BOOL isDigits;

/*!
 @property		isIntValue
 @abstract		Checks if the string is a valid 32 bit int.
 @result		Returns `YES`  if the string is an `int`.
 */
@property (readonly, assign, nonatomic) BOOL isIntValue;

/*!
 @property		isIntegerValue
 @abstract		Checks if the string is a valid system sized (32 or 64 bit) long.
 @result		Returns `YES`  if the string is an `long`.
 */
@property (readonly, assign, nonatomic) BOOL isIntegerValue;

/*!
 @property		isLongLongValue
 @abstract		Checks if the string is a valid 64 bit long long.
 @result		Returns `YES`  if the string is an `long long`.
 */
@property (readonly, assign, nonatomic) BOOL isLongLongValue;

/*!
 @property		isUnsignedLongLongValue
 @abstract		Checks if the string is a valid 64 bit unsigned long long.
 @result		Returns `YES`  if the string is an `unsigned long long`.
 */
@property (readonly, assign, nonatomic) BOOL isUnsignedLongLongValue;

/*!
 @property		isFloatValue
 @abstract		Checks if the string is a valid 32 bit float.
 @result		Returns `YES`  if the string is an `float`.
 */
@property (readonly, assign, nonatomic) BOOL isFloatValue;

/*!
 @property		isDoubleValue
 @abstract		Checks if the string is a valid 64 bit double.
 @result		Returns `YES`  if the string is an `double`.
 */
@property (readonly, assign, nonatomic) BOOL isDoubleValue;

/*!
 @property		isSystemDateTimeValue
 @abstract		Checks if the string is a valid system date and time.
 @result		Returns `YES`  if the string is valid system date and time.
 */
@property (readonly, assign, nonatomic) BOOL isSystemDateTimeValue;

/*!
 @property		systemDateTimeValue
 @abstract		The string parsed as a system date and time.
 @result		The parsed `NSDate`, or `nil` if the string is not a valid system date and time.
 */
@property (readonly, nullable, nonatomic) NSDate* systemDateTimeValue;

/*!
 @property		isSystemDateValue
 @abstract		Checks if the string is a valid system date.
 @result		Returns `YES`  if the string is valid system date.
 */
@property (readonly, assign, nonatomic) BOOL isSystemDateValue;

/*!
 @property		systemDateValue
 @abstract		The string parsed as a system date.
 @result		The parsed `NSDate`, or `nil` if the string is not a valid system date.
 */
@property (readonly, nullable, nonatomic) NSDate* systemDateValue;

/*!
 @property		isSystemTimeValue
 @abstract		Checks if the string is a valid system time.
 @result		Returns `YES`  if the string is valid system time.
 */
@property (readonly, assign, nonatomic) BOOL isSystemTimeValue;

/*!
 @property		systemTimeValue
 @abstract		The string parsed as a system time.
 @result		The parsed `NSDate`, or `nil` if the string is not a valid system time.
 */
@property (readonly, nullable, nonatomic) NSDate * systemTimeValue;

#pragma mark -

/*!
 @method		-dateWithStyle:
 @abstract		Parses the NSString as a date of a specific style.
 @discussion	Forwards to dateWithStyle:timeStyle: with no timeStyle.
 @param			dateStyle	The style of date to parse the string against.
 @result		The parsed `NSDate`, or `nil` if the string is not a valid date in that style.
 */
- (nullable NSDate *)dateWithStyle:(NSDateFormatterStyle)dateStyle;

/*!
 @method		-timeWithStyle:
 @abstract		Parses the NSString as a time of a specific style.
 @discussion	Forwards to @c dateWithStyle:timeStyle:  with no dateStyle.
 @param			timeStyle	The style of time to parse the string against.
 @result		The parsed `NSDate`, or `nil` if the string is not a valid time in that style.
 */
- (nullable NSDate *)timeWithStyle:(NSDateFormatterStyle)timeStyle;

/*!
 @method		-dateWithStyle:timeStyle:
 @abstract		Parses the NSString as a date and time with specified styles.
 @discussion	This method attempts to parse the string using the specified date and time styles.
 @param	dateStyle	The date style to use for parsing the string.
 @param	timeStyle	The time style to use for parsing the string.

 @result		The parsed `NSDate`, or `nil` if the string is not a valid date/time in those styles.
 */
- (nullable NSDate *)dateWithStyle:(NSDateFormatterStyle)dateStyle timeStyle:(NSDateFormatterStyle)timeStyle;

/*!
 @method		-dateWithFormat:
 @abstract		Parses the NSString as a date with a specific format.
 @discussion	Parses the string using the given `NSDateFormatter` format string.
				If `nil` is passed, the system date format without time is used.
 @param		strFormat	The date format string to use for parsing the string. If `nil`, the system's
						default date format is used.
 @result		The parsed `NSDate`, or `nil` if the string does not match the format.
 */
- (nullable NSDate *)dateWithFormat:(nullable NSString *)strFormat;

/*!
 @method		-objectAtIndexedSubscript:
 @abstract		Provides indexed subscript access to individual characters.
 @discussion	This makes NSStrings act more like C-Strings for accessing characters.
 @param			index	The index of the character to access.
 @result		An `NSNumber` boxing the character at `index`, or `nil` if `index` is out of range.
 */
- (nullable NSNumber *)objectAtIndexedSubscript:(NSUInteger)index;

/*!
 @method		-stringByInsertingString:atIndex:
 @abstract		Returns a new string with a given string inserted at a given index.
 @discussion	Raises `NSInvalidArgumentException` if `location` is greater than the length of the receiver.
 @param			aString		The string to insert. This value must not be `nil`.
 @param			location	The index at which to insert `aString`.
 @result		A new string with `aString` inserted at `location`.
 */
- (nonnull NSString *)stringByInsertingString:(nonnull NSString*)aString atIndex:(NSUInteger)location;

/*!
 @method		-stringByPrependingString:
 @abstract		Returns a new string with a given string prepended to the receiver.
 @discussion	Raises `NSInvalidArgumentException` if `aString` is `nil` or not an `NSString`.
 @param			aString	The string to prepend to the receiver.
 @result		A new string with `aString` prepended.
 */
- (nonnull NSString *)stringByPrependingString:(NSString * _Nonnull)aString;

/*!
 @method		-stringByPrependingFormat:
 @abstract		Returns a new string with a formatted string prepended to the receiver.
 @discussion	Raises `NSInvalidArgumentException` if `format` is `nil` or not an `NSString`.
 @param			format	A format string. This value must not be `nil`.
 @param			...		A comma-separated list of arguments to substitute into `format`.
 @result		A new string with the formatted string prepended.
 */
- (nonnull NSString *)stringByPrependingFormat:(NSString * _Nonnull)format, ... NS_FORMAT_FUNCTION(1,2);

@end




@interface NSMutableString (BExtension)


/*!
 @method		-prependString
 @abstract		Adds to the start of the receiver the characters of a given string.
 @param			aString The string to prepend to the receiver. aString must not be nil
 */
- (void)prependString:(nonnull NSString *)aString;

/*!
 @method		-prependFormat
 @abstract		Adds a constructed string to the start of the receiver.
 @param			format	A format string. See Formatting String Objects for more
						information. This value must not be nil.
 
 @param			...		A comma-separated list of arguments to substitute into
						format.
 */
- (void)prependFormat:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

/*!
 @method		-deleteAll
 @abstract		Removes all the characters and resets the string to @""
 */
- (void)deleteAll;

/*!
 @method		-deleteAtIndex
 @abstract		Deletes the character in the string at the index
 @param			index The index of the character to delete.
 */
- (void)deleteAtIndex:(NSUInteger)index;

@end


/*!
 @category      NSString (CharacterCounter)
 @abstract      Adds methods to `NSString` for counting characters based on an `NSCharacterSet`.
 @discussion	Counting iterates by composed character sequence (so a sequence like an emoji with
				modifiers is visited once), but membership is tested on the FIRST `unichar` of each
				sequence. This means a member in the astral planes (a surrogate pair, e.g. an emoji)
				is tested against its high surrogate and effectively never matches — `NSCharacterSet`
				membership here is reliable only for BMP (single-`unichar`) characters.
*/
@interface NSString (CharacterCounter)

/*!
 @method        countCharactersInSet:
 @abstract      Counts the total number of characters in the receiver that are members of a given set.
 @discussion    Iterates by composed character sequence and tests the first `unichar` of each for
				membership (see the category note about astral-plane characters). Scans the whole string.
 @param         set The set of characters to count.
 @result        The total number of characters found in the string that are members of the set.
*/
- (NSUInteger)countCharactersInSet:(nonnull NSCharacterSet *)set;

/*!
 @method        countCharactersInSet:range:
 @abstract      Counts the number of characters within a specific range of the receiver that are members of a given set.
 @discussion    Iterates by composed character sequence within the range and tests the first `unichar`
				of each for membership (see the category note about astral-plane characters).
 @param         set The set of characters to count.
 @param         range The range of the string to search within.
 @result        The total number of characters found in the specified range that are members of the set. Returns 0 if the range is invalid.
*/
- (NSUInteger)countCharactersInSet:(nonnull NSCharacterSet *)set range:(NSRange)range;
@end

#endif	//	NSString_BExtension_h
