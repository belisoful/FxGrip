/*!
	@file       FxGripColorGamut.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-08-10
	@header     FxGripColorGamut
	@abstract   Color matrices for the working gamuts FxPlug reports, plus the sRGB transfer and
	            a matrix coder.
	@discussion Introduced in FxGrip 0.1.0. FxPlug tells an effect its project's working gamut
	            (kFxColorPrimaries_Rec709 or kFxColorPrimaries_Rec2020) but ships no math for it,
	            so an effect that needs a luminance, a gamut conversion, or an XYZ transform
	            derives the matrix itself. These functions supply the standard matrices, computed
	            from each gamut's primary chromaticities against a D65 white, so the luminance
	            row agrees with the published weights.

	            Matrices are simd_float3x3 in simd's column-major layout: `simd_mul(matrix, rgb)`
	            transforms a column vector. FxGripColorMatrixMakeRowMajor builds one from the
	            row-major form a reference matrix is usually written in.
*/

#ifndef FxGripColorGamut_h
#define FxGripColorGamut_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import <FxPlug/FxPlugSDK.h>

NS_ASSUME_NONNULL_BEGIN

/*! The Rec.709 or Rec.2020 luminance weights (the CIE Y row) for the primaries. */
simd_float3 FxGripLuminanceWeights(FxColorPrimaries primaries);

/*! The RGB-to-CIE-XYZ matrix for the primaries, D65 white. */
simd_float3x3 FxGripRGBToXYZMatrix(FxColorPrimaries primaries);

/*! The CIE-XYZ-to-RGB matrix for the primaries, D65 white. */
simd_float3x3 FxGripXYZToRGBMatrix(FxColorPrimaries primaries);

/*! The matrix converting linear RGB in the `from` gamut to linear RGB in the `to` gamut. Equal
	primaries give the identity. */
simd_float3x3 FxGripGamutConversionMatrix(FxColorPrimaries from, FxColorPrimaries to);

/*! A matrix from nine row-major components, returned in simd's column-major layout. */
simd_float3x3 FxGripColorMatrixMakeRowMajor(float m00, float m01, float m02,
											float m10, float m11, float m12,
											float m20, float m21, float m22);

/*! The sRGB electro-optical transfer: a gamma-encoded component to linear. */
float FxGripSRGBToLinear(float encoded);

/*! The sRGB opto-electronic transfer: a linear component to gamma-encoded. */
float FxGripLinearToSRGB(float linear);

/*! Encodes a matrix as nine packed floats under key. */
void FxGripEncodeColorMatrix(simd_float3x3 matrix, NSCoder *coder, NSString *key);

/*! Decodes a matrix written by FxGripEncodeColorMatrix; the identity when the key is absent. */
simd_float3x3 FxGripDecodeColorMatrix(NSCoder *coder, NSString *key);

NS_ASSUME_NONNULL_END

#endif /* FxGripColorGamut_h */
