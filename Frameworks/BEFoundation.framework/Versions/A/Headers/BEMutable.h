/*!
 @header        BEMutable.h
 @copyright     -© 2025 Delicense - @belisoful. All rights released.
 @date          2025-01-01
 @author		belisoful@icloud.com
 @brief         Protocols and categories for object mutability and recursive copying of collections.
 @discussion    This header provides protocols and categories for determining object mutability and
				performing recursive copying operations on Foundation collections. It defines protocols
				to categorize objects based on their mutability characteristics and provides methods
				for deep copying of complex data structures.
				
				The framework includes five main protocols:
				- BEHasMutable: For classes that have mutable counterparts
				- BEMutable: For classes that are inherently mutable
				- BECollectionAbstract: For all collection classes (both mutable and immutable)
				- BECollection: For immutable collection classes
				- BEMutableCollection: For mutable collection classes
				
				Additionally, it provides recursive copying methods that can create both immutable
				and mutable deep copies of nested data structures.
				
				@note This implementation addresses the unique behavior of NSCharacterSet and
				NSMutableCharacterSet, which cannot be programmatically distinguished due to
				Apple's implementation. The framework provides BECharacterSet and BEMutableCharacterSet
				as replacements for clearer type distinction.
 */

#ifndef BEMutable_h
#define BEMutable_h

#define kCharSetDifferentiable		NO
#define kIncludeImmutableClassesWithMutableImplementation NO

#import <Foundation/Foundation.h>
#import <BEFoundation/NSMutableNumber.h>
#import <BEFoundation/BECharacterSet.h>

#pragma mark - NSObject Extensions

/*!
 @category      NSObject(BEMutableProtocol)
 @brief         Provides mutability checking capabilities to all NSObject instances.
 @discussion    This category extends NSObject with properties and methods to determine whether
				an object or class is mutable. It serves as the foundation for the mutability
				checking system throughout the framework.
				
				The implementation uses protocol conformance to determine mutability, making it
				a reliable method for checking whether objects can be modified after creation.

				## Usage

				```objc
				BOOL a = [NSMutableArray new].hasMutability;  // YES
				BOOL b = @[].hasMutability;                   // NO
				BOOL c = NSMutableArray.hasMutability;        // YES (class property)
				```
 */
@interface NSObject (BEMutableProtocol)

/*!
 @property      hasMutability
 @brief         A class property that indicates whether instances of this class are mutable.
 @discussion    This property returns YES if the class conforms to the BEMutable protocol,
				indicating that instances of this class can be modified after creation.
				For most classes, this returns NO.
 @return        YES if the class creates mutable instances, NO otherwise.
 */
@property (readonly, nonatomic, class) BOOL hasMutability;

/*!
 @property      hasMutability
 @brief         An instance property that indicates whether this specific object is mutable.
 @discussion    This property returns YES if the object's class conforms to the BEMutable protocol.
				It provides a convenient way to check mutability at the instance level without
				requiring knowledge of the specific class type.
 @return        YES if this object instance is mutable, NO otherwise.
 */
@property (readonly, nonatomic) BOOL hasMutability;

@end

#pragma mark - Mutability Protocols

/*!
 @protocol      BEHasMutable
 @brief         Identifies classes that have mutable counterparts.
 @discussion    This protocol is applied to immutable classes that have corresponding mutable
				versions. It serves as a marker to identify classes that participate in the
				mutable/immutable class hierarchy.
				
				Classes conforming to this protocol include:
				- NSSet (mutable counterpart: NSMutableSet)
				- NSOrderedSet (mutable counterpart: NSMutableOrderedSet)
				- NSArray (mutable counterpart: NSMutableArray)
				- NSDictionary (mutable counterpart: NSMutableDictionary)
				- NSIndexSet (mutable counterpart: NSMutableIndexSet)
				- NSString (mutable counterpart: NSMutableString)
				- NSData (mutable counterpart: NSMutableData)
				- NSAttributedString (mutable counterpart: NSMutableAttributedString)
				- NSURLRequest (mutable counterpart: NSMutableURLRequest)
				- BECharacterSet (mutable counterpart: BEMutableCharacterSet)
				
				@note NSCharacterSet and NSMutableCharacterSet are not included due to Apple's
				implementation where both classes share the same object hierarchy and cannot be
				programmatically distinguished.
 */
@protocol BEHasMutable
@end

/*!
 @protocol      BEMutable
 @brief         Identifies classes that are mutable.
 @discussion    This protocol is applied to classes whose instances can be modified after creation.
				It serves as a marker to identify mutable classes throughout the framework.
				
				Classes conforming to this protocol include:
				- NSMutableSet
				- NSMutableOrderedSet
				- NSMutableArray
				- NSMutableDictionary
				- NSMutableIndexSet
				- NSMutableString
				- NSMutableData
				- NSMutableAttributedString
				- NSMutableURLRequest
				- BEMutableCharacterSet
				
				@note NSMutableCharacterSet is not included due to Apple's implementation
				limitations. Use BEMutableCharacterSet instead for clear type distinction.

				## Usage

				```objc
				if (obj.hasMutability) {           // YES only when [obj class] conforms to BEMutable
				    [obj addObject:newItem];
				}
				```
 */
@protocol BEMutable
@end

#pragma mark - Collection Protocols

/*!
 @protocol      BECollectionAbstract
 @brief         Abstract protocol defining recursive copying operations for all collection classes.
 @discussion    This protocol serves as the foundation for all collection classes, both mutable
				and immutable, by defining the interface for recursive copying operations. It
				provides the core functionality that enables traversal of nested data structures
				and creation of deep copies.
				
				This protocol is inherited by both BECollection and BEMutableCollection, making
				it the common base for all collection types in the framework. It ensures that
				all collection classes provide consistent recursive copying behavior regardless
				of their mutability.
				
				The protocol supports four types of recursive copying:
				1. Complete immutable copying (copyRecursive)
				2. Collection-only immutable copying (copyCollectionRecursive)
				3. Complete mutable copying (mutableCopyRecursive)
				4. Collection-only mutable copying (mutableCopyCollectionRecursive)
				
				Classes that conform to this protocol (through BECollection or BEMutableCollection):
				- NSSet / NSMutableSet
				- NSOrderedSet / NSMutableOrderedSet
				- NSArray / NSMutableArray
				- NSDictionary / NSMutableDictionary

				## Usage

				```objc
				NSArray *nested = @[ @[@"a", @"b"], @{@"k": @"v"} ];

				NSArray *deepImmutable = [nested copyRecursive];                 // every level immutable
				NSMutableArray *deepMutable = [nested mutableCopyRecursive];     // every level mutable
				[deepMutable[0] addObject:@"c"];                                 // nested array is mutable too

				NSArray *shallowLeaves = [nested copyCollectionRecursive];       // collections copied, leaves shared
				```
 */
@protocol BECollectionAbstract

/*!
 @method        copyRecursive
 @brief         Creates an immutable recursive copy of the collection and all its elements.
 @discussion    This method performs a deep copy of the entire data structure, creating
				immutable copies of the collection itself and all nested objects. Any
				elements that conform to BECollection are recursively copied, and all
				other elements that support NSCopying are also copied.
				
				Elements that do not conform to NSCopying are shared by reference rather
				than copied. Reference cycles are detected and broken by referencing the
				already-visited node, so cyclic graphs terminate instead of recursing
				indefinitely.
 @return        A recursively copied collection. Every nested collection is immutable and
				every NSCopying leaf is replaced by its (typically immutable) copy.
 */
- (nonnull id)copyRecursive;

/*!
 @method        copyCollectionRecursive
 @brief         Creates an immutable recursive copy of collection objects only.
 @discussion    This method performs a selective deep copy, creating immutable copies
				of collection objects while leaving non-collection elements as references
				to the original objects. Only elements conforming to BECollection are
				recursively copied.
				
				This is useful when you need to prevent structural changes to nested
				collections while allowing modifications to individual elements.
 @return        An immutable copy of the collection with collection elements recursively copied.
 */
- (nonnull id)copyCollectionRecursive;

/*!
 @method        mutableCopyRecursive
 @brief         Creates a mutable recursive copy of the collection and all its elements.
 @discussion    This method performs a deep copy of the entire data structure, creating
				mutable copies where possible. Collections conforming to BECollection are
				recursively copied as mutable versions, and other elements conforming to
				NSMutableCopying are replaced by their mutable copies.

				Elements that do not conform to NSMutableCopying are shared by reference
				rather than copied. Reference cycles are detected and broken by referencing
				the already-visited node, so the element at a cycle point references the
				original object; mutating it mutates the source structure.
 @return        A recursively copied mutable collection. Every nested collection is mutable;
				non-NSMutableCopying leaves and cycle points reference the original objects.
 */
- (nonnull id)mutableCopyRecursive;

/*!
 @method        mutableCopyCollectionRecursive
 @brief         Creates a mutable recursive copy of collection objects only.
 @discussion    This method performs a selective deep copy, creating mutable copies of
				collection objects while leaving non-collection elements as references
				to the original objects. Only elements conforming to BECollection are
				recursively copied as mutable versions.
				
				This is useful when you need to allow structural changes to nested
				collections while preserving the original non-collection elements.
 @return        A mutable copy of the collection with collection elements recursively copied.
 */
- (nonnull id)mutableCopyCollectionRecursive;

@end

/*!
 @protocol      BECollection
 @brief         Identifies immutable collection classes with recursive copying capabilities.
 @discussion    This protocol combines BECollectionAbstract and BEHasMutable to identify
				immutable collection classes that support recursive copying operations and
				have mutable counterparts.
				
				Classes conforming to this protocol:
				- NSSet
				- NSOrderedSet
				- NSArray
				- NSDictionary
				
				These classes can perform recursive copying operations and have corresponding
				mutable versions available.

				## Usage

				```objc
				NSDictionary *config = @{ @"items": @[@"x", @"y"] };
				NSMutableDictionary *editable = [config mutableCopyRecursive];
				[editable[@"items"] addObject:@"z"];   // the nested NSArray is now an NSMutableArray
				```
 */
@protocol BECollection <BECollectionAbstract, BEHasMutable>
@end

/*!
 @protocol      BEMutableCollection
 @brief         Identifies mutable collection classes with recursive copying capabilities.
 @discussion    This protocol combines BECollectionAbstract and BEMutable to identify
				mutable collection classes that support recursive copying operations.
				
				Classes conforming to this protocol:
				- NSMutableSet
				- NSMutableOrderedSet
				- NSMutableArray
				- NSMutableDictionary
				
				These classes can perform recursive copying operations and are themselves mutable.
 */
@protocol BEMutableCollection <BECollectionAbstract, BEMutable>
@end

#pragma mark - Collection Categories

/*!
 @category      NSSet(BEMutableProtocol)
 @brief         Extends NSSet with mutability protocols and recursive copying methods.
 @discussion    This category adds BECollection protocol conformance to NSSet and implements
				all recursive copying methods. It enables NSSet to participate in the
				mutability checking system and provides deep copying capabilities for
				nested data structures containing sets.
 */
@interface NSSet (BEMutableProtocol) <BECollection>

/*!
 @method        copyRecursive
 @brief         Creates an immutable recursive copy of the set and all its elements.
 @return        An immutable NSSet containing recursively copied elements.
 */
- (nonnull NSSet *)copyRecursive;

/*!
 @method        copyCollectionRecursive
 @brief         Creates an immutable recursive copy of collection elements only.
 @return        An immutable NSSet with collection elements recursively copied.
 */
- (nonnull NSSet *)copyCollectionRecursive;

/*!
 @method        mutableCopyRecursive
 @brief         Creates a mutable recursive copy of the set and all its elements.
 @return        An NSMutableSet containing recursively copied elements.
 */
- (nonnull NSMutableSet *)mutableCopyRecursive;

/*!
 @method        mutableCopyCollectionRecursive
 @brief         Creates a mutable recursive copy of collection elements only.
 @return        An NSMutableSet with collection elements recursively copied.
 */
- (nonnull NSMutableSet *)mutableCopyCollectionRecursive;

@end

/*!
 @category      NSOrderedSet(BEMutableProtocol)
 @brief         Extends NSOrderedSet with mutability protocols and recursive copying methods.
 @discussion    This category adds BECollection protocol conformance to NSOrderedSet and
				implements all recursive copying methods. It enables NSOrderedSet to
				participate in the mutability checking system and provides deep copying
				capabilities for nested data structures containing ordered sets.
 */
@interface NSOrderedSet (BEMutableProtocol) <BECollection>

/*!
 @method        copyRecursive
 @brief         Creates an immutable recursive copy of the ordered set and all its elements.
 @return        An immutable NSOrderedSet containing recursively copied elements.
 */
- (nonnull NSOrderedSet *)copyRecursive;

/*!
 @method        copyCollectionRecursive
 @brief         Creates an immutable recursive copy of collection elements only.
 @return        An immutable NSOrderedSet with collection elements recursively copied.
 */
- (nonnull NSOrderedSet *)copyCollectionRecursive;

/*!
 @method        mutableCopyRecursive
 @brief         Creates a mutable recursive copy of the ordered set and all its elements.
 @return        An NSMutableOrderedSet containing recursively copied elements.
 */
- (nonnull NSMutableOrderedSet *)mutableCopyRecursive;

/*!
 @method        mutableCopyCollectionRecursive
 @brief         Creates a mutable recursive copy of collection elements only.
 @return        An NSMutableOrderedSet with collection elements recursively copied.
 */
- (nonnull NSMutableOrderedSet *)mutableCopyCollectionRecursive;

@end

/*!
 @category      NSArray(BEMutableProtocol)
 @brief         Extends NSArray with mutability protocols and recursive copying methods.
 @discussion    This category adds BECollection protocol conformance to NSArray and
				implements all recursive copying methods. It enables NSArray to participate
				in the mutability checking system and provides deep copying capabilities
				for nested data structures containing arrays.
 */
@interface NSArray (BEMutableProtocol) <BECollection>

/*!
 @method        copyRecursive
 @brief         Creates an immutable recursive copy of the array and all its elements.
 @return        An immutable NSArray containing recursively copied elements.
 */
- (nonnull NSArray *)copyRecursive;

/*!
 @method        copyCollectionRecursive
 @brief         Creates an immutable recursive copy of collection elements only.
 @return        An immutable NSArray with collection elements recursively copied.
 */
- (nonnull NSArray *)copyCollectionRecursive;

/*!
 @method        mutableCopyRecursive
 @brief         Creates a mutable recursive copy of the array and all its elements.
 @return        An NSMutableArray containing recursively copied elements.
 */
- (nonnull NSMutableArray *)mutableCopyRecursive;

/*!
 @method        mutableCopyCollectionRecursive
 @brief         Creates a mutable recursive copy of collection elements only.
 @return        An NSMutableArray with collection elements recursively copied.
 */
- (nonnull NSMutableArray *)mutableCopyCollectionRecursive;

@end

/*!
 @category      NSDictionary(BEMutableProtocol)
 @brief         Extends NSDictionary with mutability protocols and recursive copying methods.
 @discussion    This category adds BECollection protocol conformance to NSDictionary and
				implements all recursive copying methods. It enables NSDictionary to
				participate in the mutability checking system and provides deep copying
				capabilities for nested data structures containing dictionaries.
				
				@note Only dictionary values are recursively copied; keys are preserved
				as-is since they should be immutable according to NSDictionary requirements.
 */
@interface NSDictionary (BEMutableProtocol) <BECollection>

/*!
 @method        copyRecursive
 @brief         Creates an immutable recursive copy of the dictionary and all its values.
 @return        An immutable NSDictionary containing recursively copied values.
 */
- (nonnull NSDictionary *)copyRecursive;

/*!
 @method        copyCollectionRecursive
 @brief         Creates an immutable recursive copy of collection values only.
 @return        An immutable NSDictionary with collection values recursively copied.
 */
- (nonnull NSDictionary *)copyCollectionRecursive;

/*!
 @method        mutableCopyRecursive
 @brief         Creates a mutable recursive copy of the dictionary and all its values.
 @return        An NSMutableDictionary containing recursively copied values.
 */
- (nonnull NSMutableDictionary *)mutableCopyRecursive;

/*!
 @method        mutableCopyCollectionRecursive
 @brief         Creates a mutable recursive copy of collection values only.
 @return        An NSMutableDictionary with collection values recursively copied.
 */
- (nonnull NSMutableDictionary *)mutableCopyCollectionRecursive;

@end




#pragma mark - BEMutableCollection

/*!
 @category      NSMutableSet(BEMutableProtocol)
 @brief         Extends NSMutableSet with BEMutableCollection protocol conformance and mutability checking.
 @discussion    This category adds BEMutableCollection protocol conformance to NSMutableSet, enabling
				it to participate in the framework's mutability checking system and recursive copying
				operations. NSMutableSet inherits all recursive copying methods from its superclass
				NSSet through the BECollectionAbstract protocol.
				
				The category provides both class-level and instance-level mutability checking methods
				that consistently return YES, indicating that NSMutableSet instances are always mutable.
				
				@note This category works in conjunction with the NSSet(BEMutableProtocol) category
				to provide complete mutability support for set collections.
 */
@interface NSMutableSet (BEMutableProtocol) <BEMutableCollection>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSMutableSet instances are mutable.
 @discussion    This class method always returns YES, indicating that all instances of NSMutableSet
				are mutable and can be modified after creation.
 @return        YES, indicating that NSMutableSet instances are mutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSMutableSet instance is mutable.
 @discussion    This instance method always returns YES, confirming that this specific NSMutableSet
				instance can be modified after creation.
 @return        YES, indicating that this NSMutableSet instance is mutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSMutableOrderedSet(BEMutableProtocol)
 @brief         Extends NSMutableOrderedSet with BEMutableCollection protocol conformance and mutability checking.
 @discussion    This category adds BEMutableCollection protocol conformance to NSMutableOrderedSet,
				enabling it to participate in the framework's mutability checking system and recursive
				copying operations. NSMutableOrderedSet inherits all recursive copying methods from
				its superclass NSOrderedSet through the BECollectionAbstract protocol.
				
				The category provides both class-level and instance-level mutability checking methods
				that consistently return YES, indicating that NSMutableOrderedSet instances are always mutable.
				
				@note This category works in conjunction with the NSOrderedSet(BEMutableProtocol) category
				to provide complete mutability support for ordered set collections.
 */
@interface NSMutableOrderedSet (BEMutableProtocol) <BEMutableCollection>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSMutableOrderedSet instances are mutable.
 @discussion    This class method always returns YES, indicating that all instances of NSMutableOrderedSet
				are mutable and can be modified after creation.
 @return        YES, indicating that NSMutableOrderedSet instances are mutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSMutableOrderedSet instance is mutable.
 @discussion    This instance method always returns YES, confirming that this specific NSMutableOrderedSet
				instance can be modified after creation.
 @return        YES, indicating that this NSMutableOrderedSet instance is mutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSMutableArray(BEMutableProtocol)
 @brief         Extends NSMutableArray with BEMutableCollection protocol conformance and mutability checking.
 @discussion    This category adds BEMutableCollection protocol conformance to NSMutableArray,
				enabling it to participate in the framework's mutability checking system and recursive
				copying operations. NSMutableArray inherits all recursive copying methods from
				its superclass NSArray through the BECollectionAbstract protocol.
				
				The category provides both class-level and instance-level mutability checking methods
				that consistently return YES, indicating that NSMutableArray instances are always mutable.
				
				@note This category works in conjunction with the NSArray(BEMutableProtocol) category
				to provide complete mutability support for array collections.
 */
@interface NSMutableArray (BEMutableProtocol) <BEMutableCollection>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSMutableArray instances are mutable.
 @discussion    This class method always returns YES, indicating that all instances of NSMutableArray
				are mutable and can be modified after creation.
 @return        YES, indicating that NSMutableArray instances are mutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSMutableArray instance is mutable.
 @discussion    This instance method always returns YES, confirming that this specific NSMutableArray
				instance can be modified after creation.
 @return        YES, indicating that this NSMutableArray instance is mutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSMutableDictionary(BEMutableProtocol)
 @brief         Extends NSMutableDictionary with BEMutableCollection protocol conformance and mutability checking.
 @discussion    This category adds BEMutableCollection protocol conformance to NSMutableDictionary,
				enabling it to participate in the framework's mutability checking system and recursive
				copying operations. NSMutableDictionary inherits all recursive copying methods from
				its superclass NSDictionary through the BECollectionAbstract protocol.
				
				The category provides both class-level and instance-level mutability checking methods
				that consistently return YES, indicating that NSMutableDictionary instances are always mutable.
				
				@note This category works in conjunction with the NSDictionary(BEMutableProtocol) category
				to provide complete mutability support for dictionary collections.
 */
@interface NSMutableDictionary (BEMutableProtocol) <BEMutableCollection>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSMutableDictionary instances are mutable.
 @discussion    This class method always returns YES, indicating that all instances of NSMutableDictionary
				are mutable and can be modified after creation.
 @return        YES, indicating that NSMutableDictionary instances are mutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSMutableDictionary instance is mutable.
 @discussion    This instance method always returns YES, confirming that this specific NSMutableDictionary
				instance can be modified after creation.
 @return        YES, indicating that this NSMutableDictionary instance is mutable.
 */
- (BOOL)hasMutability;

@end

#pragma mark - BEHasMutable

/*!
 @category      NSIndexSet(BEMutableProtocol)
 @brief         Extends NSIndexSet with BEHasMutable protocol conformance and mutability checking.
 @discussion    This category adds BEHasMutable protocol conformance to NSIndexSet, indicating that
				it has a mutable counterpart (NSMutableIndexSet) and enabling it to participate in
				the framework's mutability checking system.
				
				NSIndexSet represents an immutable collection of unique unsigned integers, often used
				for representing sets of array indices. The mutability checking methods consistently
				return NO, indicating that NSIndexSet instances cannot be modified after creation.
 */
@interface NSIndexSet (BEMutableProtocol) <BEHasMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSIndexSet instances are immutable.
 @discussion    This class method always returns NO, indicating that all instances of NSIndexSet
				are immutable and cannot be modified after creation.
 @return        NO, indicating that NSIndexSet instances are immutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSIndexSet instance is immutable.
 @discussion    This instance method always returns NO, confirming that this specific NSIndexSet
				instance cannot be modified after creation.
 @return        NO, indicating that this NSIndexSet instance is immutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSNumber(BEMutableProtocol)
 @brief         Extends NSNumber with BEHasMutable protocol conformance and mutability checking.
 @discussion    This category adds BEHasMutable protocol conformance to NSNumber, indicating that
				it has a mutable counterpart (NSMutableNumber) and enabling it to participate in
				the framework's mutability checking system.
				
				NSNumber represents an immutable object wrapper for numeric values. The mutability
				checking methods consistently return NO, indicating that NSNumber instances cannot
				be modified after creation.
				
				@note NSMutableNumber is a custom class that extends NSNumber with mutable capabilities.
 */
@interface NSNumber (BEMutableProtocol) <BEHasMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSNumber instances are immutable.
 @discussion    This class method always returns NO, indicating that all instances of NSNumber
				are immutable and cannot be modified after creation.
 @return        NO, indicating that NSNumber instances are immutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSNumber instance is immutable.
 @discussion    This instance method always returns NO, confirming that this specific NSNumber
				instance cannot be modified after creation.
 @return        NO, indicating that this NSNumber instance is immutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSString(BEMutableProtocol)
 @brief         Extends NSString with BEHasMutable protocol conformance and mutability checking.
 @discussion    This category adds BEHasMutable protocol conformance to NSString, indicating that
				it has a mutable counterpart (NSMutableString) and enabling it to participate in
				the framework's mutability checking system.
				
				NSString represents an immutable sequence of Unicode characters. The class-level
				mutability checking method consistently returns NO, indicating that NSString instances
				are designed to be immutable.
				
				@note The instance-level mutability checking method is conditionally compiled based
				on the kIncludeImmutableClassesWithMutableImplementation macro, as NSString's internal
				implementation may use mutable backing stores even for immutable instances.
 */
@interface NSString (BEMutableProtocol) <BEHasMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSString instances are immutable.
 @discussion    This class method always returns NO, indicating that all instances of NSString
				are designed to be immutable and should not be modified after creation.
 @return        NO, indicating that NSString instances are immutable.
 */
+ (BOOL)hasMutability;

#if kIncludeImmutableClassesWithMutableImplementation
/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSString instance is immutable.
 @discussion    This instance method always returns NO, confirming that this specific NSString
				instance should not be modified after creation.
				
				@note This method is only available when kIncludeImmutableClassesWithMutableImplementation
				is defined as YES, as NSString's internal implementation may use mutable backing stores.
 @return        NO, indicating that this NSString instance is immutable.
 */
- (BOOL)hasMutability;
#endif

@end

/*!
 @category      NSData(BEMutableProtocol)
 @brief         Extends NSData with BEHasMutable protocol conformance and mutability checking.
 @discussion    This category adds BEHasMutable protocol conformance to NSData, indicating that
				it has a mutable counterpart (NSMutableData) and enabling it to participate in
				the framework's mutability checking system.
				
				NSData represents an immutable sequence of bytes. The mutability checking methods
				consistently return NO, indicating that NSData instances cannot be modified after creation.
 */
@interface NSData (BEMutableProtocol) <BEHasMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSData instances are immutable.
 @discussion    This class method always returns NO, indicating that all instances of NSData
				are immutable and cannot be modified after creation.
 @return        NO, indicating that NSData instances are immutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSData instance is immutable.
 @discussion    This instance method always returns NO, confirming that this specific NSData
				instance cannot be modified after creation.
 @return        NO, indicating that this NSData instance is immutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSAttributedString(BEMutableProtocol)
 @brief         Extends NSAttributedString with BEHasMutable protocol conformance and mutability checking.
 @discussion    This category adds BEHasMutable protocol conformance to NSAttributedString, indicating
				that it has a mutable counterpart (NSMutableAttributedString) and enabling it to
				participate in the framework's mutability checking system.
				
				NSAttributedString represents an immutable string with associated attributes for
				portions of its text. The mutability checking methods consistently return NO,
				indicating that NSAttributedString instances cannot be modified after creation.
 */
@interface NSAttributedString (BEMutableProtocol) <BEHasMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSAttributedString instances are immutable.
 @discussion    This class method always returns NO, indicating that all instances of NSAttributedString
				are immutable and cannot be modified after creation.
 @return        NO, indicating that NSAttributedString instances are immutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSAttributedString instance is immutable.
 @discussion    This instance method always returns NO, confirming that this specific NSAttributedString
				instance cannot be modified after creation.
 @return        NO, indicating that this NSAttributedString instance is immutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSURLRequest(BEMutableProtocol)
 @brief         Extends NSURLRequest with BEHasMutable protocol conformance and mutability checking.
 @discussion    This category adds BEHasMutable protocol conformance to NSURLRequest, indicating
				that it has a mutable counterpart (NSMutableURLRequest) and enabling it to participate
				in the framework's mutability checking system.
				
				NSURLRequest represents an immutable URL load request. The mutability checking methods
				consistently return NO, indicating that NSURLRequest instances cannot be modified after creation.
 */
@interface NSURLRequest (BEMutableProtocol) <BEHasMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSURLRequest instances are immutable.
 @discussion    This class method always returns NO, indicating that all instances of NSURLRequest
				are immutable and cannot be modified after creation.
 @return        NO, indicating that NSURLRequest instances are immutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSURLRequest instance is immutable.
 @discussion    This instance method always returns NO, confirming that this specific NSURLRequest
				instance cannot be modified after creation.
 @return        NO, indicating that this NSURLRequest instance is immutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSCharacterSet(BEMutableProtocol)
 @brief         Extends NSCharacterSet with conditional BEHasMutable protocol conformance and mutability checking.
 @discussion    This category conditionally adds BEHasMutable protocol conformance to NSCharacterSet
				based on the kCharSetDifferentiable macro setting. When kCharSetDifferentiable is NO,
				the category does not conform to BEHasMutable due to Apple's implementation where
				NSCharacterSet and NSMutableCharacterSet cannot be programmatically distinguished.
				
				NSCharacterSet represents an immutable set of Unicode characters. The class-level
				mutability checking method consistently returns NO, indicating that NSCharacterSet
				instances are designed to be immutable.
				
				@note Due to Apple's implementation, NSCharacterSet and NSMutableCharacterSet share
				the same object hierarchy, making programmatic distinction impossible. Consider using
				BECharacterSet and BEMutableCharacterSet for clearer type distinction.
 */
#if kCharSetDifferentiable
@interface NSCharacterSet (BEMutableProtocol) <BEHasMutable>
#else
@interface NSCharacterSet (BEMutableProtocol)
#endif

/*!
 @method        hasMutability
 @brief         Class method that indicates NSCharacterSet instances are immutable.
 @discussion    This class method always returns NO, indicating that all instances of NSCharacterSet
				are designed to be immutable and should not be modified after creation.
 @return        NO, indicating that NSCharacterSet instances are immutable.
 */
+ (BOOL)hasMutability;

#if kIncludeImmutableClassesWithMutableImplementation
/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSCharacterSet instance is immutable.
 @discussion    This instance method always returns NO, confirming that this specific NSCharacterSet
				instance should not be modified after creation.
				
				@note This method is only available when kIncludeImmutableClassesWithMutableImplementation
				is defined as YES, as NSCharacterSet's internal implementation may use mutable backing stores.
 @return        NO, indicating that this NSCharacterSet instance is immutable.
 */
- (BOOL)hasMutability;
#endif

@end

/*!
 @category      BECharacterSet(BEMutableProtocol)
 @brief         Extends BECharacterSet with BEHasMutable protocol conformance and mutability checking.
 @discussion    This category adds BEHasMutable protocol conformance to BECharacterSet, indicating
				that it has a mutable counterpart (BEMutableCharacterSet) and enabling it to participate
				in the framework's mutability checking system.
				
				BECharacterSet is a custom character set class that provides clear type distinction
				between immutable and mutable character sets, addressing the limitations of Apple's
				NSCharacterSet and NSMutableCharacterSet implementation.
				
				@note This class is recommended over NSCharacterSet when clear mutability distinction
				is required, as it provides reliable programmatic differentiation.
 */
@interface BECharacterSet (BEMutableProtocol) <BEHasMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates BECharacterSet instances are immutable.
 @discussion    This class method always returns NO, indicating that all instances of BECharacterSet
				are immutable and cannot be modified after creation.
 @return        NO, indicating that BECharacterSet instances are immutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this BECharacterSet instance is immutable.
 @discussion    This instance method always returns NO, confirming that this specific BECharacterSet
				instance cannot be modified after creation.
 @return        NO, indicating that this BECharacterSet instance is immutable.
 */
- (BOOL)hasMutability;

@end

#pragma mark - BEMutable

/*!
 @category      NSMutableIndexSet(BEMutableProtocol)
 @brief         Extends NSMutableIndexSet with BEMutable protocol conformance and mutability checking.
 @discussion    This category adds BEMutable protocol conformance to NSMutableIndexSet, enabling
				it to participate in the framework's mutability checking system as a mutable class.
				
				NSMutableIndexSet represents a mutable collection of unique unsigned integers that
				can be modified after creation. The mutability checking methods consistently return
				YES, indicating that NSMutableIndexSet instances are always mutable.
				
				@note This category works in conjunction with the NSIndexSet(BEMutableProtocol) category
				to provide complete mutability support for index set collections.
 */
@interface NSMutableIndexSet (BEMutableProtocol) <BEMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSMutableIndexSet instances are mutable.
 @discussion    This class method always returns YES, indicating that all instances of NSMutableIndexSet
				are mutable and can be modified after creation.
 @return        YES, indicating that NSMutableIndexSet instances are mutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSMutableIndexSet instance is mutable.
 @discussion    This instance method always returns YES, confirming that this specific NSMutableIndexSet
				instance can be modified after creation.
 @return        YES, indicating that this NSMutableIndexSet instance is mutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSMutableNumber(BEMutableProtocol)
 @brief         Extends NSMutableNumber with BEMutable protocol conformance and mutability checking.
 @discussion    This category adds BEMutable protocol conformance to NSMutableNumber, enabling
				it to participate in the framework's mutability checking system as a mutable class.
				
				NSMutableNumber is a custom class that extends NSNumber with mutable capabilities,
				allowing numeric values to be modified after creation. The mutability checking methods
				consistently return YES, indicating that NSMutableNumber instances are always mutable.
				
				@note This class provides mutable number functionality that is not available in
				Foundation's standard NSNumber class.
 */
@interface NSMutableNumber (BEMutableProtocol) <BEMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSMutableNumber instances are mutable.
 @discussion    This class method always returns YES, indicating that all instances of NSMutableNumber
				are mutable and can be modified after creation.
 @return        YES, indicating that NSMutableNumber instances are mutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSMutableNumber instance is mutable.
 @discussion    This instance method always returns YES, confirming that this specific NSMutableNumber
				instance can be modified after creation.
 @return        YES, indicating that this NSMutableNumber instance is mutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSMutableString(BEMutableProtocol)
 @brief         Extends NSMutableString with BEMutable protocol conformance and mutability checking.
 @discussion    This category adds BEMutable protocol conformance to NSMutableString, enabling
				it to participate in the framework's mutability checking system.

				NSString is a class cluster, so the static type does not determine mutability.
				The mutability checking methods inspect the concrete backing class instead of
				returning a constant.

				@note This category works in conjunction with the NSString(BEMutableProtocol) category
				to provide complete mutability support for string objects.
 */
@interface NSMutableString (BEMutableProtocol) <BEMutable>

/*!
 @method        hasMutability
 @brief         Class method that reports whether the receiver class backs mutable string instances.
 @discussion    Mutability is inferred from the concrete class within the NSString class cluster.
				Returns YES for __NSCFString (the backing class of mutable instances) and for
				BEMutable-conforming classes such as NSMutableString itself; returns NO for
				__NSCFConstantString.
 @return        YES if the receiver class backs mutable string instances, NO otherwise.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that reports whether this string instance is mutable.
 @discussion    Mutability is inferred from the concrete backing class within the NSString class
				cluster. Returns YES only when the instance is backed by __NSCFString; any other
				backing class, including __NSCFConstantString, returns NO. This method does not
				consult BEMutable protocol conformance, so an instance of a conforming custom
				subclass returns NO.
 @return        YES if the instance is backed by __NSCFString, NO otherwise.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSMutableData(BEMutableProtocol)
 @brief         Extends NSMutableData with BEMutable protocol conformance and mutability checking.
 @discussion    This category adds BEMutable protocol conformance to NSMutableData, enabling
				it to participate in the framework's mutability checking system as a mutable class.
				
				NSMutableData represents a mutable sequence of bytes that can be modified after
				creation. The mutability checking methods consistently return YES, indicating that
				NSMutableData instances are always mutable.
				
				@note This category works in conjunction with the NSData(BEMutableProtocol) category
				to provide complete mutability support for data objects.
 */
@interface NSMutableData (BEMutableProtocol) <BEMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSMutableData instances are mutable.
 @discussion    This class method always returns YES, indicating that all instances of NSMutableData
				are mutable and can be modified after creation.
 @return        YES, indicating that NSMutableData instances are mutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSMutableData instance is mutable.
 @discussion    This instance method always returns YES, confirming that this specific NSMutableData
				instance can be modified after creation.
 @return        YES, indicating that this NSMutableData instance is mutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSMutableAttributedString(BEMutableProtocol)
 @brief         Extends NSMutableAttributedString with BEMutable protocol conformance and mutability checking.
 @discussion    This category adds BEMutable protocol conformance to NSMutableAttributedString, enabling
				it to participate in the framework's mutability checking system as a mutable class.
				
				NSMutableAttributedString represents a mutable string with associated attributes for
				portions of its text that can be modified after creation. The mutability checking methods
				consistently return YES, indicating that NSMutableAttributedString instances are always mutable.
				
				@note This category works in conjunction with the NSAttributedString(BEMutableProtocol)
				category to provide complete mutability support for attributed string objects.
 */
@interface NSMutableAttributedString (BEMutableProtocol) <BEMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSMutableAttributedString instances are mutable.
 @discussion    This class method always returns YES, indicating that all instances of NSMutableAttributedString
				are mutable and can be modified after creation.
 @return        YES, indicating that NSMutableAttributedString instances are mutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSMutableAttributedString instance is mutable.
 @discussion    This instance method always returns YES, confirming that this specific NSMutableAttributedString
				instance can be modified after creation.
 @return        YES, indicating that this NSMutableAttributedString instance is mutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSMutableURLRequest(BEMutableProtocol)
 @brief         Extends NSMutableURLRequest with BEMutable protocol conformance and mutability checking.
 @discussion    This category adds BEMutable protocol conformance to NSMutableURLRequest, enabling
				it to participate in the framework's mutability checking system as a mutable class.
				
				NSMutableURLRequest represents a mutable URL load request that can be modified after
				creation. The mutability checking methods consistently return YES, indicating that
				NSMutableURLRequest instances are always mutable.
				
				@note This category works in conjunction with the NSURLRequest(BEMutableProtocol)
				category to provide complete mutability support for URL request objects.
 */
@interface NSMutableURLRequest (BEMutableProtocol) <BEMutable>

/*!
 @method        hasMutability
 @brief         Class method that indicates NSMutableURLRequest instances are mutable.
 @discussion    This class method always returns YES, indicating that all instances of NSMutableURLRequest
				are mutable and can be modified after creation.
 @return        YES, indicating that NSMutableURLRequest instances are mutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSMutableURLRequest instance is mutable.
 @discussion    This instance method always returns YES, confirming that this specific NSMutableURLRequest
				instance can be modified after creation.
 @return        YES, indicating that this NSMutableURLRequest instance is mutable.
 */
- (BOOL)hasMutability;

@end

/*!
 @category      NSMutableCharacterSet(BEMutableProtocol)
 @brief         Extends NSMutableCharacterSet with conditional BEMutable protocol conformance and mutability checking.
 @discussion    This category conditionally adds BEMutable protocol conformance to NSMutableCharacterSet
				based on the kCharSetDifferentiable macro setting. When kCharSetDifferentiable is NO,
				the category does not conform to BEMutable due to Apple's implementation where
				NSCharacterSet and NSMutableCharacterSet cannot be programmatically distinguished.
				
				NSMutableCharacterSet represents a mutable set of Unicode characters that can be
				modified after creation. The mutability checking methods return values based on
				the kCharSetDifferentiable setting.
				
				@note Due to Apple's implementation limitations, consider using BEMutableCharacterSet
				for clearer type distinction and reliable mutability checking.
 */
#if kCharSetDifferentiable
@interface NSMutableCharacterSet (BEMutableProtocol) <BEMutable>
#else
@interface NSMutableCharacterSet (BEMutableProtocol)
#endif

/*!
 @method        hasMutability
 @brief         Class method that indicates NSMutableCharacterSet mutability based on framework configuration.
 @discussion    This class method returns the value of kCharSetDifferentiable, which determines whether
				NSMutableCharacterSet instances are treated as distinguishably mutable within the framework.
				When kCharSetDifferentiable is NO, this method returns NO due to Apple's implementation
				limitations.
 @return        The value of kCharSetDifferentiable, indicating whether NSMutableCharacterSet instances
				are treated as distinguishably mutable.
 */
+ (BOOL)hasMutability;

/*!
 @method        hasMutability
 @brief         Instance method that indicates this NSMutableCharacterSet mutability based on framework configuration.
 @discussion    This instance method returns the value of kCharSetDifferentiable, which determines whether
				this NSMutableCharacterSet instance is treated as distinguishably mutable within the framework.
				When kCharSetDifferentiable is NO, this method returns NO due to Apple's implementation
				limitations.
 @return        The value of kCharSetDifferentiable, indicating whether this NSMutableCharacterSet instance
				is treated as distinguishably mutable.
 */
- (BOOL)hasMutability;

@end


/*!
@category      BEMutableCharacterSet(BEMutableProtocol)
@abstract      A category that extends BEMutableCharacterSet to conform to the BEMutable protocol.
@discussion    This category provides runtime mutability detection for BEMutableCharacterSet instances.
			   
			   NSCharacterSet and NSMutableCharacterSet share the same underlying implementation, with NSMutableCharacterSet
			   being a subclass of NSCharacterSet. This architectural design makes it impossible to differentiate between
			   mutable and immutable character sets programmatically using standard Foundation methods.
			   
			   The BEMutableCharacterSet category addresses this limitation by implementing the BEMutable protocol,
			   providing consistent mutability detection across all BE framework classes. This ensures that applications
			   can reliably determine the mutability state of character set instances at runtime.
			   
			   ## Usage
			   
			   Use the `hasMutability` method to determine whether a character set instance supports mutation operations:
			   
			   ```objc
			   BEMutableCharacterSet *mutableSet = [[BEMutableCharacterSet alloc] init];
			   BOOL canMutate = [mutableSet hasMutability]; // Returns YES
			   ```
			   
			   This category maintains consistency with other mutable/immutable class pairs in the BE framework,
			   such as NSString/NSMutableString, ensuring predictable behavior across all collection types.
*/
@interface BEMutableCharacterSet (BEMutableProtocol) <BEMutable>

/*!
@method        hasMutability
@abstract      Returns whether the BEMutableCharacterSet class supports mutation operations.
@discussion    This class method always returns `YES` since BEMutableCharacterSet is designed to be mutable.
			   
			   Use this method when you need to determine the mutability characteristics of the BEMutableCharacterSet
			   class itself, rather than a specific instance.
			   
@return        `YES` indicating that BEMutableCharacterSet supports mutation operations.
*/
+ (BOOL)hasMutability;

/*!
@method        hasMutability
@abstract      Returns whether this character set instance supports mutation operations.
@discussion    This instance method always returns `YES` for BEMutableCharacterSet instances, indicating
			   that the receiver can be safely modified using mutation methods such as `addCharactersInString:`,
			   `removeCharactersInString:`, and `formUnionWithCharacterSet:`.
			   
			   This method provides runtime mutability detection, allowing code to conditionally perform mutation
			   operations based on the actual mutability state of the character set instance.
			   
@return        `YES` indicating that this instance supports mutation operations.
*/
- (BOOL)hasMutability;

@end

#endif
