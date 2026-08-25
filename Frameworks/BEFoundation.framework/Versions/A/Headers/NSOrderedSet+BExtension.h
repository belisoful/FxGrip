/*!
 @header		NSOrderedSet+BExtension.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		NSOrderedSet and NSMutableOrderedSet BExtension category
				provides mapping, filtering, and object metadata like Class and
				className.
 @discussion	The BExtension category provides missing functionality to the
				Core Foundation.
*/

#ifndef NSOrderedSet_Extension_h
#define NSOrderedSet_Extension_h

#import <Foundation/Foundation.h>

/*!
 @category		BExtension
 @abstract		Adds set mapping, filtering, and object meta functionality.
 @discussion	This category provides map, filter, and objects meta-data methods.
 
 The following methods are provided by this category to `NSOrderedSet`:

 `-mapUsingBlock:`: Maps all objects to a new ordered set, removing `NULL` mappings and not passing.

 `-objectsClasses`:  An ordered set of the objects' distinct `Class` (deduped, in order, no counts).

 `-objectsClassNames`:  An ordered set of the objects' distinct `className` (deduped, in order, no counts).

 `-objectsUniqueClasses`:  An `NSCountedSet` of the objects' `Class` with occurrence counts.

 `-objectsUniqueClassNames`:  An `NSCountedSet` of the objects' `className` with occurrence counts.

 `-toClassesFromStrings`: Converts an ordered set of `NSString` into their `Class`.

 The following methods are provided by this category to `NSMutableOrderedSet`:

 `-filterUsingBlock:`: filters the ordered set in place, removing `NULL` mappings and rejected objects.
 Also adds `-intersectArray:`, the readwrite `array` and `set` properties (setters `be_setArray:`/`be_setSet:`), `-removeFirstElement`, `-removeLastElement`.

 @code
	NSOrderedSet *os = [NSOrderedSet orderedSetWithArray:@[@1, @2, @3, @4]];
	NSOrderedSet *evens = [os mapUsingBlock:^BOOL(id *obj, NSUInteger idx, BOOL *stop) {
		return [*obj integerValue] % 2 == 0;   // keep evens, in order; {@2, @4}
	}];

	NSMutableOrderedSet *m = os.mutableCopy;
	[m intersectArray:@[@2, @3, @9]];   // {@2, @3}
	[m filterUsingBlock:^BOOL(id *obj, NSUInteger idx, BOOL *stop) { return [*obj integerValue] > 2; }]; // {@3}
 @endcode
 */
@interface NSOrderedSet <ObjectType> (BExtension)

/*!
 @property		objectsClasses
 @abstract		Gets the distinct `class` of the objects, in order.
 @discussion 	Loops through each object, collecting `[obj class]` into an ordered set — so classes
				are deduplicated and kept in first-encounter order, with NO counts. Use
				`objectsUniqueClasses` for occurrence counts.
 @result		A new `NSOrderedSet<Class>` of the objects' distinct classes, in order.
 */
@property (readonly, nonnull) NSOrderedSet<Class> *objectsClasses;

/*!
 @property		objectsClassNames
 @abstract		Gets the distinct `className` of the objects, in order.
 @discussion 	Loops through each object, collecting `[obj className]` into an ordered set — so class
				names are deduplicated and kept in first-encounter order, with NO counts. Use
				`objectsUniqueClassNames` for occurrence counts.
 @result		A new `NSOrderedSet<NSString*>` of the objects' distinct class names, in order.
 */
@property (readonly, nonnull) NSOrderedSet<NSString*> *objectsClassNames;

/*!
 @property		objectsUniqueClasses
 @abstract		Gets the unique `class` of the objects in the ordered set and
				how many of each there are.
 @discussion 	This loops through each object in the ordered set and gets their
				`class`.  It adds each object class to the NSCountedSet.
 @result		A new `NSCountedSet<Class>`  of the objects' classes and their
				count.
 */
@property (readonly, nonnull) NSCountedSet<Class> *objectsUniqueClasses;

/*!
 @property		objectsUniqueClassNames
 @abstract		Gets the unique `className` of the objects in the ordered set
				and how many of each there are.
 @discussion 	This loops through each object in the ordered set and gets their
				`className`.  It adds each object className to the NSCountedSet.
 @result		A new `NSCountedSet<NSString*>`  of the objects' classNames and
				their count.
 */
@property (readonly, nonnull) NSCountedSet<NSString*> *objectsUniqueClassNames;


/*!
 @method		-toClassesFromStrings
 @abstract		Converts a set of `NSString` class names to an ordered set of
				`Class` objects.
 @discussion	This method maps each string in the ordered set  to its `Class`
				object using the `NSClassFromString` function.
 
				Only valid class names (strings that match registered class
				names) are transformed. Invalid or unknown class names will
				return `nil` and will not be included in the result.
 @result		A new Object of the same class as the receiver but containing
				the `Class` objects from to the class name objects in the set.
 */
- (nonnull instancetype)toClassesFromStrings;

/*!
 @method		-mapUsingBlock
 @abstract		Maps each object in the ordered set
 @param			block	The block is applied to each object in the ordered set.
						The block could mutate the object, or set it to `nil` if
						the object should be excluded from the resulting set.
						This must return YES for an object to be included in
						the new mapped ordered set.
 @discussion	This method applies a mapping method (via the provided `block`)
				to each object of the ordered set and returns a new
				@c instancetype containing the mapped objects.
				If object maps to nil or the method returns NO, the object is
				excluded from the new ordered set.
 @result		Returns a new instance of the same Class containing each passing
				object from the `block` function.
 */
- (nonnull instancetype)mapUsingBlock:(BOOL (^_Nullable)(ObjectType _Nullable * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop))block;

@end



@interface NSMutableOrderedSet<ObjectType> (BExtension)

/*!
 @method		-intersectArray:
 @abstract		Removes from the receiving ordered set each object that isn’t a
				member of the other array.
 @param			other	The array with which to perform the intersection. A nil or empty array is
						treated as the empty set, so it removes every object (it does not throw).
 @discussion	Union and minus are available directly via NSMutableOrderedSet's addObjectsFromArray:
				and removeObjectsInArray:.
 */
- (void)intersectArray:(nullable NSArray<ObjectType> *)other;

/*!
 @property		array
 @abstract		Sets the ordered set from a NSArray.
 @discussion	This implements the set method as the get `array` property is
 				already in the parent.

				The setter selector is be_setArray: because Apple defines a private
				setArray: on this class; dot syntax is unaffected.
 */
@property (readwrite, strong, nullable, setter=be_setArray:) NSArray<ObjectType> *array;

/*!
 @property		set
 @abstract		Sets the ordered set to the NSSet.
 @discussion	This implements the set method as the get `set` property is
				already in the parent.

				The setter selector is be_setSet: because Apple defines a private
				setSet: on this class; dot syntax is unaffected.
 */
@property (readwrite, strong, nullable, setter=be_setSet:) NSSet<ObjectType> *set;

/*!
 @method		-removeFirstElement
 @abstract		Removes the first object in the receiver ordered set.
 @since			1.1
 */
- (void)removeFirstElement;

/*!
 @method		-removeLastElement
 @abstract		Removes the last object in the receiver ordered set.
 @since			1.1
 */
- (void)removeLastElement;

/*!
 @method		-filterUsingBlock:
 @abstract		Filters the NSMutableOrderedSet by applying the block to
 				each object in the ordered set.
 @param			filterBlock	The block is applied to each element in the ordered
							set. If it returns NO, or the object is set to `nil`, to
							remove the element from the orderedset.
 @discussion	This method applies a transformation and filtering (via `block`)
				to each object of the ordered set. `obj` can be dereferenced,
				used, mutated, and the new different element returned within
				`obj`.

				Do NOT set `*stop` to halt early: filtering rebuilds the ordered set from the kept
				objects, so stopping before every element is visited discards the unvisited remainder.
 @result		Returns `self` after filtering its own elements through `block`.
 */
- (nonnull instancetype)filterUsingBlock:(BOOL (^ _Nullable)(ObjectType _Nullable *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop))filterBlock;

@end


#endif	//	NSOrderedSet_Extension_h
