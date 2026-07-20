/*!
 @header		NSObject+DynamicMethods.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
@abstract		A system for adding and managing dynamic methods to Objective-C objects at runtime using blocks.
  @discussion	This header provides a runtime method injection system that adds methods to existing objects
 				and classes using blocks. The system supports class methods (added to all instances of a class).

				The system provides the following capabilities:
				- Add methods to existing objects without subclassing
				- Support for both instance-specific and class-wide dynamic methods
				- Protocol-based method forwarding and delegation
				- Automatic method signature generation from block signatures
				- Optional selector capture for method implementations
				- Concurrency-safe method registration and dispatch (see Thread Safety below)
				- Memory management with automatic cleanup

				## Block Signature Requirements
				
				Method implementation blocks must follow this format:
				```
				ReturnType (^)(id self, SEL _cmd, ...parameters)
				```
				
				The `SEL _cmd` parameter is optional. If included, the block will receive the selector
				of the method being called. If omitted, the system automatically adjusts the signature.
				
				## Activation and Inheritance
				
				Dynamic methods must be explicitly enabled on a per-class basis. Classes can inherit
				dynamic method capabilities from their superclasses or explicitly enable/disable them.

				## Thread Safety

				Adding, removing, replacing, and dispatching dynamic methods (object and class) are safe
				to perform concurrently. The metadata is guarded by per-scope locks, and a dispatch holds
				a strong reference to the method's implementation for the duration of the call, so a
				concurrent remove or replace cannot free an implementation that is mid-invocation (no
				use-after-free).

				One caveat applies to instance-protocol forwarding: reconfiguring an instance's forwarded
				protocols (addInstanceProtocol:/removeInstanceProtocol: and related) concurrently with
				dispatch on that same instance may briefly present a stale view of the forwarded
				protocols. This self-corrects on the next synchronization without crashing or corrupting
				state. If you reconfigure protocol forwarding at runtime from multiple threads, serialize
				that reconfiguration externally (typical usage registers methods and protocols during
				setup, before concurrent dispatch begins).
				
				## Limitations
				
				NSMethodSignatures cannot properly encode compiler SIMD, vector, or NEON parameter types and will fail.
				Use their base types as arrays or pointers instead for arguments.
				The `_Float16` type also produces errors for malformed Block Signatures.
				
				## Usage Example
				
				```objc
				// Enable dynamic methods for a class
				[MyClass enableDynamicMethods];
				
				// Add a dynamic method to a specific object
				NSString *str = @"Hello";
				[str addObjectMethod:@selector(customMethod:) block:^(id self, NSString *param) {
					NSLog(@"Called with: %@", param);
					return [self stringByAppendingString:param];
				}];
				
				// Add a dynamic method to all instances of a class
				[NSString addClassMethod:@selector(globalMethod) block:^(id self) {
					return @"Global method called";
				}];
				
				// Add protocol-based forwarding
				[MyClass addInstanceProtocol:@protocol(MyProtocol) withClass:[MyHandler class]];
				```
*/

#ifndef NSObject_DynamicMethods_h
#define NSObject_DynamicMethods_h

#import <Foundation/Foundation.h>
#import <BEFoundation/NSMethodSignature+BlockSignatures.h>
#import <objc/runtime.h>

/*!
 @protocol		NSNoProtocol
 @abstract		A sentinel protocol used to represent targets without a specific protocol.
 @discussion	This protocol serves as a placeholder for forward targets that don't conform
				to a specific protocol. It's used internally by the dynamic method system
				to manage non-protocol-based method forwarding.
 */
@protocol NSNoProtocol
@end

/*!
 @protocol		NSProtocolImpClass
 @abstract		Optional protocol for classes used as protocol implementation targets.
 @discussion	Classes that serve as protocol implementation targets can optionally
				implement this protocol to receive a reference to the original object
				that the method was called on.
 */
@protocol NSProtocolImpClass
@optional
/*!
 @method		setOriginalObject:
 @abstract		Called to provide the implementation target with the original object.
 @param			object	The object on which the dynamic method was originally called.
 @discussion	When a protocol implementation target is created, this method is called
				(if implemented) to provide a reference to the original object. This
				allows the implementation to access the original object's state or
				forward additional method calls.
 */
- (void)setOriginalObject:(id _Nonnull)object;
@end

#pragma mark - Dynamic Method Metadata

/*!
 @class			BEDynamicMethodMeta
 @abstract		Metadata container for dynamic method implementations.
 @discussion	This class stores all the information needed to manage a dynamic method,
				including its selector, signatures, block implementation, and runtime metadata.
				It serves as the bridge between the block-based implementation and the
				Objective-C runtime method system.
				
				Instances of this class are created automatically when dynamic methods are
				added and should not be created directly by client code.
 */
@interface BEDynamicMethodMeta : NSObject

/*!
 @method		initWithSelector:block:
 @abstract		Initializes a new dynamic method metadata object.
 @param			aSelector	The selector for the dynamic method.
 @param			block		The block that implements the method.
 @return		An initialized BEDynamicMethodMeta instance, or nil if initialization failed.
 @discussion	This initializer creates the necessary method signatures and runtime
				implementations from the provided block. The block's signature is analyzed
				to determine whether it captures the method selector.
				
				This method should not be called directly by client code. Use the
				addClassMethod:block: or addObjectMethod:block: methods instead.
 */
- (nullable instancetype)initWithSelector:(nonnull SEL)aSelector
									block:(nonnull id)block;

/*!
 @property		selector
 @abstract		The selector for this dynamic method.
 @discussion	The method selector that this metadata represents. This is used as the
				key for method lookup and invocation.
 */
@property (nonnull, readonly) SEL selector;

/*!
 @property		blockSignature
 @abstract		The method signature of the implementing block.
 @discussion	This signature represents the block's parameter and return types as they
				appear in the block's implementation. Used for invocation preparation
				and argument marshalling.
 */
@property (retain, nonnull, readonly) NSMethodSignature *blockSignature;

/*!
 @property		methodSignature
 @abstract		The method signature as it appears to callers.
 @discussion	This signature represents the method as it appears to external callers,
				with proper self and _cmd parameters. Used for method signature queries
				and runtime method resolution.
 */
@property (retain, nonnull, readonly) NSMethodSignature *methodSignature;

/*!
 @property		isCapturingCmd
 @abstract		Whether the block captures the method selector.
 @discussion	When YES, the block expects to receive the method selector as an argument.
				This affects how invocations are prepared and arguments are passed during
				method forwarding.
 */
@property (assign, readonly) BOOL isCapturingCmd;

/*!
 @property		block
 @abstract		The block that implements this dynamic method.
 @discussion	The actual block object that contains the method implementation.
				This block is retained and used for method invocation.
 */
@property (retain, nonnull, readonly) id block;

/*!
 @property		implementation
 @abstract		The IMP created from the block.
 @discussion	The implementation pointer generated from the block using
				imp_implementationWithBlock. This is used for direct method invocation
				and provides optimal performance for dynamic method calls.
 */
@property (assign, nonnull, readonly) IMP implementation;

@end

#pragma mark - Dynamic Methods Activation State

/*!
 @typedef		BEDynamicMethodsActivationState
 @abstract		Enumeration describing the activation state of dynamic methods for a class.
 @discussion	This enumeration describes whether dynamic methods are enabled, disabled,
				or inherited for a particular class. The state affects method resolution
				and forwarding behavior.
 @constant		DMSelfDisabled		Dynamic methods are explicitly disabled for this class.
 @constant		DMInheritDisabled	Dynamic methods are disabled by inheritance from a parent class.
 @constant		DMInheritNone		No explicit setting; inherits from parent or defaults to disabled.
 @constant		DMInheritEnabled	Dynamic methods are enabled by inheritance from a parent class.
 @constant		DMSelfEnabled		Dynamic methods are explicitly enabled for this class.
 */
typedef NS_ENUM(NSInteger, BEDynamicMethodsActivationState) {
	DMSelfDisabled = -2,
	DMInheritDisabled = -1,
	DMInheritNone = 0,
	DMInheritEnabled = 1,
	DMSelfEnabled = 2
};

/*!
 @defined		isDynamicMethodsInherited
 @abstract		Macro to check if dynamic methods state is inherited.
 @param			state	A BEDynamicMethodsActivationState value.
 @discussion	Returns true if the class has no explicit dynamic methods setting
				and inherits its behavior from parent classes.
 */
#define isDynamicMethodsInherited(state) ((state) == DMInheritNone)

/*!
 @defined		isDynamicMethodsDisabled
 @abstract		Macro to check if dynamic methods are disabled.
 @param			state	A BEDynamicMethodsActivationState value.
 @discussion	Returns true if dynamic methods are disabled either explicitly
				or through inheritance.
 */
#define isDynamicMethodsDisabled(state) ((state) <= DMInheritNone)

/*!
 @defined		isDynamicMethodsEnabled
 @abstract		Macro to check if dynamic methods are enabled.
 @param			state	A BEDynamicMethodsActivationState value.
 @discussion	Returns true if dynamic methods are enabled either explicitly
				or through inheritance.
 */
#define isDynamicMethodsEnabled(state) ((state) > DMInheritNone)

/*!
 @defined		isDynamicMethodsSelf
 @abstract		Macro to check if dynamic methods state is set explicitly.
 @param			state	A BEDynamicMethodsActivationState value.
 @discussion	Returns true if the class has an explicit dynamic methods setting
				(either enabled or disabled) rather than inheriting from parents.
 */
#define isDynamicMethodsSelf(state) (((state) == DMSelfDisabled) || ((state) == DMSelfEnabled))

#pragma mark - NSObject Dynamic Methods Category

/*!
 @category		NSObject (DynamicMethods)
@abstract		Category that adds dynamic method capabilities to all NSObject instances.
  @discussion	This category provides the core functionality for adding, removing, and
 				managing dynamic methods on both individual objects and classes. It supports
 				class methods (added to all instances of a class).
 				
 				Dynamic methods are implemented using blocks and are managed through
 				associated objects to ensure proper memory management and thread safety.
 				All operations are synchronized to prevent race conditions in multi-threaded
 				environments.
 				
 				The system distinguishes between:
 				- Class methods: Added to all instances of a class
 				- Object methods: Added to specific object instances
 				- Protocol-based forwarding: Method calls forwarded to protocol implementations
				- Forward targets: Method calls forwarded to arbitrary objects
 */
@interface NSObject (DynamicMethods)

#pragma mark - Activation State Properties

/*!
 @property		isDynamicMethodsEnabled
 @abstract		The activation state of dynamic methods for this class.
 @discussion	This class property returns the current activation state of dynamic methods,
				including whether they are explicitly enabled/disabled or inherited from
				parent classes. Use the provided macros to interpret the state value.
				
				Dynamic methods must be enabled before they can be used. Classes inherit
				the enabled state from their parent classes unless explicitly overridden.
 */
@property (class, nonatomic, readonly) BEDynamicMethodsActivationState isDynamicMethodsEnabled;

/*!
 @property		allowNSDynamicMethods
 @abstract		Whether dynamic methods are allowed on Foundation classes.
 @discussion	This class property controls whether dynamic methods can be added to
				Foundation framework classes (those with names beginning with "NS").
				By default, this is NO to prevent potential conflicts with system classes.
				
				Set this to YES on specific classes if you need to add dynamic methods
				to Foundation classes. This setting is inherited by subclasses.
 */
@property (class, nonatomic, readwrite) BOOL allowNSDynamicMethods;

#pragma mark - Dynamic Methods Activation

/*!
 @method		enableDynamicMethods
 @abstract		Enables dynamic method support for this class.
 @return		YES if dynamic methods were successfully enabled, NO if they were already enabled or enabling failed.
 @discussion	This class method enables dynamic method support by installing the necessary
				method swizzling and runtime hooks. Once enabled, the class can use dynamic
				methods, protocol forwarding, and other dynamic capabilities.
				
				This method is thread-safe and can be called multiple times safely.
				Subclasses inherit dynamic method capabilities from their parents.
				
				@note This method cannot be called on NSObject itself or metaclasses.
 */
+ (BOOL)enableDynamicMethods;

/*!
 @method		disableDynamicMethods
 @abstract		Disables dynamic method support for this class.
 @return		YES if dynamic methods were successfully disabled, NO if they were already disabled or disabling failed.
 @discussion	This class method disables dynamic method support for this specific class.
				Existing dynamic methods remain in memory but will not be invoked.
				Subclasses are not affected unless they explicitly disable dynamic methods.
				
				This method is thread-safe and can be called multiple times safely.
				
				@note This method cannot be called on NSObject itself or metaclasses.
 */
+ (BOOL)disableDynamicMethods;

/*!
 @method		resetDynamicMethods
 @abstract		Resets dynamic method state to inherit from parent classes.
 @return		YES if the state was successfully reset, NO if there was no explicit state to reset.
 @discussion	This class method removes any explicit enable/disable state for this class,
				causing it to inherit dynamic method behavior from its parent classes.
				
				This method is thread-safe and can be called multiple times safely.
				
				@note This method cannot be called on NSObject itself or metaclasses.
 */
+ (BOOL)resetDynamicMethods;

#pragma mark - Instance Method Management

/*!
 @method		isDynamicClassMethod:
 @abstract		Checks if a selector represents a dynamic class method.
 @param			selector	The selector to check.
 @return		YES if the selector is a dynamic class method, NO otherwise.
 @discussion	This class method checks whether the given selector has been registered
 				as a dynamic method for all instances of this class or its parent classes.
 				Class methods are available to all instances and are inherited by subclasses.
 */
+ (BOOL)isDynamicClassMethod:(nonnull SEL)selector;

/*!
 @method		addClassMethod:block:
 @abstract		Adds a dynamic method to all instances of this class.
 @param			selector	The selector for the new method.
 @param			block		The block that implements the method.
 @return		YES if the method was successfully added, NO otherwise.
 @discussion	This class method adds a dynamic method that will be available to all
				instances of this class and its subclasses. The block should follow the format:
				
				```
				ReturnType (^)(id self, SEL _cmd, ...parameters)
				```
				
				The SEL parameter is optional. If present, the block will receive the
				actual selector used to call the method.
				
				If a method with the same selector already exists, it will be replaced
				and the previous implementation will be cleaned up automatically.
				
				This method is thread-safe and properly manages memory for the block.
				
				@warning The block parameter must be a valid block object. Passing nil
				or non-block values will result in failure.
 */
+ (BOOL)addClassMethod:(nonnull SEL)selector block:(nullable id)block;

/*!
 @method		removeClassMethod:
 @abstract		Removes a dynamic class method from this class.
 @param			selector	The selector of the method to remove.
 @return		YES if the method was successfully removed, NO if it wasn't found.
 @discussion	This class method removes a previously added dynamic class method.
 				The associated block is properly released and all metadata is cleaned up.
 				
 				This method only removes methods that were added directly to this class,
 				not methods inherited from parent classes.
 				
 				This method is thread-safe and can be called even if the method doesn't exist.
 */
+ (BOOL)removeClassMethod:(nonnull SEL)selector;

#pragma mark - Object Method Management

/*!
 @method		isDynamicObjectMethod:
 @abstract		Checks if a selector represents a dynamic object method.
 @param			selector	The selector to check.
 @return		YES if the selector is a dynamic object method, NO otherwise.
 @discussion	This method checks whether the given selector has been registered
				as a dynamic method specifically for this object instance.
				Object methods are only available to the specific instance they were added to.
 */
- (BOOL)isDynamicObjectMethod:(nonnull SEL)selector;

/*!
 @method		addObjectMethod:block:
 @abstract		Adds a dynamic method to this specific object instance.
 @param			selector	The selector for the new method.
 @param			block		The block that implements the method.
 @return		YES if the method was successfully added, NO otherwise.
 @discussion	This method adds a dynamic method that will be available only to this
				specific object instance. The block should follow the format:
				
				```
				ReturnType (^)(id self, SEL _cmd, ...parameters)
				```
				
				The SEL parameter is optional. If present, the block will receive the
				actual selector used to call the method.
				
				Object methods take precedence over class methods when both are present.
				If a method with the same selector already exists on this object, it will
				be replaced and the previous implementation will be cleaned up automatically.
				
				This method is thread-safe and properly manages memory for the block.
				
				@warning The block parameter must be a valid block object. Passing nil
				or non-block values will result in failure.
 */
- (BOOL)addObjectMethod:(nonnull SEL)selector block:(nullable id)block;

/*!
 @method		removeObjectMethod:
 @abstract		Removes a dynamic method from this specific object instance.
 @param			selector	The selector of the method to remove.
 @return		YES if the method was successfully removed, NO if it wasn't found.
 @discussion	This method removes a previously added dynamic object method.
				The associated block is properly released and all metadata is cleaned up.
				
				This method is thread-safe and can be called even if the method doesn't exist.
 */
- (BOOL)removeObjectMethod:(nonnull SEL)selector;


#pragma mark - Instance Protocol and Forward Target Management

/*!
 @method		isDynamicInstanceProtocol:
 @abstract		Checks if a protocol is registered for dynamic forwarding on this class.
 @param			protocol	The protocol to check.
 @return		YES if the protocol is registered for forwarding, NO otherwise.
 @discussion	This class method checks whether the given protocol has been registered
				for dynamic method forwarding on instances of this class or its parent classes.
 */
+ (BOOL)isDynamicInstanceProtocol:(nonnull Protocol*)protocol;

/*!
 @method		addInstanceProtocol:
 @abstract		Registers a protocol for dynamic method forwarding on instances of this class.
 @param			protocol	The protocol to register.
 @return		YES if the protocol was successfully registered, NO otherwise.
 @discussion	This class method registers a protocol for dynamic method forwarding.
				When a method from this protocol is called on an instance, the system
				will attempt to forward the call to a registered implementation class.
				
				The implementation class must be registered separately using
				addInstanceProtocol:withClass: or the protocol methods will not be forwarded.
 */
+ (BOOL)addInstanceProtocol:(nonnull Protocol *)protocol;

/*!
 @method		addInstanceForwardClass:
 @abstract		Registers a class for non-protocol-based method forwarding.
 @param			targetClass	The class to use for method forwarding.
 @return		YES if the class was successfully registered, NO otherwise.
 @discussion	This class method registers a class to handle method calls that don't
				match any existing methods or protocols. When an unrecognized method
				is called, the system will create an instance of the target class
				and forward the method call to it.
				
				Multiple forward classes can be registered. The system will try each
				one in registration order until it finds one that responds to the selector.
 */
+ (BOOL)addInstanceForwardClass:(nonnull Class)targetClass;

/*!
 @method		addInstanceProtocol:withClass:
 @abstract		Registers a protocol with its implementation class for method forwarding.
 @param			protocol		The protocol to register, or nil for non-protocol forwarding.
 @param			targetClass		The class that implements the protocol methods.
 @return		YES if the registration was successful, NO otherwise.
 @discussion	This class method registers a protocol along with the class that implements
				its methods. When a method from the protocol is called on an instance,
				the system will create an instance of the target class and forward the
				method call to it.
				
				If protocol is nil, this method behaves like addInstanceForwardClass:.
				If targetClass is nil, this method behaves like addInstanceProtocol:.
				
				The target class can optionally implement the NSProtocolImpClass protocol
				to receive a reference to the original object via setOriginalObject:.
 */
+ (BOOL)addInstanceProtocol:(nullable Protocol *)protocol withClass:(nullable Class)targetClass;

/*!
 @method		removeInstanceProtocol:
 @abstract		Unregisters a protocol from dynamic method forwarding.
 @param			protocol	The protocol to unregister.
 @return		YES if the protocol was successfully unregistered, NO if it wasn't found.
 @discussion	This class method removes a previously registered protocol from dynamic
				method forwarding. Methods from this protocol will no longer be forwarded
				to implementation classes.
 */
+ (BOOL)removeInstanceProtocol:(nonnull Protocol *)protocol;

/*!
 @method		removeInstanceForwardClass:
 @abstract		Unregisters a class from non-protocol-based method forwarding.
 @param			targetClass	The class to unregister.
 @return		YES if the class was successfully unregistered, NO if it wasn't found.
 @discussion	This class method removes a previously registered forward class from
				dynamic method forwarding. The class will no longer receive forwarded
				method calls for unrecognized selectors.
 */
+ (BOOL)removeInstanceForwardClass:(nonnull Class)targetClass;

/*!
 @method		removeInstanceProtocol:withClass:
 @abstract		Unregisters a protocol and/or class from method forwarding.
 @param			protocol		The protocol to unregister, or nil to match any protocol.
 @param			targetClass		The class to unregister, or nil to match any class.
 @return		YES if a registration was successfully removed, NO if no match was found.
 @discussion	This class method removes protocol/class registrations from dynamic method
				forwarding. The parameters work as filters:
				
				- If both protocol and targetClass are specified, only that exact combination is removed
				- If only protocol is specified, the protocol registration is removed regardless of class
				- If only targetClass is specified, all registrations for that class are removed
				- If protocol is nil, it matches non-protocol forward targets
 */
+ (BOOL)removeInstanceProtocol:(nullable Protocol *)protocol withClass:(nullable Class)targetClass;

#pragma mark - Object Protocol and Forward Target Management

/*!
 @method		isDynamicObjectProtocol:
 @abstract		Checks if a protocol is registered for dynamic forwarding on this object.
 @param			protocol	The protocol to check.
 @return		YES if the protocol is registered for forwarding, NO otherwise.
 @discussion	This method checks whether the given protocol has been registered
				for dynamic method forwarding specifically on this object instance.
 */
- (BOOL)isDynamicObjectProtocol:(nonnull Protocol*)protocol;

/*!
 @method		targetForProtocol:
 @abstract		returns the target implementation object for a specific protocol.
 @param			protocol	The protocol to retrieve the target implementation object.
 @return		The target, an NSArray when without a protocol, or nil.
 @discussion	This returns the target implementation for a specific protocol.
 				When the protocol parameter is nil or `\@protocol(NSNoProtocol)`, this
 				will return an NSArray of targets that don't have a protocol.
 				nil if none.
 */
- (nullable id)targetForProtocol:(nullable Protocol *)protocol;

/*!
 @method		addObjectProtocol:
 @abstract		Registers a protocol for dynamic method forwarding on this object.
 @param			protocol	The protocol to register.
 @return		YES if the protocol was successfully registered, NO otherwise.
 @discussion	This method registers a protocol for dynamic method forwarding on this
				specific object instance. When a method from this protocol is called,
				the system will attempt to forward the call to a registered target object.
				
				The target object must be registered separately using addObjectProtocol:withTarget:
				or the protocol methods will not be forwarded.
				
				@note Class methods cannot be implemented for object protocols. Dynamic
				class methods must use addInstanceProtocol:withClass:.
 */
- (BOOL)addObjectProtocol:(nonnull Protocol *)protocol;

/*!
 @method		addObjectForwardTarget:
 @abstract		Registers an object for non-protocol-based method forwarding.
 @param			target	The object to use for method forwarding.
 @return		YES if the target was successfully registered, NO otherwise.
 @discussion	This method registers an object to handle method calls that don't
				match any existing methods or protocols on this specific instance.
				When an unrecognized method is called, the system will forward
				the method call to the target object if it responds to the selector.
				
				Multiple forward targets can be registered, at most one per target
				class; registering a second target of the same class returns NO.
				The system consults the targets in unspecified order and forwards
				the call to the first target found that responds to the selector.
				
				@note Class methods cannot be implemented for object protocols. Dynamic
				class methods must use addInstanceProtocol:withClass:.
 */
- (BOOL)addObjectForwardTarget:(nonnull id)target;

/*!
 @method		addObjectProtocol:withTarget:
 @abstract		Registers a protocol with its target object for method forwarding.
 @param			protocol	The protocol to register, or nil for non-protocol forwarding.
 @param			target		The object that implements the protocol methods.
 @return		YES if the registration was successful, NO otherwise.
 @discussion	This method registers a protocol along with the object that implements
				its methods on this specific instance. When a method from the protocol
				is called, the system will forward the method call to the target object.
				
				If protocol is nil, this method behaves like addObjectForwardTarget:.
				If target is nil, this method behaves like addObjectProtocol:.
				
				The target object can optionally implement the NSProtocolImpClass protocol
				to receive a reference to the original object via setOriginalObject:.
				
				@note Class methods cannot be implemented for object protocols. Dynamic
				class methods must use addInstanceProtocol:withClass:.
 */
- (BOOL)addObjectProtocol:(nullable Protocol *)protocol withTarget:(nullable id)target;

/*!
 @method		removeObjectProtocol:
 @abstract		Unregisters a protocol from dynamic method forwarding on this object.
 @param			protocol	The protocol to unregister.
 @return		YES if the protocol was successfully unregistered, NO if it wasn't found.
 @discussion	This method removes a previously registered protocol from dynamic
				method forwarding on this specific object instance. Methods from this
				protocol will no longer be forwarded to target objects.
 */
- (BOOL)removeObjectProtocol:(nonnull Protocol *)protocol;

/*!
 @method		removeObjectForwardTarget:
 @abstract		Unregisters an object from non-protocol-based method forwarding.
 @param			target	The target object to unregister.
 @return		YES if the target was successfully unregistered, NO if it wasn't found.
 @discussion	This method removes a previously registered forward target from
				dynamic method forwarding on this specific object instance. The target
				will no longer receive forwarded method calls for unrecognized selectors.
 */
- (BOOL)removeObjectForwardTarget:(nonnull id)target;

/*!
 @method		removeObjectProtocol:withTarget:
 @abstract		Unregisters a protocol and/or target from method forwarding on this object.
 @param			protocol	The protocol to unregister, or nil to match any protocol.
 @param			target		The target to unregister, or nil to match any target.
 @return		YES if a registration was successfully removed, NO if no match was found.
 @discussion	This method removes protocol/target registrations from dynamic method
				forwarding on this specific object instance. The parameters work as filters:
				
				- If both protocol and target are specified, only that exact combination is removed
				- If only protocol is specified, the protocol registration is removed regardless of target
				- If only target is specified, all registrations for that target are removed
				- If protocol is nil, it matches non-protocol forward targets
 */
- (BOOL)removeObjectProtocol:(nullable Protocol *)protocol withTarget:(nullable id)target;

#pragma mark - Combined Method Checking

/*!
 @method		isDynamicMethod:
 @abstract		Checks whether a selector is a registered dynamic object or class method.
 @param			selector	The selector to check.
 @return		YES if the selector is a dynamic object method or, for non-class receivers, a
				dynamic class method; NO otherwise.
@discussion	Returns YES if any of the following is true, checked in order:
 				- The selector is a dynamic object method, or
 				- The selector is handled by an object/instance protocol target (a required
 				  protocol method, or an optional one the target responds to) or a no-protocol
 				  forward target, or
 				- The selector is a dynamic class method (for an instance receiver).
 */
- (BOOL)isDynamicMethod:(nonnull SEL)selector;

#pragma mark - Method Resolution

/*!
 @method		dynamicMethodSignatureForSelector:
 @abstract		Returns the method signature for a dynamic method or forwardable method.
 @param			aSelector	The selector to get the signature for.
 @return		The method signature for the dynamic method, or nil if not found.
 @discussion	This method returns the method signature for dynamic methods and forwardable
				methods, checking in this order:
				
				1. Object-specific dynamic methods
				2. Class-wide dynamic methods (for non-class objects)
				3. Protocol-based forwarding targets
				4. Non-protocol forwarding targets
				
				This method is used by the runtime method resolution system and should
				not typically be called directly by client code.
 */
- (nullable NSMethodSignature *)dynamicMethodSignatureForSelector:(nonnull SEL)aSelector;

/*!
 @method		dynamicForwardInvocation:
 @abstract		Forwards an invocation to a dynamic method implementation or forwarding target.
 @param			invocation	The invocation to forward.
 @return		YES if the invocation was successfully forwarded, NO if no handler was found.
 @discussion	This method handles the forwarding of method invocations to dynamic method
				implementations or registered forwarding targets. It properly handles:
				
				- Argument transformation for blocks that capture the method selector
				- Direct block invocation for dynamic methods
				- Method forwarding to protocol implementation objects
				- Method forwarding to non-protocol target objects
				
				The method checks handlers in the same order as dynamicMethodSignatureForSelector:.
				
				This method is typically called from forwardInvocation: and should not
				be called directly by client code.
 */
- (BOOL)dynamicForwardInvocation:(nonnull NSInvocation *)invocation;

@end

#pragma mark - NSDynamicObject

/*!
 @class			NSDynamicObject
 @abstract		Base class that provides automatic dynamic method support.
 @discussion	This class is a base class for objects that need dynamic
				method capabilities. It automatically enables dynamic methods and implements
				the necessary message forwarding methods to support dynamic method resolution.
				
				Subclasses of NSDynamicObject automatically support dynamic methods without
				needing to override methodSignatureForSelector:, forwardInvocation:, or
				respondsToSelector:.
				
				The class hierarchy for method resolution is:
				1. Standard Objective-C method dispatch
				2. Dynamic object methods (instance-specific)
				3. Dynamic class methods (class-wide)
				4. Protocol-based forwarding
				5. Non-protocol forwarding targets
				6. Standard message forwarding (unrecognized selector)
				
				@note This class automatically calls enableDynamicMethods and sets
				allowNSDynamicMethods to YES in its +load method.
 */
@interface NSDynamicObject : NSObject

/*!
 @method		load
 @abstract		Class initialization method that enables dynamic method support.
 @discussion	This method is called automatically when the class is loaded by the runtime.
				It enables dynamic method support and allows dynamic methods on Foundation
				classes for this class hierarchy.
				
				Subclasses do not need to override this method unless they want to customize
				the dynamic method configuration.
 */
+ (void)load;

@end

#endif	//	NSObject_DynamicMethods_h
