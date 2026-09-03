//
//  FxGripPhysicsSimulationStoreTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripPhysicsSimulationStore.h>
#import <FxGrip/FxGripFrameData.h>

@interface FxGripPhysicsSimulationStoreTests : XCTestCase
@end

@implementation FxGripPhysicsSimulationStoreTests

static NSDictionary<NSString *, NSData *> *SampleRecord(void)
{
	return @{ @"ball": [@"transform-bytes" dataUsingEncoding:NSUTF8StringEncoding] };
}

#pragma mark Memory store

- (void)testMemoryStoreRoundTripAndInvalidate
{
	FxGripPhysicsMemoryStore *store = [FxGripPhysicsMemoryStore.alloc init];
	NSDictionary<NSString *, NSData *> *record = SampleRecord();

	[store setTransforms:record forStep:5];
	XCTAssertEqualObjects([store transformsForStep:5], record);
	XCTAssertNil([store transformsForStep:6]);

	[store invalidate];
	XCTAssertNil([store transformsForStep:5]);
}

- (void)testMemoryStoreSignatureInvalidation
{
	FxGripPhysicsMemoryStore *store = [FxGripPhysicsMemoryStore.alloc init];

	[store invalidateIfSignatureChanged:@"A"];
	[store setTransforms:SampleRecord() forStep:1];

	[store invalidateIfSignatureChanged:@"A"]; // unchanged: kept
	XCTAssertNotNil([store transformsForStep:1]);

	[store invalidateIfSignatureChanged:@"B"]; // changed: cleared
	XCTAssertNil([store transformsForStep:1]);
}

#pragma mark FrameData store

- (void)testFrameDataStorePersistsRecordsInTheFrameData
{
	FxGripFrameData *frameData = [FxGripFrameData.alloc init];
	FxGripPhysicsFrameDataStore *store = [FxGripPhysicsFrameDataStore.alloc initWithFrameData:frameData];
	NSDictionary<NSString *, NSData *> *record = SampleRecord();

	[store setTransforms:record forStep:3];

	XCTAssertEqualObjects([store transformsForStep:3], record);
	// The record lives in the FrameData itself, which persists with the document.
	XCTAssertEqualObjects([frameData recordAtIndex:3], record);
}

- (void)testFrameDataStoreSignatureInvalidationClearsRecords
{
	FxGripFrameData *frameData = [FxGripFrameData.alloc init];
	FxGripPhysicsFrameDataStore *store = [FxGripPhysicsFrameDataStore.alloc initWithFrameData:frameData];

	[store invalidateIfSignatureChanged:@"sig-1"];
	[store setTransforms:SampleRecord() forStep:0];
	[store setTransforms:SampleRecord() forStep:1];

	[store invalidateIfSignatureChanged:@"sig-1"]; // unchanged
	XCTAssertEqual(frameData.frameIndexes.count, 2u);

	[store invalidateIfSignatureChanged:@"sig-2"]; // changed
	XCTAssertEqual(frameData.frameIndexes.count, 0u);
	XCTAssertNil([store transformsForStep:0]);
}

@end
