/*!
	@file       NSArrayFxPlugTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     NSArrayFxPlugTests
	@abstract   Verifies the NSArray (FxImageTileSearch) category that locates image tiles inside a tile list.
	@discussion Introduced in FxGrip 0.1.0. The category filters a mixed array on -isKindOfClass: before comparing parameter identifiers. These tests drive the search paths with a non-tile stub, so they run without an FxPlug host, and they pin the empty-list and non-tile behavior of each accessor.
*/

#import <XCTest/XCTest.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/NSArray+FxPlug.h"

/*!
	A tile-shaped object that is deliberately not an FxImageTile. Every search method
	filters on -isKindOfClass:, so a stub exercises the class test and the parameterID
	comparison without requiring FxPlug.framework, which is weak-linked and absent
	outside an FxPlug host.
*/
@interface FxGripTileSearchStub : NSObject
@property (nonatomic) UInt32 parameterID;
+ (instancetype)stubWithParameterID:(UInt32)parameterID;
@end

@implementation FxGripTileSearchStub

+ (instancetype)stubWithParameterID:(UInt32)parameterID
{
	FxGripTileSearchStub *stub = [self new];
	stub.parameterID = parameterID;
	return stub;
}

@end


@interface NSArrayFxPlugTests : XCTestCase
@end

@implementation NSArrayFxPlugTests

#pragma mark - Empty Input

/*! @abstract The effect-source index of an empty array is kFxImageTileNotFound. */
- (void)testEffectSourceIndexOfAnEmptyArrayIsNotFound
{
	XCTAssertEqual(@[].effectSourceIndex, (NSInteger)kFxImageTileNotFound);
}

/*! @abstract The effect source of an empty array is nil. */
- (void)testEffectSourceOfAnEmptyArrayIsNil
{
	XCTAssertNil(@[].effectSource);
}

/*! @abstract The tile at any index of an empty array is nil. */
- (void)testImageTileAtIndexOfAnEmptyArrayIsNil
{
	XCTAssertNil([@[] imageTileAtIndex:0]);
	XCTAssertNil([@[] imageTileAtIndex:7]);
}

/*! @abstract The tiles at any index of an empty array are a non-nil empty array. */
- (void)testImageTilesAtIndexOfAnEmptyArrayIsAnEmptyArray
{
	NSArray *tiles = [@[] imageTilesAtIndex:0];

	XCTAssertNotNil(tiles);
	XCTAssertEqual(tiles.count, (NSUInteger)0);
}

#pragma mark - Non-Tile Elements

/*! @abstract The effect source skips elements that are not FxImageTile instances and returns nil. */
- (void)testEffectSourceIgnoresElementsThatAreNotImageTiles
{
	NSArray *list = @[ [FxGripTileSearchStub stubWithParameterID:0], [FxGripTileSearchStub stubWithParameterID:1] ];

	XCTAssertNil(list.effectSource);
}

/*! @abstract imageTileAtIndex: skips a non-tile element whose parameterID matches and returns nil. */
- (void)testImageTileAtIndexIgnoresElementsThatAreNotImageTiles
{
	NSArray *list = @[ [FxGripTileSearchStub stubWithParameterID:3] ];

	XCTAssertNil([list imageTileAtIndex:3]);
}

/*! @abstract imageTilesAtIndex: skips non-tile elements whose parameterID matches and returns an empty array. */
- (void)testImageTilesAtIndexIgnoresElementsThatAreNotImageTiles
{
	NSArray *list = @[ [FxGripTileSearchStub stubWithParameterID:3], [FxGripTileSearchStub stubWithParameterID:3] ];

	NSArray *tiles = [list imageTilesAtIndex:3];

	XCTAssertNotNil(tiles);
	XCTAssertEqual(tiles.count, (NSUInteger)0);
}

/*! @abstract The search accessors tolerate strings, numbers, and NSNull in the list without raising. */
- (void)testImageTileSearchesToleratePlainObjectsInTheList
{
	NSArray *list = @[ @"string", @42, [NSNull null] ];

	XCTAssertNil(list.effectSource);
	XCTAssertNil([list imageTileAtIndex:0]);
	XCTAssertEqual([list imageTilesAtIndex:0].count, (NSUInteger)0);
}

/*! @abstract imageTilesAtIndex: returns a non-nil array for an index that matches nothing and for an empty list. */
- (void)testImageTilesAtIndexNeverReturnsNil
{
	XCTAssertNotNil([@[ @"a" ] imageTilesAtIndex:1]);
	XCTAssertNotNil([@[] imageTilesAtIndex:1]);
}

#pragma mark - Effect Source Index

/*!
	FRAMEWORK DEFECT. -effectSourceIndex inverts the class test its three sibling
	methods use: it skips every element that IS an FxImageTile and inspects every
	element that is not one. An element that is not a tile therefore reports as the
	effect source, and an element without a -parameterID raises. NSArray+FxPlug.m:21.
*/
- (void)testEffectSourceIndexAgreesWithEffectSource
{
	NSArray *list = @[ [FxGripTileSearchStub stubWithParameterID:1], [FxGripTileSearchStub stubWithParameterID:0] ];

	XCTAssertNil(list.effectSource, "precondition: no element is an FxImageTile");
	XCTAssertEqual(list.effectSourceIndex, (NSInteger)kFxImageTileNotFound,
				   "an element that is not an FxImageTile is not the effect source");
}

@end
