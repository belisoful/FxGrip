//
//  FxGripTypesTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxPlug/FxTypes.h>
#import "FxGrip/FxGripTypes.h"


@interface FxGripTypesTests : XCTestCase
@end

@implementation FxGripTypesTests

#pragma mark - Reserved Parameter IDs

- (void)testInstanceMetaParameterIdIsNineThousandNineHundredNinetyFive
{
	XCTAssertEqual(kFxParameterId_InstanceMeta, 9995);
}

- (void)testReservedParameterIdsHaveTheirDocumentedValues
{
	XCTAssertEqual(kFxParameterId_InstanceMeta, 9995);
	XCTAssertEqual(kFxParameterId_DebugActivator, 9996);
	XCTAssertEqual(kFxParameterId_DebugMenu, 9997);
	XCTAssertEqual(kFxParameterId_ParameterData, 9998);
	XCTAssertEqual(kFxParameterId_ApplePluginData, 9999);
}

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

- (void)testMetaRootPropertyKeys
{
	XCTAssertEqualObjects(kFxMetaProperty_Tags, @"tags");
	XCTAssertEqualObjects(kFxMetaProperty_Parameters, @"parameters");
}

- (void)testMetaRecordPropertyKeys
{
	XCTAssertEqualObjects(kFxMetaProperty_ParamId, @"id");
	XCTAssertEqualObjects(kFxMetaProperty_ParamTags, @"tags");
	XCTAssertEqualObjects(kFxMetaProperty_ParamMeta, @"meta");
}

- (void)testMetaRecordKeysAliasTheParameterPropertyKeys
{
	XCTAssertEqualObjects(kFxMetaProperty_ParamId, kFxParameterProperty_Id);
	XCTAssertEqualObjects(kFxMetaProperty_ParamTags, kFxParameterProperty_Tags);
	XCTAssertEqualObjects(kFxMetaProperty_ParamMeta, kFxParameterProperty_Meta);
}

#pragma mark - Target Preset Section Keys

- (void)testTargetPresetMetaSectionKeyIsMeta
{
	XCTAssertEqualObjects(kFxParameterProperty_TargetPresetMeta, @"meta");
}

- (void)testTargetPresetMetaSectionKeyAliasesTheParameterMetaKey
{
	XCTAssertEqualObjects(kFxParameterProperty_TargetPresetMeta, kFxParameterProperty_Meta);
}

#pragma mark - FxGripPresetOptions

- (void)testPresetOptionAllIsEveryBit
{
	XCTAssertEqual(FxGripPresetAll, NSUIntegerMax);
}

- (void)testPresetOptionBitsAreDistinctPowersOfTwo
{
	XCTAssertEqual(FxGripPresetNames, (NSUInteger)(1 << 0));
	XCTAssertEqual(FxGripPresetFlags, (NSUInteger)(1 << 1));
	XCTAssertEqual(FxGripPresetTags, (NSUInteger)(1 << 2));
	XCTAssertEqual(FxGripPresetValues, (NSUInteger)(1 << 3));
	XCTAssertEqual(FxGripPresetMeta, (NSUInteger)(1 << 4));
}

- (void)testPresetOptionMetaIsTheFifthBit
{
	XCTAssertEqual(FxGripPresetMeta, (NSUInteger)(1 << 4));
}

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

- (void)testPresetOptionAllContainsEveryNamedOption
{
	FxGripPresetOptions named = FxGripPresetNames | FxGripPresetFlags | FxGripPresetTags |
								FxGripPresetValues | FxGripPresetMeta;
	XCTAssertEqual(FxGripPresetAll & named, named);
}

- (void)testPresetOptionAllContainsMeta
{
	XCTAssertEqual(FxGripPresetAll & FxGripPresetMeta, (FxGripPresetOptions)FxGripPresetMeta);
}

#pragma mark - FxGripPresetSource

- (void)testPresetSourcePluginIsZero
{
	XCTAssertEqual(FxGripPresetSourcePlugin, (FxGripPresetSource)0);
}

- (void)testPresetSourceFileDiffersFromPlugin
{
	XCTAssertNotEqual(FxGripPresetSourceFile, FxGripPresetSourcePlugin);
}

#pragma mark - FxPlug Error Base

- (void)testThirdPartyDeveloperErrorBase
{
	XCTAssertEqual(kFxError_ThirdPartyDeveloperStart, 100000);
}

@end
