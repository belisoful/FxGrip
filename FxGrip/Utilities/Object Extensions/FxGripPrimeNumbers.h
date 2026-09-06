/*!
	@file       FxGripPrimeNumbers.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPrimeNumbers
	@abstract   The table of 16-bit primes and its element count.
	@discussion Introduced in FxGrip 0.1.0. The header declares the count of the shared gPrimeNumbers16Bit
	            table defined in the implementation. The table lists 1 followed by every prime up to 65521.
*/

#ifndef FxGripPrimeNumbers_h
#define FxGripPrimeNumbers_h


// https://numbergenerator.org/numberlist/prime-numbers/1-100000#!low=1&high=65536&csv=csv

/*! The element count of the gPrimeNumbers16Bit table: 1 plus the 6542 primes in [2, 65521]. */
//6542 primes [2 .. 65521] plus [1]
#define kNumberOf16BitPrimes 6543



#endif
