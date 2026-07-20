//
//  FxGripToggle.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripInstanceTracker_h
#define FxGripInstanceTracker_h

#import <FxGripTypes.h>
#import <FxExtension.h>
#import <FxTileableEffectBase.h>

#define kInstanceTrackerKey @"instanceTracker"


@interface FxGripInstanceTracker : FxExtension

- (nullable id)init;
- (void)dealloc;

@property (readonly, nonnull) NSArray<id<FxTileableEffectBase>> *instances;

- (void)extAddedToDocument:(nonnull NSNotification*)notification;
- (void)extRemovedFromDocument:(nonnull NSNotification*)notification;

- (CMTime)startTimeOfNextEffect:(id<FxTileableEffectBase> _Nonnull)effect;
- (CMTime)startTimeOfPreviousEffect:(id<FxTileableEffectBase> _Nonnull)effect;

@end




@interface FxTileableEffectBase (InstanceTracker)

- (nullable FxGripInstanceTracker*)newFxInstanceTracker;

@property (readonly) BOOL isTrackingInstances;
@property (readonly, nullable, nonatomic) FxGripInstanceTracker *instanceTracker;

// Cast arr[i].pointerValue into id<FxTileableEffect> or GuruFxTileableEffect to retreive the effect object.
@property (readonly) NSArray<id<FxTileableEffectBase>>*_Nonnull instances;

- (NSUInteger)instanceCount;
- (nullable id<FxTileableEffectBase>)instanceAtIndex:(int)index;


@end

#endif
