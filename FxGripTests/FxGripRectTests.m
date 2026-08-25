//
//  FxGripRectTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripRect.h>

@interface FxGripRectTests : XCTestCase
@end

@implementation FxGripRectTests

- (void)testWidthAndHeightClampToZero
{
	FxRect rect = FxGripRectMake(10, 20, 40, 80);
	XCTAssertEqual(FxGripRectWidth(rect), 30);
	XCTAssertEqual(FxGripRectHeight(rect), 60);

	FxRect inverted = FxGripRectMake(40, 80, 10, 20);
	XCTAssertEqual(FxGripRectWidth(inverted), 0);
	XCTAssertEqual(FxGripRectHeight(inverted), 0);
}

- (void)testEmptyDetection
{
	XCTAssertTrue(FxGripRectIsEmpty(FxGripRectZero()));
	XCTAssertTrue(FxGripRectIsEmpty(FxGripRectMake(10, 10, 10, 20)), @"zero width is empty");
	XCTAssertTrue(FxGripRectIsEmpty(FxGripRectMake(10, 10, 20, 10)), @"zero height is empty");
	XCTAssertFalse(FxGripRectIsEmpty(FxGripRectMake(0, 0, 1, 1)));
}

- (void)testEquality
{
	XCTAssertTrue(FxGripRectEqualToRect(FxGripRectMake(1, 2, 3, 4), FxGripRectMake(1, 2, 3, 4)));
	XCTAssertFalse(FxGripRectEqualToRect(FxGripRectMake(1, 2, 3, 4), FxGripRectMake(1, 2, 3, 5)));
}

- (void)testStandardizeSwapsInvertedEdges
{
	FxRect standard = FxGripRectStandardize(FxGripRectMake(40, 80, 10, 20));
	XCTAssertTrue(FxGripRectEqualToRect(standard, FxGripRectMake(10, 20, 40, 80)));
}

- (void)testContainsPointIsHalfOpen
{
	FxRect rect = FxGripRectMake(0, 0, 10, 10);
	XCTAssertTrue(FxGripRectContainsPoint(rect, 0, 0), @"the lower-left edge is inclusive");
	XCTAssertTrue(FxGripRectContainsPoint(rect, 9, 9));
	XCTAssertFalse(FxGripRectContainsPoint(rect, 10, 5), @"the right edge is exclusive");
	XCTAssertFalse(FxGripRectContainsPoint(rect, 5, 10), @"the top edge is exclusive");
}

- (void)testContainsRect
{
	FxRect outer = FxGripRectMake(0, 0, 100, 100);
	XCTAssertTrue(FxGripRectContainsRect(outer, FxGripRectMake(10, 10, 20, 20)));
	XCTAssertFalse(FxGripRectContainsRect(outer, FxGripRectMake(90, 90, 110, 110)));
	XCTAssertTrue(FxGripRectContainsRect(outer, FxGripRectZero()), @"an empty rect is contained");
	XCTAssertFalse(FxGripRectContainsRect(FxGripRectZero(), FxGripRectMake(0, 0, 1, 1)));
}

- (void)testIntersection
{
	FxRect a = FxGripRectMake(0, 0, 50, 50);
	FxRect b = FxGripRectMake(25, 25, 75, 75);
	XCTAssertTrue(FxGripRectEqualToRect(FxGripRectIntersection(a, b), FxGripRectMake(25, 25, 50, 50)));
	XCTAssertTrue(FxGripRectIntersectsRect(a, b));

	FxRect disjoint = FxGripRectMake(60, 60, 70, 70);
	XCTAssertTrue(FxGripRectIsEmpty(FxGripRectIntersection(a, disjoint)));
	XCTAssertFalse(FxGripRectIntersectsRect(a, disjoint));
}

- (void)testUnionTreatsEmptyAsAbsent
{
	FxRect a = FxGripRectMake(0, 0, 50, 50);
	FxRect b = FxGripRectMake(25, 25, 75, 75);
	XCTAssertTrue(FxGripRectEqualToRect(FxGripRectUnion(a, b), FxGripRectMake(0, 0, 75, 75)));
	XCTAssertTrue(FxGripRectEqualToRect(FxGripRectUnion(a, FxGripRectZero()), a));
	XCTAssertTrue(FxGripRectEqualToRect(FxGripRectUnion(FxGripRectZero(), b), b));
	XCTAssertTrue(FxGripRectIsEmpty(FxGripRectUnion(FxGripRectZero(), FxGripRectZero())));
}

- (void)testOffsetAndInset
{
	FxRect rect = FxGripRectMake(10, 10, 30, 30);
	XCTAssertTrue(FxGripRectEqualToRect(FxGripRectOffset(rect, 5, -5), FxGripRectMake(15, 5, 35, 25)));
	XCTAssertTrue(FxGripRectEqualToRect(FxGripRectInset(rect, 5, 5), FxGripRectMake(15, 15, 25, 25)));
	XCTAssertTrue(FxGripRectEqualToRect(FxGripRectInset(rect, -5, -5), FxGripRectMake(5, 5, 35, 35)), @"a negative inset grows");
	XCTAssertTrue(FxGripRectIsEmpty(FxGripRectInset(rect, 100, 100)), @"an over-inset is empty");
}

- (void)testCGRectBridgeRoundTrips
{
	FxRect rect = FxGripRectMake(10, 20, 40, 80);
	CGRect cg = FxGripRectToCGRect(rect);
	XCTAssertEqual(cg.origin.x, 10.0);
	XCTAssertEqual(cg.origin.y, 20.0);
	XCTAssertEqual(cg.size.width, 30.0);
	XCTAssertEqual(cg.size.height, 60.0);
	XCTAssertTrue(FxGripRectEqualToRect(FxGripRectFromCGRect(cg), rect));
}

- (void)testFromCGRectCoversFractionalEdges
{
	FxRect rect = FxGripRectFromCGRect(CGRectMake(10.4, 20.6, 5.2, 5.1));
	XCTAssertEqual(rect.left, 10);
	XCTAssertEqual(rect.bottom, 20);
	XCTAssertEqual(rect.right, 16), @"maxX 15.6 rounds up";
	XCTAssertEqual(rect.top, 26), @"maxY 25.7 rounds up";
}

- (void)testCGRectCorners
{
	CGPoint corners[4];
	FxGripCGRectGetCorners(CGRectMake(10, 20, 30, 40), corners);
	XCTAssertTrue(CGPointEqualToPoint(corners[0], CGPointMake(10, 20)), @"lower-left");
	XCTAssertTrue(CGPointEqualToPoint(corners[1], CGPointMake(40, 20)), @"lower-right");
	XCTAssertTrue(CGPointEqualToPoint(corners[2], CGPointMake(40, 60)), @"upper-right");
	XCTAssertTrue(CGPointEqualToPoint(corners[3], CGPointMake(10, 60)), @"upper-left");
}

- (void)testBoundingPoints
{
	CGPoint points[4] = { CGPointMake(5, 5), CGPointMake(-3, 10), CGPointMake(2, -1), CGPointMake(8, 4) };
	CGRect bounds = FxGripCGRectBoundingPoints(points, 4);
	XCTAssertEqual(bounds.origin.x, -3.0);
	XCTAssertEqual(bounds.origin.y, -1.0);
	XCTAssertEqual(bounds.origin.x + bounds.size.width, 8.0);
	XCTAssertEqual(bounds.origin.y + bounds.size.height, 10.0);

	CGRect empty = FxGripCGRectBoundingPoints(NULL, 0);
	XCTAssertEqual(empty.size.width, 0.0);
	XCTAssertEqual(empty.size.height, 0.0);
}

@end
