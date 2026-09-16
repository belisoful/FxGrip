/*!
	@file       FxPlugStub.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxPlugStub
	@abstract   Test-only stand-ins for the FxPlug classes FxGrip references directly.
	@discussion Introduced in FxGrip 0.1.0. Apple's FxPlug SDK ships headers and a text stub
	            with no binary, so FxImageTile, FxImageTileRequest, and FxMatrix44 never exist in
	            the unit-test process and FxGrip's categories on them are discarded at load time.
	            FxTaggedMenuEntry is stubbed as well, for the tagged popup menu paths.
	            The FxPlugStub target builds a framework whose product is named FxPlug with the
	            SDK's install name and dylib versions. The test bundles embed it, dyld satisfies
	            FxGrip's weak class imports from it, and the categories attach.

	            Each class implements the interface Apple declares in the SDK header and nothing
	            is redeclared, so SDK drift surfaces as a compile error. The class extensions
	            below open the readonly properties for writing and add construction helpers.
	            The framework is embedded only in test bundles and never ships.
*/

#ifndef FxPlugStub_h
#define FxPlugStub_h

#define GL_SILENCE_DEPRECATION 1

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Metal/Metal.h>
#import <IOSurface/IOSurfaceObjC.h>
#import <FxPlug/FxTypes.h>
#import <FxPlug/FxMatrix.h>
#import <FxPlug/FxImageTileRequest.h>
#import <FxPlug/FxImageTile.h>
#import <FxPlug/FxParameterAPI.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@abstract	Test controls for the FxMatrix44 stand-in.
	@discussion	Introduced in FxGrip 0.1.0. The matrix is row-major with row-vector math:
				a point transforms as p' = p · M, so translation occupies row 3. This matches
				Apple's FxShape sample, which adds the image origin to elements [3][0] and [3][1].
*/
@interface FxMatrix44 () <NSCopying>

/*! @abstract A uniform scale about the origin. */
+ (instancetype)stubMatrixWithScale:(double)scale;

/*! @abstract A non-uniform scale followed by a translation. */
+ (instancetype)stubMatrixWithScaleX:(double)scaleX
							  scaleY:(double)scaleY
						translationX:(double)translationX
						translationY:(double)translationY;

/*! @abstract YES when every element matches exactly. */
- (BOOL)isEqualToMatrix:(FxMatrix44 *)other;

@end

/*!
	@abstract	Test controls for the FxImageTileRequest stand-in.
	@discussion	Introduced in FxGrip 0.1.0. Every property the SDK declares readonly is writable.
*/
@interface FxImageTileRequest ()
@property (readwrite, nonatomic) FxImageTileRequestSource source;
@property (readwrite, nonatomic) CMTime requestTime;
@property (readwrite, nonatomic) BOOL includeLeadingFilters;
@property (readwrite, nonatomic) UInt32 parameterID;
@end

/*!
	@abstract	Test controls for the FxImageTile stand-in.
	@discussion	Introduced in FxGrip 0.1.0. Every property the SDK declares readonly is writable.
				metalTextureForDevice: answers, in order: the stubTextureProvider block, the
				stubTexture property, then a texture wrapping the ioSurface on the requested
				device, cached per device. It returns nil when none applies. The added members
				carry a stub prefix because FxGrip's FxImageTile categories define device,
				metalTexture, and pixelFormat, and a category method replaces a same-named
				class method.
*/
@interface FxImageTile ()

@property (readwrite, nonatomic) FxRect tilePixelBounds;
@property (readwrite, nonatomic) FxRect imagePixelBounds;
@property (readwrite, nonatomic, copy, nullable) FxMatrix44 *pixelTransform;
@property (readwrite, nonatomic, copy, nullable) FxMatrix44 *inversePixelTransform;
@property (readwrite, nonatomic, strong, nullable) IOSurface *ioSurface;
@property (readwrite, nonatomic) uint64_t deviceRegistryID;
@property (readwrite, nonatomic) FxField field;
@property (readwrite, nonatomic) FxFieldOrder fieldOrder;
@property (readwrite, nonatomic) FxImageOrigin imageOrigin;
@property (readwrite, nonatomic) FxEyeType eyeType;
@property (readwrite, nonatomic) FxImageTileRequestSource imageSource;
@property (readwrite, nonatomic) UInt32 parameterID;
@property (readwrite, nonatomic) CMTime mediaTime;
@property (readwrite, nonatomic, copy, nullable) NSError *requestError;
@property (readwrite, nonatomic, nullable) CGColorSpaceRef colorSpace;

/*! @abstract Texture returned by metalTextureForDevice: for every device, when set. */
@property (readwrite, nonatomic, strong, nullable) id<MTLTexture> stubTexture;

/*! @abstract Block consulted first by metalTextureForDevice:, when set. */
@property (readwrite, nonatomic, copy, nullable) id<MTLTexture> _Nullable (^stubTextureProvider)(id<MTLDevice> device);

/*! @abstract Every device passed to metalTextureForDevice:, in call order. */
@property (readonly, nonatomic) NSArray<id<MTLDevice>> *stubRequestedDevices;

/*!
	@abstract	The designated initializer: bounds with identity transforms and no surface.
	@param		imageBounds	The full image's pixel bounds.
	@param		tileBounds	This tile's pixel bounds within the image.
*/
- (instancetype)initWithImagePixelBounds:(FxRect)imageBounds
						 tilePixelBounds:(FxRect)tileBounds NS_DESIGNATED_INITIALIZER;

/*! @abstract A tile whose image and tile bounds coincide, with identity transforms and no surface. */
+ (instancetype)stubTileWithPixelBounds:(FxRect)bounds;

/*!
	@abstract	A tile backed by a fresh IOSurface sized to its bounds.
	@param		bounds				The image and tile pixel bounds.
	@param		ioSurfacePixelFormat	A CoreVideo pixel format: kCVPixelFormatType_32BGRA,
									kCVPixelFormatType_32RGBA, kCVPixelFormatType_64RGBALE,
									kCVPixelFormatType_64RGBAHalf, or kCVPixelFormatType_128RGBAFloat.
	@param		device				Sets deviceRegistryID when non-nil.
	@return		The tile, or nil when the bounds are empty or the format is unknown.
*/
+ (nullable instancetype)stubTileWithPixelBounds:(FxRect)bounds
									 pixelFormat:(OSType)ioSurfacePixelFormat
										  device:(nullable id<MTLDevice>)device;

/*! @abstract The Metal pixel format matching an IOSurface pixel format, or MTLPixelFormatInvalid. */
+ (MTLPixelFormat)stubMetalPixelFormatForIOSurfaceFormat:(OSType)ioSurfacePixelFormat;

@end

NS_ASSUME_NONNULL_END

#endif /* FxPlugStub_h */
