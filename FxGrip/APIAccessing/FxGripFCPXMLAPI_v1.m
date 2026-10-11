/*!
	@file       FxGripFCPXMLAPI_v1.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLAPI_v1
	@abstract   Captures the effect as an FCPXML filter and applies an FCPXML filter to it.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLAPI_v1.h.
*/

#import <FxGrip/FxGripFCPXMLAPI_v1.h>
#import <FxGrip/FxGripAPIAccessing.h>
#import <FxGrip/FxGripPresetsAPI_v1.h>
#import <FxGrip/FxGripParameterInfoAPI_v1.h>
#import <FxGrip/FxGripParameterSettingAPI_v5.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Timing.h>
#import <AVFoundation/AVTime.h>
#import <FxGrip/FxGripPreset+FCPXML.h>
#import <FxGrip/FxGripFCPXMLValue.h>
#import <FxGrip/FxGripFCPXMLTime.h>
#import <FxGrip/FxGripFCPXMLStoryElement.h>
#import <FxGrip/FxGripFCPXMLLibrary.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/NSDictionary+FxGripTileableEffect.h>
#import "FxGrip_ARC.h"

/*! A display name from the plist is a string or a per-language dictionary; take the
	string, or the "English" entry, or any entry. */
static NSString *FxGripFCPXMLDisplayNameString(id displayName)
{
	if ([displayName isKindOfClass:NSString.class]) {
		return displayName;
	}
	if ([displayName isKindOfClass:NSDictionary.class]) {
		NSDictionary *names = displayName;
		NSString *english = names[@"English"];
		if ([english isKindOfClass:NSString.class]) {
			return english;
		}
		for (id value in names.allValues) {
			if ([value isKindOfClass:NSString.class]) {
				return value;
			}
		}
	}
	return nil;
}

@interface FxGripFCPXMLAPI_v1 ()
@property (assign, readwrite, nullable) id<FxGripFCPXMLAPI_v1> api;
@end

@implementation FxGripFCPXMLAPI_v1

- (instancetype)initWithAPI:(id<FxGripFCPXMLAPI_v1>)api effect:(id<FxGripEffectHost>)effect
{
	self = [super initWithEffect:effect];
	if (self) {
		_api = api;
	}
	return self;
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description
{
	return [NSError errorWithDomain:FxGripPlugErrorDomain code:code
						   userInfo:@{NSLocalizedDescriptionKey: description}];
}

#pragma mark - Identity

- (NSString *)pluginUUID
{
	return FxGripHostPluginUUID(self.effect) ?: @"";
}

- (NSString *)effectUID
{
	return [FxGripFCPXMLEffect uidForFxPlugUUID:self.pluginUUID];
}

- (NSString *)pluginDisplayName
{
	NSString *name = FxGripFCPXMLDisplayNameString(FxGripHostPluginProperties(self.effect)[kProPlugPlugIn_DisplayNameProperty]);
	if (name.length == 0) {
		name = self.effect.effectBase.pluginDisplayName;
	}
	return name.length > 0 ? name : self.pluginUUID;
}

- (FxGripFCPXMLEffect *)effectResource
{
	return [FxGripFCPXMLEffect effectWithFxPlugUUID:self.pluginUUID name:self.pluginDisplayName];
}

- (BOOL)isCompatiblePluginUUID:(NSString *)uuid
{
	if (uuid.length == 0) {
		return NO;
	}
	if ([uuid caseInsensitiveCompare:self.pluginUUID] == NSOrderedSame) {
		return YES;
	}
	NSArray *alternatives = FxGripHostPluginProperties(self.effect)[kProPlugPlugIn_SupportedPluginsProperty];
	if (![alternatives isKindOfClass:NSArray.class]) {
		return NO;
	}
	for (id alternative in alternatives) {
		if ([alternative isKindOfClass:NSString.class] && [uuid caseInsensitiveCompare:alternative] == NSOrderedSame) {
			return YES;
		}
	}
	return NO;
}

- (BOOL)isCompatibleFilter:(FxGripFCPXMLFilter *)filter
{
	FxGripFCPXMLEffect *effect = filter.effect;
	if (effect == nil) {
		// A filter outside a document, or one whose reference resolves to nothing, carries no
		// identity to check.
		return YES;
	}
	return [self isCompatiblePluginUUID:effect.fxPlugUUID];
}

- (NSArray<FxGripFCPXMLFilter *> *)compatibleFiltersInDocument:(FxGripFCPXMLDocument *)document
{
	NSMutableArray *filters = [NSMutableArray array];
	for (FxGripFCPXMLFilter *filter in [document elementsNamed:@"filter-video"]) {
		if ([self isCompatiblePluginUUID:filter.effect.fxPlugUUID]) {
			[filters addObject:filter];
		}
	}
	return filters;
}

#pragma mark - Parameter access

- (NSArray<NSNumber *> *)parameterIDs
{
	NSDictionary *parameters = self.effect.effectBase.parameters;
	return [parameters.allKeys sortedArrayUsingSelector:@selector(compare:)];
}

- (NSString *)nameOfParameter:(FxParameterId)parameterID
{
	id<FxGripParameter> parameter = self.effect.effectBase.parameters[@(parameterID)];
	NSString *name = parameter.parameterName;
	return name.length > 0 ? name : [NSString stringWithFormat:@"Parameter %u", parameterID];
}

- (FxParameterType)typeOfParameter:(FxParameterId)parameterID
{
	id<FxGripParameterInfoAPI_v1> info = self.effect.apiManager.parameterInfoAPIv1;
	FxParameterType type = info ? [info parameterType:parameterID] : FxParameterType_None;
	if (type == FxParameterType_None) {
		type = self.effect.effectBase.parameters[@(parameterID)].parameterType;
	}
	return type;
}

- (NSNumber *)parameterIDForKey:(NSString *)key
{
	if (key.length == 0) {
		return nil;
	}
	NSScanner *scanner = [NSScanner scannerWithString:key];
	NSInteger parameterID = 0;
	if (![scanner scanInteger:&parameterID] || !scanner.isAtEnd || parameterID < 0) {
		return nil;
	}
	return self.effect.effectBase.parameters[@(parameterID)] != nil ? @(parameterID) : nil;
}

- (NSNumber *)parameterIDForName:(NSString *)name
{
	if (name.length == 0) {
		return nil;
	}
	for (NSNumber *pid in self.parameterIDs) {
		if ([[self nameOfParameter:pid.unsignedIntValue] isEqualToString:name]) {
			return pid;
		}
	}
	return nil;
}

#pragma mark - Capture

- (NSError *)captureFilter:(FxGripFCPXMLFilter **)filter atTime:(CMTime)time options:(FxGripFCPXMLCaptureOptions)options
{
	if (filter == NULL) {
		return [self errorWithCode:kFxGripError_FCPXML description:@"No filter out-parameter."];
	}
	*filter = nil;
	id<FxGripEffectHost> effect = self.effect;
	id<FxParameterSettingAPI_v5> setterAPI = effect.apiManager.paramSetAPIv5;
	id<FxParameterRetrievalAPI_v6> getterAPI = effect.apiManager.paramGetAPIv6;
	if (setterAPI == nil || getterAPI == nil) {
		return [self errorWithCode:kFxGripError_FCPXML description:@"The parameter APIs are unavailable."];
	}
	id<FxKeyframeAPI_v3> keyframeAPI = (options & FxGripFCPXMLCaptureKeyframes) ? effect.apiManager.keyframeAPIv3 : nil;

	FxGripFCPXMLFilter *captured = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:nil name:self.pluginDisplayName];
	for (NSNumber *pid in self.parameterIDs) {
		FxParameterId parameterID = pid.unsignedIntValue;
		FxParameterFlags flags = 0;
		[getterAPI getParameterFlags:&flags fromParameter:parameterID];
		if (flagNoValue(flags)) {
			continue;
		}
		if ((options & FxGripFCPXMLCaptureOmitHidden) && (flags & kFxParameterFlag_HIDDEN)) {
			continue;
		}
		FxParameterType type = [self typeOfParameter:parameterID];
		if (type == FxParameterType_Custom && !(options & FxGripFCPXMLCaptureCustomValues)) {
			continue;
		}
		id value = nil;
		if (![FxGripPreset getParameterValue:&value toParameter:parameterID atTime:time withAPI:setterAPI] || value == nil) {
			continue;
		}
		FxGripFCPXMLParam *param = [FxGripFCPXMLParam paramWithName:[self nameOfParameter:parameterID]
																key:pid.stringValue value:nil];
		NSString *string = [FxGripFCPXMLValue stringForValue:value type:type];
		if (string != nil) {
			param.value = string;
		} else {
			[FxGripPreset writeValue:value toParam:param];
		}
		if (keyframeAPI != nil && string != nil) {
			[self captureKeyframesOfParameter:parameterID type:type intoParam:param
								  keyframeAPI:keyframeAPI setterAPI:setterAPI];
		}
		[captured addParam:param];
	}
	*filter = captured;
	return nil;
}

- (NSString *)interpolationForSegmentStyle:(FxKeyframeSegmentStyle)style
{
	switch (style) {
		case kFxKeyframeSegmentStyle_EaseInNext:
			return FxGripFCPXMLKeyframeInterpolationEaseIn;
		case kFxKeyframeSegmentStyle_EaseOutCurrent:
			return FxGripFCPXMLKeyframeInterpolationEaseOut;
		case kFxKeyframeSegmentStyle_EaseOutCurrentEaseInNext:
		case kFxKeyframeSegmentStyle_Bezier:
		case kFxKeyframeSegmentStyle_Continuous:
			return FxGripFCPXMLKeyframeInterpolationEase;
		default:
			return FxGripFCPXMLKeyframeInterpolationLinear;
	}
}

- (void)captureKeyframesOfParameter:(FxParameterId)parameterID
							   type:(FxParameterType)type
						  intoParam:(FxGripFCPXMLParam *)param
						keyframeAPI:(id<FxKeyframeAPI_v3>)keyframeAPI
						  setterAPI:(id<FxParameterSettingAPI_v5>)setterAPI
{
	NSUInteger channelCount = 0;
	if ([keyframeAPI channelCount:&channelCount forParameter:parameterID] != nil || channelCount == 0) {
		return;
	}
	// The keyframe times of every channel, merged, each with the segment style of its first channel.
	NSMutableDictionary<NSValue *, NSNumber *> *stylesByTime = [NSMutableDictionary dictionary];
	NSMutableArray<NSValue *> *times = [NSMutableArray array];
	for (NSUInteger channel = 0; channel < channelCount; channel++) {
		NSUInteger keyframeCount = 0;
		if ([keyframeAPI keyframeCount:&keyframeCount forParameter:parameterID andChannel:channel] != nil) {
			continue;
		}
		for (NSUInteger index = 0; index < keyframeCount; index++) {
			FxKeyframe keyframe = {0};
			keyframe.version = 1;
			if ([keyframeAPI keyframe:&keyframe forParameter:parameterID channel:channel andIndex:index] != nil) {
				continue;
			}
			NSValue *key = [NSValue valueWithCMTime:keyframe.time];
			if (stylesByTime[key] == nil) {
				stylesByTime[key] = @(keyframe.segmentStyle);
				[times addObject:key];
			}
		}
	}
	if (times.count == 0) {
		return;
	}
	[times sortUsingComparator:^NSComparisonResult(NSValue *lhs, NSValue *rhs) {
		int32_t comparison = CMTimeCompare(lhs.CMTimeValue, rhs.CMTimeValue);
		return comparison < 0 ? NSOrderedAscending : (comparison > 0 ? NSOrderedDescending : NSOrderedSame);
	}];
	FxGripFCPXMLKeyframeAnimation *animation = [param keyframeAnimationCreatingIfNeeded];
	for (NSValue *key in times) {
		CMTime time = key.CMTimeValue;
		id value = nil;
		if (![FxGripPreset getParameterValue:&value toParameter:parameterID atTime:time withAPI:setterAPI]) {
			continue;
		}
		NSString *string = [FxGripFCPXMLValue stringForValue:value type:type];
		if (string == nil) {
			continue;
		}
		FxGripFCPXMLKeyframe *keyframe = [animation addKeyframeAtTime:time value:string];
		NSString *interpolation = [self interpolationForSegmentStyle:(FxKeyframeSegmentStyle)stylesByTime[key].unsignedIntegerValue];
		if (![interpolation isEqualToString:FxGripFCPXMLKeyframeInterpolationLinear]) {
			keyframe.interpolation = interpolation;
		}
	}
}

- (CMTime)effectDuration
{
	FxGripTileableEffect *base = self.effect.effectBase;
	CMTime duration = kCMTimeInvalid;
	if ([base respondsToSelector:@selector(effectDurationTime)]) {
		duration = base.effectDurationTime;
	}
	if (!CMTIME_IS_NUMERIC(duration) || CMTimeCompare(duration, kCMTimeZero) <= 0) {
		duration = CMTimeMake(1, 1);
	}
	return duration;
}

- (NSError *)captureDocument:(FxGripFCPXMLDocument **)document atTime:(CMTime)time options:(FxGripFCPXMLCaptureOptions)options
{
	if (document == NULL) {
		return [self errorWithCode:kFxGripError_FCPXML description:@"No document out-parameter."];
	}
	*document = nil;
	FxGripFCPXMLFilter *filter = nil;
	NSError *error = [self captureFilter:&filter atTime:time options:options];
	if (error != nil) {
		return error;
	}
	FxGripFCPXMLDocument *captured = [[FxGripFCPXMLDocument alloc] init];
	FxGripFCPXMLEffect *effect = [captured.resources effectForFxPlugUUID:self.pluginUUID name:self.pluginDisplayName];
	filter.effectIdentifier = effect.identifier;
	FxGripFCPXMLStoryElement *clip = [FxGripFCPXMLStoryElement clipWithName:self.pluginDisplayName duration:self.effectDuration];
	[clip addVideoFilter:filter];
	[[captured.libraryCreatingIfNeeded firstEventCreatingIfNeeded] addItem:clip];
	*document = captured;
	return nil;
}

#pragma mark - Apply

- (NSError *)applyFilter:(FxGripFCPXMLFilter *)filter atTime:(CMTime)time options:(FxGripFCPXMLApplyOptions)options
{
	if (filter == nil) {
		return [self errorWithCode:kFxGripError_FCPXML description:@"No filter to apply."];
	}
	if (!(options & FxGripFCPXMLApplyIgnoreCompatibility) && ![self isCompatibleFilter:filter]) {
		return [self errorWithCode:kFxGripError_FCPXMLIncompatible
					   description:[NSString stringWithFormat:@"The filter's effect '%@' is not this plug-in.",
									filter.effect.uid ?: filter.effectIdentifier ?: @""]];
	}
	id<FxGripEffectHost> effect = self.effect;
	id<FxGripPresetsAPI_v1> presetsAPI = effect.apiManager.presetsAPIv1;
	if (presetsAPI == nil) {
		return [self errorWithCode:kFxGripError_FCPXML description:@"The presets API is unavailable."];
	}

	// Resolve each param to a parameter ID, then split the static values from the animated ones.
	NSMutableDictionary<NSString *, id> *staticValues = [NSMutableDictionary dictionary];
	NSMutableDictionary<NSValue *, NSMutableDictionary *> *valuesByTime = [NSMutableDictionary dictionary];
	NSMutableDictionary<NSString *, FxGripFCPXMLParam *> *animatedParams = [NSMutableDictionary dictionary];
	for (FxGripFCPXMLParam *param in filter.params) {
		NSNumber *pid = [self parameterIDForKey:param.key];
		if (pid == nil && ((options & FxGripFCPXMLApplyMatchNames) || param.key.length == 0)) {
			pid = [self parameterIDForName:param.paramName];
		}
		if (pid == nil) {
			continue;
		}
		FxParameterType type = [self typeOfParameter:pid.unsignedIntValue];
		NSSet<Class> *classes = [self.effect.effectBase.parameters[pid].class respondsToSelector:@selector(customValueClasses)]
			? [(id)self.effect.effectBase.parameters[pid].class customValueClasses] : nil;
		id value = (type == FxParameterType_Custom)
			? [FxGripPreset valueFromParam:param archiveClasses:classes]
			: [FxGripFCPXMLValue valueForString:param.value type:type];
		if (value != nil) {
			staticValues[pid.stringValue] = value;
		}
		if (param.isAnimated && !(options & FxGripFCPXMLApplyIgnoreKeyframes) && type != FxParameterType_Custom) {
			animatedParams[pid.stringValue] = param;
			for (FxGripFCPXMLKeyframe *keyframe in param.keyframeAnimation.keyframes) {
				id keyframeValue = [FxGripFCPXMLValue valueForString:keyframe.value type:type];
				if (keyframeValue == nil || !CMTIME_IS_NUMERIC(keyframe.time)) {
					continue;
				}
				NSValue *key = [NSValue valueWithCMTime:keyframe.time];
				NSMutableDictionary *values = valuesByTime[key];
				if (values == nil) {
					values = [NSMutableDictionary dictionary];
					valuesByTime[key] = values;
				}
				values[pid.stringValue] = keyframeValue;
			}
		}
	}
	if (staticValues.count == 0 && valuesByTime.count == 0) {
		return nil;
	}

	FxGripParameterPresetFlags presetFlags = kFxParameterPreset_IgnoreCompatibility | kFxParameterPreset_IgnoreMetaData;
	if (options & FxGripFCPXMLApplyIgnoreTagBoundary) {
		presetFlags |= kFxParameterPreset_IgnoreTagBoundary;
	}
	id<FxUndoAPI> undoAPI = (options & FxGripFCPXMLApplyUndoGroup) ? effect.apiManager.undoAPIv1 : nil;
	BOOL grouped = undoAPI != nil && [undoAPI startUndoGroup:[NSString stringWithFormat:@"Apply %@", filter.nameOverride ?: filter.filterName ?: @"FCPXML"]];

	NSError *firstError = nil;
	// Static values first, at the apply time, including the initial value of each animated param.
	if (staticValues.count > 0) {
		firstError = [presetsAPI setPreset:[self presetWithValues:staticValues label:filter.filterName]
								   options:presetFlags atTime:time];
	}
	// Then each keyframe time, with a host keyframe added where the keyframe API is vended.
	id<FxKeyframeAPI_v3> keyframeAPI = effect.apiManager.keyframeAPIv3;
	NSArray<NSValue *> *times = [valuesByTime.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSValue *lhs, NSValue *rhs) {
		int32_t comparison = CMTimeCompare(lhs.CMTimeValue, rhs.CMTimeValue);
		return comparison < 0 ? NSOrderedAscending : (comparison > 0 ? NSOrderedDescending : NSOrderedSame);
	}];
	for (NSValue *key in times) {
		CMTime keyframeTime = key.CMTimeValue;
		NSDictionary *values = valuesByTime[key];
		if (keyframeAPI != nil) {
			for (NSString *pidString in values) {
				[self addHostKeyframeAtTime:keyframeTime toParameter:(FxParameterId)pidString.integerValue
									   param:animatedParams[pidString] keyframeAPI:keyframeAPI];
			}
		}
		NSError *error = [presetsAPI setPreset:[self presetWithValues:values label:filter.filterName]
									   options:presetFlags atTime:keyframeTime];
		if (error != nil && firstError == nil) {
			firstError = error;
		}
	}
	if (grouped) {
		[undoAPI endUndoGroup];
	}
	return firstError;
}

- (void)addHostKeyframeAtTime:(CMTime)time
				  toParameter:(FxParameterId)parameterID
						param:(FxGripFCPXMLParam *)param
				  keyframeAPI:(id<FxKeyframeAPI_v3>)keyframeAPI
{
	NSUInteger channelCount = 0;
	if ([keyframeAPI channelCount:&channelCount forParameter:parameterID] != nil) {
		return;
	}
	FxGripFCPXMLKeyframe *keyframe = [param.keyframeAnimation keyframeAtTime:time];
	FxKeyframeSegmentStyle style = kFxKeyframeSegmentStyle_Linear;
	NSString *interpolation = keyframe.interpolation;
	if ([interpolation isEqualToString:FxGripFCPXMLKeyframeInterpolationEaseIn]) {
		style = kFxKeyframeSegmentStyle_EaseInNext;
	} else if ([interpolation isEqualToString:FxGripFCPXMLKeyframeInterpolationEaseOut]) {
		style = kFxKeyframeSegmentStyle_EaseOutCurrent;
	} else if ([interpolation isEqualToString:FxGripFCPXMLKeyframeInterpolationEase]) {
		style = kFxKeyframeSegmentStyle_EaseOutCurrentEaseInNext;
	}
	for (NSUInteger channel = 0; channel < channelCount; channel++) {
		BOOL present = NO;
		if ([keyframeAPI parameter:parameterID channel:channel hasKeyframe:&present atTime:time] == nil && present) {
			continue;
		}
		FxKeyframe hostKeyframe = {0};
		hostKeyframe.version = 1;
		hostKeyframe.time = time;
		hostKeyframe.segmentStyle = style;
		[keyframeAPI addKeyframe:&hostKeyframe toParameter:parameterID andChannel:channel];
	}
}

- (FxGripPreset *)presetWithValues:(NSDictionary *)values label:(NSString *)label
{
	FxGripPreset *preset = NARC_AUTORELEASE([[FxGripPreset alloc] init]);
	preset.parameterValues = values;
	preset.name = label;
	preset.framework = @"FxGrip";
	preset.pluginUuid = self.pluginUUID;
	return preset;
}

- (NSError *)applyDocument:(FxGripFCPXMLDocument *)document atTime:(CMTime)time options:(FxGripFCPXMLApplyOptions)options
{
	if (document == nil) {
		return [self errorWithCode:kFxGripError_FCPXML description:@"No document to apply."];
	}
	FxGripFCPXMLFilter *filter = (options & FxGripFCPXMLApplyIgnoreCompatibility)
		? [document elementsNamed:@"filter-video"].firstObject
		: [self compatibleFiltersInDocument:document].firstObject;
	if (filter == nil) {
		return [self errorWithCode:kFxGripError_FCPXMLIncompatible
					   description:@"The document carries no filter for this plug-in."];
	}
	return [self applyFilter:filter atTime:time options:options];
}

#pragma mark - Presets

- (FxGripPreset *)presetFromFilter:(FxGripFCPXMLFilter *)filter label:(NSString *)label
{
	FxGripPreset *preset = [FxGripPreset presetWithFCPXMLFilter:filter];
	if (label != nil) {
		preset.name = label;
	}
	preset.pluginUuid = self.pluginUUID;
	preset.pluginLocalizedName = self.pluginDisplayName;
	preset.pluginVersion = [FxGripHostPluginProperties(self.effect)[kProPlugPlugIn_VersionProperty] description];
	return preset;
}

- (FxGripFCPXMLFilter *)filterFromPreset:(FxGripPreset *)preset inDocument:(FxGripFCPXMLDocument *)document
{
	NSString *identifier = @"r1";
	if (document != nil) {
		identifier = [document.resources effectForFxPlugUUID:self.pluginUUID name:self.pluginDisplayName].identifier;
	}
	NSMutableDictionary<NSNumber *, NSString *> *names = [NSMutableDictionary dictionary];
	for (NSNumber *pid in self.parameterIDs) {
		names[pid] = [self nameOfParameter:pid.unsignedIntValue];
	}
	return [preset fcpxmlFilterWithEffectIdentifier:identifier parameterNames:names];
}

@end
