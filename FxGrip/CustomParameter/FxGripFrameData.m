//
//  FxGripFrameData.m
//  FxGrip
//

#import "FxGripFrameData.h"
#import "FxGripImageBuffer.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+ProjectProperties.h"
#import "FxGrip_ARC.h"


@implementation FxGripFrameData
{
	NSURL *_cacheURL;
}

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

- (nullable NSURL *)spillFolderURL
{
	if (_cacheURL == nil) {
		return nil;
	}
	return [_cacheURL URLByAppendingPathComponent:self.instanceUUID isDirectory:YES];
}

- (nullable NSURL *)spillFileURLForName:(NSString *)name
{
	if (![name isKindOfClass:NSString.class] || name.pathComponents.count != 1) {
		return nil;
	}
	return [[self spillFolderURL] URLByAppendingPathComponent:name isDirectory:NO];
}


#pragma mark Records

- (BOOL)isSpillMarker:(id)value
{
	return [value isKindOfClass:NSDictionary.class]
		&& [((NSDictionary*)value)[kFxGripFrameDataKey_SpillFile] isKindOfClass:NSString.class];
}

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

- (nullable NSObject<NSSecureCoding, NSCopying> *)latestRecordAtOrBefore:(NSInteger)index
{
	NSInteger latest = [self latestIndexAtOrBefore:index];
	if (latest == NSNotFound) {
		return nil;
	}
	return [self recordAtIndex:latest];
}

@end
