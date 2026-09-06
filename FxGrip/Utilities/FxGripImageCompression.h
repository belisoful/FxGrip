/*!
	@file       FxGripImageCompression.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripImageCompression
	@abstract   Pixel-format descriptors and the lossless and lossy codecs FxGripImageBuffer uses.
	@discussion Introduced in FxGrip 0.1.0. FxGripPixelFormat packs a channel count and component
	            type, and the format functions report its geometry. FxGripCompression names the
	            lossless buffer codecs and the lossy image codecs. The envelope functions wrap a
	            payload in a self-describing container that records the codec and original length,
	            and pass small or incompressible data through unchanged.
*/

#ifndef FxGripImageCompression_h
#define FxGripImageCompression_h

#import <Foundation/Foundation.h>

/*!
	@enum       FxGripComponentType
	@abstract   The storage type of one pixel component.
	@discussion Introduced in FxGrip 0.1.0. Raw values are stable; they participate in the
				packed FxGripPixelFormat values encodeWithCoder: writes.
*/
typedef NS_ENUM(NSInteger, FxGripComponentType) {
	FxGripComponentTypeInvalid	= 0,
	FxGripComponentTypeUInt8	= 1,
	FxGripComponentTypeUInt16	= 2,
	FxGripComponentTypeUInt32	= 3,
	FxGripComponentTypeFloat16	= 4,
	FxGripComponentTypeFloat32	= 5,
};

/*! Packs a channel count (1...4) and a component type into a pixel format. */
#define FxGripPixelFormatMake(channels, componentType) \
	((FxGripPixelFormat)(((channels) << 8) | (componentType)))

/*!
	@enum       FxGripPixelFormat
	@abstract   The interleaved pixel formats FxGripImageBuffer stores.
	@discussion Introduced in FxGrip 0.1.0. Every combination of 1...4 channels and the
				five component types is valid:
				- 1 channel: Gray
				- 2 channels: GrayAlpha
				- 3 channels: RGB
				- 4 channels: RGBA
				Values pack as (channels << 8) | componentType and are stable; they are
				written by encodeWithCoder:.
*/
typedef NS_ENUM(NSInteger, FxGripPixelFormat) {
	FxGripPixelFormatInvalid		= 0,

	FxGripPixelFormatGray8U			= (1 << 8) | FxGripComponentTypeUInt8,
	FxGripPixelFormatGray16U		= (1 << 8) | FxGripComponentTypeUInt16,
	FxGripPixelFormatGray32U		= (1 << 8) | FxGripComponentTypeUInt32,
	FxGripPixelFormatGray16F		= (1 << 8) | FxGripComponentTypeFloat16,
	FxGripPixelFormatGray32F		= (1 << 8) | FxGripComponentTypeFloat32,

	FxGripPixelFormatGrayAlpha8U	= (2 << 8) | FxGripComponentTypeUInt8,
	FxGripPixelFormatGrayAlpha16U	= (2 << 8) | FxGripComponentTypeUInt16,
	FxGripPixelFormatGrayAlpha32U	= (2 << 8) | FxGripComponentTypeUInt32,
	FxGripPixelFormatGrayAlpha16F	= (2 << 8) | FxGripComponentTypeFloat16,
	FxGripPixelFormatGrayAlpha32F	= (2 << 8) | FxGripComponentTypeFloat32,

	FxGripPixelFormatRGB8U			= (3 << 8) | FxGripComponentTypeUInt8,
	FxGripPixelFormatRGB16U			= (3 << 8) | FxGripComponentTypeUInt16,
	FxGripPixelFormatRGB32U			= (3 << 8) | FxGripComponentTypeUInt32,
	FxGripPixelFormatRGB16F		= (3 << 8) | FxGripComponentTypeFloat16,
	FxGripPixelFormatRGB32F		= (3 << 8) | FxGripComponentTypeFloat32,

	FxGripPixelFormatRGBA8U		= (4 << 8) | FxGripComponentTypeUInt8,
	FxGripPixelFormatRGBA16U		= (4 << 8) | FxGripComponentTypeUInt16,
	FxGripPixelFormatRGBA32U		= (4 << 8) | FxGripComponentTypeUInt32,
	FxGripPixelFormatRGBA16F		= (4 << 8) | FxGripComponentTypeFloat16,
	FxGripPixelFormatRGBA32F		= (4 << 8) | FxGripComponentTypeFloat32,
};

// Single-channel float shader naming.
#define FxGripPixelFormatR16F	FxGripPixelFormatGray16F
#define FxGripPixelFormatR32F	FxGripPixelFormatGray32F
#define FxGripPixelFormatRA16F	FxGripPixelFormatGrayAlpha16F
#define FxGripPixelFormatRA32F	FxGripPixelFormatGrayAlpha32F

/*!
	@enum       FxGripCompression
	@abstract   The codecs a buffer's payload may be stored with.
	@discussion Lossless buffer codecs (system Compression library) apply to every
				format: LZFSE balances ratio and speed and is the default; LZ4 favors
				speed; zlib favors interchange; LZMA favors ratio.

				Lossy image codecs (ImageIO) take a quality setting and encode every
				format through an internal depth: JPEG carries 8-bit components, HEIC
				and AVIF carry 16-bit components over their 10/12-bit internals.

				Codecs are reached by type identifier, never by linked symbol, so a
				codec the running OS lacks degrades to an encoder failure. AVIF encoding
				is newer than the deployment target; consult
				FxGripCompressionIsAvailable before choosing it. Raw values are stable.
*/
typedef NS_ENUM(NSInteger, FxGripCompression) {
	FxGripCompressionNone	= 0,
	FxGripCompressionLZFSE	= 1,
	FxGripCompressionLZ4	= 2,
	FxGripCompressionZlib	= 3,
	FxGripCompressionLZMA	= 4,
	FxGripCompressionJPEG	= 5,
	FxGripCompressionHEIC	= 6,
	FxGripCompressionAVIF	= 7,
};

/*! Channels per pixel: 1 (Gray), 2 (GrayAlpha), 3 (RGB), 4 (RGBA); 0 when invalid. */
NSUInteger FxGripPixelFormatComponents(FxGripPixelFormat format);
/*! The component storage type; Invalid when the format is malformed. */
FxGripComponentType FxGripPixelFormatComponentType(FxGripPixelFormat format);
/*! Bytes per component: 1 (8U), 2 (16U/16F), 4 (32U/32F); 0 when invalid. */
NSUInteger FxGripPixelFormatBytesPerComponent(FxGripPixelFormat format);
/*! Bytes per pixel: channels times component size. */
NSUInteger FxGripPixelFormatBytesPerPixel(FxGripPixelFormat format);
/*! YES for the 2- and 4-channel formats, whose last channel is alpha. */
BOOL FxGripPixelFormatHasAlpha(FxGripPixelFormat format);
BOOL FxGripPixelFormatIsFloat(FxGripPixelFormat format);

/*! YES for the image codecs whose encode discards information (JPEG, HEIC, AVIF). */
BOOL FxGripCompressionIsLossy(FxGripCompression compression);

/*!
	@function   FxGripCompressionTypeIdentifier
	@abstract   The ImageIO type identifier a lossy codec encodes under.
	@discussion Introduced in FxGrip 0.1.0. Nil for the buffer codecs, which have no
				container type.
*/
NSString *_Nullable FxGripCompressionTypeIdentifier(FxGripCompression compression);

/*!
	@function   FxGripCompressionIsAvailable
	@abstract   Whether the running OS can encode with the codec.
	@discussion Introduced in FxGrip 0.1.0. The buffer codecs are always available; each
				lossy codec is answered individually by ImageIO's destination registry
				at run time (JPEG and HEIC on every supported OS, AVIF where the OS
				provides an encoder). An unavailable codec fails its encode and the
				buffer stores raw, so this is advisory for choosing a codec, not a
				required guard.
*/
BOOL FxGripCompressionIsAvailable(FxGripCompression compression);

/*!
	@function   FxGripCompressedData
	@abstract   Compresses data with a lossless codec.
	@discussion Introduced in FxGrip 0.1.0. Returns nil for FxGripCompressionNone, for a
				lossy or unknown codec (image codecs need image geometry and live on
				FxGripImageBuffer), and when the codec does not shrink the data; the
				caller keeps the original in those cases.
*/
NSData *_Nullable FxGripCompressedData(NSData *_Nonnull data, FxGripCompression compression);

/*!
	@function   FxGripDecompressedData
	@abstract   Decompresses data compressed by FxGripCompressedData.
	@discussion `uncompressedLength` is the exact original length; a mismatch returns nil.
				FxGripCompressionNone returns the data unchanged.
*/
NSData *_Nullable FxGripDecompressedData(NSData *_Nonnull data, FxGripCompression compression, NSUInteger uncompressedLength);

/*! The error domain for a malformed FxGrip compression envelope. */
extern NSString *_Nonnull const FxGripCompressionErrorDomain;

/*!
	@const      FxGripCompressionEnvelopeThresholdDefault
	@abstract   The default byte count below which FxGripEnvelopeCompressedData leaves data
				uncompressed.
	@discussion Introduced in FxGrip 0.1.0. A lossless codec's per-call cost outweighs its
				saving on a small payload, so data shorter than this passes through raw.
*/
extern const NSUInteger FxGripCompressionEnvelopeThresholdDefault;

/*!
	@function   FxGripEnvelopeCompressedData
	@abstract   Wraps data in a self-describing FxGrip compression envelope when a lossless
				codec shrinks it, and returns the data unchanged otherwise.
	@discussion Introduced in FxGrip 0.1.0. The envelope records the codec and the exact
				uncompressed length, so FxGripEnvelopeDecompressedData restores the original
				with no out-of-band metadata. Compression is attempted only when every
				condition holds:
				- `compression` is a lossless codec (LZFSE, LZ4, zlib, LZMA),
				- `data.length` is at least `minimumLength`,
				- the codec produces a strictly smaller payload.
				When any condition fails the original data is returned with no envelope. A
				consumer that never compresses stays byte-identical to its input, so an
				uncompressed payload matches a pre-envelope one on the wire.
*/
NSData *_Nonnull FxGripEnvelopeCompressedData(NSData *_Nonnull data, FxGripCompression compression, NSUInteger minimumLength);

/*!
	@function   FxGripEnvelopeDecompressedData
	@abstract   Restores data wrapped by FxGripEnvelopeCompressedData.
	@discussion Introduced in FxGrip 0.1.0. The envelope signature is detected in the leading
				bytes, and the recorded codec decompresses the payload. Data that lacks the
				signature is returned unchanged, so an uncompressed or pre-envelope payload
				passes through. A truncated or corrupt envelope returns nil and sets `error`
				in FxGripCompressionErrorDomain.
*/
NSData *_Nullable FxGripEnvelopeDecompressedData(NSData *_Nonnull data, NSError *_Nullable *_Nullable error);

#endif /* FxGripImageCompression_h */
