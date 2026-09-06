/*!
	@file       NSDictionaryFxGripTileableEffectTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     NSDictionaryFxGripTileableEffectTests
	@abstract   Unit tests for the FxGripTileableEffect categories on NSNumber, NSString, NSArray, NSDictionary, and NSMutableDictionary.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the parameter-type and flag coercions, the human-divider string split, array localization and index access, the plugin-property accessors behind the plugin-dictionary guard, and the parameter-property accessors behind the parameter-dictionary guard. They also cover the gradient depth resolution, the mutable-dictionary setters, and the declared accessor surface.
*/

#import <XCTest/XCTest.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/FxGripParameterUtility.h"
#import "FxGrip/NSDictionary+FxGripTileableEffect.h"

#pragma mark - Fixtures

// The plugin guard requires uuid, className, and group together.
static NSMutableDictionary *FxGripPluginDictionary(void)
{
	return [NSMutableDictionary dictionaryWithDictionary:@{
		kProPlugPlugIn_UuidProperty: @"AAAABBBB-CCCC-DDDD-EEEE-FFFF00001111",
		kProPlugPlugIn_ClassNameProperty: @"FxGripTestPlugin",
		kProPlugPlugIn_GroupUUIDProperty: @"11110000-FFFF-EEEE-DDDD-CCCCBBBBAAAA"
	}];
}

// The parameter guard requires id, type, and name together.
static NSMutableDictionary *FxGripParameterDictionary(void)
{
	return [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(7),
		kFxParameterProperty_Type: kFxParameterType_Float,
		kFxParameterProperty_Name: @"Amount"
	}];
}

static NSDictionary *FxGripParameterDictionaryWith(NSString *key, id value)
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[key] = value;
	return dictionary;
}

static NSDictionary *FxGripPluginDictionaryWith(NSString *key, id value)
{
	NSMutableDictionary *dictionary = FxGripPluginDictionary();
	dictionary[key] = value;
	return dictionary;
}


@interface NSDictionaryFxGripTileableEffectTests : XCTestCase
@end

@implementation NSDictionaryFxGripTileableEffectTests

#pragma mark - NSNumber parameterType

/*! @abstract An NSNumber parameterType returns its integer value cast to the parameter type. */
- (void)testNumberParameterTypeIsItsIntegerValue
{
	XCTAssertEqual(@(FxParameterType_Float).parameterType, FxParameterType_Float);
	XCTAssertEqual(@(FxParameterType_Group).parameterType, FxParameterType_Group);
	XCTAssertEqual(@(FxParameterType_WebView).parameterType, FxParameterType_WebView);
}

/*! @abstract An NSNumber parameterType maps -1 to the array type and -2 to the dictionary type. */
- (void)testNumberParameterTypeAcceptsTheNegativeContainerTypes
{
	XCTAssertEqual(@(-1).parameterType, FxParameterType_Array);
	XCTAssertEqual(@(-2).parameterType, FxParameterType_Dictionary);
}

/*! @abstract An NSNumber parameterType truncates a fractional value to its integer part. */
- (void)testNumberParameterTypeTruncatesAFractionalValue
{
	XCTAssertEqual(@(2.9).parameterType, FxParameterType_RGBA);
}

#pragma mark - NSString parameterType

/*! @abstract An NSString parameterType resolves the declared type-name constants to their parameter types. */
- (void)testStringParameterTypeResolvesTheDeclaredTypeNames
{
	XCTAssertEqual(kFxParameterType_Float.parameterType, FxParameterType_Float);
	XCTAssertEqual(kFxParameterType_Integer.parameterType, FxParameterType_Int);
	XCTAssertEqual(kFxParameterType_Menu.parameterType, FxParameterType_Menu);
	XCTAssertEqual(kFxParameterType_Group.parameterType, FxParameterType_Group);
	XCTAssertEqual(kFxParameterType_WebView.parameterType, FxParameterType_WebView);
}

/*! @abstract An NSString parameterType resolves type names without regard to case. */
- (void)testStringParameterTypeIsCaseInsensitive
{
	XCTAssertEqual(@"FLOAT".parameterType, FxParameterType_Float);
	XCTAssertEqual(@"Toggle".parameterType, FxParameterType_Toggle);
}

/*! @abstract An NSString parameterType is the none type for an unknown or empty name. */
- (void)testStringParameterTypeOfAnUnknownNameIsNone
{
	XCTAssertEqual(@"notatype".parameterType, FxParameterType_None);
	XCTAssertEqual(@"".parameterType, FxParameterType_None);
}

/*! @abstract An unknown four-character name resolves to its packed four-character code. */
- (void)testStringParameterTypeOfAnUnknownFourCharacterNameIsItsFourCharacterCode
{
	XCTAssertEqual(@"abcd".parameterType, (FxParameterType)0x61626364);
}

#pragma mark - NSString splitByHumanDividers

/*! @abstract splitByHumanDividers separates on spaces, commas, semicolons, and periods. */
- (void)testSplitByHumanDividersSeparatesOnWhitespaceAndPunctuation
{
	NSArray *parts = @"one two,three;four.five".splitByHumanDividers;

	XCTAssertEqualObjects(parts, (@[ @"one", @"two", @"three", @"four", @"five" ]));
}

/*! @abstract splitByHumanDividers separates on newlines. */
- (void)testSplitByHumanDividersSeparatesOnNewlines
{
	XCTAssertEqualObjects(@"a\nb".splitByHumanDividers, (@[ @"a", @"b" ]));
}

/*! @abstract splitByHumanDividers keeps an empty component between two adjacent separators. */
- (void)testSplitByHumanDividersKeepsEmptyComponentsBetweenAdjacentSeparators
{
	XCTAssertEqualObjects(@"a,,b".splitByHumanDividers, (@[ @"a", @"", @"b" ]));
}

/*! @abstract splitByHumanDividers returns a single-element array for a string with no separators. */
- (void)testSplitByHumanDividersOfAStringWithoutSeparatorsIsTheWholeString
{
	XCTAssertEqualObjects(@"single".splitByHumanDividers, (@[ @"single" ]));
	XCTAssertEqualObjects(@"".splitByHumanDividers, (@[ @"" ]));
}

#pragma mark - NSArray localize

/*! @abstract localize preserves the element order and count of the array. */
- (void)testLocalizePreservesTheElementOrderAndCount
{
	NSArray *source = @[ @"first", @"second", @"third" ];

	NSArray *localized = source.localize;

	XCTAssertEqual(localized.count, source.count);
	XCTAssertEqualObjects(localized, source);
}

/*! @abstract localize passes non-string elements through as the same objects. */
- (void)testLocalizePassesNonStringElementsThrough
{
	NSNumber *number = @42;
	NSArray *inner = @[ @"x" ];

	NSArray *localized = (@[ number, inner ]).localize;

	XCTAssertEqual(localized.count, (NSUInteger)2);
	XCTAssertTrue(localized[0] == number);
	XCTAssertTrue(localized[1] == inner);
}

/*! @abstract localize of an empty array is an empty array. */
- (void)testLocalizeOfAnEmptyArrayIsAnEmptyArray
{
	XCTAssertEqualObjects(@[].localize, @[]);
}

#pragma mark - NSArray objectForIndex:

/*! @abstract objectForIndex: returns the array element at the given position. */
- (void)testArrayObjectForIndexReturnsTheElementAtThatPosition
{
	NSArray *list = @[ @"a", @"b", @"c" ];

	XCTAssertEqualObjects([list objectForIndex:0], @"a");
	XCTAssertEqualObjects([list objectForIndex:2], @"c");
}

/*! @abstract objectForIndex: raises when the array index is out of range. */
- (void)testArrayObjectForIndexRaisesWhenTheIndexIsOutOfRange
{
	XCTAssertThrows([@[ @"a" ] objectForIndex:1]);
}

#pragma mark - NSArray fxParameterFlags

/*! @abstract fxParameterFlags of an empty array is the default flags value. */
- (void)testFxParameterFlagsOfAnEmptyArrayIsTheDefault
{
	XCTAssertEqual(@[].fxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

/*! @abstract fxParameterFlags accumulates the named flags with a bitwise OR. */
- (void)testFxParameterFlagsAccumulatesNamedFlags
{
	FxParameterFlags expected = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN] |
								[FxGripParameterUtility convertFlag:kParameterFlagString_DISABLED];

	XCTAssertEqual((@[ kParameterFlagString_HIDDEN, kParameterFlagString_DISABLED ]).fxParameterFlags, expected);
}

/*! @abstract fxParameterFlags treats a plus-prefixed flag name as an addition. */
- (void)testFxParameterFlagsTreatsAPlusPrefixAsAddition
{
	FxParameterFlags hidden = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN];

	XCTAssertEqual((@[ [@"+" stringByAppendingString:kParameterFlagString_HIDDEN] ]).fxParameterFlags, hidden);
}

/*! @abstract fxParameterFlags treats a minus-prefixed flag name as a removal. */
- (void)testFxParameterFlagsTreatsAMinusPrefixAsRemoval
{
	NSString *minusHidden = [@"-" stringByAppendingString:kParameterFlagString_HIDDEN];

	NSArray *flags = @[ kParameterFlagString_HIDDEN, kParameterFlagString_DISABLED, minusHidden ];

	XCTAssertEqual(flags.fxParameterFlags, [FxGripParameterUtility convertFlag:kParameterFlagString_DISABLED]);
}

/*! @abstract fxParameterFlags applies its entries in order, so a later entry overrides an earlier one. */
- (void)testFxParameterFlagsAppliesEntriesInOrder
{
	NSString *minusHidden = [@"-" stringByAppendingString:kParameterFlagString_HIDDEN];
	FxParameterFlags hidden = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN];

	XCTAssertEqual((@[ minusHidden, kParameterFlagString_HIDDEN ]).fxParameterFlags, hidden);
	XCTAssertEqual((@[ kParameterFlagString_HIDDEN, minusHidden ]).fxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

/*! @abstract fxParameterFlags ignores entries that are not strings. */
- (void)testFxParameterFlagsIgnoresNonStringEntries
{
	FxParameterFlags hidden = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN];

	XCTAssertEqual((@[ @42, [NSNull null], kParameterFlagString_HIDDEN ]).fxParameterFlags, hidden);
}

/*! @abstract fxParameterFlags ignores an unknown flag name and returns the default. */
- (void)testFxParameterFlagsIgnoresUnknownFlagNames
{
	XCTAssertEqual((@[ @"notaflag" ]).fxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

#pragma mark - NSArray negativeFxParameterFlags

/*! @abstract negativeFxParameterFlags collects only the minus-prefixed flag names. */
- (void)testNegativeFxParameterFlagsCollectsOnlyTheMinusPrefixedEntries
{
	NSString *minusHidden = [@"-" stringByAppendingString:kParameterFlagString_HIDDEN];
	NSString *minusDisabled = [@"-" stringByAppendingString:kParameterFlagString_DISABLED];
	FxParameterFlags expected = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN] |
								[FxGripParameterUtility convertFlag:kParameterFlagString_DISABLED];

	NSArray *flags = @[ minusHidden, kParameterFlagString_COLLAPSED, minusDisabled ];

	XCTAssertEqual(flags.negativeFxParameterFlags, expected);
}

/*! @abstract negativeFxParameterFlags ignores plain and plus-prefixed entries. */
- (void)testNegativeFxParameterFlagsIgnoresPlainAndPlusPrefixedEntries
{
	NSArray *flags = @[ kParameterFlagString_HIDDEN, [@"+" stringByAppendingString:kParameterFlagString_DISABLED] ];

	XCTAssertEqual(flags.negativeFxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

/*! @abstract negativeFxParameterFlags ignores non-string entries and an empty array. */
- (void)testNegativeFxParameterFlagsIgnoresNonStringEntries
{
	XCTAssertEqual((@[ @1, [NSNull null] ]).negativeFxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
	XCTAssertEqual(@[].negativeFxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

#pragma mark - NSDictionary objectForIndex:

/*! @abstract objectForIndex: finds a value stored under an NSNumber key. */
- (void)testDictionaryObjectForIndexFindsANumberKey
{
	XCTAssertEqualObjects([(@{ @(3): @"three" }) objectForIndex:3], @"three");
}

/*! @abstract objectForIndex: falls back to the decimal string form of the index key. */
- (void)testDictionaryObjectForIndexFallsBackToTheDecimalStringKey
{
	XCTAssertEqualObjects([(@{ @"3": @"three" }) objectForIndex:3], @"three");
}

/*! @abstract objectForIndex: prefers the NSNumber key over the decimal string key. */
- (void)testDictionaryObjectForIndexPrefersTheNumberKeyOverTheStringKey
{
	NSDictionary *dictionary = @{ @(3): @"number", @"3": @"string" };

	XCTAssertEqualObjects([dictionary objectForIndex:3], @"number");
}

/*! @abstract objectForIndex: is nil when neither the number key nor the string key is present. */
- (void)testDictionaryObjectForIndexIsNilWhenNeitherKeyIsPresent
{
	XCTAssertNil([(@{ @"other": @"value" }) objectForIndex:3]);
	XCTAssertNil([@{} objectForIndex:0]);
}

#pragma mark - Plugin Dictionary Guard

/*! @abstract The plugin accessors are nil when the required uuid key is missing, so the plugin guard fails. */
- (void)testPluginAccessorsAreNilWhenTheUuidIsMissing
{
	NSMutableDictionary *dictionary = FxGripPluginDictionary();
	dictionary[kProPlugPlugIn_DisplayNameProperty] = @"Display";
	[dictionary removeObjectForKey:kProPlugPlugIn_UuidProperty];

	XCTAssertNil(dictionary.pluginUUID);
	XCTAssertNil(dictionary.pluginClassName);
	XCTAssertNil(dictionary.pluginDisplayName);
	XCTAssertNil(dictionary.pluginGroupUUID);
}

/*! @abstract The plugin accessors are nil when the required className key is missing. */
- (void)testPluginAccessorsAreNilWhenTheClassNameIsMissing
{
	NSMutableDictionary *dictionary = FxGripPluginDictionary();
	[dictionary removeObjectForKey:kProPlugPlugIn_ClassNameProperty];

	XCTAssertNil(dictionary.pluginUUID);
	XCTAssertNil(dictionary.pluginGroupUUID);
}

/*! @abstract The plugin accessors are nil when the required group key is missing. */
- (void)testPluginAccessorsAreNilWhenTheGroupIsMissing
{
	NSMutableDictionary *dictionary = FxGripPluginDictionary();
	[dictionary removeObjectForKey:kProPlugPlugIn_GroupUUIDProperty];

	XCTAssertNil(dictionary.pluginUUID);
	XCTAssertNil(dictionary.pluginClassName);
}

/*! @abstract Every nullable plugin accessor is nil for a dictionary that does not satisfy the plugin guard. */
- (void)testEveryNullablePluginAccessorIsNilForANonPluginDictionary
{
	NSDictionary *dictionary = @{ @"unrelated": @"value" };

	XCTAssertNil(dictionary.pluginUUID);
	XCTAssertNil(dictionary.pluginClassName);
	XCTAssertNil(dictionary.pluginDisplayName);
	XCTAssertNil(dictionary.pluginGroupUUID);
	XCTAssertNil(dictionary.pluginProtocolNames);
	XCTAssertNil(dictionary.pluginInfoString);
	XCTAssertNil(dictionary.pluginDefaultFontName);
	XCTAssertNil(dictionary.pluginPresets);
	XCTAssertNil(dictionary.pluginEffectProperties);
	XCTAssertNil(dictionary.pluginPriorUUIDs);
	XCTAssertNil(dictionary.pluginParameters);
}

/*! @abstract Every boolean plugin accessor is NO for a dictionary that does not satisfy the plugin guard, even when the keys are set. */
- (void)testEveryBooleanPluginAccessorIsNoForANonPluginDictionary
{
	NSDictionary *dictionary = @{
		kProPlugPlugInX_DebugMenuProperty: @YES,
		kProPlugPlugInX_DebugActivatorProperty: @YES,
		kProPlugPlugInX_ManagedMetaProperty: @YES,
		kProPlugPlugInX_ManagedParameterDataProperty: @YES,
		kProPlugPlugInX_TrackInstancesProperty: @YES
	};

	XCTAssertFalse(dictionary.pluginDebugMenu);
	XCTAssertFalse(dictionary.pluginDebugActivator);
	XCTAssertFalse(dictionary.pluginManageMeta);
	XCTAssertFalse(dictionary.pluginManageParameterData);
	XCTAssertFalse(dictionary.pluginTrackInstances);
}

#pragma mark - Plugin Property Access

/*! @abstract The plugin identity accessors return the uuid, class name, display name, and group uuid declared in the dictionary. */
- (void)testPluginIdentityAccessorsReturnTheirDeclaredValues
{
	NSMutableDictionary *dictionary = FxGripPluginDictionary();
	dictionary[kProPlugPlugIn_DisplayNameProperty] = @"Test Plugin";

	XCTAssertEqualObjects(dictionary.pluginUUID, dictionary[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(dictionary.pluginClassName, @"FxGripTestPlugin");
	XCTAssertEqualObjects(dictionary.pluginDisplayName, @"Test Plugin");
	XCTAssertEqualObjects(dictionary.pluginGroupUUID, dictionary[kProPlugPlugIn_GroupUUIDProperty]);
}

/*! @abstract pluginDisplayName is nil when no display name is declared. */
- (void)testPluginDisplayNameIsNilWhenItIsNotDeclared
{
	XCTAssertNil(FxGripPluginDictionary().pluginDisplayName);
}

/*! @abstract The plugin descriptive accessors return the declared protocol names, info string, and default font name. */
- (void)testPluginDescriptiveAccessorsReturnTheirDeclaredValues
{
	NSArray *protocols = @[ kProPlugPlugIn_ProtocolFxFilter ];
	NSDictionary *dictionary = FxGripPluginDictionaryWith(kProPlugPlugIn_ProtocolNamesProperty, protocols);
	NSMutableDictionary *full = [dictionary mutableCopy];
	full[kProPlugPlugIn_InfoStringProperty] = @"An effect.";
	full[kProPlugPlugInX_DefaultFontNameProperty] = @"Helvetica";

	XCTAssertEqualObjects(full.pluginProtocolNames, protocols);
	XCTAssertEqualObjects(full.pluginInfoString, @"An effect.");
	XCTAssertEqualObjects(full.pluginDefaultFontName, @"Helvetica");
}

/*! @abstract pluginPresets and pluginEffectProperties return their declared tables. */
- (void)testPluginPresetsAndEffectPropertiesReturnTheirDeclaredTables
{
	NSDictionary *presets = @{ @"one": @{ @"names": @{} } };
	NSDictionary *effects = @{ @"key": @1 };
	NSMutableDictionary *dictionary = FxGripPluginDictionary();
	dictionary[kProPlugPlugInX_PresetsProperty] = presets;
	dictionary[kProPlugPlugInX_EffectPropertiesProperty] = effects;

	XCTAssertEqualObjects(dictionary.pluginPresets, presets);
	XCTAssertEqualObjects(dictionary.pluginEffectProperties, effects);
}

/*! @abstract pluginParameters returns the declared parameter configuration list. */
- (void)testPluginParametersReturnsTheDeclaredConfigurationList
{
	NSArray *parameters = @[ FxGripParameterDictionary() ];

	XCTAssertEqualObjects(FxGripPluginDictionaryWith(kProPlugPlugInX_ParametersProperty, parameters).pluginParameters, parameters);
}

/*! @abstract pluginParameters is nil when no parameter list is declared. */
- (void)testPluginParametersIsNilWhenNoneAreDeclared
{
	XCTAssertNil(FxGripPluginDictionary().pluginParameters);
}

/*! @abstract pluginPriorUUIDs splits a string declaration on the human dividers. */
- (void)testPluginPriorUUIDsSplitsAStringDeclaration
{
	NSDictionary *dictionary = FxGripPluginDictionaryWith(kProPlugPlugInX_PriorUuidsProperty, @"UUID-1, UUID-2;UUID-3");

	XCTAssertEqualObjects(dictionary.pluginPriorUUIDs, (@[ @"UUID-1", @"", @"UUID-2", @"UUID-3" ]));
}

/*! @abstract pluginPriorUUIDs passes an array declaration through unchanged. */
- (void)testPluginPriorUUIDsPassesAnArrayDeclarationThrough
{
	NSArray *uuids = @[ @"UUID-1", @"UUID-2" ];

	XCTAssertEqualObjects(FxGripPluginDictionaryWith(kProPlugPlugInX_PriorUuidsProperty, uuids).pluginPriorUUIDs, uuids);
}

/*! @abstract pluginPriorUUIDs is nil when none are declared. */
- (void)testPluginPriorUUIDsIsNilWhenNoneAreDeclared
{
	XCTAssertNil(FxGripPluginDictionary().pluginPriorUUIDs);
}

#pragma mark - Plugin Boolean Properties

/*! @abstract pluginDebugMenu defaults to NO and follows a declared YES or NO value. */
- (void)testPluginDebugMenuDefaultsToNoAndFollowsItsDeclaration
{
	XCTAssertFalse(FxGripPluginDictionary().pluginDebugMenu);
	XCTAssertTrue(FxGripPluginDictionaryWith(kProPlugPlugInX_DebugMenuProperty, @YES).pluginDebugMenu);
	XCTAssertFalse(FxGripPluginDictionaryWith(kProPlugPlugInX_DebugMenuProperty, @NO).pluginDebugMenu);
}

/*! @abstract pluginDebugActivator defaults to NO and follows a declared YES or NO value. */
- (void)testPluginDebugActivatorDefaultsToNoAndFollowsItsDeclaration
{
	XCTAssertFalse(FxGripPluginDictionary().pluginDebugActivator);
	XCTAssertTrue(FxGripPluginDictionaryWith(kProPlugPlugInX_DebugActivatorProperty, @YES).pluginDebugActivator);
	XCTAssertFalse(FxGripPluginDictionaryWith(kProPlugPlugInX_DebugActivatorProperty, @NO).pluginDebugActivator);
}

/*! @abstract pluginManageMeta defaults to YES and follows a declared YES or NO value. */
- (void)testPluginManageMetaDefaultsToYesAndFollowsItsDeclaration
{
	XCTAssertTrue(FxGripPluginDictionary().pluginManageMeta);
	XCTAssertTrue(FxGripPluginDictionaryWith(kProPlugPlugInX_ManagedMetaProperty, @YES).pluginManageMeta);
	XCTAssertFalse(FxGripPluginDictionaryWith(kProPlugPlugInX_ManagedMetaProperty, @NO).pluginManageMeta);
}

/*! @abstract pluginManageParameterData defaults to NO and follows a declared YES or NO value. */
- (void)testPluginManageParameterDataDefaultsToNoAndFollowsItsDeclaration
{
	XCTAssertFalse(FxGripPluginDictionary().pluginManageParameterData);
	XCTAssertTrue(FxGripPluginDictionaryWith(kProPlugPlugInX_ManagedParameterDataProperty, @YES).pluginManageParameterData);
	XCTAssertFalse(FxGripPluginDictionaryWith(kProPlugPlugInX_ManagedParameterDataProperty, @NO).pluginManageParameterData);
}

/*! @abstract pluginTrackInstances defaults to NO and follows a declared YES or NO value. */
- (void)testPluginTrackInstancesDefaultsToNoAndFollowsItsDeclaration
{
	// Opt-in, matching the manage-meta / manage-parameter-data gates.
	XCTAssertFalse(FxGripPluginDictionary().pluginTrackInstances);
	XCTAssertTrue(FxGripPluginDictionaryWith(kProPlugPlugInX_TrackInstancesProperty, @YES).pluginTrackInstances);
	XCTAssertFalse(FxGripPluginDictionaryWith(kProPlugPlugInX_TrackInstancesProperty, @NO).pluginTrackInstances);
}

#pragma mark - Parameter Dictionary Guard

/*! @abstract The parameter accessors fall back to their default values when the required id key is missing. */
- (void)testParameterAccessorsFallBackWhenTheIdIsMissing
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	[dictionary removeObjectForKey:kFxParameterProperty_Id];

	XCTAssertEqual(dictionary.parameterType, FxParameterType_None);
	XCTAssertEqual(dictionary.parameterID, (FxParameterId)kFxParameterId_None);
	XCTAssertNil(dictionary.parameterName);
}

/*! @abstract The parameter accessors fall back to their default values when the required type key is missing. */
- (void)testParameterAccessorsFallBackWhenTheTypeIsMissing
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	[dictionary removeObjectForKey:kFxParameterProperty_Type];

	XCTAssertEqual(dictionary.parameterType, FxParameterType_None);
	XCTAssertEqual(dictionary.parameterID, (FxParameterId)kFxParameterId_None);
}

/*! @abstract The parameter accessors fall back to their default values when the required name key is missing. */
- (void)testParameterAccessorsFallBackWhenTheNameIsMissing
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	[dictionary removeObjectForKey:kFxParameterProperty_Name];

	XCTAssertNil(dictionary.parameterName);
	XCTAssertEqual(dictionary.parameterID, (FxParameterId)kFxParameterId_None);
}

/*! @abstract Every nullable parameter accessor is nil for a dictionary that does not satisfy the parameter guard. */
- (void)testEveryNullableParameterAccessorIsNilForANonParameterDictionary
{
	NSDictionary *dictionary = @{ @"unrelated": @"value" };

	XCTAssertNil(dictionary.parameterFactory);
	XCTAssertNil(dictionary.parameterExtensionKey);
	XCTAssertNil(dictionary.parameterClassName);
	XCTAssertNil(dictionary.parameterName);
	XCTAssertNil(dictionary.parameterDescription);
	XCTAssertNil(dictionary.parameterFlagsArray);
	XCTAssertNil(dictionary.parameterTags);
	XCTAssertNil(dictionary.parameterMeta);
	XCTAssertNil(dictionary.parameterCustomClass);
	XCTAssertNil(dictionary.parameterCustomClasses);
	XCTAssertNil(dictionary.parameterDefaultValue);
	XCTAssertNil(dictionary.parameterResetValue);
	XCTAssertNil(dictionary.parameterTargetPreset);
	XCTAssertNil(dictionary.parameterMaximum);
	XCTAssertNil(dictionary.parameterSliderMinimum);
	XCTAssertNil(dictionary.parameterSliderMaximum);
	XCTAssertNil(dictionary.parameterDelta);
	XCTAssertNil(dictionary.parameterSelector);
	XCTAssertNil(dictionary.parameterSelectorObject);
	XCTAssertNil(dictionary.parameterMenuItems);
}

/*! @abstract Every scalar parameter accessor returns its fallback value for a dictionary that does not satisfy the parameter guard. */
- (void)testEveryScalarParameterAccessorFallsBackForANonParameterDictionary
{
	NSDictionary *dictionary = @{ kFxParameterProperty_Minimum: @5 };

	XCTAssertEqual(dictionary.parameterType, FxParameterType_None);
	XCTAssertEqual(dictionary.parameterID, (FxParameterId)kFxParameterId_None);
	XCTAssertEqual(dictionary.parameterParentID, (FxParameterId)kFxParameterId_None);
	XCTAssertEqual(dictionary.parameterFlags, (FxParameterFlags)kFxParameterFlag_INVALID);
	XCTAssertEqual(dictionary.parameterMinimumInt, 0);
	XCTAssertEqual(dictionary.parameterMinimumDouble, 0.0);
}

/*!
	The color, gradient, and default-coordinate accessors read their key without the
	parameter-dictionary guard, so they answer for any dictionary.
*/
- (void)testUnguardedParameterAccessorsAnswerForAnyDictionary
{
	NSDictionary *dictionary = @{
		kFxParameterProperty_Red: @0.25,
		kFxParameterProperty_Green: @0.5,
		kFxParameterProperty_Blue: @0.75,
		kFxParameterProperty_Alpha: @1.0,
		kFxParameterProperty_ColorSpace: @2,
		kFxParameterProperty_GradientSamples: @64
	};

	XCTAssertEqualObjects(dictionary.parameterRed, @0.25);
	XCTAssertEqualObjects(dictionary.parameterGreen, @0.5);
	XCTAssertEqualObjects(dictionary.parameterBlue, @0.75);
	XCTAssertEqualObjects(dictionary.parameterAlpha, @1.0);
	XCTAssertEqualObjects(dictionary.parameterColorSpace, @2);
	XCTAssertEqualObjects(dictionary.parameterGradientSamples, @64);
}

/*! @abstract The unguarded color and gradient accessors are nil when their keys are absent. */
- (void)testUnguardedParameterAccessorsAreNilWhenTheirKeysAreAbsent
{
	NSDictionary *dictionary = @{};

	XCTAssertNil(dictionary.parameterRed);
	XCTAssertNil(dictionary.parameterGreen);
	XCTAssertNil(dictionary.parameterBlue);
	XCTAssertNil(dictionary.parameterAlpha);
	XCTAssertNil(dictionary.parameterColorSpace);
	XCTAssertNil(dictionary.parameterGradientSamples);
}

#pragma mark - Parameter Identity

/*! @abstract parameterID is the declared id number. */
- (void)testParameterIdIsTheDeclaredNumber
{
	XCTAssertEqual(FxGripParameterDictionary().parameterID, (FxParameterId)7);
}

/*! @abstract parameterParentID defaults to the top-level group when none is declared. */
- (void)testParameterParentIdDefaultsToTheTopLevelGroup
{
	XCTAssertEqual(FxGripParameterDictionary().parameterParentID, (FxParameterId)kFxParameterId_TopLevelGroup);
}

/*! @abstract parameterParentID is the declared parent id number. */
- (void)testParameterParentIdIsTheDeclaredNumber
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_ParentId, @(12));

	XCTAssertEqual(dictionary.parameterParentID, (FxParameterId)12);
}

/*! @abstract parameterName and parameterDescription are their declared strings. */
- (void)testParameterNameAndDescriptionAreTheirDeclaredStrings
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Description, @"How much.");

	XCTAssertEqualObjects(dictionary.parameterName, @"Amount");
	XCTAssertEqualObjects(dictionary.parameterDescription, @"How much.");
}

/*! @abstract parameterDescription is nil when no description is declared. */
- (void)testParameterDescriptionIsNilWhenItIsNotDeclared
{
	XCTAssertNil(FxGripParameterDictionary().parameterDescription);
}

/*! @abstract parameterFactory and parameterExtensionKey are their declared values. */
- (void)testParameterFactoryAndExtensionKeyAreTheirDeclaredValues
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	NSObject *factory = [NSObject new];
	dictionary[kFxParameterProperty_Factory] = factory;
	dictionary[kFxParameterProperty_ExtensionKey] = @"ext";

	XCTAssertTrue((id)dictionary.parameterFactory == factory);
	XCTAssertEqualObjects(dictionary.parameterExtensionKey, @"ext");
}

/*! @abstract parameterClassName is the declared class-name string. */
- (void)testParameterClassNameIsTheDeclaredString
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_ClassName, @"FxGripFloatParameter");

	XCTAssertEqualObjects(dictionary.parameterClassName, @"FxGripFloatParameter");
}

/*! @abstract parameterClassName is nil when the declaration is not a string or is absent. */
- (void)testParameterClassNameIsNilWhenTheDeclarationIsNotAString
{
	XCTAssertNil(FxGripParameterDictionaryWith(kFxParameterProperty_ClassName, @42).parameterClassName);
	XCTAssertNil(FxGripParameterDictionary().parameterClassName);
}

#pragma mark - Parameter Type

/*! @abstract parameterType resolves a number declaration to its parameter type. */
- (void)testParameterTypeResolvesANumberDeclaration
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Type, @(FxParameterType_Toggle));

	XCTAssertEqual(dictionary.parameterType, FxParameterType_Toggle);
}

/*! @abstract parameterType resolves a string declaration to its parameter type. */
- (void)testParameterTypeResolvesAStringDeclaration
{
	XCTAssertEqual(FxGripParameterDictionary().parameterType, FxParameterType_Float);
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Type, kFxParameterType_Menu).parameterType, FxParameterType_Menu);
}

/*! @abstract parameterType is the none type when the declaration is neither a number nor a string. */
- (void)testParameterTypeIsNoneWhenTheDeclarationIsNeitherANumberNorAString
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Type, @[ @1 ]).parameterType, FxParameterType_None);
}

#pragma mark - Parameter Flags

/*! @abstract parameterFlags defaults to the default flags value when none are declared. */
- (void)testParameterFlagsDefaultsToNoFlags
{
	XCTAssertEqual(FxGripParameterDictionary().parameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

/*! @abstract parameterFlags resolves a space-separated string declaration into the ORed flags. */
- (void)testParameterFlagsResolvesAStringDeclaration
{
	NSString *declaration = [NSString stringWithFormat:@"%@ %@", kParameterFlagString_HIDDEN, kParameterFlagString_DISABLED];
	FxParameterFlags expected = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN] |
								[FxGripParameterUtility convertFlag:kParameterFlagString_DISABLED];

	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, declaration).parameterFlags, expected);
}

/*! @abstract parameterFlags resolves an array declaration into the ORed flags. */
- (void)testParameterFlagsResolvesAnArrayDeclaration
{
	NSArray *declaration = @[ kParameterFlagString_COLLAPSED ];

	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, declaration).parameterFlags,
				   [FxGripParameterUtility convertFlag:kParameterFlagString_COLLAPSED]);
}

/*! @abstract parameterFlags resolves a dictionary declaration from its values. */
- (void)testParameterFlagsResolvesADictionaryDeclarationFromItsValues
{
	NSDictionary *declaration = @{ @"a": kParameterFlagString_HIDDEN };

	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, declaration).parameterFlags,
				   [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN]);
}

/*! @abstract parameterFlags passes a number declaration through as the raw flags value. */
- (void)testParameterFlagsPassesANumberDeclarationThrough
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, @(6)).parameterFlags, (FxParameterFlags)6);
}

#pragma mark - Parameter Flags Array

/*! @abstract parameterFlagsArray is empty when no flags are declared. */
- (void)testParameterFlagsArrayIsEmptyWhenNoFlagsAreDeclared
{
	XCTAssertEqualObjects(FxGripParameterDictionary().parameterFlagsArray, @[]);
}

/*! @abstract parameterFlagsArray splits a string declaration on the human dividers. */
- (void)testParameterFlagsArraySplitsAStringDeclaration
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Flags, @"hidden disabled");

	XCTAssertEqualObjects(dictionary.parameterFlagsArray, (@[ @"hidden", @"disabled" ]));
}

/*! @abstract parameterFlagsArray passes an array declaration through unchanged. */
- (void)testParameterFlagsArrayPassesAnArrayDeclarationThrough
{
	NSArray *declaration = @[ kParameterFlagString_HIDDEN ];

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, declaration).parameterFlagsArray, declaration);
}

/*! @abstract parameterFlagsArray takes the values of a dictionary declaration. */
- (void)testParameterFlagsArrayTakesADictionaryDeclarationsValues
{
	NSDictionary *declaration = @{ @"a": kParameterFlagString_HIDDEN };

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, declaration).parameterFlagsArray,
						  (@[ kParameterFlagString_HIDDEN ]));
}

/*! @abstract parameterFlagsArray expands a numeric flags declaration into its flag names. */
- (void)testParameterFlagsArrayExpandsANumberDeclarationIntoNames
{
	FxParameterFlags hidden = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN];
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Flags, @(hidden));

	XCTAssertEqualObjects(dictionary.parameterFlagsArray, (@[ kParameterFlagString_HIDDEN ]));
}

#pragma mark - Parameter Tags, Meta, and Custom Classes

/*! @abstract parameterTags splits a string declaration on the human dividers. */
- (void)testParameterTagsSplitsAStringDeclaration
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Tags, @"alpha,beta");

	XCTAssertEqualObjects(dictionary.parameterTags, (@[ @"alpha", @"beta" ]));
}

/*! @abstract parameterTags passes an array declaration through unchanged. */
- (void)testParameterTagsPassesAnArrayDeclarationThrough
{
	NSArray *tags = @[ @"alpha", @"beta" ];

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_Tags, tags).parameterTags, tags);
}

/*! @abstract parameterTags is nil when none are declared. */
- (void)testParameterTagsIsNilWhenNoneAreDeclared
{
	XCTAssertNil(FxGripParameterDictionary().parameterTags);
}

/*! @abstract parameterMeta is the declared dictionary and is nil when none is declared. */
- (void)testParameterMetaIsTheDeclaredDictionary
{
	NSDictionary *meta = @{ @"note": @"value" };

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_Meta, meta).parameterMeta, meta);
	XCTAssertNil(FxGripParameterDictionary().parameterMeta);
}

/*! @abstract parameterCustomClass is the declared string and is nil when none is declared. */
- (void)testParameterCustomClassIsTheDeclaredString
{
	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_CustomClass, @"MyView").parameterCustomClass, @"MyView");
	XCTAssertNil(FxGripParameterDictionary().parameterCustomClass);
}

/*! @abstract parameterCustomClasses is an empty set when none are declared. */
- (void)testParameterCustomClassesIsAnEmptySetWhenNoneAreDeclared
{
	XCTAssertEqualObjects(FxGripParameterDictionary().parameterCustomClasses, [NSSet set]);
}

/*! @abstract parameterCustomClasses splits a string declaration into a set. */
- (void)testParameterCustomClassesSplitsAStringDeclaration
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_CustomClasses, @"One,Two");

	XCTAssertEqualObjects(dictionary.parameterCustomClasses, ([NSSet setWithArray:(@[ @"One", @"Two" ])]));
}

/*! @abstract parameterCustomClasses converts an array declaration to a set, dropping duplicates. */
- (void)testParameterCustomClassesConvertsAnArrayDeclarationToASet
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_CustomClasses, (@[ @"One", @"Two", @"One" ]));

	XCTAssertEqualObjects(dictionary.parameterCustomClasses, ([NSSet setWithArray:(@[ @"One", @"Two" ])]));
}

/*! @abstract parameterCustomClasses passes a set declaration through unchanged. */
- (void)testParameterCustomClassesPassesASetDeclarationThrough
{
	NSSet *classes = [NSSet setWithObject:@"One"];

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_CustomClasses, classes).parameterCustomClasses, classes);
}

#pragma mark - Parameter Values

/*! @abstract parameterDefaultValue and parameterResetValue are their declared values. */
- (void)testParameterDefaultAndResetValuesAreTheirDeclarations
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_Default] = @1.5;
	dictionary[kFxParameterProperty_ResetValue] = @0.0;

	XCTAssertEqualObjects(dictionary.parameterDefaultValue, @1.5);
	XCTAssertEqualObjects(dictionary.parameterResetValue, @0.0);
}

/*! @abstract parameterTargetPreset is the declared preset dictionary and is nil when none is declared. */
- (void)testParameterTargetPresetIsItsDeclaration
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetNames: @{} };

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_TargetPreset, preset).parameterTargetPreset, preset);
	XCTAssertNil(FxGripParameterDictionary().parameterTargetPreset);
}

/*! @abstract parameterSelector and parameterSelectorObject are their declared values. */
- (void)testParameterSelectorAndSelectorObjectAreTheirDeclarations
{
	NSObject *target = [NSObject new];
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_Selector] = @"clicked";
	dictionary[kFxParameterProperty_SelectorObject] = target;

	XCTAssertEqualObjects(dictionary.parameterSelector, @"clicked");
	XCTAssertTrue(dictionary.parameterSelectorObject == target);
}

#pragma mark - Parameter Ranges

/*! @abstract parameterMinimumInt and parameterMinimumDouble read the minimum key as an integer and a double. */
- (void)testParameterMinimumIntAndDoubleReadTheMinimumKey
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Minimum, @(3.75));

	XCTAssertEqual(dictionary.parameterMinimumInt, 3);
	XCTAssertEqual(dictionary.parameterMinimumDouble, 3.75);
}

/*! @abstract parameterMinimumInt and parameterMinimumDouble coerce a string minimum declaration. */
- (void)testParameterMinimumIntAndDoubleCoerceAStringDeclaration
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Minimum, @"-2.5");

	XCTAssertEqual(dictionary.parameterMinimumInt, -2);
	XCTAssertEqual(dictionary.parameterMinimumDouble, -2.5);
}

/*! @abstract parameterMinimumInt and parameterMinimumDouble are zero when no minimum is declared. */
- (void)testParameterMinimumIntAndDoubleAreZeroWhenNoMinimumIsDeclared
{
	XCTAssertEqual(FxGripParameterDictionary().parameterMinimumInt, 0);
	XCTAssertEqual(FxGripParameterDictionary().parameterMinimumDouble, 0.0);
}

/*! @abstract parameterMaximum, the slider bounds, and parameterDelta are their declared values. */
- (void)testParameterMaximumSliderBoundsAndDeltaAreTheirDeclarations
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_Maximum] = @100;
	dictionary[kFxParameterProperty_SliderMinimum] = @1;
	dictionary[kFxParameterProperty_SliderMaximum] = @99;
	dictionary[kFxParameterProperty_Delta] = @0.5;

	XCTAssertEqualObjects(dictionary.parameterMaximum, @100);
	XCTAssertEqualObjects(dictionary.parameterSliderMinimum, @1);
	XCTAssertEqualObjects(dictionary.parameterSliderMaximum, @99);
	XCTAssertEqualObjects(dictionary.parameterDelta, @0.5);
}

/*! @abstract parameterMaximum, the slider bounds, and parameterDelta are nil when not declared. */
- (void)testParameterMaximumSliderBoundsAndDeltaAreNilWhenNotDeclared
{
	NSDictionary *dictionary = FxGripParameterDictionary();

	XCTAssertNil(dictionary.parameterMaximum);
	XCTAssertNil(dictionary.parameterSliderMinimum);
	XCTAssertNil(dictionary.parameterSliderMaximum);
	XCTAssertNil(dictionary.parameterDelta);
}

#pragma mark - Parameter Default Coordinates

/*! @abstract parameterDefaultX and parameterDefaultY read the explicit x and y keys. */
- (void)testParameterDefaultCoordinatesUseTheExplicitXAndYKeys
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_X] = @0.25;
	dictionary[kFxParameterProperty_Y] = @0.75;

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @0.25);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @0.75);
}

/*! @abstract parameterDefaultX and parameterDefaultY coerce string values in the explicit x and y keys. */
- (void)testParameterDefaultCoordinatesCoerceExplicitStringKeys
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_X] = @"0.25";
	dictionary[kFxParameterProperty_Y] = @"0.75";

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @0.25);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @0.75);
}

/*! @abstract parameterDefaultX and parameterDefaultY read the x and y entries of a dictionary default. */
- (void)testParameterDefaultCoordinatesReadADictionaryDefault
{
	NSDictionary *value = @{ kFxParameterProperty_X: @1.0, kFxParameterProperty_Y: @2.0 };
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Default, value);

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @1.0);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @2.0);
}

/*! @abstract parameterDefaultX and parameterDefaultY read the first and second elements of an array default. */
- (void)testParameterDefaultCoordinatesReadAnArrayDefaultPositionally
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Default, (@[ @3.0, @4.0 ]));

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @3.0);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @4.0);
}

/*! @abstract parameterDefaultY is zero when the array default holds only one entry. */
- (void)testParameterDefaultYIsZeroWhenTheArrayDefaultHasOnlyOneEntry
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Default, (@[ @3.0 ]));

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @3.0);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @0.0);
}

/*! @abstract parameterDefaultX and parameterDefaultY split a whitespace-separated string default. */
- (void)testParameterDefaultCoordinatesSplitAWhitespaceSeparatedStringDefault
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Default, @"1.5 -2.5");

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @1.5);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @(-2.5));
}

/*! @abstract parameterDefaultX and parameterDefaultY are zero when no default is declared. */
- (void)testParameterDefaultCoordinatesAreZeroWhenNothingIsDeclared
{
	XCTAssertEqualObjects(FxGripParameterDictionary().parameterDefaultX, @0.0);
	XCTAssertEqualObjects(FxGripParameterDictionary().parameterDefaultY, @0.0);
}

#pragma mark - Parameter Menu Items

/*! @abstract parameterMenuItems is the declared items array for a menu parameter. */
- (void)testParameterMenuItemsAreTheirDeclaration
{
	NSArray *items = @[ @"One", @"Two" ];
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_Type] = kFxParameterType_Menu;
	dictionary[kFxParameterProperty_MenuItems] = items;

	XCTAssertEqualObjects(dictionary.parameterMenuItems, items);
}

/*! @abstract parameterMenuItems is an empty array for a menu or capsule parameter with no declared items. */
- (void)testParameterMenuItemsAreEmptyForAMenuOrCapsuleWithoutADeclaration
{
	NSDictionary *menu = FxGripParameterDictionaryWith(kFxParameterProperty_Type, kFxParameterType_Menu);
	NSDictionary *capsule = FxGripParameterDictionaryWith(kFxParameterProperty_Type, kFxParameterType_Capsule);

	XCTAssertEqualObjects(menu.parameterMenuItems, @[]);
	XCTAssertEqualObjects(capsule.parameterMenuItems, @[]);
}

/*! @abstract parameterMenuItems is nil for a non-menu parameter with no declared items. */
- (void)testParameterMenuItemsAreNilForAnotherTypeWithoutADeclaration
{
	XCTAssertNil(FxGripParameterDictionary().parameterMenuItems);
}

#pragma mark - Gradient Depth Type

/*! @abstract parameterGradientDepthType is the none type when not declared. */
- (void)testParameterGradientDepthTypeIsNoneWhenNotDeclared
{
	XCTAssertEqual(FxGripParameterDictionary().parameterGradientDepthType, FxGripDepthTypeNone);
}

/*! @abstract parameterGradientDepthType resolves a number declaration to the matching depth type. */
- (void)testParameterGradientDepthTypeResolvesANumberDeclaration
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @0).parameterGradientDepthType, FxGripDepthTypeNone);
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @1).parameterGradientDepthType, FxGripDepthTypeFxDepth);
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @2).parameterGradientDepthType, FxGripDepthTypeBytes);
}

/*! @abstract parameterGradientDepthType clamps an above-range number declaration to the FxDepth type. */
- (void)testParameterGradientDepthTypeClampsANumberDeclarationAboveTheRange
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @(3)).parameterGradientDepthType, FxGripDepthTypeFxDepth);
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @(9)).parameterGradientDepthType, FxGripDepthTypeFxDepth);
}

/*! @abstract parameterGradientDepthType clamps a negative number declaration to the none type. */
- (void)testParameterGradientDepthTypeClampsANegativeNumberDeclarationToNone
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @(-1)).parameterGradientDepthType, FxGripDepthTypeNone);
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @(-3)).parameterGradientDepthType, FxGripDepthTypeNone);
}

/*! @abstract parameterGradientDepthType resolves the named string declarations and defaults an unknown name to the FxDepth type. */
- (void)testParameterGradientDepthTypeResolvesAStringDeclaration
{
	NSDictionary *bytes = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, kFxParameterProperty_GradientDepthType_Bytes);
	NSDictionary *fxDepth = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, kFxParameterProperty_GradientDepthType_FxDepth);
	NSDictionary *other = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @"unrecognized");

	XCTAssertEqual(bytes.parameterGradientDepthType, FxGripDepthTypeBytes);
	XCTAssertEqual(fxDepth.parameterGradientDepthType, FxGripDepthTypeFxDepth);
	XCTAssertEqual(other.parameterGradientDepthType, FxGripDepthTypeFxDepth);
}

/*! @abstract parameterGradientDepthType is the none type when the declaration is neither a number nor a string. */
- (void)testParameterGradientDepthTypeIsNoneWhenTheDeclarationIsNeitherANumberNorAString
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @[]).parameterGradientDepthType, FxGripDepthTypeNone);
}

#pragma mark - Gradient Depth

/*! @abstract parameterGradientDepth defaults to half precision when none is declared. */
- (void)testParameterGradientDepthDefaultsToHalfPrecision
{
	XCTAssertEqual((FxDepth)FxGripParameterDictionary().parameterGradientDepth, (FxDepth)kFxDepth_FLOAT16);
}

/*! @abstract parameterGradientDepth passes a number through as the raw depth when no depth type is declared. */
- (void)testParameterGradientDepthPassesANumberThroughWhenNoDepthTypeIsDeclared
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepth, @(kFxDepth_FLOAT32));

	XCTAssertEqual((FxDepth)dictionary.parameterGradientDepth, (FxDepth)kFxDepth_FLOAT32);
}

/*! @abstract parameterGradientDepth converts a byte count to the matching FxDepth when the depth type is bytes. */
- (void)testParameterGradientDepthConvertsAByteCountWhenTheDepthTypeIsBytes
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_GradientDepthType] = kFxParameterProperty_GradientDepthType_Bytes;

	dictionary[kFxParameterProperty_GradientDepth] = @1;
	XCTAssertEqual((FxDepth)dictionary.parameterGradientDepth, (FxDepth)kFxDepth_UINT8);

	dictionary[kFxParameterProperty_GradientDepth] = @2;
	XCTAssertEqual((FxDepth)dictionary.parameterGradientDepth, (FxDepth)kFxDepth_FLOAT16);

	dictionary[kFxParameterProperty_GradientDepth] = @4;
	XCTAssertEqual((FxDepth)dictionary.parameterGradientDepth, (FxDepth)kFxDepth_FLOAT32);
}

/*! @abstract parameterGradientDepth leaves an unrecognized byte count unchanged. */
- (void)testParameterGradientDepthLeavesAnUnrecognizedByteCountAlone
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_GradientDepthType] = kFxParameterProperty_GradientDepthType_Bytes;
	dictionary[kFxParameterProperty_GradientDepth] = @3;

	XCTAssertEqual((FxDepth)dictionary.parameterGradientDepth, (FxDepth)3);
}

/*! @abstract parameterGradientDepth resolves the named depth strings and defaults an unknown name to half precision. */
- (void)testParameterGradientDepthResolvesTheNamedDepths
{
	NSDictionary *uint8 = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepth, kFxParameterProperty_GradientDepth_UInt8);
	NSDictionary *half = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepth, kFxParameterProperty_GradientDepth_half16);
	NSDictionary *float32 = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepth, kFxParameterProperty_GradientDepth_float32);
	NSDictionary *other = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepth, @"unrecognized");

	XCTAssertEqual((FxDepth)uint8.parameterGradientDepth, (FxDepth)kFxDepth_UINT8);
	XCTAssertEqual((FxDepth)half.parameterGradientDepth, (FxDepth)kFxDepth_FLOAT16);
	XCTAssertEqual((FxDepth)float32.parameterGradientDepth, (FxDepth)kFxDepth_FLOAT32);
	XCTAssertEqual((FxDepth)other.parameterGradientDepth, (FxDepth)kFxDepth_FLOAT16);
}

/*! @abstract parameterGradientDepth resolves a named depth string even when the depth type is bytes. */
- (void)testParameterGradientDepthIgnoresAByteDepthTypeForANamedDepth
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_GradientDepthType] = kFxParameterProperty_GradientDepthType_Bytes;
	dictionary[kFxParameterProperty_GradientDepth] = kFxParameterProperty_GradientDepth_UInt8;

	XCTAssertEqual((FxDepth)dictionary.parameterGradientDepth, (FxDepth)kFxDepth_UINT8);
}

#pragma mark - NSMutableDictionary Setters

/*! @abstract Setting parameterType writes the type key and reads back the same type. */
- (void)testSetParameterTypeWritesTheTypeKeyAndReadsBack
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();

	dictionary.parameterType = FxParameterType_Toggle;

	XCTAssertEqualObjects(dictionary[kFxParameterProperty_Type], @(FxParameterType_Toggle));
	XCTAssertEqual(dictionary.parameterType, FxParameterType_Toggle);
}

/*! @abstract Setting parameterID writes the id key and reads back the same id. */
- (void)testSetParameterIdWritesTheIdKeyAndReadsBack
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();

	dictionary.parameterID = 33;

	XCTAssertEqualObjects(dictionary[kFxParameterProperty_Id], @(33));
	XCTAssertEqual(dictionary.parameterID, (FxParameterId)33);
}

/*! @abstract Setting parameterParentID writes the parent key and reads back the same id. */
- (void)testSetParameterParentIdWritesTheParentKeyAndReadsBack
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();

	dictionary.parameterParentID = 5;

	XCTAssertEqualObjects(dictionary[kFxParameterProperty_ParentId], @(5));
	XCTAssertEqual(dictionary.parameterParentID, (FxParameterId)5);
}

/*! @abstract Setting parameterFlags writes the flags key and reads back the same flags. */
- (void)testSetParameterFlagsWritesTheFlagsKeyAndReadsBack
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	FxParameterFlags hidden = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN];

	dictionary.parameterFlags = hidden;

	XCTAssertEqualObjects(dictionary[kFxParameterProperty_Flags], @(hidden));
	XCTAssertEqual(dictionary.parameterFlags, hidden);
}

/*! @abstract The setters build a dictionary that satisfies the parameter guard, so the read accessors return the set values. */
- (void)testSettersBuildADictionaryThatSatisfiesTheParameterGuard
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	dictionary.parameterID = 9;
	dictionary.parameterType = FxParameterType_Int;
	dictionary[kFxParameterProperty_Name] = @"Count";

	XCTAssertEqual(dictionary.parameterID, (FxParameterId)9);
	XCTAssertEqual(dictionary.parameterType, FxParameterType_Int);
	XCTAssertEqualObjects(dictionary.parameterName, @"Count");
}

#pragma mark - Declared Surface

/*!
	FRAMEWORK DEFECT. NSDictionary+FxGripTileableEffect.h declares four accessors that
	NSDictionary+FxGripTileableEffect.m never implements, so every caller raises
	NSInvalidArgumentException:

	  -pluginVersion            (declared line 54)
	  -parameterMinimum_Raw     (declared line 87; the implementation is named
	                             -parameterMinimum)
	  -parameterMaximumInt      (declared line 91)
	  -parameterMaximumDouble   (declared line 92)

	-parameterMinimum_Raw is called by FxGripAngleParameter.m:34,
	FxGripPercentParameter.m:39, FxGripFloatParameter.m:41, and
	FxGripIntParameter.m:58; -parameterMaximumDouble is called by
	FxGripParameterCreationAPI_v5.m:108.
*/
- (void)testEveryAccessorDeclaredInTheHeaderIsImplemented
{
	NSDictionary *dictionary = FxGripParameterDictionary();

	XCTAssertTrue([dictionary respondsToSelector:@selector(pluginVersion)]);
	XCTAssertTrue([dictionary respondsToSelector:@selector(parameterMinimum_Raw)]);
	XCTAssertTrue([dictionary respondsToSelector:@selector(parameterMaximumInt)]);
	XCTAssertTrue([dictionary respondsToSelector:@selector(parameterMaximumDouble)]);
}

/*! @abstract parameterMinimum_Raw returns the declared minimum for a parameter dictionary and is nil for a non-parameter dictionary. */
- (void)testTheRawMinimumAccessorMatchesItsDeclaration
{
	NSDictionary *parameter = FxGripParameterDictionaryWith(kFxParameterProperty_Minimum, @(3.5));
	NSDictionary *other = @{ kFxParameterProperty_Minimum: @(3.5) };

	XCTAssertEqualObjects(parameter.parameterMinimum_Raw, @(3.5));
	XCTAssertNil(other.parameterMinimum_Raw, @"the parameter guard rejects a non-parameter dictionary");
}

@end
