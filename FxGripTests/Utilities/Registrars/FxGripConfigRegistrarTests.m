/*!
	@file       FxGripConfigRegistrarTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripConfigRegistrarTests
	@abstract   Unit tests for FxGripConfigRegistrar's Info.plist plugin and group lists.
	@discussion Introduced in FxGrip 0.1.0. The registrar reads ProPlugPlugInList and
	            ProPlugPlugInGroupList from the main bundle. The tests stage those keys on the main
	            bundle and verify the accessors return the staged lists, report an absent list
	            through the error argument, and feed the base registrar's registration pipeline.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripConfigRegistrar.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import "FxGripMainBundleTestSupport.h"

#define kConfigGroupUUID	@"B1B1B1B1-0000-4000-8000-00000000C0F1"
#define kConfigPluginUUID	@"B2B2B2B2-0000-4000-8000-00000000C0F2"

@interface FxGripConfigRegistrarTests : XCTestCase
@end

@implementation FxGripConfigRegistrarTests

- (void)tearDown
{
	[FxGripMainBundleTestSupport clearStagedValues];
	[super tearDown];
}

- (NSDictionary *)stagedPlugin
{
	return @{
		kProPlugPlugIn_UuidProperty: kConfigPluginUUID,
		kProPlugPlugIn_ClassNameProperty: NSStringFromClass(FxGripConfigRegistrarTests.class),
		kProPlugPlugIn_DisplayNameProperty: @"Config Plugin",
		kProPlugPlugIn_GroupUUIDProperty: kConfigGroupUUID,
		kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxFilter],
		kProPlugPlugIn_InfoStringProperty: @"",
		kProPlugPlugIn_VersionProperty: @1000
	};
}

- (NSDictionary *)stagedGroup
{
	return @{
		kProPlugPlugInX_RegGroupUUIDProperty: kConfigGroupUUID,
		kProPlugPlugInX_RegGroupNameProperty: @"Config Group"
	};
}

/*! @abstract The registrar is a static registrar. */
- (void)testConfigRegistrarIsAStaticRegistrar
{
	XCTAssertTrue([FxGripConfigRegistrar isSubclassOfClass:FxGripStaticRegistrar.class]);
}

/*! @abstract plugInGroupsWithError: returns nil and sets kFxGripError_NoConfigGroups when the bundle has no group list. */
- (void)testPlugInGroupsReportsAnAbsentList
{
	FxGripConfigRegistrar *registrar = [[FxGripConfigRegistrar alloc] init];
	NSError *error = nil;

	NSArray *groups = [registrar plugInGroupsWithError:&error];

	XCTAssertNil(groups);
	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, kFxGripError_NoConfigGroups);
}

/*! @abstract plugInsWithError: returns nil and sets kFxGripError_NoConfigPlugins when the bundle has no plugin list. */
- (void)testPlugInsReportsAnAbsentList
{
	FxGripConfigRegistrar *registrar = [[FxGripConfigRegistrar alloc] init];
	NSError *error = nil;

	NSArray *plugins = [registrar plugInsWithError:&error];

	XCTAssertNil(plugins);
	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, kFxGripError_NoConfigPlugins);
}

/*! @abstract plugInGroupsWithError: returns the staged group list with no error. */
- (void)testPlugInGroupsReturnsTheBundleList
{
	[FxGripMainBundleTestSupport stageInfoDictionary:@{ kProPlugPlugIn_GroupList_Property: @[[self stagedGroup]] }];
	FxGripConfigRegistrar *registrar = [[FxGripConfigRegistrar alloc] init];
	NSError *error = nil;

	NSArray *groups = [registrar plugInGroupsWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqualObjects(groups, @[[self stagedGroup]]);
}

/*! @abstract plugInsWithError: returns the staged plugin list with no error. */
- (void)testPlugInsReturnsTheBundleList
{
	[FxGripMainBundleTestSupport stageInfoDictionary:@{ kProPlugPlugInList_Property: @[[self stagedPlugin]] }];
	FxGripConfigRegistrar *registrar = [[FxGripConfigRegistrar alloc] init];
	NSError *error = nil;

	NSArray *plugins = [registrar plugInsWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqualObjects(plugins, @[[self stagedPlugin]]);
}

/*! @abstract The base registrar registers the staged plugin and group lists through the config hooks. */
- (void)testRegistrationPipelineRegistersTheBundleLists
{
	[FxGripMainBundleTestSupport stageInfoDictionary:@{
		kProPlugPlugInList_Property: @[[self stagedPlugin]],
		kProPlugPlugIn_GroupList_Property: @[[self stagedGroup]]
	}];
	FxGripConfigRegistrar *registrar = [[FxGripConfigRegistrar alloc] init];
	NSError *error = nil;

	NSArray *plugins = [registrar registeredPlugInsWithError:&error];
	XCTAssertNil(error);
	XCTAssertEqual(plugins.count, 1u);
	XCTAssertEqualObjects(plugins.firstObject[kProPlugPlugIn_UuidProperty], kConfigPluginUUID);

	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];
	XCTAssertNil(error);
	XCTAssertEqualObjects(groups, @[[self stagedGroup]]);
}

/*! @abstract With plugins staged but no group list, the base registrar reports kFxGripError_NoConfigGroups. */
- (void)testRegistrationWithoutAGroupListReportsNoGroups
{
	[FxGripMainBundleTestSupport stageInfoDictionary:@{ kProPlugPlugInList_Property: @[[self stagedPlugin]] }];
	FxGripConfigRegistrar *registrar = [[FxGripConfigRegistrar alloc] init];
	NSError *error = nil;

	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];

	XCTAssertNil(groups);
	XCTAssertEqual(error.code, kFxGripError_NoConfigGroups);
}

@end
