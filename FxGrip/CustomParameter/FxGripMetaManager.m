/*!
	@file       FxGripMetaManager.m
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMetaManager
	@abstract   Implements the per-parameter tag and meta store for an effect instance.
	@discussion Introduced in FxGrip 0.1.0. A single mutable dictionary holds two root containers: a
	            tag reverse index and a per-parameter record store. Aliases into that dictionary are
	            re-established after every decode and copy. A recursive lock guards every public method.
*/

#import <AppKit/AppKit.h>
#import "FxGripMetaManager.h"
#import "FxGripTypes.h"
#import "FxGripTileableEffect.h"
#import "FxGripAPIAccessing.h"
#import <BEFoundation/BEMutable.h>
#import <BEFoundation/FxTime.h>
#import "FxGripDictionary.h"
#import "FxGripInterpolatingDictionary.h"

static NSString * const kFxGripMetaManagerCoderDataKey = @"data";

/*!
	@abstract	The per-parameter tag and meta store for an effect instance.
	@discussion	Introduced in FxGrip 0.1.0. The store archives as the InstanceMeta custom parameter.
				Mutations mark the manager unsaved, and saveMeta writes it back through the effect's
				parameter-setting API.
*/
@implementation FxGripMetaManager
{
	NSMutableDictionary<NSString*, NSObject*> *_data;
	// Aliases into _data; realiasData reestablishes them after decode and copy.
	NSMutableDictionary<NSString*, NSMutableArray<NSNumber*>*> *__tags;
	NSMutableDictionary<NSNumber*, NSMutableDictionary<NSString*, id>*> *__parameters;
	NSRecursiveLock *_metaLock;
	__weak FxGripTileableEffect *_effect;
	BOOL _unsaved;
}

#pragma mark Lifecycle

- (nonnull instancetype)init
{
	return [self initWithEffect:nil];
}

- (nonnull instancetype)initWithEffect:(FxGripTileableEffect *_Nullable)effect
{
	self = [super init];
	if (self) {
		_metaLock = NSRecursiveLock.new;
		_data = NSMutableDictionary.new;
		[self realiasData];
		_effect = effect;
		_unsaved = NO;
	}
	return self;
}

- (nullable FxGripTileableEffect *)effect
{
	return _effect;
}

- (void)setEffect:(FxGripTileableEffect *_Nonnull)effect
{
	[_metaLock lock];
	_effect = effect;
	[_metaLock unlock];
}

/*!
	Ensures the two root containers exist as mutable dictionaries and points the
	`__tags` / `__parameters` aliases at them.
*/
- (void)realiasData
{
	id tags = _data[kFxMetaProperty_Tags];
	if (![tags isKindOfClass:NSMutableDictionary.class]) {
		tags = [tags isKindOfClass:NSDictionary.class] ? [tags mutableCopy] : NSMutableDictionary.new;
		_data[kFxMetaProperty_Tags] = tags;
	}
	__tags = tags;

	id parameters = _data[kFxMetaProperty_Parameters];
	if (![parameters isKindOfClass:NSMutableDictionary.class]) {
		parameters = [parameters isKindOfClass:NSDictionary.class] ? [parameters mutableCopy] : NSMutableDictionary.new;
		_data[kFxMetaProperty_Parameters] = parameters;
	}
	__parameters = parameters;
}

#pragma mark Errors

/*! @abstract Builds an error in the FxGrip plug error domain, offsetting the code by the parameter ID. */
+ (NSError *)errorForParameter:(FxParameterId)parameterID description:(NSString *)description
{
	// FxGripPlugErrorDomain guards the weak-linked FxPlug domain symbol, which is NULL
	// outside a host process.
	return [NSError errorWithDomain:FxGripPlugErrorDomain
							   code:kFxError_ThirdPartyDeveloperStart + parameterID
						   userInfo:@{NSLocalizedDescriptionKey: description}];
}

+ (NSError *)noRecordErrorForParameter:(FxParameterId)parameterID
{
	return [self errorForParameter:parameterID
					   description:[NSString stringWithFormat:@"No record for parameter (%u).", parameterID]];
}

+ (NSError *)noTagsErrorForParameter:(FxParameterId)parameterID
{
	return [self errorForParameter:parameterID
					   description:[NSString stringWithFormat:@"No tags container for parameter (%u).", parameterID]];
}

#pragma mark Record Management

/*!
	@method		addParameter:
	@abstract	Creates the record for a parameter ID.
	@discussion	Introduced in FxGrip 0.1.0. A pre-seeded record without an ID is adopted and completed;
				a record that already carries an ID is rejected. Pre-seeded tag and meta containers are
				promoted to their mutable classes.
	@result		YES when the record is created or adopted; NO for a duplicate.
*/
- (BOOL)addParameter:(FxParameterId)parameterID
{
	[_metaLock lock];
	NSNumber *key = @(parameterID);
	id record = __parameters[key];
	if ([record isKindOfClass:NSDictionary.class] && record[kFxMetaProperty_ParamId]) {
		[_metaLock unlock];
		NSLog(@"%s Error: parameter (%u) already exists.", __func__, parameterID);
		return NO;
	}

	NSMutableDictionary *rec;
	if ([record isKindOfClass:NSMutableDictionary.class]) {
		rec = record;
	} else if ([record isKindOfClass:NSDictionary.class]) {
		rec = [record mutableCopy];
	} else {
		rec = NSMutableDictionary.new;
	}
	rec[kFxMetaProperty_ParamId] = key;

	id tags = rec[kFxMetaProperty_ParamTags];
	if ([tags isKindOfClass:NSArray.class]) {
		if (![tags isKindOfClass:NSMutableArray.class]) {
			rec[kFxMetaProperty_ParamTags] = [tags mutableCopy];
		}
	} else {
		rec[kFxMetaProperty_ParamTags] = NSMutableArray.new;
	}

	id meta = rec[kFxMetaProperty_ParamMeta];
	if ([meta isKindOfClass:NSDictionary.class]) {
		if (![meta isKindOfClass:NSMutableDictionary.class]) {
			rec[kFxMetaProperty_ParamMeta] = [meta mutableCopy];
		}
	} else {
		rec[kFxMetaProperty_ParamMeta] = NSMutableDictionary.new;
	}

	__parameters[key] = rec;
	_unsaved = YES;
	[_metaLock unlock];
	return YES;
}

/*!
	@method		removeParameter:
	@abstract	Removes the record and scrubs the parameter ID from the tag reverse index.
	@result		YES when the record existed.
*/
- (BOOL)removeParameter:(FxParameterId)parameterID
{
	[_metaLock lock];
	NSNumber *key = @(parameterID);
	if (!__parameters[key]) {
		[_metaLock unlock];
		NSLog(@"%s Error: parameter (%u) does not exist.", __func__, parameterID);
		return NO;
	}
	[__parameters removeObjectForKey:key];

	for (NSString *tag in __tags.allKeys) {
		NSMutableArray *pids = __tags[tag];
		[pids removeObject:key];
		if (!pids.count) {
			[__tags removeObjectForKey:tag];
		}
	}
	_unsaved = YES;
	[_metaLock unlock];
	return YES;
}

- (BOOL)parameterExists:(FxParameterId)parameterID
{
	[_metaLock lock];
	BOOL exists = __parameters[@(parameterID)] != nil;
	[_metaLock unlock];
	return exists;
}

- (NSArray<NSNumber*> *_Nonnull)parameterIDs
{
	[_metaLock lock];
	NSArray *pids = __parameters.allKeys;
	[_metaLock unlock];
	return pids;
}

- (NSMutableDictionary *_Nullable)parameterData:(FxParameterId)parameterID
{
	[_metaLock lock];
	NSMutableDictionary *record = __parameters[@(parameterID)];
	[_metaLock unlock];
	return record;
}

// Callers hold the lock.
- (NSMutableArray *_Nullable)tagContainerForParameter:(FxParameterId)parameterID
{
	id tags = __parameters[@(parameterID)][kFxMetaProperty_ParamTags];
	return [tags isKindOfClass:NSMutableArray.class] ? tags : nil;
}

// Callers hold the lock.
- (NSMutableDictionary *_Nullable)metaContainerForParameter:(FxParameterId)parameterID
{
	id meta = __parameters[@(parameterID)][kFxMetaProperty_ParamMeta];
	return [meta isKindOfClass:NSMutableDictionary.class] ? meta : nil;
}

#pragma mark Tag API

- (NSArray<NSString*> *_Nonnull)tags
{
	[_metaLock lock];
	NSArray *allTags = __tags.allKeys;
	[_metaLock unlock];
	return allTags;
}

- (SInt32)tagCount
{
	[_metaLock lock];
	SInt32 count = (SInt32)__tags.count;
	[_metaLock unlock];
	return count;
}

- (SInt32)tagCount:(FxParameterId)parameterID
{
	[_metaLock lock];
	NSMutableArray *container = [self tagContainerForParameter:parameterID];
	SInt32 count = container ? (SInt32)container.count : -1;
	[_metaLock unlock];
	return count;
}

- (NSArray<NSString*> *_Nullable)parameterTags:(FxParameterId)parameterID
{
	[_metaLock lock];
	NSArray *tags = [self tagContainerForParameter:parameterID].copy;
	[_metaLock unlock];
	return tags;
}

- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString *_Nullable)tag
			error:(NSError *_Nullable *_Nullable)error
{
	[_metaLock lock];
	NSMutableArray *container = [self tagContainerForParameter:parameterID];
	if (!container) {
		[_metaLock unlock];
		if (error) {
			*error = [self.class noTagsErrorForParameter:parameterID];
		}
		return NO;
	}
	BOOL hasTag = tag && [container containsObject:tag];
	[_metaLock unlock];
	return hasTag;
}

/*! @abstract Replaces a parameter's tags by clearing them and adding each supplied tag. */
- (NSError *_Nullable)setTags:(NSArray<NSString*> *_Nonnull)tags toParameter:(FxParameterId)parameterID
{
	[_metaLock lock];
	NSError *error = [self removeAllTags:parameterID];
	if (!error) {
		for (NSString *tag in tags) {
			error = [self addTag:tag toParameter:parameterID];
			if (error) {
				break;
			}
		}
	}
	[_metaLock unlock];
	return error;
}

- (NSError *_Nullable)addTag:(NSString *_Nullable)tag toParameter:(FxParameterId)parameterID
{
	if (!tag) {
		return [self.class errorForParameter:parameterID description:@"No tag supplied."];
	}
	[_metaLock lock];
	NSMutableArray *container = [self tagContainerForParameter:parameterID];
	if (!container) {
		[_metaLock unlock];
		return [self.class noTagsErrorForParameter:parameterID];
	}
	if (![container containsObject:tag]) {
		[container addObject:tag];
		NSMutableArray *pids = __tags[tag];
		if (!pids) {
			pids = NSMutableArray.new;
			__tags[tag] = pids;
		}
		NSNumber *key = @(parameterID);
		if (![pids containsObject:key]) {
			[pids addObject:key];
		}
		_unsaved = YES;
	}
	[_metaLock unlock];
	return nil;
}

- (NSError *_Nullable)removeTag:(NSString *_Nullable)tag fromParameter:(FxParameterId)parameterID
{
	if (!tag) {
		return [self.class errorForParameter:parameterID description:@"No tag supplied."];
	}
	[_metaLock lock];
	NSMutableArray *container = [self tagContainerForParameter:parameterID];
	if (!container) {
		[_metaLock unlock];
		return [self.class noTagsErrorForParameter:parameterID];
	}
	if ([container containsObject:tag]) {
		[container removeObject:tag];
		NSMutableArray *pids = __tags[tag];
		[pids removeObject:@(parameterID)];
		if (!pids.count) {
			[__tags removeObjectForKey:tag];
		}
		_unsaved = YES;
	}
	[_metaLock unlock];
	return nil;
}

- (NSError *_Nullable)removeAllTags:(FxParameterId)parameterID
{
	[_metaLock lock];
	NSMutableArray *container = [self tagContainerForParameter:parameterID];
	if (!container) {
		[_metaLock unlock];
		return [self.class noTagsErrorForParameter:parameterID];
	}
	NSNumber *key = @(parameterID);
	for (NSString *tag in container.copy) {
		NSMutableArray *pids = __tags[tag];
		[pids removeObject:key];
		if (!pids.count) {
			[__tags removeObjectForKey:tag];
		}
	}
	if (container.count) {
		_unsaved = YES;
	}
	[container removeAllObjects];
	[_metaLock unlock];
	return nil;
}

- (NSArray<NSNumber*> *_Nullable)parametersWithTag:(NSString *_Nullable)tag
{
	if (!tag) {
		return nil;
	}
	[_metaLock lock];
	NSArray *pids = __tags[tag].copy;
	[_metaLock unlock];
	return pids;
}

#pragma mark Meta API

- (SInt32)metaCountFromParameter:(FxParameterId)parameterID
{
	[_metaLock lock];
	SInt32 count = -1;
	if (__parameters[@(parameterID)]) {
		count = (SInt32)[self metaContainerForParameter:parameterID].count;
	}
	[_metaLock unlock];
	return count;
}

- (NSError *_Nullable)getMeta:(NSDictionary *_Nullable *_Nonnull)meta fromParameter:(FxParameterId)parameterID
{
	[_metaLock lock];
	NSMutableDictionary *container = [self metaContainerForParameter:parameterID];
	if (!container) {
		[_metaLock unlock];
		return [self.class noRecordErrorForParameter:parameterID];
	}
	*meta = container.copy;
	[_metaLock unlock];
	return nil;
}

- (NSError *_Nullable)setMeta:(NSDictionary *_Nonnull)meta toParameter:(FxParameterId)parameterID
{
	[_metaLock lock];
	NSMutableDictionary *record = __parameters[@(parameterID)];
	if (!record) {
		[_metaLock unlock];
		return [self.class noRecordErrorForParameter:parameterID];
	}
	record[kFxMetaProperty_ParamMeta] = [meta isKindOfClass:NSDictionary.class] ? [meta mutableCopy] : NSMutableDictionary.new;
	_unsaved = YES;
	[_metaLock unlock];
	return nil;
}

- (NSError *_Nullable)getMetaKeys:(NSArray *_Nullable *_Nonnull)keys fromParameter:(FxParameterId)parameterID
{
	if (!keys) {
		return [self.class errorForParameter:parameterID description:@"No keys out-parameter supplied."];
	}
	[_metaLock lock];
	NSMutableDictionary *container = [self metaContainerForParameter:parameterID];
	if (!container) {
		[_metaLock unlock];
		return [self.class noRecordErrorForParameter:parameterID];
	}
	*keys = container.allKeys;
	[_metaLock unlock];
	return nil;
}

- (NSError *_Nullable)removeAllMeta:(FxParameterId)parameterID
{
	[_metaLock lock];
	NSMutableDictionary *container = [self metaContainerForParameter:parameterID];
	if (!container) {
		[_metaLock unlock];
		return [self.class noRecordErrorForParameter:parameterID];
	}
	if (container.count) {
		_unsaved = YES;
	}
	[container removeAllObjects];
	[_metaLock unlock];
	return nil;
}

- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString *_Nonnull)key
			error:(NSError *_Nullable *_Nullable)error
{
	[_metaLock lock];
	NSMutableDictionary *container = [self metaContainerForParameter:parameterID];
	if (!container) {
		[_metaLock unlock];
		if (error) {
			*error = [self.class noRecordErrorForParameter:parameterID];
		}
		return NO;
	}
	BOOL hasKey = key && container[key] != nil;
	[_metaLock unlock];
	return hasKey;
}

- (BOOL)getMeta:(NSObject<NSSecureCoding,NSCopying> *_Nullable *_Nullable)value
		 forKey:(NSString *_Nullable)key fromParameter:(FxParameterId)parameterID
{
	if (!key) {
		return NO;
	}
	[_metaLock lock];
	id stored = [self metaContainerForParameter:parameterID][key];
	if (stored && value) {
		*value = stored;
	}
	[_metaLock unlock];
	return stored != nil;
}

- (BOOL)setMeta:(NSObject<NSSecureCoding,NSCopying> *_Nonnull)value
		 forKey:(NSString *_Nullable)key toParameter:(FxParameterId)parameterID
{
	if (!key || !value) {
		return NO;
	}
	[_metaLock lock];
	NSMutableDictionary *container = [self metaContainerForParameter:parameterID];
	if (!container) {
		[_metaLock unlock];
		return NO;
	}
	container[key] = value;
	_unsaved = YES;
	[_metaLock unlock];
	return YES;
}

- (BOOL)removeMetaKey:(NSString *_Nullable)key fromParameter:(FxParameterId)parameterID
{
	if (!key) {
		return NO;
	}
	[_metaLock lock];
	NSMutableDictionary *container = [self metaContainerForParameter:parameterID];
	BOOL existed = container[key] != nil;
	if (existed) {
		[container removeObjectForKey:key];
		_unsaved = YES;
	}
	[_metaLock unlock];
	return existed;
}

#pragma mark Persistence

- (BOOL)unsaved
{
	[_metaLock lock];
	BOOL unsaved = _unsaved;
	[_metaLock unlock];
	return unsaved;
}

- (void)setUnsaved:(BOOL)unsavedValue
{
	[_metaLock lock];
	_unsaved = unsavedValue;
	[_metaLock unlock];
}

/*!
	@method		saveMeta
	@abstract	Writes the manager to the host as the InstanceMeta custom parameter value.
	@discussion	Introduced in FxGrip 0.1.0. Runs only when unsaved. The unsaved flag clears after the
				host write, so a write that cannot proceed leaves the manager unsaved for a later flush.
	@result		YES when nothing needs saving or the write is issued; NO when the setting API is unavailable.
*/
- (BOOL)saveMeta
{
	[_metaLock lock];
	if (!_unsaved) {
		[_metaLock unlock];
		return YES;
	}
	id<FxParameterSettingAPI_v5> api = self.effect.apiManager.paramSetAPIv5;
	if (!api) {
		// The manager stays unsaved so a later flush persists the state.
		[_metaLock unlock];
		return NO;
	}
	[api setCustomParameterValue:self toParameter:kFxParameterId_InstanceMeta atTime:kCMTimeZero];
	// Cleared only after the host write completes; a write that fails or throws leaves the
	// manager unsaved so a later flush retries it.
	_unsaved = NO;
	[_metaLock unlock];
	return YES;
}

#pragma mark Locking

- (BOOL)lock
{
	[_metaLock lock];
	return YES;
}

- (BOOL)lockWithinTime:(double)tryTime
{
	if (tryTime <= 0) {
		return [_metaLock tryLock];
	}
	return [_metaLock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:tryTime]];
}

- (void)unlock
{
	[_metaLock unlock];
}

#pragma mark NSSecureCoding / NSCopying / Equality

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[_metaLock lock];
	[coder encodeObject:_data forKey:kFxGripMetaManagerCoderDataKey];
	[_metaLock unlock];
}

/*! @abstract Decodes the root store and re-establishes the tag and parameter aliases. */
- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
	self = [self initWithEffect:nil];
	if (self) {
		NSSet<Class> *classes = [NSSet setWithArray:self.class.classesForParameter.array];
		NSDictionary *decoded = [coder decodeObjectOfClasses:classes forKey:kFxGripMetaManagerCoderDataKey];
		if ([decoded isKindOfClass:NSDictionary.class]) {
			_data = [decoded mutableCopyRecursive];
			[self realiasData];
		}
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	[_metaLock lock];
	FxGripMetaManager *copy = [FxGripMetaManager.alloc initWithEffect:_effect];
	copy->_data = [_data mutableCopyRecursive];
	[copy realiasData];
	copy->_unsaved = _unsaved;
	[_metaLock unlock];
	return copy;
}

- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if (![object isKindOfClass:FxGripMetaManager.class]) {
		return NO;
	}
	FxGripMetaManager *other = object;
	[_metaLock lock];
	BOOL equal = [_data isEqual:other->_data];
	[_metaLock unlock];
	return equal;
}

- (NSUInteger)hash
{
	return _data.hash;
}

#pragma mark FxGripCustomDataClasses

/*!
	@method		classesForParameter
	@abstract	The secure-decode allow-list for the manager's archive contents.
	@discussion	Introduced in FxGrip 0.1.0. The list admits the collection, value, and FxGrip dictionary
				classes a plugin can store under a meta key, so a meta record survives reload.
	@result		The ordered set of decodable classes.
*/
+ (NSOrderedSet<Class>*_Nonnull)classesForParameter
{
	return [NSOrderedSet orderedSetWithArray:@[
			NSMutableDictionary.class,
			NSDictionary.class,
			NSMutableArray.class,
			NSArray.class,
			NSMutableString.class,
			NSString.class,
			NSMutableSet.class,
			NSSet.class,
			NSMutableOrderedSet.class,
			NSOrderedSet.class,
			NSNumber.class,
			NSDecimalNumber.class,
			NSColor.class,
			NSDate.class,
			NSNull.class,
			NSMutableData.class,
			NSData.class,
			NSValue.class,
			NSURL.class,
			NSUUID.class,
			FxTime.class,
			// The dictionary family: setMeta: accepts any secure-codable value, so the
			// decode list must admit what a plugin can store or the whole meta record is
			// silently discarded on reload (NSCocoaErrorDomain 4864).
			FxGripDictionary.class,
			FxGripInterpolatingDictionary.class
			]
		];
}

- (NSOrderedSet<Class>*)classesForParameter
{
	return self.class.classesForParameter;
}

@end
