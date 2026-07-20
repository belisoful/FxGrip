/*!
 @header		BEPriorityExtensions.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		A comprehensive priority-based sorting framework for Foundation collections.
 @discussion	This header provides protocols and categories that enable priority-based sorting
for Foundation collection classes. Objects can implement priority protocols to participate
in automatic sorting operations, with fallback mechanisms for objects that don't initially
have priority values.

The framework supports three main use cases:
- Read-only priority items that expose their priority through BEPriorityItem
- Mutable priority items that can capture and store priority values via BEPriorityCapture
- Full priority property support combining both read and write capabilities through BEPriorityProperty

Collection extensions are provided for NSArray, NSMutableArray, NSOrderedSet, and NSMutableOrderedSet
to enable priority-based sorting operations.
*/

#ifndef NSPriorityExtensions_h
#define NSPriorityExtensions_h

#import <Foundation/Foundation.h>

/*!
@protocol BEPriorityItem
@abstract Protocol for objects that can provide a priority value for sorting operations.
@discussion Objects conforming to this protocol expose a read-only priority property that
can be used by sorting algorithms. The priority value should be consistent across multiple
calls for the same object state.

Priority values are compared using NSNumber's compare: method, where lower numeric values
represent higher priority in the sorted result.
*/
@protocol BEPriorityItem
/*!
@property itemPriority
@abstract The priority value for this item.
@discussion Returns an NSNumber representing the item's priority, or nil if no priority
is currently assigned. When nil, the sorting system will use the default priority value.
Lower numeric values indicate higher priority in sort order.
*/
@property (readonly, nullable) NSNumber *itemPriority;
@end



/*!
@protocol BEPriorityCapture
@abstract Protocol for objects that can accept and store priority values.
@discussion This protocol is intended for objects that need to capture priority values
during sorting operations. Objects conforming to this protocol should implement a setter
for itemPriority that allows the sorting system to assign default priority values when needed.

This protocol should only implement the setter for itemPriority, not the getter.
*/
@protocol BEPriorityCapture
/*!
@property itemPriority
@abstract The priority value for this item.
@discussion A settable priority property that allows the sorting system to assign priority
values to objects that don't initially have them. The setter should store the provided
priority value for future retrieval.
*/
@property (nonatomic, nullable) NSNumber *itemPriority;
@end




/*!
@protocol BEPriorityProperty
@abstract Combined protocol providing both read and write access to priority values.
@discussion This protocol combines BEPriorityItem and BEPriorityCapture to provide full
priority property support. Objects conforming to this protocol can both expose their
current priority and accept new priority assignments.

This protocol should implement both the getter and setter for itemPriority.
*/
@protocol BEPriorityProperty <BEPriorityItem, BEPriorityCapture>
/*!
@property itemPriority
@abstract The priority value for this item.
@discussion A read-write priority property that provides full priority management capabilities.
The getter returns the current priority value (or nil if unset), while the setter allows
assignment of new priority values.
*/
@property (nonatomic, nullable) NSNumber *itemPriority;
@end




/*!
@const BEDefaultSortedItemPriority
@abstract The default priority value used when objects don't specify their own priority.
@discussion This constant defines the default priority value (0) that is assigned to objects
during sorting operations when they don't already have a priority value set. Objects with
priorities lower than this value will sort earlier, while objects with higher values will
sort later.
*/
extern NSInteger const BEDefaultSortedItemPriority;




/*!
@class BEPriorityExtensionHelper
@abstract Utility class providing comparator functions for priority-based sorting.
@discussion This helper class encapsulates the core sorting logic for priority-based operations.
It provides a reusable comparator that can handle objects conforming to the priority protocols,
with intelligent fallback behavior for objects that don't initially have priority values.
*/
@interface BEPriorityExtensionHelper : NSObject

/*!
@property priorityComparator
@abstract A comparator block for sorting objects based on their priority values.
@discussion This class property returns a NSComparator block that can be used with Foundation
sorting methods. The comparator handles objects conforming to BEPriorityItem and BEPriorityCapture
protocols, automatically assigning default priority values when needed.

The comparator performs the following logic:
1. Checks if objects conform to BEPriorityItem and retrieves their priority
2. For objects without priority that conform to BEPriorityCapture, assigns the default priority
3. Falls back to the default priority for objects that don't conform to either protocol
4. Compares the resulting priority values using NSNumber's compare: method

@note Step 2 mutates the compared objects: a BEPriorityCapture object with no priority has its
itemPriority set to the default during comparison. Sorting is therefore not side-effect-free for
such objects, and the comparator is not safe to run concurrently on objects that share state.

@return A NSComparator block suitable for use with Foundation sorting methods.
*/
@property (class, readonly, nonnull) NSComparator priorityComparator;

@end




/*!
@category NSArray(BEPriorityExtensions)
@abstract Priority-based sorting extensions for NSArray.
@discussion Adds convenience methods to NSArray for creating sorted copies based on object priorities.

@code
// items contains objects conforming to BEPriorityItem (e.g. BEPredicateRule).
NSArray *ordered = [items sortedArrayUsingItemPriority];  // ascending itemPriority, stable
@endcode
*/
@interface NSArray (BEPriorityExtensions)

/*!
@method sortedArrayUsingItemPriority
@abstract Creates a new array sorted by item priorities.
@discussion Returns a new NSArray containing the same objects as the receiver, sorted according
to their priority values. Objects conforming to BEPriorityItem will be sorted by their priority
values, while objects conforming to BEPriorityCapture may have default priorities assigned during
the sorting process.

The sort is performed using NSSortStable to preserve the relative order of objects with equal priorities.

@return A new NSArray with objects sorted by priority. Objects with lower priority values appear
first in the sorted array.
*/
- (nonnull NSArray*)sortedArrayUsingItemPriority;

@end




/*!
@category NSMutableArray(BEPriorityExtensions)
@abstract Priority-based sorting extensions for NSMutableArray.
@discussion Adds in-place sorting methods to NSMutableArray based on object priorities.
*/
@interface NSMutableArray (BEPriorityExtensions)

/*!
@method sortArrayUsingItemPriority
@abstract Sorts the mutable array in place using item priorities.
@discussion Reorders the elements of the mutable array according to their priority values.
Objects conforming to BEPriorityItem will be sorted by their priority values, while objects
conforming to BEPriorityCapture may have default priorities assigned during the sorting process.

The sort is performed using NSSortStable to preserve the relative order of objects with equal priorities.
*/
- (void)sortArrayUsingItemPriority;

@end




/*!
@category NSOrderedSet(BEPriorityExtensions)
@abstract Priority-based sorting extensions for NSOrderedSet.
@discussion Adds convenience methods to NSOrderedSet for creating sorted arrays based on object priorities.
*/
@interface NSOrderedSet (BEPriorityExtensions)

/*!
@method sortedArrayUsingItemPriority
@abstract Creates a new array sorted by item priorities from the ordered set.
@discussion Returns a new NSArray containing the objects from the ordered set, sorted according
to their priority values. Objects conforming to BEPriorityItem will be sorted by their priority
values, while objects conforming to BEPriorityCapture may have default priorities assigned during
the sorting process.

The sort is performed using NSSortStable to preserve the relative order of objects with equal priorities.

@return A new NSArray with objects from the ordered set sorted by priority. Objects with lower
priority values appear first in the sorted array.
*/
- (nonnull NSArray *)sortedArrayUsingItemPriority;

@end




/*!
@category NSMutableOrderedSet(BEPriorityExtensions)
@abstract Priority-based sorting extensions for NSMutableOrderedSet.
@discussion Adds in-place sorting methods to NSMutableOrderedSet based on object priorities.
*/
@interface NSMutableOrderedSet (BEPriorityExtensions)

/*!
@method sortOrderedSetUsingItemPriority
@abstract Sorts the mutable ordered set in place using item priorities.
@discussion Reorders the elements of the mutable ordered set according to their priority values.
Objects conforming to BEPriorityItem will be sorted by their priority values, while objects
conforming to BEPriorityCapture may have default priorities assigned during the sorting process.

The sort is performed using NSSortStable to preserve the relative order of objects with equal priorities.
*/
- (void)sortOrderedSetUsingItemPriority;

@end

#endif // NSPriorityExtensions_h
