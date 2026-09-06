/*!
	@file       FxGripInstanceTracker.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInstanceTracker
	@abstract   The extension that tracks every live instance of a plugin by its UUID.
	@discussion Introduced in FxGrip 0.1.0. The extension keeps a process-wide registry of effect
	            instances keyed by plugin UUID. It records the effect when it is added to the
	            document and removes it when the effect is removed or deallocated. The registry holds
	            non-retaining pointer values, so a tracked effect is never kept alive. The registry
	            answers queries for the sibling instances and the timeline start times of the next
	            and previous instances.
*/

#ifndef FxGripInstanceTracker_h
#define FxGripInstanceTracker_h

#import "FxGripTypes.h"
#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"

/*! The plugin property key that opts an effect into instance tracking. */
#define kInstanceTrackerKey @"instanceTracker"


/*!
	@class		FxGripInstanceTracker
	@abstract	The extension that maintains the per-UUID registry of live plugin instances.
	@discussion	Introduced in FxGrip 0.1.0. The registry stores non-retaining pointers and is
				synchronized for concurrent access.
*/
@interface FxGripInstanceTracker : FxGripExtension

- (nullable id)init;

/*! The live sibling instances of this effect's plugin UUID, in registry order. */
@property (readonly, nonnull) NSArray<id<FxGripTileableEffect>> *instances;

/*! Adds the effect to the registry under its plugin UUID. */
- (void)extAddedToDocument:(nonnull NSNotification*)notification;
/*! Removes the effect from the registry. */
- (void)extRemovedFromDocument:(nonnull NSNotification*)notification;

/*! The nearest later timeline start time among sibling instances, or kCMTimeInvalid when none. */
- (CMTime)startTimeOfNextEffect:(id<FxGripTileableEffect> _Nonnull)effect;
/*! The nearest earlier timeline start time among sibling instances, or kCMTimeInvalid when none. */
- (CMTime)startTimeOfPreviousEffect:(id<FxGripTileableEffect> _Nonnull)effect;

@end




/*!
	@abstract	The effect-side accessors for the instance tracker extension.
	@discussion	Introduced in FxGrip 0.1.0. isTrackingInstances reads the plugin property that gates
				the extension.
*/
@interface FxGripTileableEffect (InstanceTracker)

/*! Creates the instance tracker extension instance for the loader to install. */
- (nullable FxGripInstanceTracker*)newFxInstanceTracker;

/*! YES when the plugin opts into instance tracking via its plugin property. */
@property (readonly) BOOL isTrackingInstances;
/*! The installed instance tracker extension, or nil when none is installed. */
@property (readonly, nullable, nonatomic) FxGripInstanceTracker *instanceTracker;

/*! The live sibling instances of this effect's plugin UUID. */
// Cast arr[i].pointerValue into id<FxTileableEffect> or FxGripTileableEffect to retrieve the effect object.
@property (readonly) NSArray<id<FxGripTileableEffect>>*_Nonnull instances;

/*! The number of live instances of this effect's plugin UUID. */
- (NSUInteger)instanceCount;
/*! The instance at an index in the registry, or nil when the index is out of range. */
- (nullable id<FxGripTileableEffect>)instanceAtIndex:(int)index;


@end

#endif
