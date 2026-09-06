/*!
	@file       FxGripInstanceTracker.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInstanceTracker
	@abstract   Implements the per-UUID registry of live plugin instances.
	@discussion Introduced in FxGrip 0.1.0. A process-wide dictionary maps a plugin UUID to an array of
	            non-retaining pointer values. Registry mutations are synchronized. Each extension
	            captures its effect's identity when added, so the dealloc sweep can remove the entry
	            after the weak effect reference and the teardown notification are gone.
*/

#import "FxGripInstanceTracker.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Extensions.h"
#import "FxGripTileableEffect+Timing.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripOOBParameterAccess.h"
#import "FxGrip_ARC.h"

static NSMutableDictionary<NSString*, NSMutableArray<NSValue*>*>    *gEffectInstances  = nil;



/*!
	@abstract	The extension that maintains the per-UUID registry of live plugin instances.
	@discussion	Introduced in FxGrip 0.1.0. The registry holds non-retaining pointers and answers
				sibling and timeline-neighbor queries.
*/
@implementation FxGripInstanceTracker
{
	// Identity captured when the effect is added, so the registry entry can be removed
	// in dealloc: self.effect is weak and reads nil by then, and the teardown
	// notification never arrives (the center's object filter is nil mid-dealloc).
	NSString *_trackedInstanceUUID;
	void *_trackedInstancePointer;
}

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

/*! Removes an effect pointer from the registry under its UUID, pruning an emptied
	bucket. Idempotent, so the dealloc sweep and an explicit removal never conflict. */
static void FxGripInstanceTrackerRemove(NSString *uuid, void *pointer)
{
	if (uuid == nil || pointer == NULL) {
		return;
	}
	@synchronized (gEffectInstances) {
		NSMutableArray<NSValue*> *bucket = gEffectInstances[uuid];
		if (bucket == nil) {
			return;
		}
		[bucket removeObject:[NSValue valueWithPointer:pointer]];
		if (bucket.count == 0) {
			[gEffectInstances removeObjectForKey:uuid];
		}
	}
}

- (void)dealloc
{
	FxGripInstanceTrackerRemove(_trackedInstanceUUID, _trackedInstancePointer);
	NARC_RELEASE(_trackedInstanceUUID);
	SUPER_DEALLOC();
}


#pragma mark -
#pragma mark Instance Tracking and Management

/*!
	@method		instances
	@abstract	The live sibling instances of this effect's plugin UUID.
	@discussion	Introduced in FxGrip 0.1.0. Do not retain the result. It links every plugin instance
				and would form a retain cycle. */
// Do NOT keep this array. It is for temporary purposes only because it links all the plugin instances
//	and would cause circular references in garbage collection.
- (NSArray<id<FxGripTileableEffect>> *)instances
{
	NSString *uuid = self.effect.pluginUUID;
	if (uuid == nil) {
		return @[];
	}
	NSMutableArray *instances = NSMutableArray.new;
	@synchronized (gEffectInstances) {
		for (NSValue* pluginValue in gEffectInstances[uuid])
		{
			id<FxGripTileableEffect> plugin  = (id<FxGripTileableEffect>)[pluginValue pointerValue];
			[instances addObject:plugin];
		}
	}
	return instances.copy;
}

/*!
	@method		extAddedToDocument:
	@abstract	Registers the effect under its plugin UUID and captures its identity for dealloc.
	@discussion	Introduced in FxGrip 0.1.0. Returns when the effect is not an FxGripTileableEffect or
				its UUID is nil, because a nil key cannot address the registry. */
// Called in FxTileableEffect::init
- (void)extAddedToDocument:(nonnull NSNotification*)notification;
{
	id<FxGripTileableEffect> effect = notification.object;
	if (![effect isKindOfClass:FxGripTileableEffect.class]) {
		return;
	}
	// A nil UUID cannot key the registry; the setter below would raise on a nil key. The
	// instances getter guards the same case.
	if (effect.pluginUUID == nil) {
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

	// Capture identity for the dealloc-time removal (self.effect is weak and the
	// teardown notification will not arrive).
	NARC_RELEASE(_trackedInstanceUUID);
	_trackedInstanceUUID = NARC_RETAIN([effect.pluginUUID copy]);
	_trackedInstancePointer = (__bridge void*)effect;
}

/*!
	@method		extRemovedFromDocument:
	@abstract	Removes the effect from the registry and clears the captured pointer.
	@discussion	Introduced in FxGrip 0.1.0. Returns when the effect is not an FxGripTileableEffect. */
// Called in FxTileableEffect::dealloc - instanceRemovedFromDocument
- (void)extRemovedFromDocument:(nonnull NSNotification*)notification;
{
	FxGripTileableEffect *effect = notification.object;
	if (![effect isKindOfClass:FxGripTileableEffect.class]) {
		return;
	}
	FxGripInstanceTrackerRemove(effect.pluginUUID, (__bridge void*)effect);
	if ((__bridge void*)effect == _trackedInstancePointer) {
		_trackedInstancePointer = NULL;
	}
}


/*!
	@method		startTimeOfNextEffect:
	@abstract	The nearest later timeline start time among the effect's sibling instances.
	@param		effect	The effect whose neighbors are examined.
	@return		The next sibling's timeline start time, or kCMTimeInvalid when none is later. */
- (CMTime)startTimeOfNextEffect:(id<FxGripTileableEffect>)effect;
{
	CMTime  timelineEffectTime  = effect.effectStartTimeInTimeline;
	CMTime  startTime   = kCMTimeInvalid;

	@synchronized (gEffectInstances) {
		CMTime  nextTimelineTime    = kCMTimePositiveInfinity;
		for (NSValue* pluginValue in gEffectInstances[effect.pluginUUID])
		{
			id<FxGripTileableEffect> plugin  = (id<FxGripTileableEffect>)[pluginValue pointerValue];
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

		if (CMTimeCompare(nextTimelineTime, kCMTimePositiveInfinity) != 0) {
			startTime = nextTimelineTime;
		}
	}
	
	return startTime;
}

/*!
	@method		startTimeOfPreviousEffect:
	@abstract	The nearest earlier timeline start time among the effect's sibling instances.
	@param		effect	The effect whose neighbors are examined.
	@return		The previous sibling's timeline start time, or kCMTimeInvalid when none is earlier. */
- (CMTime)startTimeOfPreviousEffect:(id<FxGripTileableEffect>)effect;
{
	CMTime  timelineEffectTime  = effect.effectStartTimeInTimeline;
	CMTime  startTime   = kCMTimeInvalid;

	@synchronized (gEffectInstances) {
		CMTime  prevTimelineTime    = kCMTimeNegativeInfinity;
		for (NSValue* pluginValue in gEffectInstances[effect.pluginUUID])
		{
			id<FxGripTileableEffect> plugin = (id<FxGripTileableEffect>)[pluginValue pointerValue];
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
		if (CMTimeCompare(prevTimelineTime, kCMTimeNegativeInfinity) != 0) {
			startTime = prevTimelineTime;
		}
	}
	
	return startTime;
}

@end




#pragma mark -
#pragma mark FxGripTileableEffect (InstanceTracker)

/*!
	@abstract	The effect-side accessors for the instance tracker extension.
	@discussion	Introduced in FxGrip 0.1.0. The accessors read the shared registry by the effect's
				plugin UUID.
*/
@implementation FxGripTileableEffect (InstanceTracker)

- (nullable FxGripInstanceTracker*)newFxInstanceTracker
{
	return [FxGripInstanceTracker.alloc init];
}

- (BOOL)isTrackingInstances
{
	return self.pluginProperties.pluginTrackInstances;
}

- (FxGripInstanceTracker*_Nullable)instanceTracker
{
	return [self extensionForClass:FxGripInstanceTracker.class];
}


- (nonnull NSArray<id<FxGripTileableEffect>>*)instances
{
	return self.instanceTracker.instances ?: @[];
}

- (NSUInteger)instanceCount
{
	@synchronized (gEffectInstances) {
		return gEffectInstances[self.pluginUUID].count;
	}
}


- (nullable id<FxGripTileableEffect>)instanceAtIndex:(int)index
{
	@synchronized (gEffectInstances) {
		NSArray<NSValue*> *bucket = gEffectInstances[self.pluginUUID];
		if (index < 0 || (NSUInteger)index >= bucket.count) {
			return NULL;
		}
		return bucket[index].pointerValue;
	}
}

@end
