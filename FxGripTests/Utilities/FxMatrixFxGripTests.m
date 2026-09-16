/*!
	@file       FxMatrixFxGripTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxMatrixFxGripTests
	@abstract   Verifies the FxMatrix44 (FxGrip) conversion to simd_float4x4.
	@discussion Introduced in FxGrip 0.1.0. The FxPlugStub framework supplies a real FxMatrix44, so the category attaches in the test process. The tests pin the element mapping from FxPlug's row-major storage to simd's column-major storage for the instance conversion and the raw-data conversion, and confirm the two agree.
*/

#import <XCTest/XCTest.h>
#import <simd/simd.h>
#import "FxPlugStub.h"
#import <FxGrip/FxMatrix+FxGrip.h>

@interface FxMatrixFxGripTests : XCTestCase
@end

@implementation FxMatrixFxGripTests

/*! A non-uniform scale with a translation, so every distinct element position is observable. */
- (FxMatrix44 *)sampleMatrix
{
	return [FxMatrix44 stubMatrixWithScaleX:2.0 scaleY:3.0 translationX:10.0 translationY:20.0];
}

/*! @abstract The instance conversion keeps each element at its row and column, so FxPlug's row-3 translation reads back as simd row 3. */
- (void)testToFloat4x4MatrixKeepsElementsAtTheirRowAndColumn
{
	simd_float4x4 result;
	memset(&result, 0, sizeof(result));

	[[self sampleMatrix] toFloat4x4Matrix:&result];

	// simd stores columns: columns[c][r] is the element at row r, column c.
	XCTAssertEqual(result.columns[0][0], 2.0f);
	XCTAssertEqual(result.columns[1][1], 3.0f);
	XCTAssertEqual(result.columns[2][2], 1.0f);
	XCTAssertEqual(result.columns[3][3], 1.0f);
	XCTAssertEqual(result.columns[0][3], 10.0f, @"row 3, column 0 carries the x translation");
	XCTAssertEqual(result.columns[1][3], 20.0f, @"row 3, column 1 carries the y translation");
	XCTAssertEqual(result.columns[3][0], 0.0f, @"row 0, column 3 stays zero");
	XCTAssertEqual(result.columns[3][1], 0.0f);
}

/*! @abstract The raw-data conversion narrows the double matrix into the same layout as the instance conversion. */
- (void)testDoubleMatrixConversionMatchesTheInstanceConversion
{
	FxMatrix44 *matrix = [self sampleMatrix];
	simd_float4x4 fromInstance;
	simd_float4x4 fromData;
	memset(&fromInstance, 0, sizeof(fromInstance));
	memset(&fromData, 0, sizeof(fromData));

	[matrix toFloat4x4Matrix:&fromInstance];
	[FxMatrix44 doubleMatrix:[matrix matrix] toFloat4x4Matrix:&fromData];

	for (size_t column = 0; column < 4; column++) {
		for (size_t row = 0; row < 4; row++) {
			XCTAssertEqual(fromData.columns[column][row], fromInstance.columns[column][row],
						   @"column %zu row %zu differs", column, row);
		}
	}
	XCTAssertEqual(fromData.columns[0][3], 10.0f);
}

/*! @abstract A double component narrows to the nearest float. */
- (void)testConversionNarrowsDoublesToFloat
{
	Matrix44Data data = {
		{ 0.1, 0.0, 0.0, 0.0 },
		{ 0.0, 1.0, 0.0, 0.0 },
		{ 0.0, 0.0, 1.0, 0.0 },
		{ 0.0, 0.0, 0.0, 1.0 },
	};
	simd_float4x4 result;
	memset(&result, 0, sizeof(result));

	[FxMatrix44 doubleMatrix:&data toFloat4x4Matrix:&result];

	XCTAssertEqual(result.columns[0][0], (float)0.1);
	XCTAssertNotEqual((double)result.columns[0][0], 0.1, @"the value narrows to single precision");
}

@end
