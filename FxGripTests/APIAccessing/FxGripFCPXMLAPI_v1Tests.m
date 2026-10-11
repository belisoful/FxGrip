/*!
	@file       FxGripFCPXMLAPI_v1Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLAPI_v1Tests
	@abstract   Tests the FCPXML capture and apply API against stub host APIs.
	@discussion Introduced in FxGrip 0.1.0. A stub effect carries parameter objects with names and types;
	            stub retrieval, setting, info, keyframe, and undo APIs stand in for the host; and a spy
	            presets API records each apply. The tests cover the effect identity, capture with and
	            without keyframes and hidden parameters, the document wrapper, apply matching by key
	            and by name, keyframe application, compatibility, the undo group, and the preset
	            conversions.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVTime.h>
#import <FxPlug/FxTypes.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripPreset.h>
#import <FxGrip/FxGripPresetsAPI_v1.h>
#import <FxGrip/FxGripFCPXMLAPI_v1.h>
#import <FxGrip/FxGripFCPXMLValue.h>
#import <FxGrip/FxGripPreset+FCPXML.h>
#import <FxGrip/FxGripFCPXMLStoryElement.h>
#import <FxGrip/FxGripFCPXMLLibrary.h>

static NSString *const kFCPXMLTestPluginUUID = @"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE";
static NSString *const kFCPXMLTestSupportedUUID = @"99999999-9999-9999-9999-999999999999";

#pragma mark - Doubles

@interface FxGripFCPXMLTestParameter : NSObject
@property (nonatomic, copy) NSString *parameterName;
@property (nonatomic, assign) FxParameterType parameterType;
@end
@implementation FxGripFCPXMLTestParameter
@end

@interface FxGripFCPXMLTestInfoAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *typesByParameter;
@end
@implementation FxGripFCPXMLTestInfoAPI
- (instancetype)init { self = [super init]; if (self) { _typesByParameter = NSMutableDictionary.new; } return self; }
- (FxParameterType)parameterType:(FxParameterId)parameterID
{
	NSNumber *type = self.typesByParameter[@(parameterID)];
	return type ? (FxParameterType)type.integerValue : FxParameterType_None;
}
@end

/*! Answers typed reads from staged values; keyframed values are staged per time. */
@interface FxGripFCPXMLTestRetrievalAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id> *valuesByParameter;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *valuesByParameterAndTime;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *flagsByParameter;
@end
@implementation FxGripFCPXMLTestRetrievalAPI
- (instancetype)init
{
	self = [super init];
	if (self) {
		_valuesByParameter = NSMutableDictionary.new;
		_valuesByParameterAndTime = NSMutableDictionary.new;
		_flagsByParameter = NSMutableDictionary.new;
	}
	return self;
}
- (id)stagedValueFor:(UInt32)parameterID atTime:(CMTime)time
{
	NSString *timed = [NSString stringWithFormat:@"%u@%lld/%d", parameterID, time.value, time.timescale];
	return self.valuesByParameterAndTime[timed] ?: self.valuesByParameter[@(parameterID)];
}
- (BOOL)getParameterFlags:(FxParameterFlags *)flags fromParameter:(UInt32)parameterID
{
	*flags = (FxParameterFlags)self.flagsByParameter[@(parameterID)].unsignedIntValue;
	return YES;
}
- (BOOL)getFloatValue:(double *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	NSNumber *staged = [self stagedValueFor:parameterID atTime:time];
	if (![staged isKindOfClass:NSNumber.class]) { return NO; }
	*value = staged.doubleValue;
	return YES;
}
- (BOOL)getIntValue:(int *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	NSNumber *staged = [self stagedValueFor:parameterID atTime:time];
	if (![staged isKindOfClass:NSNumber.class]) { return NO; }
	*value = staged.intValue;
	return YES;
}
- (BOOL)getBoolValue:(BOOL *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	NSNumber *staged = [self stagedValueFor:parameterID atTime:time];
	if (![staged isKindOfClass:NSNumber.class]) { return NO; }
	*value = staged.boolValue;
	return YES;
}
- (BOOL)getStringParameterValue:(NSString **)string fromParameter:(UInt32)parameterID
{
	NSString *staged = self.valuesByParameter[@(parameterID)];
	if (![staged isKindOfClass:NSString.class]) { return NO; }
	*string = staged;
	return YES;
}
- (BOOL)getRedValue:(double *)red greenValue:(double *)green blueValue:(double *)blue alphaValue:(double *)alpha
	  fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	NSArray *staged = [self stagedValueFor:parameterID atTime:time];
	if (![staged isKindOfClass:NSArray.class] || staged.count < 4) { return NO; }
	*red = [staged[0] doubleValue]; *green = [staged[1] doubleValue]; *blue = [staged[2] doubleValue]; *alpha = [staged[3] doubleValue];
	return YES;
}
- (BOOL)getRedValue:(double *)red greenValue:(double *)green blueValue:(double *)blue fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	NSArray *staged = [self stagedValueFor:parameterID atTime:time];
	if (![staged isKindOfClass:NSArray.class] || staged.count < 3) { return NO; }
	*red = [staged[0] doubleValue]; *green = [staged[1] doubleValue]; *blue = [staged[2] doubleValue];
	return YES;
}
- (BOOL)getXValue:(double *)x YValue:(double *)y fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	NSArray *staged = [self stagedValueFor:parameterID atTime:time];
	if (![staged isKindOfClass:NSArray.class] || staged.count < 2) { return NO; }
	*x = [staged[0] doubleValue]; *y = [staged[1] doubleValue];
	return YES;
}
- (BOOL)getCustomParameterValue:(NSObject<NSSecureCoding, NSCopying> **)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	id staged = self.valuesByParameter[@(parameterID)];
	if (![staged isKindOfClass:NSDictionary.class]) { return NO; }
	*value = staged;
	return YES;
}
@end

/*! Stands in for the FxGrip setting wrapper: it exposes the retrieval and info APIs the preset value primitives reach through. */
@interface FxGripFCPXMLTestSettingAPI : NSObject
@property (nonatomic, strong) FxGripFCPXMLTestRetrievalAPI *paramGetAPIv6;
@property (nonatomic, strong) FxGripFCPXMLTestInfoAPI *parameterInfoAPIv1;
@end
@implementation FxGripFCPXMLTestSettingAPI
@end

/*! A keyframe API with staged keyframe times per parameter channel; it records added keyframes. */
@interface FxGripFCPXMLTestKeyframeAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *channelsByParameter;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSArray<NSValue *> *> *timesByParameter;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *stylesByParameter;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *added;
@end
@implementation FxGripFCPXMLTestKeyframeAPI
- (instancetype)init
{
	self = [super init];
	if (self) {
		_channelsByParameter = NSMutableDictionary.new;
		_timesByParameter = NSMutableDictionary.new;
		_stylesByParameter = NSMutableDictionary.new;
		_added = NSMutableArray.new;
	}
	return self;
}
- (NSError *)channelCount:(NSUInteger *)count forParameter:(NSUInteger)parameterID
{
	NSNumber *channels = self.channelsByParameter[@(parameterID)];
	if (channels == nil) { return [NSError errorWithDomain:@"test" code:1 userInfo:nil]; }
	*count = channels.unsignedIntegerValue;
	return nil;
}
- (NSError *)keyframeCount:(NSUInteger *)count forParameter:(NSUInteger)parameterID andChannel:(NSUInteger)channelIndex
{
	*count = self.timesByParameter[@(parameterID)].count;
	return nil;
}
- (NSError *)keyframe:(FxKeyframe *)keyframe forParameter:(NSUInteger)parameterID channel:(NSUInteger)channelIndex andIndex:(NSUInteger)keyframeIndex
{
	NSArray<NSValue *> *times = self.timesByParameter[@(parameterID)];
	if (keyframeIndex >= times.count) { return [NSError errorWithDomain:@"test" code:2 userInfo:nil]; }
	keyframe->time = times[keyframeIndex].CMTimeValue;
	keyframe->segmentStyle = (FxKeyframeSegmentStyle)self.stylesByParameter[@(parameterID)].unsignedIntegerValue;
	return nil;
}
- (NSError *)parameter:(NSUInteger)parameterID channel:(NSUInteger)channelIndex hasKeyframe:(BOOL *)hasKeyframe atTime:(CMTime)time
{
	*hasKeyframe = NO;
	for (NSValue *value in self.timesByParameter[@(parameterID)]) {
		if (CMTimeCompare(value.CMTimeValue, time) == 0) { *hasKeyframe = YES; }
	}
	return nil;
}
- (NSError *)addKeyframe:(const FxKeyframe *)keyframe toParameter:(NSUInteger)parameterID andChannel:(NSUInteger)channelIndex
{
	[self.added addObject:@{@"parameter": @(parameterID), @"channel": @(channelIndex),
							@"time": [NSValue valueWithCMTime:keyframe->time], @"style": @(keyframe->segmentStyle)}];
	return nil;
}
@end

@interface FxGripFCPXMLTestUndoAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@end
@implementation FxGripFCPXMLTestUndoAPI
- (instancetype)init { self = [super init]; if (self) { _events = NSMutableArray.new; } return self; }
- (BOOL)startUndoGroup:(NSString *)name { [self.events addObject:[@"start:" stringByAppendingString:name]]; return YES; }
- (BOOL)endUndoGroup { [self.events addObject:@"end"]; return YES; }
@end

/*! Records each apply instead of writing parameters. */
@interface FxGripFCPXMLTestPresetsAPI : FxGripPresetsAPI_v1
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *applies;
@property (nonatomic, strong) NSError *applyError;
@end
@implementation FxGripFCPXMLTestPresetsAPI
- (NSError *)setPreset:(FxGripPreset *)preset options:(FxGripParameterPresetFlags)flags atTime:(CMTime)time
{
	if (self.applies == nil) { self.applies = NSMutableArray.new; }
	[self.applies addObject:@{@"values": preset.parameterValues ?: @{}, @"flags": @(flags),
							  @"time": [NSValue valueWithCMTime:time], @"uuid": preset.pluginUuid ?: @""}];
	return self.applyError;
}
@end

@interface FxGripFCPXMLTestAPIManager : NSObject
@property (nonatomic, copy) NSString *pluginUUID;
@property (nonatomic, strong) FxGripFCPXMLTestSettingAPI *paramSetAPIv5;
@property (nonatomic, strong) FxGripFCPXMLTestRetrievalAPI *paramGetAPIv6;
@property (nonatomic, strong) FxGripFCPXMLTestInfoAPI *parameterInfoAPIv1;
@property (nonatomic, strong) FxGripFCPXMLTestPresetsAPI *presetsAPIv1;
@property (nonatomic, strong) FxGripFCPXMLTestKeyframeAPI *keyframeAPIv3;
@property (nonatomic, strong) FxGripFCPXMLTestUndoAPI *undoAPIv1;
@end
@implementation FxGripFCPXMLTestAPIManager
@end

@interface FxGripFCPXMLTestEffect : NSObject
@property (nonatomic, strong) FxGripFCPXMLTestAPIManager *apiManager;
@property (nonatomic, strong) NSDictionary<NSString *, id> *pluginProperties;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, FxGripFCPXMLTestParameter *> *parameters;
@property (nonatomic, copy) NSString *pluginDisplayName;
@property (nonatomic, assign) CMTime effectDurationTime;
@end
@implementation FxGripFCPXMLTestEffect
- (id)effectBase { return self; }
@end

#pragma mark - Tests

@interface FxGripFCPXMLAPI_v1Tests : XCTestCase
@property (nonatomic, strong) FxGripFCPXMLTestEffect *effect;
@property (nonatomic, strong) FxGripFCPXMLTestAPIManager *manager;
@property (nonatomic, strong) FxGripFCPXMLTestRetrievalAPI *retrieval;
@property (nonatomic, strong) FxGripFCPXMLTestInfoAPI *info;
@property (nonatomic, strong) FxGripFCPXMLTestKeyframeAPI *keyframes;
@property (nonatomic, strong) FxGripFCPXMLTestUndoAPI *undo;
@property (nonatomic, strong) FxGripFCPXMLTestPresetsAPI *presets;
@property (nonatomic, strong) FxGripFCPXMLAPI_v1 *api;
@end

@implementation FxGripFCPXMLAPI_v1Tests

- (void)addParameter:(FxParameterId)parameterID name:(NSString *)name type:(FxParameterType)type value:(id)value
{
	FxGripFCPXMLTestParameter *parameter = [[FxGripFCPXMLTestParameter alloc] init];
	parameter.parameterName = name;
	parameter.parameterType = type;
	self.effect.parameters[@(parameterID)] = parameter;
	self.info.typesByParameter[@(parameterID)] = @(type);
	if (value != nil) {
		self.retrieval.valuesByParameter[@(parameterID)] = value;
	}
}

- (void)setUp
{
	[super setUp];
	self.effect = [[FxGripFCPXMLTestEffect alloc] init];
	self.effect.parameters = NSMutableDictionary.new;
	self.effect.pluginDisplayName = @"Grip Glow";
	self.effect.effectDurationTime = CMTimeMake(5, 1);
	self.effect.pluginProperties = @{
		kProPlugPlugIn_UuidProperty: kFCPXMLTestPluginUUID,
		kProPlugPlugIn_ClassNameProperty: @"GripGlow",
		kProPlugPlugIn_DisplayNameProperty: @"Grip Glow",
		kProPlugPlugIn_GroupUUIDProperty: @"GROUP",
		kProPlugPlugIn_VersionProperty: @3,
		kProPlugPlugIn_SupportedPluginsProperty: @[kFCPXMLTestSupportedUUID],
	};
	self.retrieval = [[FxGripFCPXMLTestRetrievalAPI alloc] init];
	self.info = [[FxGripFCPXMLTestInfoAPI alloc] init];
	self.keyframes = [[FxGripFCPXMLTestKeyframeAPI alloc] init];
	self.undo = [[FxGripFCPXMLTestUndoAPI alloc] init];
	FxGripFCPXMLTestSettingAPI *setting = [[FxGripFCPXMLTestSettingAPI alloc] init];
	setting.paramGetAPIv6 = self.retrieval;
	setting.parameterInfoAPIv1 = self.info;
	self.manager = [[FxGripFCPXMLTestAPIManager alloc] init];
	self.manager.pluginUUID = kFCPXMLTestPluginUUID;
	self.manager.paramSetAPIv5 = setting;
	self.manager.paramGetAPIv6 = self.retrieval;
	self.manager.parameterInfoAPIv1 = self.info;
	self.manager.keyframeAPIv3 = self.keyframes;
	self.manager.undoAPIv1 = self.undo;
	self.effect.apiManager = self.manager;
	self.presets = [[FxGripFCPXMLTestPresetsAPI alloc] initWithAPI:nil effect:(id)self.effect];
	self.manager.presetsAPIv1 = self.presets;
	self.api = [[FxGripFCPXMLAPI_v1 alloc] initWithAPI:nil effect:(id)self.effect];

	[self addParameter:1 name:@"Amount" type:FxParameterType_Float value:@0.5];
	[self addParameter:2 name:@"Tint" type:FxParameterType_RGBA value:@[@1, @0.5, @0.25, @1]];
	[self addParameter:3 name:@"Center" type:FxParameterType_Point value:@[@0.25, @-0.25]];
	[self addParameter:4 name:@"Enabled" type:FxParameterType_Toggle value:@YES];
	[self addParameter:5 name:@"Label" type:FxParameterType_String value:@"Hello"];
	[self addParameter:6 name:@"Mode" type:FxParameterType_Menu value:@2];
	[self addParameter:7 name:@"Curve" type:FxParameterType_Custom value:@{@"points": @[@0, @1]}];
	[self addParameter:8 name:@"Secret" type:FxParameterType_Float value:@9];
	self.retrieval.flagsByParameter[@8] = @(kFxParameterFlag_HIDDEN);
	[self addParameter:9 name:@"Button" type:FxParameterType_PushButton value:nil];
	self.retrieval.flagsByParameter[@9] = @(kFxParameterFlag_PRESETNOVALUE);
}

#pragma mark Identity

- (void)testEffectIdentity
{
	XCTAssertEqualObjects(self.api.effectUID, [@"FxPlug:" stringByAppendingString:kFCPXMLTestPluginUUID]);
	FxGripFCPXMLEffect *resource = self.api.effectResource;
	XCTAssertEqualObjects(resource.fxPlugUUID, kFCPXMLTestPluginUUID);
	XCTAssertEqualObjects(resource.resourceName, @"Grip Glow");
	XCTAssertNil(resource.identifier);
	XCTAssertNil(self.api.api);
}

#pragma mark Capture

- (void)testCaptureWritesTypedParams
{
	FxGripFCPXMLFilter *filter = nil;
	NSError *error = [self.api captureFilter:&filter atTime:CMTimeMake(1, 1) options:FxGripFCPXMLCaptureDefault];
	XCTAssertNil(error);
	XCTAssertEqualObjects(filter.filterName, @"Grip Glow");
	XCTAssertNil(filter.effectIdentifier);
	XCTAssertEqualObjects([filter.params valueForKey:@"key"], (@[@"1", @"2", @"3", @"4", @"5", @"6", @"8"]),
						  @"custom values and no-value parameters are skipped by default");
	XCTAssertEqualObjects([filter paramWithKey:@"1"].paramName, @"Amount");
	XCTAssertEqualObjects([filter paramWithKey:@"1"].value, @"0.5");
	XCTAssertEqualObjects([filter paramWithKey:@"2"].value, @"1 0.5 0.25 1");
	XCTAssertEqualObjects([filter paramWithKey:@"3"].value, @"0.25 -0.25");
	XCTAssertEqualObjects([filter paramWithKey:@"4"].value, @"1");
	XCTAssertEqualObjects([filter paramWithKey:@"5"].value, @"Hello");
	XCTAssertEqualObjects([filter paramWithKey:@"6"].value, @"2");
	XCTAssertEqualObjects([filter paramWithKey:@"8"].value, @"9");
	XCTAssertFalse([filter paramWithKey:@"1"].isAnimated, @"keyframes are off by default");
	XCTAssertEqualObjects([filter validationProblemsForVersion:FxGripFCPXMLVersionLatest() recursive:YES],
						  @[@"filter-video: the required attribute 'ref' is missing."]);
}

- (void)testCaptureOptions
{
	FxGripFCPXMLFilter *filter = nil;
	XCTAssertNil([self.api captureFilter:&filter atTime:CMTimeMake(1, 1)
								 options:FxGripFCPXMLCaptureOmitHidden | FxGripFCPXMLCaptureCustomValues]);
	XCTAssertNil([filter paramWithKey:@"8"], @"hidden parameters are omitted on request");
	FxGripFCPXMLParam *custom = [filter paramWithKey:@"7"];
	XCTAssertNotNil(custom);
	XCTAssertNil(custom.value);
	XCTAssertEqualObjects([custom subparamNamed:FxGripFCPXMLValueArchiveParamName].auxValue, FxGripFCPXMLValueArchiveMarker);
	XCTAssertEqualObjects([FxGripPreset valueFromParam:custom archiveClasses:nil], (@{@"points": @[@0, @1]}));
}

- (void)testCaptureKeyframes
{
	self.keyframes.channelsByParameter[@1] = @1;
	self.keyframes.timesByParameter[@1] = @[[NSValue valueWithCMTime:CMTimeMake(0, 1)], [NSValue valueWithCMTime:CMTimeMake(2, 1)]];
	self.keyframes.stylesByParameter[@1] = @(kFxKeyframeSegmentStyle_EaseInNext);
	self.retrieval.valuesByParameterAndTime[@"1@0/1"] = @0;
	self.retrieval.valuesByParameterAndTime[@"1@2/1"] = @1;
	self.keyframes.channelsByParameter[@3] = @2;
	self.keyframes.timesByParameter[@3] = @[[NSValue valueWithCMTime:CMTimeMake(1, 1)]];
	self.keyframes.stylesByParameter[@3] = @(kFxKeyframeSegmentStyle_Linear);
	self.retrieval.valuesByParameterAndTime[@"3@1/1"] = @[@1, @1];
	self.keyframes.channelsByParameter[@2] = @4;
	self.keyframes.timesByParameter[@2] = @[];

	FxGripFCPXMLFilter *filter = nil;
	XCTAssertNil([self.api captureFilter:&filter atTime:CMTimeMake(1, 1) options:FxGripFCPXMLCaptureKeyframes]);
	FxGripFCPXMLParam *amount = [filter paramWithKey:@"1"];
	XCTAssertEqualObjects(amount.value, @"0.5", @"the initial value is read at the capture time");
	NSArray<FxGripFCPXMLKeyframe *> *keyframes = amount.keyframeAnimation.keyframes;
	XCTAssertEqual(keyframes.count, (NSUInteger)2);
	XCTAssertEqualObjects(keyframes[0].value, @"0");
	XCTAssertEqualObjects(keyframes[0].interpolation, FxGripFCPXMLKeyframeInterpolationEaseIn);
	XCTAssertEqualObjects(keyframes[1].value, @"1");
	XCTAssertEqual(CMTimeCompare(keyframes[1].time, CMTimeMake(2, 1)), 0);
	FxGripFCPXMLParam *center = [filter paramWithKey:@"3"];
	XCTAssertEqual(center.keyframeAnimation.keyframes.count, (NSUInteger)1);
	XCTAssertEqualObjects(center.keyframeAnimation.keyframes.firstObject.value, @"1 1");
	XCTAssertNil(center.keyframeAnimation.keyframes.firstObject.interpolation, @"linear is the DTD default");
	XCTAssertFalse([filter paramWithKey:@"2"].isAnimated);
	XCTAssertFalse([filter paramWithKey:@"4"].isAnimated, @"a parameter the keyframe API refuses has no animation");
}

- (void)testCaptureDocument
{
	FxGripFCPXMLDocument *document = nil;
	XCTAssertNil([self.api captureDocument:&document atTime:kCMTimeZero options:FxGripFCPXMLCaptureDefault]);
	XCTAssertNotNil(document);
	FxGripFCPXMLEffect *effect = document.resources.effects.firstObject;
	XCTAssertEqualObjects(effect.fxPlugUUID, kFCPXMLTestPluginUUID);
	XCTAssertEqualObjects(effect.identifier, @"r1");
	FxGripFCPXMLStoryElement *clip = document.events.firstObject.clips.firstObject;
	XCTAssertEqualObjects(clip.clipName, @"Grip Glow");
	XCTAssertEqual(CMTimeCompare(clip.duration, CMTimeMake(5, 1)), 0);
	XCTAssertEqualObjects(clip.videoFilters.firstObject.effectIdentifier, @"r1");
	XCTAssertEqualObjects(clip.videoFilters.firstObject.effect, effect);
	XCTAssertEqualObjects(document.validationProblems, @[]);
	XCTAssertEqualObjects([self.api compatibleFiltersInDocument:document], clip.videoFilters);

	self.effect.effectDurationTime = kCMTimeInvalid;
	XCTAssertNil([self.api captureDocument:&document atTime:kCMTimeZero options:FxGripFCPXMLCaptureDefault]);
	XCTAssertEqual(CMTimeCompare(document.events.firstObject.clips.firstObject.duration, CMTimeMake(1, 1)), 0,
				   @"one second stands in for an unknown duration");
}

- (void)testCaptureRefusesWithoutOutParameterOrAPIs
{
	XCTAssertEqual([self.api captureFilter:(FxGripFCPXMLFilter * __strong _Nullable * _Nonnull)NULL atTime:kCMTimeZero options:0].code, kFxGripError_FCPXML);
	XCTAssertEqual([self.api captureDocument:(FxGripFCPXMLDocument * __strong _Nullable * _Nonnull)NULL atTime:kCMTimeZero options:0].code, kFxGripError_FCPXML);
	self.manager.paramGetAPIv6 = nil;
	FxGripFCPXMLFilter *filter = nil;
	XCTAssertEqual([self.api captureFilter:&filter atTime:kCMTimeZero options:0].code, kFxGripError_FCPXML);
	XCTAssertNil(filter);
}

#pragma mark Apply

- (FxGripFCPXMLFilter *)filterWithParams:(NSArray<FxGripFCPXMLParam *> *)params
{
	FxGripFCPXMLFilter *filter = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:nil name:@"Incoming"];
	for (FxGripFCPXMLParam *param in params) {
		[filter addParam:param];
	}
	return filter;
}

- (void)testApplyMatchesByKeyAndDecodesByType
{
	FxGripFCPXMLFilter *filter = [self filterWithParams:@[
		[FxGripFCPXMLParam paramWithName:@"Renamed" key:@"1" value:@"0.75"],
		[FxGripFCPXMLParam paramWithName:@"Tint" key:@"2" value:@"0 0 1"],
		[FxGripFCPXMLParam paramWithName:@"Center" key:@"3" value:@"1 2"],
		[FxGripFCPXMLParam paramWithName:@"Enabled" key:@"4" value:@"0"],
		[FxGripFCPXMLParam paramWithName:@"Label" key:@"5" value:@"Bye"],
		[FxGripFCPXMLParam paramWithName:@"Mode" key:@"6" value:@"1"],
		[FxGripFCPXMLParam paramWithName:@"Unknown" key:@"42" value:@"1"],
		[FxGripFCPXMLParam paramWithName:@"Nameless" key:nil value:@"1"],
	]];
	NSError *error = [self.api applyFilter:filter atTime:CMTimeMake(3, 1) options:FxGripFCPXMLApplyDefault];
	XCTAssertNil(error);
	XCTAssertEqual(self.presets.applies.count, (NSUInteger)1);
	NSDictionary *apply = self.presets.applies.firstObject;
	NSDictionary *values = apply[@"values"];
	XCTAssertEqualObjects(values[@"1"], @0.75);
	XCTAssertEqualObjects(values[@"2"][kFxParameterProperty_Alpha], @1);
	XCTAssertEqualObjects(values[@"3"][kFxParameterProperty_Y], @2);
	XCTAssertEqualObjects(values[@"4"], @NO);
	XCTAssertEqualObjects(values[@"5"], @"Bye");
	XCTAssertEqualObjects(values[@"6"], @1);
	XCTAssertNil(values[@"42"]);
	XCTAssertEqual(values.count, (NSUInteger)6);
	XCTAssertEqual(CMTimeCompare([apply[@"time"] CMTimeValue], CMTimeMake(3, 1)), 0);
	XCTAssertEqualObjects(apply[@"uuid"], kFCPXMLTestPluginUUID);
	NSUInteger flags = [apply[@"flags"] unsignedIntegerValue];
	XCTAssertTrue(flags & kFxParameterPreset_IgnoreCompatibility);
	XCTAssertTrue(flags & kFxParameterPreset_IgnoreMetaData);
	XCTAssertFalse(flags & kFxParameterPreset_IgnoreTagBoundary);
	XCTAssertEqual(self.undo.events.count, (NSUInteger)0);
}

- (void)testApplyMatchesByNameOnRequest
{
	FxGripFCPXMLFilter *filter = [self filterWithParams:@[
		[FxGripFCPXMLParam paramWithName:@"Amount" key:@"77" value:@"0.1"],
		[FxGripFCPXMLParam paramWithName:@"Label" key:nil value:@"Named"],
		[FxGripFCPXMLParam paramWithName:@"Nope" key:nil value:@"1"],
	]];
	XCTAssertNil([self.api applyFilter:filter atTime:kCMTimeZero options:FxGripFCPXMLApplyDefault]);
	XCTAssertEqual(self.presets.applies.count, (NSUInteger)1, @"a keyless param matches by name even by default");
	XCTAssertEqualObjects(self.presets.applies.firstObject[@"values"], @{@"5": @"Named"});
	[self.presets.applies removeAllObjects];
	XCTAssertNil([self.api applyFilter:filter atTime:kCMTimeZero options:FxGripFCPXMLApplyMatchNames | FxGripFCPXMLApplyIgnoreTagBoundary]);
	NSDictionary *values = self.presets.applies.firstObject[@"values"];
	XCTAssertEqualObjects(values[@"1"], @0.1, @"a key that names nothing falls back to the name");
	XCTAssertEqualObjects(values[@"5"], @"Named");
	XCTAssertTrue([self.presets.applies.firstObject[@"flags"] unsignedIntegerValue] & kFxParameterPreset_IgnoreTagBoundary);
}

- (void)testApplyNothingWhenNoParamMatches
{
	FxGripFCPXMLFilter *filter = [self filterWithParams:@[[FxGripFCPXMLParam paramWithName:@"X" key:@"99" value:@"1"]]];
	XCTAssertNil([self.api applyFilter:filter atTime:kCMTimeZero options:FxGripFCPXMLApplyUndoGroup]);
	XCTAssertEqual(self.presets.applies.count, (NSUInteger)0);
	XCTAssertEqual(self.undo.events.count, (NSUInteger)0, @"no undo group opens for an empty apply");
}

- (void)testApplyKeyframesAddsHostKeyframes
{
	self.keyframes.channelsByParameter[@1] = @1;
	self.keyframes.timesByParameter[@1] = @[[NSValue valueWithCMTime:CMTimeMake(0, 1)]];
	self.keyframes.channelsByParameter[@3] = @2;
	self.keyframes.timesByParameter[@3] = @[];
	FxGripFCPXMLParam *amount = [FxGripFCPXMLParam paramWithName:@"Amount" key:@"1" value:@"0"];
	[[amount keyframeAnimationCreatingIfNeeded] addKeyframeAtTime:CMTimeMake(0, 1) value:@"0"];
	FxGripFCPXMLKeyframe *eased = [[amount keyframeAnimationCreatingIfNeeded] addKeyframeAtTime:CMTimeMake(2, 1) value:@"1"];
	eased.interpolation = FxGripFCPXMLKeyframeInterpolationEase;
	FxGripFCPXMLParam *center = [FxGripFCPXMLParam paramWithName:@"Center" key:@"3" value:@"0 0"];
	[[center keyframeAnimationCreatingIfNeeded] addKeyframeAtTime:CMTimeMake(2, 1) value:@"1 1"];
	FxGripFCPXMLFilter *filter = [self filterWithParams:@[amount, center]];

	XCTAssertNil([self.api applyFilter:filter atTime:CMTimeMake(5, 1) options:FxGripFCPXMLApplyUndoGroup]);
	XCTAssertEqual(self.presets.applies.count, (NSUInteger)3, @"the static values, then each keyframe time");
	XCTAssertEqual(CMTimeCompare([self.presets.applies[0][@"time"] CMTimeValue], CMTimeMake(5, 1)), 0);
	XCTAssertEqualObjects(self.presets.applies[0][@"values"][@"1"], @0);
	XCTAssertEqual(CMTimeCompare([self.presets.applies[1][@"time"] CMTimeValue], CMTimeMake(0, 1)), 0);
	XCTAssertEqualObjects(self.presets.applies[1][@"values"], @{@"1": @0});
	XCTAssertEqual(CMTimeCompare([self.presets.applies[2][@"time"] CMTimeValue], CMTimeMake(2, 1)), 0);
	XCTAssertEqualObjects(self.presets.applies[2][@"values"][@"1"], @1);
	XCTAssertEqualObjects(self.presets.applies[2][@"values"][@"3"][kFxParameterProperty_X], @1);
	// Parameter 1 has a host keyframe at 0 already, so one is added at 2; parameter 3 gets both channels at 2.
	XCTAssertEqual(self.keyframes.added.count, (NSUInteger)3, @"%@", self.keyframes.added);
	XCTAssertEqualObjects(self.keyframes.added[0][@"parameter"], @1);
	XCTAssertEqualObjects(self.keyframes.added[0][@"style"], @(kFxKeyframeSegmentStyle_EaseOutCurrentEaseInNext));
	XCTAssertEqualObjects(self.keyframes.added[1][@"parameter"], @3);
	XCTAssertEqualObjects(self.keyframes.added[2][@"channel"], @1);
	XCTAssertEqualObjects(self.undo.events, (@[@"start:Apply Incoming", @"end"]));
}

- (void)testApplyIgnoresKeyframesOnRequestAndWithoutKeyframeAPI
{
	FxGripFCPXMLParam *amount = [FxGripFCPXMLParam paramWithName:@"Amount" key:@"1" value:@"0"];
	[[amount keyframeAnimationCreatingIfNeeded] addKeyframeAtTime:CMTimeMake(2, 1) value:@"1"];
	FxGripFCPXMLFilter *filter = [self filterWithParams:@[amount]];
	XCTAssertNil([self.api applyFilter:filter atTime:kCMTimeZero options:FxGripFCPXMLApplyIgnoreKeyframes]);
	XCTAssertEqual(self.presets.applies.count, (NSUInteger)1);
	[self.presets.applies removeAllObjects];
	self.manager.keyframeAPIv3 = nil;
	XCTAssertNil([self.api applyFilter:filter atTime:kCMTimeZero options:FxGripFCPXMLApplyDefault]);
	XCTAssertEqual(self.presets.applies.count, (NSUInteger)2, @"values still write at each keyframe time");
	XCTAssertEqual(self.keyframes.added.count, (NSUInteger)0);
}

- (void)testApplyRefusesAnotherPluginUnlessIgnored
{
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	FxGripFCPXMLEffect *other = [document.resources effectForFxPlugUUID:@"OTHER" name:@"Other"];
	FxGripFCPXMLStoryElement *clip = [FxGripFCPXMLStoryElement clipWithName:@"C" duration:CMTimeMake(1, 1)];
	FxGripFCPXMLFilter *filter = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:other.identifier name:@"Other"];
	[filter setValue:@"1" forParamNamed:@"Amount" key:@"1"];
	[clip addVideoFilter:filter];
	[[document.libraryCreatingIfNeeded firstEventCreatingIfNeeded] addItem:clip];

	XCTAssertFalse([self.api isCompatibleFilter:filter]);
	NSError *error = [self.api applyFilter:filter atTime:kCMTimeZero options:FxGripFCPXMLApplyDefault];
	XCTAssertEqual(error.code, kFxGripError_FCPXMLIncompatible);
	XCTAssertTrue([error.localizedDescription containsString:@"FxPlug:OTHER"]);
	XCTAssertEqual(self.presets.applies.count, (NSUInteger)0);
	XCTAssertEqual([self.api applyDocument:document atTime:kCMTimeZero options:FxGripFCPXMLApplyDefault].code, kFxGripError_FCPXMLIncompatible);
	XCTAssertEqualObjects([self.api compatibleFiltersInDocument:document], @[]);

	XCTAssertNil([self.api applyDocument:document atTime:kCMTimeZero options:FxGripFCPXMLApplyIgnoreCompatibility]);
	XCTAssertEqual(self.presets.applies.count, (NSUInteger)1);

	FxGripFCPXMLEffect *supported = [document.resources effectForFxPlugUUID:kFCPXMLTestSupportedUUID name:@"Older"];
	filter.effectIdentifier = supported.identifier;
	XCTAssertTrue([self.api isCompatibleFilter:filter], @"a supportedPlugins alternative is compatible");
	XCTAssertEqual([self.api compatibleFiltersInDocument:document].count, (NSUInteger)1);
	XCTAssertNil([self.api applyDocument:document atTime:kCMTimeZero options:FxGripFCPXMLApplyDefault]);
	filter.effectIdentifier = @"r77";
	XCTAssertTrue([self.api isCompatibleFilter:filter], @"an unresolvable reference carries no identity");
	XCTAssertTrue([self.api isCompatibleFilter:[self filterWithParams:@[]]]);
}

- (void)testApplyErrorsAndMissingAPIs
{
	XCTAssertEqual([self.api applyFilter:(id _Nonnull)nil atTime:kCMTimeZero options:0].code, kFxGripError_FCPXML);
	XCTAssertEqual([self.api applyDocument:(id _Nonnull)nil atTime:kCMTimeZero options:0].code, kFxGripError_FCPXML);
	FxGripFCPXMLFilter *filter = [self filterWithParams:@[[FxGripFCPXMLParam paramWithName:@"Amount" key:@"1" value:@"1"]]];
	self.presets.applyError = [NSError errorWithDomain:@"test" code:5 userInfo:nil];
	XCTAssertEqual([self.api applyFilter:filter atTime:kCMTimeZero options:FxGripFCPXMLApplyUndoGroup].code, 5);
	XCTAssertEqualObjects(self.undo.events.lastObject, @"end", @"the undo group closes on an error");
	self.manager.presetsAPIv1 = nil;
	XCTAssertEqual([self.api applyFilter:filter atTime:kCMTimeZero options:0].code, kFxGripError_FCPXML);
	FxGripFCPXMLDocument *empty = [[FxGripFCPXMLDocument alloc] init];
	XCTAssertEqual([self.api applyDocument:empty atTime:kCMTimeZero options:0].code, kFxGripError_FCPXMLIncompatible);
}

#pragma mark Presets

- (void)testPresetConversions
{
	FxGripPreset *preset = [[FxGripPreset alloc] init];
	preset.name = @"Warm";
	preset.parameterValues = @{@"1": @0.25, @"5": @"Text"};
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	FxGripFCPXMLFilter *filter = [self.api filterFromPreset:preset inDocument:document];
	XCTAssertEqualObjects(filter.effectIdentifier, @"r1");
	XCTAssertEqualObjects(document.resources.effects.firstObject.fxPlugUUID, kFCPXMLTestPluginUUID);
	XCTAssertEqualObjects([filter paramWithKey:@"1"].paramName, @"Amount", @"names come from the effect's parameters");
	XCTAssertEqualObjects([filter paramWithKey:@"5"].value, @"Text");
	XCTAssertEqualObjects([self.api filterFromPreset:preset inDocument:nil].effectIdentifier, @"r1");

	FxGripPreset *back = [self.api presetFromFilter:filter label:@"Back"];
	XCTAssertEqualObjects(back.name, @"Back");
	XCTAssertEqualObjects(back.pluginUuid, kFCPXMLTestPluginUUID);
	XCTAssertEqualObjects(back.pluginLocalizedName, @"Grip Glow");
	XCTAssertEqualObjects(back.pluginVersion, @"3");
	XCTAssertEqualObjects(back.parameterValues[@"1"], @0.25);
	XCTAssertEqualObjects([self.api presetFromFilter:filter label:nil].name, @"Warm");
}

@end
