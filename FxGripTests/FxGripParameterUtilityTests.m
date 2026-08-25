//
//  FxGripParameterUtilityTests.m
//  FxGripTests
//
//  Unit tests for the creation-time target-preset defaults: the Menu and Toggle
//  drivers that select a preset entry from their declared default, and the
//  `names`, `flags`, `tags`, and `values` sections that rewrite the target
//  configurations in place.
//

#import <XCTest/XCTest.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/FxGripParameterUtility.h"


static NSMutableDictionary *FxTPConfig(int parameterID, id type)
{
	return [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(parameterID),
		kFxParameterProperty_Type: type,
		kFxParameterProperty_Name: @"declared"
	}];
}

static NSMutableDictionary *FxTPDriver(int parameterID, id type, id defaultValue, id definition)
{
	NSMutableDictionary *config = FxTPConfig(parameterID, type);
	config[kFxParameterProperty_Default] = defaultValue;
	config[kFxParameterProperty_TargetPreset] = definition;
	return config;
}

static NSMutableArray<NSMutableDictionary*> *FxTPList(NSArray<NSMutableDictionary*> *configs)
{
	return [NSMutableArray arrayWithArray:configs];
}

// A preset whose `names` section renames parameter 2, used as the visible effect of a
// driver that resolves.
static NSDictionary *FxTPRenamePreset(NSString *name)
{
	return @{ kFxParameterProperty_TargetPresetNames: @{ @2: name } };
}


@interface FxGripParameterUtilityTests : XCTestCase
@end

@implementation FxGripParameterUtilityTests

#pragma mark - Driver Selection

- (void)testMenuDefaultIndexSelectsTheMatchingPresetEntry
{
	NSArray *definition = @[FxTPRenamePreset(@"first"), FxTPRenamePreset(@"second")];
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @1, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"second");
}

- (void)testToggleDefaultNoSelectsTheFirstPresetEntry
{
	NSArray *definition = @[FxTPRenamePreset(@"off"), FxTPRenamePreset(@"on")];
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Toggle), @NO, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"off");
}

- (void)testToggleDefaultYesSelectsTheSecondPresetEntry
{
	NSArray *definition = @[FxTPRenamePreset(@"off"), FxTPRenamePreset(@"on")];
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Toggle), @YES, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"on");
}

- (void)testTypeGivenAsANameStringDrivesTheSameApplication
{
	NSArray *definition = @[FxTPRenamePreset(@"first")];
	NSMutableDictionary *target = FxTPConfig(2, kFxParameterType_Float);
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, kFxParameterType_Menu, @0, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"first");
}

- (void)testInlineArrayDefinitionResolvesWithoutAPresetTable
{
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[FxTPRenamePreset(@"inline")]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"inline");
}

- (void)testInlineDictionaryDefinitionResolvesByNumberKey
{
	NSDictionary *definition = @{ @1: FxTPRenamePreset(@"numbered") };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @1, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"numbered");
}

- (void)testInlineDictionaryDefinitionResolvesByStringKey
{
	NSDictionary *definition = @{ @"1": FxTPRenamePreset(@"stringKeyed") };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @1, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"stringKeyed");
}

- (void)testDictionaryDefinitionHasNoDefaultKeyFallback
{
	NSDictionary *definition = @{ kFxParameterProperty_Default: FxTPRenamePreset(@"fallback") };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @1, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}

- (void)testArrayIndexOutOfRangeAppliesNothing
{
	NSArray *definition = @[FxTPRenamePreset(@"first"), FxTPRenamePreset(@"second")];
	NSMutableDictionary *high = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableDictionary *low = FxTPConfig(2, @(FxParameterType_Float));

	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @7, definition), high
	]) pluginPresets:nil]);
	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @(-1), definition), low
	]) pluginPresets:nil]);

	XCTAssertEqualObjects(high[kFxParameterProperty_Name], @"declared");
	XCTAssertEqualObjects(low[kFxParameterProperty_Name], @"declared");
}

- (void)testStringDefinitionResolvesThroughThePluginPresets
{
	NSDictionary *pluginPresets = @{ @"styles": @[FxTPRenamePreset(@"fromTable")] };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @"styles"),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:pluginPresets];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"fromTable");
}

- (void)testUnresolvableStringDefinitionAppliesNothing
{
	NSDictionary *pluginPresets = @{ @"styles": @[FxTPRenamePreset(@"fromTable")] };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @"missing"),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:pluginPresets];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}

- (void)testDriverThatIsNeitherMenuNorToggleIsIgnored
{
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Int), @0, @[FxTPRenamePreset(@"ignored")]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}

- (void)testSelectedEntryThatIsNotADictionaryAppliesNothing
{
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[@"not a preset"]),
		target
	]);

	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil]);
	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}


#pragma mark - Names Section

- (void)testNamesSectionRewritesTheTargetName
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetNames: @{ @2: @"Renamed" } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"Renamed");
}

- (void)testNamesSectionIgnoresANonStringEntry
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetNames: @{ @2: @17 } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}


#pragma mark - Flags Section

- (void)testFlagsSectionAddsBareAndPlusPrefixedNames
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @[@"hidden", @"+disabled"] } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = [NSMutableArray arrayWithObject:@"dontsave"];
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"dontsave", @"hidden", @"disabled"]));
}

- (void)testFlagsSectionRemovesMinusPrefixedNames
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @[@"-hidden"] } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = @[@"hidden", @"disabled"];
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"disabled"]));
}

- (void)testFlagsSectionDoesNotDuplicateAnExistingName
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @[@"hidden"] } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = @[@"hidden"];
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"hidden"]));
}

- (void)testFlagsSectionCreatesTheArrayWhenTheTargetHasNone
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @[@"hidden"] } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"hidden"]));
}

- (void)testFlagsSectionAcceptsADividerSeparatedStringSpec
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @"hidden, +disabled -dontsave" } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = @[@"dontsave"];
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"hidden", @"disabled"]));
}

- (void)testFlagsSectionConvertsAnExistingStringValueToAnArray
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @[@"disabled"] } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = @"hidden dontsave";
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"hidden", @"dontsave", @"disabled"]));
}


#pragma mark - Tags Section

- (void)testTagsSectionAddsAndRemovesNames
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetTags: @{ @2: @[@"outline", @"-legacy"] } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Tags] = @[@"legacy", @"style"];
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Tags], (@[@"style", @"outline"]));
}

- (void)testTagsSectionDoesNotDuplicateAnExistingName
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetTags: @{ @2: @[@"style"] } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Tags] = @[@"style"];
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Tags], (@[@"style"]));
}

- (void)testTagsSectionCreatesTheArrayWhenTheTargetHasNone
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetTags: @{ @2: @[@"style"] } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Tags], (@[@"style"]));
}

- (void)testTagsSectionAcceptsADividerSeparatedStringSpec
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetTags: @{ @2: @"style; -legacy" } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Tags] = @[@"legacy"];
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Tags], (@[@"style"]));
}


#pragma mark - Values Section

- (void)testValuesSectionWritesTheRGBChannels
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{
		@2: @{ kFxParameterProperty_Red: @0.25, kFxParameterProperty_Green: @0.5, kFxParameterProperty_Blue: @0.75 }
	} };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_RGB));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Red], @0.25);
	XCTAssertEqualObjects(target[kFxParameterProperty_Green], @0.5);
	XCTAssertEqualObjects(target[kFxParameterProperty_Blue], @0.75);
	XCTAssertNil(target[kFxParameterProperty_Default]);
}

- (void)testValuesSectionWritesRGBAAlphaAndFallsThroughToTheChannels
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{
		@2: @{ kFxParameterProperty_Red: @1.0, kFxParameterProperty_Green: @0.0,
			   kFxParameterProperty_Blue: @0.0, kFxParameterProperty_Alpha: @0.5 }
	} };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_RGBA));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Alpha], @0.5);
	XCTAssertEqualObjects(target[kFxParameterProperty_Red], @1.0);
	XCTAssertEqualObjects(target[kFxParameterProperty_Green], @0.0);
	XCTAssertEqualObjects(target[kFxParameterProperty_Blue], @0.0);
}

- (void)testValuesSectionLeavesRGBAAlphaWhenThePresetOmitsIt
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{
		@2: @{ kFxParameterProperty_Red: @1.0 }
	} };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_RGBA));
	target[kFxParameterProperty_Alpha] = @0.25;
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Alpha], @0.25);
	XCTAssertEqualObjects(target[kFxParameterProperty_Red], @1.0);
}

- (void)testValuesSectionWritesThePointAxes
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{
		@2: @{ kFxParameterProperty_X: @12, kFxParameterProperty_Y: @34 }
	} };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Point));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_X], @12);
	XCTAssertEqualObjects(target[kFxParameterProperty_Y], @34);
}

- (void)testValuesSectionMergesCustomDefaultsWithThePresetWinning
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{
		@2: @{ @"shared": @"preset", @"nested": @{ @"inner": @"preset" } }
	} };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Custom));
	target[kFxParameterProperty_Default] = @{
		@"shared": @"declared",
		@"kept": @"declared",
		@"nested": @{ @"inner": @"declared", @"innerKept": @"declared" }
	};
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	NSDictionary *merged = target[kFxParameterProperty_Default];
	XCTAssertEqualObjects(merged[@"shared"], @"preset");
	XCTAssertEqualObjects(merged[@"kept"], @"declared");
	XCTAssertEqualObjects(merged[@"nested"][@"inner"], @"preset");
	XCTAssertEqualObjects(merged[@"nested"][@"innerKept"], @"declared");
}

- (void)testValuesSectionSetsTheCustomDefaultWhenTheTargetHasNone
{
	NSDictionary *value = @{ @"shape": @"circle" };
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{ @2: value } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Custom));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Default], value);
}

- (void)testValuesSectionSetsTheDefaultForEveryOtherType
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{ @2: @42.5 } };
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Default] = @1.0;
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Default], @42.5);
}


#pragma mark - Section Keys and Missing Targets

- (void)testSectionKeysResolveAsStringsAndAsNumbers
{
	NSDictionary *preset = @{
		kFxParameterProperty_TargetPresetNames: @{ @"2": @"byString" },
		kFxParameterProperty_TargetPresetValues: @{ @3: @9 }
	};
	NSMutableDictionary *named = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableDictionary *valued = FxTPConfig(3, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		named,
		valued
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(named[kFxParameterProperty_Name], @"byString");
	XCTAssertEqualObjects(valued[kFxParameterProperty_Default], @9);
}

- (void)testSectionEntryForAnUnknownParameterIsSkippedWhileSiblingsApply
{
	NSDictionary *preset = @{
		kFxParameterProperty_TargetPresetNames: @{ @2: @"Renamed", @99: @"Nowhere" },
		kFxParameterProperty_TargetPresetValues: @{ @2: @5, @99: @6 }
	};
	NSMutableDictionary *target = FxTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxTPList(@[
		FxTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil]);

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"Renamed");
	XCTAssertEqualObjects(target[kFxParameterProperty_Default], @5);
}


#pragma mark - Degenerate Input

- (void)testEmptyParameterListIsANoOp
{
	NSMutableArray *parameters = NSMutableArray.new;

	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil]);
	XCTAssertEqual(parameters.count, 0u);
}

- (void)testNilParameterListIsANoOp
{
	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:nil pluginPresets:nil]);
}

@end
