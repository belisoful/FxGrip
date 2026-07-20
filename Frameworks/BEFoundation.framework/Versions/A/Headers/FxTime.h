/*!
 @header 		FxTime.h
 @copyright 	-© 2025 Delicense - @belisoful. All rights released.
 @date 			2025-01-01
 @author		belisoful@icloud.com
 @abstract 		An Objective-C wrapper for CoreMedia's CMTime structure providing time manipulation and arithmetic operations.
 @discussion	FxTime encapsulates CoreMedia's CMTime structure in an Objective-C object, providing an object-oriented interface for time-based operations in media applications. This class supports all standard CMTime operations including arithmetic, comparison, and conversion while maintaining compatibility with NSSecureCoding, NSCopying, and NSMutableCopying protocols.

 The class provides factory methods for creating common time values (zero, invalid, infinity) and supports various initialization methods for different time representations.

 FxTime is immutable and therefore thread-safe: its wrapped CMTime cannot change after creation. For in-place arithmetic and component mutation, use the mutable subclass FxMutableTime (obtained via -mutableCopy or its own factory/initializers). This mirrors the NSString/NSMutableString and NSNumber idioms.
 */

#ifndef FxTime_h
#define FxTime_h

#import <Foundation/Foundation.h>
#import <CoreMedia/CMTime.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @struct SRational32
 @abstract A structure representing a rational number with 32-bit integer components.
 @discussion
 This structure is used to represent fractional values as a ratio of two integers, providing precise representation of decimal numbers without floating-point precision loss.
 @field multiplier The numerator of the rational number.
 @field divisor The denominator of the rational number.
 */
struct SRational32 {
	int32_t multiplier;
	int32_t divisor;
};
typedef struct SRational32 SRational32;

/*!
 @class FxTime
 @abstract An Objective-C wrapper for CoreMedia's CMTime structure.
 @discussion
 FxTime provides an object-oriented interface for working with time values in media applications. It encapsulates a CMTime structure and provides methods for comparison and conversion operations.

 The class supports secure coding and copying, making it suitable for serialization and for use as a thread-safe, immutable time representation.

 FxTime is immutable. Arithmetic and component mutation live on the mutable subclass FxMutableTime; create one with -mutableCopy (or FxMutableTime's factory/initializers) to perform in-place operations.

 @code
 // Half a second at a 600 timescale.
 FxTime *t = [FxTime time:CMTimeMake(300, 600)];
 NSLog(@"%.3f s", t.seconds);              // 0.500 s
 NSLog(@"%lld / %d", t.value, t.timescale); // 300 / 600

 if (t.isNumeric && [t compare:[FxTime zero]] > 0) {
     NSLog(@"t is a positive, finite time");
 }
 @endcode
 */
@interface FxTime : NSObject <NSSecureCoding, NSCopying, NSMutableCopying> {
@protected
	// Declared here (rather than left to auto-synthesis) so the FxMutableTime
	// subclass, implemented in the same translation unit, can mutate it directly.
	CMTime _time;
}

/*!
 @property time
 @abstract The underlying CMTime structure (read-only on the immutable base class).
 @discussion
 Direct read access to the wrapped CMTime structure. FxMutableTime redeclares this
 property read-write for in-place mutation.
 */
@property (readonly) CMTime time;

#pragma mark - Factory Methods

/*!
 @method time:
 @abstract Creates a new FxTime instance with the specified CMTime value.
 @param time The CMTime value to wrap.
 @return A new autoreleased FxTime instance.
 @discussion
 This is the primary factory method for creating FxTime instances from existing CMTime values.
 */
+ (instancetype)time:(CMTime)time;

/*!
 @method timeWithDictionary:
 @abstract Creates a new FxTime instance from a dictionary representation.
 @param timeDictionary A dictionary containing CMTime components as created by CMTimeCopyAsDictionary.
 @return A new autoreleased FxTime instance.
 @discussion
 This method is useful for deserializing time values from property lists or other dictionary-based storage formats.
 */
+ (instancetype)timeWithDictionary:(NSDictionary*)timeDictionary;

/*!
 @method invalid
 @abstract Creates an invalid time value.
 @return A new FxTime instance representing an invalid time (kCMTimeInvalid).
 @discussion
 Invalid times are used to represent uninitialized or error states in time calculations.
 */
+ (instancetype)invalid;

/*!
 @method indefinite
 @abstract Creates an indefinite time value.
 @return A new FxTime instance representing an indefinite time (kCMTimeIndefinite).
 @discussion
 Indefinite times are used to represent unknown or unbounded durations.
 */
+ (instancetype)indefinite;

/*!
 @method infinity
 @abstract Creates a positive infinity time value.
 @return A new FxTime instance representing positive infinity (kCMTimePositiveInfinity).
 @discussion
 Positive infinity is used to represent unlimited future time or maximum duration values.
 */
+ (instancetype)infinity;

/*!
 @method minusInfinity
 @abstract Creates a negative infinity time value.
 @return A new FxTime instance representing negative infinity (kCMTimeNegativeInfinity).
 @discussion
 Negative infinity is used to represent unlimited past time or minimum duration values.
 */
+ (instancetype)minusInfinity;

/*!
 @method zero
 @abstract Creates a zero time value.
 @return A new FxTime instance representing zero time (kCMTimeZero).
 @discussion
 Zero time represents the origin point for time calculations and is commonly used as a starting reference.
 */
+ (instancetype)zero;

#pragma mark - Initialization Methods

/*!
 @method initWithTime:
 @abstract Initializes a new FxTime instance by copying another FxTime instance.
 @param time The FxTime instance to copy.
 @return An initialized FxTime instance.
 @discussion
 This initializer creates a new FxTime instance with the same time value as the source instance.
 */
- (instancetype)initWithTime:(FxTime*)time;

/*!
 @method initWithCMTime:
 @abstract Initializes a new FxTime instance with a CMTime value.
 @param time The CMTime value to wrap.
 @return An initialized FxTime instance.
 @discussion
 This is the designated initializer for creating FxTime instances from CMTime values.
 */
- (instancetype)initWithCMTime:(CMTime)time;

/*!
 @method initWithDictionary:
 @abstract Initializes a new FxTime instance from a dictionary representation.
 @param timeDictionary A dictionary containing CMTime components.
 @return An initialized FxTime instance.
 @discussion
 The dictionary should contain the same keys and values as those created by CMTimeCopyAsDictionary.
 */
- (instancetype)initWithDictionary:(NSDictionary*)timeDictionary;

/*!
 @method initWithTime:timescale:
 @abstract Initializes a new FxTime instance with a time value and timescale.
 @param value The time value in timescale units.
 @param timescale The number of time units per second.
 @return An initialized FxTime instance.
 @discussion
 This initializer creates a time value where the actual time in seconds is value/timescale.
 */
- (instancetype)initWithTime:(int64_t)value timescale:(int32_t)timescale;

/*!
 @method initWithTime:timescale:epoch:
 @abstract Initializes a new FxTime instance with a time value, timescale, and epoch.
 @param value The time value in timescale units.
 @param timescale The number of time units per second.
 @param epoch The epoch value for the time.
 @return An initialized FxTime instance.
 @discussion
 The epoch parameter is used for time values that need to reference a specific starting point other than zero.
 */
- (instancetype)initWithTime:(int64_t)value timescale:(int32_t)timescale epoch:(int64_t)epoch;

/*!
 @method initWithSeconds:preferredTimescale:
 @abstract Initializes a new FxTime instance with a time value in seconds.
 @param seconds The time value in seconds.
 @param preferredTimescale The preferred timescale for internal representation.
 @return An initialized FxTime instance.
 @discussion
 This initializer converts a floating-point seconds value to the most appropriate CMTime representation using the specified preferred timescale.
 */
- (instancetype)initWithSeconds:(Float64)seconds preferredTimescale:(int32_t)preferredTimescale;

#pragma mark - Time Component Properties

/*!
 @property value
 @abstract The time value component of the wrapped CMTime.
 @discussion
 This represents the numerator of the time fraction. The actual time in seconds is value/timescale. Read-only on FxTime; read-write on FxMutableTime.
 */
@property (nonatomic, readonly) CMTimeValue value;

/*!
 @property timescale
 @abstract The timescale component of the wrapped CMTime.
 @discussion
 This represents the denominator of the time fraction and indicates the number of time units per second. Read-only on FxTime; read-write on FxMutableTime.
 */
@property (nonatomic, readonly) CMTimeScale timescale;

/*!
 @property flags
 @abstract The flags component of the wrapped CMTime.
 @discussion
 These flags indicate special states of the time value such as invalid, indefinite, or infinity. Read-only on FxTime; read-write on FxMutableTime.
 */
@property (nonatomic, readonly) CMTimeFlags flags;

/*!
 @property epoch
 @abstract The epoch component of the wrapped CMTime.
 @discussion
 The epoch is used for time values that need to reference a specific starting point other than zero. Read-only on FxTime; read-write on FxMutableTime.
 */
@property (nonatomic, readonly) CMTimeEpoch epoch;

#pragma mark - Computed Properties

/*!
 @property seconds
 @abstract The time value converted to seconds as a floating-point number.
 @discussion
 This property accesses the time value in seconds without manual conversion.
 */
@property (assign, readonly) Float64 seconds;

/*!
 @property isValid
 @abstract Whether the time value is valid.
 @discussion
 Returns YES if the time represents a valid time value, NO if it represents an invalid or uninitialized state.
 */
@property (nonatomic, readonly) BOOL isValid;

/*!
 @property isInfinity
 @abstract Whether the time value represents positive infinity.
 @discussion
 Returns YES if the time represents positive infinity, indicating unlimited future time or maximum duration.
 */
@property (nonatomic, readonly) BOOL isInfinity;

/*!
 @property isNegativeInfinity
 @abstract Whether the time value represents negative infinity.
 @discussion
 Returns YES if the time represents negative infinity, indicating unlimited past time or minimum duration.
 */
@property (nonatomic, readonly) BOOL isNegativeInfinity;

/*!
 @property isIndefinite
 @abstract Whether the time value is indefinite.
 @discussion
 Returns YES if the time represents an indefinite duration, indicating unknown or unbounded time.
 */
@property (nonatomic, readonly) BOOL isIndefinite;

/*!
 @property isNumeric
 @abstract Whether the time value is numeric (finite and valid).
 @discussion
 Returns YES only if the time is valid, non-indefinite, and non-infinite. Such times can be used in arithmetic operations.
 */
@property (nonatomic, readonly) BOOL isNumeric;

/*!
 @property isRounded
 @abstract Whether the time value has been rounded during conversion.
 @discussion
 Returns YES if the time value has been rounded during a previous conversion operation, indicating potential precision loss.
 */
@property (nonatomic, readonly) BOOL isRounded;

#pragma mark - Utility Methods

/*!
 @method asDictionary
 @abstract Converts the time value to a dictionary representation.
 @return A dictionary containing the time components.
 @discussion
 This method creates a dictionary representation of the time value that can be used for serialization or storage.
 */
- (NSDictionary *)asDictionary;

/*!
 @method show
 @abstract Displays the time value in the debugger console.
 @discussion
 This method uses CMTimeShow to display a human-readable representation of the time value for debugging purposes.
 */
- (void)show;

#pragma mark - Utility Functions

/*!
 @method rationalize:
 @abstract Converts a floating-point number to a rational representation.
 @param number The floating-point number to rationalize.
 @return A SRational32 structure containing the rational representation.
 @discussion
 This method finds the best rational approximation of the given floating-point number using a default tolerance of 1.0e-6.
 */
+ (SRational32)rationalize:(Float64)number;

/*!
 @method rationalize:tolerance:
 @abstract Converts a floating-point number to a rational representation with specified tolerance.
 @param number The floating-point number to rationalize.
 @param tolerance The maximum acceptable error in the approximation.
 @return A SRational32 structure containing the rational representation.
 @discussion
 This method finds the best rational approximation of the given floating-point number within the specified tolerance using continued fractions.
 */
+ (SRational32)rationalize:(Float64)number tolerance:(double)tolerance;

#pragma mark - Comparison Operations

/*!
 @method compare:
 @abstract Compares this time value with another FxTime instance.
 @param time1 The FxTime instance to compare against.
 @return -1 if the receiver is less than time1, 0 if equal, 1 if the receiver is greater than time1.
 @discussion
 Follows the standard Cocoa NSComparisonResult convention: the result describes the
 receiver relative to time1 (i.e. -1 == NSOrderedAscending when self < time1). Both time
 values must be numeric for meaningful comparison.

 @since 1.1
 */
- (int32_t)compare:(FxTime*)time1;

/*!
 @method compareTime:
 @abstract Compares this time value with a CMTime value.
 @param time1 The CMTime value to compare against.
 @return -1 if the receiver is less than time1, 0 if equal, 1 if the receiver is greater than time1.
 @discussion
 Follows the standard Cocoa NSComparisonResult convention: the result describes the
 receiver relative to time1. Both time values must be numeric for meaningful comparison.
 (See -compare:.)

 @since 1.1
 */
- (int32_t)compareTime:(CMTime)time1;

#pragma mark - Absolute Value

/*!
 @property absoluteValue
 @abstract The absolute value of this time as a new FxTime instance.
 @discussion
 Returns a new FxTime instance containing the absolute value of this time. The original time value is not modified.
 */
@property (readonly) FxTime* absoluteValue;

/*!
 @property absoluteValueTime
 @abstract The absolute value of this time as a CMTime value.
 @discussion
 Returns a CMTime structure containing the absolute value of this time. The original time value is not modified.
 */
@property (assign, readonly) CMTime absoluteValueTime;

@end

#pragma mark -

/*!
 @class FxMutableTime
 @abstract The mutable subclass of FxTime.
 @discussion
 FxMutableTime adds read-write access to the time components and in-place arithmetic,
 timescale conversion, and min/max operations. Use it wherever you previously mutated an
 FxTime. Obtain one via -[FxTime mutableCopy], any inherited factory/initializer, or by
 constructing it directly.

 Because it is mutable, FxMutableTime is NOT thread-safe; do not mutate a shared instance
 from multiple threads without external synchronization. -copy returns an immutable FxTime
 snapshot; -mutableCopy returns an independent FxMutableTime.

 WARNING: like NSMutableString/NSMutableArray, an FxMutableTime's -hash changes when its
 value changes. Do NOT mutate an FxMutableTime after it has been added to an NSSet or used
 as an NSDictionary key — doing so corrupts the collection. Store an immutable -copy instead.

 @code
 FxTime *start = [FxTime time:CMTimeMake(300, 600)]; // 0.5 s
 FxMutableTime *t = [start mutableCopy];

 [t addTime:CMTimeMake(600, 600)]; // + 1.0 s  -> 1.5 s
 [t multiply:2];                   // x2       -> 3.0 s
 [t convertTimeScale:30 roundingMethod:kCMTimeRoundingMethod_RoundHalfAwayFromZero];
 NSLog(@"%.3f s", t.seconds);      // 3.000 s

 FxTime *snapshot = [t copy];      // immutable; safe as a dictionary key
 @endcode

 @since 1.1
 */
@interface FxMutableTime : FxTime

/*! @property time Read-write access to the wrapped CMTime structure. */
@property (readwrite) CMTime time;

/*! @property value Read-write numerator of the time fraction. */
@property (nonatomic, readwrite) CMTimeValue value;

/*! @property timescale Read-write denominator (time units per second). */
@property (nonatomic, readwrite) CMTimeScale timescale;

/*! @property flags Read-write CMTime flags. */
@property (nonatomic, readwrite) CMTimeFlags flags;

/*! @property epoch Read-write epoch component. */
@property (nonatomic, readwrite) CMTimeEpoch epoch;

#pragma mark - Time Conversion

/*!
 @method convertTimeScale:roundingMethod:
 @abstract Converts the receiver's time value to a new timescale, in place.
 @param newTimescale The target timescale for conversion.
 @param method The rounding method to use during conversion.
 */
- (void)convertTimeScale:(int32_t)newTimescale roundingMethod:(CMTimeRoundingMethod)method;

#pragma mark - Arithmetic Operations

/*!
 @method add:
 @abstract Adds another FxTime instance to the receiver, in place.
 @param time The FxTime instance to add. Both values must be numeric.
 */
- (void)add:(FxTime*)time;

/*!
 @method addTime:
 @abstract Adds a CMTime value to the receiver, in place.
 @param time The CMTime value to add. Both values must be numeric.
 */
- (void)addTime:(CMTime)time;

/*!
 @method subtract:
 @abstract Subtracts another FxTime instance from the receiver, in place.
 @param time The FxTime instance to subtract. Both values must be numeric.
 */
- (void)subtract:(FxTime*)time;

/*!
 @method subtractTime:
 @abstract Subtracts a CMTime value from the receiver, in place.
 @param time The CMTime value to subtract. Both values must be numeric.
 */
- (void)subtractTime:(CMTime)time;

/*!
 @method multiply:
 @abstract Multiplies the receiver by an integer multiplier, in place.
 @param multiplier The integer multiplier. The time value must be numeric.
 */
- (void)multiply:(int32_t)multiplier;

/*!
 @method multiplyByFloat64:
 @abstract Multiplies the receiver by a floating-point multiplier, in place.
 @param multiplier The floating-point multiplier. The time value must be numeric.
 */
- (void)multiplyByFloat64:(Float64)multiplier;

/*!
 @method multiplyByRatio:divisor:
 @abstract Multiplies the receiver by a rational number (multiplier/divisor), in place.
 @param multiplier The numerator of the rational multiplier.
 @param divisor The denominator of the rational multiplier.
 */
- (void)multiplyByRatio:(int32_t)multiplier divisor:(int32_t)divisor;

#pragma mark - Min/Max Operations

/*!
 @method minimum:
 @abstract Sets the receiver to the minimum of itself and another FxTime instance.
 @param time The FxTime instance to compare against.
 */
- (void)minimum:(FxTime*)time;

/*!
 @method minimumTime:
 @abstract Sets the receiver to the minimum of itself and a CMTime value.
 @param time The CMTime value to compare against.
 */
- (void)minimumTime:(CMTime)time;

/*!
 @method maximum:
 @abstract Sets the receiver to the maximum of itself and another FxTime instance.
 @param time The FxTime instance to compare against.
 */
- (void)maximum:(FxTime*)time;

/*!
 @method maximumTime:
 @abstract Sets the receiver to the maximum of itself and a CMTime value.
 @param time The CMTime value to compare against.
 */
- (void)maximumTime:(CMTime)time;

@end

NS_ASSUME_NONNULL_END

#endif
