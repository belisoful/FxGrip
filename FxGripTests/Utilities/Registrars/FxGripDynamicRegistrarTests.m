//
//  FxGripDynamicRegistrarTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import "FxGrip/FxGripStaticRegistrar.h"
#import "FxGrip/FxGripDynamicRegistrar.h"
#import "FxGrip/FxGripPluginGroupData.h"
#import "FxGrip/FxGripRegisteredPlugin.h"
#import <FxPlug/FxTypes.h>
#import <FxGrip/FxGripTypes.h>

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


#pragma mark - Tests

@interface FxGripDynamicRegistrarTests : XCTestCase
@end

@implementation FxGripDynamicRegistrarTests

#pragma mark registerGroup:

- (void)testRegisterGroup_WellFormedDictionary_RegistersGroup {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSString *uuid = NSUUID.UUID.UUIDString;

	[registrar registerGroup:@{
		kProPlugPlugInX_RegGroupUUIDProperty: uuid,
		kProPlugPlugInX_RegGroupNameProperty: @"Well Formed Group"
	}];

	XCTAssertTrue([registrar containsGroupUUID:uuid]);
}

- (void)testRegisterGroup_NilInput_DoesNotCrashOrRegister {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];

	XCTAssertNoThrow([registrar registerGroup:nil]);
	XCTAssertFalse([registrar containsGroupUUID:NSUUID.UUID.UUIDString]);
}

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

- (void)testRegisterGroup_FxPluginGroupDataInstance_RegistersGroup {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSString *uuid = NSUUID.UUID.UUIDString;
	FxGripPluginGroupData *groupData = [FxGripPluginGroupData.alloc initWithGroupUUID:uuid groupName:@"Object Group"];

	[registrar registerGroup:groupData];

	XCTAssertTrue([registrar containsGroupUUID:uuid]);
}

#pragma mark registerPluginClass:

- (void)testRegisterPluginClass_ValidClass_RegistersAndReturnsYes {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];

	BOOL success = [registrar registerPluginClass:FxGripDynamicRegistrarValidTestPlugin.class];

	XCTAssertTrue(success);
	XCTAssertTrue([registrar containsPluginUUID:kDynPlugin1UUID]);
}

- (void)testRegisterPluginClass_NonConformingClass_ReturnsNoWithoutCrash {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];

	BOOL success = YES;
	XCTAssertNoThrow(success = [registrar registerPluginClass:NSObject.class]);
	XCTAssertFalse(success);
}

- (void)testRegisterPluginClass_NilClass_ReturnsNoWithoutCrash {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	Class degenerateClass = Nil;

	BOOL success = YES;
	XCTAssertNoThrow(success = [registrar registerPluginClass:degenerateClass]);
	XCTAssertFalse(success);
}

- (void)testRegisterPluginClass_DisabledPlugin_ReturnsNo {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];

	BOOL success = [registrar registerPluginClass:FxGripDynamicRegistrarDisabledTestPlugin.class];

	XCTAssertFalse(success);
}

- (void)testRegisterPluginClass_IncompleteInformation_ReturnsYesButDoesNotStore {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];

	// -registerPluginClass: reports success once the class supplies non-nil information;
	// actual storage still requires -registerPlugin: to accept all required fields.
	BOOL success = [registrar registerPluginClass:FxGripDynamicRegistrarIncompleteTestPlugin.class];

	XCTAssertTrue(success);
	XCTAssertFalse([registrar containsPluginUUID:kDynPlugin2UUID]);
}

#pragma mark globalRegisteredPluginClasses

- (void)testGlobalRegisteredPluginClasses_ReturnsConformingClasses {
	NSArray<Class> *classes = nil;
	XCTAssertNoThrow(classes = [FxGripDynamicRegistrar globalRegisteredPluginClasses]);

	XCTAssertNotNil(classes);
	XCTAssertTrue([classes containsObject:FxGripDynamicRegistrarValidTestPlugin.class]);
	XCTAssertTrue([classes containsObject:FxGripDynamicRegistrarDisabledTestPlugin.class]);
	XCTAssertFalse([classes containsObject:NSObject.class]);
}

- (void)testGlobalRegisteredPluginClasses_IncludesSubclassOfConformingClass {
	NSArray<Class> *classes = [FxGripDynamicRegistrar globalRegisteredPluginClasses];

	XCTAssertTrue([classes containsObject:FxGripDynamicRegistrarSubclassTestPlugin.class]);
}

#pragma mark plugInsWithError:

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

- (void)testPlugInGroupsWithError_ReturnsWithoutCrashing {
	FxGripDynamicRegistrar *registrar = [FxGripDynamicRegistrar.alloc init];
	NSError *error = nil;

	XCTAssertNoThrow([registrar plugInGroupsWithError:&error]);
}

@end
