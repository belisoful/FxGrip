//
//  NSArray+FxPlug.m
//  FxTileableEffectBase
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#import "NSArray+FxPlug.h"
#import <FxPlug/FxImageTile.h>

#pragma mark -
#pragma mark NSArray FxImageTile Discovery

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
