/*!
 @header		NSCoder+AtIndex.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		A category on NSCoder that provides index-based encoding and decoding methods.
 @discussion	This category extends NSCoder to support encoding and decoding operations
				using integer indices instead of string keys. Each index is internally
				converted to a string representation for use with the underlying NSCoder
				key-based methods. This provides a more convenient API when working with
				sequential or numeric data structures.
*/

#ifndef NSCoder_AtIndex_AtTime_h
#define NSCoder_AtIndex_AtTime_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @category		NSCoder(AtIndex)
 @abstract		Provides index-based encoding and decoding methods for NSCoder.
 @discussion	This category adds methods to NSCoder that allow encoding and decoding
				values using 64-bit unsigned integer indices instead of string keys.
				The indices are converted to string representations internally and used
				with the standard NSCoder key-based methods. This is particularly useful
				for array-like data structures or when working with sequential data.

				Because indices map to decimal string keys ("0", "1", …), do not mix
				index-based and string-key encoding that could collide in the same coder.
 @code
	// Encode a sequence of values by position inside -encodeWithCoder::
	[coder encodeObject:self.name atIndex:0];
	[coder encodeInteger:self.count atIndex:1];
	[coder encodeDouble:self.scale atIndex:2];

	// Decode them back inside -initWithCoder::
	NSString *name = [coder decodeObjectOfClass:NSString.class atIndex:0];
	NSInteger count = [coder decodeIntegerAtIndex:1];
	double scale = [coder decodeDoubleAtIndex:2];
 @endcode
 */
@interface NSCoder (AtIndex)

// MARK: - Index Key Conversion

/*!
 @method		indexKey:
 @abstract		Converts a 64-bit unsigned integer index to its string representation.
 @param			index	The 64-bit unsigned integer index to convert.
 @return		An NSString representation of the index.
 @discussion	This method provides the mapping from integer indices to string keys
				used internally by the encoding and decoding methods. The current
				implementation uses a simple decimal string representation, but
				subclasses could override this to use alternative mapping strategies
				such as hash-based or alphabetic representations.
 */
- (NSString *)indexKey:(uint64_t)index;

// MARK: - Encoding Methods

/*!
 @method		encodeObject:atIndex:
 @abstract		Encodes an object and associates it with the given integer index.
 @param			object	The object to encode. May be nil.
 @param			index	The 64-bit unsigned integer index to associate with the encoded object.
 @discussion	This method encodes the specified object using the underlying
				encodeObject:forKey: method, with the index converted to a string key.
 */
- (void)encodeObject:(nullable id)object atIndex:(uint64_t)index;

/*!
 @method		encodeConditionalObject:atIndex:
 @abstract		Conditionally encodes an object and associates it with the given integer index.
 @param			object	The object to conditionally encode. May be nil.
 @param			index	The 64-bit unsigned integer index to associate with the encoded object.
 @discussion	This method conditionally encodes the specified object, preserving
				common references to it only if it has been unconditionally encoded
				elsewhere. If the object was never encoded unconditionally, decoding
				will return nil. This is useful for handling object graphs with
				shared references while avoiding retain cycles.
 */
- (void)encodeConditionalObject:(nullable id)object atIndex:(uint64_t)index;

/*!
 @method		encodeBool:atIndex:
 @abstract		Encodes a Boolean value and associates it with the given integer index.
 @param			value	The BOOL value to encode.
 @param			index	The 64-bit unsigned integer index to associate with the encoded value.
 */
- (void)encodeBool:(BOOL)value atIndex:(uint64_t)index;

/*!
 @method		encodeInt:atIndex:
 @abstract		Encodes a native C integer value and associates it with the given integer index.
 @param			value	The int value to encode.
 @param			index	The 64-bit unsigned integer index to associate with the encoded value.
 */
- (void)encodeInt:(int)value atIndex:(uint64_t)index;

/*!
 @method		encodeInt32:atIndex:
 @abstract		Encodes a 32-bit integer value and associates it with the given integer index.
 @param			value	The int32_t value to encode.
 @param			index	The 64-bit unsigned integer index to associate with the encoded value.
 */
- (void)encodeInt32:(int32_t)value atIndex:(uint64_t)index;

/*!
 @method		encodeInt64:atIndex:
 @abstract		Encodes a 64-bit integer value and associates it with the given integer index.
 @param			value	The int64_t value to encode.
 @param			index	The 64-bit unsigned integer index to associate with the encoded value.
 */
- (void)encodeInt64:(int64_t)value atIndex:(uint64_t)index;

/*!
 @method		encodeHalf:atIndex:
 @abstract		Encodes a 16-bit floating-point value and associates it with the given integer index.
 @param			value	The _Float16 value to encode.
 @param			index	The 64-bit unsigned integer index to associate with the encoded value.
 @discussion	This method encodes a half-precision floating-point value. Support for
				_Float16 may vary by platform and compiler version.
 */
- (void)encodeHalf:(_Float16)value atIndex:(uint64_t)index;

/*!
 @method		encodeFloat:atIndex:
 @abstract		Encodes a 32-bit floating-point value and associates it with the given integer index.
 @param			value	The float value to encode.
 @param			index	The 64-bit unsigned integer index to associate with the encoded value.
 */
- (void)encodeFloat:(float)value atIndex:(uint64_t)index;

/*!
 @method		encodeDouble:atIndex:
 @abstract		Encodes a 64-bit floating-point value and associates it with the given integer index.
 @param			value	The double value to encode.
 @param			index	The 64-bit unsigned integer index to associate with the encoded value.
 */
- (void)encodeDouble:(double)value atIndex:(uint64_t)index;

/*!
 @method		encodeBytes:length:atIndex:
 @abstract		Encodes a buffer of bytes and associates it with the given integer index.
 @param			bytes	A pointer to the bytes to encode. May be NULL if length is 0.
 @param			length	The number of bytes to encode.
 @param			index	The 64-bit unsigned integer index to associate with the encoded data.
 @discussion	This method encodes a buffer of raw bytes. The bytes are copied into
				the archive, so the original buffer can be safely deallocated after
				encoding completes.
 */
- (void)encodeBytes:(nullable const uint8_t *)bytes length:(NSUInteger)length atIndex:(uint64_t)index;

/*!
 @method		encodeInteger:atIndex:
 @abstract		Encodes an NSInteger value and associates it with the given integer index.
 @param			value	The NSInteger value to encode.
 @param			index	The 64-bit unsigned integer index to associate with the encoded value.
 @discussion	NSInteger is a platform-dependent type that is 32-bit on 32-bit platforms
				and 64-bit on 64-bit platforms.
 */
- (void)encodeInteger:(NSInteger)value atIndex:(uint64_t)index API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));

// MARK: - Value Checking

/*!
 @method		containsValueAtIndex:
 @abstract		Returns whether an encoded value exists for the given integer index.
 @param			index	The 64-bit unsigned integer index to check.
 @return		YES if a value is encoded at the specified index, NO otherwise.
 @discussion	This method allows you to check if a value was previously encoded
				at a specific index before attempting to decode it.
 */
- (BOOL)containsValueAtIndex:(uint64_t)index;

// MARK: - Basic Decoding Methods

/*!
 @method		decodeObjectAtIndex:
 @abstract		Decodes and returns an object that was previously encoded at the given integer index.
 @param			index	The 64-bit unsigned integer index that identifies the object to decode.
 @return		The decoded object, or nil if no object was encoded at the specified index.
 @discussion	This method decodes an object that was previously encoded using
				encodeObject:atIndex: or encodeConditionalObject:atIndex:.
 */
- (nullable id)decodeObjectAtIndex:(uint64_t)index;

/*!
 @method		decodeTopLevelObjectAtIndex:error:
 @abstract		Decodes a top-level object at the given integer index, with error handling.
 @param			index	The 64-bit unsigned integer index that identifies the object to decode.
 @param			error	On return, contains an NSError object if decoding fails, or nil if decoding succeeds.
 @return		The decoded object, or nil if decoding fails.
 @discussion	This method is used for decoding top-level objects from archives with
				error handling. It's particularly useful when working with secure coding.
 */
- (nullable id)decodeTopLevelObjectAtIndex:(uint64_t)index error:(NSError * _Nullable * _Nullable)error API_AVAILABLE(macos(10.11), ios(9.0), watchos(2.0), tvos(9.0)) NS_SWIFT_UNAVAILABLE("Use 'decodeObject(of:, atIndex:)' instead");

/*!
 @method		decodeBoolAtIndex:
 @abstract		Decodes and returns a Boolean value that was previously encoded at the given integer index.
 @param			index	The 64-bit unsigned integer index that identifies the value to decode.
 @return		The decoded Boolean value.
 */
- (BOOL)decodeBoolAtIndex:(uint64_t)index;

/*!
 @method		decodeIntAtIndex:
 @abstract		Decodes and returns an integer value that was previously encoded at the given integer index.
 @param			index	The 64-bit unsigned integer index that identifies the value to decode.
 @return		The decoded integer value.
 @discussion	This method can decode values that were encoded using encodeInt:atIndex:,
				encodeInteger:atIndex:, encodeInt32:atIndex:, or encodeInt64:atIndex:.
 */
- (int)decodeIntAtIndex:(uint64_t)index;

/*!
 @method		decodeInt32AtIndex:
 @abstract		Decodes and returns a 32-bit integer value that was previously encoded at the given integer index.
 @param			index	The 64-bit unsigned integer index that identifies the value to decode.
 @return		The decoded 32-bit integer value.
 */
- (int32_t)decodeInt32AtIndex:(uint64_t)index;

/*!
 @method		decodeInt64AtIndex:
 @abstract		Decodes and returns a 64-bit integer value that was previously encoded at the given integer index.
 @param			index	The 64-bit unsigned integer index that identifies the value to decode.
 @return		The decoded 64-bit integer value.
 */
- (int64_t)decodeInt64AtIndex:(uint64_t)index;

/*!
 @method		decodeHalfAtIndex:
 @abstract		Decodes and returns a 16-bit floating-point value that was previously encoded at the given integer index.
 @param			index	The 64-bit unsigned integer index that identifies the value to decode.
 @return		The decoded _Float16 value.
 @discussion	This method decodes a half-precision floating-point value that was
				previously encoded using encodeHalf:atIndex:.
 */
- (_Float16)decodeHalfAtIndex:(uint64_t)index;

/*!
 @method		decodeFloatAtIndex:
 @abstract		Decodes and returns a floating-point value that was previously encoded at the given integer index.
 @param			index	The 64-bit unsigned integer index that identifies the value to decode.
 @return		The decoded float value.
 @discussion	This method can decode values that were encoded using encodeFloat:atIndex:
				or encodeDouble:atIndex:.
 */
- (float)decodeFloatAtIndex:(uint64_t)index;

/*!
 @method		decodeDoubleAtIndex:
 @abstract		Decodes and returns a double-precision floating-point value that was previously encoded at the given integer index.
 @param			index	The 64-bit unsigned integer index that identifies the value to decode.
 @return		The decoded double value.
 @discussion	This method can decode values that were encoded using encodeFloat:atIndex:
				or encodeDouble:atIndex:.
 */
- (double)decodeDoubleAtIndex:(uint64_t)index;

/*!
 @method		decodeBytesAtIndex:returnedLength:
 @abstract		Decodes and returns a buffer of bytes that was previously encoded at the given integer index.
 @param			index		The 64-bit unsigned integer index that identifies the data to decode.
 @param			lengthp		On return, contains the length of the decoded byte buffer.
 @return		A pointer to the decoded bytes, or NULL if no data was encoded at the specified index.
 @discussion	The returned bytes are immutable and owned by the coder. The buffer's
				length is returned by reference in the lengthp parameter. The returned
				pointer is valid only until the next call to a decode method.
 */
- (nullable const uint8_t *)decodeBytesAtIndex:(uint64_t)index returnedLength:(nullable NSUInteger *)lengthp NS_RETURNS_INNER_POINTER;

/*!
 @method		decodeIntegerAtIndex:
 @abstract		Decodes and returns an NSInteger value that was previously encoded at the given integer index.
 @param			index	The 64-bit unsigned integer index that identifies the value to decode.
 @return		The decoded NSInteger value.
 @discussion	This method can decode values that were encoded using encodeInt:atIndex:,
				encodeInteger:atIndex:, encodeInt32:atIndex:, or encodeInt64:atIndex:.
 */
- (NSInteger)decodeIntegerAtIndex:(uint64_t)index API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));

// MARK: - Secure Coding Methods

/*!
 @method		decodeObjectOfClass:atIndex:
 @abstract		Decodes an object at the given integer index, restricted to the specified class.
 @param			aClass	The expected class of the object being decoded.
 @param			index	The 64-bit unsigned integer index that identifies the object to decode.
 @return		The decoded object, or nil if the object is not of the expected class or decoding fails.
 @discussion	If the coder requires secure coding, this method throws an exception if
				the class to be decoded does not implement NSSecureCoding or is not a
				kind of the specified class. If secure coding is not required, the class
				parameter is ignored.
 */
- (nullable id)decodeObjectOfClass:(Class)aClass atIndex:(uint64_t)index API_AVAILABLE(macos(10.8), ios(6.0), watchos(2.0), tvos(9.0));

/*!
 @method		decodeTopLevelObjectOfClass:atIndex:error:
 @abstract		Decodes a top-level object at the given integer index as an expected type.
 @param			aClass	The expected class of the object being decoded.
 @param			index	The 64-bit unsigned integer index that identifies the object to decode.
 @param			error	On return, contains an NSError object if decoding fails, or nil if decoding succeeds.
 @return		The decoded object, or nil if decoding fails.
 @discussion	If the coder requires secure coding, this method fails if the class
				does not implement NSSecureCoding or if the decoded object's class
				does not match the expected class or its superclasses.
 */
- (nullable id)decodeTopLevelObjectOfClass:(Class)aClass atIndex:(uint64_t)index error:(NSError * _Nullable * _Nullable)error API_AVAILABLE(macos(10.11), ios(9.0), watchos(2.0), tvos(9.0)) NS_SWIFT_UNAVAILABLE("Use 'decodeObject(of:, atIndex:)' instead");

/*!
 @method		decodeArrayOfObjectsOfClass:atIndex:
 @abstract		Decodes an array of objects at the given integer index, restricted to the specified class.
 @param			cls		The expected class of the array elements.
 @param			index	The 64-bit unsigned integer index that identifies the array to decode.
 @return		An NSArray containing objects of the specified class, or nil if decoding fails.
 @discussion	This method decodes an NSArray whose elements are all of the specified
				class. The array must contain only non-collection objects (no nested
				arrays or dictionaries). Requires secure coding.
 */
- (nullable NSArray *)decodeArrayOfObjectsOfClass:(Class)cls atIndex:(uint64_t)index API_AVAILABLE(macos(11.0), ios(14.0), watchos(7.0), tvos(14.0)) NS_REFINED_FOR_SWIFT;

/*!
 @method		decodeDictionaryWithKeysOfClass:objectsOfClass:atIndex:
 @abstract		Decodes a dictionary at the given integer index, restricted to the specified key and object classes.
 @param			keyCls		The expected class of the dictionary keys.
 @param			objectCls	The expected class of the dictionary values.
 @param			index		The 64-bit unsigned integer index that identifies the dictionary to decode.
 @return		An NSDictionary with keys and values of the specified classes, or nil if decoding fails.
 @discussion	This method decodes an NSDictionary whose keys and values are all of
				the specified classes. Requires secure coding.
 */
- (nullable NSDictionary *)decodeDictionaryWithKeysOfClass:(Class)keyCls objectsOfClass:(Class)objectCls atIndex:(uint64_t)index API_AVAILABLE(macos(11.0), ios(14.0), watchos(7.0), tvos(14.0)) NS_REFINED_FOR_SWIFT;

/*!
 @method		decodeObjectOfClasses:atIndex:
 @abstract		Decodes an object at the given integer index, restricted to the specified set of classes.
 @param			classes	An NSSet containing the expected classes of the object being decoded.
 @param			index	The 64-bit unsigned integer index that identifies the object to decode.
 @return		The decoded object, or nil if the object is not of an expected class or decoding fails.
 @discussion	The decoded object's class may be any class in the classes set, or a
				subclass of any class in the set. Otherwise, the behavior is the same
				as decodeObjectOfClass:atIndex:.
 */
- (nullable id)decodeObjectOfClasses:(nullable NSSet<Class> *)classes atIndex:(uint64_t)index API_AVAILABLE(macos(10.8), ios(6.0), watchos(2.0), tvos(9.0)) NS_REFINED_FOR_SWIFT;

/*!
 @method		decodeTopLevelObjectOfClasses:atIndex:error:
 @abstract		Decodes a top-level object at the given integer index as one of several expected types.
 @param			classes	An NSSet containing the expected classes that the object should match.
 @param			index	The 64-bit unsigned integer index that identifies the object to decode.
 @param			error	On return, contains an NSError object if decoding fails, or nil if decoding succeeds.
 @return		The decoded object, or nil if decoding fails.
 @discussion	This method allows you to specify multiple acceptable classes for the
				decoded object. If secure coding is required, the decoded object's class
				must be a member of the classes set or a subclass of a member.
 */
- (nullable id)decodeTopLevelObjectOfClasses:(nullable NSSet<Class> *)classes atIndex:(uint64_t)index error:(NSError * _Nullable * _Nullable)error API_AVAILABLE(macos(10.11), ios(9.0), watchos(2.0), tvos(9.0)) NS_SWIFT_UNAVAILABLE("Use 'decodeObject(of:, atIndex:)' instead");

/*!
 @method		decodeArrayOfObjectsOfClasses:atIndex:
 @abstract		Decodes an array of objects at the given integer index, restricted to the specified set of classes.
 @param			classes	An NSSet containing the expected classes of the array elements.
 @param			index	The 64-bit unsigned integer index that identifies the array to decode.
 @return		An NSArray containing objects of the specified classes, or nil if decoding fails.
 @discussion	This method decodes an NSArray whose elements are all of one of the
				specified classes. The array must contain only non-collection objects
				(no nested arrays or dictionaries). Requires secure coding.
 */
- (nullable NSArray *)decodeArrayOfObjectsOfClasses:(NSSet<Class> *)classes atIndex:(uint64_t)index API_AVAILABLE(macos(11.0), ios(14.0), watchos(7.0), tvos(14.0)) NS_REFINED_FOR_SWIFT;

/*!
 @method		decodeDictionaryWithKeysOfClasses:objectsOfClasses:atIndex:
 @abstract		Decodes a dictionary at the given integer index, restricted to the specified sets of key and object classes.
 @param			keyClasses		An NSSet containing the expected classes of the dictionary keys.
 @param			objectClasses	An NSSet containing the expected classes of the dictionary values.
 @param			index			The 64-bit unsigned integer index that identifies the dictionary to decode.
 @return		An NSDictionary with keys and values of the specified classes, or nil if decoding fails.
 @discussion	This method decodes an NSDictionary whose keys and values are all of
				one of the specified classes. Requires secure coding.
 */
- (nullable NSDictionary *)decodeDictionaryWithKeysOfClasses:(NSSet<Class> *)keyClasses objectsOfClasses:(NSSet<Class> *)objectClasses atIndex:(uint64_t)index API_AVAILABLE(macos(11.0), ios(14.0), watchos(7.0), tvos(14.0)) NS_REFINED_FOR_SWIFT;

/*!
 @method		decodePropertyListAtIndex:
 @abstract		Decodes a property list at the given integer index.
 @param			index	The 64-bit unsigned integer index that identifies the property list to decode.
 @return		The decoded property list object, or nil if decoding fails.
 @discussion	This method decodes a property list (containing only NSString, NSNumber,
				NSDate, NSData, NSArray, and NSDictionary objects) that was previously
				encoded at the specified index.
 */
- (nullable id)decodePropertyListAtIndex:(uint64_t)index API_AVAILABLE(macos(10.8), ios(6.0), watchos(2.0), tvos(9.0));

@end

NS_ASSUME_NONNULL_END

#endif	// NSCoder_AtIndex_AtTime_h
