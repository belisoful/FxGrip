//
//  NSCoder+AtIndex.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#import "FxMatrix+FxGrip.h"

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
