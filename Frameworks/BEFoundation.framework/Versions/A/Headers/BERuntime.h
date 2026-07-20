/*!
 * @file		BERuntime.h
 * @copyright	-© 2025 Delicense - @belisoful. All rights released.
 * @date		2025-01-01
 * @author		belisoful@icloud.com
 * @abstract	Runtime utility functions for Objective-C class and method introspection
 * @discussion	This header provides utility functions for working with Objective-C runtime,
 *             including metaclass resolution and method existence checking within a specific class
 *             These functions extend the standard runtime API with commonly needed functionality.
 *
 *             @code
 *             // Does NSString itself define -isEqualToString: (vs. inheriting it)?
 *             BOOL defined = class_hasMethod(NSString.class, @selector(isEqualToString:));
 *
 *             // Recover a class from its metaclass.
 *             Class meta = object_getClass(NSString.class);   // the metaclass
 *             Class cls  = metaclass_getClass(meta);          // back to NSString
 *             @endcode
 */

#ifndef BERuntime_h
#define BERuntime_h

#import <objc/runtime.h>

/*!
 * @function metaclass_getClass
 * @abstract Retrieves the class instance corresponding to a given metaclass
 * @discussion Given a metaclass, this function returns the corresponding class instance.
 *             This is useful when you have a metaclass and need to find its associated class.
 * @param metaClass The metaclass to resolve to its corresponding class
 * @return The class instance corresponding to the metaclass, or nil if the metaclass is invalid
 *         or if no corresponding class is found
 */
extern Class _Nullable metaclass_getClass(Class _Nonnull metaClass);

/*!
 * @function class_hasMethod
 * @abstract Checks if a class defines a specific method
 * @discussion This function checks if the given class has a method with the specified selector.
 *             It only checks methods defined on the class itself, not inherited methods.
 * @param cls The class to check for the method
 * @param selector The selector of the method to look for
 * @return YES if the class defines the method, NO otherwise or if parameters are invalid
 */
extern BOOL class_hasMethod(Class _Nonnull cls, SEL _Nonnull selector);

#endif /* BERuntime_h */
