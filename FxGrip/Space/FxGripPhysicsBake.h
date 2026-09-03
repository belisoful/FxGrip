//
//  FxGripPhysicsBake.h
//  FxGrip
//

#ifndef FxGripPhysicsBake_h
#define FxGripPhysicsBake_h

#import "FxGripCustomExtension.h"
#import "FxGripFrameData.h"
#import "FxGripTileableEffect.h"

/*!
	@class      FxGripPhysicsBake
	@abstract   The extension that persists a physics simulation's per-frame body transforms with the
				document.
	@discussion Introduced in FxGrip 1.0. Registers the hidden Physics Bake custom parameter
				(`kFxParameterId_PhysicsBake`) whose value is an `FxGripFrameData`, loads it from the
				document when the effect is added, and installs an `FxGripFrameData`-backed store on
				the effect's `FxGripSceneKitPhysicsBackend` in session-cache mode. The catch-up
				simulation then fills the store lazily as frames render, and the bake survives a
				reopen. The records are small (a body transform per dynamic body per frame), so they
				stay inline in the parameter with no media-folder spill.

				A space effect opts in by adding this extension in `loadExtensions`
				(`newPhysicsBakeExtension`). Without it, a physics backend uses its default in-memory
				session cache, which does not persist.
*/
@interface FxGripPhysicsBake : FxGripCustomExtension

/*! The per-frame bake store; created on demand, never nil once accessed. */
@property (readonly, nonatomic, nonnull) FxGripFrameData *frameData;

@end


@interface FxGripTileableEffect (PhysicsBake)

/*! The frame data of the loaded FxGripPhysicsBake extension; nil when it is not loaded. */
@property (readonly, nullable, nonatomic) FxGripFrameData *physicsBakeData;

/*! YES when the FxGripPhysicsBake extension is loaded. */
@property (readonly, nonatomic) BOOL hasPhysicsBake;

- (nonnull FxGripPhysicsBake *)newPhysicsBakeExtension;

@end

#endif /* FxGripPhysicsBake_h */
