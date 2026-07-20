/*!
 @header		NSArray+BExtension.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		Category extensions for NSArray and NSMutableArray providing additional utility methods.
 @discussion	This header provides category extensions for NSArray and NSMutableArray that add
				functionality for collection conversion, class introspection, array manipulation,
				and functional programming patterns like mapping and filtering.
 */

#ifndef NSArray_BExtension_h
#define NSArray_BExtension_h

#import <Foundation/Foundation.h>


/*!
 @category		NSArray (BExtension)
 @abstract		Category extension for NSArray providing utility methods for collection operations.
 @discussion	This category adds methods for converting arrays to other collection types,
				introspecting object classes, manipulating array contents, and functional
				programming operations like mapping.
 @code
	NSArray *items = @[@"a", @1, @[]];
	NSSet *unique = items.set;                     // unordered, de-duplicated
	NSArray<Class> *kinds = items.objectsClasses;  // one Class per element, in order

	// mapUsingBlock is map + filter in one pass: return NO to drop an element,
	// or mutate *obj and return YES to keep the transformed value.
	NSArray *doubledOdds = [@[@1, @2, @3, @4] mapUsingBlock:^BOOL(id *obj, NSUInteger idx, BOOL *stop) {
		if ([*obj integerValue] % 2 == 0) { return NO; }
		*obj = @([*obj integerValue] * 2);
		return YES;
	}]; // -> @[@2, @6]

	NSArray *merged = [@[@1, @2] arrayByInsertingObjectsFromArray:@[@9] atIndex:1]; // @[@1, @9, @2]
 @endcode
 */
@interface NSArray <ObjectType> (BExtension)

/*!
 @property		orderedSet
 @abstract		Returns an NSOrderedSet containing the elements of the array.
 @discussion	Creates and returns an NSOrderedSet with the same elements as the receiver,
				preserving order while ensuring uniqueness.
 @result		A new NSOrderedSet containing the array's elements.
 */
@property (readonly, strong, nonnull) NSOrderedSet<ObjectType> *orderedSet;

/*!
 @property		set
 @abstract		Returns an NSSet containing the elements of the array.
 @discussion	Creates and returns an NSSet with the same elements as the receiver.
				Duplicate elements will be removed as sets only contain unique objects.
 @result		A new NSSet containing the array's unique elements.
 */
@property (readonly, strong, nonnull) NSSet<ObjectType> *set;

/*!
 @property		objectsClasses
 @abstract		Returns an array of Class objects representing the classes of the array's elements.
 @discussion	Iterates through the array and collects the class of each object using the
				-class method. The resulting array may contain duplicate Class objects if
				multiple elements share the same class.
 @result		A new NSArray containing Class objects corresponding to each element's class.
 */
@property (readonly, nonnull) NSArray<Class> *objectsClasses;

/*!
 @property		objectsClassNames
 @abstract		Returns an array of class name strings for the array's elements.
 @discussion	Iterates through the array and collects the class name of each object using
				the -className method. The resulting array may contain duplicate strings if
				multiple elements share the same class.
 @result		A new NSArray containing NSString objects representing each element's class name.
 */
@property (readonly, nonnull) NSArray<NSString*> *objectsClassNames;

/*!
 @property		objectsUniqueClasses
 @abstract		Returns a counted set of unique Class objects from the array's elements.
 @discussion	Iterates through the array and collects the class of each object, storing
				them in an NSCountedSet which tracks both uniqueness and occurrence count.
				This is useful for analyzing the distribution of object types in the array.
 @result		A new NSCountedSet containing unique Class objects with their occurrence counts.
 */
@property (readonly, nonnull) NSCountedSet<Class> *objectsUniqueClasses;

/*!
 @property		objectsUniqueClassNames
 @abstract		Returns a counted set of unique class name strings from the array's elements.
 @discussion	Iterates through the array and collects the class name of each object using
				the -className method, storing them in an NSCountedSet which tracks both
				uniqueness and occurrence count. Useful for analyzing class distribution.
 @result		A new NSCountedSet containing unique class name strings with their occurrence counts.
 */
@property (readonly, nonnull) NSCountedSet<NSString*> *objectsUniqueClassNames;

/*!
 @method		-toClassesFromStrings
 @abstract		Converts an array of class name strings to an array of Class objects.
 @discussion	Maps each NSString element in the receiver (representing a class name) to the
				corresponding Class object using NSClassFromString. Only valid class names
				that match registered classes are included in the result. Invalid or unknown
				class names return nil and are filtered out.
 @result		A new array containing Class objects corresponding to valid class names
				in the receiver array.
 */
- (nonnull instancetype)toClassesFromStrings;

/*!
 @method		-arrayByInsertingObjectsFromArray:atIndex:
 @abstract		Returns a new array with objects from another array inserted at a specific index.
 @discussion	Creates a new array by inserting all objects from the specified array at the
				given index position. The original array remains unchanged. Objects at and
				after the insertion point are shifted to make room for the new objects.
 @param			otherArray The array containing objects to insert. Must not be nil.
 @param			index The index at which to insert the objects. Must be <= count of receiver.
 @result		A new NSArray containing the receiver's objects with the other array's
				objects inserted at the specified index.
 @exception		NSInvalidArgumentException Thrown if otherArray is nil, not an NSArray,
				or if index is greater than the receiver's count.
 */
- (nonnull NSArray<ObjectType> *) arrayByInsertingObjectsFromArray:(nonnull NSArray<ObjectType> *) otherArray
														   atIndex:(NSUInteger)index;

/*!
 @method		-mapUsingBlock:
 @abstract		Returns a new array by applying a transformation block to each element.
 @discussion	Iterates through the receiver and applies the provided block to each element.
				The block can modify the element and return YES to include it in the result,
				or return NO to exclude it. This provides both mapping and filtering functionality.
 @param			block A block that takes a pointer to the current object, its index, and a
				stop flag. The block should modify the object as needed and return YES to
				include it in the result array, or NO to exclude it.
 @result		A new array containing the transformed elements that returned YES from the block.
				Returns a copy of the receiver if block is nil.
 */
- (nonnull instancetype)mapUsingBlock:(BOOL (^_Nullable)(id _Nullable *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop))block;

@end


/*!
 @category		NSMutableArray (BExtension)
 @abstract		Category extension for NSMutableArray providing additional mutating operations.
 @discussion	This category adds methods for removing elements, inserting multiple objects,
				converting from other collection types, and functional programming operations
				that modify the array in place.
 @code
	NSMutableArray *m = @[@3, @1, @2].mutableCopy;
	[m insertObjects:@[@8, @9] atIndex:0];  // @[@8, @9, @3, @1, @2]
	[m removeFirstObject];                  // @[@9, @3, @1, @2]
	m.set = [NSSet setWithArray:m];          // replace contents from a set (order not preserved)

	// filterUsingBlock mutates in place: return NO to remove, or mutate *obj and return YES to keep.
	[m filterUsingBlock:^BOOL(id *obj, NSUInteger idx, BOOL *stop) {
		return [*obj integerValue] % 2 == 0;   // keep only even numbers
	}];
 @endcode
 */
@interface NSMutableArray <ObjectType> (BExtension)

/*!
 @method		-removeFirstObject
 @abstract		Removes the first object from the array if it exists.
 @discussion	Safely removes the object at index 0 if the array is not empty.
				Does nothing if the array is empty, avoiding index out of bounds exceptions.
 */
- (void)removeFirstObject;

/*!
 @method		-insertObjects:atIndex:
 @abstract		Inserts multiple objects from an array at the specified index.
 @discussion	Inserts all objects from the provided array at the given index position.
				Objects at and after the insertion point are shifted to make room.
				This is a mutating operation that modifies the receiver.
 @param			objects The array containing objects to insert. Must not be nil.
 @param			index The index at which to insert the objects. Must be <= count of receiver.
 @exception		NSInvalidArgumentException Thrown if objects is nil, not an NSArray,
				or if index is greater than the receiver's count.
 */
- (void) insertObjects:(nonnull NSArray<ObjectType> *) objects
			   atIndex:(NSUInteger)index;

/*!
 @property		orderedSet
 @abstract		Gets or sets the array's contents from an NSOrderedSet.
 @discussion	When setting, replaces the array's contents with the ordered set's array.
				When getting, returns an NSOrderedSet containing the array's elements.
				Setting to nil will clear the array.
 */
@property (readwrite, strong, nullable) NSOrderedSet<ObjectType> *orderedSet;

/*!
 @property		set
 @abstract		Gets or sets the array's contents from an NSSet.
 @discussion	When setting, replaces the array's contents with the set's allObjects array.
				When getting, returns an NSSet containing the array's unique elements.
				Setting to nil will clear the array. Note that order is not preserved
				when setting from a set.
 */
@property (readwrite, strong, nullable) NSSet<ObjectType> *set;

/*!
 @method		-filterUsingBlock:
 @abstract		Filters the array in place using a block predicate.
 @discussion	Iterates through the array and applies the provided block to each element.
				Elements for which the block returns YES are kept, while those returning
				NO are removed. This is a mutating operation that modifies the receiver.
 @param			filterBlock A block that takes a pointer to the current object, its index,
				and a stop flag. The block should return YES to keep the element or NO to
				remove it. The object can be modified within the block.
 @result		Returns self after filtering, allowing for method chaining.
 */
- (nonnull instancetype)filterUsingBlock:(BOOL (^_Nullable)(id _Nullable *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop))filterBlock;

@end


#endif // NSArray_BExtension_h
