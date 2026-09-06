/*!
	@file       FxMatrix+FxGrip.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxMatrix+FxGrip
	@abstract   Converts FxPlug's double-precision FxMatrix44 to a simd_float4x4.
	@discussion Introduced in FxGrip 0.1.0. FxPlug hands transforms as an FxMatrix44 in row-major
	            double precision. Metal and simd work in column-major single precision. This
	            category transposes and narrows the matrix so an effect can pass a host transform
	            straight to a shader.
*/

#ifndef FxMatrix44_FxGrip_h
#define FxMatrix44_FxGrip_h

#import <FxPlug/FxPlugSDK.h>
#include <simd/simd.h>

/*!
	@abstract	Adds simd_float4x4 conversion to FxPlug's FxMatrix44.
	@discussion	Introduced in FxGrip 0.1.0. The conversion transposes from row-major to
				column-major and narrows double components to float.
*/
@interface FxMatrix44 (FxGrip)

/*!
	@method		toFloat4x4Matrix:
	@abstract	Writes the receiver's transform into a simd_float4x4.
	@param		floatMatrix	The destination matrix, filled column-major in single precision.
*/
- (void)toFloat4x4Matrix:(simd_float4x4*)floatMatrix;

/*!
	@method		doubleMatrix:toFloat4x4Matrix:
	@abstract	Converts a raw Matrix44Data to a simd_float4x4.
	@param		doubleMatrix	The source row-major double matrix.
	@param		floatMatrix		The destination matrix, filled column-major in single precision.
*/
+ (void)doubleMatrix:(Matrix44Data*)doubleMatrix toFloat4x4Matrix:(simd_float4x4*)floatMatrix;

@end



#endif	//	NSCoder_AtIndex_AtTime
