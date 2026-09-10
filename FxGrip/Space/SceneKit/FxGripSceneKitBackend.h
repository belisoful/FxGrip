/*!
	@file       FxGripSceneKitBackend.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripSceneKitBackend
	@abstract   The render-driver seam of the SceneKit engine.
	@discussion Introduced in FxGrip 0.1.0. This file declares the protocol a render driver adopts to draw
	            a SceneKit scene into an FxPlug tile's Metal texture. The seam keeps the driver swappable
	            and mockable in tests. Its RealityKit counterpart is `FxGripRealityKitBackend`, in the
	            Swift `FxGripRealityKit` framework.
*/

#ifndef FxGripSceneKitBackend_h
#define FxGripSceneKitBackend_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@protocol   FxGripSceneKitBackend
	@abstract   Renders a SceneKit scene into a Metal texture for the 3D Space subsystem.
	@discussion Introduced in FxGrip 0.1.0. The subsystem builds the scene with SceneKit and hands it,
				with a point-of-view node, to a backend that draws it into the destination tile's
				`MTLTexture`. The seam exists to keep the render engine swappable and mockable in
				tests; the shipped implementation is `FxGripSceneKitMetalBackend`. Drawing the scene
				is SceneKit's job, and connecting it to an FxPlug tile is the backend's.

				`atTime` is the render time in seconds, sampled for SceneKit animations and actions.
				The FxPlug host reports time as a `CMTime`; the effect converts it.
*/
@protocol FxGripSceneKitBackend <NSObject>

/*! YES when the backend can render. */
@property (nonatomic, readonly) BOOL isReady;

/*! A short stable identifier for the engine, for logging and selection. */
@property (nonatomic, readonly, copy) NSString *backendIdentifier;

/*! Renders `scene` through `pointOfView` into `texture` at `seconds`. Returns NO with an error on
	failure. */
- (BOOL)renderScene:(SCNScene *)scene
		pointOfView:(nullable SCNNode *)pointOfView
		  toTexture:(id<MTLTexture>)texture
			 atTime:(CFTimeInterval)seconds
			  error:(NSError * _Nullable *)error;

@optional

/*! Loads any resources once, off the render thread. Returns NO with an error on failure. */
- (BOOL)prepareWithError:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripSceneKitBackend_h */
