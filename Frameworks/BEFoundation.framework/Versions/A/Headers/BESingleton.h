/*!
 @header     BESingleton.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @date       2025-01-01
 @author	 belisoful@icloud.com
 @abstract   Provides a reusable and thread-safe singleton pattern implementation.
 @discussion This file defines the `BESingleton` protocol and a category on `NSObject`
			 to simplify the creation of singleton classes. To create a singleton,
			 a class must conform to the `BESingleton` protocol and override the
			 `isSingleton` class method to return `YES`. The shared instance can then
			 be accessed via the `__BESingleton` class method.

			 An example implementation:
 ```objc
 // MyClass.h
 #import "BESingleton.h"

 @interface MyClass : NSObject <BESingleton>
 + (instancetype)sharedInstance;
 @end

 // MyClass.m
 @implementation MyClass
 + (BOOL)isSingleton {
	 return YES;
 }

 + (instancetype)sharedInstance {
	 return [self __BESingleton];
 }
 @end
 ```
*/

#ifndef BESingleton_h
#define BESingleton_h

#import <Foundation/Foundation.h>

#pragma mark - BESingleton Protocol

/*!
 @protocol   BESingleton
 @abstract   Declares the interface for a class that adopts the singleton pattern.
 @discussion A class must conform to this protocol to use the backing implementation
			 provided by the `NSObject (BESingleton)` category. The core requirement
			 is to implement the `isSingleton` class method.
 */
@protocol BESingleton <NSObject>

#pragma mark - Required Methods

/*!
 @property   isSingleton
 @abstract   Indicates that the class implements the singleton pattern.
 @discussion This method must be overridden to return `YES` for the `__BESingleton`
			 method to return a shared instance. If not overridden, the default
			 implementation in `NSObject` returns `NO`.
 @return     `YES` if the class is a singleton; otherwise, `NO`.
 */
@property (class, readonly, nonatomic) BOOL isSingleton;

/*!
 @method     __BESingleton
 @abstract   Retrieves the shared singleton instance for the class.
 @discussion This method provides the core logic for the singleton pattern. It ensures
			 that only one instance of the class is created in a thread-safe manner.
			 On first call, it initializes the instance using `initForSingleton:` if
			 available, or `init` as a fallback.
 @return     The shared instance of the class, retained.
 */
+ (nullable instancetype)__BESingleton NS_RETURNS_RETAINED;

#pragma mark - Optional Methods

@optional

/*!
 @method     initForSingleton:
 @abstract   An optional custom initializer for the singleton instance.
 @discussion If a class implements this method, it will be called exactly once to
			 initialize the singleton instance. This allows for custom setup logic
			 that should only be run when the singleton is first created.
 @param      initInfo A dictionary containing initialization data, retrieved from
			 the `singletonInitInfo` class property.
 @return     An initialized instance of the class.
 */
- (nullable instancetype)initForSingleton:(nullable NSDictionary *)initInfo;

@end

#pragma mark - BESingleton Category

/*!
 @category   NSObject (BESingleton)
 @abstract   Provides the default implementation and backing logic for the `BESingleton` protocol.
 @discussion This category adds the `__BESingleton` method to all `NSObject` subclasses,
			 along with a default `isSingleton` implementation that returns `NO`. This
			 makes the singleton pattern opt-in for any class.
 */
@interface NSObject (BESingleton)

/*!
 @property   isSingleton
 @abstract   The default implementation, which indicates that the class is not a singleton.
 @return     Always returns `NO`. Subclasses must override this to enable singleton behavior.
 */
@property (class, readonly) BOOL isSingleton;

/*!
 @property   __BESingleton
 @abstract   A property-based accessor for the shared singleton instance.
 @discussion This is a convenience property that calls the `+__BESingleton` method.
 @return     The shared instance of the class.
 */
@property (class, readonly, retain, nullable) id __BESingleton;

/*!
 @property   singletonInitInfo
 @abstract   A dictionary passed to the custom singleton initializer.
 @discussion Set this property *before* the first time the singleton is accessed. The
			 dictionary will be passed to the `initForSingleton:` method during
			 initialization. The property is atomic to ensure thread-safe access.
 */
@property (class, readwrite, atomic, retain, nullable) NSDictionary *singletonInitInfo;

/*!
 @method     __BESingleton
 @abstract   Provides the main backing function for the singleton pattern.
 @discussion This constructs the shared instance using `init` or the optional `initForSingleton:`
			 method. This method is thread-safe. The class must conform to the `BESingleton`
			 protocol and have `isSingleton` return `YES` for this method to work.
 @return     The shared instance of the implementing class, retained.
 */
+ (nullable instancetype)__BESingleton NS_RETURNS_RETAINED;

@end

#endif /* BESingleton_h */
