//
//  FxGripColorGamutTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripColorGamut.h>

@interface FxGripColorGamutTests : XCTestCase
@end

@implementation FxGripColorGamutTests

static void AssertMatrixClose(XCTestCase *self, simd_float3x3 a, simd_float3x3 b, float tol)
{
	for (int c = 0; c < 3; c++) {
		XCTAssertEqualWithAccuracy(a.columns[c].x, b.columns[c].x, tol);
		XCTAssertEqualWithAccuracy(a.columns[c].y, b.columns[c].y, tol);
		XCTAssertEqualWithAccuracy(a.columns[c].z, b.columns[c].z, tol);
	}
}

- (void)testLuminanceWeights
{
	simd_float3 rec709 = FxGripLuminanceWeights(kFxColorPrimaries_Rec709);
	XCTAssertEqualWithAccuracy(rec709.x, 0.2126f, 1e-5);
	XCTAssertEqualWithAccuracy(rec709.y, 0.7152f, 1e-5);
	XCTAssertEqualWithAccuracy(rec709.z, 0.0722f, 1e-5);

	simd_float3 rec2020 = FxGripLuminanceWeights(kFxColorPrimaries_Rec2020);
	XCTAssertEqualWithAccuracy(rec2020.x, 0.2627f, 1e-5);
	XCTAssertEqualWithAccuracy(rec2020.y, 0.6780f, 1e-5);
	XCTAssertEqualWithAccuracy(rec2020.z, 0.0593f, 1e-5);
}

- (void)testTheRGBToXYZLuminanceRowMatchesTheLuminanceWeights
{
	// The Y row of the RGB→XYZ matrix IS the luminance weights; agreement cross-validates
	// the chromaticity-derived matrix against the published constants.
	simd_float3x3 matrix = FxGripRGBToXYZMatrix(kFxColorPrimaries_Rec709);
	simd_float3 weights = FxGripLuminanceWeights(kFxColorPrimaries_Rec709);
	XCTAssertEqualWithAccuracy(matrix.columns[0].y, weights.x, 1e-3);
	XCTAssertEqualWithAccuracy(matrix.columns[1].y, weights.y, 1e-3);
	XCTAssertEqualWithAccuracy(matrix.columns[2].y, weights.z, 1e-3);
}

- (void)testRec709RGBToXYZMatchesPublishedSRGBMatrix
{
	// The standard sRGB/Rec.709 D65 RGB→XYZ matrix, row-major.
	simd_float3x3 expected = FxGripColorMatrixMakeRowMajor(0.4124f, 0.3576f, 0.1805f,
														  0.2126f, 0.7152f, 0.0722f,
														  0.0193f, 0.1192f, 0.9505f);
	AssertMatrixClose(self, FxGripRGBToXYZMatrix(kFxColorPrimaries_Rec709), expected, 1e-3);
}

- (void)testXYZToRGBInvertsRGBToXYZ
{
	simd_float3x3 forward = FxGripRGBToXYZMatrix(kFxColorPrimaries_Rec2020);
	simd_float3x3 back = FxGripXYZToRGBMatrix(kFxColorPrimaries_Rec2020);
	AssertMatrixClose(self, simd_mul(back, forward), matrix_identity_float3x3, 1e-4);
}

- (void)testGamutConversionToSelfIsIdentity
{
	AssertMatrixClose(self,
					  FxGripGamutConversionMatrix(kFxColorPrimaries_Rec709, kFxColorPrimaries_Rec709),
					  matrix_identity_float3x3, 1e-6);
}

- (void)testGamutConversionRoundTripsToIdentity
{
	simd_float3x3 toWide = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec709, kFxColorPrimaries_Rec2020);
	simd_float3x3 back = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec2020, kFxColorPrimaries_Rec709);
	AssertMatrixClose(self, simd_mul(back, toWide), matrix_identity_float3x3, 1e-4);
}

- (void)testWhitePreservesAcrossGamutsBecauseTheyShareD65
{
	// RGB(1,1,1) is D65 white in both gamuts, so the conversion fixes it.
	simd_float3x3 toWide = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec709, kFxColorPrimaries_Rec2020);
	simd_float3 white = simd_mul(toWide, simd_make_float3(1.0f, 1.0f, 1.0f));
	XCTAssertEqualWithAccuracy(white.x, 1.0f, 1e-3);
	XCTAssertEqualWithAccuracy(white.y, 1.0f, 1e-3);
	XCTAssertEqualWithAccuracy(white.z, 1.0f, 1e-3);
}

- (void)testRowMajorBuilderPlacesComponents
{
	simd_float3x3 matrix = FxGripColorMatrixMakeRowMajor(1, 2, 3, 4, 5, 6, 7, 8, 9);
	// Column 0 is the first math column (m00, m10, m20).
	XCTAssertEqual(matrix.columns[0].x, 1.0f);
	XCTAssertEqual(matrix.columns[0].y, 4.0f);
	XCTAssertEqual(matrix.columns[0].z, 7.0f);
	// Multiplying by e0 selects that column.
	simd_float3 col = simd_mul(matrix, simd_make_float3(1, 0, 0));
	XCTAssertEqual(col.y, 4.0f);
}

- (void)testSRGBTransferEndpointsAndRoundTrip
{
	XCTAssertEqualWithAccuracy(FxGripSRGBToLinear(0.0f), 0.0f, 1e-6);
	XCTAssertEqualWithAccuracy(FxGripSRGBToLinear(1.0f), 1.0f, 1e-6);
	XCTAssertEqualWithAccuracy(FxGripLinearToSRGB(0.0f), 0.0f, 1e-6);
	XCTAssertEqualWithAccuracy(FxGripLinearToSRGB(1.0f), 1.0f, 1e-6);

	for (float v = 0.0f; v <= 1.0f; v += 0.1f) {
		XCTAssertEqualWithAccuracy(FxGripLinearToSRGB(FxGripSRGBToLinear(v)), v, 1e-4);
	}
	// 0.5 encoded decodes to the well-known ~0.214 linear.
	XCTAssertEqualWithAccuracy(FxGripSRGBToLinear(0.5f), 0.21404f, 1e-4);
}

- (void)testMatrixCoderRoundTrips
{
	simd_float3x3 matrix = FxGripRGBToXYZMatrix(kFxColorPrimaries_Rec2020);

	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	FxGripEncodeColorMatrix(matrix, archiver, @"matrix");
	[archiver finishEncoding];

	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
	unarchiver.requiresSecureCoding = YES;
	AssertMatrixClose(self, FxGripDecodeColorMatrix(unarchiver, @"matrix"), matrix, 1e-6);
}

- (void)testMatrixCoderReturnsIdentityForAMissingKey
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	FxGripEncodeColorMatrix(matrix_identity_float3x3, archiver, @"present");
	[archiver finishEncoding];

	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
	unarchiver.requiresSecureCoding = YES;
	AssertMatrixClose(self, FxGripDecodeColorMatrix(unarchiver, @"absent"), matrix_identity_float3x3, 1e-6);
}

@end
