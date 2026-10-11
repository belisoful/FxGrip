/*!
	@file       FxGripFCPXMLStoryElement.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLStoryElement
	@abstract   The story elements of a timeline, their markers, and their metadata.
	@discussion Introduced in FxGrip 0.1.0. A story element is anything scheduled in time: a
	            `sequence`, its `spine`, and the `clip`, `asset-clip`, `ref-clip`, `sync-clip`,
	            `mc-clip`, `video`, `audio`, `title`, `gap`, `transition`, `audition`, `caption`,
	            and `live-drawing` elements inside it. They share the clip attributes (`name`,
	            `lane`, `offset`, `start`, `duration`, `enabled`) and carry filters, markers,
	            anchored items, and intrinsic adjustments. ``FxGripFCPXMLMarker`` covers the marker
	            family and ``FxGripFCPXMLMetadata`` the `metadata` element's `md` entries.
*/

#ifndef FxGripFCPXMLStoryElement_h
#define FxGripFCPXMLStoryElement_h

#import <FxGrip/FxGripFCPXMLElement.h>
#import <FxGrip/FxGripFCPXMLFilter.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripFCPXMLMarker
	@abstract   A `marker`, `chapter-marker`, `keyword`, `rating`, `analysis-marker`, or `hidden-clip-marker`.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLMarker : FxGripFCPXMLElement

/*! The marker's start in the parent's local time. */
@property (readwrite) CMTime start;
/*! The marker's duration, or `kCMTimeInvalid`. */
@property (readwrite) CMTime duration;
/*! The marker text, keyword list, or rating (`favorite` or `reject`). */
@property (readwrite, copy, nullable) NSString *value;
/*! The note. */
@property (readwrite, copy, nullable) NSString *note;
/*! YES for a to-do marker that is completed; a marker with no `completed` attribute is not a to-do. */
@property (readwrite) BOOL completed;
/*! YES when the marker is a to-do item. */
@property (readonly) BOOL isToDo;
/*! The chapter marker's poster frame offset, or `kCMTimeInvalid`. */
@property (readwrite) CMTime posterOffset;

/*! A standard marker. */
+ (instancetype)markerAtStart:(CMTime)start value:(NSString *)value;
/*! A chapter marker. */
+ (instancetype)chapterMarkerAtStart:(CMTime)start value:(NSString *)value;
/*! A keyword range; `value` is a comma-separated keyword list. */
+ (instancetype)keywordAtStart:(CMTime)start duration:(CMTime)duration value:(NSString *)value;
/*! A favorite or reject range. */
+ (instancetype)ratingAtStart:(CMTime)start duration:(CMTime)duration value:(NSString *)value;

@end

/*!
	@class      FxGripFCPXMLMetadata
	@abstract   A `metadata` element: keyed `md` entries.
	@discussion Introduced in FxGrip 0.1.0. An entry holds a value string or an array of strings.
*/
@interface FxGripFCPXMLMetadata : FxGripFCPXMLElement

/*! The entry keys, in document order. */
@property (readonly, copy) NSArray<NSString *> *keys;
/*! The `md` entry for a key, or nil. */
- (nullable FxGripFCPXMLElement *)entryForMetadataKey:(NSString *)key;
/*! The value for a key, or nil; an array entry answers its strings joined by commas. */
- (nullable NSString *)valueForMetadataKey:(NSString *)key;
/*! The array strings for a key; empty when the entry holds a plain value. */
- (NSArray<NSString *> *)arrayForMetadataKey:(NSString *)key;
/*! Sets a value for a key with an optional type (`string`, `boolean`, `integer`, `float`,
	`date`, `timecode`); nil removes the entry. */
- (void)setValue:(nullable NSString *)value type:(nullable NSString *)type forMetadataKey:(NSString *)key;
/*! Sets an array of strings for a key. */
- (void)setArray:(NSArray<NSString *> *)strings forMetadataKey:(NSString *)key;

@end

/*!
	@class      FxGripFCPXMLStoryElement
	@abstract   A scheduled element of a timeline.
	@discussion Introduced in FxGrip 0.1.0. The class wraps every story element name; `kind`
				is the element name. Child accessors keep the DTD's grouping: adjustments, then
				contained and anchored items, then markers, then filters, then metadata.
*/
@interface FxGripFCPXMLStoryElement : FxGripFCPXMLElement

/*! The story element names the class wraps. */
+ (NSSet<NSString *> *)storyElementNames;
/*! YES when a name is a story element. */
+ (BOOL)isStoryElementName:(nullable NSString *)name;

/*! The element name: `clip`, `asset-clip`, `video`, `sequence`, and so on. */
@property (readonly, copy) NSString *kind;
/*! The display name. */
@property (readwrite, copy, nullable) NSString *clipName;
/*! The lane: 0 contained, positive above, negative below the parent. */
@property (readwrite) NSInteger lane;
/*! The position in the parent timeline, or `kCMTimeInvalid` for the default of zero. */
@property (readwrite) CMTime offset;
/*! The local timeline start, or `kCMTimeInvalid` for the default of zero. */
@property (readwrite) CMTime start;
/*! The duration, or `kCMTimeInvalid` when it comes from the media. */
@property (readwrite) CMTime duration;
/*! YES unless `enabled="0"`. */
@property (readwrite) BOOL enabled;
/*! The referenced resource identifier (`ref`) for a clip kind that carries one. */
@property (readwrite, copy, nullable) NSString *referenceIdentifier;
/*! The format resource identifier, where the kind overrides its parent's. */
@property (readwrite, copy, nullable) NSString *formatIdentifier;
/*! The role, such as `video` or `dialogue`. */
@property (readwrite, copy, nullable) NSString *role;
/*! The timecode start, or `kCMTimeInvalid`. */
@property (readwrite) CMTime timecodeStart;
/*! `DF` or `NDF`. */
@property (readwrite, copy, nullable) NSString *timecodeFormat;
/*! The audio start for a split edit, or `kCMTimeInvalid`. */
@property (readwrite) CMTime audioStart;
/*! The audio duration for a split edit, or `kCMTimeInvalid`. */
@property (readwrite) CMTime audioDuration;
/*! The offset plus the duration, or `kCMTimeInvalid` when either is absent. */
@property (readonly) CMTime endOffset;

/*! The `note` text, or nil. */
@property (readwrite, copy, nullable) NSString *note;

/*! The `spine` child of a sequence, or nil. */
@property (readonly, nullable) FxGripFCPXMLStoryElement *spine;
/*! The `spine` child, created when absent. */
- (FxGripFCPXMLStoryElement *)spineCreatingIfNeeded;

/*! The contained and anchored story elements, in document order. */
@property (readonly, copy) NSArray<FxGripFCPXMLStoryElement *> *storyChildren;
/*! The story children with a non-zero lane. */
@property (readonly, copy) NSArray<FxGripFCPXMLStoryElement *> *anchoredItems;
/*! Appends a story element, placed before the markers and filters. */
- (void)addStoryElement:(FxGripFCPXMLStoryElement *)element;

/*! The `filter-video` and `filter-video-mask` children, in order. */
@property (readonly, copy) NSArray<__kindof FxGripFCPXMLElement *> *videoFilterItems;
/*! The `filter-video` children, including those inside masks, in order. */
@property (readonly, copy) NSArray<FxGripFCPXMLFilter *> *videoFilters;
/*! The `filter-audio` children. */
@property (readonly, copy) NSArray<FxGripFCPXMLFilter *> *audioFilters;
/*! Appends a video filter after the last video filter item. */
- (void)addVideoFilter:(FxGripFCPXMLFilter *)filter;
/*! Appends an audio filter after the last audio filter. */
- (void)addAudioFilter:(FxGripFCPXMLFilter *)filter;
/*! The video filters that reference an effect identifier. */
- (NSArray<FxGripFCPXMLFilter *> *)videoFiltersWithEffectIdentifier:(NSString *)identifier;

/*! The marker-family children, in order. */
@property (readonly, copy) NSArray<FxGripFCPXMLMarker *> *markers;
/*! Inserts a marker after the last marker. */
- (void)addMarker:(FxGripFCPXMLMarker *)marker;

/*! The `metadata` child, or nil. */
@property (readonly, nullable) FxGripFCPXMLMetadata *metadata;
/*! The `metadata` child, created when absent. */
- (FxGripFCPXMLMetadata *)metadataCreatingIfNeeded;

/*! The intrinsic adjustment with a name, such as `adjust-transform`, or nil. */
- (nullable FxGripFCPXMLElement *)adjustmentNamed:(NSString *)name;
/*! The intrinsic adjustment with a name, created in place when absent. */
- (FxGripFCPXMLElement *)adjustmentNamed:(NSString *)name create:(BOOL)create;

/*! A `sequence` for a format identifier. */
+ (instancetype)sequenceWithFormatIdentifier:(NSString *)formatIdentifier duration:(CMTime)duration;
/*! A `gap` of a duration. */
+ (instancetype)gapWithDuration:(CMTime)duration;
/*! A `clip` with a name and duration. */
+ (instancetype)clipWithName:(nullable NSString *)name duration:(CMTime)duration;
/*! An `asset-clip` referencing an asset identifier. */
+ (instancetype)assetClipWithAssetIdentifier:(NSString *)identifier name:(nullable NSString *)name duration:(CMTime)duration;
/*! A `video` element referencing an asset or effect identifier. */
+ (instancetype)videoWithReferenceIdentifier:(NSString *)identifier name:(nullable NSString *)name duration:(CMTime)duration;
/*! A `title` referencing an effect identifier. */
+ (instancetype)titleWithEffectIdentifier:(NSString *)identifier name:(nullable NSString *)name duration:(CMTime)duration;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLStoryElement_h */
