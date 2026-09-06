/*!
	@file       FxGripColorGamut.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripColorGamut
	@abstract   Implements the working-gamut matrices, sRGB transfer, and matrix coder.
	@discussion Introduced in FxGrip 0.1.0. Each matrix derives from a gamut's primary
	            chromaticities against a D65 white, so the luminance row agrees with the
	            published weights. Rec.2020 supplies the wide gamut and Rec.709 supplies the
	            default. The coder packs the nine matrix components as floats under a key.
*/

#import "FxGripColorGamut.h"

typedef struct {
	float xr, yr, xg, yg, xb, yb, xw, yw;
} FxGripChromaticities;

/*! CIE xy primaries and D65 white for a gamut. Rec.2020 for the wide gamut, Rec.709 otherwise. */
static FxGripChromaticities FxGripChromaticitiesForPrimaries(FxColorPrimaries primaries)
{
	if (primaries == kFxColorPrimaries_Rec2020) {
		return (FxGripChromaticities){ 0.708f, 0.292f, 0.170f, 0.797f, 0.131f, 0.046f, 0.3127f, 0.3290f };
	}
	return (FxGripChromaticities){ 0.640f, 0.330f, 0.300f, 0.600f, 0.150f, 0.060f, 0.3127f, 0.3290f };
}

/*! The XYZ of a chromaticity at unit luminance. */
static simd_float3 FxGripXYZFromChromaticity(float x, float y)
{
	return simd_make_float3(x / y, 1.0f, (1.0f - x - y) / y);
}

simd_float3x3 FxGripColorMatrixMakeRowMajor(float m00, float m01, float m02,
											float m10, float m11, float m12,
											float m20, float m21, float m22)
{
	// simd is column-major: each argument column is a column of the matrix.
	return simd_matrix(simd_make_float3(m00, m10, m20),
					   simd_make_float3(m01, m11, m21),
					   simd_make_float3(m02, m12, m22));
}

simd_float3x3 FxGripRGBToXYZMatrix(FxColorPrimaries primaries)
{
	FxGripChromaticities c = FxGripChromaticitiesForPrimaries(primaries);
	simd_float3 r = FxGripXYZFromChromaticity(c.xr, c.yr);
	simd_float3 g = FxGripXYZFromChromaticity(c.xg, c.yg);
	simd_float3 b = FxGripXYZFromChromaticity(c.xb, c.yb);
	simd_float3x3 primariesMatrix = simd_matrix(r, g, b);

	simd_float3 white = FxGripXYZFromChromaticity(c.xw, c.yw);
	simd_float3 scale = simd_mul(simd_inverse(primariesMatrix), white);

	return simd_matrix(r * scale.x, g * scale.y, b * scale.z);
}

simd_float3x3 FxGripXYZToRGBMatrix(FxColorPrimaries primaries)
{
	return simd_inverse(FxGripRGBToXYZMatrix(primaries));
}

simd_float3x3 FxGripGamutConversionMatrix(FxColorPrimaries from, FxColorPrimaries to)
{
	if (from == to) {
		return matrix_identity_float3x3;
	}
	return simd_mul(FxGripXYZToRGBMatrix(to), FxGripRGBToXYZMatrix(from));
}

simd_float3 FxGripLuminanceWeights(FxColorPrimaries primaries)
{
	if (primaries == kFxColorPrimaries_Rec2020) {
		return simd_make_float3(0.2627f, 0.6780f, 0.0593f);
	}
	return simd_make_float3(0.2126f, 0.7152f, 0.0722f);
}

float FxGripSRGBToLinear(float encoded)
{
	return encoded <= 0.04045f ? encoded / 12.92f : powf((encoded + 0.055f) / 1.055f, 2.4f);
}

float FxGripLinearToSRGB(float linear)
{
	return linear <= 0.0031308f ? linear * 12.92f : 1.055f * powf(linear, 1.0f / 2.4f) - 0.055f;
}

void FxGripEncodeColorMatrix(simd_float3x3 matrix, NSCoder *coder, NSString *key)
{
	float packed[9] = {
		matrix.columns[0].x, matrix.columns[0].y, matrix.columns[0].z,
		matrix.columns[1].x, matrix.columns[1].y, matrix.columns[1].z,
		matrix.columns[2].x, matrix.columns[2].y, matrix.columns[2].z,
	};
	[coder encodeObject:[NSData dataWithBytes:packed length:sizeof(packed)] forKey:key];
}

simd_float3x3 FxGripDecodeColorMatrix(NSCoder *coder, NSString *key)
{
	NSData *data = [coder decodeObjectOfClass:NSData.class forKey:key];
	if (data.length != sizeof(float) * 9) {
		return matrix_identity_float3x3;
	}
	float packed[9];
	[data getBytes:packed length:sizeof(packed)];
	return simd_matrix(simd_make_float3(packed[0], packed[1], packed[2]),
					   simd_make_float3(packed[3], packed[4], packed[5]),
					   simd_make_float3(packed[6], packed[7], packed[8]));
}
