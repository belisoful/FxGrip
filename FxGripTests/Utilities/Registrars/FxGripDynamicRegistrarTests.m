/*!
	@file       FxGripDynamicRegistrarTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDynamicRegistrarTests
	@abstract   Unit tests for FxGripDynamicRegistrar group and plugin registration.
	@discussion Introduced in FxGrip 0.1.0. The tests verify that the dynamic registrar registers groups and plugin classes from well-formed input, rejects malformed or non-conforming input without crashing, and discovers conforming plugin classes across the superclass chain.
*/

#import <XCTest/XCTest.h>
#import "FxGrip/FxGripStaticRegistrar.h"
#import "FxGrip/FxGripDynamicRegistrar.h"
#import "FxGrip/FxGripPluginGroupData.h"
#import "FxGrip/FxGripRegisteredPlugin.h"
#import <FxPlug/FxTypes.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import "FxGripMainBundleTestSupport.h"

#define kDynPlugin1UUID		@"1B7B6A20-4C3D-4E2F-8A1B-2C3D4E5F6001"
#define kDynPlugin1Group	@"7A6E6E30-9E1B-4B34-9C34-9A2E6B1F001A"

#define kDynPlugin2UUID		@"2B7B6A20-4C3D-4E2F-8A1B-2C3D4E5F6002"


#pragma mark - Test Plugin Classes

@interface FxGripDynamicRegistrarValidTestPlugin : NSObject <FxGripRegisteredPlugin>
@end
@implementation FxGripDynamicRegistrarValidTestPlugin
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups>)groupRegistrar
{
	return @{
		kProPlugPlugIn_UuidProperty: kDynPlugin1UUID,
		kProPlugPlugIn_ClassNameProperty: NSStringFromClass(self),
		kProPlugPlugIn_DisplayNameProperty: @"Valid Test Plugin",
		kProPlugPlugIn_GroupUUIDProperty: kDynPlugin1Group,
		kProPlugPlugIn_ProtocolNamesProperty: @[],
		kProPlugPlugIn_InfoStringProperty: @"",
		kProPlugPlugIn_VersionProperty: @1000
	};
}
@end


@interface FxGripDynamicRegistrarIncompleteTestPlugin : NSObject <FxGripRegisteredPlugin>
@end
@implementation FxGripDynamicRegistrarIncompleteTestPlugin
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups>)groupRegistrar
{
	// Missing kProPlugPlugIn_VersionProperty, so -registerPlugin: cannot store it even
	// though this method itself returns non-nil information.
	return @{
		kProPlugPlugIn_UuidProperty: kDynPlugin2UUID,
		kProPlugPlugIn_ClassNameProperty: NSStringFromClass(self),
		kProPlugPlugIn_DisplayNameProperty: @"Incomplete Test Plugin",
		kProPlugPlugIn_GroupUUIDProperty: kDynPlugin1Group,
		kProPlugPlugIn_ProtocolNamesProperty: @[]
	};
}
@end


@interface FxGripDynamicRegistrarDisabledTestPlugin : NSObject <FxGripRegisteredPlugin>
@end
@implementation FxGripDynamicRegistrarDisabledTestPlugin
+ (BOOL)isRegisteredPlugIn
{
	return NO;
}
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups>)groupRegistrar
{
	return @{};
}
@end


// Conforms only through its superclass; exercises the superclass-chain walk in
// +globalRegisteredPluginClasses.
@interface FxGripDynamicRegistrarSubclassTestPlugin : FxGripDynamicRegistrarValidTestPlugin
@end
@implementation FxGripDynamicRegistrarSubclassTestPlugin
@end

#define kDynNamedGroupPluginUUID		@"3B7B6A20-4C3D-4E2F-8A1B-2C3D4E5F6003"
#define kDynNamedGroupUUID				@"7A6E6E30-9E1B-4B34-9C34-9A2E6B1F003A"
#define kDynClassGroupPluginUUID		@"4B7B6A20-4C3D-4E2F-8A1B-2C3D4E5F6004"
#define kDynClassGroupUUID				@"7A6E6E30-9E1B-4B34-9C34-9A2E6B1F004A"
#define kDynBundleGroupPluginUUID		@"5B7B6A20-4C3D-4E2F-8A1B-2C3D4E5F6005"
#define kDynBundleGroupUUID				@"7A6E6E30-9E1B-4B34-9C34-9A2E6B1F005A"
#define kDynThrowingGroupPluginUUID		@"6B7B6A20-4C3D-4E2F-8A1B-2C3D4E5F6006"
#define kDynThrowingGroupUUID			@"7A6E6E30-9E1B-4B34-9C34-9A2E6B1F006A"

static NSDictionary *FxGripDynamicTestPluginInfo(Class cls, NSString *uuid, NSString *groupUUID)
{
	return @{
		kProPlugPlugIn_UuidProperty: uuid,
		kProPlugPlugIn_ClassNameProperty: NSStringFromClass(cls),
		kProPlugPlugIn_DisplayNameProperty: NSStringFromClass(cls),
		kProPlugPlugIn_GroupUUIDProperty: groupUUID,
		kProPlugPlugIn_ProtocolNamesProperty: @[],
		kProPlugPlugIn_InfoStringProperty: @"",
		kProPlugPlugIn_VersionProperty: @1000
	};
}

// Names its group through +groupNameForUUID:.
@interface FxGripDynamicRegistrarNamedGroupTestPlugin : NSObject <FxGripRegisteredPlugin>
@end
@implementation FxGripDynamicRegistrarNamedGroupTestPlugin
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups>)groupRegistrar
{
	return FxGripDynamicTestPluginInfo(self, kDynNamedGroupPluginUUID, kDynNamedGroupUUID);
}
+ (NSString *)groupNameForUUID:(NSString *)groupUUID
{
	return [groupUUID isEqualToString:kDynNamedGroupUUID] ? @"Named Group" : nil;
}
@end

// Answers nil from +groupNameForUUID: so the name falls back to +groupName.
@interface FxGripDynamicRegistrarClassGroupTestPlugin : NSObject <FxGripRegisteredPlugin>
@end
@implementation FxGripDynamicRegistrarClassGroupTestPlugin
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups>)groupRegistrar
{
	return FxGripDynamicTestPluginInfo(self, kDynClassGroupPluginUUID, kDynClassGroupUUID);
}
+ (NSString *)groupNameForUUID:(NSString *)groupUUID
{
	return nil;
}
+ (NSString *)groupName
{
	return @"Class Group";
}
@end

// Names no group, so the name comes from the host bundle's group list or a placeholder.
@interface FxGripDynamicRegistrarBundleGroupTestPlugin : NSObject <FxGripRegisteredPlugin>
@end
@implementation FxGripDynamicRegistrarBundleGroupTestPlugin
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups>)groupRegistrar
{
	return FxGripDynamicTestPluginInfo(self, kDynBundleGroupPluginUUID, kDynBundleGroupUUID);
}
@end

// Raises from +groupNameForUUID: while the test arms it; otherwise names its group.
static BOOL gFxGripDynamicRegistrarThrowOnGroupName = NO;
@interface FxGripDynamicRegistrarThrowingGroupTestPlugin : NSObject <FxGripRegisteredPlugin>
@end
@implementation FxGripDynamicRegistrarThrowingGroupTestPlugin
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups>)groupRegistrar
{
	return FxGripDynamicTestPluginInfo(self, kDynThrowingGroupPluginUUID, kDynThrowingGroupUUID);
}
+ (NSString *)groupNameForUUID:(NSString *)groupUUID
{
	if (gFxGripDynamicRegistrarThrowOnGroupName) {
		[NSException raise:NSInternalInconsistencyException format:@"group name unavailable"];
	}
	return @"Throwing Group";
}
@end

// Registered only while the test arms it, and raises from its information call.
static BOOL gFxGripDynamicRegistrarThrowOnInformation = NO;
@interface FxGripDynamicRegistrarThrowingInfoTestPlugin : NSObject <FxGripRegisteredPlugin>
@end
@implementation FxGripDynamicRegistrarThrowingInfoTestPlugin
+ (BOOL)isRegisteredPlugIn
{
	return gFxGripDynamicRegistrarThrowOnInformation;
}
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups>)groupRegistrar
{
	[NSException raise:NSInternalInconsistencyException format:@"information unavailable"];
	return @{};
}
@end



#pragma mark - Tests

@interface FxGripDynamicRegistrarTests : XCTestCase
@end

@implementation FxGripDynamicRegistrarTests

- (void)tearDown
{
	[FxGripMainBundleTestSupport clearStagedValues];
	[super tearDown];
}

#pragma mark registerGroup:

/*! @abstract A well-formed group dictionary registers, and the registrar then reports containing its UUID. */
- (void)testRegisterGroup_WellFormedDictionary_RegistersGroup {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSString *uuid = NSUUID.UUID.UUIDString;

	[registrar registerGroup:@{
		kProPlugPlugInX_RegGroupUUIDProperty: uuid,
		kProPlugPlugInX_RegGroupNameProperty: @"Well Formed Group"
	}];

	XCTAssertTrue([registrar containsGroupUUID:uuid]);
}

/*! @abstract A nil group argument neither throws nor registers any group. */
- (void)testRegisterGroup_NilInput_DoesNotCrashOrRegister {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];

	XCTAssertNoThrow([registrar registerGroup:nil]);
	XCTAssertFalse([registrar containsGroupUUID:NSUUID.UUID.UUIDString]);
}

/*! @abstract Wrong-typed group input is ignored without throwing, and a well-formed group still registers afterward. */
- (void)testRegisterGroup_WrongTypeInput_DoesNotCrashOrRegister {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];

	XCTAssertNoThrow([registrar registerGroup:@"not a group"]);
	XCTAssertNoThrow([registrar registerGroup:@42]);
	XCTAssertNoThrow([registrar registerGroup:@[@"still not a group"]]);

	// Wrong-typed input must not corrupt the registrar; a well-formed group still
	// registers afterward.
	NSString *uuid = NSUUID.UUID.UUIDString;
	[registrar registerGroup:@{
		kProPlugPlugInX_RegGroupUUIDProperty: uuid,
		kProPlugPlugInX_RegGroupNameProperty: @"Recovery Group"
	}];
	XCTAssertTrue([registrar containsGroupUUID:uuid]);
}

/*! @abstract A FxGripPluginGroupData instance passed to -registerGroup: registers under its group UUID. */
- (void)testRegisterGroup_FxPluginGroupDataInstance_RegistersGroup {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSString *uuid = NSUUID.UUID.UUIDString;
	FxGripPluginGroupData *groupData = [FxGripPluginGroupData.alloc initWithGroupUUID:uuid groupName:@"Object Group"];

	[registrar registerGroup:groupData];

	XCTAssertTrue([registrar containsGroupUUID:uuid]);
}

#pragma mark registerPluginClass:

/*! @abstract A conforming plugin class with complete information registers and returns YES. */
- (void)testRegisterPluginClass_ValidClass_RegistersAndReturnsYes {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];

	BOOL success = [registrar registerPluginClass:FxGripDynamicRegistrarValidTestPlugin.class];

	XCTAssertTrue(success);
	XCTAssertTrue([registrar containsPluginUUID:kDynPlugin1UUID]);
}

/*! @abstract A class that does not conform to the plugin protocol returns NO without throwing. */
- (void)testRegisterPluginClass_NonConformingClass_ReturnsNoWithoutCrash {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];

	BOOL success = YES;
	XCTAssertNoThrow(success = [registrar registerPluginClass:NSObject.class]);
	XCTAssertFalse(success);
}

/*! @abstract A Nil class argument returns NO without throwing. */
- (void)testRegisterPluginClass_NilClass_ReturnsNoWithoutCrash {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	Class degenerateClass = Nil;

	BOOL success = YES;
	XCTAssertNoThrow(success = [registrar registerPluginClass:degenerateClass]);
	XCTAssertFalse(success);
}

/*! @abstract A class that reports +isRegisteredPlugIn as NO is not registered and returns NO. */
- (void)testRegisterPluginClass_DisabledPlugin_ReturnsNo {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];

	BOOL success = [registrar registerPluginClass:FxGripDynamicRegistrarDisabledTestPlugin.class];

	XCTAssertFalse(success);
}

/*! @abstract A class returning non-nil but incomplete information returns YES yet the plugin is not stored, because the missing version field fails the registration pipeline. */
- (void)testRegisterPluginClass_IncompleteInformation_ReturnsYesButDoesNotStore {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];

	// -registerPluginClass: reports success once the class supplies non-nil information;
	// actual storage still requires -registerPlugin: to accept all required fields.
	BOOL success = [registrar registerPluginClass:FxGripDynamicRegistrarIncompleteTestPlugin.class];

	XCTAssertTrue(success);
	XCTAssertFalse([registrar containsPluginUUID:kDynPlugin2UUID]);
}

#pragma mark globalRegisteredPluginClasses

/*! @abstract +globalRegisteredPluginClasses returns the conforming plugin classes and excludes NSObject. */
- (void)testGlobalRegisteredPluginClasses_ReturnsConformingClasses {
	NSArray<Class> *classes = nil;
	XCTAssertNoThrow(classes = [FxGripDynamicRegistrar globalRegisteredPluginClasses]);

	XCTAssertNotNil(classes);
	XCTAssertTrue([classes containsObject:FxGripDynamicRegistrarValidTestPlugin.class]);
	XCTAssertTrue([classes containsObject:FxGripDynamicRegistrarDisabledTestPlugin.class]);
	XCTAssertFalse([classes containsObject:NSObject.class]);
}

/*! @abstract +globalRegisteredPluginClasses includes a subclass that conforms only through its superclass. */
- (void)testGlobalRegisteredPluginClasses_IncludesSubclassOfConformingClass {
	NSArray<Class> *classes = [FxGripDynamicRegistrar globalRegisteredPluginClasses];

	XCTAssertTrue([classes containsObject:FxGripDynamicRegistrarSubclassTestPlugin.class]);
}

#pragma mark plugInsWithError:

/*! @abstract -plugInsWithError: registers the discovered conforming classes as a side effect, returns nil, and sets no error. */
- (void)testPlugInsWithError_RegistersConformingClassesWithoutCrashing {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSError *error = nil;

	NSArray *result = nil;
	XCTAssertNoThrow(result = [registrar plugInsWithError:&error]);

	// Registers the discovered plugin classes as a side effect and returns nil.
	XCTAssertNil(result);
	XCTAssertNil(error);
	XCTAssertTrue([registrar containsPluginUUID:kDynPlugin1UUID]);
}

#pragma mark plugInGroupsWithError:

/*! @abstract -plugInGroupsWithError: returns without throwing. */
- (void)testPlugInGroupsWithError_ReturnsWithoutCrashing {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSError *error = nil;

	XCTAssertNoThrow([registrar plugInGroupsWithError:&error]);
}


#pragma mark Group name resolution

- (NSDictionary *)group:(NSString *)uuid inArray:(NSArray<NSDictionary *> *)groups
{
	for (NSDictionary *group in groups) {
		if ([group[kProPlugPlugInX_RegGroupUUIDProperty] isEqualToString:uuid]) {
			return group;
		}
	}
	return nil;
}

/*! @abstract A group named by the plugin class through +groupNameForUUID: registers under that name. */
- (void)testRegisteredPlugInGroups_NamesAGroupThroughGroupNameForUUID {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSError *error = nil;

	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqualObjects([self group:kDynNamedGroupUUID inArray:groups][kProPlugPlugInX_RegGroupNameProperty], @"Named Group");
}

/*! @abstract A group whose class answers nil from +groupNameForUUID: falls back to +groupName. */
- (void)testRegisteredPlugInGroups_FallsBackToGroupName {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSError *error = nil;

	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqualObjects([self group:kDynClassGroupUUID inArray:groups][kProPlugPlugInX_RegGroupNameProperty], @"Class Group");
}

/*! @abstract A group no class names takes its name from the host bundle's group list. */
- (void)testRegisteredPlugInGroups_FillsANameFromTheBundleGroupList {
	[FxGripMainBundleTestSupport stageInfoDictionary:@{ kProPlugPlugIn_GroupList_Property: @[
		@"not a group",
		@{ kProPlugPlugInX_RegGroupUUIDProperty: @"7A6E6E30-9E1B-4B34-9C34-9A2E6B1F00FF", kProPlugPlugInX_RegGroupNameProperty: @"Unreferenced" },
		@{ kProPlugPlugInX_RegGroupUUIDProperty: kDynBundleGroupUUID, kProPlugPlugInX_RegGroupNameProperty: @"Bundle Group" }
	] }];
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSError *error = nil;

	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqualObjects([self group:kDynBundleGroupUUID inArray:groups][kProPlugPlugInX_RegGroupNameProperty], @"Bundle Group");
	XCTAssertNil([self group:@"7A6E6E30-9E1B-4B34-9C34-9A2E6B1F00FF" inArray:groups]);
}

/*! @abstract A bundle group list given as a dictionary contributes its values. */
- (void)testRegisteredPlugInGroups_AcceptsADictionaryBundleGroupList {
	[FxGripMainBundleTestSupport stageInfoDictionary:@{ kProPlugPlugIn_GroupList_Property: @{
		@"entry": @{ kProPlugPlugInX_RegGroupUUIDProperty: kDynBundleGroupUUID, kProPlugPlugInX_RegGroupNameProperty: @"Dictionary Group" }
	} }];
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSError *error = nil;

	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqualObjects([self group:kDynBundleGroupUUID inArray:groups][kProPlugPlugInX_RegGroupNameProperty], @"Dictionary Group");
}

/*! @abstract A group no class or bundle names registers under a numbered placeholder. */
- (void)testRegisteredPlugInGroups_LabelsAnUnnamedGroupWithAPlaceholder {
	[FxGripMainBundleTestSupport stageInfoDictionary:@{ kProPlugPlugIn_GroupList_Property: NSNull.null }];
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSError *error = nil;

	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];

	XCTAssertNil(error);
	NSString *name = [self group:kDynBundleGroupUUID inArray:groups][kProPlugPlugInX_RegGroupNameProperty];
	XCTAssertTrue([name hasPrefix:@"Unlabelled Group "], @"%@", name);
}

/*! @abstract Every group a registered plugin references is registered exactly once. */
- (void)testRegisteredPlugInGroups_CoversEveryReferencedGroupOnce {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSError *error = nil;

	NSArray *plugins = [registrar registeredPlugInsWithError:&error];
	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];

	NSSet *referenced = [NSSet setWithArray:[plugins valueForKey:kProPlugPlugIn_GroupUUIDProperty]];
	NSArray *registered = [groups valueForKey:kProPlugPlugInX_RegGroupUUIDProperty];
	XCTAssertEqualObjects([NSSet setWithArray:registered], referenced);
	XCTAssertEqual(registered.count, referenced.count);
}

/*! @abstract An exception raised while naming a group is caught and reported as kFxGripError_Exception. */
- (void)testPlugInGroupsWithError_ReportsAnExceptionWhileNamingGroups {
	gFxGripDynamicRegistrarThrowOnGroupName = YES;
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSError *error = nil;

	NSArray *result = nil;
	XCTAssertNoThrow(result = [registrar plugInGroupsWithError:&error]);
	gFxGripDynamicRegistrarThrowOnGroupName = NO;

	XCTAssertNil(result);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, kFxGripError_Exception);
	XCTAssertTrue([error.localizedDescription containsString:@"group name unavailable"]);
}

/*! @abstract An exception raised by a plugin's information call is caught and reported as kFxGripError_Exception. */
- (void)testPlugInsWithError_ReportsAnExceptionWhileRegistering {
	gFxGripDynamicRegistrarThrowOnInformation = YES;
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSError *error = nil;

	NSArray *result = nil;
	XCTAssertNoThrow(result = [registrar plugInsWithError:&error]);
	gFxGripDynamicRegistrarThrowOnInformation = NO;

	XCTAssertNil(result);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, kFxGripError_Exception);
	XCTAssertTrue([error.localizedDescription containsString:@"information unavailable"]);
}


@end
