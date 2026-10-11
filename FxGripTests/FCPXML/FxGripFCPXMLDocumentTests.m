/*!
	@file       FxGripFCPXMLDocumentTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLDocumentTests
	@abstract   Tests the FCPXML document: parsing, structure, lookup, validation, and writing.
	@discussion Introduced in FxGrip 0.1.0. The tests parse a representative project the way Final Cut Pro
	            exports it, round-trip it through bytes and through a `.fcpxmld` package, build a document
	            from scratch, validate against the schema, and validate against the installed DTD when
	            Final Cut Pro is present.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripFCPXMLDocument.h>
#import <FxGrip/FxGripFCPXMLParam.h>
#import <FxGrip/FxGripFCPXMLFilter.h>
#import <FxGrip/FxGripFCPXMLStoryElement.h>
#import <FxGrip/FxGripFinalCutPro.h>
#import <FxGrip/FxGripErrors.h>

static NSString *const kFxGripFCPXMLSampleProject =
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
@"<!DOCTYPE fcpxml>\n"
@"<fcpxml version=\"1.14\">\n"
@"  <import-options>\n"
@"    <option key=\"copy assets\" value=\"0\"/>\n"
@"  </import-options>\n"
@"  <resources>\n"
@"    <format id=\"r1\" name=\"FFVideoFormat1080p2997\" frameDuration=\"1001/30000s\" width=\"1920\" height=\"1080\" colorSpace=\"1-1-1 (Rec. 709)\"/>\n"
@"    <asset id=\"r2\" name=\"Clip\" uid=\"ASSET-1\" start=\"0s\" duration=\"600600/30000s\" hasVideo=\"1\" format=\"r1\" hasAudio=\"1\" audioSources=\"1\" audioChannels=\"2\" audioRate=\"48000\">\n"
@"      <media-rep kind=\"original-media\" sig=\"ASSET-1\" src=\"file:///Users/me/Movies/Clip.mov\"/>\n"
@"      <metadata>\n"
@"        <md key=\"com.apple.proapps.studio.reel\" value=\"A001\"/>\n"
@"      </metadata>\n"
@"    </asset>\n"
@"    <effect id=\"r3\" name=\"Grip Glow\" uid=\"FxPlug:11111111-2222-3333-4444-555555555555\"/>\n"
@"    <effect id=\"r4\" name=\"Basic Title\" uid=\"~/Titles.localized/Bumper:Opener.localized/Basic Title.localized/Basic Title.moti\"/>\n"
@"  </resources>\n"
@"  <library location=\"file:///Users/me/Movies/Lib.fcpbundle/\">\n"
@"    <event name=\"Day 1\" uid=\"EVENT-1\">\n"
@"      <project name=\"Cut\" uid=\"PROJECT-1\" modDate=\"2026-10-10 12:00:00 +0000\">\n"
@"        <sequence format=\"r1\" duration=\"600600/30000s\" tcStart=\"0s\" tcFormat=\"NDF\" audioLayout=\"stereo\" audioRate=\"48k\">\n"
@"          <spine>\n"
@"            <asset-clip ref=\"r2\" offset=\"0s\" name=\"Clip\" duration=\"600600/30000s\" tcFormat=\"NDF\">\n"
@"              <adjust-transform position=\"0 0\" scale=\"1 1\"/>\n"
@"              <title ref=\"r4\" lane=\"1\" offset=\"30030/30000s\" name=\"Opener\" duration=\"120120/30000s\">\n"
@"                <text>\n"
@"                  <text-style ref=\"ts1\">Hello</text-style>\n"
@"                </text>\n"
@"                <text-style-def id=\"ts1\">\n"
@"                  <text-style font=\"Helvetica\" fontSize=\"72\" fontColor=\"1 1 1 1\" bold=\"1\" alignment=\"center\"/>\n"
@"                </text-style-def>\n"
@"              </title>\n"
@"              <marker start=\"60060/30000s\" duration=\"1001/30000s\" value=\"Check\" completed=\"0\"/>\n"
@"              <keyword start=\"0s\" duration=\"600600/30000s\" value=\"Interview\"/>\n"
@"              <filter-video ref=\"r3\" name=\"Grip Glow\" nameOverride=\"Soft Glow\">\n"
@"                <param name=\"Amount\" key=\"1\" value=\"0.5\">\n"
@"                  <keyframeAnimation>\n"
@"                    <keyframe time=\"0s\" value=\"0\"/>\n"
@"                    <keyframe time=\"30030/30000s\" value=\"1\" interp=\"easeIn\"/>\n"
@"                  </keyframeAnimation>\n"
@"                </param>\n"
@"                <param name=\"Tint\" key=\"2\" value=\"1 0.5 0.25 1\"/>\n"
@"                <param name=\"Center\" key=\"3\" value=\"0.25 -0.25\"/>\n"
@"                <param name=\"Enabled\" key=\"4\" value=\"1\"/>\n"
@"                <param name=\"Label\" key=\"5\" value=\"Hello\"/>\n"
@"              </filter-video>\n"
@"            </asset-clip>\n"
@"          </spine>\n"
@"        </sequence>\n"
@"      </project>\n"
@"    </event>\n"
@"  </library>\n"
@"</fcpxml>\n";

@interface FxGripFCPXMLDocumentTests : XCTestCase
@property (nonatomic, strong) NSURL *sandboxURL;
@end

@implementation FxGripFCPXMLDocumentTests

- (void)setUp
{
	[super setUp];
	self.sandboxURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
					   URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:self.sandboxURL withIntermediateDirectories:YES attributes:nil error:NULL];
}

- (void)tearDown
{
	[NSFileManager.defaultManager removeItemAtURL:self.sandboxURL error:NULL];
	[super tearDown];
}

- (FxGripFCPXMLDocument *)sampleDocument
{
	NSError *error = nil;
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] initWithXMLString:kFxGripFCPXMLSampleProject error:&error];
	XCTAssertNotNil(document, @"%@", error);
	return document;
}

#pragma mark - Parsing

- (void)testParsesTheSampleProject
{
	FxGripFCPXMLDocument *document = self.sampleDocument;
	XCTAssertEqual(document.version.minor, 14);
	XCTAssertEqualObjects(document.importOptions, @{@"copy assets": @"0"});
	XCTAssertTrue(document.hasResources);
	XCTAssertEqual(document.resources.formats.count, (NSUInteger)1);
	XCTAssertEqual(document.resources.assets.count, (NSUInteger)1);
	XCTAssertEqual(document.resources.effects.count, (NSUInteger)2);
	XCTAssertEqualObjects([document.resources effectWithFxPlugUUID:@"11111111-2222-3333-4444-555555555555"].identifier, @"r3");
	XCTAssertEqualObjects(document.library.location, @"file:///Users/me/Movies/Lib.fcpbundle/");
	XCTAssertEqual(document.events.count, (NSUInteger)1);
	XCTAssertEqual(document.projects.count, (NSUInteger)1);
	XCTAssertEqualObjects(document.events.firstObject.eventName, @"Day 1");
	FxGripFCPXMLProject *project = document.projects.firstObject;
	XCTAssertEqualObjects(project.projectName, @"Cut");
	FxGripFCPXMLStoryElement *sequence = project.sequence;
	XCTAssertEqualObjects(sequence.kind, @"sequence");
	XCTAssertEqual(CMTimeCompare(sequence.duration, CMTimeMake(600600, 30000)), 0);
	FxGripFCPXMLStoryElement *clip = sequence.spine.storyChildren.firstObject;
	XCTAssertEqualObjects(clip.kind, @"asset-clip");
	XCTAssertEqualObjects(clip.referenceIdentifier, @"r2");
	XCTAssertEqualObjects([document resourceReferencedByElement:clip].resourceName, @"Clip");
	XCTAssertEqual(clip.anchoredItems.count, (NSUInteger)1);
	XCTAssertEqual(clip.markers.count, (NSUInteger)2);
	XCTAssertTrue(clip.markers.firstObject.isToDo);
	XCTAssertNotNil([clip adjustmentNamed:@"adjust-transform"]);
	FxGripFCPXMLFilter *filter = clip.videoFilters.firstObject;
	XCTAssertEqualObjects(filter.nameOverride, @"Soft Glow");
	XCTAssertEqualObjects(filter.effect.fxPlugUUID, @"11111111-2222-3333-4444-555555555555");
	XCTAssertEqual(filter.params.count, (NSUInteger)5);
	FxGripFCPXMLParam *amount = [filter paramWithKey:@"1"];
	XCTAssertTrue(amount.isAnimated);
	XCTAssertEqualObjects(amount.keyframeAnimation.keyframes.lastObject.interpolation, @"easeIn");
	XCTAssertEqualObjects([amount valueAtTime:CMTimeMake(15015, 30000)], @"0.5");
	XCTAssertEqualObjects([document elementWithIdentifier:@"ts1"].name, @"text-style-def");
	XCTAssertNil([document elementWithIdentifier:@"nope"]);
	XCTAssertEqual([document elementsNamed:@"param"].count, (NSUInteger)5);
	XCTAssertEqualObjects(document.validationProblems, @[]);
	XCTAssertEqual(document.minimumVersion.minor, 12, @"nameOverride arrived in 1.12");
}

- (void)testRejectsNonFCPXML
{
	NSError *error = nil;
	XCTAssertNil([[FxGripFCPXMLDocument alloc] initWithXMLString:@"<plist/>" error:&error]);
	XCTAssertEqual(error.code, kFxGripError_FCPXML);
	XCTAssertTrue([error.localizedDescription containsString:@"'plist'"]);
	error = nil;
	XCTAssertNil([[FxGripFCPXMLDocument alloc] initWithXMLString:@"not xml" error:&error]);
	XCTAssertNotNil(error);
	XCTAssertNil([[FxGripFCPXMLDocument alloc] initWithData:(id _Nonnull)nil error:&error]);
	XCTAssertEqual(error.code, kFxGripError_FCPXML);
	XCTAssertNil([[FxGripFCPXMLDocument alloc] initWithContentsOfURL:[self.sandboxURL URLByAppendingPathComponent:@"missing.fcpxml"] error:&error]);
	XCTAssertNotNil(error);
}

- (void)testAbsentVersionReadsAsLatest
{
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] initWithXMLString:@"<fcpxml/>" error:NULL];
	XCTAssertTrue(FxGripFCPXMLVersionEqual(document.version, FxGripFCPXMLVersionLatest()));
	document.version = FxGripFCPXMLVersionMake(1, 9);
	XCTAssertEqualObjects([document.rootElement stringForAttribute:@"version"], @"1.9");
	XCTAssertFalse(document.hasResources);
	XCTAssertEqual(document.topLevelItems.count, (NSUInteger)0);
	XCTAssertNil(document.library);
}

#pragma mark - Round trips

- (void)testWritesWithDeclarationAndDoctypeAndRoundTrips
{
	FxGripFCPXMLDocument *document = self.sampleDocument;
	NSString *xml = document.XMLString;
	XCTAssertTrue([xml hasPrefix:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE fcpxml>\n<fcpxml version=\"1.14\">"]);
	FxGripFCPXMLDocument *again = [[FxGripFCPXMLDocument alloc] initWithData:document.XMLData error:NULL];
	XCTAssertEqualObjects(again.XMLString, xml);
	XCTAssertEqual(again.projects.count, (NSUInteger)1);
	XCTAssertTrue([xml containsString:@"nameOverride=\"Soft Glow\""]);
	XCTAssertTrue([xml containsString:@"<option key=\"copy assets\" value=\"0\"/>"]);
}

- (void)testWritesAndReadsFileAndBundle
{
	FxGripFCPXMLDocument *document = self.sampleDocument;
	NSURL *fileURL = [self.sandboxURL URLByAppendingPathComponent:@"Cut.fcpxml"];
	NSError *error = nil;
	XCTAssertTrue([document writeToURL:fileURL error:&error], @"%@", error);
	FxGripFCPXMLDocument *fromFile = [[FxGripFCPXMLDocument alloc] initWithContentsOfURL:fileURL error:&error];
	XCTAssertNotNil(fromFile, @"%@", error);
	XCTAssertNil(fromFile.bundleURL);

	NSURL *bundleURL = [self.sandboxURL URLByAppendingPathComponent:@"Cut.fcpxmld"];
	XCTAssertTrue([document writeToURL:bundleURL error:&error], @"%@", error);
	XCTAssertEqualObjects(document.bundleURL, bundleURL);
	BOOL isDirectory = NO;
	XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:bundleURL.path isDirectory:&isDirectory] && isDirectory);
	XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:[bundleURL URLByAppendingPathComponent:FxGripFCPXMLBundleInfoFileName].path]);
	FxGripFCPXMLDocument *fromBundle = [[FxGripFCPXMLDocument alloc] initWithContentsOfURL:bundleURL error:&error];
	XCTAssertNotNil(fromBundle, @"%@", error);
	XCTAssertEqualObjects(fromBundle.bundleURL, bundleURL);
	XCTAssertEqualObjects(fromBundle.XMLString, document.XMLString);
	XCTAssertEqualObjects(fromBundle.rootElement.document.bundleURL, bundleURL, @"the bundle is reachable from any element");
}

- (void)testCopyIsIndependent
{
	FxGripFCPXMLDocument *document = self.sampleDocument;
	FxGripFCPXMLDocument *copy = [document copy];
	copy.version = FxGripFCPXMLVersionMake(1, 10);
	[copy.resources addResource:[FxGripFCPXMLEffect effectWithFxPlugUUID:@"X" name:@"X"]];
	XCTAssertEqual(document.version.minor, 14);
	XCTAssertEqual(document.resources.effects.count, (NSUInteger)2);
	XCTAssertEqual(copy.resources.effects.count, (NSUInteger)3);
}

#pragma mark - Building

- (void)testBuildsADocumentInDTDOrder
{
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	XCTAssertTrue(FxGripFCPXMLVersionEqual(document.version, FxGripFCPXMLVersionLatest()));
	XCTAssertTrue(document.hasResources);
	FxGripFCPXMLFormat *format = [FxGripFCPXMLFormat formatWithFrameDuration:CMTimeMake(100, 2400) width:1920 height:1080];
	[document.resources addResource:format];
	FxGripFCPXMLAsset *asset = [FxGripFCPXMLAsset assetWithName:@"Clip" fileURL:[NSURL fileURLWithPath:@"/tmp/Clip.mov"]];
	asset.formatIdentifier = format.identifier;
	asset.hasVideo = YES;
	asset.duration = CMTimeMake(10, 1);
	[document.resources addResource:asset];
	FxGripFCPXMLEffect *effect = [document.resources effectForFxPlugUUID:@"UUID-1" name:@"Grip"];
	FxGripFCPXMLStoryElement *sequence = [FxGripFCPXMLStoryElement sequenceWithFormatIdentifier:format.identifier duration:CMTimeMake(10, 1)];
	FxGripFCPXMLStoryElement *clip = [FxGripFCPXMLStoryElement assetClipWithAssetIdentifier:asset.identifier name:@"Clip" duration:CMTimeMake(10, 1)];
	FxGripFCPXMLFilter *filter = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:effect.identifier name:@"Grip"];
	[filter setValue:@"0.5" forParamNamed:@"Amount" key:@"1"];
	[clip addVideoFilter:filter];
	[sequence.spine addStoryElement:clip];
	FxGripFCPXMLProject *project = [FxGripFCPXMLProject projectWithName:@"Build" sequence:sequence];
	FxGripFCPXMLEvent *event = [document.libraryCreatingIfNeeded firstEventCreatingIfNeeded];
	event.eventName = @"Built";
	[event addItem:project];
	document.importOptions = @{@"copy assets": @"1", @"suppress warnings": @"1"};

	NSArray<NSString *> *rootChildren = [document.rootElement.children valueForKey:@"name"];
	XCTAssertEqualObjects(rootChildren, (@[@"import-options", @"resources", @"library"]));
	XCTAssertEqualObjects(document.validationProblems, @[]);
	XCTAssertEqual(document.minimumVersion.minor, 9, @"media-rep arrived in 1.9");
	XCTAssertEqualObjects(document.importOptions[@"suppress warnings"], @"1");
	document.importOptions = @{};
	XCTAssertEqual(document.importOptions.count, (NSUInteger)0);
	XCTAssertEqualObjects([document.rootElement.children valueForKey:@"name"], (@[@"resources", @"library"]));
	XCTAssertEqualObjects(filter.effect, effect);
	XCTAssertEqualObjects(document.library.events.firstObject, event);
	XCTAssertTrue([document.description containsString:@"1.14"]);
}

- (void)testTopLevelEventsWithoutLibrary
{
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	[document addTopLevelItem:[FxGripFCPXMLEvent eventWithName:@"Loose"]];
	XCTAssertNil(document.library);
	XCTAssertEqual(document.events.count, (NSUInteger)1);
	XCTAssertEqual(document.topLevelItems.count, (NSUInteger)1);
	XCTAssertEqualObjects(document.validationProblems, @[]);
}

#pragma mark - Validation

- (void)testValidationReportsDanglingReferencesAndDuplicateIdentifiers
{
	FxGripFCPXMLDocument *document = self.sampleDocument;
	FxGripFCPXMLStoryElement *clip = document.projects.firstObject.sequence.spine.storyChildren.firstObject;
	clip.videoFilters.firstObject.effectIdentifier = @"r99";
	FxGripFCPXMLEffect *duplicate = [FxGripFCPXMLEffect effectWithFxPlugUUID:@"D" name:@"D"];
	duplicate.identifier = @"r1";
	[document.resources addResource:duplicate];
	NSArray<NSString *> *problems = document.validationProblems;
	XCTAssertEqual(problems.count, (NSUInteger)2, @"%@", problems);
	XCTAssertTrue([problems[0] containsString:@"'r1' is declared twice"]);
	XCTAssertTrue([problems[1] containsString:@"'ref' refers to 'r99'"]);
}

- (void)testValidationReportsVersionMismatch
{
	FxGripFCPXMLDocument *document = self.sampleDocument;
	document.version = FxGripFCPXMLVersionMake(1, 8);
	NSArray<NSString *> *problems = document.validationProblems;
	XCTAssertTrue(problems.count >= 2, @"%@", problems);
	BOOL mentionsMediaRep = NO;
	BOOL mentionsNameOverride = NO;
	for (NSString *problem in problems) {
		mentionsMediaRep |= [problem containsString:@"'media-rep' is not in FCPXML 1.8"];
		mentionsNameOverride |= [problem containsString:@"'nameOverride' is not in FCPXML 1.8"];
	}
	XCTAssertTrue(mentionsMediaRep);
	XCTAssertTrue(mentionsNameOverride);
}

- (void)testDTDValidationAgainstInstalledFinalCutPro
{
	FxGripFCPXMLDocument *document = self.sampleDocument;
	NSURL *dtd = [FxGripFinalCutPro installedDTDURLForVersion:document.version];
	if (dtd == nil) {
		NSError *error = nil;
		XCTAssertFalse([document validateAgainstDTDAtURL:nil error:&error]);
		XCTAssertEqual(error.code, kFxGripError_FCPXML);
		return;
	}
	NSError *error = nil;
	XCTAssertTrue([document validateAgainstDTDAtURL:nil error:&error], @"%@", error);
	XCTAssertTrue([document validateAgainstDTDAtURL:dtd error:&error], @"%@", error);
	XCTAssertEqualObjects(document.XMLString, self.sampleDocument.XMLString, @"validation leaves the document unchanged");

	FxGripFCPXMLDocument *broken = [document copy];
	[broken.rootElement addChild:[FxGripFCPXMLElement elementNamed:@"gizmo"]];
	XCTAssertFalse([broken validateAgainstDTDAtURL:nil error:&error]);
	XCTAssertNotNil(error);

	FxGripFCPXMLDocument *built = [[FxGripFCPXMLDocument alloc] init];
	FxGripFCPXMLEffect *effect = [built.resources effectForFxPlugUUID:@"UUID-1" name:@"Grip"];
	FxGripFCPXMLStoryElement *clip = [FxGripFCPXMLStoryElement clipWithName:@"Grip" duration:CMTimeMake(1, 1)];
	FxGripFCPXMLFilter *filter = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:effect.identifier name:@"Grip"];
	[filter setValue:@"0.5" forParamNamed:@"Amount" key:@"1"];
	[clip addVideoFilter:filter];
	[[built.libraryCreatingIfNeeded firstEventCreatingIfNeeded] addItem:clip];
	XCTAssertTrue([built validateAgainstDTDAtURL:nil error:&error], @"a filter-only clip is DTD-valid: %@", error);
	XCTAssertEqualObjects(built.validationProblems, @[]);
}

@end
