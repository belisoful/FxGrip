/*!
 @header     BEStackExtensions.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @date       2025-01-01
 @author	 belisoful@icloud.com
 @abstract   Adds stack (LIFO) and queue (FIFO) operations to mutable collections.
 @discussion This header file provides categories on NSMutableArray and NSMutableOrderedSet
			 to enable stack-like and queue-like behaviors using common push, pop, and shift
			 method names. These extensions allow treating mutable collections as stacks
			 (Last-In, First-Out) or queues (First-In, First-Out) with intuitive method names.
 */

#ifndef BEStackExtensions_h
#define BEStackExtensions_h

#import <Foundation/Foundation.h>

#pragma mark - NSMutableArray Stack and Queue Extensions

/*!
 @category   NSMutableArray (StackAdditions)
 @abstract   Adds stack (LIFO) and queue (FIFO) operations to NSMutableArray.
 @discussion This category provides methods to treat an NSMutableArray as a stack using
			 push: and pop methods, or as a queue using push: and shift methods. All
			 methods return the array instance to enable method chaining.

			 @code
			 NSMutableArray *stack = [NSMutableArray array];
			 [[stack push:@"a"] push:@"b"];   // chaining; stack is now @[@"a", @"b"]
			 id top = [stack pop];            // @"b" (LIFO)

			 NSMutableArray *queue = [NSMutableArray array];
			 [queue pushObjects:@"a", @"b", @"c", nil];
			 id first = [queue shift];        // @"a" (FIFO)
			 @endcode
 */
@interface NSMutableArray <ObjectType> (StackAdditions)

/*!
 @method     push:
 @abstract   Adds an object to the end of the array (stack push operation).
 @discussion This method appends the specified object to the end of the array, emulating
			 the push operation of a stack. If the object is nil, the array remains unchanged.
 @param      obj The object to add to the array. Pass nil to leave the array unchanged.
 @return     The array instance, enabling method chaining.
 */
- (nonnull instancetype)push:(nullable ObjectType)obj;

/*!
 @method     pushObjects:
 @abstract   Adds multiple objects to the end of the array using variadic arguments.
 @discussion This method accepts a variable number of arguments and adds each non-nil
			 object to the end of the array in the order they are provided. The argument
			 list must be terminated with nil.
 @param      obj The first object to add, followed by additional objects. Pass nil as the
			 final argument to terminate the list.
 @return     The array instance, enabling method chaining.
 */
- (nonnull instancetype)pushObjects:(nullable ObjectType)obj, ... NS_REQUIRES_NIL_TERMINATION;

/*!
 @method     pushArray:
 @abstract   Adds all objects from another array to the end of this array.
 @discussion This method appends all objects from the specified array to the end of
			 this array, maintaining their original order. If the source array is nil
			 or empty, this array remains unchanged.
 @param      array The array whose objects should be added. Pass nil to leave the array unchanged.
 @return     The array instance, enabling method chaining.
 */
- (nonnull instancetype)pushArray:(nullable NSArray<ObjectType> *)array;

/*!
 @method     pop
 @abstract   Removes and returns the last object in the array (stack pop operation).
 @discussion This method removes the last object from the array and returns it, emulating
			 the pop operation of a stack (Last-In, First-Out). If the array is empty,
			 no changes are made and nil is returned.
 @return     The last object in the array, or nil if the array is empty.
 */
- (nullable ObjectType)pop;

/*!
 @method     shift
 @abstract   Removes and returns the first object in the array (queue dequeue operation).
 @discussion This method removes the first object from the array and returns it. When
			 combined with push:, this enables queue-like behavior (First-In, First-Out).
			 If the array is empty, no changes are made and nil is returned.
 @return     The first object in the array, or nil if the array is empty.
 */
- (nullable ObjectType)shift;

@end

#pragma mark - NSMutableOrderedSet Stack and Queue Extensions

/*!
 @category   NSMutableOrderedSet (StackAdditions)
 @abstract   Adds stack (LIFO) and queue (FIFO) operations to NSMutableOrderedSet.
 @discussion This category provides methods to treat an NSMutableOrderedSet as a stack
			 using push: and pop methods, or as a queue using push: and shift methods.
			 The behavior when pushing existing objects is controlled by the isPushOnTop
			 property. All methods return the set instance to enable method chaining.
 */
@interface NSMutableOrderedSet <ObjectType> (StackAdditions)

/*!
 @property   isPushOnTop
 @abstract   Controls whether pushing existing objects moves them to the end of the set.
 @discussion When YES (the default), pushing an object that already exists in the set
			 will first remove the existing instance before adding it to the end,
			 ensuring the pushed object is at the "top" of the stack. When NO, pushing
			 an existing object has no effect on the set.
 */
@property (readwrite, assign, nonatomic) BOOL isPushOnTop;

/*!
 @method     push:
 @abstract   Adds an object to the end of the ordered set (stack push operation).
 @discussion This method adds the specified object to the end of the ordered set. The
			 behavior with existing objects is controlled by the isPushOnTop property.
			 If the object is nil, the set remains unchanged.
 @param      obj The object to add to the set. Pass nil to leave the set unchanged.
 @return     The ordered set instance, enabling method chaining.
 */
- (nonnull instancetype)push:(nullable ObjectType)obj;

/*!
 @method     pushObjects:
 @abstract   Adds multiple objects to the end of the ordered set using variadic arguments.
 @discussion This method accepts a variable number of arguments and pushes each non-nil
			 object to the end of the set in the order they are provided. Each object
			 respects the isPushOnTop property behavior. The argument list must be
			 terminated with nil.
 @param      obj The first object to add, followed by additional objects. Pass nil as the
			 final argument to terminate the list.
 @return     The ordered set instance, enabling method chaining.
 */
- (nonnull instancetype)pushObjects:(nullable ObjectType)obj, ... NS_REQUIRES_NIL_TERMINATION;

/*!
 @method     pushArray:
 @abstract   Adds all objects from an array to the end of the ordered set.
 @discussion This method adds all objects from the specified array to the end of the
			 ordered set, maintaining their original order. The isPushOnTop property
			 controls the behavior for objects that already exist in the set. If the
			 source array is nil or empty, the set remains unchanged.
 @param      array The array whose objects should be added. Pass nil to leave the set unchanged.
 @return     The ordered set instance, enabling method chaining.
 */
- (nonnull instancetype)pushArray:(nullable NSArray<ObjectType> *)array;

/*!
 @method     pop
 @abstract   Removes and returns the last object in the ordered set (stack pop operation).
 @discussion This method removes the last object from the ordered set and returns it,
			 emulating the pop operation of a stack (Last-In, First-Out). If the set
			 is empty, no changes are made and nil is returned.
 @return     The last object in the set, or nil if the set is empty.
 */
- (nullable ObjectType)pop;

/*!
 @method     shift
 @abstract   Removes and returns the first object in the ordered set (queue dequeue operation).
 @discussion This method removes the first object from the ordered set and returns it.
			 When combined with push:, this enables queue-like behavior (First-In, First-Out).
			 If the set is empty, no changes are made and nil is returned.
 @return     The first object in the set, or nil if the set is empty.
 */
- (nullable ObjectType)shift;

@end

#endif /* BEStackExtensions_h */
