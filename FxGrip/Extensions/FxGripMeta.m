/*!
	@file       FxGripMeta.m
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMeta
	@abstract   Implements the per-instance parameter meta storage extension.
	@discussion Introduced in FxGrip 0.1.0. The extension seeds a record for each parameter after the
	            other extensions process the add, additively merging the configuration's tags, meta,
	            reset value, and target-preset definitions. It applies target presets and momentary
	            reset values on parameter changes and flushes the manager last in the cycle.
*/

#import "FxGripMeta.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripTileableEffect+Extensions.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTypes.h"
#import "FxGripParameterFlags.h"
#import "FxGripAPIAccessing.h"
#import "FxGripParameterTagsAPI_v1.h"
#import "FxGripPreset.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import <BEFoundation/FxTime.h>
#import "FxGrip_ARC.h"

@interface FxGripMeta ()
{
	BOOL _documentAdded;   // tracked from the AddedToDocument notification
	id _resolveObserver;
}
@end

/*!
	@abstract	The extension that owns the effect's FxGripMetaManager.
	@discussion	Introduced in FxGrip 0.1.0. The manager is loaded from the document, seeded per
				parameter, and persisted on flush.
*/
@implementation FxGripMeta
{
	FxGripMetaManager *_manager;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_manager = nil;
		_parameterID = kFxParameterId_InstanceMeta;
	}
	return self;
}

- (void)dealloc
{
	if (_resolveObserver != nil) {
		[self.effect.notifier removeObserver:_resolveObserver];
		NARC_RELEASE(_resolveObserver);
	}
	NARC_RELEASE(_manager);

	SUPER_DEALLOC();
}

/*! Answers the host's meta-resolve notification with this extension's manager, so the meta
	bridge works on a plain host that loads this extension. */
- (BOOL)extLoadWithEffect:(nonnull id<FxGripTileableEffect>)effect
{
	BOOL loaded = [super extLoadWithEffect:effect];
	if (loaded && _resolveObserver == nil) {
		__weak typeof(self) weakSelf = self;
		_resolveObserver = NARC_RETAIN([self.effect.notifier
			addObserverForName:FxGripTileableEffectResolveMetaName
						object:effect
						 queue:nil
					usingBlock:^(NSNotification *note) {
			((NSMutableDictionary *)note.userInfo)[FxGripTileableEffectResolvedObjectKey] = weakSelf.manager;
		}]);
	}
	return loaded;
}

- (nullable FxGripMetaManager *)manager
{
	return _manager;
}

- (NSSet *)dataClasses
{
	return [super.dataClasses setByAddingObjectsFromArray:@[FxGripMetaManager.class, FxTime.class]];
}

// Callers hold @synchronized (self).
- (FxGripMetaManager *)managerCreateIfNeeded
{
	if (!_manager) {
		_manager = [FxGripMetaManager.alloc initWithEffect:self.effect.effectBase];
	}
	return _manager;
}

// Seeding runs after the other extensions have processed the add; loading and flushing
// mirror FxGripParameterData, with the flush one step later so the meta write is last.
- (NSInteger)ncPriority:(nullable NSNotificationName)aName
{
	NSInteger priority = [super ncPriority:aName];

	if ([FxGripNotifyAPI_ParameterAddName isEqualToString:aName]) {
		return -20;
	} else if ([FxGripTileableEffectAddedToDocumentName isEqualToString:aName]) {
		return -18;
	} else if ([FxGripTileableEffectParameterChangedName isEqualToString:aName]) {
		// After the per-parameter startChangedTime: handlers have run.
		return -10;
	} else if ([FxGripTileableEffectFlushName isEqualToString:aName]) {
		return -14;
	}

	return priority;
}

/*!
	@method		extAddParameters:
	@abstract	Registers the hidden InstanceMeta custom parameter.
	@discussion	Introduced in FxGrip 0.1.0. The parameter carries no state, is never presented or
				animated, and stays out of presets. */
- (void)extAddParameters:(nonnull NSNotification*)notification
{
	NSDictionary *metaData = @{
		kFxParameterProperty_Factory: self,
		kFxParameterProperty_Id: @(kFxParameterId_InstanceMeta),
		kFxParameterProperty_Name: @"Plugin Data",
		kFxParameterProperty_Type: kFxParameterType_Custom,
		kFxParameterProperty_Flags: @[kParameterFlagString_DONT_DISPLAY, kParameterFlagString_HIDDEN,
									  kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA,
									  kParameterFlagString_PRESETNOVALUE,
									  kParameterFlagString_NO_DEBUG, kParameterFlagString_NO_STATE]
	};
	[notification.userInfo.fxEffectParameters addObject:[metaData mutableCopy]];
}

/*!
	@method		extAddedToDocument:
	@abstract	Loads the meta manager from the document and merges any pre-load seeded records.
	@discussion	Introduced in FxGrip 0.1.0. When the document has no stored manager, the seeded manager
				is kept. Otherwise the loaded manager wins and the seeded records fill only its
				absent entries. */
- (void)extAddedToDocument:(nonnull NSNotification*)notification
{
	@synchronized (self) {
		_documentAdded = YES;
		NSObject<NSCopying, NSSecureCoding> *object = nil;
		[self.effect.apiManager.paramGetAPIv6 getCustomParameterValue:&object
														fromParameter:self.parameterID
															   atTime:kCMTimeZero];
		if (![object isKindOfClass:FxGripMetaManager.class]) {
			[self managerCreateIfNeeded];
			return;
		}

		FxGripMetaManager *loaded = (FxGripMetaManager*)object;
		[loaded setEffect:self.effect.effectBase];
		[loaded setUnsaved:NO];

		if (_manager) {
			[self mergeSeededRecordsFrom:_manager into:loaded];
		}
		_manager = loaded;
	}
}

/*!
	Carries the records seeded before the document load into the loaded manager. The
	document's own entries win; a seeded record only fills entries the document lacks.
*/
- (void)mergeSeededRecordsFrom:(FxGripMetaManager *)seeded into:(FxGripMetaManager *)loaded
{
	[seeded lock];
	[loaded lock];
	for (NSNumber *pidNumber in seeded.parameterIDs) {
		FxParameterId pid = pidNumber.unsignedIntValue;
		if (![loaded parameterExists:pid]) {
			[loaded addParameter:pid];
		}

		for (NSString *tag in [seeded parameterTags:pid]) {
			[loaded addTag:tag toParameter:pid];
		}

		NSDictionary *seededMeta = nil;
		[seeded getMeta:&seededMeta fromParameter:pid];
		for (NSString *key in seededMeta) {
			if (![loaded getMeta:nil forKey:key fromParameter:pid]) {
				[loaded setMeta:seededMeta[key] forKey:key toParameter:pid];
			}
		}

		NSMutableDictionary *seededRecord = [seeded parameterData:pid];
		NSMutableDictionary *loadedRecord = [loaded parameterData:pid];
		for (NSString *key in seededRecord) {
			BOOL isContainerKey = [key isEqualToString:kFxMetaProperty_ParamId]
				|| [key isEqualToString:kFxMetaProperty_ParamTags]
				|| [key isEqualToString:kFxMetaProperty_ParamMeta];
			if (!isContainerKey && !loadedRecord[key]) {
				loadedRecord[key] = seededRecord[key];
				// The record dictionary is mutated directly, so the manager's unsaved flag
				// must be raised by hand or the merged entry never flushes. extAddedToDocument:
				// clears the flag just before this merge, so a raw write would be lost.
				[loaded setUnsaved:YES];
			}
		}
	}
	[loaded unlock];
	[seeded unlock];
}

/*!
	@method		extAPIParameterAdd:
	@abstract	Seeds the meta record for a newly added parameter and flushes when the instance is live.
	@discussion	Introduced in FxGrip 0.1.0. The InstanceMeta parameter itself is skipped. A per-add
				flush runs only once the instance is live, outside a batched flag-cache setup. */
- (void)extAPIParameterAdd:(nonnull NSNotification*)notification
{
	// The id is read directly: the guarded parameterID accessor requires id+type+name,
	// which the API wrappers' payloads do not always carry.
	NSNumber *pidNumber = notification.userInfo.fxParameter[kFxParameterProperty_Id]
		?: notification.userInfo[kFxParameterProperty_Id];
	if (!pidNumber) {
		return;
	}
	FxParameterId pid = pidNumber.unsignedIntValue;
	if (pid == kFxParameterId_InstanceMeta) {
		return;
	}

	@synchronized (self) {
		FxGripMetaManager *manager = [self managerCreateIfNeeded];
		[manager lock];
		if (![manager parameterExists:pid]) {
			[manager addParameter:pid];
		}
		[self seedRecordForParameter:pid manager:manager];
		[manager unlock];

		// Flush per-add only once the instance is live: not mid flag-cache (a batched setup
		// defers the write), the meta parameter is added, and the document has loaded.
		if (!flagCache(_parameterFlags) && self.addedToEffect && _documentAdded) {
			[self extFlush:notification];
		}
	}
}

/*!
	Transfers configuration state into the parameter's record. Additive: existing
	entries, including customizations restored from the document, are kept.
*/
- (void)seedRecordForParameter:(FxParameterId)pid manager:(FxGripMetaManager *)manager
{
	NSDictionary *config = FxGripHostConfigurationForParameter(self.effect, pid);
	if (!config) {
		return;
	}

	NSArray *tags = config.parameterTags;
	for (NSString *tag in tags) {
		[manager addTag:tag toParameter:pid];
	}

	NSDictionary *meta = config.parameterMeta;
	for (NSString *key in meta) {
		if (![manager getMeta:nil forKey:key fromParameter:pid]) {
			[manager setMeta:meta[key] forKey:key toParameter:pid];
		}
	}

	// Reset value and target-preset definitions become per-instance record entries so
	// runtime customizations persist in the document.
	NSMutableDictionary *record = [manager parameterData:pid];
	for (NSString *key in config) {
		BOOL isTargetKey = [key hasPrefix:kFxParameterProperty_TargetPrefix];
		BOOL isResetKey = [key isEqualToString:kFxParameterProperty_ResetValue];
		if ((isTargetKey || isResetKey) && !record[key]) {
			record[key] = config[key];
			// A direct record write bypasses the manager's unsaved tracking; raise it by
			// hand so a config that carries only target/reset keys (no tags or meta) still
			// flushes to the document.
			[manager setUnsaved:YES];
		}
	}
}

/*!
	@method		extAPIParameterRemove:
	@abstract	Removes a parameter's meta record and flushes when the instance is live.
	@discussion	Introduced in FxGrip 0.1.0. Returns when the manager does not track the parameter. */
- (void)extAPIParameterRemove:(nonnull NSNotification*)notification
{
	NSNumber *pidNumber = notification.userInfo.fxParameter[kFxParameterProperty_Id]
		?: notification.userInfo[kFxParameterProperty_Id];
	if (!pidNumber) {
		return;
	}
	FxParameterId pid = pidNumber.unsignedIntValue;

	@synchronized (self) {
		if (!_manager || ![_manager parameterExists:pid]) {
			return;
		}
		[_manager removeParameter:pid];

		// Flush per-remove only when the instance is live; see extAPIParameterAdd:.
		if (!flagCache(_parameterFlags) && self.addedToEffect && _documentAdded) {
			[self extFlush:notification];
		}
	}
}

/*!
	Applies the target preset a Menu or Toggle change selects.

	Ordering contract: value work first, the reset value next, names last. Final Cut Pro
	misreports a String parameter when its name changes earlier in the same pass, so the
	names section runs in a second call.
*/
- (void)extParameterChanged:(nonnull NSNotification*)notification
{
	NSNumber *pidNumber = notification.userInfo[FxGripTileableEffectParameterChangedIDKey];
	if (!pidNumber) {
		return;
	}
	FxParameterId pid = pidNumber.unsignedIntValue;

	CMTime time = kCMTimeZero;
	NSDictionary *timeDict = notification.userInfo[FxGripTileableEffectParameterChangedAtTimeKey];
	if ([timeDict isKindOfClass:NSDictionary.class]) {
		time = CMTimeMakeFromDictionary((__bridge CFDictionaryRef)timeDict);
	}

	FxGripTileableEffect *effect = self.effect.effectBase;
	id<FxGripParameterTagsAPI_v1> tagsAPI = effect.apiManager.paramTagsAPIv1;
	if (![tagsAPI respondsToSelector:@selector(applyTargetPresetForParameter:atTime:options:)]) {
		return;
	}

	[tagsAPI applyTargetPresetForParameter:pid
									atTime:time
								   options:(FxGripPresetValues | FxGripPresetFlags | FxGripPresetTags | FxGripPresetMeta)];

	// A parameter carrying a reset value is a momentary control: it snaps back to that value
	// after every change (for example a Menu returning to its main item).
	id resetValue = nil;
	@synchronized (self) {
		resetValue = [_manager parameterData:pid][kFxParameterProperty_ResetValue];
	}
	if (resetValue) {
		[FxGripPreset setParameterValue:resetValue
							toParameter:pid
								 atTime:time
								withAPI:effect.apiManager.paramSetAPIv5];
	}

	[tagsAPI applyTargetPresetForParameter:pid atTime:time options:FxGripPresetNames];
}

/*! @abstract Persists the meta manager to the custom parameter. */
- (void)extFlush:(nonnull NSNotification*)notification
{
	@synchronized (self) {
		[_manager saveMeta];
	}
}

/*! @abstract The meta manager, returned as the InstanceMeta parameter's custom value for encoding. */
- (id<NSSecureCoding, NSCopying> _Nullable)valueAtTime:(CMTime)renderTime
{
	// Read under the same lock that guards every _manager reassignment.
	@synchronized (self) {
		return _manager;
	}
}

@end


/*!
	@abstract	The effect-side accessors for the meta extension and its manager.
	@discussion	Introduced in FxGrip 0.1.0. meta resolves the loaded extension's manager.
*/
@implementation FxGripTileableEffect (Meta)

- (nullable FxGripMetaManager *)meta
{
	return ((FxGripMeta*)[self extensionForClass:FxGripMeta.class]).manager;
}

- (BOOL)hasMeta
{
	return [self extensionForClass:FxGripMeta.class] != nil;
}

- (nonnull FxGripMeta *)newMetaExtension
{
	return [FxGripMeta.alloc init];
}

@end
