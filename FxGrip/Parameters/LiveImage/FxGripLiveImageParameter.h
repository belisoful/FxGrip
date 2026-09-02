//
//  FxGripLiveImageParameter.h
//  FxGrip
//

#ifndef FxGripLiveImageParameter_h
#define FxGripLiveImageParameter_h

#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripCustomParameter.h"
#import "FxGripCustomViewDataDelegate.h"
#import "FxGripLiveFrame.h"

@class FxGripImageBuffer;

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripLiveImageView
	@abstract   The slot strip backing a live image parameter.
	@discussion Introduced in FxGrip 1.0. The view draws one slot per configured label
				across the inspector width. Each slot shows its latest FxGripLiveFrame
				aspect-fit over a checkerboard, with a caption carrying the slot label and,
				when enabled, the frame's dimensions and pixel format. An empty slot draws
				the caption alone. updateFromCustomData: applies the configuration; the
				pixels arrive through showFrame:inSlot: on the main thread.
*/
@interface FxGripLiveImageView : NSView <FxGripCustomViewDataDelegate>

@property (readonly) NSUInteger slotCount;

/*! Replaces the frame shown in a slot and redraws it; nil empties the slot. Main thread. */
- (void)showFrame:(nullable FxGripLiveFrame *)frame inSlot:(NSUInteger)slot;
- (nullable FxGripLiveFrame *)frameInSlot:(NSUInteger)slot;
- (nullable NSString *)labelInSlot:(NSUInteger)slot;

@end

/*!
	@class      FxGripLiveImageParameter
	@abstract   A read-only strip of live images fed from the render pass.
	@discussion Introduced in FxGrip 1.0. The FxPlug host runs the render pass and the
				custom parameter views in the same plugin process, so an image the effect
				holds at render can reach the inspector without a round trip through the
				host's parameter store. The parameter's value is an FxGripDictionary
				carrying only the configuration (the slot labels, row height, info caption,
				checkerboard, vertical flip, and snapshot size from `FxGripLiveImage.h`);
				the pixels stay in memory and never enter the host document. Creation adds
				the custom-UI, not-animatable, full-view-width, and no-state flags.

				Publishing is gated on the inspector. A publish is suppressed, storing
				nothing and returning NO, while no parameter view is on screen. The FxPlug
				host puts a parameter view on screen only for the interactive timeline
				render in the inspector's process; a batch export or a background render
				runs with no inspector and never puts a view on screen, so the strip shows
				the timeline play point and not an off-screen render.

				The effect publishes from any thread. A Metal texture is copied on the GPU
				into a CPU-readable staging texture, downscaled through its mipmap chain
				until its longest side is at most snapshotSize, and read back when the
				command buffer completes; the publish call returns before the copy runs.
				A slot whose previous copy is still in flight drops the new texture. A
				frame, CGImage, or image buffer is stored as given. Every path stores the
				latest frame per slot and coalesces the redraw onto the main thread, so a
				view attached while another is on screen shows the last frame.

				The runtime instance is the effect's parameter for the ID
				(`effect[parameterID]`). The slot count is fixed by the declared
				configuration.
*/
@interface FxGripLiveImageParameter : FxGripCustomParameter

@property (readonly) NSUInteger slotCount;

/*! The longest side, in pixels, of the snapshot read back from a published texture; 0
	reads the texture at full size. Seeded from the configuration's snapshot-size key. */
@property (assign) NSUInteger snapshotSize;

/*!
	@method     publishTexture:inSlot:
	@abstract   Copies a texture into a slot's snapshot asynchronously.
	@discussion Returns NO with no view on screen, for an out-of-range slot, a non-2D
				texture, an unsupported pixel format (see FxGripLiveFrame), or a slot
				still reading back its previous texture. The command buffer retains the
				texture until the copy completes.
*/
- (BOOL)publishTexture:(id<MTLTexture>)texture inSlot:(NSUInteger)slot;

/*!
	@method     publishTextures:
	@abstract   Copies several textures in one command buffer, array index to slot index.
	@discussion An NSNull entry skips its slot. Every texture must belong to the same
				device. Returns NO with no view on screen, else YES when at least one
				slot was encoded.
*/
- (BOOL)publishTextures:(NSArray *)textures;

/*! Publishes the tile's Metal texture through publishTexture:inSlot:. */
- (BOOL)publishImageTile:(FxImageTile *)tile inSlot:(NSUInteger)slot;

/*! Stores a ready frame in a slot. Returns NO with no view on screen, for an out-of-range
	slot, or for a nil frame. */
- (BOOL)publishFrame:(FxGripLiveFrame *)frame inSlot:(NSUInteger)slot;

/*! Draws the image into an RGBA8 frame and stores it. */
- (BOOL)publishCGImage:(CGImageRef)image inSlot:(NSUInteger)slot;

/*! Wraps the buffer's pixels in a frame and stores it. */
- (BOOL)publishImageBuffer:(FxGripImageBuffer *)buffer inSlot:(NSUInteger)slot;

- (void)clearSlot:(NSUInteger)slot;
- (void)clearAllSlots;

/*! The latest frame stored for a slot; nil when empty or out of range. */
- (nullable FxGripLiveFrame *)frameInSlot:(NSUInteger)slot;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripLiveImageParameter_h */
