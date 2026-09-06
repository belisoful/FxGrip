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

	XCTAssertNoThrow([registrar registerGroupUUID:nil groupName:kGroup1Name]);
	XCTAssertNoThrow([registrar registerGroupUUID:kGroup1UUID groupName:nil]);
	XCTAssertNoThrow([registrar registerGroupUUID:nil groupName:nil]);

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

@end
