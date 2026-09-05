//
//  FxGripPluginInfoTests.m
//  FxGripTests
//
//  Unit tests for FxGripPluginInfo: the separator character set, the Info.plist
//  property readers, the recursive localization pass, and the plugin lookups that
//  run over the registered plugin list. Also covers the FxMatrix44 (FxGrip)
//  category and the FxGripTypes.h inline rect conversions.
//

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

- (void)testSeparatorSetIsBuiltOnce
{
	XCTAssertTrue(FxGripPluginInfo.separatorSet == FxGripPluginInfo.separatorSet);
}

#pragma mark - localizeObject:

- (void)testLocalizeObjectOfNilIsNil
{
	XCTAssertNil([FxGripPluginInfo localizeObject:nil]);
}

- (void)testLocalizeObjectOfAStringWithoutATranslationIsThatString
{
	NSString *source = @"FxGripPluginInfoTests.untranslated.key";

	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:source], source);
}

- (void)testLocalizeObjectPassesAnUnsupportedTypeThrough
{
	NSNumber *number = @42;
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:0];

	XCTAssertTrue([FxGripPluginInfo localizeObject:number] == number);
	XCTAssertTrue([FxGripPluginInfo localizeObject:date] == date);
}

- (void)testLocalizeObjectRewritesAMutableArrayInPlace
{
	NSMutableArray *source = [NSMutableArray arrayWithArray:@[ @"one", @2, @"three" ]];

	id result = [FxGripPluginInfo localizeObject:source];

	XCTAssertTrue(result == source);
	XCTAssertEqual([result count], (NSUInteger)3);
	XCTAssertEqualObjects(result[1], @2);
}

- (void)testLocalizeObjectRewritesAMutableDictionaryInPlace
{
	NSMutableDictionary *source = [NSMutableDictionary dictionaryWithDictionary:@{ @"a": @"one", @"b": @2 }];

	id result = [FxGripPluginInfo localizeObject:source];

	XCTAssertTrue(result == source);
	XCTAssertEqual([result count], (NSUInteger)2);
	XCTAssertEqualObjects(result[@"b"], @2);
}

- (void)testLocalizeObjectPreservesAnImmutableArraysContent
{
	NSArray *source = @[ @"one", @2 ];

	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:source], source);
}

- (void)testLocalizeObjectPreservesAnImmutableDictionarysContent
{
	NSDictionary *source = @{ @"a": @"one", @"b": @2 };

	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:source], source);
}

- (void)testLocalizeObjectDescendsIntoNestedContainers
{
	NSDictionary *source = @{
		@"list": @[ @"one", @{ @"inner": @"two" } ],
		@"map": @{ @"deep": @[ @3 ] }
	};

	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:source], source);
}

- (void)testLocalizeObjectOfEmptyContainersProducesEmptyContainers
{
	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:@[]], @[]);
	XCTAssertEqualObjects([FxGripPluginInfo localizeObject:@{}], @{});
}

#pragma mark - Info.plist Properties

- (void)testPropertyForKeyIsNilForAKeyTheMainBundleDoesNotDeclare
{
	XCTAssertNil([FxGripPluginInfo propertyForKey:@"FxGripPluginInfoTestsAbsentKey"]);
}

- (void)testPropertyForKeyMatchesTheMainBundleInfoDictionary
{
	NSString *key = @"CFBundleIdentifier";

	XCTAssertEqualObjects([FxGripPluginInfo propertyForKey:key], [NSBundle.mainBundle objectForInfoDictionaryKey:key]);
}

- (void)testCopyrightReadsTheHumanReadableCopyrightKey
{
	XCTAssertEqualObjects(FxGripPluginInfo.copyright, [FxGripPluginInfo propertyForKey:@"NSHumanReadableCopyright"]);
}

- (void)testIsDynamicRegistrationIsNoWhenTheKeyIsAbsent
{
	XCTAssertNil([FxGripPluginInfo propertyForKey:kProPlugDynamicRegistration_Property]);
	XCTAssertFalse(FxGripPluginInfo.isDynamicRegistration);
}

- (void)testDynamicRegistrationPrincipalClassIsNilWhenTheKeyIsAbsent
{
	XCTAssertNil(FxGripPluginInfo.dynamicRegistrationPrincipalClass);
}

- (void)testPlugInsIsNilWhenTheStaticListIsAbsent
{
	XCTAssertNil([FxGripPluginInfo propertyForKey:kProPlugPlugInList_Property]);
	XCTAssertNil(FxGripPluginInfo.plugIns);
}

- (void)testPlugInGroupsIsNilWhenTheStaticListIsAbsent
{
	XCTAssertNil([FxGripPluginInfo propertyForKey:kProPlugPlugIn_GroupList_Property]);
	XCTAssertNil(FxGripPluginInfo.plugInGroups);
}

#pragma mark - Plugin Lookups

- (void)testPluginPropertiesByUUIDIsAnEmptyDictionaryWhenNoPluginsAreRegistered
{
	NSDictionary *properties = [FxGripPluginInfo pluginPropertiesByUUID:@"AAAABBBB-CCCC-DDDD-EEEE-FFFF00001111"];

	XCTAssertNotNil(properties);
	XCTAssertEqual(properties.count, (NSUInteger)0);
}

- (void)testPluginPropertiesByUUIDNeverReturnsNil
{
	XCTAssertNotNil([FxGripPluginInfo pluginPropertiesByUUID:@""]);
	XCTAssertNotNil([FxGripPluginInfo pluginPropertiesByUUID:@"not-a-uuid"]);
}

- (void)testPluginPropertiesByClassNameIsAnEmptyDictionaryWhenNoPluginsAreRegistered
{
	NSDictionary *properties = [FxGripPluginInfo pluginPropertiesByClassName:@"FxGripTestPlugin"];

	XCTAssertNotNil(properties);
	XCTAssertEqual(properties.count, (NSUInteger)0);
}

- (void)testPluginPropertiesByClassNameMatchesAStagedEntryWithoutRegardToCase
{
	XCTAssertEqualObjects([FxGripPluginInfoTestStub pluginPropertiesByClassName:@"FxGripMixedCasePlugin"][@"marker"],
						  @"mixed");
	XCTAssertEqualObjects([FxGripPluginInfoTestStub pluginPropertiesByClassName:@"FXGRIPMIXEDCASEPLUGIN"][@"marker"],
						  @"mixed");
	XCTAssertEqualObjects([FxGripPluginInfoTestStub pluginPropertiesByClassName:@"FxGripLowercasePlugin"][@"marker"],
						  @"lower");
}

- (void)testPluginPropertiesByClassNameSkipsAnEntryWhoseClassNameIsNotAString
{
	NSDictionary *properties = [FxGripPluginInfoTestStub pluginPropertiesByClassName:@"42"];

	XCTAssertEqual(properties.count, (NSUInteger)0);
}

- (void)testPluginPropertiesByUUIDMatchesAStagedEntryWithoutRegardToCase
{
	XCTAssertEqualObjects([FxGripPluginInfoTestStub pluginPropertiesByUUID:@"aaaabbbb-cccc-dddd-eeee-ffff00001111"][@"marker"],
						  @"mixed");
}

#pragma mark - Shared Instance

- (void)testSharedInstanceIsStable
{
	id first = FxGripPluginInfo.sharedInstance;

	XCTAssertNotNil(first);
	XCTAssertTrue(first == FxGripPluginInfo.sharedInstance);
}

- (void)testSharedInstanceIsAnFxGripPluginInfo
{
	XCTAssertTrue([FxGripPluginInfo.sharedInstance isKindOfClass:FxGripPluginInfo.class]);
}

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

- (void)testCGRectFromFxRectMapsTheEdgesToAnOriginAndSize
{
	FxRect source = { -10, -20, 30, 40 };

	CGRect rect = CGRectFromFxRect(source);

	XCTAssertEqual(rect.origin.x, -10.0);
	XCTAssertEqual(rect.origin.y, -20.0);
	XCTAssertEqual(rect.size.width, 40.0);
	XCTAssertEqual(rect.size.height, 60.0);
}

- (void)testCGRectFromAnEmptyFxRectIsEmpty
{
	CGRect rect = CGRectFromFxRect((FxRect){ 0, 0, 0, 0 });

	XCTAssertEqual(rect.size.width, 0.0);
	XCTAssertEqual(rect.size.height, 0.0);
}

- (void)testFxRectFromCGRectMapsTheOriginAndSizeToEdges
{
	CGRect source = CGRectMake(5.0, 7.0, 20.0, 30.0);

	FxRect rect = FxRectFromCGRect(source);

	XCTAssertEqual(rect.left, 5);
	XCTAssertEqual(rect.bottom, 7);
	XCTAssertEqual(rect.right, 25);
	XCTAssertEqual(rect.top, 37);
}

- (void)testFxRectAndCGRectConversionsRoundTrip
{
	FxRect source = { -3, -4, 11, 12 };

	FxRect result = FxRectFromCGRect(CGRectFromFxRect(source));

	XCTAssertEqual(result.left, source.left);
	XCTAssertEqual(result.bottom, source.bottom);
	XCTAssertEqual(result.right, source.right);
	XCTAssertEqual(result.top, source.top);
}

- (void)testFxRectFromCGRectTruncatesFractionalCoordinates
{
	FxRect rect = FxRectFromCGRect(CGRectMake(1.9, 2.9, 3.9, 4.9));

	XCTAssertEqual(rect.left, 1);
	XCTAssertEqual(rect.bottom, 2);
	XCTAssertEqual(rect.right, 5);
	XCTAssertEqual(rect.top, 7);
}


#pragma mark - Host identity

- (void)testMotionBundleIdentifiersAreRecognized
{
	XCTAssertTrue(FxGripHostBundleIdentifierIsMotion(@"com.apple.motionapp"));
	XCTAssertTrue(FxGripHostBundleIdentifierIsMotion(@"com.apple.motionappApp"));
}

- (void)testOtherHostsAndNoHostAreNotMotion
{
	XCTAssertFalse(FxGripHostBundleIdentifierIsMotion(@"com.apple.FinalCut"));
	XCTAssertFalse(FxGripHostBundleIdentifierIsMotion(@"com.apple.motionapp.helper"));
	XCTAssertFalse(FxGripHostBundleIdentifierIsMotion(nil));
}

- (void)testHostIsMotionFollowsTheEstablishedConnection
{
	FxGripPluginInfo *info = [FxGripPluginInfo.alloc init];
	XCTAssertFalse(info.hostIsMotion);

	[info didEstablishConnectionWithHost:@"com.apple.motionapp" version:@"5.9"];

	XCTAssertTrue(info.hostIsMotion);
	XCTAssertEqualObjects(info.hostBundleIdentifier, @"com.apple.motionapp");
}

@end
