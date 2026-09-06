/*!
	@file       FxGripFrameData.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripFrameData
	@abstract   Implements the per-frame custom parameter store with size-gated spill.
	@discussion Introduced in FxGrip 0.1.0. Records key by NSNumber frame index. A record whose secure
	            archive exceeds the spill threshold writes to the cache folder and a marker dictionary
	            replaces it in the store. Reads rehydrate a spilled record from the cache folder.
*/

#import "FxGripFrameData.h"
#import "FxGripImageBuffer.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+ProjectProperties.h"
#import "FxGrip_ARC.h"


/*!
	@abstract	The per-frame custom parameter store with size-gated spill to the project media folder.
	@discussion	Introduced in FxGrip 0.1.0. Records key by frame index and spill to a machine-local
				cache folder when their archive exceeds the threshold. The class does not interpolate.
*/
@implementation FxGripFrameData
{
	NSURL *_cacheURL;
}

/*!
	@method		classesForParameter
	@abstract	Extends the base allow-list with FxGripImageBuffer so image records decode.
	@result		The ordered set of decodable classes.
*/
+ (NSOrderedSet<Class>*)classesForParameter
{
	NSMutableOrderedSet *classes = [[super classesForParameter] mutableCopy];
	[classes addObject:FxGripImageBuffer.class];
	return NARC_AUTORELEASE(classes);
}

// The secure unarchiver requires every concrete class to answer classForCoder itself;
// an inherited override fails the possibly-altered-archive check.
- (Class)classForCoder
{
	return self.class;
}

- (void)dealloc
{
	NARC_RELEASE(_cacheURL);
	SUPER_DEALLOC();
}


#pragma mark Configuration

- (nullable NSURL *)cacheURL
{
	return _cacheURL;
}

- (void)setCacheURL:(nullable NSURL *)cacheURL
{
	NSURL *copied = [cacheURL copy];
	NARC_RELEASE(_cacheURL);
	_cacheURL = copied;
}

/*!
	@method		attachProjectMediaCacheForEffect:
	@abstract	Points the spill cache at the effect's project media folder.
	@discussion	Introduced in FxGrip 0.1.0. When the effect has no media folder the cache URL clears
				and every record stays inline.
	@result		YES when a media folder is available.
*/
- (BOOL)attachProjectMediaCacheForEffect:(nullable id)effect
{
	NSURL *mediaFolder = nil;
	if ([effect respondsToSelector:@selector(projectMediaFolder)]) {
		mediaFolder = ((FxGripTileableEffect*)effect).projectMediaFolder;
	}
	self.cacheURL = mediaFolder;
	return mediaFolder != nil;
}

- (NSInteger)spillThreshold
{
	id threshold = [self objectForKey:kFxGripFrameDataKey_SpillThreshold];
	if ([threshold isKindOfClass:NSNumber.class]) {
		return ((NSNumber*)threshold).integerValue;
	}
	return kFxGripFrameDataDefaultSpillThreshold;
}

- (void)setSpillThreshold:(NSInteger)spillThreshold
{
	[self setObject:@(spillThreshold) forKey:kFxGripFrameDataKey_SpillThreshold];
}

/*! @abstract The stable identity naming the cache subfolder, created and persisted on first use. */
- (nonnull NSString *)instanceUUID
{
	id uuid = [self objectForKey:kFxGripFrameDataKey_InstanceUUID];
	if ([uuid isKindOfClass:NSString.class]) {
		return uuid;
	}
	NSString *created = NSUUID.UUID.UUIDString;
	[self setObject:created forKey:kFxGripFrameDataKey_InstanceUUID];
	return created;
}

/*! @abstract The cache subfolder for this store's spilled records, or nil without a cache URL. */
- (nullable NSURL *)spillFolderURL
{
	if (_cacheURL == nil) {
		return nil;
	}
	return [_cacheURL URLByAppendingPathComponent:self.instanceUUID isDirectory:YES];
}

/*! @abstract The cache file URL for a spill file name, or nil when the name is not a single path component. */
- (nullable NSURL *)spillFileURLForName:(NSString *)name
{
	if (![name isKindOfClass:NSString.class] || name.pathComponents.count != 1) {
		return nil;
	}
	return [[self spillFolderURL] URLByAppendingPathComponent:name isDirectory:NO];
}


#pragma mark Records

/*! @abstract YES when a stored value is the marker dictionary that stands in for a spilled record. */
- (BOOL)isSpillMarker:(id)value
{
	return [value isKindOfClass:NSDictionary.class]
		&& [((NSDictionary*)value)[kFxGripFrameDataKey_SpillFile] isKindOfClass:NSString.class];
}

/*!
	@method		recordAtIndex:
	@abstract	Returns the record at a frame index, loading a spilled record from the cache folder.
	@discussion	Introduced in FxGrip 0.1.0. Returns nil when nothing is stored or the cache file is absent.
*/
- (nullable NSObject<NSSecureCoding, NSCopying> *)recordAtIndex:(NSInteger)index
{
	id stored = [self objectForKey:@(index)];
	if (![self isSpillMarker:stored]) {
		return stored;
	}

	NSURL *fileURL = [self spillFileURLForName:((NSDictionary*)stored)[kFxGripFrameDataKey_SpillFile]];
	NSData *archived = fileURL != nil ? [NSData dataWithContentsOfURL:fileURL] : nil;
	if (archived == nil) {
		return nil;
	}
	NSSet<Class> *classes = [NSSet setWithArray:self.classesForParameter.array];
	return [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:archived error:NULL];
}

/*!
	@method		setRecord:atIndex:
	@abstract	Stores a record at a frame index, spilling it to the cache folder when it exceeds the threshold.
	@discussion	Introduced in FxGrip 0.1.0. A spill failure logs and stores the record inline. Overwriting a
				previously spilled record removes its orphaned cache file.
	@result		YES when the record is stored; NO when record is nil.
*/
- (BOOL)setRecord:(nonnull NSObject<NSSecureCoding, NSCopying> *)record atIndex:(NSInteger)index
{
	if (record == nil) {
		return NO;
	}

	NSInteger threshold = self.spillThreshold;
	NSURL *folderURL = [self spillFolderURL];
	if (folderURL != nil && threshold >= 0) {
		NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:record
												 requiringSecureCoding:YES
																 error:NULL];
		if ((NSInteger)archived.length > threshold) {
			NSString *name = [NSString stringWithFormat:@"%ld.%@", (long)index, kFxGripFrameDataFileExtension];
			NSURL *fileURL = [folderURL URLByAppendingPathComponent:name isDirectory:NO];
			[NSFileManager.defaultManager createDirectoryAtURL:folderURL
								   withIntermediateDirectories:YES
													attributes:nil
														 error:NULL];
			if ([archived writeToURL:fileURL atomically:YES]) {
				[self setObject:@{kFxGripFrameDataKey_SpillFile: name,
								  kFxGripFrameDataKey_SpillLength: @(archived.length)}
						 forKey:@(index)];
				return YES;
			}
			NSLog(@"%s Error: could not spill frame %ld to %@; storing inline.", __func__, (long)index, fileURL.path);
		}
	}

	// An inline overwrite of a previously spilled record must not orphan its cache file.
	id previous = [self objectForKey:@(index)];
	if ([self isSpillMarker:previous]) {
		NSURL *previousURL = [self spillFileURLForName:((NSDictionary*)previous)[kFxGripFrameDataKey_SpillFile]];
		if (previousURL != nil) {
			[NSFileManager.defaultManager removeItemAtURL:previousURL error:NULL];
		}
	}
	[self setObject:record forKey:@(index)];
	return YES;
}

/*! @abstract Removes the record at a frame index and its cache file when spilled. */
- (void)removeRecordAtIndex:(NSInteger)index
{
	id stored = [self objectForKey:@(index)];
	if ([self isSpillMarker:stored]) {
		NSURL *fileURL = [self spillFileURLForName:((NSDictionary*)stored)[kFxGripFrameDataKey_SpillFile]];
		if (fileURL != nil) {
			[NSFileManager.defaultManager removeItemAtURL:fileURL error:NULL];
		}
	}
	[self removeObjectForKey:@(index)];
}

/*! @abstract The stored frame indexes in ascending order. */
- (nonnull NSArray<NSNumber*> *)frameIndexes
{
	NSMutableArray *indexes = [NSMutableArray array];
	for (id key in self.allKeys) {
		if ([key isKindOfClass:NSNumber.class]) {
			[indexes addObject:key];
		}
	}
	[indexes sortUsingSelector:@selector(compare:)];
	return indexes;
}

/*! @abstract The greatest stored index at or before a frame index, or NSNotFound when none exists. */
- (NSInteger)latestIndexAtOrBefore:(NSInteger)index
{
	NSInteger latest = NSNotFound;
	for (id key in self.allKeys) {
		if (![key isKindOfClass:NSNumber.class]) {
			continue;
		}
		NSInteger candidate = ((NSNumber*)key).integerValue;
		if (candidate <= index && (latest == NSNotFound || candidate > latest)) {
			latest = candidate;
		}
	}
	return latest;
}

/*! @abstract The record at latestIndexAtOrBefore:, or nil when none exists. */
- (nullable NSObject<NSSecureCoding, NSCopying> *)latestRecordAtOrBefore:(NSInteger)index
{
	NSInteger latest = [self latestIndexAtOrBefore:index];
	if (latest == NSNotFound) {
		return nil;
	}
	return [self recordAtIndex:latest];
}

@end
