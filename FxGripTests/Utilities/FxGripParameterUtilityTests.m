/*!
	@file       FxGripParameterUtilityTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterUtilityTests
	@abstract   Tests the target-preset defaults that FxGripParameterUtility applies to a parameter list at creation time.
	@discussion Introduced in FxGrip 0.1.0. A Menu or Toggle driver selects one entry from a preset definition using its declared default. The selected entry's names, flags, tags, and values sections rewrite the sibling target configurations in place. These tests cover driver selection, definition resolution through inline data and the plugin preset table, each section's edits, and degenerate input.
*/

#import <XCTest/XCTest.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/FxGripParameterUtility.h"


static NSMutableDictionary *FxGripTPConfig(int parameterID, id type)
{
	return [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(parameterID),
		kFxParameterProperty_Type: type,
		kFxParameterProperty_Name: @"declared"
	}];
}

static NSMutableDictionary *FxGripTPDriver(int parameterID, id type, id defaultValue, id definition)
{
	NSMutableDictionary *config = FxGripTPConfig(parameterID, type);
	config[kFxParameterProperty_Default] = defaultValue;
	config[kFxParameterProperty_TargetPreset] = definition;
	return config;
}

static NSMutableArray<NSMutableDictionary*> *FxGripTPList(NSArray<NSMutableDictionary*> *configs)
{
	return [NSMutableArray arrayWithArray:configs];
}

// A preset whose `names` section renames parameter 2, used as the visible effect of a
// driver that resolves.
static NSDictionary *FxGripTPRenamePreset(NSString *name)
{
	return @{ kFxParameterProperty_TargetPresetNames: @{ @2: name } };
}


@interface FxGripParameterUtilityTests : XCTestCase
@end

@implementation FxGripParameterUtilityTests

#pragma mark - Driver Selection

/*! @abstract A Menu default index selects the preset entry at that index and applies its rename to the target. */
- (void)testMenuDefaultIndexSelectsTheMatchingPresetEntry
{
	NSArray *definition = @[FxGripTPRenamePreset(@"first"), FxGripTPRenamePreset(@"second")];
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @1, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"second");
}

/*! @abstract A Toggle default of NO selects the first preset entry. */
- (void)testToggleDefaultNoSelectsTheFirstPresetEntry
{
	NSArray *definition = @[FxGripTPRenamePreset(@"off"), FxGripTPRenamePreset(@"on")];
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Toggle), @NO, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"off");
}

/*! @abstract A Toggle default of YES selects the second preset entry. */
- (void)testToggleDefaultYesSelectsTheSecondPresetEntry
{
	NSArray *definition = @[FxGripTPRenamePreset(@"off"), FxGripTPRenamePreset(@"on")];
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Toggle), @YES, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"on");
}

/*! @abstract A driver whose type is given as a name string resolves and applies the same as the numeric type. */
- (void)testTypeGivenAsANameStringDrivesTheSameApplication
{
	NSArray *definition = @[FxGripTPRenamePreset(@"first")];
	NSMutableDictionary *target = FxGripTPConfig(2, kFxParameterType_Float);
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, kFxParameterType_Menu, @0, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"first");
}

/*! @abstract An inline array definition resolves by index without a plugin preset table. */
- (void)testInlineArrayDefinitionResolvesWithoutAPresetTable
{
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[FxGripTPRenamePreset(@"inline")]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"inline");
}

/*! @abstract An inline dictionary definition resolves the selected entry by its number key. */
- (void)testInlineDictionaryDefinitionResolvesByNumberKey
{
	NSDictionary *definition = @{ @1: FxGripTPRenamePreset(@"numbered") };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @1, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"numbered");
}

/*! @abstract An inline dictionary definition resolves the selected entry by its string key. */
- (void)testInlineDictionaryDefinitionResolvesByStringKey
{
	NSDictionary *definition = @{ @"1": FxGripTPRenamePreset(@"stringKeyed") };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @1, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"stringKeyed");
}

/*! @abstract A dictionary definition that lacks the selected key applies nothing, even when it holds a default key. */
- (void)testDictionaryDefinitionHasNoDefaultKeyFallback
{
	NSDictionary *definition = @{ kFxParameterProperty_Default: FxGripTPRenamePreset(@"fallback") };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @1, definition),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}

/*! @abstract A selection index above or below the array bounds applies nothing and does not throw. */
- (void)testArrayIndexOutOfRangeAppliesNothing
{
	NSArray *definition = @[FxGripTPRenamePreset(@"first"), FxGripTPRenamePreset(@"second")];
	NSMutableDictionary *high = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableDictionary *low = FxGripTPConfig(2, @(FxParameterType_Float));

	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @7, definition), high
	]) pluginPresets:nil]);
	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @(-1), definition), low
	]) pluginPresets:nil]);

	XCTAssertEqualObjects(high[kFxParameterProperty_Name], @"declared");
	XCTAssertEqualObjects(low[kFxParameterProperty_Name], @"declared");
}

/*! @abstract A string definition names a plugin preset table entry, which resolves and applies. */
- (void)testStringDefinitionResolvesThroughThePluginPresets
{
	NSDictionary *pluginPresets = @{ @"styles": @[FxGripTPRenamePreset(@"fromTable")] };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @"styles"),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:pluginPresets];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"fromTable");
}

/*! @abstract A string definition with no matching plugin preset entry applies nothing. */
- (void)testUnresolvableStringDefinitionAppliesNothing
{
	NSDictionary *pluginPresets = @{ @"styles": @[FxGripTPRenamePreset(@"fromTable")] };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @"missing"),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:pluginPresets];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}

/*! @abstract A driver whose type is neither Menu nor Toggle applies nothing. */
- (void)testDriverThatIsNeitherMenuNorToggleIsIgnored
{
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Int), @0, @[FxGripTPRenamePreset(@"ignored")]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}

/*! @abstract A selected entry that is not a dictionary applies nothing and does not throw. */
- (void)testSelectedEntryThatIsNotADictionaryAppliesNothing
{
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[@"not a preset"]),
		target
	]);

	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil]);
	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}


#pragma mark - Names Section

/*! @abstract The names section rewrites the addressed target's name. */
- (void)testNamesSectionRewritesTheTargetName
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetNames: @{ @2: @"Renamed" } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"Renamed");
}

/*! @abstract The names section leaves the target name unchanged when the entry is not a string. */
- (void)testNamesSectionIgnoresANonStringEntry
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetNames: @{ @2: @17 } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}


#pragma mark - Flags Section

/*! @abstract The flags section adds both bare and plus-prefixed names to the existing flags. */
- (void)testFlagsSectionAddsBareAndPlusPrefixedNames
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @[@"hidden", @"+disabled"] } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = [NSMutableArray arrayWithObject:@"dontsave"];
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"dontsave", @"hidden", @"disabled"]));
}

/*! @abstract The flags section removes a minus-prefixed name from the existing flags. */
- (void)testFlagsSectionRemovesMinusPrefixedNames
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @[@"-hidden"] } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = @[@"hidden", @"disabled"];
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"disabled"]));
}

/*! @abstract The flags section does not add a name the target already carries. */
- (void)testFlagsSectionDoesNotDuplicateAnExistingName
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @[@"hidden"] } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = @[@"hidden"];
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"hidden"]));
}

/*! @abstract The flags section creates the flags array when the target declares none. */
- (void)testFlagsSectionCreatesTheArrayWhenTheTargetHasNone
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @[@"hidden"] } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"hidden"]));
}

/*! @abstract The flags section accepts a divider-separated string spec and applies each add and remove token. */
- (void)testFlagsSectionAcceptsADividerSeparatedStringSpec
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @"hidden, +disabled -dontsave" } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = @[@"dontsave"];
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"hidden", @"disabled"]));
}

/*! @abstract The flags section converts an existing string flags value into an array before adding the new names. */
- (void)testFlagsSectionConvertsAnExistingStringValueToAnArray
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @[@"disabled"] } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = @"hidden dontsave";
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], (@[@"hidden", @"dontsave", @"disabled"]));
}


#pragma mark - Tags Section

/*! @abstract The tags section adds a bare name and removes a minus-prefixed name from the existing tags. */
- (void)testTagsSectionAddsAndRemovesNames
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetTags: @{ @2: @[@"outline", @"-legacy"] } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Tags] = @[@"legacy", @"style"];
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Tags], (@[@"style", @"outline"]));
}

/*! @abstract The tags section does not add a tag the target already carries. */
- (void)testTagsSectionDoesNotDuplicateAnExistingName
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetTags: @{ @2: @[@"style"] } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Tags] = @[@"style"];
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Tags], (@[@"style"]));
}

/*! @abstract The tags section creates the tags array when the target declares none. */
- (void)testTagsSectionCreatesTheArrayWhenTheTargetHasNone
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetTags: @{ @2: @[@"style"] } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Tags], (@[@"style"]));
}

/*! @abstract The tags section accepts a divider-separated string spec and applies each add and remove token. */
- (void)testTagsSectionAcceptsADividerSeparatedStringSpec
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetTags: @{ @2: @"style; -legacy" } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Tags] = @[@"legacy"];
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Tags], (@[@"style"]));
}


#pragma mark - Values Section

/*! @abstract The values section writes the red, green, and blue channels of an RGB target and sets no default. */
- (void)testValuesSectionWritesTheRGBChannels
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{
		@2: @{ kFxParameterProperty_Red: @0.25, kFxParameterProperty_Green: @0.5, kFxParameterProperty_Blue: @0.75 }
	} };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_RGB));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Red], @0.25);
	XCTAssertEqualObjects(target[kFxParameterProperty_Green], @0.5);
	XCTAssertEqualObjects(target[kFxParameterProperty_Blue], @0.75);
	XCTAssertNil(target[kFxParameterProperty_Default]);
}

/*! @abstract The values section writes the alpha and all three color channels of an RGBA target. */
- (void)testValuesSectionWritesRGBAAlphaAndFallsThroughToTheChannels
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{
		@2: @{ kFxParameterProperty_Red: @1.0, kFxParameterProperty_Green: @0.0,
			   kFxParameterProperty_Blue: @0.0, kFxParameterProperty_Alpha: @0.5 }
	} };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_RGBA));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Alpha], @0.5);
	XCTAssertEqualObjects(target[kFxParameterProperty_Red], @1.0);
	XCTAssertEqualObjects(target[kFxParameterProperty_Green], @0.0);
	XCTAssertEqualObjects(target[kFxParameterProperty_Blue], @0.0);
}

/*! @abstract The values section leaves an RGBA target's existing alpha in place when the preset omits it. */
- (void)testValuesSectionLeavesRGBAAlphaWhenThePresetOmitsIt
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{
		@2: @{ kFxParameterProperty_Red: @1.0 }
	} };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_RGBA));
	target[kFxParameterProperty_Alpha] = @0.25;
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Alpha], @0.25);
	XCTAssertEqualObjects(target[kFxParameterProperty_Red], @1.0);
}

/*! @abstract The values section writes the X and Y axes of a Point target. */
- (void)testValuesSectionWritesThePointAxes
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{
		@2: @{ kFxParameterProperty_X: @12, kFxParameterProperty_Y: @34 }
	} };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Point));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_X], @12);
	XCTAssertEqualObjects(target[kFxParameterProperty_Y], @34);
}

/*! @abstract The values section deep-merges a Custom target's declared default with the preset value, with preset keys winning and unmatched declared keys kept. */
- (void)testValuesSectionMergesCustomDefaultsWithThePresetWinning
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{
		@2: @{ @"shared": @"preset", @"nested": @{ @"inner": @"preset" } }
	} };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Custom));
	target[kFxParameterProperty_Default] = @{
		@"shared": @"declared",
		@"kept": @"declared",
		@"nested": @{ @"inner": @"declared", @"innerKept": @"declared" }
	};
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	NSDictionary *merged = target[kFxParameterProperty_Default];
	XCTAssertEqualObjects(merged[@"shared"], @"preset");
	XCTAssertEqualObjects(merged[@"kept"], @"declared");
	XCTAssertEqualObjects(merged[@"nested"][@"inner"], @"preset");
	XCTAssertEqualObjects(merged[@"nested"][@"innerKept"], @"declared");
}

/*! @abstract The values section sets a Custom target's default to the preset value when the target declares none. */
- (void)testValuesSectionSetsTheCustomDefaultWhenTheTargetHasNone
{
	NSDictionary *value = @{ @"shape": @"circle" };
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{ @2: value } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Custom));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Default], value);
}

/*! @abstract The values section overwrites the default with the scalar value for a non-color, non-point, non-custom type. */
- (void)testValuesSectionSetsTheDefaultForEveryOtherType
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{ @2: @42.5 } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Default] = @1.0;
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Default], @42.5);
}


#pragma mark - Section Keys and Missing Targets

/*! @abstract Section keys address a target whether the key is a string or a number. */
- (void)testSectionKeysResolveAsStringsAndAsNumbers
{
	NSDictionary *preset = @{
		kFxParameterProperty_TargetPresetNames: @{ @"2": @"byString" },
		kFxParameterProperty_TargetPresetValues: @{ @3: @9 }
	};
	NSMutableDictionary *named = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableDictionary *valued = FxGripTPConfig(3, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		named,
		valued
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(named[kFxParameterProperty_Name], @"byString");
	XCTAssertEqualObjects(valued[kFxParameterProperty_Default], @9);
}

/*! @abstract A section entry addressing an unregistered parameter is skipped while entries for present parameters still apply. */
- (void)testSectionEntryForAnUnknownParameterIsSkippedWhileSiblingsApply
{
	NSDictionary *preset = @{
		kFxParameterProperty_TargetPresetNames: @{ @2: @"Renamed", @99: @"Nowhere" },
		kFxParameterProperty_TargetPresetValues: @{ @2: @5, @99: @6 }
	};
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil]);

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"Renamed");
	XCTAssertEqualObjects(target[kFxParameterProperty_Default], @5);
}


#pragma mark - Degenerate Input

/*! @abstract An empty parameter list is a no-op and stays empty. */
- (void)testEmptyParameterListIsANoOp
{
	NSMutableArray *parameters = NSMutableArray.new;

	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil]);
	XCTAssertEqual(parameters.count, 0u);
}

/*! @abstract A nil parameter list is a no-op and does not throw. */
- (void)testNilParameterListIsANoOp
{
	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:nil pluginPresets:nil]);
}


#pragma mark - Type Maps

/*! @abstract typeParameters is the inverse of parameterTypes. */
- (void)testTypeParametersInvertsTheTypeMap
{
	NSDictionary<NSString *, NSNumber *> *types = FxGripParameterUtility.parameterTypes;
	NSDictionary<NSNumber *, NSString *> *inverse = FxGripParameterUtility.typeParameters;

	XCTAssertEqual(inverse.count, types.count);
	for (NSString *name in types) {
		XCTAssertEqualObjects(inverse[types[name]], name);
	}
	XCTAssertTrue(inverse == FxGripParameterUtility.typeParameters);
}

/*! @abstract parameterTypeString: names a known type and is nil for an unknown one. */
- (void)testParameterTypeStringNamesKnownTypesOnly
{
	XCTAssertEqualObjects([FxGripParameterUtility parameterTypeString:FxParameterType_Float], kFxParameterType_Float);
	XCTAssertEqualObjects([FxGripParameterUtility parameterTypeString:FxParameterType_Section], kFxParameterType_Section);
	XCTAssertNil([FxGripParameterUtility parameterTypeString:FxParameterType_None]);
}

/*! @abstract parameterTypeFromString: maps a name in any case, decodes an unknown four-character name as its FourCC, and is None otherwise. */
- (void)testParameterTypeFromStringMapsNamesAndFourCharacterCodes
{
	XCTAssertEqual([FxGripParameterUtility parameterTypeFromString:@"FLOAT"], FxParameterType_Float);
	XCTAssertEqual([FxGripParameterUtility parameterTypeFromString:@"zzzz"], (FxParameterType)'zzzz');
	XCTAssertEqual([FxGripParameterUtility parameterTypeFromString:@"unknown"], FxParameterType_None);
	XCTAssertEqual([FxGripParameterUtility parameterTypeFromString:nil], FxParameterType_None);
}

#pragma mark - Flag Conversion

/*! @abstract convertToFlag: names a single-bit flag and is nil for zero or a multi-bit mask. */
- (void)testConvertToFlagNamesASingleBitOnly
{
	XCTAssertEqualObjects([FxGripParameterUtility convertToFlag:kFxParameterFlag_HIDDEN], kParameterFlagString_HIDDEN);
	XCTAssertNil([FxGripParameterUtility convertToFlag:kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED]);
	XCTAssertNil([FxGripParameterUtility convertToFlag:0]);
}

/*! @abstract convertToFlags: names every bit set in a mask. */
- (void)testConvertToFlagsNamesEveryBit
{
	NSArray *names = [FxGripParameterUtility convertToFlags:kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED | kFxParameterFlag_DONT_SAVE];

	XCTAssertEqual(names.count, 3u);
	XCTAssertTrue([names containsObject:kParameterFlagString_HIDDEN]);
	XCTAssertTrue([names containsObject:kParameterFlagString_DISABLED]);
	XCTAssertTrue([names containsObject:kParameterFlagString_DONT_SAVE]);
	XCTAssertEqualObjects([FxGripParameterUtility convertToFlags:0], @[]);
}

/*! @abstract convertFlag: maps a flag name to its bit and an unknown or nil name to the default. */
- (void)testConvertFlagMapsNamesToBits
{
	XCTAssertEqual([FxGripParameterUtility convertFlag:kParameterFlagString_DISABLED], (FxParameterFlags)kFxParameterFlag_DISABLED);
	XCTAssertEqual([FxGripParameterUtility convertFlag:@"no such flag"], (FxParameterFlags)kFxParameterFlag_DEFAULT);
	XCTAssertEqual([FxGripParameterUtility convertFlag:nil], (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

/*! @abstract convertFlags: folds a divided string, an array, and a dictionary's values into one mask. */
- (void)testConvertFlagsFoldsStringsArraysAndDictionaryValues
{
	FxParameterFlags expected = kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED;

	XCTAssertEqual([FxGripParameterUtility convertFlags:@"hidden, disabled"], expected);
	XCTAssertEqual(([FxGripParameterUtility convertFlags:@[kParameterFlagString_HIDDEN, kParameterFlagString_DISABLED]]), expected);
	XCTAssertEqual(([FxGripParameterUtility convertFlags:@{ @"a": kParameterFlagString_HIDDEN, @"b": kParameterFlagString_DISABLED }]), expected);
}

/*! @abstract convertFlags: is the default for nil, an unsupported type, and unknown names. */
- (void)testConvertFlagsIsTheDefaultForUnusableInput
{
	XCTAssertEqual([FxGripParameterUtility convertFlags:nil], (FxParameterFlags)kFxParameterFlag_DEFAULT);
	XCTAssertEqual([FxGripParameterUtility convertFlags:@42], (FxParameterFlags)kFxParameterFlag_DEFAULT);
	XCTAssertEqual([FxGripParameterUtility convertFlags:@"nothing known"], (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

#pragma mark - Flattening

/*! @abstract Flattening a nil list does not throw. */
- (void)testFlattenNilListIsANoOp
{
	XCTAssertNoThrow([FxGripParameterUtility flattenDictionaryParameters:nil]);
}

/*! @abstract A group's array of children unfolds after the group, each stamped with the group as parent. */
- (void)testFlattenUnfoldsAGroupsChildrenAfterTheGroup
{
	NSMutableDictionary *childA = FxGripTPConfig(11, @(FxParameterType_Float));
	NSMutableDictionary *childB = FxGripTPConfig(12, @(FxParameterType_Float));
	childB[kFxParameterProperty_ParentId] = @99;
	NSMutableDictionary *group = FxGripTPConfig(1, @(FxParameterType_Group));
	group[kFxParameterProperty_GroupParameters] = @[childA, childB];
	NSMutableDictionary *trailing = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[group, trailing]);

	[FxGripParameterUtility flattenDictionaryParameters:parameters];

	XCTAssertEqualObjects(parameters, (@[group, childA, childB, trailing]));
	XCTAssertNil(group[kFxParameterProperty_GroupParameters]);
	XCTAssertEqualObjects(childA[kFxParameterProperty_ParentId], @1);
	XCTAssertEqualObjects(childB[kFxParameterProperty_ParentId], @99);
}

/*! @abstract A group's dictionary of children unfolds its values. */
- (void)testFlattenUnfoldsAGroupsDictionaryOfChildren
{
	NSMutableDictionary *child = FxGripTPConfig(11, @(FxParameterType_Float));
	NSMutableDictionary *group = FxGripTPConfig(1, kFxParameterType_Group);
	group[kFxParameterProperty_GroupParameters] = @{ @"only": child };
	NSMutableArray *parameters = FxGripTPList(@[group]);

	[FxGripParameterUtility flattenDictionaryParameters:parameters];

	XCTAssertEqualObjects(parameters, (@[group, child]));
	XCTAssertEqualObjects(child[kFxParameterProperty_ParentId], @1);
}

/*! @abstract Nested groups flatten fully, with each child stamped by its immediate group. */
- (void)testFlattenUnfoldsNestedGroups
{
	NSMutableDictionary *leaf = FxGripTPConfig(21, @(FxParameterType_Float));
	NSMutableDictionary *inner = FxGripTPConfig(2, @(FxParameterType_Group));
	inner[kFxParameterProperty_GroupParameters] = @[leaf];
	NSMutableDictionary *outer = FxGripTPConfig(1, @(FxParameterType_Group));
	outer[kFxParameterProperty_GroupParameters] = @[inner];
	NSMutableArray *parameters = FxGripTPList(@[outer]);

	[FxGripParameterUtility flattenDictionaryParameters:parameters];

	XCTAssertEqualObjects(parameters, (@[outer, inner, leaf]));
	XCTAssertEqualObjects(inner[kFxParameterProperty_ParentId], @1);
	XCTAssertEqualObjects(leaf[kFxParameterProperty_ParentId], @2);
}

/*! @abstract A group whose children entry is neither an array nor a dictionary is left as declared. */
- (void)testFlattenLeavesAGroupWithAnUnusableChildrenEntry
{
	NSMutableDictionary *group = FxGripTPConfig(1, @(FxParameterType_Group));
	group[kFxParameterProperty_GroupParameters] = @"not children";
	NSMutableDictionary *empty = FxGripTPConfig(3, @(FxParameterType_Group));
	NSMutableArray *parameters = FxGripTPList(@[group, empty]);

	[FxGripParameterUtility flattenDictionaryParameters:parameters];

	XCTAssertEqualObjects(parameters, (@[group, empty]));
	XCTAssertEqualObjects(group[kFxParameterProperty_GroupParameters], @"not children");
}

#pragma mark - Target Preset Edge Cases

/*! @abstract A driver whose type is neither a number nor a string applies nothing. */
- (void)testDriverWithAnUnusableTypeIsIgnored
{
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @[@"menu"], @0, @[FxGripTPRenamePreset(@"ignored")]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}

/*! @abstract A driver without a target-preset entry applies nothing. */
- (void)testDriverWithoutADefinitionIsIgnored
{
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableDictionary *driver = FxGripTPConfig(1, @(FxParameterType_Menu));
	driver[kFxParameterProperty_Default] = @0;
	NSMutableArray *parameters = FxGripTPList(@[driver, target]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Name], @"declared");
}

/*! @abstract Immutable entries in the list are skipped as drivers and as targets, and a string id still dispatches. */
- (void)testImmutableEntriesAreSkippedAndStringIdsDispatch
{
	NSDictionary *immutableTarget = @{ kFxParameterProperty_Id: @2, kFxParameterProperty_Type: @(FxParameterType_Float),
									   kFxParameterProperty_Name: @"declared" };
	NSDictionary *immutableDriver = @{ kFxParameterProperty_Id: @5, kFxParameterProperty_Type: @(FxParameterType_Menu),
									   kFxParameterProperty_Default: @0,
									   kFxParameterProperty_TargetPreset: @[FxGripTPRenamePreset(@"fromImmutable")] };
	NSMutableDictionary *stringIdTarget = FxGripTPConfig(3, @(FxParameterType_Float));
	stringIdTarget[kFxParameterProperty_Id] = @"3";
	NSMutableDictionary *unkeyed = FxGripTPConfig(4, @(FxParameterType_Float));
	[unkeyed removeObjectForKey:kFxParameterProperty_Id];
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetNames: @{ @2: @"changed", @3: @"byStringId" } };
	NSMutableArray *parameters = FxGripTPList(@[
		(id)immutableDriver, (id)immutableTarget, stringIdTarget, unkeyed,
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset])
	]);

	XCTAssertNoThrow([FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil]);

	XCTAssertEqualObjects(immutableTarget[kFxParameterProperty_Name], @"declared");
	XCTAssertEqualObjects(stringIdTarget[kFxParameterProperty_Name], @"byStringId");
}

/*! @abstract A flags or tags entry that is neither a string nor an array leaves the target unchanged. */
- (void)testStringSpecOfAnUnusableTypeIsIgnored
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @17 },
							  kFxParameterProperty_TargetPresetTags: @{ @2: @{ @"no": @"tags" } } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = @[@"hidden"];
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], @[@"hidden"]);
	XCTAssertNil(target[kFxParameterProperty_Tags]);
}

/*! @abstract A flags spec skips empty, sign-only, and non-string entries and replaces a non-collection existing value. */
- (void)testStringSpecSkipsUnusableEntries
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetFlags: @{ @2: @[@"", @"+", @"-", @7, @"hidden"] } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	target[kFxParameterProperty_Flags] = @42;
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Flags], @[@"hidden"]);
}

/*! @abstract A color or point value that is not a dictionary leaves the target unchanged. */
- (void)testValuesSectionIgnoresANonDictionaryColorOrPointValue
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{ @2: @1.0, @3: @1.0, @4: @"point" } };
	NSMutableDictionary *rgb = FxGripTPConfig(2, @(FxParameterType_RGB));
	NSMutableDictionary *rgba = FxGripTPConfig(3, @(FxParameterType_RGBA));
	rgba[kFxParameterProperty_Alpha] = @0.5;
	NSMutableDictionary *point = FxGripTPConfig(4, @(FxParameterType_Point));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		rgb, rgba, point
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertNil(rgb[kFxParameterProperty_Red]);
	XCTAssertNil(rgb[kFxParameterProperty_Default]);
	XCTAssertEqualObjects(rgba[kFxParameterProperty_Alpha], @0.5);
	XCTAssertNil(rgba[kFxParameterProperty_Default]);
	XCTAssertNil(point[kFxParameterProperty_X]);
	XCTAssertNil(point[kFxParameterProperty_Default]);
}

/*! @abstract A Custom target with a dictionary default takes a non-dictionary preset value as its new default. */
- (void)testValuesSectionReplacesACustomDefaultWithANonDictionaryValue
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @{ @2: @"replacement" } };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Custom));
	target[kFxParameterProperty_Default] = @{ @"declared": @YES };
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertEqualObjects(target[kFxParameterProperty_Default], @"replacement");
}

/*! @abstract A values section that is not a dictionary applies nothing. */
- (void)testValuesSectionOfAnUnusableTypeIsIgnored
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetValues: @[@1, @2] };
	NSMutableDictionary *target = FxGripTPConfig(2, @(FxParameterType_Float));
	NSMutableArray *parameters = FxGripTPList(@[
		FxGripTPDriver(1, @(FxParameterType_Menu), @0, @[preset]),
		target
	]);

	[FxGripParameterUtility applyTargetPresetDefaults:parameters pluginPresets:nil];

	XCTAssertNil(target[kFxParameterProperty_Default]);
}

#pragma mark - Click Selectors

/*! @abstract The click selector name is the prefix followed by the decimal parameter ID and decodes back to it. */
- (void)testClickSelectorRoundTripsTheParameterID
{
	NSString *name = [FxGripParameterUtility clickSelectorNameForParameter:4321];
	FxParameterId decoded = 0;

	XCTAssertEqualObjects(name, [kFxGripClickSelectorPrefix stringByAppendingString:@"4321"]);
	XCTAssertTrue([FxGripParameterUtility getParameterID:&decoded fromClickSelector:NSSelectorFromString(name)]);
	XCTAssertEqual(decoded, 4321u);
}

/*! @abstract Decoding rejects a nil selector, a nil result pointer, a foreign selector, a bare prefix, non-digits, and an out-of-range value. */
- (void)testClickSelectorDecodingRejectsEveryOtherForm
{
	FxParameterId decoded = 0;

	XCTAssertFalse([FxGripParameterUtility getParameterID:&decoded fromClickSelector:NULL]);
	FxParameterId *noParameterID = NULL;
	XCTAssertFalse([FxGripParameterUtility getParameterID:noParameterID fromClickSelector:@selector(description)]);
	XCTAssertFalse([FxGripParameterUtility getParameterID:&decoded fromClickSelector:@selector(description)]);
	XCTAssertFalse([FxGripParameterUtility getParameterID:&decoded fromClickSelector:NSSelectorFromString(kFxGripClickSelectorPrefix)]);
	XCTAssertFalse([FxGripParameterUtility getParameterID:&decoded
											fromClickSelector:NSSelectorFromString([kFxGripClickSelectorPrefix stringByAppendingString:@"12x"])]);
	XCTAssertFalse([FxGripParameterUtility getParameterID:&decoded
											fromClickSelector:NSSelectorFromString([kFxGripClickSelectorPrefix stringByAppendingString:@"99999999999"])]);
}


@end
