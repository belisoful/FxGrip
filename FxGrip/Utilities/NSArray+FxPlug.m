/*!
	@file       NSArray+FxPlug.m
	@copyright  Copyright © 2020-2023 Apple, Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     NSArray+FxPlug
	@abstract   Implements FxImageTile lookup within a host source-tile array.
	@discussion Introduced in FxGrip 0.1.0. Each finder enumerates the array, skips non-tile
	            objects, and matches on parameterID. The effect source is the tile with
	            parameterID 0.
*/

#import "NSArray+FxPlug.h"
#import <FxPlug/FxImageTile.h>

#pragma mark -
#pragma mark NSArray FxImageTile Discovery

/*!
	@abstract	Locates FxImageTile inputs within a source-tile array by parameterID.
	@discussion	Introduced in FxGrip 0.1.0. The effect source is the tile with parameterID 0.
*/
@implementation NSArray (FxImageTileSearch)

- (NSInteger)effectSourceIndex
{
	__block NSInteger result = kFxImageTileNotFound;
	[self enumerateObjectsUsingBlock:^(FxImageTile *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		if (![obj isKindOfClass:FxImageTile.class]) {
			return;
		}
		if (obj.parameterID == 0) {
			result = idx;
			*stop = true;
		}
	}];
	return result;
}

- (nullable FxImageTile *)effectSource
{
	__block FxImageTile *result = nil;
	[self enumerateObjectsUsingBlock:^(FxImageTile *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		if (![obj isKindOfClass:FxImageTile.class]) {
			return;
		}
		if (obj.parameterID == 0) {
			result = obj;
			*stop = true;
		}
	}];
	return result;
}


- (nullable FxImageTile *)imageTileAtIndex:(UInt32)parameterID
{
	__block FxImageTile *result = nil;
	[self enumerateObjectsUsingBlock:^(FxImageTile *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		if (![obj isKindOfClass:FxImageTile.class]) {
			return;
		}
		if (obj.parameterID == parameterID) {
			result = obj;
			*stop = true;
		}
	}];
	return result;
}

/*! @abstract The receiver's objects that pass the block, in order. */
- (NSArray *) filteredArrayUsingBlock:(BOOL (^)(id obj))block {
	NSIndexSet *const filteredIndexes = [self indexesOfObjectsPassingTest:^BOOL (id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
									   return block(obj);
								   }];

	return [self objectsAtIndexes:filteredIndexes];
}


- (nullable NSArray<FxImageTile *>*)imageTilesAtIndex:(UInt32)parameterID
{
	return [self filteredArrayUsingBlock:^BOOL(FxImageTile *obj) {
		if (![obj isKindOfClass:FxImageTile.class]) {
			return NO;
		}
		return obj.parameterID == parameterID;
	}];
}



@end
