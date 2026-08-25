//
//  FxGripPointListDataTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripPointListData.h>

@interface FxGripPointListDataTests : XCTestCase
@end

@implementation FxGripPointListDataTests

- (FxGripPointListData *)triangleClosed:(BOOL)closed
{
	CGPoint points[3] = { CGPointMake(0.0, 0.0), CGPointMake(1.0, 0.0), CGPointMake(1.0, 1.0) };
	return [FxGripPointListData pointListWithPoints:points count:3 closed:closed];
}

- (void)testAnEmptyListHasNoPoints
{
	FxGripPointListData *list = [FxGripPointListData emptyPointListClosed:YES];
	XCTAssertEqual(list.count, (NSUInteger)0);
	XCTAssertTrue(list.closed);
	XCTAssertTrue(CGPointEqualToPoint([list pointAtIndex:0], CGPointMake(0.0, 0.0)), @"out-of-range reads are zero");
}

- (void)testTheConstructorStoresPointsInOrder
{
	FxGripPointListData *list = [self triangleClosed:NO];
	XCTAssertEqual(list.count, (NSUInteger)3);
	XCTAssertFalse(list.closed);
	XCTAssertTrue(CGPointEqualToPoint([list pointAtIndex:1], CGPointMake(1.0, 0.0)));
}

- (void)testInsertingAddsAPointAndKeepsTheRest
{
	FxGripPointListData *inserted = [[self triangleClosed:YES] byInsertingPoint:CGPointMake(0.5, 0.5) atIndex:1];
	XCTAssertEqual(inserted.count, (NSUInteger)4);
	XCTAssertTrue(CGPointEqualToPoint([inserted pointAtIndex:1], CGPointMake(0.5, 0.5)));
	XCTAssertTrue(CGPointEqualToPoint([inserted pointAtIndex:2], CGPointMake(1.0, 0.0)));
	XCTAssertTrue(inserted.closed);
}

- (void)testInsertingBeyondTheEndClampsToTheEnd
{
	FxGripPointListData *inserted = [[self triangleClosed:NO] byInsertingPoint:CGPointMake(2.0, 2.0) atIndex:99];
	XCTAssertEqual(inserted.count, (NSUInteger)4);
	XCTAssertTrue(CGPointEqualToPoint([inserted pointAtIndex:3], CGPointMake(2.0, 2.0)));
}

- (void)testRemovingDropsThePointAndReturnsSelfWhenOutOfRange
{
	FxGripPointListData *base = [self triangleClosed:NO];
	FxGripPointListData *removed = [base byRemovingPointAtIndex:0];
	XCTAssertEqual(removed.count, (NSUInteger)2);
	XCTAssertTrue(CGPointEqualToPoint([removed pointAtIndex:0], CGPointMake(1.0, 0.0)));
	XCTAssertEqual([base byRemovingPointAtIndex:9], base, @"an out-of-range removal is a no-op");
}

- (void)testReplacingRewritesOnePoint
{
	FxGripPointListData *replaced = [[self triangleClosed:NO] byReplacingPointAtIndex:2 withPoint:CGPointMake(-1.0, -1.0)];
	XCTAssertEqual(replaced.count, (NSUInteger)3);
	XCTAssertTrue(CGPointEqualToPoint([replaced pointAtIndex:2], CGPointMake(-1.0, -1.0)));
}

- (void)testTranslatingOffsetsEveryPoint
{
	FxGripPointListData *moved = [[self triangleClosed:YES] byTranslatingBy:CGPointMake(0.5, -0.5)];
	XCTAssertTrue(CGPointEqualToPoint([moved pointAtIndex:0], CGPointMake(0.5, -0.5)));
	XCTAssertTrue(CGPointEqualToPoint([moved pointAtIndex:2], CGPointMake(1.5, 0.5)));
	XCTAssertTrue(moved.closed);
}

- (void)testCopyPointsToBufferHonorsCapacity
{
	CGPoint buffer[2];
	NSUInteger written = [[self triangleClosed:NO] copyPointsToBuffer:buffer capacity:2];
	XCTAssertEqual(written, (NSUInteger)2);
	XCTAssertTrue(CGPointEqualToPoint(buffer[0], CGPointMake(0.0, 0.0)));
	XCTAssertTrue(CGPointEqualToPoint(buffer[1], CGPointMake(1.0, 0.0)));
}

- (void)testSecureCodingRoundTrips
{
	FxGripPointListData *original = [self triangleClosed:YES];
	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original requiringSecureCoding:YES error:&error];
	XCTAssertNil(error);
	XCTAssertNotNil(data);

	FxGripPointListData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripPointListData.class
																	 fromData:data
																		error:&error];
	XCTAssertNil(error);
	XCTAssertEqualObjects(decoded, original);
	XCTAssertEqual(decoded.count, (NSUInteger)3);
	XCTAssertTrue(decoded.closed);
}

- (void)testEqualityConsidersPointsAndClosedFlag
{
	XCTAssertEqualObjects([self triangleClosed:YES], [self triangleClosed:YES]);
	XCTAssertNotEqualObjects([self triangleClosed:YES], [self triangleClosed:NO]);
}

@end
