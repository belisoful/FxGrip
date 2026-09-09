/*!
	@file       FxGripPhysicsBake.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPhysicsBake
	@abstract   The extension that persists a deterministic physics simulation with the document.
	@discussion Introduced in FxGrip 0.1.0. This file declares the custom-parameter extension that stores
	            per-frame body transforms and the effect-side category that loads and reads it. The
	            bake backs the physics backend's simulation store, so the simulation fills lazily as
	            frames render and survives a document reopen.
*/

#ifndef FxGripPhysicsBake_h
#define FxGripPhysicsBake_h

#import "FxGripCustomExtension.h"
#import "FxGripFrameData.h"
#import "FxGripTileableEffect.h"

/*!
	@class      FxGripPhysicsBake
	@abstract   The extension that persists a physics simulation's per-frame body transforms with the
				document.
	@discussion Introduced in FxGrip 0.1.0. Registers the hidden Physics Bake custom parameter
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


/*!
	@abstract	The effect-side accessors that read and create the physics-bake extension.
	@discussion	Introduced in FxGrip 0.1.0. The accessors resolve the loaded extension and its frame data;
				a space effect creates the extension in loadExtensions.
*/
@interface FxGripTileableEffect (PhysicsBake)

/*! The frame data of the loaded FxGripPhysicsBake extension; nil when it is not loaded. */
@property (readonly, nullable, nonatomic) FxGripFrameData *physicsBakeData;

/*! YES when the FxGripPhysicsBake extension is loaded. */
@property (readonly, nonatomic) BOOL hasPhysicsBake;

/*!
	@method		newPhysicsBakeExtension
	@abstract	Creates the physics-bake extension instance for loadExtensions to install.
	@return		A new extension instance.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides this to supply a custom subclass. */
- (nonnull FxGripPhysicsBake *)newPhysicsBakeExtension;

@end

#endif /* FxGripPhysicsBake_h */
