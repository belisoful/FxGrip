/*!
	@file       FxGripFCPXMLSchemaTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLSchemaTests
	@abstract   Tests the FCPXML version value and the generated schema table.
	@discussion Introduced in FxGrip 0.1.0. The tests pin facts the DTDs establish: the latest version,
	            when key elements and attributes appeared or disappeared, required attributes, enumerations,
	            and content models. A Final Cut Pro update that adds a DTD changes the latest version, so
	            the pin here is what the generator script's documentation points at.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripFCPXMLVersion.h>
#import <FxGrip/FxGripFCPXMLSchema.h>

@interface FxGripFCPXMLSchemaTests : XCTestCase
@end

@implementation FxGripFCPXMLSchemaTests

#pragma mark - Version

- (void)testVersionStringRoundTrip
{
	FxGripFCPXMLVersion version = FxGripFCPXMLVersionFromString(@"1.11");
	XCTAssertEqual(version.major, 1);
	XCTAssertEqual(version.minor, 11);
	XCTAssertEqualObjects(FxGripFCPXMLVersionString(version), @"1.11");
	XCTAssertNil(FxGripFCPXMLVersionString(FxGripFCPXMLVersionInvalid));
}

- (void)testVersionRejectsMalformedStrings
{
	XCTAssertFalse(FxGripFCPXMLVersionIsValid(FxGripFCPXMLVersionFromString(nil)));
	XCTAssertFalse(FxGripFCPXMLVersionIsValid(FxGripFCPXMLVersionFromString(@"1")));
	XCTAssertFalse(FxGripFCPXMLVersionIsValid(FxGripFCPXMLVersionFromString(@"1.x")));
	XCTAssertFalse(FxGripFCPXMLVersionIsValid(FxGripFCPXMLVersionFromString(@"-1.2")));
	XCTAssertFalse(FxGripFCPXMLVersionIsValid(FxGripFCPXMLVersionFromString(@"1.2.3")));
}

- (void)testVersionComparison
{
	XCTAssertEqual(FxGripFCPXMLVersionCompare(FxGripFCPXMLVersionMake(1, 9), FxGripFCPXMLVersionMake(1, 10)), NSOrderedAscending);
	XCTAssertEqual(FxGripFCPXMLVersionCompare(FxGripFCPXMLVersionMake(2, 0), FxGripFCPXMLVersionMake(1, 14)), NSOrderedDescending);
	XCTAssertEqual(FxGripFCPXMLVersionCompare(FxGripFCPXMLVersionMake(1, 5), FxGripFCPXMLVersionMake(1, 5)), NSOrderedSame);
	XCTAssertTrue(FxGripFCPXMLVersionEqual(FxGripFCPXMLVersionEarliest, FxGripFCPXMLVersionMake(1, 0)));
}

- (void)testLatestVersionIsOneFourteen
{
	FxGripFCPXMLVersion latest = FxGripFCPXMLVersionLatest();
	XCTAssertEqual(latest.major, 1);
	XCTAssertEqual(latest.minor, 14, @"regenerate the schema with Scripts/make-fcpxml-schema.py and update this pin after a Final Cut Pro update");
	XCTAssertTrue(FxGripFCPXMLVersionEqual(FxGripFCPXMLSchema.sharedSchema.latestVersion, latest));
	XCTAssertTrue(FxGripFCPXMLVersionEqual(FxGripFCPXMLSchema.sharedSchema.earliestVersion, FxGripFCPXMLVersionEarliest));
}

#pragma mark - Elements

- (void)testSchemaKnowsEveryElementOfTheLatestDTD
{
	FxGripFCPXMLSchema *schema = FxGripFCPXMLSchema.sharedSchema;
	NSArray *available = [schema elementNamesAvailableInVersion:schema.latestVersion];
	for (NSString *name in @[@"fcpxml", @"resources", @"format", @"asset", @"media-rep", @"effect", @"media", @"locator",
							 @"library", @"event", @"project", @"sequence", @"spine", @"clip", @"asset-clip", @"ref-clip",
							 @"sync-clip", @"mc-clip", @"video", @"audio", @"title", @"gap", @"transition", @"caption",
							 @"live-drawing", @"filter-video", @"filter-video-mask", @"filter-audio", @"param",
							 @"keyframeAnimation", @"keyframe", @"fadeIn", @"fadeOut", @"marker", @"chapter-marker",
							 @"keyword", @"rating", @"metadata", @"md", @"text", @"text-style", @"text-style-def",
							 @"match-analysis-type", @"adjust-stereo-3D", @"object-tracker"]) {
		XCTAssertTrue([available containsObject:name], @"%@ is in FCPXML 1.14", name);
	}
	XCTAssertFalse([available containsObject:@"filter"], @"the generic filter left in 1.3");
	XCTAssertEqual(schema.elementNames.count, (NSUInteger)128);
}

- (void)testElementLifetimes
{
	FxGripFCPXMLSchema *schema = FxGripFCPXMLSchema.sharedSchema;
	FxGripFCPXMLSchemaElement *keyframe = [schema elementNamed:@"keyframe"];
	XCTAssertEqual(keyframe.introducedIn.minor, 4);
	XCTAssertFalse(FxGripFCPXMLVersionIsValid(keyframe.removedIn));
	XCTAssertFalse([keyframe isAvailableInVersion:FxGripFCPXMLVersionMake(1, 3)]);
	XCTAssertTrue([keyframe isAvailableInVersion:FxGripFCPXMLVersionMake(1, 4)]);

	FxGripFCPXMLSchemaElement *filter = [schema elementNamed:@"filter"];
	XCTAssertEqual(filter.introducedIn.minor, 0);
	XCTAssertEqual(filter.removedIn.minor, 3);
	XCTAssertTrue([filter isAvailableInVersion:FxGripFCPXMLVersionMake(1, 2)]);
	XCTAssertFalse([filter isAvailableInVersion:FxGripFCPXMLVersionMake(1, 3)]);

	XCTAssertEqualObjects([schema elementNamesIntroducedInVersion:FxGripFCPXMLVersionMake(1, 14)], @[@"match-analysis-type"]);
	XCTAssertEqualObjects([schema elementNamesIntroducedInVersion:FxGripFCPXMLVersionMake(1, 13)], (@[@"adjust-stereo-3D", @"hidden-clip-marker"]));
	XCTAssertTrue([[schema elementNamesRemovedInVersion:FxGripFCPXMLVersionMake(1, 5)] containsObject:@"adjust-color"]);
	XCTAssertNil([schema elementNamed:@"no-such-element"]);
}

- (void)testParamAttributes
{
	FxGripFCPXMLSchemaElement *param = [FxGripFCPXMLSchema.sharedSchema elementNamed:@"param"];
	XCTAssertEqualObjects(param.requiredAttributeNames, @[@"name"]);
	XCTAssertEqual([param attributeNamed:@"key"].introducedIn.minor, 3);
	XCTAssertEqual([param attributeNamed:@"auxValue"].introducedIn.minor, 11);
	FxGripFCPXMLSchemaAttribute *keyTimes = [param attributeNamed:@"keyTimes"];
	XCTAssertEqual(keyTimes.introducedIn.minor, 1);
	XCTAssertEqual(keyTimes.removedIn.minor, 4);
	XCTAssertTrue([keyTimes isAvailableInVersion:FxGripFCPXMLVersionMake(1, 3)]);
	XCTAssertFalse([keyTimes isAvailableInVersion:FxGripFCPXMLVersionMake(1, 4)]);
	FxGripFCPXMLSchemaAttribute *enabled = [param attributeNamed:@"enabled"];
	XCTAssertEqual(enabled.kind, FxGripFCPXMLAttributeKindEnumeration);
	XCTAssertEqualObjects(enabled.enumeratedValues, (@[@"0", @"1"]));
	XCTAssertEqualObjects(enabled.defaultValue, @"1");
	XCTAssertTrue([enabled acceptsValue:@"0"]);
	XCTAssertFalse([enabled acceptsValue:@"yes"]);
	XCTAssertTrue([param.childElementNames containsObject:@"keyframeAnimation"]);
	XCTAssertTrue([param allowsChildNamed:@"param"]);
	XCTAssertFalse([param allowsChildNamed:@"clip"]);
}

- (void)testAttributeKinds
{
	FxGripFCPXMLSchema *schema = FxGripFCPXMLSchema.sharedSchema;
	FxGripFCPXMLSchemaAttribute *time = [[schema elementNamed:@"keyframe"] attributeNamed:@"time"];
	XCTAssertEqual(time.kind, FxGripFCPXMLAttributeKindTime);
	XCTAssertTrue(time.required);
	XCTAssertTrue([time acceptsValue:@"1001/30000s"]);
	XCTAssertFalse([time acceptsValue:@"later"]);
	XCTAssertFalse([time acceptsValue:nil], @"a required attribute refuses absence");

	FxGripFCPXMLSchemaAttribute *identifier = [[schema elementNamed:@"effect"] attributeNamed:@"id"];
	XCTAssertEqual(identifier.kind, FxGripFCPXMLAttributeKindIdentifier);
	FxGripFCPXMLSchemaAttribute *reference = [[schema elementNamed:@"filter-video"] attributeNamed:@"ref"];
	XCTAssertEqual(reference.kind, FxGripFCPXMLAttributeKindReference);
	XCTAssertFalse([reference acceptsValue:@""]);
	FxGripFCPXMLSchemaAttribute *name = [[schema elementNamed:@"effect"] attributeNamed:@"name"];
	XCTAssertEqual(name.kind, FxGripFCPXMLAttributeKindString);
	XCTAssertTrue([name acceptsValue:nil], @"an optional attribute accepts absence");
	XCTAssertEqual([[schema elementNamed:@"filter-video"] attributeNamed:@"nameOverride"].introducedIn.minor, 12);
	XCTAssertEqual([[schema elementNamed:@"effect"] attributeNamed:@"src"].introducedIn.minor, 6);
}

- (void)testMinimumVersionLookup
{
	FxGripFCPXMLSchema *schema = FxGripFCPXMLSchema.sharedSchema;
	XCTAssertEqual([schema minimumVersionForElementNamed:@"caption" attributeNamed:nil].minor, 8);
	XCTAssertEqual([schema minimumVersionForElementNamed:@"keyframe" attributeNamed:@"auxValue"].minor, 11);
	XCTAssertFalse(FxGripFCPXMLVersionIsValid([schema minimumVersionForElementNamed:@"keyframe" attributeNamed:@"nope"]));
	XCTAssertFalse(FxGripFCPXMLVersionIsValid([schema minimumVersionForElementNamed:@"nope" attributeNamed:nil]));
}

- (void)testContentModels
{
	FxGripFCPXMLSchema *schema = FxGripFCPXMLSchema.sharedSchema;
	FxGripFCPXMLSchemaElement *fcpxml = [schema elementNamed:@"fcpxml"];
	XCTAssertTrue([fcpxml allowsChildNamed:@"resources"]);
	XCTAssertTrue([fcpxml allowsChildNamed:@"library"]);
	XCTAssertTrue([fcpxml allowsChildNamed:@"import-options"]);
	XCTAssertFalse([fcpxml allowsChildNamed:@"sequence"]);
	FxGripFCPXMLSchemaElement *clip = [schema elementNamed:@"clip"];
	XCTAssertTrue([clip allowsChildNamed:@"filter-video"]);
	XCTAssertTrue([clip allowsChildNamed:@"marker"]);
	XCTAssertTrue([clip allowsChildNamed:@"adjust-transform"]);
	XCTAssertFalse([clip allowsChildNamed:@"param"]);
	XCTAssertEqual([schema elementNamed:@"effect"].childElementNames.count, (NSUInteger)0);
}

@end
