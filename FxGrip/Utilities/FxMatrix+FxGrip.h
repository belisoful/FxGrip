//
//  FxMatrix44+FxGrip.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#ifndef FxMatrix44_FxGrip_h
#define FxMatrix44_FxGrip_h

#import <FxPlug/FxPlugSDK.h>
#include <simd/simd.h>

@interface FxMatrix44 (FxGrip)

- (void)toFloat4x4Matrix:(simd_float4x4*)floatMatrix;
+ (void)doubleMatrix:(Matrix44Data*)doubleMatrix toFloat4x4Matrix:(simd_float4x4*)floatMatrix;

@end



#endif	//	NSCoder_AtIndex_AtTime
