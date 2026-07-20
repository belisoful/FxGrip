//
//  FxGripExtension.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripInstanceTracker.h"
#import "FxTileableEffectBase.h"
#import "FxTileableEffectBase+Extensions.h"
#import "FxTileableEffectBase+Timing.h"
#import "FxGripOOBParameterAccess.h"
#import "FxGrip_ARC.h"

static NSMutableDictionary<NSString*, NSMutableArray<NSValue*>*>    *gEffectInstances  = nil;



@implementation FxGripInstanceTracker

static dispatch_once_t gInstanceTrackerOnce = 0;

- (nullable id)init
{
	self = [super init];
	if (self) {
		dispatch_once(&gInstanceTrackerOnce, ^{
			gEffectInstances = [NSMutableDictionary.alloc init];
		});
	}
	return self;
}


-(void) dealloc
{
	@synchronized (gEffectInstances) {
		if (!gEffectInstances.count) {
			gEffectInstances = nil;
			gInstanceTrackerOnce = 0;
		}
	}
	
	SUPER_DEALLOC();
}


#pragma mark -
#pragma mark Instance Tracking and Management

// Do NOT keep this array. It is for temporary purposes only because it links all the plugin instances
//	and would cause circular references in garbage collection.
- (NSArray<id<FxTileableEffectBase>> *)instances
{
	if (!gEffectInstances[self.effect.pluginUUID]) {
		return @[];
	}
	NSMutableArray *instances = [NSMutableArray.alloc initWithCapacity:gEffectInstances[self.effect.pluginUUID].count];
	
	for (NSValue* pluginValue in gEffectInstances[self.effect.pluginUUID])
	{
		id<FxTileableEffectBase> plugin  = (id<FxTileableEffectBase>)[pluginValue pointerValue];
		[instances addObject:plugin];
	}
	
	return instances.copy;
}

// Called in FxTileableEffect::init
- (void)extAddedToDocument:(nonnull NSNotification*)notification;
{
	id<FxTileableEffectBase> effect = notification.object;
	if (![effect isKindOfClass:FxTileableEffectBase.class]) {
		return;
	}
	@synchronized (gEffectInstances) {
		if (!gEffectInstances[effect.pluginUUID]) {
			gEffectInstances[effect.pluginUUID] = [NSMutableArray.alloc init];
		}
		
		// We don't want to retain the effect, so we make a pointer value out of it.
		NSValue *instancePtr = [NSValue valueWithPointer:(void*)effect];
		if (![gEffectInstances[effect.pluginUUID]  containsObject:instancePtr]) {
			[gEffectInstances[effect.pluginUUID]  addObject:instancePtr];
		}
	}
}

// Called in FxTileableEffect::dealloc - instanceRemovedFromDocument
- (void)extRemovedFromDocument:(nonnull NSNotification*)notification;
{
	FxTileableEffectBase *effect = notification.object;
	if (![effect isKindOfClass:FxTileableEffectBase.class]) {
		return;
	}
	@synchronized (gEffectInstances) {
		if (!gEffectInstances[effect.pluginUUID]) {
			return;
		}
		
		// We don't want to retain the effect, so we make a pointer value out of it.
		NSValue *instancePtr = [NSValue valueWithPointer:(void*)effect];
		if ([gEffectInstances[effect.pluginUUID] containsObject:instancePtr]) {
			[gEffectInstances[effect.pluginUUID] removeObject:instancePtr];
		}
		if (!gEffectInstances[effect.pluginUUID].count) {
			[gEffectInstances removeObjectForKey:effect.pluginUUID];
		}
	}
}


- (CMTime)startTimeOfNextEffect:(id<FxTileableEffectBase>)effect;
{
	CMTime  timelineEffectTime  = effect.effectStartTimeInTimeline;
	CMTime  startTime   = kCMTimeInvalid;
	
	if (!gEffectInstances[effect.pluginUUID]) {
		return startTime;
	}
	
	@synchronized (gEffectInstances) {
		CMTime  nextTimelineTime    = kCMTimePositiveInfinity;
		for (NSValue* pluginValue in gEffectInstances[effect.pluginUUID])
		{
			id<FxTileableEffectBase> plugin  = (id<FxTileableEffectBase>)[pluginValue pointerValue];
			if (plugin != effect)
			{
				FxGripOOBParameterAccess *__attribute__((unused)) accessor = [plugin startContext];
					
				CMTime  pluginTimelineTime  = plugin.effectStartTimeInTimeline;
				if (CMTimeCompare(timelineEffectTime, pluginTimelineTime) < 0) {
					if (CMTimeCompare(pluginTimelineTime, nextTimelineTime) < 0) {
						nextTimelineTime = pluginTimelineTime;
					}
				}
			}
		}
		
		startTime = nextTimelineTime;
	}
	
	return startTime;
}

- (CMTime)startTimeOfPreviousEffect:(id<FxTileableEffectBase>)effect;
{
	CMTime  timelineEffectTime  = effect.effectStartTimeInTimeline;
	CMTime  startTime   = kCMTimeInvalid;
	
	@synchronized (gEffectInstances) {
		CMTime  prevTimelineTime    = kCMTimeNegativeInfinity;
		for (NSValue* pluginValue in gEffectInstances[effect.pluginUUID])
		{
			id<FxTileableEffectBase> plugin = (id<FxTileableEffectBase>)[pluginValue pointerValue];
			if (plugin != effect)
			{
				FxGripOOBParameterAccess *__attribute__((unused)) accessor = [plugin startContext];
					
				CMTime  pluginTimelineTime  = plugin.effectStartTimeInTimeline;
				if (CMTimeCompare(timelineEffectTime, pluginTimelineTime) > 0) {
					if (CMTimeCompare(pluginTimelineTime, prevTimelineTime) > 0) {
						prevTimelineTime = pluginTimelineTime;
					}
				}
			}
		}
		startTime = prevTimelineTime;
	}
	
	return startTime;
}

@end




#pragma mark -
#pragma mark FxTileableEffectBase (InstanceTracker)

@implementation FxTileableEffectBase (InstanceTracker)

- (nullable FxGripInstanceTracker*)newFxInstanceTracker
{
	return [FxGripInstanceTracker.alloc init];
}

- (BOOL)isTrackingInstances
{
	return NO;
}

- (FxGripInstanceTracker*_Nullable)instanceTracker
{
	return [self extensionForClass:FxGripInstanceTracker.class];
}


- (nonnull NSArray<id<FxTileableEffectBase>>*)instances
{
	return self.instanceTracker.instances;
}

- (NSUInteger)instanceCount
{
	if (!gEffectInstances[self.pluginUUID])
		return 0;
	return gEffectInstances[self.pluginUUID].count;
}


- (nullable id<FxTileableEffectBase>)instanceAtIndex:(int)index
{
	if (!gEffectInstances[self.pluginUUID])
		return NULL;
	return gEffectInstances[self.pluginUUID][index].pointerValue;
}

@end
