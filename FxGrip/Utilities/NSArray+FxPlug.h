/*!
	@file       NSArray+FxPlug.h
	@copyright  Copyright © 2020-2023 Apple, Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     NSArray+FxPlug
	@abstract   Finds FxImageTile inputs in the source-tile array a host hands a render.
	@discussion Introduced in FxGrip 0.1.0. FxPlug passes a render its input tiles as a flat
	            NSArray of FxImageTile, each tagged with a parameterID. The effect source carries
	            parameterID 0. This category locates a tile by its parameterID and finds the
	            effect source, so a render reads its inputs by identifier.
*/

#import <Foundation/Foundation.h>

@class FxImageTile;

/*! The sentinel returned when no matching tile is found. */
#define kFxImageTileNotFound (-1)

/*!
	@abstract	Locates FxImageTile inputs within a source-tile array by parameterID.
	@discussion	Introduced in FxGrip 0.1.0. The effect source is the tile with parameterID 0.
*/
@interface NSArray (FxImageTileSearch)
/*! The index of the effect-source tile (parameterID 0), or kFxImageTileNotFound. */
- (NSInteger)effectSourceIndex;
/*! The effect-source tile (parameterID 0), or nil when absent. */
- (nullable FxImageTile *)effectSource;
/*! The first tile whose parameterID matches, or nil. */
- (nullable FxImageTile *)imageTileAtIndex:(UInt32)parameterID;
/*! Every tile whose parameterID matches, in order. */
- (nullable NSArray<FxImageTile *>*)imageTilesAtIndex:(UInt32)parameterID;
@end
