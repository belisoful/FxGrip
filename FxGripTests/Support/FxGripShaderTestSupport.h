/*!
	@file       FxGripShaderTestSupport.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripShaderTestSupport
	@abstract   The documented shader example and float image tiles shared by the shader suites.
	@discussion Introduced in FxGrip 0.1.0. The example source is the Shaders DocC article's worked
	            example verbatim, so the metadata suite scans it and the pipeline suite compiles it.
	            The tiles are RGBA32Float stub tiles backed by an IOSurface, so a render's output reads
	            back as exact floats.
*/

#ifndef FxGripShaderTestSupport_h
#define FxGripShaderTestSupport_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <simd/simd.h>
#import <FxPlug/FxPlugSDK.h>

NS_ASSUME_NONNULL_BEGIN

/*! The worked example of the Shaders DocC article, verbatim. */
NSString *FxGripShaderTestDocumentedExampleSource(void);

/*! Wraps a JSON5 body in a metadata block and appends Metal source after it. */
NSString *FxGripShaderTestSource(NSString *metadataBody, NSString *metal);

/*! The system default Metal device, or nil when the machine has none. */
id<MTLDevice> _Nullable FxGripShaderTestDevice(void);

/*! An RGBA32Float tile on the test device whose image and tile bounds are the given bounds, every pixel set to fill. */
FxImageTile *_Nullable FxGripShaderTestFloatTile(FxRect bounds, simd_float4 fill);

/*! Sets every pixel of a float tile from a block of column and row, where row 0 is the top row. */
void FxGripShaderTestFillTile(FxImageTile *tile, simd_float4 (^color)(NSUInteger column, NSUInteger row));

/*! The pixel of a float tile at a column and row, where row 0 is the top row. */
simd_float4 FxGripShaderTestPixel(FxImageTile *tile, NSUInteger column, NSUInteger row);

NS_ASSUME_NONNULL_END

#endif /* FxGripShaderTestSupport_h */
