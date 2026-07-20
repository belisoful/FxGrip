/*!
 @header		NSDictionary+BExtension.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
@abstract		An extension to NSDictionary and NSMutableDictionary providing collection manipulation, indexed subscripting, and recursive merging capabilities.
@discussion		This extension adds functional programming methods to NSDictionary and NSMutableDictionary, including indexed access, object class inspection, dictionary mapping and filtering, and recursive merging operations. The extension adds commonly needed operations to the native Foundation dictionary classes while following Apple's design patterns and conventions.
*/

#ifndef NSDictionary_BExtension_h
#define NSDictionary_BExtension_h

#import <Foundation/Foundation.h>

/*!
 @enum BEDictionaryCombineFlags
 @abstract Options for controlling how dictionaries are combined during recursive merge operations.
 @constant BEDictionaryDefaultCombineFlags Default behavior with no special flags.
 @constant BEDictionaryMergeEntriesFlag When set, existing entries are preserved (merge behavior). When clear, existing entries are overwritten (add behavior).
 @constant BEDictionarySelfMutableCollectionFlag When set, immutable collections in the target dictionary are converted to mutable versions during merging.
 @constant BEDictionaryMutableCollectionCopyFlag When set, collection objects conforming to BECollectionAbstract are copied as mutable versions.
 @constant BEDictionaryMutableCopyFlag When set, objects conforming to NSMutableCopying are copied as mutable versions.
 */
typedef NS_ENUM(NSInteger, BEDictionaryCombineFlags) {
	BEDictionaryDefaultCombineFlags = 0,
	BEDictionaryMergeEntriesFlag = (1 << 0),
	BEDictionarySelfMutableCollectionFlag = (1 << 1),
	BEDictionaryMutableCollectionCopyFlag = (1 << 2),
	BEDictionaryMutableCopyFlag = (1 << 3),
};

/*!
 @category NSDictionary(BExtension)
 @abstract Extensions to NSDictionary providing indexed access, object inspection, and functional programming methods.
 @discussion This category adds methods for indexed subscripting, extracting class information from dictionary values, transforming dictionaries through mapping operations, and creating new dictionaries by combining existing ones. All methods maintain immutability of the original dictionary.
 @code
	NSDictionary *d = @{@"a": @1, @"b": @2, @"c": @3};

	// map + filter over key/value pairs: keep odd values, doubled.
	NSDictionary *oddsDoubled = [d mapUsingBlock:^BOOL(id *key, id *obj, BOOL *stop) {
		if ([*obj integerValue] % 2 == 0) { return NO; }
		*obj = @([*obj integerValue] * 2);
		return YES;
	}]; // -> @{@"a": @2, @"c": @6}

	NSDictionary *flipped = d.swapped;                       // @{@1:@"a", @2:@"b", @3:@"c"}
	NSDictionary *merged = [d dictionaryByMergingDictionary:@{@"a": @9, @"z": @0}]; // keeps @"a":@1, adds @"z":@0
 @endcode
 */
@interface NSDictionary<KeyType, ObjectType> (BExtension)

/*!
 @method objectAtIndexedSubscript:
 @abstract Provides indexed subscript access to dictionary values using numeric indices.
 @param idx The index to retrieve the value for.
 @return The object at the specified index, or nil if not found.
 @discussion This method first attempts to find a value using the index as an NSNumber key, then falls back to using the string representation of the index. This enables array-like access patterns for dictionaries with numeric or string-numeric keys.
 */
- (nullable ObjectType)objectAtIndexedSubscript:(NSUInteger)idx;

/*!
 @property objectsClasses
 @abstract A dictionary mapping the receiver's keys to the classes of their corresponding values.
 @return A new NSDictionary where keys are preserved and values are the Class objects of the original values.
 @discussion This property creates a new dictionary that maintains the same key structure while replacing each value with its corresponding Class object, useful for type inspection and validation.
 */
@property (readonly, nonnull) NSDictionary<KeyType, Class> *objectsClasses;

/*!
 @property objectsClassNames
 @abstract A dictionary mapping the receiver's keys to the class names of their corresponding values.
 @return A new NSDictionary where keys are preserved and values are NSString representations of the original values' class names.
 @discussion This property creates a new dictionary that maintains the same key structure while replacing each value with its class name as a string, useful for debugging and serialization.
 */
@property (readonly, nonnull) NSDictionary<KeyType, NSString*> *objectsClassNames;

/*!
 @property objectsUniqueClasses
 @abstract A counted set of the unique classes represented by the dictionary's values.
 @return A new NSCountedSet containing Class objects with their occurrence counts.
 @discussion This property analyzes all values in the dictionary and returns a counted set showing how many times each class appears, useful for understanding the type distribution of dictionary contents.
 */
@property (readonly, nonnull) NSCountedSet<Class> *objectsUniqueClasses;

/*!
 @property objectsUniqueClassNames
 @abstract A counted set of the unique class names represented by the dictionary's values.
 @return A new NSCountedSet containing NSString class names with their occurrence counts.
 @discussion This property analyzes all values in the dictionary and returns a counted set showing how many times each class name appears, useful for debugging and analyzing dictionary content types.
 */
@property (readonly, nonnull) NSCountedSet<NSString*> *objectsUniqueClassNames;

/*!
 @method toClassesFromStrings
 @abstract Converts string values representing class names to their corresponding Class objects.
 @return A new dictionary with the same keys but Class objects as values where possible.
 @discussion This method processes each value in the dictionary, converting NSString values that represent valid class names into their corresponding Class objects using NSClassFromString. Non-string values or invalid class names are filtered out.
 */
- (nonnull instancetype)toClassesFromStrings;

/*!
 @method mapUsingBlock:
 @abstract Creates a new dictionary by applying a transformation block to each key-value pair.
 @param block A block that takes pointers to the key and value, allowing modification, and returns YES to include the pair in the result.
 @return A new dictionary containing the transformed key-value pairs.
 @discussion This method provides functional mapping capabilities, allowing both keys and values to be transformed. The block can modify the key and value through the provided pointers and should return YES to include the pair in the result dictionary.
 */
- (nonnull instancetype)mapUsingBlock:(BOOL (^_Nullable)(id _Nullable *_Nonnull key, id _Nullable *_Nonnull obj, BOOL *_Nonnull stop))block;

/*!
 @method swapped
 @abstract Creates a new dictionary with keys and values swapped.
 @return A new dictionary where the original values become keys and original keys become values.
 @discussion This method creates a new dictionary by swapping keys and values. Only values that conform to NSCopying can become keys. Pairs where the value doesn't conform to NSCopying are excluded from the result.
 */
- (nonnull instancetype)swapped;

/*!
 @method dictionaryByAddingDictionary:
 @abstract Creates a new dictionary by adding entries from another dictionary, overwriting existing keys.
 @param otherDictionary The dictionary whose entries should be added.
 @return A new dictionary containing entries from both dictionaries, with otherDictionary taking precedence for duplicate keys.
 @discussion This method creates a new dictionary by combining the receiver with another dictionary. If both dictionaries contain the same key, the value from otherDictionary is used in the result.
 */
- (nonnull id)dictionaryByAddingDictionary:(nonnull NSDictionary *)otherDictionary;

/*!
 @method dictionaryByMergingDictionary:
 @abstract Creates a new dictionary by merging entries from another dictionary, preserving existing keys.
 @param otherDictionary The dictionary whose entries should be merged.
 @return A new dictionary containing entries from both dictionaries, with the receiver taking precedence for duplicate keys.
 @discussion This method creates a new dictionary by combining the receiver with another dictionary. If both dictionaries contain the same key, the value from the receiver is preserved in the result.
 */
- (nonnull id)dictionaryByMergingDictionary:(nonnull NSDictionary *)otherDictionary;

@end

/*!
 @category NSMutableDictionary(BExtension)
 @abstract Extensions to NSMutableDictionary providing indexed access, in-place transformations, and recursive merging capabilities.
 @discussion This category adds methods for indexed subscripting with configurable key types, in-place filtering and swapping operations, and recursive merging that can handle nested dictionary structures with various combining strategies.
 */
@interface NSMutableDictionary<KeyType, ObjectType> (BExtension)

/*!
 @property isIndexedSubscriptNumeric
 @abstract Controls whether indexed subscript operations use numeric keys (NSNumber) or string keys (NSString).
 @discussion When YES, indexed subscript operations use NSNumber keys. When NO, they use NSString representations of indices. The property automatically determines the appropriate type based on existing keys if not explicitly set.
 */
@property (readwrite, nonatomic) BOOL isIndexedSubscriptNumeric;

/*!
 @method setObject:atIndexedSubscript:
 @abstract Sets an object at the specified index using either numeric or string keys based on the isIndexedSubscriptNumeric property.
 @param obj The object to store.
 @param idx The index at which to store the object.
 @discussion This method enables array-like assignment syntax for mutable dictionaries. The key type used depends on the isIndexedSubscriptNumeric property setting.
 */
- (void)setObject:(nonnull ObjectType)obj atIndexedSubscript:(NSUInteger)idx;

/*!
 @method swap
 @abstract Swaps keys and values in place within the mutable dictionary.
 @return The receiver after swapping keys and values.
 @discussion This method modifies the dictionary in place, swapping keys and values. Only pairs where the value conforms to NSCopying can be swapped. Other pairs are removed from the dictionary.
 */
- (nonnull instancetype)swap;

/*!
 @method filterUsingBlock:
 @abstract Filters the dictionary in place using a predicate block.
 @param filterBlock A block that takes pointers to the key and value, allows modification, and returns YES to keep the pair.
 @return The receiver after filtering.
 @discussion This method modifies the dictionary in place, removing key-value pairs for which the block returns NO. The block can also modify keys and values through the provided pointers.
 */
- (nonnull instancetype)filterUsingBlock:(BOOL (^_Nullable)(id _Nullable *_Nonnull key, id _Nullable *_Nonnull obj, BOOL *_Nonnull stop))filterBlock;

/*!
 @method mergeEntriesFromDictionary:
 @abstract Merges entries from another dictionary without overwriting existing keys.
 @param otherDictionary The dictionary whose entries should be merged.
 @discussion This method adds entries from otherDictionary to the receiver, but only for keys that don't already exist in the receiver. Unlike addEntriesFromDictionary:, this method preserves existing values.
 */
- (void)mergeEntriesFromDictionary:(nonnull NSDictionary<KeyType, ObjectType> *)otherDictionary;

/*!
 @method mergeEntriesFromDictionaryRecursive:
 @abstract Recursively merges entries from another dictionary using default combine flags.
 @param otherDictionary The dictionary whose entries should be merged recursively.
 @discussion This method performs a deep merge of nested dictionaries, preserving existing keys at all levels. Nested dictionaries are merged recursively at every level.
 */
- (void)mergeEntriesFromDictionaryRecursive:(nonnull NSDictionary<KeyType, ObjectType> *)otherDictionary;

/*!
 @method mergeEntriesFromDictionaryRecursive:flags:
 @abstract Recursively merges entries from another dictionary with specified combine flags.
 @param otherDictionary The dictionary whose entries should be merged recursively.
 @param combineFlags Options controlling how the merge is performed.
 @discussion This method performs a deep merge of nested dictionaries with customizable behavior. The flags parameter controls whether existing keys are preserved, whether mutable copies are created, and how collection objects are handled.
 */
- (void)mergeEntriesFromDictionaryRecursive:(nonnull NSDictionary<KeyType, ObjectType> *)otherDictionary flags:(BEDictionaryCombineFlags)combineFlags;

/*!
 @method addEntriesFromDictionaryRecursive:
 @abstract Recursively adds entries from another dictionary, overwriting existing keys.
 @param otherDictionary The dictionary whose entries should be added recursively.
 @discussion This method performs a deep merge of nested dictionaries, overwriting existing keys at all levels. Nested dictionaries are merged recursively at every level.
 */
- (void)addEntriesFromDictionaryRecursive:(nonnull NSDictionary<KeyType, ObjectType> *)otherDictionary;

/*!
 @method addEntriesFromDictionaryRecursive:flags:
 @abstract Recursively adds entries from another dictionary with specified combine flags.
 @param otherDictionary The dictionary whose entries should be added recursively.
 @param combineFlags Options controlling how the addition is performed.
 @discussion This method performs a deep merge of nested dictionaries with customizable behavior. The flags parameter controls whether existing keys are overwritten, whether mutable copies are created, and how collection objects are handled.
 */
- (void)addEntriesFromDictionaryRecursive:(nonnull NSDictionary<KeyType, ObjectType> *)otherDictionary flags:(BEDictionaryCombineFlags)combineFlags;

/*!
 @method combineEntriesFromDictionaryRecursive:flags:
 @abstract Core method for recursively combining entries from another dictionary with full flag control.
 @param otherDictionary The dictionary whose entries should be combined.
 @param combineFlags Complete set of flags controlling the combine operation.
 @discussion This is the fundamental method that implements all recursive dictionary combining operations. It handles nested dictionaries, mutable copying, and various merge strategies based on the provided flags.
 */
- (void)combineEntriesFromDictionaryRecursive:(nullable NSDictionary *)otherDictionary flags:(BEDictionaryCombineFlags)combineFlags;

@end

#endif // NSDictionary_BExtension_h
