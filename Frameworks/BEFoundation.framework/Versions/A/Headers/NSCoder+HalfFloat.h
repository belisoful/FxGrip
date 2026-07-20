/*!
 @header		NSCoder+HalfFloat.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		Category extension for NSCoder providing encoding and decoding support for half-precision floats.
 @discussion	This header provides a category extension for NSCoder that adds functionality for
				encoding and decoding half-precision floating-point values (_Float16). The standard
				NSCoder class lacks built-in support for half-precision floats, which are increasingly
				important for memory-efficient applications and GPU computing. This extension fills
				that gap by providing convenient methods that handle the byte-level encoding and
				decoding of _Float16 values.
 */

#ifndef NSCoder_Half_h
#define NSCoder_Half_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @category		NSCoder (HalfFloat)
 @abstract		Category extension for NSCoder providing half-precision float encoding and decoding.
 @discussion	This category adds methods for encoding and decoding half-precision floating-point
				values (_Float16) to NSCoder. Half-precision floats are 16-bit IEEE 754 floating-point
				numbers that provide a good balance between precision and memory usage. They are
				commonly used in graphics programming, machine learning, and other applications where
				memory efficiency is important.

				The implementation stores the value's raw bytes via encodeBytes:length:forKey: and reads
				them back with decodeBytesForKey:returnedLength:, working with all NSCoder subclasses
				including NSKeyedArchiver and NSKeyedUnarchiver. The bytes are stored in the encoding
				platform's native byte order, so an archive round-trips on the same platform; it is not
				byte-swapped for cross-endian portability.
 @code
	// Encode inside -encodeWithCoder::
	[coder encodeHalf:(_Float16)0.5 forKey:@"gain"];

	// Decode inside -initWithCoder::
	_Float16 gain = [coder decodeHalfForKey:@"gain"];   // returns 0 if the key is absent or malformed
 @endcode
 */
@interface NSCoder (HalfFloat)

/*!
 @method		-encodeHalf:forKey:
 @abstract		Encodes a half-precision float value and associates it with a string key.
 @discussion	This method encodes a _Float16 value by converting it to its byte representation
				and storing it using the NSCoder's byte encoding mechanism. The encoded value can
				later be retrieved using decodeHalfForKey: with the same key.
				
				The method stores the value's raw native-endian bytes internally; it does not
				byte-swap for cross-platform portability.
 @param			value The _Float16 half-precision float value to encode.
 @param			key The string key to associate with the encoded value. This key will be used
				to retrieve the value during decoding. Must not be nil.
 @see			decodeHalfForKey:
 */
- (void)encodeHalf:(_Float16)value forKey:(NSString *)key;

/*!
 @method		-decodeHalfForKey:
 @abstract		Decodes a half-precision float value that was previously encoded with encodeHalf:forKey:.
 @discussion	This method retrieves and decodes a _Float16 value that was previously stored
				using encodeHalf:forKey: with the same key. The method handles the conversion
				from the stored byte representation back to a _Float16 value.
				
				If the key is not found, or the stored data is not the correct size for a
				_Float16, the method returns 0 — matching the contract of NSCoder's other
				scalar decoders (decodeFloatForKey:, decodeIntForKey:, …), which all default to
				a zero value for a missing key. As with those, a stored 0 is indistinguishable
				from a missing key; use -containsValueForKey: when you need to tell them apart.
				(A value encoded as NaN does round-trip and decodes back to NaN.)
 @param			key The string key associated with the encoded half-precision float value.
				This should be the same key used when encoding the value.
 @result		Returns the decoded _Float16 value, or 0 if the key is not found or if
				the stored data is invalid.
 @see			encodeHalf:forKey:
 */
- (_Float16)decodeHalfForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

#endif // NSCoder_Half_h
