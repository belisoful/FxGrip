/*!
	@file       FxGripOSCMetalTestSupport.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripOSCMetalTestSupport
	@abstract   A live Metal render pass and destination tile for exercising the on-screen control draw kit.
	@discussion Introduced in FxGrip 0.1.0. The on-screen control parts draw through a real
	            id<MTLRenderCommandEncoder>, so a unit test needs a device, a destination tile backed by
	            an IOSurface, a pipeline built from the framework's own shader library, and a live
	            encoder. FxGripOSCMetalTestPass supplies all four, and reads the rendered pixels back
	            after the pass finishes so a test asserts on what was drawn. FxGripOSCBlockDrawPart is a
	            part whose draw, hit-test, and drag hooks run caller-supplied blocks, for driving the
	            control's own drawing scaffold and counting the calls it makes.
*/

#ifndef FxGripOSCMetalTestSupport_h
#define FxGripOSCMetalTestSupport_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <simd/simd.h>
#import <FxGrip/FxGripOnScreenControl.h>
#import <FxGrip/FxGripOSCPart.h>

@class FxImageTile;

NS_ASSUME_NONNULL_BEGIN

/*! The control's private shader-library accessor, exposed for caching assertions. */
@interface FxGripOnScreenControl (FxGripOSCMetalTesting)
- (nullable id<MTLLibrary>)fxOSCLibraryForDevice:(nullable id<MTLDevice>)device;
@end

/*!
	@class      FxGripOSCMetalTestPass
	@abstract   A live render pass into an IOSurface-backed tile, with pixel read-back.
	@discussion Introduced in FxGrip 0.1.0. `passWithCanvasSize:` returns nil when the machine has no
				Metal device or the framework's shader library will not load, so a test skips rather
				than fails. The encoder is open on return with the flat-color pipeline and a full-canvas
				viewport bound. Call `finish` once, then read pixels with `colorAtCanvasPoint:`.
*/
@interface FxGripOSCMetalTestPass : NSObject

/*! The system default Metal device, or nil when the machine has none. */
+ (nullable id<MTLDevice>)sharedDevice;

/*! A pass over a canvas of the given size, or nil when Metal is unavailable. */
+ (nullable instancetype)passWithCanvasSize:(CGSize)canvasSize;

/*! A destination tile sized to the canvas and backed by a fresh IOSurface, for the control's own
	drawing scaffold; nil when Metal is unavailable. */
+ (nullable FxImageTile *)destinationTileWithCanvasSize:(CGSize)canvasSize;

/*! The color at a canvas point of a texture the OSC pipeline rendered, as straight RGBA in 0...1. */
+ (simd_float4)colorInTexture:(id<MTLTexture>)texture atCanvasPoint:(CGPoint)canvasPoint;

/*! The device the pass renders on. */
@property (nonatomic, readonly) id<MTLDevice> device;

/*! The destination tile, sized to the canvas and backed by an IOSurface. */
@property (nonatomic, readonly) FxImageTile *tile;

/*! The tile's Metal texture, the pass's color attachment. */
@property (nonatomic, readonly) id<MTLTexture> texture;

/*! The framework's OSC shader library on this device. */
@property (nonatomic, readonly) id<MTLLibrary> library;

/*! The open encoder, with the flat-color pipeline and full-canvas viewport bound. */
@property (nonatomic, readonly) id<MTLRenderCommandEncoder> commandEncoder;

/*! The canvas size the pass was created with. */
@property (nonatomic, readonly) CGSize canvasSize;

/*! Ends the encoding, commits, and waits for the GPU. Repeated calls do nothing. */
- (void)finish;

/*! The rendered color at a canvas point, as straight RGBA in 0...1. Valid after `finish`. */
- (simd_float4)colorAtCanvasPoint:(CGPoint)canvasPoint;

@end

/*!
	@class      FxGripOSCBlockDrawPart
	@abstract   A part whose hooks run caller-supplied blocks and count their calls.
	@discussion Introduced in FxGrip 0.1.0. Used to drive the control's drawing scaffold with known
				geometry, and to count how often the scaffold asks a part to draw.
*/
@interface FxGripOSCBlockDrawPart : FxGripOSCPart

/*! Runs in place of drawSelected:; the part, the selected flag, the canvas size, and the encoder. */
@property (nonatomic, copy, nullable) void (^drawBlock)(FxGripOSCBlockDrawPart *part,
													    BOOL selected,
													    CGSize canvasSize,
													    id<MTLRenderCommandEncoder> commandEncoder);

/*! The number of drawSelected: calls the part has received. */
@property (nonatomic, readonly) NSUInteger drawCount;

/*! The number of drawSelected: calls that arrived with selected set. */
@property (nonatomic, readonly) NSUInteger selectedDrawCount;

/*! The canvas size of the most recent drawSelected: call. */
@property (nonatomic, readonly) CGSize lastCanvasSize;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripOSCMetalTestSupport_h */
