//
//  NSArrayFxPlugTests.m
//  FxGripTests
//
//  Unit tests for the NSArray (FxImageTileSearch) category: locating the effect
//  source tile and the tiles bound to a given input parameter within a tile list.
//

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

- (void)testEffectSourceIndexOfAnEmptyArrayIsNotFound
{
	XCTAssertEqual(@[].effectSourceIndex, (NSInteger)kFxImageTileNotFound);
}

- (void)testEffectSourceOfAnEmptyArrayIsNil
{
	XCTAssertNil(@[].effectSource);
}

- (void)testImageTileAtIndexOfAnEmptyArrayIsNil
{
	XCTAssertNil([@[] imageTileAtIndex:0]);
	XCTAssertNil([@[] imageTileAtIndex:7]);
}

- (void)testImageTilesAtIndexOfAnEmptyArrayIsAnEmptyArray
{
	NSArray *tiles = [@[] imageTilesAtIndex:0];

	XCTAssertNotNil(tiles);
	XCTAssertEqual(tiles.count, (NSUInteger)0);
}

#pragma mark - Non-Tile Elements

- (void)testEffectSourceIgnoresElementsThatAreNotImageTiles
{
	NSArray *list = @[ [FxGripTileSearchStub stubWithParameterID:0], [FxGripTileSearchStub stubWithParameterID:1] ];

	XCTAssertNil(list.effectSource);
}

- (void)testImageTileAtIndexIgnoresElementsThatAreNotImageTiles
{
	NSArray *list = @[ [FxGripTileSearchStub stubWithParameterID:3] ];

	XCTAssertNil([list imageTileAtIndex:3]);
}

- (void)testImageTilesAtIndexIgnoresElementsThatAreNotImageTiles
{
	NSArray *list = @[ [FxGripTileSearchStub stubWithParameterID:3], [FxGripTileSearchStub stubWithParameterID:3] ];

	NSArray *tiles = [list imageTilesAtIndex:3];

	XCTAssertNotNil(tiles);
	XCTAssertEqual(tiles.count, (NSUInteger)0);
}

- (void)testImageTileSearchesToleratePlainObjectsInTheList
{
	NSArray *list = @[ @"string", @42, [NSNull null] ];

	XCTAssertNil(list.effectSource);
	XCTAssertNil([list imageTileAtIndex:0]);
	XCTAssertEqual([list imageTilesAtIndex:0].count, (NSUInteger)0);
}

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
