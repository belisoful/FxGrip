/*!
	@file       FxGripClassRegistrarTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripClassRegistrarTests
	@abstract   Unit tests for FxGripClassRegistrar's Info.plist class references.
	@discussion Introduced in FxGrip 0.1.0. The registrar reads FxGripRegisteredPlugins from the
	            main bundle and hands the value to the base registrar as plugin class references.
	            The tests stage the key on the main bundle and verify the reference read and the
	            registration of the named class.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripClassRegistrar.h>
#import <FxGrip/FxGripRegisteredPlugin.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import "FxGripMainBundleTestSupport.h"

#define kClassRegistrarPluginUUID	@"C1C1C1C1-0000-4000-8000-00000000C1A1"
#define kClassRegistrarGroupUUID	@"C2C2C2C2-0000-4000-8000-00000000C1A2"

@interface FxGripClassRegistrarTestPlugin : NSObject <FxGripRegisteredPlugin>
@end

@implementation FxGripClassRegistrarTestPlugin

+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups>)groupRegistrar
{
	return @{
		kProPlugPlugIn_UuidProperty: kClassRegistrarPluginUUID,
		kProPlugPlugIn_ClassNameProperty: NSStringFromClass(self),
		kProPlugPlugIn_DisplayNameProperty: @"Class Registrar Plugin",
		kProPlugPlugIn_GroupUUIDProperty: kClassRegistrarGroupUUID,
		kProPlugPlugInX_RegGroupNameProperty: @"Class Registrar Group",
		kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxFilter],
		kProPlugPlugIn_InfoStringProperty: @"",
		kProPlugPlugIn_VersionProperty: @1000
	};
}

@end


@interface FxGripClassRegistrarTests : XCTestCase
@end

@implementation FxGripClassRegistrarTests

- (void)tearDown
{
	[FxGripMainBundleTestSupport clearStagedValues];
	[super tearDown];
}

/*! @abstract The registrar is a static registrar. */
- (void)testClassRegistrarIsAStaticRegistrar
{
	XCTAssertTrue([FxGripClassRegistrar isSubclassOfClass:FxGripStaticRegistrar.class]);
}

/*! @abstract plugInReferences is nil when the bundle declares no FxGripRegisteredPlugins key. */
- (void)testPlugInReferencesIsNilWhenTheKeyIsAbsent
{
	FxGripClassRegistrar *registrar = [[FxGripClassRegistrar alloc] init];

	XCTAssertNil([registrar plugInReferences]);
}

/*! @abstract plugInReferences returns the bundle's FxGripRegisteredPlugins value unchanged. */
- (void)testPlugInReferencesReturnsTheBundleValue
{
	NSArray *references = @[NSStringFromClass(FxGripClassRegistrarTestPlugin.class)];
	[FxGripMainBundleTestSupport stageInfoDictionary:@{ kProPlugPlugInX_FxRegisteredPlugins_Property: references }];
	FxGripClassRegistrar *registrar = [[FxGripClassRegistrar alloc] init];

	XCTAssertEqualObjects([registrar plugInReferences], references);
}

/*! @abstract A class named in the bundle registers with its plugin record and its carried group. */
- (void)testRegistrationRegistersTheNamedClass
{
	[FxGripMainBundleTestSupport stageInfoDictionary:@{
		kProPlugPlugInX_FxRegisteredPlugins_Property: NSStringFromClass(FxGripClassRegistrarTestPlugin.class)
	}];
	FxGripClassRegistrar *registrar = [[FxGripClassRegistrar alloc] init];
	NSError *error = nil;

	NSArray *plugins = [registrar registeredPlugInsWithError:&error];
	XCTAssertNil(error);
	XCTAssertEqual(plugins.count, 1u);
	XCTAssertEqualObjects(plugins.firstObject[kProPlugPlugIn_UuidProperty], kClassRegistrarPluginUUID);
	XCTAssertNil(plugins.firstObject[kProPlugPlugInX_RegGroupNameProperty]);

	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];
	XCTAssertNil(error);
	XCTAssertEqual(groups.count, 1u);
	XCTAssertEqualObjects(groups.firstObject[kProPlugPlugInX_RegGroupUUIDProperty], kClassRegistrarGroupUUID);
	XCTAssertEqualObjects(groups.firstObject[kProPlugPlugInX_RegGroupNameProperty], @"Class Registrar Group");
}

/*! @abstract A bundle value naming no loaded class registers nothing and reports no plugins. */
- (void)testRegistrationWithAnUnknownClassNameRegistersNothing
{
	[FxGripMainBundleTestSupport stageInfoDictionary:@{
		kProPlugPlugInX_FxRegisteredPlugins_Property: @"FxGripClassRegistrarNoSuchPlugin"
	}];
	FxGripClassRegistrar *registrar = [[FxGripClassRegistrar alloc] init];
	NSError *error = nil;

	XCTAssertNil([registrar registeredPlugInsWithError:&error]);
	XCTAssertEqual(error.code, kFxGripError_NoConfigPlugins);
}

@end
