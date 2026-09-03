//
//  FxGripSceneKitMetalBackend.h
//  FxGrip
//

#ifndef FxGripSceneKitMetalBackend_h
#define FxGripSceneKitMetalBackend_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "FxGripSpaceBackend.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripSceneKitMetalBackend
	@abstract   The shipped `FxGripSpaceBackend`: a Metal `SCNRenderer` driving a scene into a tile
				texture.
	@discussion Introduced in FxGrip 1.0. Holds one `SCNRenderer` per Metal device, builds a render
				pass whose color attachment is the destination texture and whose depth attachment
				comes from the FxGrip device cache, draws the scene synchronously through a cached
				command queue, and waits for completion. The command queue and depth texture are
				obtained from `FxGripMTLDeviceCache`, matching the device that owns the destination
				texture.
*/
@interface FxGripSceneKitMetalBackend : NSObject <FxGripSpaceBackend>

/*! A new backend. */
+ (instancetype)backend;

/*! The color the render pass clears to before drawing. Defaults to transparent black. */
@property (nonatomic, assign) MTLClearColor clearColor;

/*!
	@method     advanceSimulationForScene:renderer:toTime:
	@abstract   A subclass hook to advance a stateful simulation on the scene before it is drawn.
	@discussion The default does nothing. SceneKit steps physics and particles only through
				`updateAtTime:`, and the Metal render path does not call it, so a subclass overrides
				this to drive `renderer` up to `seconds` before the draw. FxGrip calls it with the
				render's borrowed renderer, after the scene and point of view are set, on the
				per-render scene, so the stepping is isolated to this render.
*/
- (void)advanceSimulationForScene:(SCNScene *)scene
						renderer:(SCNRenderer *)renderer
						  toTime:(CFTimeInterval)seconds;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripSceneKitMetalBackend_h */
