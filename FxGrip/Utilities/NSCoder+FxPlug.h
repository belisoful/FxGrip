/*!
	@file       NSCoder+FxPlug.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     NSCoder+FxPlug
	@abstract   Encodes and decodes FxPlug value types, 3D scene state, and lights through an NSCoder.
	@discussion Introduced in FxGrip 0.1.0. FxPlug parameter state passes through an NSCoder, and
	            its geometry types are plain C structs and double matrices. This category encodes
	            and decodes FxPoint2D, FxSize, FxPoint3D, FxRect, and Matrix44/FxMatrix44 as keyed
	            bytes. It captures a whole Fx3DAPI scene, camera matrices, frustum, and focal
	            length, and every FxLightingAPI light, under a key prefix. The render time and
	            quality level travel with the coder so the current-time convenience methods write
	            only when the coder's time matches.
*/

#ifndef NSCoder_FxPlug_h
#define NSCoder_FxPlug_h

#import <Foundation/Foundation.h>
#import <BEFoundation/NSCoder+AtIndex.h>
#import <CoreMedia/CMTime.h>
#import <simd/simd.h>
#import <FxPlug/FxLightingAPI.h>

/*! The key the coder stores the quality level under. */
#define kFxPlugCoderQualityLevelKey @"_pluginStateQualityLevel"
/*! The key the coder stores the image-ref count under. */
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

/*! The per-attribute key suffixes the 3D encoders append to a scene key prefix. */
extern NSString * _Nonnull const FxGrip3DCoderFocalLengthKey;
extern NSString * _Nonnull const FxGrip3DCoderModelMatrixKey;
extern NSString * _Nonnull const FxGrip3DCoderViewMatrixKey;
extern NSString * _Nonnull const FxGrip3DCoderProjectionMatrixKey;
extern NSString * _Nonnull const FxGrip3DCoderFrustumLeftKey;
extern NSString * _Nonnull const FxGrip3DCoderFrustumRightKey;
extern NSString * _Nonnull const FxGrip3DCoderFrustumBottomKey;
extern NSString * _Nonnull const FxGrip3DCoderFrustumTopKey;
extern NSString * _Nonnull const FxGrip3DCoderFrustumNearKey;
extern NSString * _Nonnull const FxGrip3DCoderFrustumFarKey;

/*! The key prefix that stands for the coder's current render time. */
extern NSString * _Nonnull const FxGrip3DCoderCurrentTimeKey;


/*!
	@abstract	Encodes and decodes FxPlug value types, 3D scene state, and lights.
	@discussion	Introduced in FxGrip 0.1.0. The render time and quality level associate with the
				coder. The current-time convenience methods act only when the coder's render time
				matches the requested time.
*/
@interface NSCoder (FxPlug)

/*! The render time associated with the coder; kCMTimeInvalid when none is set. */
@property CMTime renderTime;
/*! The encoded quality level; kFxQuality_HIGH when absent. */
@property FxQuality qualityLevel;
/*! YES when a render time has been associated, marking the coder as a plugin-state encoder. */
@property (readonly) BOOL isFxPluginStateEncoder;

/*! Encodes an FxPoint2D as keyed bytes. */
- (void)encodeFxPoint2D:(FxPoint2D)value forKey:(NSString *_Null_unspecified)key;
/*! Encodes an FxSize as keyed bytes. */
- (void)encodeFxSize:(FxSize)value forKey:(NSString *_Null_unspecified)key;
/*! Encodes an FxPoint3D as keyed bytes. */
- (void)encodeFxPoint3D:(FxPoint3D)value forKey:(NSString *_Null_unspecified)key;
/*! Encodes an FxRect as keyed bytes. */
- (void)encodeFxRect:(FxRect)value forKey:(NSString *_Null_unspecified)key;
/*! Encodes a raw 4x4 double matrix as keyed bytes. */
- (void)encodeMatrix44Data:(nonnull Matrix44Data*)value forKey:(NSString *_Null_unspecified)key;
/*! Encodes an FxMatrix44's matrix data as keyed bytes. */
- (void)encodeFxMatrix44:(nonnull FxMatrix44*)value forKey:(NSString *_Null_unspecified)key;

/*! Encodes the Fx3DAPI scene at the coder's render time under the current-time key. */
- (void)encodeFx3DAPI:(nonnull id<Fx3DAPI_v5>)api;
/*!
	@method		encodeFx3DAPI:atTime:forKey:
	@abstract	Encodes the model, view, and projection matrices, focal length, and frustum.
	@discussion	Introduced in FxGrip 0.1.0. Each attribute stores under key plus its suffix. A
				current-time key with a mismatched time is skipped. A host retrieval error stops
				the encode. */
- (void)encodeFx3DAPI:(nonnull id<Fx3DAPI_v5>)api atTime:(CMTime)time forKey:(nonnull NSString *)key;

/*! Encodes the FxLightingAPI lights at the coder's render time under the current-time key. */
- (void)encodeFxLightingAPI:(nonnull id<FxLightingAPI_v3>)api;
/*!
	@method		encodeFxLightingAPI:atTime:forKey:
	@abstract	Encodes the light count and every FxLight under key.
	@discussion	Introduced in FxGrip 0.1.0. A current-time key with a mismatched time is skipped.
				A light the host cannot supply is logged and omitted. */
- (void)encodeFxLightingAPI:(nonnull id<FxLightingAPI_v3>)api atTime:(CMTime)time forKey:(nonnull NSString *)key;

/*! The FxPoint2D for a key; zero when absent or the wrong size. */
- (FxPoint2D)decodeFxPoint2D:(NSString *_Null_unspecified)key;
/*! The FxSize for a key; zero when absent or the wrong size. */
- (FxSize)decodeFxSize:(NSString *_Null_unspecified)key;
/*! The FxPoint3D for a key; zero when absent or the wrong size. */
- (FxPoint3D)decodeFxPoint3D:(NSString *_Null_unspecified)key;
/*! The FxRect for a key; zero when absent or the wrong size. */
- (FxRect)decodeFxRect:(NSString *_Null_unspecified)key;
/*! An FxMatrix44 built from the matrix data at a key. */
- (nullable FxMatrix44*)decodeFxMatrix44:(NSString *_Null_unspecified)key;
/*! An FxMatrix44 built as a color matrix from the matrix data at a key. */
- (nullable FxMatrix44*)decodeFxColorMatrix44:(NSString *_Null_unspecified)key;
/*! An inner pointer to the raw 4x4 double matrix at a key; nil when absent or the wrong size. */
- (nullable Matrix44Data*)decodeMatrix44Data:(NSString *_Null_unspecified)key NS_RETURNS_INNER_POINTER;

/*! The 3D attribute at the coder's current-time key. */
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

/*! The same 3D attributes decoded under an explicit scene key prefix. */
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

/*! The encoded light count at the current-time key. */
- (long)decodeFxLightCount;
/*! The encoded light count under a scene key prefix. */
- (long)decodeFxLightCount:(NSString *_Null_unspecified)key;
/*! An inner pointer to the FxLight at an index under the current-time key; nil when out of range. */
- (nullable struct FxLight *)decodeFxLight:(long)lightIndex;// NS_INTERNAL_POINTER;
/*! An inner pointer to the FxLight at an index under a scene key prefix; nil when out of range. */
- (nullable struct FxLight *)decodeFxLight:(long)lightIndex forKey:(NSString *_Null_unspecified)key;

/*! Copies the FxLight at an index under the current-time key into light; NO when out of range. */
- (BOOL)decodeFxLight:(nonnull struct FxLight *)light index:(long)lightIndex;
/*! Copies the FxLight at an index under a scene key prefix into light; NO when out of range. */
- (BOOL)decodeFxLight:(nonnull struct FxLight *)light forKey:(NSString *_Null_unspecified)key index:(long)lightIndex;

/*! Converts a 4x4 double matrix to a matrix_float4x4 through simd vector loads. */
+ (void)floatMatrix:(nonnull matrix_float4x4*)outputMatrix fromDoubleMatrix:(nonnull Matrix44Data*)inputMatrix;


@end



#endif	//	NSCoder_AtIndex_AtTime
