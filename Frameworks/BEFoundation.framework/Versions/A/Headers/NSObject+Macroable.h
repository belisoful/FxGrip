/*!
 @header		NSObject+Macroable.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		A simplified macro system for Objective-C inspired by Laravel's Macroable trait.
 @discussion	This header provides a simple, lightweight macro system for adding methods to classes
 				at runtime using blocks. Unlike NSObject+DynamicMethods, this is a simplified
 				implementation focused on core macro functionality.

 				Macros are blocks that are attached to a class and can be called as if they
 				were native methods. The system uses NSObject+DynamicMethods internally
 				for the actual method implementation.

 				The system provides:
 				- Macro registration and removal
 				- Class-level macros (available to all instances)
 				- Thread-safe operations
 				- Uses NSObject+DynamicMethods internally for method implementation

 				## Usage

 				```objc
 				// Enable macro support
 				[MyClass enableMacros];

 				// Add a macro
 				[MyClass macro:@selector(greet:) macroBlock:^(id self, NSString *name) {
 					return [NSString stringWithFormat:@"Hello, %@!", name];
 				}];

 				// Call the macro on any instance
 				NSString *greeting = [myObject greet:@"World"];  // "Hello, World!"

 				// Check if macro exists
 				if ([MyClass hasMacro:@selector(greet:)]) {
 					// Macro exists
 				}

 				// Remove a macro
 				[MyClass removeMacro:@selector(greet:)];

 				// Remove all macros
 				[MyClass flushMacros];
 				```
 */

#ifndef NSObject_Macroable_h
#define NSObject_Macroable_h

#import <Foundation/Foundation.h>

@class BEMacroMeta;

#pragma mark - NSObject (Macroable) Category

/*!
 @category		NSObject (Macroable)
 @abstract		Category that adds macro capabilities to NSObject classes.
 @discussion	This category provides a simplified macro system inspired by Laravel's
 				Macroable trait. It allows adding methods to classes using blocks
 				at runtime.

 				Macros are stored in a class-level storage and implemented using
 				NSObject+DynamicMethods when enabled.
 */
@interface NSObject (Macroable)

#pragma mark - Activation

/*!
 @method		enableMacros
 @abstract		Enables macro support for this class.
 @return		YES if macros were successfully enabled, NO if already enabled.
 @discussion	Enables the underlying dynamic method support. Calling this explicitly is
 				optional — `macro:macroBlock:` enables macros automatically on first use.
 */
+ (BOOL)enableMacros;

/*!
 @method		disableMacros
 @abstract		Disables macro support for this class.
 @return		YES if macros were successfully disabled, NO if already disabled.
 @discussion	Disables macro support. Existing macros remain registered but
 				will not be callable until macros are re-enabled.
 */
+ (BOOL)disableMacros;

/*!
 @method		isMacrosEnabled
 @abstract		Checks if macro support is enabled for this class.
 @return		YES if macros are enabled, NO otherwise.
 */
+ (BOOL)isMacrosEnabled;

#pragma mark - Macro Registration

/*!
 @method		macro:macroBlock:
 @abstract		Registers a macro for the specified selector.
 @param			selector	The selector to register the macro for.
 @param			macroBlock	The block implementing the macro.
 @return		YES if the macro was successfully registered, NO on failure.
 @discussion	The block should have the signature matching the method being added.
 				For example, for a method `-(NSString *)greet:(NSString *)name`,
 				the block should be: `^(id self, NSString *name) { ... }`

 				If a macro already exists for the selector, it will be replaced.

 				Passing a `nil` macroBlock removes any existing macro for the selector and
 				returns YES (whether or not one was registered). Registering a macro
 				automatically enables macro support on the class.
 */
+ (BOOL)macro:(SEL _Nonnull)selector macroBlock:(nullable id)macroBlock;

/*!
 @method		hasMacro:
 @abstract		Checks if a macro is registered for the specified selector.
 @param			selector	The selector to check.
 @return		YES if a macro is registered, NO otherwise.
 */
+ (BOOL)hasMacro:(SEL _Nonnull)selector;

/*!
 @method		removeMacro:
 @abstract		Removes a macro for the specified selector.
 @param			selector	The selector whose macro should be removed.
 @return		YES if a macro was found and removed, NO if no macro existed.
 */
+ (BOOL)removeMacro:(SEL _Nonnull)selector;

/*!
 @method		flushMacros
 @abstract		Removes all macros for this class.
 @discussion	This removes all registered macros from this class only.
 				Macros registered on parent classes are not affected.
 */
+ (void)flushMacros;

#pragma mark - Object-Level Macros

/*!
 @method		objectMacro:macroBlock:
 @abstract		Registers a macro for a specific object instance.
 @param			selector	The selector to register the macro for.
 @param			macroBlock	The block implementing the macro.
 @return		YES if the macro was successfully registered, NO on failure.
 @discussion	Unlike class macros (macro:macroBlock:), object macros are only
 				available on the specific instance they were added to.

 				Passing a `nil` macroBlock removes any existing object macro for the
 				selector and returns YES. An object macro registered for the same selector
 				as a class macro overrides the class macro for this instance only.
 */
- (BOOL)objectMacro:(SEL _Nonnull)selector macroBlock:(nullable id)macroBlock;

/*!
 @method		hasObjectMacro:
 @abstract		Checks if an object-specific macro is registered.
 @param			selector	The selector to check.
 @return		YES if an object macro is registered, NO otherwise.
 */
- (BOOL)hasObjectMacro:(SEL _Nonnull)selector;

/*!
 @method		removeObjectMacro:
 @abstract		Removes an object-specific macro.
 @param			selector	The selector whose macro should be removed.
 @return		YES if a macro was found and removed, NO if no macro existed.
 */
- (BOOL)removeObjectMacro:(SEL _Nonnull)selector;

/*!
 @method		flushObjectMacros
 @abstract		Removes all object-specific macros from this instance.
 */
- (void)flushObjectMacros;

@end

#pragma mark - BEMacroMeta

/*!
 @class			BEMacroMeta
 @abstract		Metadata container for macro implementations.
 @discussion	This class stores the block and metadata for a registered macro.
 */
@interface BEMacroMeta : NSObject

/*!
 @method		initWithSelector:block:
 @abstract		Initializes a macro metadata object.
 @param			selector	The selector for the macro.
 @param			block		The block implementing the macro.
 @return		An initialized BEMacroMeta instance, or nil if initialization failed.
 */
- (nullable instancetype)initWithSelector:(nonnull SEL)selector block:(nullable id)block;

/*!
 @property		selector
 @abstract		The selector for this macro.
 */
@property (nonnull, readonly) SEL selector;

/*!
 @property		block
 @abstract		The block that implements this macro.
 */
@property (nullable, readonly) id block;

@end

#endif	//	NSObject_Macroable_h
