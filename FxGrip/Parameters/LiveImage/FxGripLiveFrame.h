/*!
	@file       FxGripLiveFrame.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripLiveFrame
	@abstract   One immutable published image: tightly packed pixels with a CGImage built on demand.
	@discussion Introduced in FxGrip 0.1.0. A frame is the unit a live image parameter carries from
	            the render pass to its inspector view. It owns a copy of its pixels in a supported
	            Metal pixel format, so it outlives the texture or image it was read from. A CGImage is
	            built lazily, converting a float format to 8-bit on first use. Frames stay in the
	            plugin process and never persist in the host document.
*/

#ifndef FxGripLiveFrame_h
#define FxGripLiveFrame_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>

@class FxGripImageBuffer;

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripLiveFrame
	@abstract   One published image: tightly packed pixels in a Metal pixel format, with a
				CGImage built on demand.
	@discussion Introduced in FxGrip 0.1.0. A frame is the unit a live image parameter carries
				from the render pass to its inspector view. It is immutable and owns a copy
				of its pixels, so it outlives the texture or image it was read from. Frames
				stay in the plugin process and never persist in the host document.

				Supported pixel formats: RGBA8Unorm, RGBA8Unorm_sRGB, BGRA8Unorm,
				BGRA8Unorm_sRGB, RGBA16Unorm, RGBA16Float, RGBA32Float, R8Unorm, R16Float,
				and R32Float. A constructor given any other format returns nil.

				The CGImage wraps the pixel bytes directly for the integer formats. A float
				format converts to 8-bit on first use, clamped to 0...1, and keeps the raw
				float pixels in `pixels`. Color: integer formats are tagged sRGB and float
				formats extended linear sRGB, unless colorSpaceName overrides the tag.
				Four-channel pixels are treated as premultiplied.
*/
@interface FxGripLiveFrame : NSObject <NSCopying>

/*!
	@method     frameWithBytes:rowBytes:width:height:pixelFormat:
	@abstract   Copies pixel rows into a frame.
	@discussion `rowBytes` is the source stride; rows repack tightly. Returns nil for an
				unsupported format, zero dimensions, a nil source, or a stride shorter than
				a row.
*/
+ (nullable instancetype)frameWithBytes:(const void *)pixels
							   rowBytes:(NSUInteger)rowBytes
								  width:(NSUInteger)width
								 height:(NSUInteger)height
							pixelFormat:(MTLPixelFormat)pixelFormat;

/*!
	@method     frameWithTexture:
	@abstract   Reads mipmap level 0 of a 2D texture into a frame.
	@discussion The read is synchronous on the calling thread. The texture must be
				CPU-readable: shared storage, or managed storage after a blit
				synchronize. Returns nil for a private texture, a non-2D texture, or an
				unsupported format.
*/
+ (nullable instancetype)frameWithTexture:(id<MTLTexture>)texture;

/*! Draws a CGImage into an RGBA8Unorm premultiplied frame. */
+ (nullable instancetype)frameWithCGImage:(CGImageRef)image;

/*!
	@method     frameWithImageBuffer:
	@abstract   Wraps an image buffer's pixels.
	@discussion The RGBA and Gray members of the 8U, 16F, and 32F component types, and
				RGBA16U, map to their Metal formats directly; every other buffer format
				converts to RGBA8U first.
*/
+ (nullable instancetype)frameWithImageBuffer:(FxGripImageBuffer *)buffer;

/*! YES for the formats a frame can carry. */
+ (BOOL)supportsPixelFormat:(MTLPixelFormat)pixelFormat;

@property (readonly) NSUInteger width;
@property (readonly) NSUInteger height;
@property (readonly) MTLPixelFormat pixelFormat;
@property (readonly) NSUInteger bytesPerPixel;
/*! Tightly packed bytes per row: width times bytes per pixel. */
@property (readonly) NSUInteger rowBytes;
@property (readonly) NSData *pixels;
@property (readonly) BOOL isFloat;
/*! The system uptime when the frame was created. */
@property (readonly) NSTimeInterval timestamp;
/*! The pixel format's short name: "RGBA16F", "BGRA8", "R32F". */
@property (readonly, copy) NSString *formatDescription;
/*! The dimensions and format: "1920×1080 RGBA16F". */
@property (readonly, copy) NSString *sizeDescription;
/*! A CoreGraphics color-space name (kCGColorSpace…) overriding the format's default
	tag. Set it before the first CGImage use; setting it discards a built CGImage. */
@property (copy, nullable) NSString *colorSpaceName;

/*! The frame drawn as a CGImage; owned by the frame. Nil when CoreGraphics rejects the
	layout. */
- (nullable CGImageRef)CGImage;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripLiveFrame_h */
