/*!
	@file       FxGripTileableGeneratorTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripTileableGeneratorTests
	@abstract   Unit tests for the FxGripTileableGenerator destination and source-tile callbacks.
	@discussion Introduced in FxGrip 0.1.0. A generator draws its output without a source image, so
	            the destination rect is the destination tile's image pixel bounds and the source
	            tile rect is empty. The tests cover both the pluginState and pluginCoder render paths.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTileableGenerator.h>
#import "FxPlugStub.h"

@interface FxGripTileableGeneratorTestEffect : FxGripTileableGenerator
@end

@implementation FxGripTileableGeneratorTestEffect
@end


@interface FxGripTileableGeneratorTests : XCTestCase
@end

@implementation FxGripTileableGeneratorTests

- (FxGripTileableGeneratorTestEffect *)makeGenerator
{
	FxGripTileableGeneratorTestEffect *generator =
		[FxGripTileableGeneratorTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(generator);
	return generator;
}

- (FxImageTile *)destinationTile
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:((FxRect){ 0, 0, 16, 8 })];
	tile.imagePixelBounds = (FxRect){ -3, -5, 640, 480 };
	return tile;
}

- (void)assertRect:(FxRect)rect equals:(FxRect)expected
{
	XCTAssertEqual(rect.left, expected.left);
	XCTAssertEqual(rect.bottom, expected.bottom);
	XCTAssertEqual(rect.right, expected.right);
	XCTAssertEqual(rect.top, expected.top);
}

/*! @abstract The generator subclasses FxGripTileableEffect. */
- (void)testGeneratorIsATileableEffect
{
	XCTAssertTrue([FxGripTileableGenerator isSubclassOfClass:FxGripTileableEffect.class]);
}

/*! @abstract The pluginState destination rect is the destination tile's image pixel bounds. */
- (void)testDestinationImageRectWithPluginStateIsTheDestinationImageBounds
{
	FxGripTileableGeneratorTestEffect *generator = [self makeGenerator];
	FxImageTile *destination = [self destinationTile];
	FxRect rect = { 1, 1, 1, 1 };
	NSError *error = nil;

	BOOL ok = [generator destinationImageRect:&rect
								 sourceImages:@[]
							 destinationImage:destination
								  pluginState:nil
									   atTime:kCMTimeZero
										error:&error];

	XCTAssertTrue(ok);
	XCTAssertNil(error);
	[self assertRect:rect equals:destination.imagePixelBounds];
}

/*! @abstract The pluginState source tile rect is empty for any source index. */
- (void)testSourceTileRectWithPluginStateIsEmpty
{
	FxGripTileableGeneratorTestEffect *generator = [self makeGenerator];
	FxImageTile *destination = [self destinationTile];
	FxRect rect = { 7, 7, 7, 7 };
	NSError *error = nil;

	BOOL ok = [generator sourceTileRect:&rect
					   sourceImageIndex:3
						   sourceImages:@[]
					destinationTileRect:destination.tilePixelBounds
					   destinationImage:destination
							pluginState:nil
								 atTime:kCMTimeZero
								  error:&error];

	XCTAssertTrue(ok);
	XCTAssertNil(error);
	[self assertRect:rect equals:kFxRect_Empty];
}

/*! @abstract The pluginCoder destination rect is the destination tile's image pixel bounds. */
- (void)testDestinationImageRectWithPluginCoderIsTheDestinationImageBounds
{
	FxGripTileableGeneratorTestEffect *generator = [self makeGenerator];
	FxImageTile *destination = [self destinationTile];
	NSKeyedArchiver *coder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
	FxRect rect = { 1, 1, 1, 1 };
	NSError *error = nil;

	BOOL ok = [generator destinationImageRect:&rect
								 sourceImages:@[]
							 destinationImage:destination
								  pluginCoder:coder
									   atTime:kCMTimeZero
										error:&error];

	XCTAssertTrue(ok);
	XCTAssertNil(error);
	[self assertRect:rect equals:destination.imagePixelBounds];
}

/*! @abstract The pluginCoder source tile rect is empty for any source index. */
- (void)testSourceTileRectWithPluginCoderIsEmpty
{
	FxGripTileableGeneratorTestEffect *generator = [self makeGenerator];
	FxImageTile *destination = [self destinationTile];
	NSKeyedArchiver *coder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
	FxRect rect = { 7, 7, 7, 7 };
	NSError *error = nil;

	BOOL ok = [generator sourceTileRect:&rect
					   sourceImageIndex:0
						   sourceImages:@[]
					destinationTileRect:destination.tilePixelBounds
					   destinationImage:destination
							pluginCoder:coder
								 atTime:kCMTimeZero
								  error:&error];

	XCTAssertTrue(ok);
	XCTAssertNil(error);
	[self assertRect:rect equals:kFxRect_Empty];
}

@end
