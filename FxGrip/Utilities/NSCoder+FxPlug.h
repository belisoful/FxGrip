//
//  NSCoder+FxPlug.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#ifndef NSCoder_FxPlug_h
#define NSCoder_FxPlug_h

#import <Foundation/Foundation.h>
#import <BEFoundation/NSCoder+AtIndex.h>
#import <CoreMedia/CMTime.h>
#import <simd/simd.h>
#import <FxPlug/FxLightingAPI.h>

#define kFxPlugCoderQualityLevelKey @"_pluginStateQualityLevel"
#define kFxPlugCoderImageRefCountKey @"_pluginStateImageRefCount"

#ifndef __FXTYPES_H__
enum {
	kFxQuality_LOW    = 0,
	kFxQuality_MEDIUM = 1,
	kFxQuality_HIGH   = 2
};
typedef NSUInteger FxQuality;
#endif

#ifndef __FXMATRIX_H__
typedef double  Matrix44Data[4][4];
@class FxMatrix44;
#endif
@class FxImageTile;
@protocol Fx3DLighting_v5;

extern NSString * _Nonnull const Fx3DCoderFocalLengthKey;
extern NSString * _Nonnull const Fx3DCoderModelMatrixKey;
extern NSString * _Nonnull const Fx3DCoderViewMatrixKey;
extern NSString * _Nonnull const Fx3DCoderProjectionMatrixKey;
extern NSString * _Nonnull const Fx3DCoderFrustumLeftKey;
extern NSString * _Nonnull const Fx3DCoderFrustumRightKey;
extern NSString * _Nonnull const Fx3DCoderFrustumBottomKey;
extern NSString * _Nonnull const Fx3DCoderFrustumTopKey;
extern NSString * _Nonnull const Fx3DCoderFrustumNearKey;
extern NSString * _Nonnull const Fx3DCoderFrustumFarKey;

extern NSString * _Nonnull const Fx3DCoderCurrentTimeKey;


@interface NSCoder (FxPlug)

@property CMTime renderTime;
@property FxQuality qualityLevel;
@property (readonly) BOOL isFxPluginStateEncoder;

- (void)encodeFxPoint2D:(FxPoint2D)value forKey:(NSString *_Null_unspecified)key;
- (void)encodeFxSize:(FxSize)value forKey:(NSString *_Null_unspecified)key;
- (void)encodeFxPoint3D:(FxPoint3D)value forKey:(NSString *_Null_unspecified)key;
- (void)encodeFxRect:(FxRect)value forKey:(NSString *_Null_unspecified)key;
- (void)encodeMatrix44Data:(nonnull Matrix44Data*)value forKey:(NSString *_Null_unspecified)key;
- (void)encodeFxMatrix44:(nonnull FxMatrix44*)value forKey:(NSString *_Null_unspecified)key;

- (void)encodeFx3DAPI:(nonnull id<Fx3DAPI_v5>)api;
- (void)encodeFx3DAPI:(nonnull id<Fx3DAPI_v5>)api atTime:(CMTime)time forKey:(nonnull NSString *)key;

- (void)encodeFxLightingAPI:(nonnull id<FxLightingAPI_v3>)api;
- (void)encodeFxLightingAPI:(nonnull id<FxLightingAPI_v3>)api atTime:(CMTime)time forKey:(nonnull NSString *)key;

- (FxPoint2D)decodeFxPoint2D:(NSString *_Null_unspecified)key;
- (FxSize)decodeFxSize:(NSString *_Null_unspecified)key;
- (FxPoint3D)decodeFxPoint3D:(NSString *_Null_unspecified)key;
- (FxRect)decodeFxRect:(NSString *_Null_unspecified)key;
- (nullable FxMatrix44*)decodeFxMatrix44:(NSString *_Null_unspecified)key;
- (nullable FxMatrix44*)decodeFxColorMatrix44:(NSString *_Null_unspecified)key;
- (nullable Matrix44Data*)decodeMatrix44Data:(NSString *_Null_unspecified)key NS_RETURNS_INNER_POINTER;

- (double)decodeFx3DFocalLength;
- (nullable Matrix44Data*)decodeFx3DModelMatrixData NS_RETURNS_INNER_POINTER;
- (nullable FxMatrix44*)decodeFx3DModelMatrix;
- (nullable Matrix44Data*)decodeFx3DViewMatrixData NS_RETURNS_INNER_POINTER;// NS_INTERNAL_POINTER;
- (nullable FxMatrix44*)decodeFx3DViewMatrix;
- (nullable Matrix44Data*)decodeFx3DProjectionMatrixData NS_RETURNS_INNER_POINTER;
- (nullable FxMatrix44*)decodeFx3DProjectionMatrix;
- (double)decodeFx3DFrustumLeft;
- (double)decodeFx3DFrustumRight;
- (double)decodeFx3DFrustumBottom;
- (double)decodeFx3DFrustumTop;
- (double)decodeFx3DFrustumNear;
- (double)decodeFx3DFrustumFar;
- (double)decodeFx3DFocalLength:(NSString *_Null_unspecified)key;
- (nullable Matrix44Data*)decodeFx3DModelMatrixData:(NSString *_Null_unspecified)key NS_RETURNS_INNER_POINTER;
- (nullable FxMatrix44*)decodeFx3DModelMatrix:(NSString *_Null_unspecified)key;
- (nullable Matrix44Data*)decodeFx3DViewMatrixData:(NSString *_Null_unspecified)key NS_RETURNS_INNER_POINTER;
- (nullable FxMatrix44*)decodeFx3DViewMatrix:(NSString *_Null_unspecified)key;
- (nullable Matrix44Data*)decodeFx3DProjectionMatrixData:(NSString *_Null_unspecified)key NS_RETURNS_INNER_POINTER;
- (nullable FxMatrix44*)decodeFx3DProjectionMatrix:(NSString *_Null_unspecified)key;
- (double)decodeFx3DFrustumLeft:(NSString *_Null_unspecified)key;
- (double)decodeFx3DFrustumRight:(NSString *_Null_unspecified)key;
- (double)decodeFx3DFrustumBottom:(NSString *_Null_unspecified)key;
- (double)decodeFx3DFrustumTop:(NSString *_Null_unspecified)key;
- (double)decodeFx3DFrustumNear:(NSString *_Null_unspecified)key;
- (double)decodeFx3DFrustumFar:(NSString *_Null_unspecified)key;

- (long)decodeFxLightCount;
- (long)decodeFxLightCount:(NSString *_Null_unspecified)key;
- (nullable struct FxLight *)decodeFxLight:(long)lightIndex;// NS_INTERNAL_POINTER;
- (nullable struct FxLight *)decodeFxLight:(long)lightIndex forKey:(NSString *_Null_unspecified)key;

- (BOOL)decodeFxLight:(nonnull struct FxLight *)light index:(long)lightIndex;
- (BOOL)decodeFxLight:(nonnull struct FxLight *)light forKey:(NSString *_Null_unspecified)key index:(long)lightIndex;

+ (void)floatMatrix:(nonnull matrix_float4x4*)outputMatrix fromDoubleMatrix:(nonnull Matrix44Data*)inputMatrix;


@end



#endif	//	NSCoder_AtIndex_AtTime
