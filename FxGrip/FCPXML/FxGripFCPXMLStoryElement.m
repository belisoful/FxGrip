/*!
	@file       FxGripFCPXMLStoryElement.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLStoryElement
	@abstract   The story elements of a timeline, their markers, and their metadata.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLStoryElement.h.
*/

#import <FxGrip/FxGripFCPXMLStoryElement.h>

#pragma mark - Marker

@implementation FxGripFCPXMLMarker

+ (NSString *)elementName { return @"marker"; }

+ (NSArray<NSString *> *)elementNames
{
	return @[@"marker", @"chapter-marker", @"keyword", @"rating", @"analysis-marker", @"hidden-clip-marker"];
}

+ (instancetype)markerAtStart:(CMTime)start value:(NSString *)value
{
	FxGripFCPXMLMarker *marker = [[self alloc] initWithElementName:@"marker"];
	marker.start = start;
	marker.value = value;
	return marker;
}

+ (instancetype)chapterMarkerAtStart:(CMTime)start value:(NSString *)value
{
	FxGripFCPXMLMarker *marker = [[self alloc] initWithElementName:@"chapter-marker"];
	marker.start = start;
	marker.value = value;
	return marker;
}

+ (instancetype)keywordAtStart:(CMTime)start duration:(CMTime)duration value:(NSString *)value
{
	FxGripFCPXMLMarker *marker = [[self alloc] initWithElementName:@"keyword"];
	marker.start = start;
	marker.duration = duration;
	marker.value = value;
	return marker;
}

+ (instancetype)ratingAtStart:(CMTime)start duration:(CMTime)duration value:(NSString *)value
{
	FxGripFCPXMLMarker *marker = [[self alloc] initWithElementName:@"rating"];
	marker.start = start;
	marker.duration = duration;
	marker.value = value;
	return marker;
}

- (CMTime)start { return [self timeForAttribute:@"start"]; }
- (void)setStart:(CMTime)start { [self setTime:start forAttribute:@"start"]; }
- (CMTime)duration { return [self timeForAttribute:@"duration"]; }
- (void)setDuration:(CMTime)duration { [self setTime:duration forAttribute:@"duration"]; }
- (NSString *)value { return [self stringForAttribute:@"value"]; }
- (void)setValue:(NSString *)value { [self setString:value forAttribute:@"value"]; }
- (NSString *)note { return [self stringForAttribute:@"note"]; }
- (void)setNote:(NSString *)note { [self setString:note forAttribute:@"note"]; }
- (BOOL)completed { return [self boolForAttribute:@"completed" defaultValue:NO]; }
- (void)setCompleted:(BOOL)completed { [self setBool:completed forAttribute:@"completed"]; }
- (BOOL)isToDo { return [self hasAttribute:@"completed"]; }
- (CMTime)posterOffset { return [self timeForAttribute:@"posterOffset"]; }
- (void)setPosterOffset:(CMTime)offset { [self setTime:offset forAttribute:@"posterOffset"]; }

@end

#pragma mark - Metadata

@implementation FxGripFCPXMLMetadata

+ (NSString *)elementName { return @"metadata"; }

- (NSArray<NSString *> *)keys
{
	NSMutableArray *keys = [NSMutableArray array];
	for (FxGripFCPXMLElement *entry in [self childrenNamed:@"md"]) {
		NSString *key = [entry stringForAttribute:@"key"];
		if (key != nil) {
			[keys addObject:key];
		}
	}
	return keys;
}

- (FxGripFCPXMLElement *)entryForMetadataKey:(NSString *)key
{
	for (FxGripFCPXMLElement *entry in [self childrenNamed:@"md"]) {
		if ([[entry stringForAttribute:@"key"] isEqualToString:key]) {
			return entry;
		}
	}
	return nil;
}

- (NSString *)valueForMetadataKey:(NSString *)key
{
	FxGripFCPXMLElement *entry = [self entryForMetadataKey:key];
	if (entry == nil) {
		return nil;
	}
	NSString *value = [entry stringForAttribute:@"value"];
	if (value != nil) {
		return value;
	}
	NSArray *strings = [self arrayForMetadataKey:key];
	return strings.count > 0 ? [strings componentsJoinedByString:@", "] : nil;
}

- (NSArray<NSString *> *)arrayForMetadataKey:(NSString *)key
{
	FxGripFCPXMLElement *array = [[self entryForMetadataKey:key] firstChildNamed:@"array"];
	NSMutableArray *strings = [NSMutableArray array];
	for (FxGripFCPXMLElement *string in [array childrenNamed:@"string"]) {
		[strings addObject:string.stringValue ?: @""];
	}
	return strings;
}

- (void)setValue:(NSString *)value type:(NSString *)type forMetadataKey:(NSString *)key
{
	FxGripFCPXMLElement *entry = [self entryForMetadataKey:key];
	if (value == nil) {
		[self removeChild:entry];
		return;
	}
	if (entry == nil) {
		entry = [FxGripFCPXMLElement elementNamed:@"md"];
		[entry setString:key forAttribute:@"key"];
		[self addChild:entry];
	}
	[entry removeChildrenNamed:@"array"];
	[entry setString:value forAttribute:@"value"];
	[entry setString:type forAttribute:@"type"];
}

- (void)setArray:(NSArray<NSString *> *)strings forMetadataKey:(NSString *)key
{
	FxGripFCPXMLElement *entry = [self entryForMetadataKey:key];
	if (entry == nil) {
		entry = [FxGripFCPXMLElement elementNamed:@"md"];
		[entry setString:key forAttribute:@"key"];
		[self addChild:entry];
	}
	[entry removeAttribute:@"value"];
	[entry removeChildrenNamed:@"array"];
	FxGripFCPXMLElement *array = [FxGripFCPXMLElement elementNamed:@"array"];
	for (NSString *string in strings) {
		FxGripFCPXMLElement *element = [FxGripFCPXMLElement elementNamed:@"string"];
		element.stringValue = string;
		[array addChild:element];
	}
	[entry addChild:array];
}

@end

#pragma mark - Story element

static NSSet<NSString *> *FxGripFCPXMLAdjustmentNames(void)
{
	static NSSet *names = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		names = [NSSet setWithArray:@[
			@"object-tracker", @"adjust-crop", @"adjust-corners", @"adjust-conform", @"adjust-transform",
			@"adjust-blend", @"adjust-stabilization", @"adjust-rollingShutter", @"adjust-360-transform",
			@"adjust-reorient", @"adjust-orientation", @"adjust-cinematic", @"adjust-colorConform",
			@"adjust-stereo-3D", @"adjust-volume", @"adjust-panner", @"adjust-loudness",
			@"adjust-noiseReduction", @"adjust-humReduction", @"adjust-EQ", @"adjust-matchEQ",
			@"adjust-voiceIsolation", @"conform-rate", @"timeMap",
		]];
	});
	return names;
}

@implementation FxGripFCPXMLStoryElement

+ (NSString *)elementName { return @"clip"; }

+ (NSSet<NSString *> *)storyElementNames
{
	static NSSet *names = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		names = [NSSet setWithArray:@[
			@"sequence", @"spine", @"clip", @"asset-clip", @"ref-clip", @"sync-clip", @"mc-clip",
			@"video", @"audio", @"title", @"gap", @"transition", @"audition", @"caption",
			@"live-drawing", @"mc-angle", @"multicam",
		]];
	});
	return names;
}

+ (NSArray<NSString *> *)elementNames
{
	return [self.storyElementNames.allObjects sortedArrayUsingSelector:@selector(compare:)];
}

+ (BOOL)isStoryElementName:(NSString *)name
{
	return name != nil && [self.storyElementNames containsObject:name];
}

#pragma mark Factories

+ (instancetype)sequenceWithFormatIdentifier:(NSString *)formatIdentifier duration:(CMTime)duration
{
	FxGripFCPXMLStoryElement *sequence = [[self alloc] initWithElementName:@"sequence"];
	sequence.formatIdentifier = formatIdentifier;
	sequence.duration = duration;
	[sequence spineCreatingIfNeeded];
	return sequence;
}

+ (instancetype)gapWithDuration:(CMTime)duration
{
	FxGripFCPXMLStoryElement *gap = [[self alloc] initWithElementName:@"gap"];
	gap.duration = duration;
	return gap;
}

+ (instancetype)clipWithName:(NSString *)name duration:(CMTime)duration
{
	FxGripFCPXMLStoryElement *clip = [[self alloc] initWithElementName:@"clip"];
	clip.clipName = name;
	clip.duration = duration;
	return clip;
}

+ (instancetype)assetClipWithAssetIdentifier:(NSString *)identifier name:(NSString *)name duration:(CMTime)duration
{
	FxGripFCPXMLStoryElement *clip = [[self alloc] initWithElementName:@"asset-clip"];
	clip.referenceIdentifier = identifier;
	clip.clipName = name;
	clip.duration = duration;
	return clip;
}

+ (instancetype)videoWithReferenceIdentifier:(NSString *)identifier name:(NSString *)name duration:(CMTime)duration
{
	FxGripFCPXMLStoryElement *video = [[self alloc] initWithElementName:@"video"];
	video.referenceIdentifier = identifier;
	video.clipName = name;
	video.duration = duration;
	return video;
}

+ (instancetype)titleWithEffectIdentifier:(NSString *)identifier name:(NSString *)name duration:(CMTime)duration
{
	FxGripFCPXMLStoryElement *title = [[self alloc] initWithElementName:@"title"];
	title.referenceIdentifier = identifier;
	title.clipName = name;
	title.duration = duration;
	return title;
}

#pragma mark Attributes

- (NSString *)kind { return self.name; }
- (NSString *)clipName { return [self stringForAttribute:@"name"]; }
- (void)setClipName:(NSString *)name { [self setString:name forAttribute:@"name"]; }
- (NSInteger)lane { return [self integerForAttribute:@"lane" defaultValue:0]; }

- (void)setLane:(NSInteger)lane
{
	if (lane == 0) {
		[self removeAttribute:@"lane"];
	} else {
		[self setInteger:lane forAttribute:@"lane"];
	}
}

- (CMTime)offset { return [self timeForAttribute:@"offset"]; }
- (void)setOffset:(CMTime)offset { [self setTime:offset forAttribute:@"offset"]; }
- (CMTime)start { return [self timeForAttribute:@"start"]; }
- (void)setStart:(CMTime)start { [self setTime:start forAttribute:@"start"]; }
- (CMTime)duration { return [self timeForAttribute:@"duration"]; }
- (void)setDuration:(CMTime)duration { [self setTime:duration forAttribute:@"duration"]; }
- (BOOL)enabled { return [self boolForAttribute:@"enabled" defaultValue:YES]; }

- (void)setEnabled:(BOOL)enabled
{
	if (enabled) {
		[self removeAttribute:@"enabled"];
	} else {
		[self setBool:NO forAttribute:@"enabled"];
	}
}

- (NSString *)referenceIdentifier { return [self stringForAttribute:@"ref"]; }
- (void)setReferenceIdentifier:(NSString *)identifier { [self setString:identifier forAttribute:@"ref"]; }
- (NSString *)formatIdentifier { return [self stringForAttribute:@"format"]; }
- (void)setFormatIdentifier:(NSString *)identifier { [self setString:identifier forAttribute:@"format"]; }
- (NSString *)role { return [self stringForAttribute:@"role"]; }
- (void)setRole:(NSString *)role { [self setString:role forAttribute:@"role"]; }
- (CMTime)timecodeStart { return [self timeForAttribute:@"tcStart"]; }
- (void)setTimecodeStart:(CMTime)start { [self setTime:start forAttribute:@"tcStart"]; }
- (NSString *)timecodeFormat { return [self stringForAttribute:@"tcFormat"]; }
- (void)setTimecodeFormat:(NSString *)format { [self setString:format forAttribute:@"tcFormat"]; }
- (CMTime)audioStart { return [self timeForAttribute:@"audioStart"]; }
- (void)setAudioStart:(CMTime)start { [self setTime:start forAttribute:@"audioStart"]; }
- (CMTime)audioDuration { return [self timeForAttribute:@"audioDuration"]; }
- (void)setAudioDuration:(CMTime)duration { [self setTime:duration forAttribute:@"audioDuration"]; }

- (CMTime)endOffset
{
	CMTime offset = self.offset;
	CMTime duration = self.duration;
	if (!CMTIME_IS_NUMERIC(duration)) {
		return kCMTimeInvalid;
	}
	return CMTimeAdd(CMTIME_IS_NUMERIC(offset) ? offset : kCMTimeZero, duration);
}

- (NSString *)note
{
	return [self firstChildNamed:@"note"].stringValue;
}

- (void)setNote:(NSString *)note
{
	[self removeChildrenNamed:@"note"];
	if (note != nil) {
		FxGripFCPXMLElement *element = [FxGripFCPXMLElement elementNamed:@"note"];
		element.stringValue = note;
		[self insertChild:element atIndex:0];
	}
}

#pragma mark Children

- (FxGripFCPXMLStoryElement *)spine
{
	return [self firstChildNamed:@"spine"];
}

- (FxGripFCPXMLStoryElement *)spineCreatingIfNeeded
{
	FxGripFCPXMLStoryElement *spine = self.spine;
	if (spine == nil) {
		spine = [[FxGripFCPXMLStoryElement alloc] initWithElementName:@"spine"];
		[self addStoryElement:spine];
	}
	return spine;
}

- (NSArray<FxGripFCPXMLStoryElement *> *)storyChildren
{
	NSMutableArray *children = [NSMutableArray array];
	for (FxGripFCPXMLElement *child in self.children) {
		if ([child isKindOfClass:FxGripFCPXMLStoryElement.class]) {
			[children addObject:child];
		}
	}
	return children;
}

- (NSArray<FxGripFCPXMLStoryElement *> *)anchoredItems
{
	NSMutableArray *items = [NSMutableArray array];
	for (FxGripFCPXMLStoryElement *child in self.storyChildren) {
		if (child.lane != 0) {
			[items addObject:child];
		}
	}
	return items;
}

/*! The index at which a child of a DTD group is appended: after the last element of that group
	or of any earlier group, before the first element of a later group. */
- (NSUInteger)insertionIndexForGroup:(NSUInteger)group
{
	// Groups in DTD order: 0 note and adjustments, 1 story items, 2 markers, 3 filters and
	// audio sources, 4 metadata.
	NSUInteger index = 0;
	for (FxGripFCPXMLElement *child in self.children) {
		NSUInteger childGroup = 4;
		NSString *name = child.name;
		if ([name isEqualToString:@"note"] || [FxGripFCPXMLAdjustmentNames() containsObject:name]) {
			childGroup = 0;
		} else if ([FxGripFCPXMLStoryElement isStoryElementName:name] || [name isEqualToString:@"text"]
				   || [name isEqualToString:@"text-style-def"] || [name isEqualToString:@"param"]) {
			childGroup = 1;
		} else if ([FxGripFCPXMLMarker.elementNames containsObject:name]) {
			childGroup = 2;
		} else if ([name hasPrefix:@"filter-"] || [name hasSuffix:@"-source"]) {
			childGroup = 3;
		}
		if (childGroup <= group) {
			index = child.xmlElement.index + 1;
		}
	}
	return index;
}

- (void)addStoryElement:(FxGripFCPXMLStoryElement *)element
{
	[self insertChild:element atIndex:[self insertionIndexForGroup:1]];
}

- (NSArray *)videoFilterItems
{
	NSMutableArray *items = [NSMutableArray array];
	for (FxGripFCPXMLElement *child in self.children) {
		if ([child.name isEqualToString:@"filter-video"] || [child.name isEqualToString:@"filter-video-mask"]) {
			[items addObject:child];
		}
	}
	return items;
}

- (NSArray<FxGripFCPXMLFilter *> *)videoFilters
{
	NSMutableArray *filters = [NSMutableArray array];
	for (FxGripFCPXMLElement *item in self.videoFilterItems) {
		if ([item isKindOfClass:FxGripFCPXMLFilter.class]) {
			[filters addObject:item];
		} else if ([item isKindOfClass:FxGripFCPXMLFilterMask.class]) {
			[filters addObjectsFromArray:[item childrenNamed:@"filter-video"]];
		}
	}
	return filters;
}

- (NSArray<FxGripFCPXMLFilter *> *)audioFilters
{
	return [self childrenNamed:@"filter-audio"];
}

- (void)addVideoFilter:(FxGripFCPXMLFilter *)filter
{
	NSUInteger index = [self insertionIndexForGroup:2];
	for (FxGripFCPXMLElement *child in self.children) {
		if ([child.name isEqualToString:@"filter-video"] || [child.name isEqualToString:@"filter-video-mask"]
			|| [child.name hasSuffix:@"-source"]) {
			index = child.xmlElement.index + 1;
		}
	}
	[self insertChild:filter atIndex:index];
}

- (void)addAudioFilter:(FxGripFCPXMLFilter *)filter
{
	[self insertChild:filter atIndex:[self insertionIndexForGroup:3]];
}

- (NSArray<FxGripFCPXMLFilter *> *)videoFiltersWithEffectIdentifier:(NSString *)identifier
{
	NSMutableArray *filters = [NSMutableArray array];
	for (FxGripFCPXMLFilter *filter in self.videoFilters) {
		if ([filter.effectIdentifier isEqualToString:identifier]) {
			[filters addObject:filter];
		}
	}
	return filters;
}

- (NSArray<FxGripFCPXMLMarker *> *)markers
{
	NSMutableArray *markers = [NSMutableArray array];
	for (FxGripFCPXMLElement *child in self.children) {
		if ([child isKindOfClass:FxGripFCPXMLMarker.class]) {
			[markers addObject:child];
		}
	}
	return markers;
}

- (void)addMarker:(FxGripFCPXMLMarker *)marker
{
	[self insertChild:marker atIndex:[self insertionIndexForGroup:2]];
}

- (FxGripFCPXMLMetadata *)metadata
{
	return [self firstChildNamed:@"metadata"];
}

- (FxGripFCPXMLMetadata *)metadataCreatingIfNeeded
{
	FxGripFCPXMLMetadata *metadata = self.metadata;
	if (metadata == nil) {
		metadata = [[FxGripFCPXMLMetadata alloc] init];
		[self addChild:metadata];
	}
	return metadata;
}

- (FxGripFCPXMLElement *)adjustmentNamed:(NSString *)name
{
	return [self firstChildNamed:name];
}

- (FxGripFCPXMLElement *)adjustmentNamed:(NSString *)name create:(BOOL)create
{
	FxGripFCPXMLElement *adjustment = [self firstChildNamed:name];
	if (adjustment == nil && create) {
		adjustment = [FxGripFCPXMLElement elementNamed:name];
		[self insertChild:adjustment atIndex:[self insertionIndexForGroup:0]];
	}
	return adjustment;
}

@end
