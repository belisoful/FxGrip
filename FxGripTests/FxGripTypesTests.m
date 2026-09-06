/*!
	@file       FxGripTypesTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTypesTests
	@abstract   Verifies the constant values FxGripTypes.h publishes.
	@discussion Introduced in FxGrip 0.1.0. The tests pin the reserved parameter identifiers, the meta property keys and their aliases to the parameter property keys, the FxGripPresetOptions bit layout, the FxGripPresetSource cases, and the third-party developer error base.
*/

#import <XCTest/XCTest.h>
#import <FxPlug/FxTypes.h>
#import "FxGrip/FxGripTypes.h"


@interface FxGripTypesTests : XCTestCase
@end

@implementation FxGripTypesTests

#pragma mark - Reserved Parameter IDs

/*! @abstract The instance-meta reserved parameter identifier equals 9995. */
- (void)testInstanceMetaParameterIdIsNineThousandNineHundredNinetyFive
{
	XCTAssertEqual(kFxParameterId_InstanceMeta, 9995);
}

/*! @abstract Each reserved parameter identifier holds its documented value from 9995 through 9999. */
- (void)testReservedParameterIdsHaveTheirDocumentedValues
{
	XCTAssertEqual(kFxParameterId_InstanceMeta, 9995);
	XCTAssertEqual(kFxParameterId_DebugActivator, 9996);
	XCTAssertEqual(kFxParameterId_DebugMenu, 9997);
	XCTAssertEqual(kFxParameterId_ParameterData, 9998);
	XCTAssertEqual(kFxParameterId_ApplePluginData, 9999);
}

/*! @abstract The five reserved parameter identifiers are distinct from one another. */
- (void)testReservedParameterIdsAreUnique
{
	NSArray<NSNumber*> *ids = @[
		@(kFxParameterId_InstanceMeta),
		@(kFxParameterId_DebugActivator),
		@(kFxParameterId_DebugMenu),
		@(kFxParameterId_ParameterData),
		@(kFxParameterId_ApplePluginData)
	];
	NSSet<NSNumber*> *unique = [NSSet setWithArray:ids];
	XCTAssertEqual(unique.count, ids.count);
}

#pragma mark - Meta Property Keys

/*! @abstract The root meta property keys equal "tags" and "parameters". */
- (void)testMetaRootPropertyKeys
{
	XCTAssertEqualObjects(kFxMetaProperty_Tags, @"tags");
	XCTAssertEqualObjects(kFxMetaProperty_Parameters, @"parameters");
}

/*! @abstract The per-record meta property keys equal "id", "tags", and "meta". */
- (void)testMetaRecordPropertyKeys
{
	XCTAssertEqualObjects(kFxMetaProperty_ParamId, @"id");
	XCTAssertEqualObjects(kFxMetaProperty_ParamTags, @"tags");
	XCTAssertEqualObjects(kFxMetaProperty_ParamMeta, @"meta");
}

/*! @abstract The meta record keys carry the same string values as the parameter property keys. */
- (void)testMetaRecordKeysAliasTheParameterPropertyKeys
{
	XCTAssertEqualObjects(kFxMetaProperty_ParamId, kFxParameterProperty_Id);
	XCTAssertEqualObjects(kFxMetaProperty_ParamTags, kFxParameterProperty_Tags);
	XCTAssertEqualObjects(kFxMetaProperty_ParamMeta, kFxParameterProperty_Meta);
}

#pragma mark - Target Preset Section Keys

/*! @abstract The target-preset meta section key equals "meta". */
- (void)testTargetPresetMetaSectionKeyIsMeta
{
	XCTAssertEqualObjects(kFxParameterProperty_TargetPresetMeta, @"meta");
}

/*! @abstract The target-preset meta section key carries the same value as the parameter meta key. */
- (void)testTargetPresetMetaSectionKeyAliasesTheParameterMetaKey
{
	XCTAssertEqualObjects(kFxParameterProperty_TargetPresetMeta, kFxParameterProperty_Meta);
}

#pragma mark - FxGripPresetOptions

/*! @abstract The FxGripPresetAll option equals NSUIntegerMax. */
- (void)testPresetOptionAllIsEveryBit
{
	XCTAssertEqual(FxGripPresetAll, NSUIntegerMax);
}

/*! @abstract The named preset options occupy bits 0 through 4 in order. */
- (void)testPresetOptionBitsAreDistinctPowersOfTwo
{
	XCTAssertEqual(FxGripPresetNames, (NSUInteger)(1 << 0));
	XCTAssertEqual(FxGripPresetFlags, (NSUInteger)(1 << 1));
	XCTAssertEqual(FxGripPresetTags, (NSUInteger)(1 << 2));
	XCTAssertEqual(FxGripPresetValues, (NSUInteger)(1 << 3));
	XCTAssertEqual(FxGripPresetMeta, (NSUInteger)(1 << 4));
}

/*! @abstract The meta preset option occupies bit 4. */
- (void)testPresetOptionMetaIsTheFifthBit
{
	XCTAssertEqual(FxGripPresetMeta, (NSUInteger)(1 << 4));
}

/*! @abstract Each named preset option is a single set bit, and all five are distinct. */
- (void)testEveryPresetOptionBitIsADistinctSingleBit
{
	NSArray<NSNumber*> *bits = @[
		@(FxGripPresetNames),
		@(FxGripPresetFlags),
		@(FxGripPresetTags),
		@(FxGripPresetValues),
		@(FxGripPresetMeta)
	];

	for (NSNumber *bit in bits) {
		NSUInteger value = bit.unsignedIntegerValue;
		XCTAssertNotEqual(value, (NSUInteger)0);
		XCTAssertEqual(value & (value - 1), (NSUInteger)0, @"%@ is a single bit", bit);
	}

	XCTAssertEqual([NSSet setWithArray:bits].count, bits.count);
}

/*! @abstract FxGripPresetAll includes every named preset option bit. */
- (void)testPresetOptionAllContainsEveryNamedOption
{
	FxGripPresetOptions named = FxGripPresetNames | FxGripPresetFlags | FxGripPresetTags |
								FxGripPresetValues | FxGripPresetMeta;
	XCTAssertEqual(FxGripPresetAll & named, named);
}

/*! @abstract FxGripPresetAll includes the meta option bit. */
- (void)testPresetOptionAllContainsMeta
{
	XCTAssertEqual(FxGripPresetAll & FxGripPresetMeta, (FxGripPresetOptions)FxGripPresetMeta);
}

#pragma mark - FxGripPresetSource

/*! @abstract The plugin preset source equals zero. */
- (void)testPresetSourcePluginIsZero
{
	XCTAssertEqual(FxGripPresetSourcePlugin, (FxGripPresetSource)0);
}

/*! @abstract The file preset source differs from the plugin preset source. */
- (void)testPresetSourceFileDiffersFromPlugin
{
	XCTAssertNotEqual(FxGripPresetSourceFile, FxGripPresetSourcePlugin);
}

#pragma mark - FxPlug Error Base

/*! @abstract The third-party developer error base equals 100000. */
- (void)testThirdPartyDeveloperErrorBase
{
	XCTAssertEqual(kFxError_ThirdPartyDeveloperStart, 100000);
}

@end
