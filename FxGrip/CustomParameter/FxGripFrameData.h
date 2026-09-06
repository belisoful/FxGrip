/*!
	@file       FxGripFrameData.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripFrameData
	@abstract   Per-frame custom parameter store with size-gated spill to the project media folder.
	@discussion Introduced in FxGrip 0.1.0. The store keys records by frame index for feedback-style
	            simulations where a frame derives from the previous one. A record whose archive exceeds
	            a size threshold spills to a machine-local cache folder, leaving a small marker in the
	            host document. The store does not interpolate.
*/

#ifndef FxGripFrameData_h
#define FxGripFrameData_h

#import "FxGripDictionary.h"

// Reserved header keys, exempt from record enumeration.
#define kFxGripFrameDataKey_InstanceUUID	@"__instanceUUID"
#define kFxGripFrameDataKey_SpillThreshold	@"__spillThreshold"
#define kFxGripFrameDataKey_FrameDuration	@"__frameDuration"

// Spill-marker keys: a record above the threshold is replaced by this dictionary and
// the archived record lives in the cache folder.
#define kFxGripFrameDataKey_SpillFile		@"__fxSpilledFrame"
#define kFxGripFrameDataKey_SpillLength		@"__fxSpilledLength"

#define kFxGripFrameDataDefaultSpillThreshold	((NSInteger)(4 * 1024 * 1024))
#define kFxGripFrameDataFileExtension			@"fxframe"

/*! spillThreshold value: no record ever spills. */
static const NSInteger kFxGripFrameDataNeverSpill = -1;

/*!
	@class      FxGripFrameData
	@abstract   Per-frame custom data keyed by frame index.
	@discussion Introduced in FxGrip 0.1.0. Records store under NSNumber frame-index keys;
				the store is sparse, and `latestRecordAtOrBefore:` serves the
				feedback-simulation seek: a frame whose maximum extent of influence is
				the previous frame re-simulates forward from the nearest stored index.
				String-keyed header entries (frame duration for arbitrary generator
				rates, the instance UUID, the spill threshold) ride alongside and
				persist with the store.

				Storage is size-gated. A record whose secure-coded archive exceeds
				`spillThreshold` is written to
				`<cacheURL>/<instanceUUID>/<index>.fxframe` and a small marker takes its
				place in the parameter, so the host document carries only the manifest;
				smaller records stay inline. `cacheURL` is machine-local state the
				owner configures after decode and is never encoded; without it nothing
				spills and everything stays inline. A document opened where the cache
				files are absent returns nil for spilled records, and the caller
				re-simulates.

				The spill home is the PROJECT MEDIA FOLDER
				(attachProjectMediaCacheForEffect:), which the host deletes with its
				project and carries with collected media. A user-domain folder is
				deliberately not a fallback: nothing ever clears it. Without a media
				folder the store spills nothing.

				Frame N depending only on frame N-1 means eviction is safe: any prefix
				of stored records may be removed and re-derived from the latest earlier
				record.

				The class does not interpolate; host keyframing blends nothing.
*/
@interface FxGripFrameData : FxGripDictionary

/*! Machine-local cache folder for spilled records. Not encoded. */
@property (copy, nullable, nonatomic) NSURL *cacheURL;

/*!
	@method     attachProjectMediaCacheForEffect:
	@abstract   Points the spill gate at the effect's project media folder.
	@discussion Introduced in FxGrip 0.1.0. The media folder exists only for a saved
				Motion project with Collect Media; without one the cache URL clears and
				every record stays inline. Call again to re-resolve after the project
				is saved. A sandboxed plug-in needs the security-scoped-bookmark
				entitlements to use the folder.
	@result     YES when a media folder is available and spilling is active.
*/
- (BOOL)attachProjectMediaCacheForEffect:(nullable id)effect;

/*! The archive-size gate in bytes. A record whose archive exceeds the threshold spills;
	0 spills every record; kFxGripFrameDataNeverSpill (any negative value) keeps every
	record inline. Persisted. */
@property (assign, nonatomic) NSInteger spillThreshold;

/*! A stable identity naming this store's cache subfolder; created on first use and
	persisted with the store. */
@property (readonly, nonnull, nonatomic) NSString *instanceUUID;

/*! The record at a frame index, loading a spilled record from the cache folder.
	Returns nil when nothing is stored or the cache file is absent. */
- (nullable NSObject<NSSecureCoding, NSCopying> *)recordAtIndex:(NSInteger)index;

/*! Stores a record, spilling it to the cache folder when its archive exceeds the
	threshold and a cache URL is set. */
- (BOOL)setRecord:(nonnull NSObject<NSSecureCoding, NSCopying> *)record atIndex:(NSInteger)index;

/*! Removes the record and its cache file. */
- (void)removeRecordAtIndex:(NSInteger)index;

/*! The stored frame indexes, ascending. */
- (nonnull NSArray<NSNumber*> *)frameIndexes;

/*! The greatest stored index at or before `index`; NSNotFound when none exists. */
- (NSInteger)latestIndexAtOrBefore:(NSInteger)index;

/*! The record at latestIndexAtOrBefore:. */
- (nullable NSObject<NSSecureCoding, NSCopying> *)latestRecordAtOrBefore:(NSInteger)index;

@end

#endif /* FxGripFrameData_h */
