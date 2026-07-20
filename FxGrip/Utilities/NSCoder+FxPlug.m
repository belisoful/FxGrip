//
//  NSCoder+FxPlug.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#import <objc/runtime.h>
#import <FxPlug/FxTypes.h>
#import <FxPlug/Fx3DAPI.h>
#import <FxPlug/FxLightingAPI.h>
#import <BEFoundation/NSSet+BExtension.h>
//#import "NSSet+BExtension.h"
#import "NSCoder+FxPlug.h"
#import <BEFoundation/NSCoder+AtIndex.h>
#import <FxPlug/FxMatrix.h>
#import <simd/conversion.h>
#import "NSArray+FxPlug.h"


NSString * const Fx3DCoderFocalLengthKey = @"_fx3d_FocalLength";
NSString * const Fx3DCoderModelMatrixKey = @"_fx3d_ModelMatrix";
NSString * const Fx3DCoderViewMatrixKey = @"_fx3d_ViewMatrix";
NSString * const Fx3DCoderProjectionMatrixKey = @"_fx3d_ProjectionMatrix";
NSString * const Fx3DCoderFrustumLeftKey = @"_fx3d_FrustumLeft";
NSString * const Fx3DCoderFrustumRightKey = @"_fx3d_FrustumRight";
NSString * const Fx3DCoderFrustumBottomKey = @"_fx3d_FrustumBottom";
NSString * const Fx3DCoderFrustumTopKey = @"_fx3d_FrustumTop";
NSString * const Fx3DCoderFrustumNearKey = @"_fx3d_FrustumNear";
NSString * const Fx3DCoderFrustumFarKey = @"_fx3d_FrustumFar";

NSString * const FxLightingCoderLightCountKey = @"_fxlighting_LightCount";
NSString * const FxLightingCoderLightingKey = @"_fxlighting";

NSString * const Fx3DCoderCurrentTimeKey = @"_";


@implementation NSCoder (FxPlug)

- (CMTime) renderTime
{
	NSData* time = (NSData*)objc_getAssociatedObject(self, @selector(renderTime));
	if (!time) {
		return kCMTimeInvalid;
	}
		
	return *(CMTime*)time.bytes;
}

- (void) setRenderTime:(CMTime)time
{
	objc_setAssociatedObject(self, @selector(renderTime), [NSData dataWithBytes:&time length:sizeof(CMTime)], OBJC_ASSOCIATION_RETAIN);
}



- (FxQuality) qualityLevel
{
	if (![self containsValueForKey:kFxPlugCoderQualityLevelKey])
		return kFxQuality_HIGH;
	return (FxQuality)[self decodeInt64ForKey:kFxPlugCoderQualityLevelKey];
}

- (void) setQualityLevel:(FxQuality)qualityLevel
{
	[self encodeInt64:(unsigned long)qualityLevel forKey:kFxPlugCoderQualityLevelKey];
}



- (BOOL)isFxPluginStateEncoder
{
	return objc_getAssociatedObject(self, @selector(renderTime)) != nil;
}




- (void)encodeFxPoint2D:(FxPoint2D)value forKey:(NSString *)key
{
	[self encodeBytes:(void*)&value length:sizeof(value) forKey:key];
}

- (void)encodeFxSize:(FxSize)value forKey:(NSString *)key
{
	[self encodeBytes:(void*)&value length:sizeof(value) forKey:key];
}

- (void)encodeFxPoint3D:(FxPoint3D)value forKey:(NSString *)key
{
	[self encodeBytes:(void*)&value length:sizeof(value) forKey:key];
}

- (void)encodeFxRect:(FxRect)value forKey:(NSString *)key
{
	[self encodeBytes:(void*)&value length:sizeof(value) forKey:key];
}
- (void)encodeMatrix44Data:(Matrix44Data*)value forKey:(NSString *)key
{
	[self encodeBytes:(void*)value length:sizeof(*value) forKey:key];
}

- (void)encodeFxMatrix44:(FxMatrix44*)value forKey:(NSString *)key
{
	[self encodeMatrix44Data:value.matrix forKey:key];
}


- (void)encodeFx3DAPI:(id<Fx3DAPI_v5>)api
{
	[self encodeFx3DAPI:api atTime:self.renderTime forKey:Fx3DCoderCurrentTimeKey];
}

- (void)encodeFx3DAPI:(id<Fx3DAPI_v5>)api atTime:(CMTime)time forKey:(nonnull NSString *)key
{
	if ([key isEqualToString:Fx3DCoderCurrentTimeKey] && CMTimeCompare(self.renderTime, time)) {
		// If encoding current time but not the current time, skip
		return;
	}
	NSError *error = nil;
	
	[self encodeFxMatrix44:[api layerMatrixAtTime:time error:&error] forKey:[key stringByAppendingString:Fx3DCoderModelMatrixKey]];
	if (error) {
		NSLog(@"Error: cannot retrieve the Fx3D API Layer/Model Matrix. %@", error);
		return;
	}
	
	[self encodeFxMatrix44:[api viewMatrixAtTime:time error:&error] forKey:[key stringByAppendingString:Fx3DCoderViewMatrixKey]];
	if (error) {
		NSLog(@"Error: cannot retrieve the Fx3D API View Matrix. %@", error);
		return;
	}
	
	[self encodeFxMatrix44:[api metalProjectionMatrixAtTime:time error:&error] forKey:[key stringByAppendingString:Fx3DCoderProjectionMatrixKey]];
	if (error) {
		NSLog(@"Error: cannot retrieve the Fx3D API Projection Matrix. %@", error);
		return;
	}
	
	
	
	[self encodeDouble:[api focalLengthAtTime:time error:&error] forKey:[key stringByAppendingString:Fx3DCoderFocalLengthKey]];
	if (error) {
		NSLog(@"Error: cannot retrieve the Fx3D API Focal Length. %@", error);
		return;
	}
	
	double left, right, bottom, top, near, far;
	
	if(![api frustumLeft:&left right:&right bottom:&bottom top:&top near:&near far:&far atTime:time error:&error] || error) {
		if (error) {
			NSLog(@"Error: cannot retrieve the Fx3D API Focal Length. %@", error);
		}
		return;
	}
	
	[self encodeDouble:left forKey:[key stringByAppendingString:Fx3DCoderFrustumLeftKey]];
	[self encodeDouble:right forKey:[key stringByAppendingString:Fx3DCoderFrustumRightKey]];
	[self encodeDouble:bottom forKey:[key stringByAppendingString:Fx3DCoderFrustumBottomKey]];
	[self encodeDouble:top forKey:[key stringByAppendingString:Fx3DCoderFrustumTopKey]];
	[self encodeDouble:near forKey:[key stringByAppendingString:Fx3DCoderFrustumNearKey]];
	[self encodeDouble:far forKey:[key stringByAppendingString:Fx3DCoderFrustumFarKey]];
}

- (void)encodeFxLightingAPI:(nonnull id<FxLightingAPI_v3>)api
{
	[self encodeFxLightingAPI:api atTime:self.renderTime forKey:Fx3DCoderCurrentTimeKey];
}

- (void)encodeFxLightingAPI:(nonnull id<FxLightingAPI_v3>)api atTime:(CMTime)time forKey:(nonnull NSString *)key
{
	if ([key isEqualToString:Fx3DCoderCurrentTimeKey] && CMTimeCompare(self.renderTime, time)) {
		return; // if current time and current renderTime is not the passed time
	}
	long totalLights = [api numberOfLightsAtTime:time];
	NSString *lightKey = [key stringByAppendingString:FxLightingCoderLightCountKey];
	[self encodeInteger:totalLights forKey:lightKey];
	
	NSError *error = nil;
	for(long index = 0; index < totalLights; index++) {
		FxLight light;
		if (![api lightInfo:&light forLight:index atTime:time error:&error]) {
			if (error) {
				NSLog(@"%s Error: could not get light %ld %@", __func__, index, error);
			}
			error = nil;
			continue;
		}
		
		lightKey = [key stringByAppendingFormat:@"%ld%@", index, FxLightingCoderLightingKey];
		[self encodeBytes:(void*)&light length:sizeof(light) forKey:lightKey];
	}
}




- (FxPoint2D)decodeFxPoint2D:(NSString *)key
{
	NSUInteger lengthp = 0;
	const void* p = [self decodeBytesForKey:key returnedLength:&lengthp];
	if (lengthp != sizeof(FxPoint2D) || !p) {
		return (FxPoint2D){0.0, 0.0};
	}
	return *(FxPoint2D *)p;
}

- (FxSize)decodeFxSize:(NSString *)key
{
	NSUInteger lengthp = 0;
	const void* p = [self decodeBytesForKey:key returnedLength:&lengthp];
	if (lengthp != sizeof(FxSize) || !p) {
		return (FxSize){0.0, 0.0};
	}
	return *(FxSize *)p;
}

- (FxPoint3D)decodeFxPoint3D:(NSString *)key
{
	NSUInteger lengthp = 0;
	const void* p = [self decodeBytesForKey:key returnedLength:&lengthp];
	if (lengthp != sizeof(FxPoint3D) || !p) {
		return (FxPoint3D){0.0, 0.0, 0.0};
	}
	return *(FxPoint3D *)p;
}

- (FxRect)decodeFxRect:(NSString *)key
{
	NSUInteger lengthp = 0;
	const void* p = [self decodeBytesForKey:key returnedLength:&lengthp];
	if (lengthp != sizeof(FxRect) || !p) {
		return (FxRect){0.0, 0.0, 0.0, 0.0};
	}
	return *(FxRect *)p;
}

- (Matrix44Data*)decodeMatrix44Data:(NSString *)key
{
	NSUInteger lengthp = 0;
	Matrix44Data *p = (Matrix44Data*)[self decodeBytesForKey:key returnedLength:&lengthp];
	if (lengthp != sizeof(Matrix44Data) || !p) {
		return nil;
	}
	return p;
}

- (FxMatrix44*)decodeFxMatrix44:(NSString *)key
{
	return [FxMatrix44.alloc initWithMatrix44Data:*[self decodeMatrix44Data:key]];
}

- (FxMatrix44*)decodeFxColorMatrix44:(NSString *)key
{
	return [FxMatrix44.alloc initWithColorMatrix44Data:*[self decodeMatrix44Data:key]];
}



- (double)decodeFx3DFocalLength {
	return [self decodeFx3DFocalLength:Fx3DCoderCurrentTimeKey];
}
- (nullable Matrix44Data*)decodeFx3DModelMatrixData {
	return [self decodeFx3DModelMatrixData:Fx3DCoderCurrentTimeKey];
}
- (nullable FxMatrix44*)decodeFx3DModelMatrix {
	return [self decodeFx3DModelMatrix:Fx3DCoderCurrentTimeKey];
}
- (nullable Matrix44Data*)decodeFx3DViewMatrixData {
	return [self decodeFx3DViewMatrixData:Fx3DCoderCurrentTimeKey];
}
- (nullable FxMatrix44*)decodeFx3DViewMatrix {
	return [self decodeFx3DViewMatrix:Fx3DCoderCurrentTimeKey];
}
- (nullable Matrix44Data*)decodeFx3DProjectionMatrixData {
	return [self decodeFx3DProjectionMatrixData:Fx3DCoderCurrentTimeKey];
}
- (nullable FxMatrix44*)decodeFx3DProjectionMatrix {
	return [self decodeFx3DProjectionMatrix:Fx3DCoderCurrentTimeKey];
}
- (double)decodeFx3DFrustumLeft {
	return [self decodeFx3DFrustumLeft:Fx3DCoderCurrentTimeKey];
}
- (double)decodeFx3DFrustumRight {
	return [self decodeFx3DFrustumRight:Fx3DCoderCurrentTimeKey];
}
- (double)decodeFx3DFrustumBottom {
	return [self decodeFx3DFrustumBottom:Fx3DCoderCurrentTimeKey];
}
- (double)decodeFx3DFrustumTop {
	return [self decodeFx3DFrustumTop:Fx3DCoderCurrentTimeKey];
}
- (double)decodeFx3DFrustumNear {
	return [self decodeFx3DFrustumNear:Fx3DCoderCurrentTimeKey];
}
- (double)decodeFx3DFrustumFar {
	return [self decodeFx3DFrustumFar:Fx3DCoderCurrentTimeKey];
}

- (double)decodeFx3DFocalLength:(NSString *_Null_unspecified)key {
	return [self decodeDoubleForKey:[key stringByAppendingString:Fx3DCoderFocalLengthKey]];
}

- (nullable Matrix44Data*)decodeFx3DModelMatrixData:(NSString *_Null_unspecified)key {
	return [self decodeMatrix44Data:[key stringByAppendingString:Fx3DCoderModelMatrixKey]];
}

- (nullable FxMatrix44*)decodeFx3DModelMatrix:(NSString *_Null_unspecified)key {
	return [self decodeFxMatrix44:[key stringByAppendingString:Fx3DCoderModelMatrixKey]];
}

- (nullable Matrix44Data*)decodeFx3DViewMatrixData:(NSString *_Null_unspecified)key {
	return [self decodeMatrix44Data:[key stringByAppendingString:Fx3DCoderViewMatrixKey]];
}

- (nullable FxMatrix44*)decodeFx3DViewMatrix:(NSString *_Null_unspecified)key {
	return [self decodeFxMatrix44:[key stringByAppendingString:Fx3DCoderViewMatrixKey]];
}

- (nullable Matrix44Data*)decodeFx3DProjectionMatrixData:(NSString *_Null_unspecified)key {
	return [self decodeMatrix44Data:[key stringByAppendingString:Fx3DCoderProjectionMatrixKey]];
}

- (nullable FxMatrix44*)decodeFx3DProjectionMatrix:(NSString *_Null_unspecified)key {
	return [self decodeFxMatrix44:[key stringByAppendingString:Fx3DCoderProjectionMatrixKey]];
}

- (double)decodeFx3DFrustumLeft:(NSString *_Null_unspecified)key {
	return [self decodeDoubleForKey:[key stringByAppendingString:Fx3DCoderFrustumLeftKey]];
}

- (double)decodeFx3DFrustumRight:(NSString *_Null_unspecified)key {
	return [self decodeDoubleForKey:[key stringByAppendingString:Fx3DCoderFrustumRightKey]];
}

- (double)decodeFx3DFrustumBottom:(NSString *_Null_unspecified)key {
	return [self decodeDoubleForKey:[key stringByAppendingString:Fx3DCoderFrustumBottomKey]];
}

- (double)decodeFx3DFrustumTop:(NSString *_Null_unspecified)key {
	return [self decodeDoubleForKey:[key stringByAppendingString:Fx3DCoderFrustumTopKey]];
}

- (double)decodeFx3DFrustumNear:(NSString *_Null_unspecified)key {
	return [self decodeDoubleForKey:[key stringByAppendingString:Fx3DCoderFrustumNearKey]];
}

- (double)decodeFx3DFrustumFar:(NSString *_Null_unspecified)key {
	return [self decodeDoubleForKey:[key stringByAppendingString:Fx3DCoderFrustumFarKey]];
}

- (long)decodeFxLightCount
{
	return [self decodeFxLightCount:Fx3DCoderCurrentTimeKey];
}

- (long)decodeFxLightCount:(NSString *_Null_unspecified)key {
	NSString *lightKey = [key stringByAppendingString:FxLightingCoderLightCountKey];
	return [self decodeDoubleForKey:lightKey];
}

- (struct FxLight *)decodeFxLight:(long)lightIndex
{
	return [self decodeFxLight:lightIndex forKey:Fx3DCoderCurrentTimeKey];
}

- (struct FxLight *)decodeFxLight:(long)lightIndex forKey:(NSString *_Null_unspecified)key
{
	long count = [self decodeFxLightCount:key];
	
	if (lightIndex < 0 || lightIndex >= count) {
		return nil;
	}
	
	NSUInteger lengthp = 0;
	FxLight *p = (FxLight*)[self decodeBytesForKey:key returnedLength:&lengthp];
	if (lengthp != sizeof(FxLight) || !p) {
		return nil;
	}
	return p;
}

- (BOOL)decodeFxLight:(struct FxLight *)light index:(long)lightIndex
{
	return [self decodeFxLight:light forKey:Fx3DCoderCurrentTimeKey index:lightIndex];
}

- (BOOL)decodeFxLight:(struct FxLight *)light forKey:(NSString *_Null_unspecified)key index:(long)lightIndex
{
	FxLight* _light = [self decodeFxLight:lightIndex forKey:key];
	if (!_light) {
		return NO;
	}
	memcpy(light, _light, sizeof(FxLight));
	return YES;
}


+ (void)floatMatrix:(nonnull matrix_float4x4*)outputMatrix fromDoubleMatrix:(nonnull Matrix44Data*)inputMatrix
{    // Cast the input matrix to a double pointer for sequential access
	double *doublePtr = (double *)inputMatrix;
	float *floatPtr = (float *)outputMatrix;
	
	// Convert first 8 doubles to floats using aligned load
	simd_double8 firstHalf = *(simd_packed_double8*)doublePtr;
	simd_float8 firstFloats = simd_float(firstHalf);
	
	// Convert second 8 doubles to floats using aligned load
	simd_double8 secondHalf = *(simd_packed_double8*)(doublePtr + 8);
	simd_float8 secondFloats = simd_float(secondHalf);
	
	// Store the results using aligned store
	*(simd_packed_float8*)floatPtr = firstFloats;
	*(simd_packed_float8*)(floatPtr + 8) = secondFloats;
}
@end

