//
//  NSArray+FxPlug.h
//  NSArray+FxPlug
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FxImageTile;

#define kFxImageTileNotFound (-1)

@interface NSArray (FxImageTileSearch)
- (NSInteger)effectSourceIndex;
- (nullable FxImageTile *)effectSource;
- (nullable FxImageTile *)imageTileAtIndex:(UInt32)parameterID;
- (nullable NSArray<FxImageTile *>*)imageTilesAtIndex:(UInt32)parameterID;
@end
