/*!
 @header		NSNumber+Primes16b.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		A category extension for NSNumber that provides prime number operations within the 16-bit range.
 @discussion	This category extends NSNumber with methods for finding, rounding, and working with prime numbers
 up to 65521 (the largest prime that fits in a 16-bit unsigned integer). It uses a precomputed lookup table
 of all 6542 primes in the 16-bit range for efficient operations.
 
 The implementation provides three main types of operations:
 - Index-based methods that return array indices into the prime lookup table
 - Value-based methods that return prime numbers directly
 - Instance methods that operate on NSNumber objects
 
 All methods handle edge cases and return appropriate values (NSNotFound, 0, or nil) for invalid inputs.
 */

#ifndef NSNumber_Primes16b_h
#define NSNumber_Primes16b_h

#import <Foundation/Foundation.h>

// https://numbergenerator.org/numberlist/prime-numbers/1-100000#!low=1&high=65536&csv=csv

/*!
 @constant NSPrimeNumbers16BitCount
 @abstract The total number of prime numbers in the 16-bit range.
 @discussion This constant represents the count of all prime numbers from 2 to 65521.
 The actual array contains 6542 primes plus guard values at indices 0 and 6543.
 */
#define NSPrimeNumbers16BitCount (6542)

/*!
 @constant UInt16SmallestPrime
 @abstract The smallest prime number in the 16-bit range.
 @discussion This is always 2, the first prime number.
 */
#define UInt16SmallestPrime (2)

/*!
 @constant UInt16LargestPrime
 @abstract The largest prime number that fits in a 16-bit unsigned integer.
 @discussion This is 65521, the largest prime ≤ 65535 (2^16 - 1).
 */
#define UInt16LargestPrime (65521)

/*!
 @constant UInt17NextLargestPrime
 @abstract The first prime number larger than UInt16LargestPrime.
 @discussion This is 65537, used for boundary checking in algorithms.
 Note: 65529 (the midpoint between 65521 and 65537) is not prime.
 */
#define UInt17NextLargestPrime (65537)

/*!
 @var NSPrimeNumbers16Bit
 @abstract A lookup table containing all prime numbers in the 16-bit range.
 @discussion This array contains 6544 elements total:
 - Index 0: Contains 1 (not prime, but included for algorithmic convenience)
 - Indices 1-6542: Contains all primes from 2 to 65521
 - Index 6543: Contains 0 (sentinel value)
 
 The array is sorted in ascending order for efficient binary search operations.
 */
extern uint16_t const NSPrimeNumbers16Bit[1 + NSPrimeNumbers16BitCount + 1];

/*!
 @category NSNumber(BEPrimeNumbers16)
 @abstract A category that extends NSNumber with 16-bit prime number operations.
 @discussion This category provides efficient prime number operations using a precomputed lookup table.
 All methods are designed to work with values up to 65521 (the largest 16-bit prime).

 @code
 NSUInteger ceil  = [NSNumber ceilPrimeValue16:100];   // 101
 NSUInteger floor = [NSNumber floorPrimeValue16:100];  // 97
 NSNumber  *round = [NSNumber roundPrime16:100];       // @101 (nil if out of range)

 NSNumber *near = [@90 roundPrime16];                  // @89
 @endcode
 */
@interface NSNumber (BEPrimeNumbers16)

#pragma mark - Index Prime Methods

/*!
 @method ceilPrimeIndex16:
 @abstract Returns the index of the smallest prime greater than or equal to the given value.
 @param value The input value to find the ceiling prime index for.
 @return The index in NSPrimeNumbers16Bit of the ceiling prime, or NSNotFound if no valid prime exists.
 @discussion This method performs a binary search to find the smallest prime ≥ value.
 Returns NSNotFound if value is less than 1 or greater than UInt16LargestPrime.
 */
+ (NSInteger)ceilPrimeIndex16:(NSUInteger)value;

/*!
 @method floorPrimeIndex16:
 @abstract Returns the index of the largest prime less than or equal to the given value.
 @param value The input value to find the floor prime index for.
 @return The index in NSPrimeNumbers16Bit of the floor prime, or NSNotFound if no valid prime exists.
 @discussion This method performs a binary search to find the largest prime ≤ value.
 Returns NSNotFound if value is less than 1 or greater than or equal to UInt17NextLargestPrime.
 */
+ (NSInteger)floorPrimeIndex16:(NSUInteger)value;

/*!
 @method roundPrimeIndex16:
 @abstract Returns the index of the prime closest to the given value.
 @param value The input value to find the nearest prime index for.
 @return The index in NSPrimeNumbers16Bit of the nearest prime, or NSNotFound if no valid prime exists.
 @discussion This method uses standard rounding behavior (round up if exactly halfway).
 Returns NSNotFound if value is less than 1 or at-or-greater-than the midpoint between
 UInt16LargestPrime and UInt17NextLargestPrime (65529). The exact midpoint is excluded because
 rounding it up would escape the 16-bit prime range.
 */
+ (NSInteger)roundPrimeIndex16:(NSUInteger)value;

#pragma mark - Round Prime Methods

/*!
 @method roundPrimeValue16:
 @abstract Returns the prime number closest to the given value.
 @param value The input value to find the nearest prime for.
 @return The nearest prime number, or 0 if no valid prime exists.
 @discussion This method finds the prime with the minimum distance from the input value.
 Uses standard rounding behavior (round up if exactly halfway between two primes).
 */
+ (NSUInteger)roundPrimeValue16:(NSUInteger)value;

/*!
 @method roundPrime16:
 @abstract Returns an NSNumber containing the prime closest to the given value.
 @param value The input value to find the nearest prime for.
 @return An NSNumber containing the nearest prime, or nil if no valid prime exists.
 @discussion This is the NSNumber wrapper for roundPrimeValue16:. Returns nil for invalid inputs.
 */
+ (NSNumber * _Nullable)roundPrime16:(NSUInteger)value;

#pragma mark - Floor Prime Methods

/*!
 @method floorPrimeValue16:offset:
 @abstract Returns the largest prime ≤ value, optionally offset by a number of positions.
 @param value The input value to find the floor prime for.
 @param offset The number of positions to offset in the prime table (can be negative).
 @return The floor prime (possibly offset), or 0 if no valid prime exists.
 @discussion This method first finds the floor prime, then moves by offset positions in the lookup table.
 Positive offset moves toward larger primes, negative offset moves toward smaller primes.
 Returns 0 if the offset results in an invalid array index.
 */
+ (NSUInteger)floorPrimeValue16:(NSUInteger)value offset:(int)offset;

/*!
 @method floorPrimeValue16:
 @abstract Returns the largest prime less than or equal to the given value.
 @param value The input value to find the floor prime for.
 @return The largest prime ≤ value, or 0 if no valid prime exists.
 @discussion This is equivalent to calling floorPrimeValue16:offset: with offset 0.
 */
+ (NSUInteger)floorPrimeValue16:(NSUInteger)value;

/*!
 @method floorPrime16:
 @abstract Returns an NSNumber containing the largest prime ≤ value.
 @param value The input value to find the floor prime for.
 @return An NSNumber containing the floor prime, or nil if no valid prime exists.
 @discussion This is the NSNumber wrapper for floorPrimeValue16:. Returns nil for invalid inputs.
 */
+ (NSNumber * _Nullable)floorPrime16:(NSUInteger)value;

#pragma mark - Ceil Prime Methods

/*!
 @method ceilPrimeValue16:offset:
 @abstract Returns the smallest prime ≥ value, optionally offset by a number of positions.
 @param value The input value to find the ceiling prime for.
 @param offset The number of positions to offset in the prime table (can be negative).
 @return The ceiling prime (possibly offset), or 0 if no valid prime exists.
 @discussion This method first finds the ceiling prime, then moves by offset positions in the lookup table.
 Positive offset moves toward larger primes, negative offset moves toward smaller primes.
 Returns 0 if the offset results in an invalid array index.
 */
+ (NSUInteger)ceilPrimeValue16:(NSUInteger)value offset:(int)offset;

/*!
 @method ceilPrimeValue16:
 @abstract Returns the smallest prime greater than or equal to the given value.
 @param value The input value to find the ceiling prime for.
 @return The smallest prime ≥ value, or 0 if no valid prime exists.
 @discussion This is equivalent to calling ceilPrimeValue16:offset: with offset 0.
 */
+ (NSUInteger)ceilPrimeValue16:(NSUInteger)value;

/*!
 @method ceilPrime16:
 @abstract Returns an NSNumber containing the smallest prime ≥ value.
 @param value The input value to find the ceiling prime for.
 @return An NSNumber containing the ceiling prime, or nil if no valid prime exists.
 @discussion This is the NSNumber wrapper for ceilPrimeValue16:. Returns nil for invalid inputs.
 */
+ (NSNumber * _Nullable)ceilPrime16:(NSUInteger)value;

#pragma mark - Instance Methods

/*!
 @method roundPrime16
 @abstract Returns an NSNumber containing the prime closest to this number's value.
 @return An NSNumber containing the nearest prime, or nil if this number's value is invalid.
 @discussion This instance method operates on the receiver's unsignedIntegerValue.
 Equivalent to calling [NSNumber roundPrime16:self.unsignedIntegerValue].
 */
- (NSNumber * _Nullable)roundPrime16;

/*!
 @method floorPrime16
 @abstract Returns an NSNumber containing the largest prime ≤ this number's value.
 @return An NSNumber containing the floor prime, or nil if this number's value is invalid.
 @discussion This instance method operates on the receiver's unsignedIntegerValue.
 Equivalent to calling [NSNumber floorPrime16:self.unsignedIntegerValue].
 */
- (NSNumber * _Nullable)floorPrime16;

/*!
 @method ceilPrime16
 @abstract Returns an NSNumber containing the smallest prime ≥ this number's value.
 @return An NSNumber containing the ceiling prime, or nil if this number's value is invalid.
 @discussion This instance method operates on the receiver's unsignedIntegerValue.
 Equivalent to calling [NSNumber ceilPrime16:self.unsignedIntegerValue].
 */
- (NSNumber * _Nullable)ceilPrime16;

@end

#endif
