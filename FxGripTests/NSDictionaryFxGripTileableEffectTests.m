//
//  NSDictionaryFxGripTileableEffectTests.m
//  FxGripTests
//
//  Unit tests for the NSNumber, NSString, NSArray, NSDictionary, and
//  NSMutableDictionary (FxGripTileableEffect) categories: the type and flag coercions,
//  the plugin-property accessors behind the plugin-dictionary guard, and the
//  parameter-property accessors behind the parameter-dictionary guard.
//

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

- (void)testNumberParameterTypeIsItsIntegerValue
{
	XCTAssertEqual(@(FxParameterType_Float).parameterType, FxParameterType_Float);
	XCTAssertEqual(@(FxParameterType_Group).parameterType, FxParameterType_Group);
	XCTAssertEqual(@(FxParameterType_WebView).parameterType, FxParameterType_WebView);
}

- (void)testNumberParameterTypeAcceptsTheNegativeContainerTypes
{
	XCTAssertEqual(@(-1).parameterType, FxParameterType_Array);
	XCTAssertEqual(@(-2).parameterType, FxParameterType_Dictionary);
}

- (void)testNumberParameterTypeTruncatesAFractionalValue
{
	XCTAssertEqual(@(2.9).parameterType, FxParameterType_RGBA);
}

#pragma mark - NSString parameterType

- (void)testStringParameterTypeResolvesTheDeclaredTypeNames
{
	XCTAssertEqual(kFxParameterType_Float.parameterType, FxParameterType_Float);
	XCTAssertEqual(kFxParameterType_Integer.parameterType, FxParameterType_Int);
	XCTAssertEqual(kFxParameterType_Menu.parameterType, FxParameterType_Menu);
	XCTAssertEqual(kFxParameterType_Group.parameterType, FxParameterType_Group);
	XCTAssertEqual(kFxParameterType_WebView.parameterType, FxParameterType_WebView);
}

- (void)testStringParameterTypeIsCaseInsensitive
{
	XCTAssertEqual(@"FLOAT".parameterType, FxParameterType_Float);
	XCTAssertEqual(@"Toggle".parameterType, FxParameterType_Toggle);
}

- (void)testStringParameterTypeOfAnUnknownNameIsNone
{
	XCTAssertEqual(@"notatype".parameterType, FxParameterType_None);
	XCTAssertEqual(@"".parameterType, FxParameterType_None);
}

- (void)testStringParameterTypeOfAnUnknownFourCharacterNameIsItsFourCharacterCode
{
	XCTAssertEqual(@"abcd".parameterType, (FxParameterType)0x61626364);
}

#pragma mark - NSString splitByHumanDividers

- (void)testSplitByHumanDividersSeparatesOnWhitespaceAndPunctuation
{
	NSArray *parts = @"one two,three;four.five".splitByHumanDividers;

	XCTAssertEqualObjects(parts, (@[ @"one", @"two", @"three", @"four", @"five" ]));
}

- (void)testSplitByHumanDividersSeparatesOnNewlines
{
	XCTAssertEqualObjects(@"a\nb".splitByHumanDividers, (@[ @"a", @"b" ]));
}

- (void)testSplitByHumanDividersKeepsEmptyComponentsBetweenAdjacentSeparators
{
	XCTAssertEqualObjects(@"a,,b".splitByHumanDividers, (@[ @"a", @"", @"b" ]));
}

- (void)testSplitByHumanDividersOfAStringWithoutSeparatorsIsTheWholeString
{
	XCTAssertEqualObjects(@"single".splitByHumanDividers, (@[ @"single" ]));
	XCTAssertEqualObjects(@"".splitByHumanDividers, (@[ @"" ]));
}

#pragma mark - NSArray localize

- (void)testLocalizePreservesTheElementOrderAndCount
{
	NSArray *source = @[ @"first", @"second", @"third" ];

	NSArray *localized = source.localize;

	XCTAssertEqual(localized.count, source.count);
	XCTAssertEqualObjects(localized, source);
}

- (void)testLocalizePassesNonStringElementsThrough
{
	NSNumber *number = @42;
	NSArray *inner = @[ @"x" ];

	NSArray *localized = (@[ number, inner ]).localize;

	XCTAssertEqual(localized.count, (NSUInteger)2);
	XCTAssertTrue(localized[0] == number);
	XCTAssertTrue(localized[1] == inner);
}

- (void)testLocalizeOfAnEmptyArrayIsAnEmptyArray
{
	XCTAssertEqualObjects(@[].localize, @[]);
}

#pragma mark - NSArray objectForIndex:

- (void)testArrayObjectForIndexReturnsTheElementAtThatPosition
{
	NSArray *list = @[ @"a", @"b", @"c" ];

	XCTAssertEqualObjects([list objectForIndex:0], @"a");
	XCTAssertEqualObjects([list objectForIndex:2], @"c");
}

- (void)testArrayObjectForIndexRaisesWhenTheIndexIsOutOfRange
{
	XCTAssertThrows([@[ @"a" ] objectForIndex:1]);
}

#pragma mark - NSArray fxParameterFlags

- (void)testFxParameterFlagsOfAnEmptyArrayIsTheDefault
{
	XCTAssertEqual(@[].fxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

- (void)testFxParameterFlagsAccumulatesNamedFlags
{
	FxParameterFlags expected = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN] |
								[FxGripParameterUtility convertFlag:kParameterFlagString_DISABLED];

	XCTAssertEqual((@[ kParameterFlagString_HIDDEN, kParameterFlagString_DISABLED ]).fxParameterFlags, expected);
}

- (void)testFxParameterFlagsTreatsAPlusPrefixAsAddition
{
	FxParameterFlags hidden = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN];

	XCTAssertEqual((@[ [@"+" stringByAppendingString:kParameterFlagString_HIDDEN] ]).fxParameterFlags, hidden);
}

- (void)testFxParameterFlagsTreatsAMinusPrefixAsRemoval
{
	NSString *minusHidden = [@"-" stringByAppendingString:kParameterFlagString_HIDDEN];

	NSArray *flags = @[ kParameterFlagString_HIDDEN, kParameterFlagString_DISABLED, minusHidden ];

	XCTAssertEqual(flags.fxParameterFlags, [FxGripParameterUtility convertFlag:kParameterFlagString_DISABLED]);
}

- (void)testFxParameterFlagsAppliesEntriesInOrder
{
	NSString *minusHidden = [@"-" stringByAppendingString:kParameterFlagString_HIDDEN];
	FxParameterFlags hidden = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN];

	XCTAssertEqual((@[ minusHidden, kParameterFlagString_HIDDEN ]).fxParameterFlags, hidden);
	XCTAssertEqual((@[ kParameterFlagString_HIDDEN, minusHidden ]).fxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

- (void)testFxParameterFlagsIgnoresNonStringEntries
{
	FxParameterFlags hidden = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN];

	XCTAssertEqual((@[ @42, [NSNull null], kParameterFlagString_HIDDEN ]).fxParameterFlags, hidden);
}

- (void)testFxParameterFlagsIgnoresUnknownFlagNames
{
	XCTAssertEqual((@[ @"notaflag" ]).fxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

#pragma mark - NSArray negativeFxParameterFlags

- (void)testNegativeFxParameterFlagsCollectsOnlyTheMinusPrefixedEntries
{
	NSString *minusHidden = [@"-" stringByAppendingString:kParameterFlagString_HIDDEN];
	NSString *minusDisabled = [@"-" stringByAppendingString:kParameterFlagString_DISABLED];
	FxParameterFlags expected = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN] |
								[FxGripParameterUtility convertFlag:kParameterFlagString_DISABLED];

	NSArray *flags = @[ minusHidden, kParameterFlagString_COLLAPSED, minusDisabled ];

	XCTAssertEqual(flags.negativeFxParameterFlags, expected);
}

- (void)testNegativeFxParameterFlagsIgnoresPlainAndPlusPrefixedEntries
{
	NSArray *flags = @[ kParameterFlagString_HIDDEN, [@"+" stringByAppendingString:kParameterFlagString_DISABLED] ];

	XCTAssertEqual(flags.negativeFxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

- (void)testNegativeFxParameterFlagsIgnoresNonStringEntries
{
	XCTAssertEqual((@[ @1, [NSNull null] ]).negativeFxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
	XCTAssertEqual(@[].negativeFxParameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

#pragma mark - NSDictionary objectForIndex:

- (void)testDictionaryObjectForIndexFindsANumberKey
{
	XCTAssertEqualObjects([(@{ @(3): @"three" }) objectForIndex:3], @"three");
}

- (void)testDictionaryObjectForIndexFallsBackToTheDecimalStringKey
{
	XCTAssertEqualObjects([(@{ @"3": @"three" }) objectForIndex:3], @"three");
}

- (void)testDictionaryObjectForIndexPrefersTheNumberKeyOverTheStringKey
{
	NSDictionary *dictionary = @{ @(3): @"number", @"3": @"string" };

	XCTAssertEqualObjects([dictionary objectForIndex:3], @"number");
}

- (void)testDictionaryObjectForIndexIsNilWhenNeitherKeyIsPresent
{
	XCTAssertNil([(@{ @"other": @"value" }) objectForIndex:3]);
	XCTAssertNil([@{} objectForIndex:0]);
}

#pragma mark - Plugin Dictionary Guard

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

- (void)testPluginAccessorsAreNilWhenTheClassNameIsMissing
{
	NSMutableDictionary *dictionary = FxGripPluginDictionary();
	[dictionary removeObjectForKey:kProPlugPlugIn_ClassNameProperty];

	XCTAssertNil(dictionary.pluginUUID);
	XCTAssertNil(dictionary.pluginGroupUUID);
}

- (void)testPluginAccessorsAreNilWhenTheGroupIsMissing
{
	NSMutableDictionary *dictionary = FxGripPluginDictionary();
	[dictionary removeObjectForKey:kProPlugPlugIn_GroupUUIDProperty];

	XCTAssertNil(dictionary.pluginUUID);
	XCTAssertNil(dictionary.pluginClassName);
}

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

- (void)testPluginIdentityAccessorsReturnTheirDeclaredValues
{
	NSMutableDictionary *dictionary = FxGripPluginDictionary();
	dictionary[kProPlugPlugIn_DisplayNameProperty] = @"Test Plugin";

	XCTAssertEqualObjects(dictionary.pluginUUID, dictionary[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(dictionary.pluginClassName, @"FxGripTestPlugin");
	XCTAssertEqualObjects(dictionary.pluginDisplayName, @"Test Plugin");
	XCTAssertEqualObjects(dictionary.pluginGroupUUID, dictionary[kProPlugPlugIn_GroupUUIDProperty]);
}

- (void)testPluginDisplayNameIsNilWhenItIsNotDeclared
{
	XCTAssertNil(FxGripPluginDictionary().pluginDisplayName);
}

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

- (void)testPluginParametersReturnsTheDeclaredConfigurationList
{
	NSArray *parameters = @[ FxGripParameterDictionary() ];

	XCTAssertEqualObjects(FxGripPluginDictionaryWith(kProPlugPlugInX_ParametersProperty, parameters).pluginParameters, parameters);
}

- (void)testPluginParametersIsNilWhenNoneAreDeclared
{
	XCTAssertNil(FxGripPluginDictionary().pluginParameters);
}

- (void)testPluginPriorUUIDsSplitsAStringDeclaration
{
	NSDictionary *dictionary = FxGripPluginDictionaryWith(kProPlugPlugInX_PriorUuidsProperty, @"UUID-1, UUID-2;UUID-3");

	XCTAssertEqualObjects(dictionary.pluginPriorUUIDs, (@[ @"UUID-1", @"", @"UUID-2", @"UUID-3" ]));
}

- (void)testPluginPriorUUIDsPassesAnArrayDeclarationThrough
{
	NSArray *uuids = @[ @"UUID-1", @"UUID-2" ];

	XCTAssertEqualObjects(FxGripPluginDictionaryWith(kProPlugPlugInX_PriorUuidsProperty, uuids).pluginPriorUUIDs, uuids);
}

- (void)testPluginPriorUUIDsIsNilWhenNoneAreDeclared
{
	XCTAssertNil(FxGripPluginDictionary().pluginPriorUUIDs);
}

#pragma mark - Plugin Boolean Properties

- (void)testPluginDebugMenuDefaultsToNoAndFollowsItsDeclaration
{
	XCTAssertFalse(FxGripPluginDictionary().pluginDebugMenu);
	XCTAssertTrue(FxGripPluginDictionaryWith(kProPlugPlugInX_DebugMenuProperty, @YES).pluginDebugMenu);
	XCTAssertFalse(FxGripPluginDictionaryWith(kProPlugPlugInX_DebugMenuProperty, @NO).pluginDebugMenu);
}

- (void)testPluginDebugActivatorDefaultsToNoAndFollowsItsDeclaration
{
	XCTAssertFalse(FxGripPluginDictionary().pluginDebugActivator);
	XCTAssertTrue(FxGripPluginDictionaryWith(kProPlugPlugInX_DebugActivatorProperty, @YES).pluginDebugActivator);
	XCTAssertFalse(FxGripPluginDictionaryWith(kProPlugPlugInX_DebugActivatorProperty, @NO).pluginDebugActivator);
}

- (void)testPluginManageMetaDefaultsToNoAndFollowsItsDeclaration
{
	XCTAssertFalse(FxGripPluginDictionary().pluginManageMeta);
	XCTAssertTrue(FxGripPluginDictionaryWith(kProPlugPlugInX_ManagedMetaProperty, @YES).pluginManageMeta);
	XCTAssertFalse(FxGripPluginDictionaryWith(kProPlugPlugInX_ManagedMetaProperty, @NO).pluginManageMeta);
}

- (void)testPluginManageParameterDataDefaultsToNoAndFollowsItsDeclaration
{
	XCTAssertFalse(FxGripPluginDictionary().pluginManageParameterData);
	XCTAssertTrue(FxGripPluginDictionaryWith(kProPlugPlugInX_ManagedParameterDataProperty, @YES).pluginManageParameterData);
	XCTAssertFalse(FxGripPluginDictionaryWith(kProPlugPlugInX_ManagedParameterDataProperty, @NO).pluginManageParameterData);
}

- (void)testPluginTrackInstancesDefaultsToNoAndFollowsItsDeclaration
{
	// Opt-in, matching the manage-meta / manage-parameter-data gates.
	XCTAssertFalse(FxGripPluginDictionary().pluginTrackInstances);
	XCTAssertTrue(FxGripPluginDictionaryWith(kProPlugPlugInX_TrackInstancesProperty, @YES).pluginTrackInstances);
	XCTAssertFalse(FxGripPluginDictionaryWith(kProPlugPlugInX_TrackInstancesProperty, @NO).pluginTrackInstances);
}

#pragma mark - Parameter Dictionary Guard

- (void)testParameterAccessorsFallBackWhenTheIdIsMissing
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	[dictionary removeObjectForKey:kFxParameterProperty_Id];

	XCTAssertEqual(dictionary.parameterType, FxParameterType_None);
	XCTAssertEqual(dictionary.parameterID, (FxParameterId)kFxParameterId_None);
	XCTAssertNil(dictionary.parameterName);
}

- (void)testParameterAccessorsFallBackWhenTheTypeIsMissing
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	[dictionary removeObjectForKey:kFxParameterProperty_Type];

	XCTAssertEqual(dictionary.parameterType, FxParameterType_None);
	XCTAssertEqual(dictionary.parameterID, (FxParameterId)kFxParameterId_None);
}

- (void)testParameterAccessorsFallBackWhenTheNameIsMissing
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	[dictionary removeObjectForKey:kFxParameterProperty_Name];

	XCTAssertNil(dictionary.parameterName);
	XCTAssertEqual(dictionary.parameterID, (FxParameterId)kFxParameterId_None);
}

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

- (void)testParameterIdIsTheDeclaredNumber
{
	XCTAssertEqual(FxGripParameterDictionary().parameterID, (FxParameterId)7);
}

- (void)testParameterParentIdDefaultsToTheTopLevelGroup
{
	XCTAssertEqual(FxGripParameterDictionary().parameterParentID, (FxParameterId)kFxParameterId_TopLevelGroup);
}

- (void)testParameterParentIdIsTheDeclaredNumber
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_ParentId, @(12));

	XCTAssertEqual(dictionary.parameterParentID, (FxParameterId)12);
}

- (void)testParameterNameAndDescriptionAreTheirDeclaredStrings
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Description, @"How much.");

	XCTAssertEqualObjects(dictionary.parameterName, @"Amount");
	XCTAssertEqualObjects(dictionary.parameterDescription, @"How much.");
}

- (void)testParameterDescriptionIsNilWhenItIsNotDeclared
{
	XCTAssertNil(FxGripParameterDictionary().parameterDescription);
}

- (void)testParameterFactoryAndExtensionKeyAreTheirDeclaredValues
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	NSObject *factory = [NSObject new];
	dictionary[kFxParameterProperty_Factory] = factory;
	dictionary[kFxParameterProperty_ExtensionKey] = @"ext";

	XCTAssertTrue((id)dictionary.parameterFactory == factory);
	XCTAssertEqualObjects(dictionary.parameterExtensionKey, @"ext");
}

- (void)testParameterClassNameIsTheDeclaredString
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_ClassName, @"FxGripFloatParameter");

	XCTAssertEqualObjects(dictionary.parameterClassName, @"FxGripFloatParameter");
}

- (void)testParameterClassNameIsNilWhenTheDeclarationIsNotAString
{
	XCTAssertNil(FxGripParameterDictionaryWith(kFxParameterProperty_ClassName, @42).parameterClassName);
	XCTAssertNil(FxGripParameterDictionary().parameterClassName);
}

#pragma mark - Parameter Type

- (void)testParameterTypeResolvesANumberDeclaration
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Type, @(FxParameterType_Toggle));

	XCTAssertEqual(dictionary.parameterType, FxParameterType_Toggle);
}

- (void)testParameterTypeResolvesAStringDeclaration
{
	XCTAssertEqual(FxGripParameterDictionary().parameterType, FxParameterType_Float);
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Type, kFxParameterType_Menu).parameterType, FxParameterType_Menu);
}

- (void)testParameterTypeIsNoneWhenTheDeclarationIsNeitherANumberNorAString
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Type, @[ @1 ]).parameterType, FxParameterType_None);
}

#pragma mark - Parameter Flags

- (void)testParameterFlagsDefaultsToNoFlags
{
	XCTAssertEqual(FxGripParameterDictionary().parameterFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
}

- (void)testParameterFlagsResolvesAStringDeclaration
{
	NSString *declaration = [NSString stringWithFormat:@"%@ %@", kParameterFlagString_HIDDEN, kParameterFlagString_DISABLED];
	FxParameterFlags expected = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN] |
								[FxGripParameterUtility convertFlag:kParameterFlagString_DISABLED];

	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, declaration).parameterFlags, expected);
}

- (void)testParameterFlagsResolvesAnArrayDeclaration
{
	NSArray *declaration = @[ kParameterFlagString_COLLAPSED ];

	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, declaration).parameterFlags,
				   [FxGripParameterUtility convertFlag:kParameterFlagString_COLLAPSED]);
}

- (void)testParameterFlagsResolvesADictionaryDeclarationFromItsValues
{
	NSDictionary *declaration = @{ @"a": kParameterFlagString_HIDDEN };

	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, declaration).parameterFlags,
				   [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN]);
}

- (void)testParameterFlagsPassesANumberDeclarationThrough
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, @(6)).parameterFlags, (FxParameterFlags)6);
}

#pragma mark - Parameter Flags Array

- (void)testParameterFlagsArrayIsEmptyWhenNoFlagsAreDeclared
{
	XCTAssertEqualObjects(FxGripParameterDictionary().parameterFlagsArray, @[]);
}

- (void)testParameterFlagsArraySplitsAStringDeclaration
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Flags, @"hidden disabled");

	XCTAssertEqualObjects(dictionary.parameterFlagsArray, (@[ @"hidden", @"disabled" ]));
}

- (void)testParameterFlagsArrayPassesAnArrayDeclarationThrough
{
	NSArray *declaration = @[ kParameterFlagString_HIDDEN ];

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, declaration).parameterFlagsArray, declaration);
}

- (void)testParameterFlagsArrayTakesADictionaryDeclarationsValues
{
	NSDictionary *declaration = @{ @"a": kParameterFlagString_HIDDEN };

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_Flags, declaration).parameterFlagsArray,
						  (@[ kParameterFlagString_HIDDEN ]));
}

- (void)testParameterFlagsArrayExpandsANumberDeclarationIntoNames
{
	FxParameterFlags hidden = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN];
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Flags, @(hidden));

	XCTAssertEqualObjects(dictionary.parameterFlagsArray, (@[ kParameterFlagString_HIDDEN ]));
}

#pragma mark - Parameter Tags, Meta, and Custom Classes

- (void)testParameterTagsSplitsAStringDeclaration
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Tags, @"alpha,beta");

	XCTAssertEqualObjects(dictionary.parameterTags, (@[ @"alpha", @"beta" ]));
}

- (void)testParameterTagsPassesAnArrayDeclarationThrough
{
	NSArray *tags = @[ @"alpha", @"beta" ];

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_Tags, tags).parameterTags, tags);
}

- (void)testParameterTagsIsNilWhenNoneAreDeclared
{
	XCTAssertNil(FxGripParameterDictionary().parameterTags);
}

- (void)testParameterMetaIsTheDeclaredDictionary
{
	NSDictionary *meta = @{ @"note": @"value" };

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_Meta, meta).parameterMeta, meta);
	XCTAssertNil(FxGripParameterDictionary().parameterMeta);
}

- (void)testParameterCustomClassIsTheDeclaredString
{
	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_CustomClass, @"MyView").parameterCustomClass, @"MyView");
	XCTAssertNil(FxGripParameterDictionary().parameterCustomClass);
}

- (void)testParameterCustomClassesIsAnEmptySetWhenNoneAreDeclared
{
	XCTAssertEqualObjects(FxGripParameterDictionary().parameterCustomClasses, [NSSet set]);
}

- (void)testParameterCustomClassesSplitsAStringDeclaration
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_CustomClasses, @"One,Two");

	XCTAssertEqualObjects(dictionary.parameterCustomClasses, ([NSSet setWithArray:(@[ @"One", @"Two" ])]));
}

- (void)testParameterCustomClassesConvertsAnArrayDeclarationToASet
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_CustomClasses, (@[ @"One", @"Two", @"One" ]));

	XCTAssertEqualObjects(dictionary.parameterCustomClasses, ([NSSet setWithArray:(@[ @"One", @"Two" ])]));
}

- (void)testParameterCustomClassesPassesASetDeclarationThrough
{
	NSSet *classes = [NSSet setWithObject:@"One"];

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_CustomClasses, classes).parameterCustomClasses, classes);
}

#pragma mark - Parameter Values

- (void)testParameterDefaultAndResetValuesAreTheirDeclarations
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_Default] = @1.5;
	dictionary[kFxParameterProperty_ResetValue] = @0.0;

	XCTAssertEqualObjects(dictionary.parameterDefaultValue, @1.5);
	XCTAssertEqualObjects(dictionary.parameterResetValue, @0.0);
}

- (void)testParameterTargetPresetIsItsDeclaration
{
	NSDictionary *preset = @{ kFxParameterProperty_TargetPresetNames: @{} };

	XCTAssertEqualObjects(FxGripParameterDictionaryWith(kFxParameterProperty_TargetPreset, preset).parameterTargetPreset, preset);
	XCTAssertNil(FxGripParameterDictionary().parameterTargetPreset);
}

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

- (void)testParameterMinimumIntAndDoubleReadTheMinimumKey
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Minimum, @(3.75));

	XCTAssertEqual(dictionary.parameterMinimumInt, 3);
	XCTAssertEqual(dictionary.parameterMinimumDouble, 3.75);
}

- (void)testParameterMinimumIntAndDoubleCoerceAStringDeclaration
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Minimum, @"-2.5");

	XCTAssertEqual(dictionary.parameterMinimumInt, -2);
	XCTAssertEqual(dictionary.parameterMinimumDouble, -2.5);
}

- (void)testParameterMinimumIntAndDoubleAreZeroWhenNoMinimumIsDeclared
{
	XCTAssertEqual(FxGripParameterDictionary().parameterMinimumInt, 0);
	XCTAssertEqual(FxGripParameterDictionary().parameterMinimumDouble, 0.0);
}

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

- (void)testParameterMaximumSliderBoundsAndDeltaAreNilWhenNotDeclared
{
	NSDictionary *dictionary = FxGripParameterDictionary();

	XCTAssertNil(dictionary.parameterMaximum);
	XCTAssertNil(dictionary.parameterSliderMinimum);
	XCTAssertNil(dictionary.parameterSliderMaximum);
	XCTAssertNil(dictionary.parameterDelta);
}

#pragma mark - Parameter Default Coordinates

- (void)testParameterDefaultCoordinatesUseTheExplicitXAndYKeys
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_X] = @0.25;
	dictionary[kFxParameterProperty_Y] = @0.75;

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @0.25);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @0.75);
}

- (void)testParameterDefaultCoordinatesCoerceExplicitStringKeys
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_X] = @"0.25";
	dictionary[kFxParameterProperty_Y] = @"0.75";

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @0.25);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @0.75);
}

- (void)testParameterDefaultCoordinatesReadADictionaryDefault
{
	NSDictionary *value = @{ kFxParameterProperty_X: @1.0, kFxParameterProperty_Y: @2.0 };
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Default, value);

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @1.0);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @2.0);
}

- (void)testParameterDefaultCoordinatesReadAnArrayDefaultPositionally
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Default, (@[ @3.0, @4.0 ]));

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @3.0);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @4.0);
}

- (void)testParameterDefaultYIsZeroWhenTheArrayDefaultHasOnlyOneEntry
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Default, (@[ @3.0 ]));

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @3.0);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @0.0);
}

- (void)testParameterDefaultCoordinatesSplitAWhitespaceSeparatedStringDefault
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_Default, @"1.5 -2.5");

	XCTAssertEqualObjects(dictionary.parameterDefaultX, @1.5);
	XCTAssertEqualObjects(dictionary.parameterDefaultY, @(-2.5));
}

- (void)testParameterDefaultCoordinatesAreZeroWhenNothingIsDeclared
{
	XCTAssertEqualObjects(FxGripParameterDictionary().parameterDefaultX, @0.0);
	XCTAssertEqualObjects(FxGripParameterDictionary().parameterDefaultY, @0.0);
}

#pragma mark - Parameter Menu Items

- (void)testParameterMenuItemsAreTheirDeclaration
{
	NSArray *items = @[ @"One", @"Two" ];
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_Type] = kFxParameterType_Menu;
	dictionary[kFxParameterProperty_MenuItems] = items;

	XCTAssertEqualObjects(dictionary.parameterMenuItems, items);
}

- (void)testParameterMenuItemsAreEmptyForAMenuOrCapsuleWithoutADeclaration
{
	NSDictionary *menu = FxGripParameterDictionaryWith(kFxParameterProperty_Type, kFxParameterType_Menu);
	NSDictionary *capsule = FxGripParameterDictionaryWith(kFxParameterProperty_Type, kFxParameterType_Capsule);

	XCTAssertEqualObjects(menu.parameterMenuItems, @[]);
	XCTAssertEqualObjects(capsule.parameterMenuItems, @[]);
}

- (void)testParameterMenuItemsAreNilForAnotherTypeWithoutADeclaration
{
	XCTAssertNil(FxGripParameterDictionary().parameterMenuItems);
}

#pragma mark - Gradient Depth Type

- (void)testParameterGradientDepthTypeIsNoneWhenNotDeclared
{
	XCTAssertEqual(FxGripParameterDictionary().parameterGradientDepthType, FxGripDepthTypeNone);
}

- (void)testParameterGradientDepthTypeResolvesANumberDeclaration
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @0).parameterGradientDepthType, FxGripDepthTypeNone);
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @1).parameterGradientDepthType, FxGripDepthTypeFxDepth);
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @2).parameterGradientDepthType, FxGripDepthTypeBytes);
}

- (void)testParameterGradientDepthTypeClampsANumberDeclarationAboveTheRange
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @(3)).parameterGradientDepthType, FxGripDepthTypeFxDepth);
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @(9)).parameterGradientDepthType, FxGripDepthTypeFxDepth);
}

- (void)testParameterGradientDepthTypeClampsANegativeNumberDeclarationToNone
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @(-1)).parameterGradientDepthType, FxGripDepthTypeNone);
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @(-3)).parameterGradientDepthType, FxGripDepthTypeNone);
}

- (void)testParameterGradientDepthTypeResolvesAStringDeclaration
{
	NSDictionary *bytes = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, kFxParameterProperty_GradientDepthType_Bytes);
	NSDictionary *fxDepth = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, kFxParameterProperty_GradientDepthType_FxDepth);
	NSDictionary *other = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @"unrecognized");

	XCTAssertEqual(bytes.parameterGradientDepthType, FxGripDepthTypeBytes);
	XCTAssertEqual(fxDepth.parameterGradientDepthType, FxGripDepthTypeFxDepth);
	XCTAssertEqual(other.parameterGradientDepthType, FxGripDepthTypeFxDepth);
}

- (void)testParameterGradientDepthTypeIsNoneWhenTheDeclarationIsNeitherANumberNorAString
{
	XCTAssertEqual(FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepthType, @[]).parameterGradientDepthType, FxGripDepthTypeNone);
}

#pragma mark - Gradient Depth

- (void)testParameterGradientDepthDefaultsToHalfPrecision
{
	XCTAssertEqual((FxDepth)FxGripParameterDictionary().parameterGradientDepth, (FxDepth)kFxDepth_FLOAT16);
}

- (void)testParameterGradientDepthPassesANumberThroughWhenNoDepthTypeIsDeclared
{
	NSDictionary *dictionary = FxGripParameterDictionaryWith(kFxParameterProperty_GradientDepth, @(kFxDepth_FLOAT32));

	XCTAssertEqual((FxDepth)dictionary.parameterGradientDepth, (FxDepth)kFxDepth_FLOAT32);
}

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

- (void)testParameterGradientDepthLeavesAnUnrecognizedByteCountAlone
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_GradientDepthType] = kFxParameterProperty_GradientDepthType_Bytes;
	dictionary[kFxParameterProperty_GradientDepth] = @3;

	XCTAssertEqual((FxDepth)dictionary.parameterGradientDepth, (FxDepth)3);
}

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

- (void)testParameterGradientDepthIgnoresAByteDepthTypeForANamedDepth
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	dictionary[kFxParameterProperty_GradientDepthType] = kFxParameterProperty_GradientDepthType_Bytes;
	dictionary[kFxParameterProperty_GradientDepth] = kFxParameterProperty_GradientDepth_UInt8;

	XCTAssertEqual((FxDepth)dictionary.parameterGradientDepth, (FxDepth)kFxDepth_UINT8);
}

#pragma mark - NSMutableDictionary Setters

- (void)testSetParameterTypeWritesTheTypeKeyAndReadsBack
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();

	dictionary.parameterType = FxParameterType_Toggle;

	XCTAssertEqualObjects(dictionary[kFxParameterProperty_Type], @(FxParameterType_Toggle));
	XCTAssertEqual(dictionary.parameterType, FxParameterType_Toggle);
}

- (void)testSetParameterIdWritesTheIdKeyAndReadsBack
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();

	dictionary.parameterID = 33;

	XCTAssertEqualObjects(dictionary[kFxParameterProperty_Id], @(33));
	XCTAssertEqual(dictionary.parameterID, (FxParameterId)33);
}

- (void)testSetParameterParentIdWritesTheParentKeyAndReadsBack
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();

	dictionary.parameterParentID = 5;

	XCTAssertEqualObjects(dictionary[kFxParameterProperty_ParentId], @(5));
	XCTAssertEqual(dictionary.parameterParentID, (FxParameterId)5);
}

- (void)testSetParameterFlagsWritesTheFlagsKeyAndReadsBack
{
	NSMutableDictionary *dictionary = FxGripParameterDictionary();
	FxParameterFlags hidden = [FxGripParameterUtility convertFlag:kParameterFlagString_HIDDEN];

	dictionary.parameterFlags = hidden;

	XCTAssertEqualObjects(dictionary[kFxParameterProperty_Flags], @(hidden));
	XCTAssertEqual(dictionary.parameterFlags, hidden);
}

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

- (void)testTheRawMinimumAccessorMatchesItsDeclaration
{
	NSDictionary *parameter = FxGripParameterDictionaryWith(kFxParameterProperty_Minimum, @(3.5));
	NSDictionary *other = @{ kFxParameterProperty_Minimum: @(3.5) };

	XCTAssertEqualObjects(parameter.parameterMinimum_Raw, @(3.5));
	XCTAssertNil(other.parameterMinimum_Raw, @"the parameter guard rejects a non-parameter dictionary");
}

@end
