/*!
	@file       FxGripTileGeometryTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileGeometryTests
	@abstract   Tests the pixel-to-image and image-to-pixel rect conversions against a stub transform.
	@discussion Introduced in FxGrip 0.1.0. A stub matrix applies a known scale and offset so the conversions are checked without a live FxPlug host. The tests cover corner transformation with outward rounding, inversion back to the image rect, and the empty result when no transform is supplied.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxTileImage+FxGrip.h>
#import <FxGrip/FxGripRect.h>

/*! A stand-in for FxMatrix44 applying p → (scale·x + offset.x, scale·y + offset.y). */
@interface FxGripTileGeoStubMatrix : NSObject
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) CGPoint offset;
@end

@implementation FxGripTileGeoStubMatrix

- (instancetype)init
{
	self = [super init];
	if (self) {
		_scale = 1.0;
	}
	return self;
}

- (CGPoint)transform2DPoint:(CGPoint)point
{
	return CGPointMake(point.x * self.scale + self.offset.x, point.y * self.scale + self.offset.y);
}

@end

@interface FxGripTileGeometryTests : XCTestCase
@end

@implementation FxGripTileGeometryTests

/*! @abstract Transforming an image rect scales and offsets its corners into the expected integer pixel box. */
- (void)testPixelBoundsForImageRectTransformsCornersAndRoundsOutward
{
	FxGripTileGeoStubMatrix *transform = FxGripTileGeoStubMatrix.new;
	transform.scale = 2.0;
	transform.offset = CGPointMake(10, 20);

	// Image rect (0,0)-(5,5); corners scale·2 + offset → pixel box (10,20)-(20,30).
	FxRect bounds = FxGripPixelBoundsForImageRect(CGRectMake(0, 0, 5, 5), (FxMatrix44 *)transform);
	XCTAssertEqual(bounds.left, 10);
	XCTAssertEqual(bounds.bottom, 20);
	XCTAssertEqual(bounds.right, 20);
	XCTAssertEqual(bounds.top, 30);
}

/*! @abstract A fractional offset floors the low pixel edges and ceils the high pixel edges. */
- (void)testPixelBoundsRoundsAFractionalTransformOutward
{
	FxGripTileGeoStubMatrix *transform = FxGripTileGeoStubMatrix.new;
	transform.scale = 1.0;
	transform.offset = CGPointMake(0.4, 0.6);

	FxRect bounds = FxGripPixelBoundsForImageRect(CGRectMake(0, 0, 5, 5), (FxMatrix44 *)transform);
	XCTAssertEqual(bounds.left, 0, @"0.4 floors to 0");
	XCTAssertEqual(bounds.bottom, 0, @"0.6 floors to 0");
	XCTAssertEqual(bounds.right, 6, @"5.4 ceils to 6");
	XCTAssertEqual(bounds.top, 6, @"5.6 ceils to 6");
}

/*! @abstract Converting a pixel box through the inverse transform recovers the original image rect. */
- (void)testImageRectForPixelBoundsInvertsThroughTheTransform
{
	// Inverse of (scale 2, offset 10/20): p → ((x-10)/2, (y-20)/2).
	FxGripTileGeoStubMatrix *inverse = FxGripTileGeoStubMatrix.new;
	inverse.scale = 0.5;
	inverse.offset = CGPointMake(-5, -10);

	CGRect imageRect = FxGripImageRectForPixelBounds(FxGripRectMake(10, 20, 20, 30), (FxMatrix44 *)inverse);
	XCTAssertEqual(imageRect.origin.x, 0.0);
	XCTAssertEqual(imageRect.origin.y, 0.0);
	XCTAssertEqual(imageRect.size.width, 5.0);
	XCTAssertEqual(imageRect.size.height, 5.0);
}

/*! @abstract A nil transform yields an empty image rect and an empty pixel bounds in both directions. */
- (void)testConversionsWithoutATransformAreEmpty
{
	CGRect emptyImage = FxGripImageRectForPixelBounds(FxGripRectMake(0, 0, 10, 10), nil);
	XCTAssertEqual(emptyImage.size.width, 0.0);
	XCTAssertEqual(emptyImage.size.height, 0.0);
	XCTAssertTrue(FxGripRectIsEmpty(FxGripPixelBoundsForImageRect(CGRectMake(0, 0, 10, 10), nil)));
}

@end
