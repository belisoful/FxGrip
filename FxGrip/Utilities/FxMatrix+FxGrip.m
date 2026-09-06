/*!
	@file       FxMatrix+FxGrip.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxMatrix+FxGrip
	@abstract   Implements FxMatrix44 conversion to simd_float4x4.
	@discussion Introduced in FxGrip 0.1.0. Both methods transpose from FxPlug's row-major layout
	            to simd's column-major layout while narrowing double components to float.
*/

#import "FxMatrix+FxGrip.h"

/*!
	@abstract	Adds simd_float4x4 conversion to FxPlug's FxMatrix44.
	@discussion	Introduced in FxGrip 0.1.0. The transpose accounts for the row-major to
				column-major difference between FxPlug and simd.
*/
@implementation FxMatrix44 (FxGrip)

- (void)toFloat4x4Matrix:(simd_float4x4*)floatMatrix
{
	// Transpose while copying
	for (size_t row = 0; row < 4; row++)
	{
		for (size_t col = 0; col < 4; col++)
		{
			floatMatrix->columns [ row ][ col ] = _mat[ col ][ row ];
		}
	}
}

+ (void)doubleMatrix:(Matrix44Data*)doubleMatrix toFloat4x4Matrix:(simd_float4x4*)floatMatrix
{
	// Transpose while copying
	for (size_t row = 0; row < 4; row++)
	{
		for (size_t col = 0; col < 4; col++)
		{
			floatMatrix->columns [ row ][ col ] = (*doubleMatrix)[ col ][ row ];
		}
	}
}

@end
