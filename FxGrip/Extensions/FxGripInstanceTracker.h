//
//  FxGripInstanceTracker.h
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripInstanceTracker_h
#define FxGripInstanceTracker_h

#import "FxGripTypes.h"
#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"

#define kInstanceTrackerKey @"instanceTracker"


@interface FxGripInstanceTracker : FxGripExtension

- (nullable id)init;

@property (readonly, nonnull) NSArray<id<FxGripTileableEffect>> *instances;

- (void)extAddedToDocument:(nonnull NSNotification*)notification;
- (void)extRemovedFromDocument:(nonnull NSNotification*)notification;

- (CMTime)startTimeOfNextEffect:(id<FxGripTileableEffect> _Nonnull)effect;
- (CMTime)startTimeOfPreviousEffect:(id<FxGripTileableEffect> _Nonnull)effect;

@end




@interface FxGripTileableEffect (InstanceTracker)

- (nullable FxGripInstanceTracker*)newFxInstanceTracker;

@property (readonly) BOOL isTrackingInstances;
@property (readonly, nullable, nonatomic) FxGripInstanceTracker *instanceTracker;

// Cast arr[i].pointerValue into id<FxTileableEffect> or FxGripTileableEffect to retrieve the effect object.
@property (readonly) NSArray<id<FxGripTileableEffect>>*_Nonnull instances;

- (NSUInteger)instanceCount;
- (nullable id<FxGripTileableEffect>)instanceAtIndex:(int)index;


@end

#endif
