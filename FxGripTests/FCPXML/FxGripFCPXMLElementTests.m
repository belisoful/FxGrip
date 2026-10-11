/*!
	@file       FxGripFCPXMLElementTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLElementTests
	@abstract   Tests the element wrapper, the typed element classes, and schema validation.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the class registry, typed attribute access,
	            tree edits in DTD order, the resource, param, filter, story, library, and text classes,
	            and the per-element validation problems.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripFCPXMLElement.h>
#import <FxGrip/FxGripFCPXMLResources.h>
#import <FxGrip/FxGripFCPXMLParam.h>
#import <FxGrip/FxGripFCPXMLFilter.h>
#import <FxGrip/FxGripFCPXMLStoryElement.h>
#import <FxGrip/FxGripFCPXMLLibrary.h>
#import <FxGrip/FxGripFCPXMLText.h>
#import <FxGrip/FxGripFCPXMLDocument.h>

@interface FxGripFCPXMLElementTests : XCTestCase
@end

@implementation FxGripFCPXMLElementTests

#pragma mark - Registry and wrapping

- (void)testRegistryReturnsTypedClasses
{
	XCTAssertEqual([FxGripFCPXMLElement classForElementNamed:@"param"], FxGripFCPXMLParam.class);
	XCTAssertEqual([FxGripFCPXMLElement classForElementNamed:@"filter-audio"], FxGripFCPXMLFilter.class);
	XCTAssertEqual([FxGripFCPXMLElement classForElementNamed:@"asset-clip"], FxGripFCPXMLStoryElement.class);
	XCTAssertEqual([FxGripFCPXMLElement classForElementNamed:@"chapter-marker"], FxGripFCPXMLMarker.class);
	XCTAssertEqual([FxGripFCPXMLElement classForElementNamed:@"text-style-def"], FxGripFCPXMLTextStyle.class);
	XCTAssertEqual([FxGripFCPXMLElement classForElementNamed:@"fadeOut"], FxGripFCPXMLFade.class);
	XCTAssertEqual([FxGripFCPXMLElement classForElementNamed:@"adjust-transform"], FxGripFCPXMLElement.class);
	XCTAssertEqual([FxGripFCPXMLElement classForElementNamed:nil], FxGripFCPXMLElement.class);
	XCTAssertTrue([[FxGripFCPXMLElement elementNamed:@"keyframe"] isKindOfClass:FxGripFCPXMLKeyframe.class]);
}

- (void)testWrappersOverTheSameNodeAreEqual
{
	FxGripFCPXMLParam *param = [FxGripFCPXMLParam paramWithName:@"Amount" key:@"1" value:@"0.5"];
	FxGripFCPXMLElement *again = [FxGripFCPXMLElement elementWithXMLElement:param.xmlElement];
	XCTAssertEqualObjects(param, again);
	XCTAssertEqual(param.hash, again.hash);
	XCTAssertTrue([again isKindOfClass:FxGripFCPXMLParam.class]);
	XCTAssertNotEqualObjects(param, [FxGripFCPXMLParam paramWithName:@"Amount" key:@"1" value:@"0.5"]);
}

- (void)testCustomRegistration
{
	Class before = [FxGripFCPXMLElement classForElementNamed:@"note"];
	[FxGripFCPXMLElement registerClass:FxGripFCPXMLMarker.class forElementNamed:@"note"];
	XCTAssertEqual([FxGripFCPXMLElement classForElementNamed:@"note"], FxGripFCPXMLMarker.class);
	[FxGripFCPXMLElement registerClass:before forElementNamed:@"note"];
	[FxGripFCPXMLElement registerClass:NSObject.class forElementNamed:@"note"];
	XCTAssertEqual([FxGripFCPXMLElement classForElementNamed:@"note"], before, @"a non-element class is refused");
}

#pragma mark - Attributes

- (void)testTypedAttributes
{
	FxGripFCPXMLElement *element = [FxGripFCPXMLElement elementNamed:@"adjust-transform"];
	[element setString:@"1 1" forAttribute:@"scale"];
	[element setDouble:0.25 forAttribute:@"rotation"];
	[element setBool:NO forAttribute:@"enabled"];
	[element setInteger:-2 forAttribute:@"lane"];
	[element setTime:CMTimeMake(1001, 30000) forAttribute:@"offset"];
	[element setNumbers:@[@1.5, @-2] forAttribute:@"position"];

	XCTAssertEqualObjects([element stringForAttribute:@"scale"], @"1 1");
	XCTAssertEqual([element doubleForAttribute:@"rotation" defaultValue:9], 0.25);
	XCTAssertEqualObjects([element stringForAttribute:@"rotation"], @"0.25");
	XCTAssertFalse([element boolForAttribute:@"enabled" defaultValue:YES]);
	XCTAssertEqual([element integerForAttribute:@"lane" defaultValue:0], -2);
	XCTAssertEqual(CMTimeCompare([element timeForAttribute:@"offset"], CMTimeMake(1001, 30000)), 0);
	XCTAssertEqualObjects([element numbersForAttribute:@"position"], (@[@1.5, @-2]));
	XCTAssertEqualObjects([element stringForAttribute:@"position"], @"1.5 -2");

	XCTAssertEqual([element doubleForAttribute:@"missing" defaultValue:3], 3);
	XCTAssertTrue([element boolForAttribute:@"scale" defaultValue:YES], @"a malformed boolean reads as the default");
	XCTAssertFalse(CMTIME_IS_VALID([element timeForAttribute:@"scale"]));
	XCTAssertEqualObjects([element numbersForAttribute:@"missing"], @[]);
	[element setString:@"a b c" forAttribute:@"words"];
	XCTAssertEqualObjects([element numbersForAttribute:@"words"], @[], @"a non-numeric token empties the list");

	[element setString:nil forAttribute:@"rotation"];
	XCTAssertFalse([element hasAttribute:@"rotation"]);
	[element setTime:kCMTimeInvalid forAttribute:@"offset"];
	XCTAssertFalse([element hasAttribute:@"offset"]);
	[element setNumbers:@[] forAttribute:@"position"];
	XCTAssertFalse([element hasAttribute:@"position"]);
	XCTAssertEqualObjects(element.attributes[@"scale"], @"1 1");
	[element setDouble:1e-7 forAttribute:@"tiny"];
	XCTAssertEqual([element doubleForAttribute:@"tiny" defaultValue:0], 1e-7);
	[element setDouble:3 forAttribute:@"whole"];
	XCTAssertEqualObjects([element stringForAttribute:@"whole"], @"3");
}

- (void)testStringValue
{
	FxGripFCPXMLElement *note = [FxGripFCPXMLElement elementNamed:@"note"];
	XCTAssertNil(note.stringValue);
	note.stringValue = @"Check <this> & that";
	XCTAssertEqualObjects(note.stringValue, @"Check <this> & that");
	XCTAssertTrue([note.XMLString containsString:@"&lt;this&gt; &amp; that"]);
	note.stringValue = @"Again";
	XCTAssertEqualObjects(note.stringValue, @"Again");
	note.stringValue = nil;
	XCTAssertNil(note.stringValue);
}

#pragma mark - Tree

- (void)testTreeEditsAndQueries
{
	FxGripFCPXMLStoryElement *clip = [FxGripFCPXMLStoryElement clipWithName:@"A" duration:CMTimeMake(5, 1)];
	FxGripFCPXMLFilter *first = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:@"r1" name:@"One"];
	FxGripFCPXMLFilter *second = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:@"r2" name:@"Two"];
	[clip addChild:first];
	[clip addChild:second];
	XCTAssertEqual(clip.children.count, (NSUInteger)2);
	XCTAssertEqualObjects(first.parent, clip);
	XCTAssertEqual(first.index, (NSUInteger)0);
	XCTAssertEqual(second.index, (NSUInteger)1);
	XCTAssertEqualObjects([clip firstChildNamed:@"filter-video"], first);
	XCTAssertEqual([clip childrenNamed:@"filter-video"].count, (NSUInteger)2);

	FxGripFCPXMLFilter *inserted = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:@"r3" name:@"Zero"];
	[clip insertChild:inserted atIndex:0];
	XCTAssertEqualObjects(clip.children.firstObject, inserted);
	[clip addChild:second afterLastChildNamed:@"filter-video"];
	XCTAssertEqualObjects(clip.children.lastObject, second, @"re-adding moves the child to the end");
	[clip removeChild:inserted];
	XCTAssertNil(inserted.parent);
	XCTAssertEqual(inserted.index, NSNotFound);
	[clip removeChildrenNamed:@"filter-video"];
	XCTAssertEqual(clip.children.count, (NSUInteger)0);

	FxGripFCPXMLElement *created = [clip childNamed:@"note" create:YES];
	XCTAssertEqualObjects(created.name, @"note");
	XCTAssertEqualObjects([clip childNamed:@"note" create:NO], created);
	XCTAssertNil([clip childNamed:@"metadata" create:NO]);
	XCTAssertEqualObjects(clip.path, @"clip", @"a detached element has no leading slash");
}

- (void)testDescendantsAndXPath
{
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	FxGripFCPXMLStoryElement *clip = [FxGripFCPXMLStoryElement clipWithName:@"A" duration:CMTimeMake(5, 1)];
	FxGripFCPXMLFilter *filter = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:@"r1" name:@"One"];
	[filter addParam:[FxGripFCPXMLParam paramWithName:@"Amount" key:@"1" value:@"0.5"]];
	[clip addVideoFilter:filter];
	[[document.libraryCreatingIfNeeded firstEventCreatingIfNeeded] addItem:clip];
	XCTAssertEqual([document.rootElement descendantsNamed:@"param"].count, (NSUInteger)1);
	XCTAssertEqual([document.rootElement elementsForXPath:@"//filter-video[@ref='r1']"].count, (NSUInteger)1);
	XCTAssertEqualObjects(filter.document.rootElement, document.rootElement);
	XCTAssertEqualObjects(filter.path, @"/fcpxml[1]/library[1]/event[1]/clip[1]/filter-video[1]");
	XCTAssertNil([[FxGripFCPXMLElement elementNamed:@"gap"] document]);
}

- (void)testCopyIsDetachedAndDeep
{
	FxGripFCPXMLFilter *filter = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:@"r1" name:@"One"];
	[filter addParam:[FxGripFCPXMLParam paramWithName:@"Amount" key:@"1" value:@"0.5"]];
	FxGripFCPXMLStoryElement *clip = [FxGripFCPXMLStoryElement clipWithName:@"A" duration:CMTimeMake(5, 1)];
	[clip addVideoFilter:filter];
	FxGripFCPXMLFilter *copy = [filter copy];
	XCTAssertTrue([copy isKindOfClass:FxGripFCPXMLFilter.class]);
	XCTAssertNil(copy.parent);
	XCTAssertNotEqualObjects(copy, filter);
	copy.params.firstObject.value = @"1";
	XCTAssertEqualObjects(filter.params.firstObject.value, @"0.5");
}

#pragma mark - Resources

- (void)testResourcesAllocateIdentifiersAndFindEffects
{
	FxGripFCPXMLResources *resources = [[FxGripFCPXMLResources alloc] init];
	XCTAssertEqualObjects(resources.allocateIdentifier, @"r1");
	FxGripFCPXMLFormat *format = [FxGripFCPXMLFormat formatWithFrameDuration:CMTimeMake(1001, 30000) width:1920 height:1080];
	XCTAssertEqualObjects([resources addResource:format], @"r1");
	XCTAssertEqualObjects(resources.allocateIdentifier, @"r2");
	FxGripFCPXMLEffect *effect = [resources effectForFxPlugUUID:@"ABCD-1234" name:@"Grip"];
	XCTAssertEqualObjects(effect.identifier, @"r2");
	XCTAssertEqualObjects(effect.uid, @"FxPlug:ABCD-1234");
	XCTAssertTrue(effect.isFxPlug);
	XCTAssertEqualObjects(effect.fxPlugUUID, @"ABCD-1234");
	XCTAssertEqualObjects([resources effectForFxPlugUUID:@"abcd-1234" name:nil], effect, @"the lookup ignores case and adds nothing");
	XCTAssertEqual(resources.effects.count, (NSUInteger)1);
	XCTAssertEqualObjects([resources resourceWithIdentifier:@"r1"], format);
	XCTAssertEqualObjects([resources effectWithUID:@"FxPlug:ABCD-1234"], effect);
	XCTAssertNil([resources resourceWithIdentifier:@"r9"]);
	XCTAssertEqual(resources.resources.count, (NSUInteger)2);
	XCTAssertEqualObjects(format.frameDuration.value == 1001 ? @"ok" : @"bad", @"ok");
	XCTAssertEqual(format.width, 1920);

	FxGripFCPXMLEffect *custom = [[FxGripFCPXMLEffect alloc] init];
	custom.identifier = @"r2";
	custom.uid = @"~/Effects.localized/Custom/Custom.moef";
	XCTAssertFalse(custom.isFxPlug);
	XCTAssertNil(custom.fxPlugUUID);
	[resources addResource:custom];
	XCTAssertEqualObjects(resources.allocateIdentifier, @"r3", @"the candidate counts distinct identifiers in use");
}

- (void)testFxPlugUIDParsingTrimsAppleSuffixes
{
	XCTAssertEqualObjects([FxGripFCPXMLEffect fxPlugUUIDForUID:@"FxPlug:196B9DB2-28FD-420F-9BA1-3F0E9EEBBAAA:preset1"], @"196B9DB2-28FD-420F-9BA1-3F0E9EEBBAAA");
	XCTAssertEqualObjects([FxGripFCPXMLEffect fxPlugUUIDForUID:@"FxPlug:14B39AEF-607D-42DF-98DD-DB3DD345E925_wrapper"], @"14B39AEF-607D-42DF-98DD-DB3DD345E925");
	XCTAssertNil([FxGripFCPXMLEffect fxPlugUUIDForUID:@"FxPlug:"]);
	XCTAssertNil([FxGripFCPXMLEffect fxPlugUUIDForUID:nil]);
}

- (void)testAssetWithMediaReps
{
	FxGripFCPXMLAsset *asset = [FxGripFCPXMLAsset assetWithName:nil fileURL:[NSURL fileURLWithPath:@"/tmp/Clip.mov"]];
	XCTAssertEqualObjects(asset.resourceName, @"Clip.mov");
	XCTAssertEqualObjects(asset.originalMediaRep.sourceURL.path, @"/tmp/Clip.mov");
	[asset addMediaRepOfKind:@"proxy-media" source:@"file:///tmp/Proxy.mov"];
	XCTAssertEqual(asset.mediaReps.count, (NSUInteger)2);
	XCTAssertEqualObjects(asset.originalMediaRep.kind, @"original-media");
	asset.hasVideo = YES;
	asset.duration = CMTimeMake(10, 1);
	XCTAssertTrue(asset.hasVideo);
	XCTAssertFalse(asset.hasAudio);
	XCTAssertEqualObjects([asset stringForAttribute:@"duration"], @"10s");
}

#pragma mark - Params

- (void)testParamKeyframesStayInTimeOrder
{
	FxGripFCPXMLParam *param = [FxGripFCPXMLParam paramWithName:@"Amount" key:@"1" value:@"0"];
	XCTAssertFalse(param.isAnimated);
	XCTAssertNil(param.keyframeAnimation);
	FxGripFCPXMLKeyframeAnimation *animation = [param keyframeAnimationCreatingIfNeeded];
	[animation addKeyframeAtTime:CMTimeMake(2, 1) value:@"1"];
	[animation addKeyframeAtTime:CMTimeMake(0, 1) value:@"0"];
	FxGripFCPXMLKeyframe *middle = [animation addKeyframeAtTime:CMTimeMake(1, 1) value:@"0.5"];
	middle.interpolation = FxGripFCPXMLKeyframeInterpolationEase;
	[animation addKeyframeAtTime:CMTimeMake(1, 1) value:@"0.75"];
	NSArray<FxGripFCPXMLKeyframe *> *keyframes = animation.keyframes;
	XCTAssertEqual(keyframes.count, (NSUInteger)3);
	XCTAssertEqualObjects(keyframes[0].value, @"0");
	XCTAssertEqualObjects(keyframes[1].value, @"0.75", @"a keyframe at the same time replaces the earlier one");
	XCTAssertEqualObjects(keyframes[2].value, @"1");
	XCTAssertTrue(param.isAnimated);
	XCTAssertEqualObjects([animation keyframeAtTime:CMTimeMake(2, 1)].value, @"1");
	XCTAssertEqualObjects([animation keyframeAtOrBeforeTime:CMTimeMake(3, 2)].value, @"0.75");
	XCTAssertEqualObjects([animation keyframeAtOrAfterTime:CMTimeMake(3, 2)].value, @"1");
	XCTAssertNil([animation keyframeAtOrAfterTime:CMTimeMake(5, 1)]);
	XCTAssertEqualObjects([param valueAtTime:CMTimeMake(1, 1)], @"0.75");
	XCTAssertEqualObjects([param valueAtTime:CMTimeMake(3, 2)], @"0.875", @"numeric values interpolate linearly");
	XCTAssertEqualObjects([param valueAtTime:CMTimeMake(9, 1)], @"1", @"past the last keyframe the last value holds");
	XCTAssertEqualObjects([param valueAtTime:CMTimeMake(-1, 1)], @"0", @"before the first keyframe the first value holds");
	[animation removeAllKeyframes];
	XCTAssertFalse(param.isAnimated);
	[param removeKeyframeAnimation];
	XCTAssertNil(param.keyframeAnimation);
	XCTAssertEqualObjects([param valueAtTime:CMTimeMake(1, 1)], @"0");
}

- (void)testParamFadesAndSubparamsKeepDTDOrder
{
	FxGripFCPXMLParam *param = [FxGripFCPXMLParam paramWithName:@"Volume" key:nil value:@"0dB"];
	[param addSubparam:[FxGripFCPXMLParam paramWithName:@"Inner" key:@"i" value:@"1"]];
	[param setFadeOut:[FxGripFCPXMLFade fadeOutWithDuration:CMTimeMake(1, 1)]];
	[param setFadeIn:[FxGripFCPXMLFade fadeInWithDuration:CMTimeMake(2, 1)]];
	[param keyframeAnimationCreatingIfNeeded];
	NSArray<NSString *> *names = [param.children valueForKey:@"name"];
	XCTAssertEqualObjects(names, (@[@"fadeIn", @"fadeOut", @"keyframeAnimation", @"param"]));
	XCTAssertTrue(param.fadeIn.isFadeIn);
	XCTAssertFalse(param.fadeOut.isFadeIn);
	XCTAssertEqual(CMTimeCompare(param.fadeIn.duration, CMTimeMake(2, 1)), 0);
	XCTAssertEqualObjects([param subparamNamed:@"Inner"].value, @"1");
	XCTAssertEqualObjects([param subparamWithKey:@"i"].paramName, @"Inner");
	XCTAssertNil([param subparamNamed:@"Outer"]);
	[param setFadeIn:nil];
	XCTAssertNil(param.fadeIn);
	param.enabled = NO;
	XCTAssertFalse(param.enabled);
	XCTAssertEqualObjects([param stringForAttribute:@"enabled"], @"0");
	param.enabled = YES;
	XCTAssertFalse([param hasAttribute:@"enabled"], @"the DTD default is left implicit");
	param.auxValue = @"aux";
	XCTAssertEqualObjects(param.auxValue, @"aux");
}

#pragma mark - Filters

- (void)testFilterParamsAndData
{
	FxGripFCPXMLFilter *filter = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:@"r1" name:@"Glow"];
	XCTAssertTrue(filter.isVideo);
	XCTAssertFalse(filter.isAudio);
	XCTAssertTrue(filter.enabled);
	[filter setValue:@"0.5" forParamNamed:@"Amount" key:@"1"];
	[filter setValue:@"1 0 0 1" forParamNamed:@"Color" key:@"2"];
	XCTAssertEqual(filter.params.count, (NSUInteger)2);
	XCTAssertEqualObjects([filter paramWithKey:@"1"].value, @"0.5");
	XCTAssertEqualObjects([filter paramNamed:@"Color"].value, @"1 0 0 1");
	XCTAssertEqualObjects([filter paramWithKey:@"9" orName:@"Amount"].value, @"0.5");
	XCTAssertNil([filter paramWithKey:@"9" orName:@"Nope"]);
	[filter setValue:@"0.75" forParamNamed:@"Amount" key:@"1"];
	XCTAssertEqual(filter.params.count, (NSUInteger)2, @"an existing param is updated, not duplicated");
	XCTAssertEqualObjects([filter paramWithKey:@"1"].value, @"0.75");

	NSData *blob = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
	[filter setData:blob forKey:FxGripFCPXMLDataKeyEffectData];
	XCTAssertEqualObjects(filter.children.firstObject.name, @"data", @"data precedes params in the DTD");
	XCTAssertEqualObjects([filter dataForKey:FxGripFCPXMLDataKeyEffectData].data, blob);
	[filter setData:[@"again" dataUsingEncoding:NSUTF8StringEncoding] forKey:FxGripFCPXMLDataKeyEffectData];
	XCTAssertEqual(filter.dataElements.count, (NSUInteger)1);
	[filter setData:nil forKey:FxGripFCPXMLDataKeyEffectData];
	XCTAssertEqual(filter.dataElements.count, (NSUInteger)0);
	filter.enabled = NO;
	filter.nameOverride = @"My Glow";
	XCTAssertFalse(filter.enabled);
	XCTAssertEqualObjects(filter.nameOverride, @"My Glow");
	[filter removeParam:[filter paramWithKey:@"2"]];
	XCTAssertEqual(filter.params.count, (NSUInteger)1);
	XCTAssertNil(filter.effect, @"a detached filter resolves no effect");

	FxGripFCPXMLFilter *audio = [FxGripFCPXMLFilter audioFilterWithEffectIdentifier:@"r2" name:@"EQ"];
	audio.presetIdentifier = @"p1";
	XCTAssertTrue(audio.isAudio);
	XCTAssertEqualObjects(audio.presetIdentifier, @"p1");
}

- (void)testFilterResolvesEffectThroughDocument
{
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	FxGripFCPXMLEffect *effect = [document.resources effectForFxPlugUUID:@"UUID-1" name:@"Grip"];
	FxGripFCPXMLStoryElement *clip = [FxGripFCPXMLStoryElement clipWithName:@"A" duration:CMTimeMake(1, 1)];
	FxGripFCPXMLFilter *filter = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:effect.identifier name:@"Grip"];
	[clip addVideoFilter:filter];
	[[document.libraryCreatingIfNeeded firstEventCreatingIfNeeded] addItem:clip];
	XCTAssertEqualObjects(filter.effect, effect);
	filter.effectIdentifier = @"r9";
	XCTAssertNil(filter.effect);
}

- (void)testFilterMask
{
	FxGripFCPXMLFilterMask *mask = [[FxGripFCPXMLFilterMask alloc] init];
	[mask addChild:[FxGripFCPXMLElement elementNamed:@"mask-shape"]];
	[mask addChild:[FxGripFCPXMLFilter videoFilterWithEffectIdentifier:@"r1" name:@"Inner"]];
	[mask addChild:[FxGripFCPXMLFilter videoFilterWithEffectIdentifier:@"r1" name:@"Outer"]];
	mask.inverted = YES;
	XCTAssertEqual(mask.masks.count, (NSUInteger)1);
	XCTAssertEqualObjects(mask.innerFilter.filterName, @"Inner");
	XCTAssertEqualObjects(mask.outerFilter.filterName, @"Outer");
	XCTAssertTrue(mask.inverted);
	XCTAssertTrue(mask.enabled);
}

#pragma mark - Story elements

- (void)testStoryElementAttributesAndOrdering
{
	FxGripFCPXMLStoryElement *clip = [FxGripFCPXMLStoryElement clipWithName:@"Shot" duration:CMTimeMake(10, 1)];
	XCTAssertEqualObjects(clip.kind, @"clip");
	XCTAssertTrue([FxGripFCPXMLStoryElement isStoryElementName:@"sync-clip"]);
	XCTAssertFalse([FxGripFCPXMLStoryElement isStoryElementName:@"param"]);
	clip.offset = CMTimeMake(2, 1);
	clip.lane = 1;
	clip.enabled = NO;
	clip.role = @"video.foreground";
	clip.timecodeFormat = @"NDF";
	XCTAssertEqual(CMTimeCompare(clip.endOffset, CMTimeMake(12, 1)), 0);
	XCTAssertEqual(clip.lane, 1);
	XCTAssertFalse(clip.enabled);
	clip.lane = 0;
	XCTAssertFalse([clip hasAttribute:@"lane"]);
	clip.enabled = YES;
	XCTAssertFalse([clip hasAttribute:@"enabled"]);

	FxGripFCPXMLFilter *filter = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:@"r1" name:@"F"];
	[clip addVideoFilter:filter];
	[clip addMarker:[FxGripFCPXMLMarker markerAtStart:CMTimeMake(1, 1) value:@"Note"]];
	[clip addStoryElement:[FxGripFCPXMLStoryElement gapWithDuration:CMTimeMake(1, 1)]];
	[clip adjustmentNamed:@"adjust-transform" create:YES];
	[clip addAudioFilter:[FxGripFCPXMLFilter audioFilterWithEffectIdentifier:@"r2" name:@"A"]];
	clip.note = @"Hello";
	[clip metadataCreatingIfNeeded];
	NSArray<NSString *> *names = [clip.children valueForKey:@"name"];
	XCTAssertEqualObjects(names, (@[@"note", @"adjust-transform", @"gap", @"marker", @"filter-video", @"filter-audio", @"metadata"]));
	XCTAssertEqual(clip.videoFilters.count, (NSUInteger)1);
	XCTAssertEqual(clip.audioFilters.count, (NSUInteger)1);
	XCTAssertEqual(clip.markers.count, (NSUInteger)1);
	XCTAssertEqual(clip.storyChildren.count, (NSUInteger)1);
	XCTAssertEqual([clip videoFiltersWithEffectIdentifier:@"r1"].count, (NSUInteger)1);
	XCTAssertEqual([clip videoFiltersWithEffectIdentifier:@"r7"].count, (NSUInteger)0);
	XCTAssertEqualObjects(clip.note, @"Hello");
	XCTAssertNotNil([clip adjustmentNamed:@"adjust-transform"]);
	XCTAssertNil([clip adjustmentNamed:@"adjust-crop"]);
	clip.note = nil;
	XCTAssertNil(clip.note);
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFCPXMLStoryElement gapWithDuration:kCMTimeInvalid].endOffset));
}

- (void)testSequenceSpineAndAnchoredItems
{
	FxGripFCPXMLStoryElement *sequence = [FxGripFCPXMLStoryElement sequenceWithFormatIdentifier:@"r1" duration:CMTimeMake(20, 1)];
	XCTAssertEqualObjects(sequence.formatIdentifier, @"r1");
	XCTAssertNotNil(sequence.spine);
	XCTAssertEqualObjects([sequence spineCreatingIfNeeded], sequence.spine);
	FxGripFCPXMLStoryElement *clip = [FxGripFCPXMLStoryElement assetClipWithAssetIdentifier:@"r2" name:@"A" duration:CMTimeMake(20, 1)];
	[sequence.spine addStoryElement:clip];
	FxGripFCPXMLStoryElement *title = [FxGripFCPXMLStoryElement titleWithEffectIdentifier:@"r3" name:@"T" duration:CMTimeMake(5, 1)];
	title.lane = 1;
	[clip addStoryElement:title];
	XCTAssertEqualObjects(clip.referenceIdentifier, @"r2");
	XCTAssertEqual(clip.anchoredItems.count, (NSUInteger)1);
	XCTAssertEqualObjects(clip.anchoredItems.firstObject.kind, @"title");
	FxGripFCPXMLStoryElement *video = [FxGripFCPXMLStoryElement videoWithReferenceIdentifier:@"r4" name:@"V" duration:CMTimeMake(1, 1)];
	XCTAssertEqualObjects(video.kind, @"video");
}

- (void)testMarkers
{
	FxGripFCPXMLMarker *marker = [FxGripFCPXMLMarker markerAtStart:CMTimeMake(3, 1) value:@"Fix"];
	XCTAssertFalse(marker.isToDo);
	marker.completed = NO;
	XCTAssertTrue(marker.isToDo);
	XCTAssertFalse(marker.completed);
	marker.note = @"n";
	XCTAssertEqualObjects(marker.note, @"n");
	FxGripFCPXMLMarker *chapter = [FxGripFCPXMLMarker chapterMarkerAtStart:CMTimeMake(1, 1) value:@"Intro"];
	chapter.posterOffset = CMTimeMake(1, 2);
	XCTAssertEqualObjects(chapter.name, @"chapter-marker");
	XCTAssertEqual(CMTimeCompare(chapter.posterOffset, CMTimeMake(1, 2)), 0);
	FxGripFCPXMLMarker *keyword = [FxGripFCPXMLMarker keywordAtStart:CMTimeMake(0, 1) duration:CMTimeMake(4, 1) value:@"a, b"];
	XCTAssertEqualObjects(keyword.value, @"a, b");
	FxGripFCPXMLMarker *rating = [FxGripFCPXMLMarker ratingAtStart:CMTimeMake(0, 1) duration:CMTimeMake(4, 1) value:@"favorite"];
	XCTAssertEqualObjects(rating.name, @"rating");
	XCTAssertEqual(CMTimeCompare(rating.duration, CMTimeMake(4, 1)), 0);
}

- (void)testMetadata
{
	FxGripFCPXMLMetadata *metadata = [[FxGripFCPXMLMetadata alloc] init];
	[metadata setValue:@"Reel 7" type:@"string" forMetadataKey:@"com.apple.proapps.studio.reel"];
	[metadata setArray:@[@"a", @"b"] forMetadataKey:@"keywords"];
	XCTAssertEqualObjects(metadata.keys, (@[@"com.apple.proapps.studio.reel", @"keywords"]));
	XCTAssertEqualObjects([metadata valueForMetadataKey:@"com.apple.proapps.studio.reel"], @"Reel 7");
	XCTAssertEqualObjects([metadata arrayForMetadataKey:@"keywords"], (@[@"a", @"b"]));
	XCTAssertEqualObjects([metadata valueForMetadataKey:@"keywords"], @"a, b");
	XCTAssertEqualObjects([[metadata entryForMetadataKey:@"com.apple.proapps.studio.reel"] stringForAttribute:@"type"], @"string");
	[metadata setValue:@"Reel 8" type:nil forMetadataKey:@"com.apple.proapps.studio.reel"];
	XCTAssertEqual(metadata.keys.count, (NSUInteger)2);
	[metadata setValue:nil type:nil forMetadataKey:@"keywords"];
	XCTAssertNil([metadata valueForMetadataKey:@"keywords"]);
	XCTAssertEqualObjects([metadata arrayForMetadataKey:@"missing"], @[]);
}

#pragma mark - Library

- (void)testLibraryEventsAndProjects
{
	FxGripFCPXMLLibrary *library = [[FxGripFCPXMLLibrary alloc] init];
	library.location = @"file:///Users/me/Movies/Lib.fcpbundle/";
	library.colorProcessing = @"wide-hdr";
	FxGripFCPXMLEvent *event = [library firstEventCreatingIfNeeded];
	XCTAssertEqual(library.events.count, (NSUInteger)1);
	XCTAssertEqualObjects([library firstEventCreatingIfNeeded], event);
	event.eventName = @"Day 1";
	event.uid = @"E1";
	FxGripFCPXMLStoryElement *sequence = [FxGripFCPXMLStoryElement sequenceWithFormatIdentifier:@"r1" duration:CMTimeMake(1, 1)];
	FxGripFCPXMLProject *project = [FxGripFCPXMLProject projectWithName:@"Cut" sequence:sequence];
	[event addItem:project];
	[event addItem:[FxGripFCPXMLStoryElement clipWithName:@"Clip" duration:CMTimeMake(1, 1)]];
	XCTAssertEqualObjects([library eventNamed:@"Day 1"], event);
	XCTAssertNil([library eventNamed:@"Day 2"]);
	XCTAssertEqual(event.projects.count, (NSUInteger)1);
	XCTAssertEqual(event.clips.count, (NSUInteger)1);
	XCTAssertEqual(event.items.count, (NSUInteger)2);
	XCTAssertEqualObjects(project.sequence, sequence);
	XCTAssertEqualObjects(project.projectName, @"Cut");
	project.modificationDate = @"2026-10-10 12:00:00 +0000";
	XCTAssertEqualObjects(project.modificationDate, @"2026-10-10 12:00:00 +0000");
	[project setSequence:[FxGripFCPXMLStoryElement sequenceWithFormatIdentifier:@"r1" duration:CMTimeMake(2, 1)]];
	XCTAssertEqual([project childrenNamed:@"sequence"].count, (NSUInteger)1);
	XCTAssertEqualObjects(library.colorProcessing, @"wide-hdr");
	[library addEvent:[FxGripFCPXMLEvent eventWithName:@"Day 2"]];
	XCTAssertEqual(library.events.count, (NSUInteger)2);
}

#pragma mark - Text

- (void)testTextStylesAndRuns
{
	FxGripFCPXMLTextStyle *definition = [FxGripFCPXMLTextStyle definitionWithIdentifier:@"ts1" font:@"Helvetica" size:72];
	definition.bold = YES;
	definition.fontColor = @[@1, @1, @1, @1];
	definition.alignment = @"center";
	XCTAssertTrue(definition.isDefinition);
	XCTAssertEqualObjects(definition.attributeElement.name, @"text-style");
	XCTAssertEqualObjects(definition.font, @"Helvetica");
	XCTAssertEqual(definition.fontSize, 72);
	XCTAssertTrue(definition.bold);
	XCTAssertEqualObjects(definition.fontColor, (@[@1, @1, @1, @1]));
	XCTAssertEqualObjects([definition.attributeElement stringForAttribute:@"alignment"], @"center");

	FxGripFCPXMLText *text = [[FxGripFCPXMLText alloc] init];
	[text setPlainText:@"Hello" styleReference:@"ts1"];
	XCTAssertEqual(text.spans.count, (NSUInteger)1);
	XCTAssertEqualObjects(text.spans.firstObject.referenceIdentifier, @"ts1");
	XCTAssertEqualObjects(text.plainText, @"Hello");
	[text addSpan:[FxGripFCPXMLTextStyle spanWithReferenceIdentifier:@"ts2" text:@" World"]];
	XCTAssertEqualObjects(text.plainText, @"Hello World");
	[text setPlainText:@"Plain" styleReference:nil];
	XCTAssertEqual(text.spans.count, (NSUInteger)0);
	XCTAssertEqualObjects(text.plainText, @"Plain");
	text.displayStyle = @"pop-on";
	XCTAssertEqualObjects(text.displayStyle, @"pop-on");
}

#pragma mark - Validation

- (void)testValidationProblems
{
	FxGripFCPXMLVersion latest = FxGripFCPXMLVersionLatest();
	FxGripFCPXMLParam *param = [FxGripFCPXMLParam paramWithName:@"Amount" key:@"1" value:@"0.5"];
	XCTAssertEqualObjects([param validationProblemsForVersion:latest recursive:YES], @[]);

	FxGripFCPXMLParam *bad = [[FxGripFCPXMLParam alloc] init];
	[bad setString:@"maybe" forAttribute:@"enabled"];
	[bad setString:@"x" forAttribute:@"bogus"];
	[bad addChild:[FxGripFCPXMLElement elementNamed:@"clip"]];
	NSArray<NSString *> *problems = [bad validationProblemsForVersion:latest recursive:NO];
	XCTAssertEqual(problems.count, (NSUInteger)4);
	XCTAssertTrue([problems[0] containsString:@"'bogus' is not defined"]);
	XCTAssertTrue([problems[1] containsString:@"'enabled' does not accept 'maybe'"]);
	XCTAssertTrue([problems[2] containsString:@"required attribute 'name' is missing"]);
	XCTAssertTrue([problems[3] containsString:@"does not allow a 'clip' child"]);

	FxGripFCPXMLElement *unknown = [FxGripFCPXMLElement elementNamed:@"gizmo"];
	XCTAssertTrue([[unknown validationProblemsForVersion:latest recursive:NO].firstObject containsString:@"not an FCPXML element"]);
	XCTAssertNil(unknown.schemaElement);

	FxGripFCPXMLParam *aux = [FxGripFCPXMLParam paramWithName:@"A" key:nil value:@"1"];
	aux.auxValue = @"2";
	XCTAssertEqual([aux validationProblemsForVersion:FxGripFCPXMLVersionMake(1, 10) recursive:NO].count, (NSUInteger)1,
				   @"auxValue is not in 1.10");
	XCTAssertEqual(aux.minimumVersion.minor, 11);
	XCTAssertEqual(param.minimumVersion.minor, 3, @"key arrived in 1.3");
	FxGripFCPXMLElement *caption = [FxGripFCPXMLElement elementNamed:@"caption"];
	XCTAssertTrue([[caption validationProblemsForVersion:FxGripFCPXMLVersionMake(1, 7) recursive:NO].firstObject containsString:@"not in FCPXML 1.7"]);
	XCTAssertFalse(FxGripFCPXMLVersionIsValid(unknown.minimumVersion));
	[param addChild:unknown];
	XCTAssertFalse(FxGripFCPXMLVersionIsValid(param.minimumVersion), @"an unknown descendant has no version");
	XCTAssertEqual([param validationProblemsForVersion:latest recursive:YES].count, (NSUInteger)2);
}

@end
