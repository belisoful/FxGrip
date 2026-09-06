/*!
	@file       FxGripPhysicsSimulationStoreTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPhysicsSimulationStoreTests
	@abstract   Tests for the physics simulation stores that cache baked body transforms per step.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the in-memory store and the frame-data-backed store. Both round-trip a per-step transform record, invalidate on demand, and clear their records when the simulation signature changes.
*/

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

/*! @abstract The memory store returns a stored step's transforms, nil for an unset step, and nil for every step after -invalidate. */
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

/*! @abstract The memory store keeps its records when the signature is unchanged and clears them when it changes. */
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

/*! @abstract The frame-data store returns a stored step's transforms and writes the record into the backing FrameData at the same index. */
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

/*! @abstract The frame-data store keeps its FrameData records on an unchanged signature and empties them when the signature changes. */
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
