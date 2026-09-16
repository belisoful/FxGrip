/*!
	@file       FxGripStaticRegistrarTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripStaticRegistrarTests
	@abstract   Unit tests for FxGripStaticRegistrar protocol conformance, plugin validation, and OSC linking.
	@discussion Introduced in FxGrip 0.1.0. The tests verify the registrar's declared protocol conformance, its baseline error behavior with no registered content, the validation the registration pipeline applies to plugin dictionaries, and the on-screen-control linking that moves a consumer's OSC directive into the OSC plugin's supportedPlugins list.
*/

#import <XCTest/XCTest.h>
#import "FxGrip/FxGripStaticRegistrar.h"
#import <FxPlug/FxTypes.h>
#import <FxGrip/FxGripTypes.h>
#import "FxGrip/FxGripRegisteredPlugin.h"
#import "FxGrip/FxGripPluginGroupData.h"

#define kGroup1UUID	@"56962728-AB95-42C5-95D0-6308A002746A"
#define kGroup1Name	@"Group 1 Name"
#define kGroup2UUID	@"5CC3C425-16E4-4BBD-B321-447A3C6A2DE6"
#define kGroup2Name	@"Group 2 Name"


#define kPlugin1UUID		@"9CF67DCA-CBDA-418C-9B4C-3A3599E4AADD"
#define kPlugin1ClassName	@"Plugin1Class"

#define kPlugin2UUID		@"C38DB915-C100-4327-81D2-E422FDF20682"
#define kPlugin2ClassName	@"Plugin2Class"

#define kOSCPluginUUID		@"A1111111-0000-4000-8000-000000000001"
#define kConsumerAUUID		@"A2222222-0000-4000-8000-000000000002"
#define kConsumerBUUID		@"A3333333-0000-4000-8000-000000000003"

@interface StaticRegistrarPropertiesClass : FxGripStaticRegistrar
@end
@implementation StaticRegistrarPropertiesClass
- (NSArray<NSDictionary<NSString*, NSString*> *>*)registeredPlugInGroups
{
	return @[
			@{
				kProPlugPlugInX_RegGroupUUIDProperty: kGroup1UUID,
				kProPlugPlugInX_RegGroupNameProperty: kGroup1Name
			},
			@{
				kProPlugPlugInX_RegGroupUUIDProperty: kGroup2UUID,
				kProPlugPlugInX_RegGroupNameProperty: kGroup2Name
			}
		];
}
- (NSArray<NSDictionary<NSString*, id> *>*)registeredPlugIns
{
	return @[
			@{
				kProPlugPlugIn_UuidProperty: kPlugin1UUID,
				kProPlugPlugIn_ClassNameProperty: @"Plugin1Class",
				kProPlugPlugIn_DisplayNameProperty: @"",
				kProPlugPlugIn_GroupUUIDProperty: kGroup1UUID,
				kProPlugPlugIn_ProtocolNamesProperty: @[],
				kProPlugPlugIn_InfoStringProperty: @"",
				kProPlugPlugIn_VersionProperty: @1
			},
			@{
				kProPlugPlugInX_RegGroupUUIDProperty: kPlugin2UUID,
				kProPlugPlugIn_ClassNameProperty: @"Plugin2Class",
				kProPlugPlugIn_DisplayNameProperty: @"",
				kProPlugPlugIn_GroupUUIDProperty: kGroup2UUID,
				kProPlugPlugIn_ProtocolNamesProperty: @[],
				kProPlugPlugIn_InfoStringProperty: @"",
				kProPlugPlugIn_VersionProperty: @1
			}
		];
}
@end

@interface StaticRegistrarTestClass : FxGripStaticRegistrar
@end
@implementation StaticRegistrarTestClass
@end

#define kRefPluginAUUID		@"D1D1D1D1-0000-4000-8000-0000000000A1"
#define kRefPluginBUUID		@"D2D2D2D2-0000-4000-8000-0000000000B2"
#define kHookPluginUUID		@"D3D3D3D3-0000-4000-8000-0000000000C3"

#define kStaticRegistrarHookErrorCode	4242

@interface StaticRegistrarRefPluginA : NSObject <FxGripRegisteredPlugin>
@end
@implementation StaticRegistrarRefPluginA
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups>)groupRegistrar
{
	return @{
		kProPlugPlugIn_UuidProperty: kRefPluginAUUID,
		kProPlugPlugIn_ClassNameProperty: NSStringFromClass(self),
		kProPlugPlugIn_DisplayNameProperty: @"Reference Plugin A",
		kProPlugPlugIn_GroupUUIDProperty: kGroup1UUID,
		kProPlugPlugIn_ProtocolNamesProperty: @[],
		kProPlugPlugIn_InfoStringProperty: @"",
		kProPlugPlugIn_VersionProperty: @1000
	};
}
+ (NSString *)groupName
{
	return kGroup1Name;
}
@end

@interface StaticRegistrarRefPluginB : NSObject <FxGripRegisteredPlugin>
@end
@implementation StaticRegistrarRefPluginB
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups>)groupRegistrar
{
	return @{
		kProPlugPlugInList_Property: @[@{
			kProPlugPlugIn_UuidProperty: kRefPluginBUUID,
			kProPlugPlugIn_ClassNameProperty: NSStringFromClass(self),
			kProPlugPlugIn_DisplayNameProperty: @"Reference Plugin B",
			kProPlugPlugIn_GroupUUIDProperty: kGroup2UUID,
			kProPlugPlugIn_ProtocolNamesProperty: @[],
			kProPlugPlugIn_InfoStringProperty: @"",
			kProPlugPlugIn_VersionProperty: @1000
		}],
		kProPlugPlugIn_GroupList_Property: @{
			kProPlugPlugInX_RegGroupUUIDProperty: kGroup2UUID,
			kProPlugPlugInX_RegGroupNameProperty: kGroup2Name
		}
	};
}
@end

/*! A registrar whose hooks supply one plugin and one group. */
@interface StaticRegistrarHooksSubclass : FxGripStaticRegistrar
+ (NSDictionary *)hookPlugin;
+ (NSDictionary *)hookGroup;
@end
@implementation StaticRegistrarHooksSubclass
+ (NSDictionary *)hookPlugin
{
	return @{
		kProPlugPlugIn_UuidProperty: kHookPluginUUID,
		kProPlugPlugIn_ClassNameProperty: NSStringFromClass(StaticRegistrarTestClass.class),
		kProPlugPlugIn_DisplayNameProperty: @"Hook Plugin",
		kProPlugPlugIn_GroupUUIDProperty: kGroup1UUID,
		kProPlugPlugIn_ProtocolNamesProperty: @[],
		kProPlugPlugIn_InfoStringProperty: @"",
		kProPlugPlugIn_VersionProperty: @1000
	};
}
+ (NSDictionary *)hookGroup
{
	return @{kProPlugPlugInX_RegGroupUUIDProperty: kGroup1UUID,
			 kProPlugPlugInX_RegGroupNameProperty: kGroup1Name};
}
- (NSArray *)plugInsWithError:(NSError **)error
{
	return @[self.class.hookPlugin];
}
- (NSArray *)plugInGroupsWithError:(NSError **)error
{
	return @[self.class.hookGroup];
}
@end

/*! A registrar whose group hook reports an error. */
@interface StaticRegistrarGroupErrorSubclass : StaticRegistrarHooksSubclass
@end
@implementation StaticRegistrarGroupErrorSubclass
- (NSArray *)plugInGroupsWithError:(NSError **)error
{
	*error = [NSError errorWithDomain:FxGripPlugErrorDomain code:kStaticRegistrarHookErrorCode userInfo:nil];
	return nil;
}
@end

/*! A registrar whose plugin hook reports an error. */
@interface StaticRegistrarPluginErrorSubclass : FxGripStaticRegistrar
@end
@implementation StaticRegistrarPluginErrorSubclass
- (NSArray *)plugInsWithError:(NSError **)error
{
	*error = [NSError errorWithDomain:FxGripPlugErrorDomain code:kStaticRegistrarHookErrorCode userInfo:nil];
	return nil;
}
@end

/*! A registrar whose group hook returns a dictionary of groups. */
@interface StaticRegistrarGroupsDictionarySubclass : StaticRegistrarHooksSubclass
@end
@implementation StaticRegistrarGroupsDictionarySubclass
- (id)plugInGroupsWithError:(NSError **)error
{
	return @{ @"one": @{kProPlugPlugInX_RegGroupUUIDProperty: kGroup1UUID,
						kProPlugPlugInX_RegGroupNameProperty: kGroup1Name},
			  @"two": @{kProPlugPlugInX_RegGroupUUIDProperty: kGroup2UUID,
						kProPlugPlugInX_RegGroupNameProperty: kGroup2Name} };
}
@end

/*! A registrar whose plugInReferences answers whatever the test stages. */
@interface StaticRegistrarReferencesSubclass : FxGripStaticRegistrar
@property (class, nonatomic, strong, nullable) id references;
@end
@implementation StaticRegistrarReferencesSubclass
static id gStaticRegistrarReferences = nil;
+ (id)references
{
	return gStaticRegistrarReferences;
}
+ (void)setReferences:(id)references
{
	gStaticRegistrarReferences = references;
}
- (id)plugInReferences
{
	return self.class.references;
}
@end




@interface FxGripStaticRegistrarTests : XCTestCase

@end

@implementation FxGripStaticRegistrarTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

/*! @abstract FxGripStaticRegistrar conforms to PROPlugInRegistering and FxGripStaticRegistrarSubclass. */
- (void)testClassProtocols {
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(PROPlugInRegistering)]);
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(FxGripStaticRegistrarSubclass)]);
}

/*! @abstract FxGripStaticRegistrar conforms to the registering-groups and registering-plugins protocols in addition to the base registration protocols. */
- (void)testRegistrationProtocols {
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(PROPlugInRegistering)]);
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(FxGripStaticRegistrarSubclass)]);
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(FxGripRegisteringGroups)]);
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(FxGripRegisteringPlugins)]);
}


/*! @abstract A fresh registrar is loadable, loads the first instance without error, and reports nil registered groups and plugins. */
- (void)testInit {
	FxGripStaticRegistrar *staticRegistrar = [FxGripStaticRegistrar.alloc init];
	
	XCTAssertTrue(staticRegistrar.isLoadable);
	
	NSError *error = nil;
	XCTAssertTrue([staticRegistrar shouldLoadFirstInstanceOfPlugInWithError:&error]);
	XCTAssertNil(error);
	XCTAssertNil(staticRegistrar.registeredPlugInGroups);
	XCTAssertNil(staticRegistrar.registeredPlugIns);
}

/*! @abstract +sharedInstance returns an instance of FxGripStaticRegistrar. */
- (void)testSharedInstance
{
	FxGripStaticRegistrar *globalStaticRegistrar = [FxGripStaticRegistrar sharedInstance];
	XCTAssertTrue([globalStaticRegistrar isKindOfClass:FxGripStaticRegistrar.class]);
}


/*! @abstract A base registrar with no groups returns nil from -registeredPlugInGroupsWithError: and sets an error. */
- (void)testRegisteredPlugInGroupsWithError_Baseline {
	FxGripStaticRegistrar *staticRegistrar = [FxGripStaticRegistrar.alloc init];
	
	NSError *error = nil;
	XCTAssertNil([staticRegistrar registeredPlugInGroupsWithError:&error]);
	XCTAssertNotNil(error);
}

/*! @abstract A base registrar with no plugins returns nil from -registeredPlugInsWithError: and sets an error. */
- (void)testRegisteredPlugInsWithError_Baseline {
	FxGripStaticRegistrar *staticRegistrar = [FxGripStaticRegistrar.alloc init];
	
	NSError *error = nil;
	XCTAssertNil([staticRegistrar registeredPlugInsWithError:&error]);
	XCTAssertNotNil(error);
}



/*! @abstract A subclass overriding -registeredPlugInGroups returns exactly those group dictionaries. */
- (void)testRegisteredPlugInGroups_Property {
	FxGripStaticRegistrar *propertyRegistrar = [StaticRegistrarPropertiesClass.alloc init];
	
	NSArray *reference = @[
		@{
			   kProPlugPlugInX_RegGroupUUIDProperty: kGroup1UUID,
			   kProPlugPlugInX_RegGroupNameProperty: kGroup1Name
		   },
		   @{
			   kProPlugPlugInX_RegGroupUUIDProperty: kGroup2UUID,
			   kProPlugPlugInX_RegGroupNameProperty: kGroup2Name
		   }
	   ];
	XCTAssertEqualObjects(propertyRegistrar.registeredPlugInGroups, reference);
}

// The registeredPlugIns property is the processed result, not raw input: a subclass that
// supplies it is declaring the finished set, so it is returned as-is. Subclasses feeding
// unprocessed plugins use the plugInReferences / plugInsWithError: hooks, which run the
// registration pipeline (see testRegisterPlugin_* below).
/*! @abstract A subclass supplying -registeredPlugIns has that finished set returned unchanged and with no error. */
- (void)testRegisteredPlugIns_Property {
	FxGripStaticRegistrar *staticRegistrar = [StaticRegistrarPropertiesClass.alloc init];

	NSError *error = nil;
	NSArray *plugIns = [staticRegistrar registeredPlugInsWithError:&error];

	XCTAssertEqualObjects(plugIns, staticRegistrar.registeredPlugIns);
	XCTAssertNil(error);
}

#pragma mark registerPlugin: validation

/*! @abstract A plugin dictionary with all required fields and a loaded class registers and is reported by UUID. */
- (void)testRegisterPlugin_CompleteInformationWithLoadedClass_Registers {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	NSString *uuid = NSUUID.UUID.UUIDString;

	BOOL success = [registrar registerPlugin:@{
		kProPlugPlugIn_UuidProperty: uuid,
		kProPlugPlugIn_ClassNameProperty: NSStringFromClass(StaticRegistrarTestClass.class),
		kProPlugPlugIn_DisplayNameProperty: @"Loaded Plugin",
		kProPlugPlugIn_GroupUUIDProperty: kGroup1UUID,
		kProPlugPlugIn_ProtocolNamesProperty: @[],
		kProPlugPlugIn_InfoStringProperty: @"",
		kProPlugPlugIn_VersionProperty: @1000
	}];

	XCTAssertTrue(success);
	XCTAssertTrue([registrar containsPluginUUID:uuid]);
}

/*! @abstract A plugin naming a class that does not exist in the process is rejected despite complete fields. */
- (void)testRegisterPlugin_UnloadedClassName_IsRejected {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	NSString *uuid = NSUUID.UUID.UUIDString;

	// Every required field is present; only the class does not exist in the process.
	BOOL success = [registrar registerPlugin:@{
		kProPlugPlugIn_UuidProperty: uuid,
		kProPlugPlugIn_ClassNameProperty: @"FxGripNoSuchPluginClassExists",
		kProPlugPlugIn_DisplayNameProperty: @"Missing Class Plugin",
		kProPlugPlugIn_GroupUUIDProperty: kGroup1UUID,
		kProPlugPlugIn_ProtocolNamesProperty: @[],
		kProPlugPlugIn_InfoStringProperty: @"",
		kProPlugPlugIn_VersionProperty: @1000
	}];

	XCTAssertFalse(success);
	XCTAssertFalse([registrar containsPluginUUID:uuid]);
}

/*! @abstract A plugin missing the version field is rejected and not stored. */
- (void)testRegisterPlugin_MissingRequiredField_IsRejected {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	NSString *uuid = NSUUID.UUID.UUIDString;

	BOOL success = [registrar registerPlugin:@{
		kProPlugPlugIn_UuidProperty: uuid,
		kProPlugPlugIn_ClassNameProperty: NSStringFromClass(StaticRegistrarTestClass.class),
		kProPlugPlugIn_DisplayNameProperty: @"No Version Plugin",
		kProPlugPlugIn_GroupUUIDProperty: kGroup1UUID,
		kProPlugPlugIn_ProtocolNamesProperty: @[]
	}];

	XCTAssertFalse(success);
	XCTAssertFalse([registrar containsPluginUUID:uuid]);
}

// The dictionaries the properties subclass supplies are exactly the kind of unvalidated
// input the pipeline rejects: plugin 1 names an unloaded class, plugin 2 carries no
// plugin uuid.
/*! @abstract The properties subclass dictionaries are both rejected, one for an unloaded class and one for a missing plugin UUID. */
- (void)testRegisterPlugins_PropertyClassDictionaries_AreAllRejected {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	StaticRegistrarPropertiesClass *properties = [StaticRegistrarPropertiesClass.alloc init];

	[registrar registerPlugins:properties.registeredPlugIns];

	XCTAssertFalse([registrar containsPluginUUID:kPlugin1UUID]);
	XCTAssertFalse([registrar containsPluginUUID:kPlugin2UUID]);
}


/*! @abstract A base registrar with no groups returns nil and sets an error. */
- (void)testPlugInGroupsWithError_Baseline {
	FxGripStaticRegistrar *staticRegistrar = [FxGripStaticRegistrar.alloc init];
	
	NSError *error = nil;
	XCTAssertNil([staticRegistrar registeredPlugInGroupsWithError:&error]);
	XCTAssertNotNil(error);
}

/*! @abstract A base registrar with no plugins returns nil and sets an error. */
- (void)testPlugInsWithError_Baseline {
	FxGripStaticRegistrar *staticRegistrar = [FxGripStaticRegistrar.alloc init];
	
	NSError *error = nil;
	XCTAssertNil([staticRegistrar registeredPlugInsWithError:&error]);
	XCTAssertNotNil(error);
}


#pragma mark OSC linking

- (NSDictionary *)plugin:(NSString *)uuid inArray:(NSArray<NSDictionary *> *)plugins {
	for (NSDictionary *plugin in plugins) {
		if ([plugin[kProPlugPlugIn_UuidProperty] isEqualToString:uuid]) {
			return plugin;
		}
	}
	return nil;
}

- (NSDictionary *)validPluginUUID:(NSString *)uuid extra:(NSDictionary *)extra {
	NSMutableDictionary *plugin = [@{
		kProPlugPlugIn_UuidProperty: uuid,
		kProPlugPlugIn_ClassNameProperty: NSStringFromClass(StaticRegistrarTestClass.class),
		kProPlugPlugIn_DisplayNameProperty: @"",
		kProPlugPlugIn_GroupUUIDProperty: kGroup1UUID,
		kProPlugPlugIn_ProtocolNamesProperty: @[],
		kProPlugPlugIn_InfoStringProperty: @"",
		kProPlugPlugIn_VersionProperty: @1000
	} mutableCopy];
	[plugin addEntriesFromDictionary:extra];
	return plugin;
}

// An `osc` directive links a plugin to its on-screen-control plugin: registration strips the
// directive from the consumer and adds the consumer's uuid to the OSC's supportedPlugins.
/*! @abstract Registering a consumer with an OSC directive strips the directive and adds the consumer UUID to the OSC plugin's supportedPlugins. */
- (void)testRegisteredPlugIns_OSCConsumer_MovesToSupportedPlugins {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kOSCPluginUUID extra:@{}]]);
	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kConsumerAUUID
															  extra:@{kProPlugPlugInX_OSCUUIDsProperty: kOSCPluginUUID}]]);

	NSError *error = nil;
	NSArray *plugIns = [registrar registeredPlugInsWithError:&error];
	XCTAssertNil(error);

	NSDictionary *consumer = [self plugin:kConsumerAUUID inArray:plugIns];
	NSDictionary *osc = [self plugin:kOSCPluginUUID inArray:plugIns];

	XCTAssertNil(consumer[kProPlugPlugInX_OSCUUIDsProperty]);
	XCTAssertEqualObjects(osc[kProPlugPlugIn_SupportedPluginsProperty], @[kConsumerAUUID]);
}

// Two consumers naming the same OSC both accumulate; the OSC entry is upgraded to a mutable
// copy in place without corrupting either consumer's record.
/*! @abstract Two consumers naming the same OSC both accumulate in its supportedPlugins, and neither consumer retains the OSC directive. */
- (void)testRegisteredPlugIns_MultipleOSCConsumers_Accumulate {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kOSCPluginUUID extra:@{}]]);
	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kConsumerAUUID
															  extra:@{kProPlugPlugInX_OSCUUIDsProperty: kOSCPluginUUID}]]);
	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kConsumerBUUID
															  extra:@{kProPlugPlugInX_OSCUUIDsProperty: @[kOSCPluginUUID]}]]);

	NSError *error = nil;
	NSArray *plugIns = [registrar registeredPlugInsWithError:&error];
	XCTAssertNil(error);

	NSArray *supported = [self plugin:kOSCPluginUUID inArray:plugIns][kProPlugPlugIn_SupportedPluginsProperty];

	XCTAssertEqual(supported.count, 2);
	XCTAssertTrue([supported containsObject:kConsumerAUUID]);
	XCTAssertTrue([supported containsObject:kConsumerBUUID]);
	XCTAssertNil([self plugin:kConsumerAUUID inArray:plugIns][kProPlugPlugInX_OSCUUIDsProperty]);
	XCTAssertNil([self plugin:kConsumerBUUID inArray:plugIns][kProPlugPlugInX_OSCUUIDsProperty]);
}

// A dangling OSC reference is logged and skipped, leaving the consumer registered.
/*! @abstract An OSC directive naming an unregistered plugin is skipped without throwing, and the consumer stays registered without the directive. */
- (void)testRegisteredPlugIns_OSCReferenceToMissingPlugin_DoesNotCrash {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kConsumerAUUID
															  extra:@{kProPlugPlugInX_OSCUUIDsProperty: kOSCPluginUUID}]]);

	NSError *error = nil;
	NSArray *plugIns = nil;
	XCTAssertNoThrow(plugIns = [registrar registeredPlugInsWithError:&error]);
	XCTAssertNil(error);
	XCTAssertNil([self plugin:kConsumerAUUID inArray:plugIns][kProPlugPlugInX_OSCUUIDsProperty]);
}

/*! @abstract -registerGroupUUID:groupName: with a nil UUID or nil name registers nothing and does not throw. */
- (void)testRegisterGroupUUID_NilArguments_DoNotRegisterOrCrash {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	NSString *noGroupUUID = nil;
	NSString *noGroupName = nil;

	XCTAssertNoThrow([registrar registerGroupUUID:noGroupUUID groupName:kGroup1Name]);
	XCTAssertNoThrow([registrar registerGroupUUID:kGroup1UUID groupName:noGroupName]);
	XCTAssertNoThrow([registrar registerGroupUUID:noGroupUUID groupName:noGroupName]);

	XCTAssertFalse([registrar containsGroupUUID:kGroup1UUID]);
}


/*
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}
 */


#pragma mark Subclass hooks

/*! @abstract The deprecated requestedProtocolsWithError: returns nil and leaves the error untouched. */
- (void)testRequestedProtocolsWithError_ReturnsNil {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	NSError *error = nil;

	XCTAssertNil([registrar requestedProtocolsWithError:&error]);
	XCTAssertNil(error);
}

/*! @abstract A subclass supplying plugins and groups through the hooks has both registered, and the groups freeze after the first read. */
- (void)testRegisteredPlugInGroups_SubclassHooks_RegistersAndFreezesTheGroups {
	StaticRegistrarHooksSubclass *registrar = [StaticRegistrarHooksSubclass.alloc init];
	NSError *error = nil;

	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqualObjects(groups, @[[StaticRegistrarHooksSubclass hookGroup]]);
	XCTAssertTrue(groups == [registrar registeredPlugInGroupsWithError:&error]);
	XCTAssertTrue([registrar containsPluginUUID:kHookPluginUUID] == NO);
	XCTAssertFalse([registrar containsGroupUUID:kGroup1UUID]);

	[registrar registerGroupUUID:kGroup2UUID groupName:kGroup2Name];
	XCTAssertEqualObjects([registrar registeredPlugInGroupsWithError:&error], @[[StaticRegistrarHooksSubclass hookGroup]]);
}

/*! @abstract A group hook that reports an error yields nil groups and that error. */
- (void)testRegisteredPlugInGroups_GroupHookError_PropagatesTheError {
	StaticRegistrarGroupErrorSubclass *registrar = [StaticRegistrarGroupErrorSubclass.alloc init];
	NSError *error = nil;

	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];

	XCTAssertNil(groups);
	XCTAssertEqual(error.code, kStaticRegistrarHookErrorCode);
	XCTAssertTrue([registrar containsPluginUUID:kHookPluginUUID] == NO);
}

/*! @abstract A plugin hook that reports an error yields nil plugins and that error instead of the no-plugins error. */
- (void)testRegisteredPlugIns_PluginHookError_PropagatesTheError {
	StaticRegistrarPluginErrorSubclass *registrar = [StaticRegistrarPluginErrorSubclass.alloc init];
	NSError *error = nil;

	NSArray *plugins = [registrar registeredPlugInsWithError:&error];

	XCTAssertNil(plugins);
	XCTAssertEqual(error.code, kStaticRegistrarHookErrorCode);
}

/*! @abstract A group hook returning a dictionary of groups registers each value. */
- (void)testRegisteredPlugInGroups_DictionaryHook_RegistersEachValue {
	StaticRegistrarGroupsDictionarySubclass *registrar = [StaticRegistrarGroupsDictionarySubclass.alloc init];
	NSError *error = nil;

	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqual(groups.count, 2u);
	NSArray *uuids = [groups valueForKey:kProPlugPlugInX_RegGroupUUIDProperty];
	XCTAssertTrue([uuids containsObject:kGroup1UUID]);
	XCTAssertTrue([uuids containsObject:kGroup2UUID]);
}

#pragma mark plugInReferences

/*! @abstract A human-divided string of class names registers each named class. */
- (void)testRegisteredPlugIns_ReferencesString_RegistersEachNamedClass {
	StaticRegistrarReferencesSubclass.references = [NSString stringWithFormat:@"%@, %@",
		NSStringFromClass(StaticRegistrarRefPluginA.class), NSStringFromClass(StaticRegistrarRefPluginB.class)];
	StaticRegistrarReferencesSubclass *registrar = [StaticRegistrarReferencesSubclass.alloc init];
	NSError *error = nil;

	NSArray *plugins = [registrar registeredPlugInsWithError:&error];

	XCTAssertNil(error);
	XCTAssertNotNil([self plugin:kRefPluginAUUID inArray:plugins]);
	XCTAssertNotNil([self plugin:kRefPluginBUUID inArray:plugins]);
}

/*! @abstract A dictionary of class references registers its values. */
- (void)testRegisteredPlugIns_ReferencesDictionary_RegistersTheValues {
	StaticRegistrarReferencesSubclass.references = @{ @"first": StaticRegistrarRefPluginA.class };
	StaticRegistrarReferencesSubclass *registrar = [StaticRegistrarReferencesSubclass.alloc init];
	NSError *error = nil;

	NSArray *plugins = [registrar registeredPlugInsWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqual(plugins.count, 1u);
	XCTAssertNotNil([self plugin:kRefPluginAUUID inArray:plugins]);
}

/*! @abstract A single class reference registers that class. */
- (void)testRegisteredPlugIns_ReferencesSingleClass_RegistersTheClass {
	StaticRegistrarReferencesSubclass.references = StaticRegistrarRefPluginA.class;
	StaticRegistrarReferencesSubclass *registrar = [StaticRegistrarReferencesSubclass.alloc init];
	NSError *error = nil;

	NSArray *plugins = [registrar registeredPlugInsWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqual(plugins.count, 1u);
	XCTAssertEqualObjects(plugins.firstObject[kProPlugPlugIn_UuidProperty], kRefPluginAUUID);
}

/*! @abstract A reference naming no loaded class is skipped and the registrar reports no plugins. */
- (void)testRegisteredPlugIns_ReferencesUnknownName_IsSkipped {
	StaticRegistrarReferencesSubclass.references = @[@"FxGripStaticRegistrarNoSuchPlugin"];
	StaticRegistrarReferencesSubclass *registrar = [StaticRegistrarReferencesSubclass.alloc init];
	NSError *error = nil;

	XCTAssertNil([registrar registeredPlugInsWithError:&error]);
	XCTAssertEqual(error.code, kFxGripError_NoConfigPlugins);
}

#pragma mark registerPluginClass: and registerPlugin: forms

/*! @abstract A class whose information carries plugin and group lists registers both. */
- (void)testRegisterPluginClass_ListWithGroups_RegistersPluginsAndGroups {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	XCTAssertTrue([registrar registerPluginClass:StaticRegistrarRefPluginB.class]);

	XCTAssertTrue([registrar containsPluginUUID:kRefPluginBUUID]);
	XCTAssertTrue([registrar containsGroupUUID:kGroup2UUID]);
}

/*! @abstract registerPlugin: with a class argument forwards to class registration. */
- (void)testRegisterPlugin_ClassArgument_ForwardsToClassRegistration {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	XCTAssertTrue([registrar registerPlugin:(id)StaticRegistrarRefPluginA.class]);
	XCTAssertTrue([registrar containsPluginUUID:kRefPluginAUUID]);
}

/*! @abstract registerPlugin: rejects an argument that is neither a class nor a dictionary. */
- (void)testRegisterPlugin_NonDictionaryArgument_IsRejected {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	XCTAssertFalse([registrar registerPlugin:(id)@"not a plugin"]);
	XCTAssertFalse([registrar registerPlugin:(id)@42]);
}

/*! @abstract A plugin carrying a group name and group UUID registers the group and stores the record without the name. */
- (void)testRegisterPlugin_GroupNameWithGroupUUID_RegistersTheGroupAndStripsTheName {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kConsumerAUUID
															  extra:@{kProPlugPlugInX_RegGroupNameProperty: kGroup1Name}]]);
	XCTAssertTrue([registrar containsGroupUUID:kGroup1UUID]);

	NSError *error = nil;
	NSArray *plugins = [registrar registeredPlugInsWithError:&error];
	NSDictionary *record = [self plugin:kConsumerAUUID inArray:plugins];
	XCTAssertNil(record[kProPlugPlugInX_RegGroupNameProperty]);
	XCTAssertEqualObjects([registrar registeredPlugInGroupsWithError:&error],
						  (@[@{kProPlugPlugInX_RegGroupUUIDProperty: kGroup1UUID, kProPlugPlugInX_RegGroupNameProperty: kGroup1Name}]));
}

/*! @abstract A plugin carrying a group name but no group UUID registers neither the group nor the plugin. */
- (void)testRegisterPlugin_GroupNameWithoutGroupUUID_RegistersNothing {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	NSMutableDictionary *plugin = [[self validPluginUUID:kConsumerAUUID
												   extra:@{kProPlugPlugInX_RegGroupNameProperty: kGroup1Name}] mutableCopy];
	[plugin removeObjectForKey:kProPlugPlugIn_GroupUUIDProperty];

	XCTAssertFalse([registrar registerPlugin:plugin]);
	XCTAssertFalse([registrar containsGroupUUID:kGroup1UUID]);
	XCTAssertFalse([registrar containsPluginUUID:kConsumerAUUID]);
}

/*! @abstract A plugin without a class name is rejected. */
- (void)testRegisterPlugin_MissingClassName_IsRejected {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	NSMutableDictionary *plugin = [[self validPluginUUID:kConsumerAUUID extra:@{}] mutableCopy];
	[plugin removeObjectForKey:kProPlugPlugIn_ClassNameProperty];
	plugin[kProPlugPlugIn_ProtocolNamesProperty] = @"FxFilter";
	plugin[kProPlugPlugIn_VersionProperty] = @"1000";

	XCTAssertFalse([registrar registerPlugin:plugin]);
	XCTAssertFalse([registrar containsPluginUUID:kConsumerAUUID]);
}

/*! @abstract A plugin offered after registration closes is rejected. */
- (void)testRegisterPlugin_AfterRegistrationCloses_IsRejected {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kConsumerAUUID extra:@{}]]);
	NSError *error = nil;
	XCTAssertEqual([registrar registeredPlugInsWithError:&error].count, 1u);

	XCTAssertFalse([registrar registerPlugin:[self validPluginUUID:kConsumerBUUID extra:@{}]]);
	XCTAssertFalse([registrar containsPluginUUID:kConsumerBUUID]);
	XCTAssertEqual([registrar registeredPlugInsWithError:&error].count, 1u);
}

/*! @abstract registerPlugins: registers the values of a dictionary that is not itself a plugin. */
- (void)testRegisterPlugins_DictionaryOfPlugins_RegistersTheValues {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	[registrar registerPlugins:(id)@{ @"a": [self validPluginUUID:kConsumerAUUID extra:@{}],
									  @"b": [self validPluginUUID:kConsumerBUUID extra:@{}] }];

	XCTAssertTrue([registrar containsPluginUUID:kConsumerAUUID]);
	XCTAssertTrue([registrar containsPluginUUID:kConsumerBUUID]);
}

/*! @abstract registerPlugins: registers a single plugin dictionary that carries a class name. */
- (void)testRegisterPlugins_SinglePluginDictionary_Registers {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	[registrar registerPlugins:(id)[self validPluginUUID:kConsumerAUUID extra:@{}]];

	XCTAssertTrue([registrar containsPluginUUID:kConsumerAUUID]);
}

/*! @abstract registerPlugins: with nil registers nothing and does not throw. */
- (void)testRegisterPlugins_Nil_IsANoOp {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	XCTAssertNoThrow([registrar registerPlugins:nil]);
	XCTAssertFalse([registrar containsPluginUUID:kConsumerAUUID]);
}

/*! @abstract The frozen plugin array is cached and holds immutable records. */
- (void)testRegisteredPlugIns_SecondCallReturnsTheCachedImmutableArray {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kConsumerAUUID extra:@{}]]);
	NSError *error = nil;

	NSArray *first = [registrar registeredPlugInsWithError:&error];
	NSArray *second = [registrar registeredPlugInsWithError:&error];

	XCTAssertTrue(first == second);
	XCTAssertFalse([first isKindOfClass:NSMutableArray.class]);
	XCTAssertFalse([first.firstObject isKindOfClass:NSMutableDictionary.class]);
	XCTAssertFalse([registrar containsPluginUUID:kConsumerAUUID]);
}

/*! @abstract An OSC directive given as a dictionary links the consumer to each of its values. */
- (void)testRegisteredPlugIns_OSCDictionaryDirective_MovesToSupportedPlugins {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kOSCPluginUUID extra:@{}]]);
	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kConsumerAUUID
															  extra:@{kProPlugPlugInX_OSCUUIDsProperty: @{ @"control": kOSCPluginUUID }}]]);

	NSError *error = nil;
	NSArray *plugIns = [registrar registeredPlugInsWithError:&error];

	XCTAssertNil(error);
	XCTAssertEqualObjects([self plugin:kOSCPluginUUID inArray:plugIns][kProPlugPlugIn_SupportedPluginsProperty], @[kConsumerAUUID]);
	XCTAssertNil([self plugin:kConsumerAUUID inArray:plugIns][kProPlugPlugInX_OSCUUIDsProperty]);
}

#pragma mark registerGroups: forms

/*! @abstract registerGroups: with nil registers nothing and does not throw. */
- (void)testRegisterGroups_Nil_IsANoOp {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	XCTAssertNoThrow([registrar registerGroups:nil]);
	XCTAssertFalse([registrar containsGroupUUID:kGroup1UUID]);
}

/*! @abstract registerGroups: with one group dictionary registers that group. */
- (void)testRegisterGroups_SingleGroupDictionary_Registers {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	[registrar registerGroups:@{kProPlugPlugInX_RegGroupUUIDProperty: kGroup1UUID,
								kProPlugPlugInX_RegGroupNameProperty: kGroup1Name}];

	XCTAssertTrue([registrar containsGroupUUID:kGroup1UUID]);
}

/*! @abstract registerGroups: with a dictionary of groups registers each value. */
- (void)testRegisterGroups_DictionaryOfGroups_RegistersTheValues {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];

	[registrar registerGroups:@{ @"one": @{kProPlugPlugInX_RegGroupUUIDProperty: kGroup1UUID,
										   kProPlugPlugInX_RegGroupNameProperty: kGroup1Name},
								 @"two": @{kProPlugPlugInX_RegGroupUUIDProperty: kGroup2UUID,
										   kProPlugPlugInX_RegGroupNameProperty: kGroup2Name} }];

	XCTAssertTrue([registrar containsGroupUUID:kGroup1UUID]);
	XCTAssertTrue([registrar containsGroupUUID:kGroup2UUID]);
}

/*! @abstract registerGroups: with an array registers each entry, including FxGripPluginGroupData instances. */
- (void)testRegisterGroups_Array_RegistersEachEntry {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	FxGripPluginGroupData *groupData = [FxGripPluginGroupData.alloc initWithGroupUUID:kGroup2UUID groupName:kGroup2Name];

	[registrar registerGroups:@[ @{kProPlugPlugInX_RegGroupUUIDProperty: kGroup1UUID,
								   kProPlugPlugInX_RegGroupNameProperty: kGroup1Name},
								 groupData ]];

	XCTAssertTrue([registrar containsGroupUUID:kGroup1UUID]);
	XCTAssertTrue([registrar containsGroupUUID:kGroup2UUID]);
}

/*! @abstract Registering a group UUID again with a different name replaces the stored name. */
- (void)testRegisterGroupUUID_DifferentName_ReplacesTheName {
	FxGripStaticRegistrar *registrar = [FxGripStaticRegistrar.alloc init];
	XCTAssertTrue([registrar registerPlugin:[self validPluginUUID:kConsumerAUUID extra:@{}]]);

	[registrar registerGroupUUID:kGroup1UUID groupName:@"Old Name"];
	[registrar registerGroupUUID:kGroup1UUID groupName:kGroup1Name];

	NSError *error = nil;
	NSArray *groups = [registrar registeredPlugInGroupsWithError:&error];
	XCTAssertNil(error);
	XCTAssertEqual(groups.count, 1u);
	XCTAssertEqualObjects(groups.firstObject[kProPlugPlugInX_RegGroupNameProperty], kGroup1Name);
}


@end
