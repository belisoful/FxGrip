//
//  FxGripImageBuffer.h
//  FxGrip
//

#ifndef FxGripImageBuffer_h
#define FxGripImageBuffer_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import "FxGripImageCompression.h"

#define kFxGripImageBufferDefaultQuality	(0.75f)

/*!
	@class      FxGripImageBuffer
	@abstract   An immutable image buffer that stores its pixels compressed.
	@discussion Introduced in FxGrip 1.0. Pixels compress at initialization and stay
				compressed in memory; encodeWithCoder: writes the compressed bytes
				directly, so archiving a buffer costs no compression pass. pixelData
				decompresses on demand and returns tightly-packed rows.

				Lossless codecs preserve the pixels exactly. Lossy reduction takes two
				forms: format conversion (bufferByConvertingToFormat:compression:
				converts between any channel counts and component types through a
				canonical RGBA intermediate — color collapses to Rec.709 luminance for
				a Gray target, gray replicates to color channels, alpha is added opaque
				or discarded, and narrower components lose precision) and the lossy
				image codecs governed by the `quality` setting — a render cache might
				use JPEG at quality 0.5. Every format lossy-encodes: components
				down-convert to the codec's internal depth (JPEG carries 8-bit; HEIC
				carries 16-bit components over its 10/12-bit HEVC internals, so wider
				sources keep precision beyond 8), floats clamp to 0...1, and alpha
				always encodes as its own plane alongside the color, so no
				premultiplication touches the pixels. Only an encoder failure stores
				raw.

				Bridges: Metal textures for the 1-, 2-, and 4-channel formats (Gray→R,
				GrayAlpha→RG, RGBA; Metal has no packed 3-channel storage), and
				NSBitmapImageRep/NSImage previews through an RGBA8U conversion.
 	@agent @todo should floats not be clamped to 0...1 due to HDR content?
*/
@interface FxGripImageBuffer : NSObject <NSSecureCoding, NSCopying>

/*!
	@method     initWithBytes:rowBytes:width:height:format:compression:
	@abstract   Copies and compresses pixel rows.
	@discussion `rowBytes` is the source stride; rows are repacked tightly. When the
				codec does not shrink the data the buffer stores it uncompressed.
				Returns nil for an invalid format, zero dimensions, or a nil source.
*/
- (nullable instancetype)initWithBytes:(const void *_Nonnull)pixels
							  rowBytes:(NSUInteger)rowBytes
								 width:(NSUInteger)width
								height:(NSUInteger)height
								format:(FxGripPixelFormat)format
						   compression:(FxGripCompression)compression;

/*!
	@method     initWithBytes:rowBytes:width:height:format:compression:quality:
	@abstract   Copies and compresses pixel rows with a lossy-codec quality.
	@discussion `quality` is 0...1 and applies to the lossy image codecs; lossless
				codecs ignore it. The quality-less initializer uses
				kFxGripImageBufferDefaultQuality.
*/
- (nullable instancetype)initWithBytes:(const void *_Nonnull)pixels
							  rowBytes:(NSUInteger)rowBytes
								 width:(NSUInteger)width
								height:(NSUInteger)height
								format:(FxGripPixelFormat)format
						   compression:(FxGripCompression)compression
							   quality:(float)quality;

@property (readonly) NSUInteger width;
@property (readonly) NSUInteger height;
@property (readonly) FxGripPixelFormat format;
/*! The codec the payload is stored with; None when a lossless codec did not shrink it
	or the encoder failed. */
@property (readonly) FxGripCompression compression;
/*! The lossy-codec quality (0...1) the payload was encoded with. */
@property (readonly) float quality;
/*! Tightly-packed bytes per row: width times bytes per pixel. */
@property (readonly) NSUInteger rowBytes;
@property (readonly) NSUInteger uncompressedLength;
@property (readonly, nonnull) NSData *compressedData;

/*! The decompressed, tightly-packed pixels; nil when the payload fails to decompress. */
- (nullable NSData *)pixelData;

/*!
	@method     bufferByConvertingToFormat:compression:
	@abstract   Converts to another pixel format and recompresses.
	@discussion Pixels pass through a canonical RGBA double intermediate: a Gray source
				replicates to the color channels, a color source collapses to Rec.709
				luminance for a Gray or GrayAlpha target, alpha is carried, added
				opaque, or discarded, integer components map to 0...1, floats pass
				unclamped between float formats, and a float to an integer component
				clamps to 0...1.
*/
- (nullable FxGripImageBuffer *)bufferByConvertingToFormat:(FxGripPixelFormat)format
											   compression:(FxGripCompression)compression;

/*! bufferByConvertingToFormat:compression: with a lossy-codec quality. */
- (nullable FxGripImageBuffer *)bufferByConvertingToFormat:(FxGripPixelFormat)format
											   compression:(FxGripCompression)compression
												   quality:(float)quality;

/*! A new Metal texture holding the pixels. Gray maps to R, GrayAlpha to RG, RGBA to
	RGBA (8U as Unorm, 16U as Unorm, 32U as Uint, floats as Float); nil for the
	3-channel formats. */
- (nullable id<MTLTexture>)newTextureWithDevice:(nonnull id<MTLDevice>)device;

/*!
	@method     bufferWithTexture:compression:
	@abstract   Reads a Metal texture into a buffer.
	@discussion Supported texture formats: the R/RG/RGBA members of Unorm 8/16, Uint 32,
				and Float 16/32. Returns nil for any other format.
*/
+ (nullable instancetype)bufferWithTexture:(nonnull id<MTLTexture>)texture
							   compression:(FxGripCompression)compression;

/*! An RGBA8U preview representation. */
- (nullable NSBitmapImageRep *)bitmapRep;
- (nullable NSImage *)image;

@end

#endif /* FxGripImageBuffer_h */
