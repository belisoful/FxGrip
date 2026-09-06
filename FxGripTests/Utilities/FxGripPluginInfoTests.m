/*!
	@file       FxGripPluginInfoTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPluginInfoTests
	@abstract   Unit tests for FxGripPluginInfo property readers, localization, and plugin lookups.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the separator character set, the recursive localizeObject: pass, the Info.plist property readers, the class-name and UUID plugin lookups, the shared instance, and host identity. They also cover the FxMatrix44 (FxGrip) category and the FxGripTypes.h inline rect conversions.
*/

#import <XCTest/XCTest.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/FxGripPluginInfo.h"
#import "FxGrip/FxMatrix+FxGrip.h"

/*!
	A subclass that stages a plugin list. The lookups dispatch +plugIns on the receiving
	class, so the list the Info.plist would supply is replaced here.
*/
@interface FxGripPluginInfoTestStub : FxGripPluginInfo
@end

@implementation FxGripPluginInfoTestStub

+ (NSArray *)plugIns
{
	return @[
		@{ kProPlugPlugIn_ClassNameProperty: @"FxGripMixedCasePlugin",
		   kProPlugPlugIn_UuidProperty: @"AAAABBBB-CCCC-DDDD-EEEE-FFFF00001111",
		   @"marker": @"mixed" },
		@{ kProPlugPlugIn_ClassNameProperty: @"fxgriplowercaseplugin",
		   @"marker": @"lower" },
		@{ kProPlugPlugIn_ClassNameProperty: @42 }
	];
}

@end

@interface FxGripPluginInfoTests : XCTestCase
@end

@implementation FxGripPluginInfoTests

#pragma mark - Separator Set

/*! @abstract The separator set contains space, tab, newline, and the sentence dividers period, comma, and semicolon. */
- (void)testSeparatorSetContainsWhitespaceAndTheHumanDividers
{
	NSCharacterSet *set = FxGripPluginInfo.separatorSet;

	XCTAssertTrue([set characterIsMember:' ']);
	XCTAssertTrue([set characterIsMember:'\t']);
	XCTAssertTrue([set characterIsMember:'\n']);
	XCTAssertTrue([set characterIsMember:'.']);
	XCTAssertTrue([set characterIsMember:',']);
	XCTAssertTrue([set characterIsMember:';']);
}

/*! @abstract The separator set excludes letters, digits, and the joining characters hyphen, plus, and colon. */
- (void)testSeparatorSetExcludesOrdinaryCharacters
{
	NSCharacterSet *set = FxGripPluginInfo.separatorSet;

	XCTAssertFalse([set characterIsMember:'a']);
	XCTAssertFalse([set characterIsMember:'Z']);
	XCTAssertFalse([set characterIsMember:'0']);
	XCTAssertFalse([set characterIsMember:'-']);
	XCTAssertFalse([set characterIsMember:'+']);
	XCTAssertFalse([set characterIsMember:':']);
}

/*! @abstract The separator set is cached, so repeated access returns the same instance. */
- (void)testSeparatorSetIsBuiltOnce
{
	XCTAssertTrue(FxGripPluginInfo.separatorSet == FxGripPluginInfo.separatorSet);
}

#pragma mark - localizeObject:

/*! @abstract localizeObject: returns nil for a nil argument. */
- (void)testLocalizeObjectOfNilIsNil
{
	XCTAssertNil([FxGripPluginInfo localizeObject:nil]);
}

/*! @abstract localizeObject: returns a string unchanged when no translation exists for it. */
- (void)testLocalizeObjectOfAStringWithoutATranslationIsThatString
{
	NSString *source = @"FxGripPluginInfoTests.untranslated.key";

	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:source], source);
}

/*! @abstract localizeObject: returns a number or date argument as the same object. */
- (void)testLocalizeObjectPassesAnUnsupportedTypeThrough
{
	NSNumber *number = @42;
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:0];

	XCTAssertTrue([FxGripPluginInfo localizeObject:number] == number);
	XCTAssertTrue([FxGripPluginInfo localizeObject:date] == date);
}

/*! @abstract localizeObject: returns the same mutable array instance with its element count and non-string elements intact. */
- (void)testLocalizeObjectRewritesAMutableArrayInPlace
{
	NSMutableArray *source = [NSMutableArray arrayWithArray:@[ @"one", @2, @"three" ]];

	id result = [FxGripPluginInfo localizeObject:source];

	XCTAssertTrue(result == source);
	XCTAssertEqual([result count], (NSUInteger)3);
	XCTAssertEqualObjects(result[1], @2);
}

/*! @abstract localizeObject: returns the same mutable dictionary instance with its entry count and non-string values intact. */
- (void)testLocalizeObjectRewritesAMutableDictionaryInPlace
{
	NSMutableDictionary *source = [NSMutableDictionary dictionaryWithDictionary:@{ @"a": @"one", @"b": @2 }];

	id result = [FxGripPluginInfo localizeObject:source];

	XCTAssertTrue(result == source);
	XCTAssertEqual([result count], (NSUInteger)2);
	XCTAssertEqualObjects(result[@"b"], @2);
}

/*! @abstract localizeObject: preserves the contents of an immutable array. */
- (void)testLocalizeObjectPreservesAnImmutableArraysContent
{
	NSArray *source = @[ @"one", @2 ];

	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:source], source);
}

/*! @abstract localizeObject: preserves the contents of an immutable dictionary. */
- (void)testLocalizeObjectPreservesAnImmutableDictionarysContent
{
	NSDictionary *source = @{ @"a": @"one", @"b": @2 };

	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:source], source);
}

/*! @abstract localizeObject: recurses through nested arrays and dictionaries and preserves their untranslated contents. */
- (void)testLocalizeObjectDescendsIntoNestedContainers
{
	NSDictionary *source = @{
		@"list": @[ @"one", @{ @"inner": @"two" } ],
		@"map": @{ @"deep": @[ @3 ] }
	};

	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:source], source);
}

/*! @abstract localizeObject: returns an empty array or empty dictionary for an empty container. */
- (void)testLocalizeObjectOfEmptyContainersProducesEmptyContainers
{
	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:@[]], @[]);
	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:@{}], @{});
}

#pragma mark - Info.plist Properties

/*! @abstract propertyForKey: returns nil for a key the main bundle Info.plist does not declare. */
- (void)testPropertyForKeyIsNilForAKeyTheMainBundleDoesNotDeclare
{
	XCTAssertNil([FxGripPluginInfo propertyForKey:@"FxGripPluginInfoTestsAbsentKey"]);
}

/*! @abstract propertyForKey: returns the value the main bundle Info dictionary holds for a declared key. */
- (void)testPropertyForKeyMatchesTheMainBundleInfoDictionary
{
	NSString *key = @"CFBundleIdentifier";

	XCTAssertEqualObjects([FxGripPluginInfo propertyForKey:key], [NSBundle.mainBundle objectForInfoDictionaryKey:key]);
}

/*! @abstract The copyright property reads the NSHumanReadableCopyright Info.plist key. */
- (void)testCopyrightReadsTheHumanReadableCopyrightKey
{
	XCTAssertEqualObjects(FxGripPluginInfo.copyright, [FxGripPluginInfo propertyForKey:@"NSHumanReadableCopyright"]);
}

/*! @abstract isDynamicRegistration is NO when the dynamic-registration Info.plist key is absent. */
- (void)testIsDynamicRegistrationIsNoWhenTheKeyIsAbsent
{
	XCTAssertNil([FxGripPluginInfo propertyForKey:kProPlugDynamicRegistration_Property]);
	XCTAssertFalse(FxGripPluginInfo.isDynamicRegistration);
}

/*! @abstract dynamicRegistrationPrincipalClass is nil when the dynamic-registration key is absent. */
- (void)testDynamicRegistrationPrincipalClassIsNilWhenTheKeyIsAbsent
{
	XCTAssertNil(FxGripPluginInfo.dynamicRegistrationPrincipalClass);
}

/*! @abstract The plugIns property is nil when the static plugin list Info.plist key is absent. */
- (void)testPlugInsIsNilWhenTheStaticListIsAbsent
{
	XCTAssertNil([FxGripPluginInfo propertyForKey:kProPlugPlugInList_Property]);
	XCTAssertNil(FxGripPluginInfo.plugIns);
}

/*! @abstract The plugInGroups property is nil when the static group list Info.plist key is absent. */
- (void)testPlugInGroupsIsNilWhenTheStaticListIsAbsent
{
	XCTAssertNil([FxGripPluginInfo propertyForKey:kProPlugPlugIn_GroupList_Property]);
	XCTAssertNil(FxGripPluginInfo.plugInGroups);
}

#pragma mark - Plugin Lookups

/*! @abstract pluginPropertiesByUUID: returns an empty non-nil dictionary when no plugins are registered. */
- (void)testPluginPropertiesByUUIDIsAnEmptyDictionaryWhenNoPluginsAreRegistered
{
	NSDictionary *properties = [FxGripPluginInfo pluginPropertiesByUUID:@"AAAABBBB-CCCC-DDDD-EEEE-FFFF00001111"];

	XCTAssertNotNil(properties);
	XCTAssertEqual(properties.count, (NSUInteger)0);
}

/*! @abstract pluginPropertiesByUUID: returns a non-nil dictionary for an empty or malformed UUID string. */
- (void)testPluginPropertiesByUUIDNeverReturnsNil
{
	XCTAssertNotNil([FxGripPluginInfo pluginPropertiesByUUID:@""]);
	XCTAssertNotNil([FxGripPluginInfo pluginPropertiesByUUID:@"not-a-uuid"]);
}

/*! @abstract pluginPropertiesByClassName: returns an empty non-nil dictionary when no plugins are registered. */
- (void)testPluginPropertiesByClassNameIsAnEmptyDictionaryWhenNoPluginsAreRegistered
{
	NSDictionary *properties = [FxGripPluginInfo pluginPropertiesByClassName:@"FxGripTestPlugin"];

	XCTAssertNotNil(properties);
	XCTAssertEqual(properties.count, (NSUInteger)0);
}

/*! @abstract pluginPropertiesByClassName: matches a staged plugin entry by class name without regard to case. */
- (void)testPluginPropertiesByClassNameMatchesAStagedEntryWithoutRegardToCase
{
	XCTAssertEqualObjects([FxGripPluginInfoTestStub pluginPropertiesByClassName:@"FxGripMixedCasePlugin"][@"marker"],
						  @"mixed");
	XCTAssertEqualObjects([FxGripPluginInfoTestStub pluginPropertiesByClassName:@"FXGRIPMIXEDCASEPLUGIN"][@"marker"],
						  @"mixed");
	XCTAssertEqualObjects([FxGripPluginInfoTestStub pluginPropertiesByClassName:@"FxGripLowercasePlugin"][@"marker"],
						  @"lower");
}

/*! @abstract pluginPropertiesByClassName: skips a staged entry whose class-name value is not a string. */
- (void)testPluginPropertiesByClassNameSkipsAnEntryWhoseClassNameIsNotAString
{
	NSDictionary *properties = [FxGripPluginInfoTestStub pluginPropertiesByClassName:@"42"];

	XCTAssertEqual(properties.count, (NSUInteger)0);
}

/*! @abstract pluginPropertiesByUUID: matches a staged plugin entry by UUID without regard to case. */
- (void)testPluginPropertiesByUUIDMatchesAStagedEntryWithoutRegardToCase
{
	XCTAssertEqualObjects([FxGripPluginInfoTestStub pluginPropertiesByUUID:@"aaaabbbb-cccc-dddd-eeee-ffff00001111"][@"marker"],
						  @"mixed");
}

#pragma mark - Shared Instance

/*! @abstract The sharedInstance is non-nil and returns the same object on repeated access. */
- (void)testSharedInstanceIsStable
{
	id first = FxGripPluginInfo.sharedInstance;

	XCTAssertNotNil(first);
	XCTAssertTrue(first == FxGripPluginInfo.sharedInstance);
}

/*! @abstract The sharedInstance is a kind of FxGripPluginInfo. */
- (void)testSharedInstanceIsAnFxGripPluginInfo
{
	XCTAssertTrue([FxGripPluginInfo.sharedInstance isKindOfClass:FxGripPluginInfo.class]);
}

/*! @abstract didEstablishConnectionWithHost:version: records the host bundle identifier and version on the instance. */
- (void)testDidEstablishConnectionRecordsTheHostIdentityOnTheInstance
{
	FxGripPluginInfo *info = FxGripPluginInfo.sharedInstance;

	[info didEstablishConnectionWithHost:@"com.apple.motionapp" version:@"5.7"];

	XCTAssertEqualObjects(info.hostBundleIdentifier, @"com.apple.motionapp");
	XCTAssertEqualObjects(info.hostVersion, @"5.7");
}

#pragma mark - FxMatrix44 (FxGrip)

/*!
	FxPlug.framework is weak-linked and is not present outside an FxPlug host, so
	FxMatrix44 resolves to Nil and neither category method has a receiver. The
	category is reachable only inside a host process.
*/
- (void)testFxMatrix44CategoryRequiresFxPlugToBeLoaded
{
	Class matrixClass = NSClassFromString(@"FxMatrix44");

	if (matrixClass == Nil) {
		XCTSkip(@"FxPlug is not loaded, so FxMatrix44 has no receiver and the category cannot run.");
	}

	simd_float4x4 destination;
	memset(&destination, 0, sizeof(destination));
	Matrix44Data source = {
		{  1.0,  2.0,  3.0,  4.0 },
		{  5.0,  6.0,  7.0,  8.0 },
		{  9.0, 10.0, 11.0, 12.0 },
		{ 13.0, 14.0, 15.0, 16.0 }
	};

	[matrixClass doubleMatrix:&source toFloat4x4Matrix:&destination];

	for (int row = 0; row < 4; row++) {
		for (int column = 0; column < 4; column++) {
			XCTAssertEqual(destination.columns[row][column], (float)source[column][row]);
		}
	}
}

#pragma mark - FxGripTypes.h Inline Conversions

/*! @abstract CGRectFromFxRect maps the FxRect edges to a CGRect origin and size. */
- (void)testCGRectFromFxRectMapsTheEdgesToAnOriginAndSize
{
	FxRect source = { -10, -20, 30, 40 };

	CGRect rect = CGRectFromFxRect(source);

	XCTAssertEqual(rect.origin.x, -10.0);
	XCTAssertEqual(rect.origin.y, -20.0);
	XCTAssertEqual(rect.size.width, 40.0);
	XCTAssertEqual(rect.size.height, 60.0);
}

/*! @abstract CGRectFromFxRect produces a zero-size rect for an empty FxRect. */
- (void)testCGRectFromAnEmptyFxRectIsEmpty
{
	CGRect rect = CGRectFromFxRect((FxRect){ 0, 0, 0, 0 });

	XCTAssertEqual(rect.size.width, 0.0);
	XCTAssertEqual(rect.size.height, 0.0);
}

/*! @abstract FxRectFromCGRect maps the CGRect origin and size to FxRect edges. */
- (void)testFxRectFromCGRectMapsTheOriginAndSizeToEdges
{
	CGRect source = CGRectMake(5.0, 7.0, 20.0, 30.0);

	FxRect rect = FxRectFromCGRect(source);

	XCTAssertEqual(rect.left, 5);
	XCTAssertEqual(rect.bottom, 7);
	XCTAssertEqual(rect.right, 25);
	XCTAssertEqual(rect.top, 37);
}

/*! @abstract Converting an FxRect to a CGRect and back reproduces the original edges. */
- (void)testFxRectAndCGRectConversionsRoundTrip
{
	FxRect source = { -3, -4, 11, 12 };

	FxRect result = FxRectFromCGRect(CGRectFromFxRect(source));

	XCTAssertEqual(result.left, source.left);
	XCTAssertEqual(result.bottom, source.bottom);
	XCTAssertEqual(result.right, source.right);
	XCTAssertEqual(result.top, source.top);
}

/*! @abstract FxRectFromCGRect truncates fractional coordinates toward zero. */
- (void)testFxRectFromCGRectTruncatesFractionalCoordinates
{
	FxRect rect = FxRectFromCGRect(CGRectMake(1.9, 2.9, 3.9, 4.9));

	XCTAssertEqual(rect.left, 1);
	XCTAssertEqual(rect.bottom, 2);
	XCTAssertEqual(rect.right, 5);
	XCTAssertEqual(rect.top, 7);
}


#pragma mark - Host identity

/*! @abstract FxGripHostBundleIdentifierIsMotion recognizes the Motion application bundle identifiers. */
- (void)testMotionBundleIdentifiersAreRecognized
{
	XCTAssertTrue(FxGripHostBundleIdentifierIsMotion(@"com.apple.motionapp"));
	XCTAssertTrue(FxGripHostBundleIdentifierIsMotion(@"com.apple.motionappApp"));
}

/*! @abstract FxGripHostBundleIdentifierIsMotion is false for Final Cut, a Motion helper identifier, and nil. */
- (void)testOtherHostsAndNoHostAreNotMotion
{
	XCTAssertFalse(FxGripHostBundleIdentifierIsMotion(@"com.apple.FinalCut"));
	XCTAssertFalse(FxGripHostBundleIdentifierIsMotion(@"com.apple.motionapp.helper"));
	XCTAssertFalse(FxGripHostBundleIdentifierIsMotion(nil));
}

/*! @abstract hostIsMotion is false before a connection and becomes true after connecting to a Motion host. */
- (void)testHostIsMotionFollowsTheEstablishedConnection
{
	FxGripPluginInfo *info = [FxGripPluginInfo.alloc init];
	XCTAssertFalse(info.hostIsMotion);

	[info didEstablishConnectionWithHost:@"com.apple.motionapp" version:@"5.9"];

	XCTAssertTrue(info.hostIsMotion);
	XCTAssertEqualObjects(info.hostBundleIdentifier, @"com.apple.motionapp");
}

@end
