/*!
 @header		BECharacterSet.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-06-10
 @author		belisoful@icloud.com
 @abstract		This provides differentiable versions of NSCharacterSet and NSMutableCharacterSet.
 @discussion	BECharacterSet is a replacement for NSCharacterSet, and BEMutableCharacterSet is a
				replacement for NSMutableCharacterSet.
 
				NSCharacterSet and NSMutableCharacterSet cannot be told apart programmatically:
				Foundation's class cluster backs both with the same concrete subclass, so even
				instantiating an NSCharacterSet yields an object that is kind-of
				NSMutableCharacterSet.

				BECharacterSet and BEMutableCharacterSet restore the immutable/mutable distinction
				that NSString vs NSMutableString provides, ensuring clear type safety and
				mutability contracts.
 
 @availability	macOS 10.0+, iOS 2.0+, watchOS 2.0+, tvOS 9.0+
*/

#ifndef BECharacterSet_h
#define BECharacterSet_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @typedef		BECharacterSetEquality
 @abstract		Constants that specify whether to equate BECharacterSet instances with NSCharacterSet instances.
 @discussion	This enumeration controls equality behavior for both class-level and instance-level comparisons
				between BECharacterSet/BEMutableCharacterSet and NSCharacterSet/NSMutableCharacterSet objects.
 
 @constant		NSCharacterSetAllUnequal	All instances are never equal to NSCharacterSet instances
 @constant		NSCharacterSetUnequal		This specific instance is not equal to NSCharacterSet instances
 @constant		NSCharacterSetClassStyle	Use the class-level equality setting (default behavior)
 @constant		NSCharacterSetEqual			This specific instance is equal to equivalent NSCharacterSet instances
 @constant		NSCharacterSetAllEqual		All instances are always equal to equivalent NSCharacterSet instances
 */
typedef NS_ENUM(NSInteger, BECharacterSetEquality) {
	NSCharacterSetAllUnequal = -2,
	NSCharacterSetUnequal = -1,
	NSCharacterSetClassStyle = 0,
	NSCharacterSetEqual = 1,
	NSCharacterSetAllEqual = 2
};

/*!
 @class			BECharacterSet
 @superclass	NSObject
 @abstract		An immutable collection of Unicode characters for use in search operations.
 @discussion	BECharacterSet is a replacement for NSCharacterSet that provides clear differentiation
				from its mutable counterpart BEMutableCharacterSet. This class wraps NSCharacterSet
				functionality while maintaining type safety and providing configurable equality
				behavior with NSCharacterSet instances.
 
				Character sets are used primarily to search for and categorize characters in strings.
				They provide an efficient way to represent large sets of characters and perform
				membership tests.
 
				BECharacterSet conforms to NSCopying, NSMutableCopying, and NSSecureCoding protocols,
				making it suitable for use in collections, copying operations, and secure archiving.
 
 @note			Unlike NSCharacterSet, BECharacterSet instances are guaranteed to be immutable.
				Use BEMutableCharacterSet when you need to modify the character set after creation.
 */
@interface BECharacterSet : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
{
	NSCharacterSet *_characterSet;
}

#pragma mark - Properties

/*!
 @property		characterSet
 @abstract		The underlying NSCharacterSet instance.
 @discussion	This property provides access to the wrapped NSCharacterSet for interoperability
				with existing APIs that expect NSCharacterSet instances.
 
 @return		The NSCharacterSet instance wrapped by this BECharacterSet.
 */
@property (nonatomic, readonly, copy) NSCharacterSet *characterSet;

/*!
 @property		isClassEqualToNSCharacterSet
 @abstract		The default equality behavior for all BECharacterSet instances when compared to NSCharacterSet instances.
 @discussion	This class property controls the default equality behavior for BECharacterSet instances
				that haven't explicitly set their individual equality behavior. Individual instances
				can override this setting using the isEqualToNSCharacterSet property.
 
 @see			isEqualToNSCharacterSet
 */
@property (nonatomic, class, readwrite) BECharacterSetEquality isClassEqualToNSCharacterSet;

/*!
 @property		isEqualToNSCharacterSet
 @abstract		The equality behavior for this specific BECharacterSet instance when compared to NSCharacterSet instances.
 @discussion	This property allows individual instances to override the class-level equality setting.
				When set to NSCharacterSetClassStyle (the default), the instance uses the class-level
				setting specified by isClassEqualToNSCharacterSet.
 
 @see			isClassEqualToNSCharacterSet
 */
@property (readwrite) BECharacterSetEquality isEqualToNSCharacterSet;

#pragma mark - Initialization

/*!
 @method		init
 @abstract		Initializes a new BECharacterSet instance with an empty character set.
 @discussion	Creates a new BECharacterSet containing no characters. The equality behavior
				is set based on the current class-level setting, unless the class is configured
				for NSCharacterSetAllUnequal or NSCharacterSetAllEqual, in which case the instance
				setting is set to NSCharacterSetUnequal or NSCharacterSetEqual respectively.
 
 @return		An initialized BECharacterSet instance, or nil if initialization fails.
 */
- (nullable instancetype)init NS_DESIGNATED_INITIALIZER;

/*!
 @method		initWithSet:
 @param			charSet An NSCharacterSet or BECharacterSet instance to copy.
 @abstract		Initializes a new BECharacterSet instance with the characters from another character set.
 @discussion	Creates a new BECharacterSet containing the same characters as the provided character set.
				The method accepts both NSCharacterSet and BECharacterSet instances. The equality behavior
				is set based on the current class-level setting, unless the class is configured
				for NSCharacterSetAllUnequal or NSCharacterSetAllEqual.
 
 @return		An initialized BECharacterSet instance, or nil if initialization fails.
 */
- (nullable instancetype)initWithSet:(id)charSet NS_DESIGNATED_INITIALIZER;

#pragma mark - NSSecureCoding Protocol

/*!
 @method		supportsSecureCoding
 @abstract		Returns whether the class supports secure coding.
 @discussion	BECharacterSet supports secure coding for safe archiving and unarchiving operations.
 
 @return		YES, indicating that BECharacterSet supports secure coding.
 */
+ (BOOL)supportsSecureCoding;

/*!
 @method		initWithCoder:
 @param			coder The decoder to read the character set data from.
 @abstract		Initializes a BECharacterSet instance from archived data.
 @discussion	This designated initializer supports secure decoding of BECharacterSet instances
				from archived data. The method properly handles both BECharacterSet and
				BEMutableCharacterSet encoded data.
 
 @return		An initialized BECharacterSet instance, or nil if decoding fails.
 */
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

/*!
 @method		encodeWithCoder:
 @param			coder The encoder to write the character set data to.
 @abstract		Archives the BECharacterSet instance for secure storage or transmission.
 @discussion	This method supports secure encoding of both BECharacterSet and BEMutableCharacterSet
				instances. The encoded data can be safely transmitted or stored and later decoded
				using initWithCoder:.
 */
- (void)encodeWithCoder:(NSCoder *)coder;

#pragma mark - NSCopying Protocol

/*!
 @method		copyWithZone:
 @param			zone The memory zone to allocate the copy in, or NULL to use the default zone.
 @abstract		Creates an immutable copy of the character set.
 @discussion	Returns a BECharacterSet instance containing the same characters as the receiver.
				If the receiver is already a BECharacterSet, this may return the receiver itself
				since immutable objects can safely share references.
 
 @return		A BECharacterSet instance containing the same characters as the receiver.
 */
- (id)copyWithZone:(nullable NSZone *)zone;

/*!
 @method		mutableCopyWithZone:
 @param			zone The memory zone to allocate the copy in, or NULL to use the default zone.
 @abstract		Creates a mutable copy of the character set.
 @discussion	Returns a BEMutableCharacterSet instance containing the same characters as the receiver.
				The returned object can be modified without affecting the original.
 
 @return		A BEMutableCharacterSet instance containing the same characters as the receiver.
 */
- (id)mutableCopyWithZone:(nullable NSZone *)zone;

#pragma mark - Object Comparison

/*!
 @method		hash
 @abstract		Returns a hash value for the character set.
 @discussion	The hash is the underlying NSCharacterSet's hash and is independent of the
				equality-style setting. isEqual: compares two BECharacterSet instances by their
				characters alone, and can equate a BECharacterSet with a plain NSCharacterSet,
				so every equal pair shares the plain NSCharacterSet hash.

 @return		A hash value for the receiver.
 */
- (NSUInteger)hash;

/*!
 @method		isEqual:
 @param			object The object to compare with the receiver.
 @abstract		Returns whether the receiver is equal to another object.
 @discussion	Two BECharacterSet instances are considered equal if they contain the same characters.
				Equality with NSCharacterSet instances depends on the equality configuration set
				through the isEqualToNSCharacterSet and isClassEqualToNSCharacterSet properties.
 
 @return		YES if the objects are equal, NO otherwise.
 */
- (BOOL)isEqual:(nullable id)object;

#pragma mark - Predefined Character Sets

/*!
 @property		controlCharacterSet
 @abstract		A character set containing control characters.
 @discussion	Returns a character set containing the characters in Unicode General Categories Cc and Cf.
				These characters include control characters to support bi-directional text,
				the soft hyphen (U+00AD), and IETF language tag characters.
 
 @return		A BECharacterSet containing all control characters.
 */
@property (readonly, class, copy) BECharacterSet *controlCharacterSet;

/*!
 @property		whitespaceCharacterSet
 @abstract		A character set containing whitespace characters, excluding newlines.
 @discussion	Returns a character set containing the characters in Unicode General Category Zs
				and CHARACTER TABULATION (U+0009). This set does not include newline or
				carriage return characters.
 
 @return		A BECharacterSet containing whitespace characters.
 @see			whitespaceAndNewlineCharacterSet
 */
@property (readonly, class, copy) BECharacterSet *whitespaceCharacterSet;

/*!
 @property		whitespaceAndNewlineCharacterSet
 @abstract		A character set containing whitespace and newline characters.
 @discussion	Returns a character set containing characters in Unicode General Category Z*,
				U+000A through U+000D, and U+0085. This includes all whitespace characters
				plus newline and carriage return characters.
 
 @return		A BECharacterSet containing whitespace and newline characters.
 @see			whitespaceCharacterSet, newlineCharacterSet
 */
@property (readonly, class, copy) BECharacterSet *whitespaceAndNewlineCharacterSet;

/*!
 @property		decimalDigitCharacterSet
 @abstract		A character set containing decimal digit characters.
 @discussion	Returns a character set containing the characters in the Unicode category of
				Decimal Numbers. These characters represent the decimal values 0 through 9
				and include digits from various scripts such as Indic and Arabic numerals.
 
 @return		A BECharacterSet containing decimal digit characters.
 */
@property (readonly, class, copy) BECharacterSet *decimalDigitCharacterSet;

/*!
 @property		letterCharacterSet
 @abstract		A character set containing letter characters.
 @discussion	Returns a character set containing the characters in Unicode General Categories L* and M*.
				This includes all characters used as letters of alphabets and ideographs.
 
 @return		A BECharacterSet containing letter characters.
 @see			lowercaseLetterCharacterSet, uppercaseLetterCharacterSet
 */
@property (readonly, class, copy) BECharacterSet *letterCharacterSet;

/*!
 @property		lowercaseLetterCharacterSet
 @abstract		A character set containing lowercase letter characters.
 @discussion	Returns a character set containing the characters in Unicode General Category Ll.
				This includes all characters used as lowercase letters in alphabets that
				distinguish between upper and lower case.
 
 @return		A BECharacterSet containing lowercase letter characters.
 @see			uppercaseLetterCharacterSet, letterCharacterSet
 */
@property (readonly, class, copy) BECharacterSet *lowercaseLetterCharacterSet;

/*!
 @property		uppercaseLetterCharacterSet
 @abstract		A character set containing uppercase letter characters.
 @discussion	Returns a character set containing the characters in Unicode General Categories Lu and Lt.
				This includes all characters used as uppercase letters in alphabets that
				distinguish between upper and lower case.
 
 @return		A BECharacterSet containing uppercase letter characters.
 @see			lowercaseLetterCharacterSet, capitalizedLetterCharacterSet
 */
@property (readonly, class, copy) BECharacterSet *uppercaseLetterCharacterSet;

/*!
 @property		nonBaseCharacterSet
 @abstract		A character set containing non-base characters.
 @discussion	Returns a character set containing the characters in Unicode General Category M*.
				This set includes all legal Unicode characters with a non-spacing priority
				greater than 0, typically characters used as modifiers of base characters
				(such as accent marks).
 
 @return		A BECharacterSet containing non-base characters.
 */
@property (readonly, class, copy) BECharacterSet *nonBaseCharacterSet;

/*!
 @property		alphanumericCharacterSet
 @abstract		A character set containing alphanumeric characters.
 @discussion	Returns a character set containing the characters in Unicode General Categories L*, M*, and N*.
				This includes all characters used as basic units of alphabets, syllabaries,
				ideographs, and digits.
 
 @return		A BECharacterSet containing alphanumeric characters.
 @see			letterCharacterSet, decimalDigitCharacterSet
 */
@property (readonly, class, copy) BECharacterSet *alphanumericCharacterSet;

/*!
 @property		decomposableCharacterSet
 @abstract		A character set containing decomposable Unicode characters.
 @discussion	Returns a character set containing individual Unicode characters that can be
				represented as composed character sequences (such as letters with accents),
				according to the "standard decomposition" definition in Unicode 3.2.
				This includes both compatibility characters and pre-composed characters.
 
 @return		A BECharacterSet containing decomposable characters.
 @note			This character set doesn't include the Hangul characters defined in Unicode 2.0.
 */
@property (readonly, class, copy) BECharacterSet *decomposableCharacterSet;

/*!
 @property		illegalCharacterSet
 @abstract		A character set containing illegal Unicode characters.
 @discussion	Returns a character set containing values in the category of Non-Characters
				or characters that have not yet been defined in Unicode 3.2.
 
 @return		A BECharacterSet containing illegal Unicode characters.
 */
@property (readonly, class, copy) BECharacterSet *illegalCharacterSet;

/*!
 @property		punctuationCharacterSet
 @abstract		A character set containing punctuation characters.
 @discussion	Returns a character set containing the characters in Unicode General Category P*.
				This includes all non-whitespace characters used to separate linguistic units
				in scripts, such as periods, dashes, parentheses, and similar punctuation marks.
 
 @return		A BECharacterSet containing punctuation characters.
 */
@property (readonly, class, copy) BECharacterSet *punctuationCharacterSet;

/*!
 @property		capitalizedLetterCharacterSet
 @abstract		A character set containing capitalized letter characters.
 @discussion	Returns a character set containing the characters in Unicode General Category Lt.
				These are titlecase letters, which are used in some scripts where the first
				letter of a word has a special capitalized form.
 
 @return		A BECharacterSet containing capitalized letter characters.
 @see			uppercaseLetterCharacterSet
 */
@property (readonly, class, copy) BECharacterSet *capitalizedLetterCharacterSet;

/*!
 @property		symbolCharacterSet
 @abstract		A character set containing symbol characters.
 @discussion	Returns a character set containing the characters in Unicode General Category S*.
				These characters include mathematical symbols, currency symbols, and other
				symbolic characters like the dollar sign ($) and plus sign (+).
 
 @return		A BECharacterSet containing symbol characters.
 */
@property (readonly, class, copy) BECharacterSet *symbolCharacterSet;

/*!
 @property		newlineCharacterSet
 @abstract		A character set containing newline characters.
 @discussion	Returns a character set containing the newline characters: U+000A through U+000D,
				U+0085, U+2028, and U+2029. This includes line feed, carriage return,
				next line, line separator, and paragraph separator characters.
 
 @return		A BECharacterSet containing newline characters.
 @see			whitespaceAndNewlineCharacterSet
 */
@property (readonly, class, copy) BECharacterSet *newlineCharacterSet API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));

#pragma mark - Factory Methods

/*!
 @method		characterSetWithRange:
 @param			aRange A range of Unicode code points. The location is the first character value,
					   and location + length - 1 is the last character value to include.
 @abstract		Returns a character set containing characters with Unicode values in the specified range.
 @discussion	Creates a character set containing characters whose Unicode values fall within
				the specified range. If the range length is 0, returns an empty character set.
 
				Example usage:
				```objc
				NSRange lcEnglishRange = NSMakeRange('a', 26);
				BECharacterSet *lcEnglishLetters = [BECharacterSet characterSetWithRange:lcEnglishRange];
				```
 
 @return		A BECharacterSet containing characters in the specified Unicode range.
 */
+ (BECharacterSet *)characterSetWithRange:(NSRange)aRange;

/*!
 @method		characterSetWithCharactersInString:
 @param			aString A string containing characters to include in the character set.
 @abstract		Returns a character set containing the characters found in the specified string.
 @discussion	Creates a character set containing all unique characters found in the provided string.
				If the string is empty, returns an empty character set. Duplicate characters
				in the string are only represented once in the resulting set.
 
 @return		A BECharacterSet containing the characters from the string.
 */
+ (BECharacterSet *)characterSetWithCharactersInString:(NSString *)aString;

/*!
 @method		characterSetWithBitmapRepresentation:
 @param			data A bitmap representation of a character set.
 @abstract		Returns a character set created from a bitmap representation.
 @discussion	Creates a character set from binary data representing character membership.
				This method is useful for recreating character sets from saved data or
				external sources.
 
				A bitmap representation consists of:
				- First 8192 bytes: Basic Multilingual Plane (BMP) coverage
				- Additional segments: Each additional Unicode plane (1 byte plane index + 8192 bytes data)
 
				To test for character presence in a bitmap:
				```c
				unsigned char bitmapRep[8192];
				if (bitmapRep[n >> 3] & (1 << (n & 7))) {
					// Character n is present
				}
				```
 
 @return		A BECharacterSet created from the bitmap data.
 @see			bitmapRepresentation
 */
+ (BECharacterSet *)characterSetWithBitmapRepresentation:(NSData *)data;

/*!
 @method		characterSetWithContentsOfFile:
 @param			fName The path to a file containing a bitmap representation. Must end with .bitmap extension.
 @abstract		Returns a character set read from a bitmap file.
 @discussion	Creates a character set by reading bitmap data from the specified file.
				The file must contain a valid bitmap representation as created by the
				bitmapRepresentation property.
 
				This method doesn't cache character sets, so loading the same file multiple
				times will create separate instances. Consider implementing your own caching
				mechanism if you need to load the same character set repeatedly.
 
 @return		A BECharacterSet read from the file, or nil if the file cannot be read or contains invalid data.
 @see			characterSetWithBitmapRepresentation:
 */
+ (nullable BECharacterSet *)characterSetWithContentsOfFile:(NSString *)fName;

#pragma mark - Character Testing

/*!
 @method		characterIsMember:
 @param			aCharacter The 16-bit Unicode character to test.
 @abstract		Returns whether the specified character is a member of the character set.
 @discussion	Tests whether a single Unicode character (limited to the Basic Multilingual Plane)
				is contained in the receiver. For characters outside the BMP, use longCharacterIsMember:.
 
 @return		YES if the character is in the set, NO otherwise.
 @see			longCharacterIsMember:
 */
- (BOOL)characterIsMember:(unichar)aCharacter;

/*!
 @method		longCharacterIsMember:
 @param			theLongChar A 32-bit UTF-32 Unicode character.
 @abstract		Returns whether the specified UTF-32 character is a member of the character set.
 @discussion	Tests whether a UTF-32 character is contained in the receiver. This method
				supports the full Unicode range, including characters outside the Basic
				Multilingual Plane (such as emoji and supplementary characters).
 
 @return		YES if the character is in the set, NO otherwise.
 @see			characterIsMember:
 */
- (BOOL)longCharacterIsMember:(UTF32Char)theLongChar;

#pragma mark - Set Operations

/*!
 @method		isSupersetOfSet:
 @param			theOtherSet The character set to compare against (NSCharacterSet or BECharacterSet).
 @abstract		Returns whether the receiver contains all characters in another character set.
 @discussion	Tests whether the receiver is a superset of the specified character set.
				A character set is a superset of another if it contains all the characters
				that the other set contains (and possibly more).
 
 @return		YES if the receiver is a superset of theOtherSet, NO otherwise.
 */
- (BOOL)isSupersetOfSet:(id)theOtherSet;

/*!
 @method		hasMemberInPlane:
 @param			thePlane The Unicode plane to check (0-16).
 @abstract		Returns whether the character set has any members in the specified Unicode plane.
 @discussion	Tests whether the receiver contains at least one character in the specified
				Unicode plane. Plane 0 is the Basic Multilingual Plane, planes 1-16 are
				supplementary planes containing specialized characters.
 
 @return		YES if the receiver has at least one character in the specified plane, NO otherwise.
 */
- (BOOL)hasMemberInPlane:(uint8_t)thePlane;

#pragma mark - Data Representation

/*!
 @property		bitmapRepresentation
 @abstract		A binary representation of the character set suitable for storage or transmission.
 @discussion	Returns an NSData object containing a bitmap representation of the character set.
				This format can be saved to files, transmitted over networks, or archived.
 
				The bitmap format:
				- 8192 bytes for Basic Multilingual Plane (BMP)
				- For each additional plane: 1 byte plane index + 8192 bytes character data
 
				Example: A set with ASCII and emoji characters would be 16385 bytes
				(8192 for BMP + 1 byte for plane 1 index + 8192 for Supplementary Multilingual Plane).
 
 @return		Binary data representing the character set.
 @see			characterSetWithBitmapRepresentation:
 */
@property (readonly, copy) NSData *bitmapRepresentation;

/*!
 @property		invertedSet
 @abstract		A character set containing all characters not in the receiver.
 @discussion	Returns a new character set that contains exactly those characters that are
				not in the receiver. This operation is efficient for immutable character sets.
 
 @return		A BECharacterSet containing the inverse of the receiver's characters.
 @note			Using invertedSet on an immutable character set is more efficient than
				using the invert method on a mutable character set.
 */
@property (readonly, copy) BECharacterSet *invertedSet;

@end

#pragma mark - BEMutableCharacterSet

/*!
 @class			BEMutableCharacterSet
 @superclass	BECharacterSet
 @abstract		A mutable collection of Unicode characters for use in search operations.
 @discussion	BEMutableCharacterSet is a replacement for NSMutableCharacterSet that provides
				clear differentiation from its immutable counterpart BECharacterSet. This class
				extends BECharacterSet with methods for modifying the set of characters after creation.
 
				Mutable character sets allow you to build character sets incrementally by adding
				and removing characters, ranges, or entire strings. They also support set operations
				like union and intersection.
 
 @note			BEMutableCharacterSet maintains the same equality configuration behavior as
				BECharacterSet through inheritance.
 */
@interface BEMutableCharacterSet : BECharacterSet <NSCopying, NSMutableCopying, NSSecureCoding>

#pragma mark - Properties

/*!
 @property		characterSet
 @abstract		The underlying NSMutableCharacterSet instance.
 @discussion	This property provides read-write access to the wrapped NSMutableCharacterSet.
				Setting this property replaces the entire character set content.
 
 @return		The NSMutableCharacterSet instance wrapped by this BEMutableCharacterSet.
 */
@property (nonatomic, readwrite, copy) NSMutableCharacterSet *characterSet;

#pragma mark - Character Set Management

/*!
 @method		setCharacterSet:
 @param			set The NSCharacterSet or NSMutableCharacterSet to copy.
 @abstract		Replaces the receiver's characters with those from another character set.
 @discussion	Sets the internal character set to a mutable copy of the provided character set.
				This method accepts both NSCharacterSet and NSMutableCharacterSet instances,
				as NSCharacterSet may be internally implemented as NSMutableCharacterSet.
 */
- (void)setCharacterSet:(NSMutableCharacterSet *)set;

#pragma mark - Adding Characters

/*!
 @method		addCharactersInRange:
 @param			aRange The range of Unicode values to add. If length is 0, no characters are added.
 @abstract		Adds characters in the specified Unicode range to the character set.
 @discussion	Adds all characters whose Unicode values fall within the specified range.
				The range location is the first character value, and location + length - 1
				is the last character value to add.
 
				Example:
				```objc
				NSRange lcEnglishRange = NSMakeRange('a', 26);
				[mutableCharSet addCharactersInRange:lcEnglishRange];
				```
 */
- (void)addCharactersInRange:(NSRange)aRange;

/*!
 @method		addCharactersInString:
 @param			aString The string containing characters to add.
 @abstract		Adds all characters found in the specified string to the character set.
 @discussion	Adds each unique character from the string to the character set. If the string
				contains duplicate characters, they are only added once. If the string is empty,
				this method has no effect.
 */
- (void)addCharactersInString:(NSString *)aString;

#pragma mark - Removing Characters

/*!
 @method		removeCharactersInRange:
 @param			aRange The range of Unicode values to remove. If length is 0, no characters are removed.
 @abstract		Removes characters in the specified Unicode range from the character set.
 @discussion	Removes all characters whose Unicode values fall within the specified range.
				Characters not in the set are ignored.
 */
- (void)removeCharactersInRange:(NSRange)aRange;

/*!
 @method		removeCharactersInString:
 @param			aString The string containing characters to remove.
 @abstract		Removes all characters found in the specified string from the character set.
 @discussion	Removes each character from the string from the character set. Characters not
				in the set are ignored. If the string is empty, this method has no effect.
 */
- (void)removeCharactersInString:(NSString *)aString;

#pragma mark - Set Operations

/*!
 @method		formIntersectionWithCharacterSet:
 @param			otherSet The character set to intersect with (NSCharacterSet or BECharacterSet).
 @abstract		Modifies the receiver to contain only characters present in both sets.
 @discussion	Performs an intersection operation, keeping only characters that exist in both
				the receiver and the other character set. Characters that exist in only one
				of the sets are removed from the receiver.
 */
- (void)formIntersectionWithCharacterSet:(id)otherSet;

/*!
 @method		formUnionWithCharacterSet:
 @param			otherSet The character set to union with (NSCharacterSet or BECharacterSet).
 @abstract		Modifies the receiver to contain all characters from both sets.
 @discussion	Performs a union operation, adding all characters from the other character set
				to the receiver. The result contains all characters that exist in either set.
 */
- (void)formUnionWithCharacterSet:(id)otherSet;

/*!
 @method		invert
 @abstract		Replaces all characters in the receiver with all characters not previously in the set.
 @discussion	Inverts the character set so that it contains exactly those characters that
				were not previously members, and no longer contains any characters that were
				previously members. This operation affects all Unicode planes.
 
 @note			Inverting a mutable character set is less efficient than using the invertedSet
				property on an immutable character set.
 */
- (void)invert;

#pragma mark - Mutable Predefined Character Sets

/*!
 @method		controlCharacterSet
 @abstract		Returns a mutable character set containing control characters.
 @discussion	Returns a mutable copy of the control character set containing characters
				in Unicode General Categories Cc and Cf.
 @return		A BEMutableCharacterSet containing control characters.
 @see			BECharacterSet.controlCharacterSet
 */
+ (BEMutableCharacterSet *)controlCharacterSet;

/*!
 @method		whitespaceCharacterSet
 @abstract		Returns a mutable character set containing whitespace characters.
 @discussion	Returns a mutable copy of the whitespace character set containing characters
				in Unicode General Category Zs and CHARACTER TABULATION (U+0009).
 @return		A BEMutableCharacterSet containing whitespace characters.
 @see			BECharacterSet.whitespaceCharacterSet
 */
+ (BEMutableCharacterSet *)whitespaceCharacterSet;

/*!
 @method		whitespaceAndNewlineCharacterSet
 @abstract		Returns a mutable character set containing whitespace and newline characters.
 @discussion	Returns a mutable copy of the whitespace and newline character set containing
				characters in Unicode General Category Z*, U+000A through U+000D, and U+0085.
 @return		A BEMutableCharacterSet containing whitespace and newline characters.
 @see			BECharacterSet.whitespaceAndNewlineCharacterSet
 */
+ (BEMutableCharacterSet *)whitespaceAndNewlineCharacterSet;

/*!
 @method		decimalDigitCharacterSet
 @abstract		Returns a mutable character set containing decimal digit characters.
 @discussion	Returns a mutable copy of the decimal digit character set containing characters
				in the Unicode category of Decimal Numbers.
 @return		A BEMutableCharacterSet containing decimal digit characters.
 @see			BECharacterSet.decimalDigitCharacterSet
 */
+ (BEMutableCharacterSet *)decimalDigitCharacterSet;

/*!
 @method		letterCharacterSet
 @abstract		Returns a mutable character set containing letter characters.
 @discussion	Returns a mutable copy of the letter character set containing characters
				in Unicode General Categories L* and M*.
 @return		A BEMutableCharacterSet containing letter characters.
 @see			BECharacterSet.letterCharacterSet
 */
+ (BEMutableCharacterSet *)letterCharacterSet;

/*!
 @method		lowercaseLetterCharacterSet
 @abstract		Returns a mutable character set containing lowercase letter characters.
 @discussion	Returns a mutable copy of the lowercase letter character set containing
				characters in Unicode General Category Ll.
 @return		A BEMutableCharacterSet containing lowercase letter characters.
 @see			BECharacterSet.lowercaseLetterCharacterSet
 */
+ (BEMutableCharacterSet *)lowercaseLetterCharacterSet;

/*!
 @method		uppercaseLetterCharacterSet
 @abstract		Returns a mutable character set containing uppercase letter characters.
 @discussion	Returns a mutable copy of the uppercase letter character set containing
				characters in Unicode General Categories Lu and Lt.
 @return		A BEMutableCharacterSet containing uppercase letter characters.
 @see			BECharacterSet.uppercaseLetterCharacterSet
 */
+ (BEMutableCharacterSet *)uppercaseLetterCharacterSet;

/*!
 @method		nonBaseCharacterSet
 @abstract		Returns a mutable character set containing non-base characters.
 @discussion	Returns a mutable copy of the non-base character set containing characters
				in Unicode General Category M*.
 @return		A BEMutableCharacterSet containing non-base characters.
 @see			BECharacterSet.nonBaseCharacterSet
 */
+ (BEMutableCharacterSet *)nonBaseCharacterSet;

/*!
 @method		alphanumericCharacterSet
 @abstract		Returns a mutable character set containing alphanumeric characters.
 @discussion	Returns a mutable copy of the alphanumeric character set containing characters
				in Unicode General Categories L*, M*, and N*.
 @return		A BEMutableCharacterSet containing alphanumeric characters.
 @see			BECharacterSet.alphanumericCharacterSet
 */
+ (BEMutableCharacterSet *)alphanumericCharacterSet;

/*!
 @method		decomposableCharacterSet
 @abstract		Returns a mutable character set containing decomposable Unicode characters.
 @discussion	Returns a mutable copy of the decomposable character set containing individual
				Unicode characters that can be represented as composed character sequences.
 @return		A BEMutableCharacterSet containing decomposable characters.
 @see			BECharacterSet.decomposableCharacterSet
 */
+ (BEMutableCharacterSet *)decomposableCharacterSet;

/*!
 @method		illegalCharacterSet
 @abstract		Returns a mutable character set containing illegal Unicode characters.
 @discussion	Returns a mutable copy of the illegal character set containing values in
				the category of Non-Characters or undefined characters in Unicode 3.2.
 @return		A BEMutableCharacterSet containing illegal Unicode characters.
 @see			BECharacterSet.illegalCharacterSet
 */
+ (BEMutableCharacterSet *)illegalCharacterSet;

/*!
 @method		punctuationCharacterSet
 @abstract		Returns a mutable character set containing punctuation characters.
 @discussion	Returns a mutable copy of the punctuation character set containing characters
				in Unicode General Category P*.
 @return		A BEMutableCharacterSet containing punctuation characters.
 @see			BECharacterSet.punctuationCharacterSet
 */
+ (BEMutableCharacterSet *)punctuationCharacterSet;

/*!
 @method		capitalizedLetterCharacterSet
 @abstract		Returns a mutable character set containing capitalized letter characters.
 @discussion	Returns a mutable copy of the capitalized letter character set containing
				characters in Unicode General Category Lt.
 @return		A BEMutableCharacterSet containing capitalized letter characters.
 @see			BECharacterSet.capitalizedLetterCharacterSet
 */
+ (BEMutableCharacterSet *)capitalizedLetterCharacterSet;

/*!
 @method		symbolCharacterSet
 @abstract		Returns a mutable character set containing symbol characters.
 @discussion	Returns a mutable copy of the symbol character set containing characters
				in Unicode General Category S*.
 @return		A BEMutableCharacterSet containing symbol characters.
 @see			BECharacterSet.symbolCharacterSet
 */
+ (BEMutableCharacterSet *)symbolCharacterSet;

/*!
 @method		newlineCharacterSet
 @abstract		Returns a mutable character set containing newline characters.
 @discussion	Returns a mutable copy of the newline character set containing newline
				characters: U+000A through U+000D, U+0085, U+2028, and U+2029.
 @return		A BEMutableCharacterSet containing newline characters.
 @see			BECharacterSet.newlineCharacterSet
 */
+ (BEMutableCharacterSet *)newlineCharacterSet API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));

#pragma mark - Mutable Factory Methods

/*!
 @method		characterSetWithRange:
 @param			aRange A range of Unicode code points to include in the character set.
 @abstract		Returns a mutable character set containing characters in the specified Unicode range.
 @discussion	Creates a mutable character set containing characters whose Unicode values
				fall within the specified range. The returned set can be modified after creation.
 @return		A BEMutableCharacterSet containing characters in the specified range.
 @see			BECharacterSet.characterSetWithRange:
 */
+ (BEMutableCharacterSet *)characterSetWithRange:(NSRange)aRange;

/*!
 @method		characterSetWithCharactersInString:
 @param			aString A string containing characters to include in the character set.
 @abstract		Returns a mutable character set containing characters from the specified string.
 @discussion	Creates a mutable character set containing all unique characters found in
				the provided string. The returned set can be modified after creation.
 @return		A BEMutableCharacterSet containing characters from the string.
 @see			BECharacterSet.characterSetWithCharactersInString:
 */
+ (BEMutableCharacterSet *)characterSetWithCharactersInString:(NSString *)aString;

/*!
 @method		characterSetWithBitmapRepresentation:
 @param			data A bitmap representation of a character set.
 @abstract		Returns a mutable character set created from a bitmap representation.
 @discussion	Creates a mutable character set from binary data representing character
				membership. The returned set can be modified after creation.
 @return		A BEMutableCharacterSet created from the bitmap data.
 @see			BECharacterSet.characterSetWithBitmapRepresentation:
 */
+ (BEMutableCharacterSet *)characterSetWithBitmapRepresentation:(NSData *)data;

/*!
 @method		characterSetWithContentsOfFile:
 @param			fName The path to a file containing a bitmap representation.
 @abstract		Returns a mutable character set read from a bitmap file.
 @discussion	Creates a mutable character set by reading bitmap data from the specified file.
				The returned set can be modified after creation.
 @return		A BEMutableCharacterSet read from the file, or nil if the file cannot be read.
 @see			BECharacterSet.characterSetWithContentsOfFile:
 */
+ (nullable BEMutableCharacterSet *)characterSetWithContentsOfFile:(NSString *)fName;

@end

NS_ASSUME_NONNULL_END

#endif /* BECharacterSet_h */
