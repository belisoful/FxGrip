/*!
 @header		NSSet+BExtension.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		NSSet and NSMutableSet BExtension category provides mapping,
				filtering, and object metadata like Class and className.
 @discussion	The BExtension category provides missing functionality to the
				Core Foundation.
*/

#ifndef NSSet_Extension_h
#define NSSet_Extension_h

#import <Foundation/Foundation.h>

/*!
 @category		BExtension
 @abstract		Adds set mapping, filtering, and object meta functionality.
 @discussion	This category provides map, filter, and objects meta-data
				methods.
 
 The following methods are provided by this category to `NSSet`:

 `-mapUsingBlock:`: Maps all objects to a new set, removing `NULL` mappings and not passing.

 `-objectsClasses` / `-objectsUniqueClasses`:  An `NSCountedSet` of the objects' `Class` and counts.

 `-objectsClassNames` / `-objectsUniqueClassNames`:  An `NSCountedSet` of the objects' `className` and counts.

 `-toClassesFromStrings`: Converts a set of `NSString` into their `Class`.

 The following method is provided by this category to `NSMutableSet`:

 `-filterUsingBlock:`: filters the set in place, removing `NULL` mappings and objects the block rejects.

 Note: because a set's members are already unique, the `objectsClasses`/`objectsUniqueClasses`
 (and `…ClassNames`) pairs are equivalent — both return an `NSCountedSet`.

 @code
	NSSet *s = @[@1, @2, @3, @4].set;
	NSSet *evens = [s mapUsingBlock:^BOOL(id *obj, BOOL *stop) {
		return [*obj integerValue] % 2 == 0;   // keep evens; mutate *obj to transform
	}]; // {@2, @4}
	NSCountedSet *kinds = s.objectsClasses;     // counts of each value's Class

	NSMutableSet *m = s.mutableCopy;
	[m filterUsingBlock:^BOOL(id *obj, BOOL *stop) { return [*obj integerValue] > 2; }]; // {@3, @4}
 @endcode
 */

@interface NSSet <ObjectType> (BExtension)

/*!
 @property		objectsClasses
 @abstract		Gets the `class` of the objects in the set and how many of each
				there are.
 @discussion 	This loops through each object in the set and gets their
				`class`.  It adds each object class to the `NSCountedSet`.
 @result		A new `NSCountedSet<Class>`  of the objects' classes and their
				count.
 */
@property (readonly, nonnull) NSCountedSet<Class> *objectsClasses;

/*!
 @property		objectsClassNames
 @abstract		Gets the `className` of the objects in the set and how many of
				each there are.
 @discussion 	This loops through each object in the set and gets their
				`className`.  It adds each object className to the `NSCountedSet`.
 @result		A new `NSCountedSet<NSString*>`  of the objects' classNames and
				their count.
 */
@property (readonly, nonnull) NSCountedSet<NSString*> *objectsClassNames;

/*!
 @property		objectsUniqueClasses
 @abstract		Gets the unique `class` of the objects in the set and how many
				of each there are.
 @discussion 	This loops through each object in the set and gets their
				`class`.  It adds each object class to the NSCountedSet.
 @result		A new `NSCountedSet<Class>`  of the objects' classes and their
				count.
 */
@property (readonly, nonnull) NSCountedSet<Class> *objectsUniqueClasses;

/*!
 @property		objectsUniqueClassNames
 @abstract		Gets the unique `className` of the objects in the set and how
				many of each there are.
 @discussion 	This loops through each object in the set and gets their
				`className`.  It adds each object className to the NSCountedSet.
 @result		A new `NSCountedSet<NSString*>`  of the objects' classNames and
				their count.
 */
@property (readonly, nonnull) NSCountedSet<NSString*> *objectsUniqueClassNames;


/*!
 @method		-toClassesFromStrings
 @abstract		Converts a set of `NSString` class names to a set of `Class`
				objects.
 @discussion	This method maps each string in the set to its `Class` object
				using the `NSClassFromString` function.
 
				Only valid class names (strings that match registered class
				names) are transformed. Invalid or unknown class names will
				return `nil` and will not be included in the result.
 @result		A new Object of the same class as the receiver but containing
				the `Class` objects from to the class name objects in the set.
 */
- (nonnull instancetype)toClassesFromStrings;

/*!
 @method		-mapUsingBlock:
 @abstract		Maps each object in the set
 @param			block	The block is applied to each object in the set. The
							block could mutate the object, or set it to `nil` if
							the object should be excluded from the resulting set.
							This must return YES for an object to be included in
							the mapped set.
 @discussion	This method applies a mapping method (via the provided `block`)
				to each object of the set and returns a new @c instancetype
				containing the new mapped objects.
				If object maps to nil or the method returns NO, the object is
				excluded from the new set.
 @result		Returns a new instance of the same Class containing each passing
				object from the `block` function.
 */
- (nonnull instancetype)mapUsingBlock:(BOOL (^_Nullable)(ObjectType _Nullable * _Nonnull obj, BOOL * _Nonnull stop))block;

@end



#pragma mark -

@interface NSMutableSet <ObjectType> (BExtension)

/*!
 @method		-filterUsingBlock:
 @abstract		Filters the NSMutableSet by applying the block to each
				object in the set.
 @param			block	The block is applied to each element in the set. If it
						returns NO, or the object is set to `nil`, to remove
						the element from the set.
 @discussion	This method applies a transformation and filtering (via `block`)
				to each object of the set. `obj` can be dereferenced, used,
				mutated, and the new different element returned within `obj`.

				Do NOT set `*stop` to halt early: filtering rebuilds the set from the kept objects, so
				stopping before every element is visited discards the entire unvisited remainder.
 @result		Returns `self` after filtering its own elements through `block`.
 */
- (nonnull instancetype)filterUsingBlock:(BOOL (^_Nullable)(ObjectType _Nullable * _Nonnull obj, BOOL * _Nonnull stop))block;

@end


#endif	//	NSSet_Extension_h
