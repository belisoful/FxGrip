/*!
	@file       FxGripPluginDataTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPluginDataTests
	@abstract   Unit tests for the FxGripPluginData model object.
	@discussion Introduced in FxGrip 0.1.0. The tests verify construction, the typed accessors for uuid, class name, display name, group uuid, protocol names, info string, version, and supported plugins, and the -setData: filter that normalizes and retains only the known plugin keys in an immutable backing dictionary. They cover each property setter and the keyed subscript accessors.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripPluginData.h>
#import <FxGrip/FxGripTileableEffect.h>

@interface FxGripPlugDataPluginExample : FxGripTileableEffect
@end
@implementation FxGripPlugDataPluginExample
@end


@interface FxGripPluginDataTests : XCTestCase

@end

@implementation FxGripPluginDataTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

/*! @abstract A freshly initialized plugin holds an empty immutable dictionary with every typed accessor nil or zero, for both -init and +new. */
-(void)testInit
{
	FxGripPluginData *plugin = [FxGripPluginData.alloc init];
	
	XCTAssertNotNil(plugin.data);
	XCTAssertTrue([plugin.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([plugin.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(plugin.data, @{});
	XCTAssertNil(plugin.uuid);
	XCTAssertNil(plugin.pluginClassName);
	XCTAssertNil(plugin.displayName);
	XCTAssertNil(plugin.groupUuid);
	XCTAssertNil(plugin.protocolNames);
	XCTAssertNil(plugin.infoString);
	XCTAssertNil(plugin.version);
	XCTAssertEqual(plugin.versionInteger, 0);
	XCTAssertNil(plugin.supportedPlugins);
	
	
	plugin = FxGripPluginData.new;
	
	XCTAssertNotNil(plugin.data);
	XCTAssertTrue([plugin.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([plugin.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(plugin.data, @{});
	XCTAssertNil(plugin.uuid);
	XCTAssertNil(plugin.pluginClassName);
	XCTAssertNil(plugin.displayName);
	XCTAssertNil(plugin.groupUuid);
	XCTAssertNil(plugin.protocolNames);
	XCTAssertNil(plugin.infoString);
	XCTAssertNil(plugin.version);
	XCTAssertEqual(plugin.versionInteger, 0);
	XCTAssertNil(plugin.supportedPlugins);
}

/*! @abstract -initWithDictionary: stores every declared field and exposes it through the typed accessors. */
-(void)testInitWithGroup
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxFilter],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @911,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData.alloc initWithDictionary:reference];
	
	XCTAssertNotNil(plugin.data);
	XCTAssertTrue([plugin.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([plugin.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(plugin.data, reference);
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}


/*! @abstract +newPluginWithDictionary: builds a plugin carrying every declared field. */
-(void)testNewPluginGroup
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"New Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxGenerator],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @811,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertNotNil(plugin.data);
	XCTAssertTrue([plugin.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([plugin.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(plugin.data, reference);
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}



/*! @abstract -setData: stores a copy of a full dictionary and exposes every field through the accessors. */
-(void)testSetData_Full
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"OSC Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @711,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = FxGripPluginData.new;
	
	plugin.data = reference;
	
	XCTAssertNotNil(plugin.data);
	XCTAssertNotEqual(plugin.data, reference);
	XCTAssertTrue([plugin.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([plugin.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(plugin.data, reference);
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}

/*! @abstract -setData: keeps the supplied fields and leaves the undeclared protocol names, version, and supported plugins nil. */
-(void)testSetData_NoValidationFields
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								kProPlugPlugIn_InfoStringProperty: @"Preset Info String",
	};
	
	FxGripPluginData *plugin = FxGripPluginData.new;
	
	plugin.data = reference;
	
	XCTAssertNotNil(plugin.data);
	XCTAssertNotEqual(plugin.data, reference);
	XCTAssertTrue([plugin.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([plugin.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(plugin.data, reference);
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertNil(plugin.protocolNames);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertNil(plugin.version);
	XCTAssertEqual(plugin.versionInteger, 0);
	XCTAssertNil(plugin.supportedPlugins);
}

/*! @abstract -setData: normalizes a scalar protocol name, version string, and supported-plugin string into their array and number forms. */
-(void)testSetData_AltValidationFields
{
	NSString	*pluginUUID = [NSUUID UUID].UUIDString;
	NSString	*groupUUID = [NSUUID UUID].UUIDString;
	NSString 	*supportedPluginUUID = [NSUUID UUID].UUIDString;
	
	NSDictionary	*preset = @{kProPlugPlugIn_UuidProperty: pluginUUID,
								kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								kProPlugPlugIn_GroupUUIDProperty: groupUUID,
								kProPlugPlugIn_ProtocolNamesProperty: kProPlugPlugIn_ProtocolFxOnScreenControl,
								kProPlugPlugIn_InfoStringProperty: @"Preset Info String",
								kProPlugPlugIn_VersionProperty: @"700",
								kProPlugPlugIn_SupportedPluginsProperty: supportedPluginUUID
	};
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: pluginUUID,
								kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								kProPlugPlugIn_GroupUUIDProperty: groupUUID,
								kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								kProPlugPlugIn_InfoStringProperty: @"Preset Info String",
								kProPlugPlugIn_VersionProperty: @700,
								kProPlugPlugIn_SupportedPluginsProperty: @[supportedPluginUUID]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:nil];
	
	plugin.data = preset;
	
	XCTAssertNotNil(plugin.data);
	XCTAssertNotEqual(plugin.data, reference);
	XCTAssertTrue([plugin.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([plugin.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(plugin.data, reference);
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}

/*! @abstract -setData: replaces preset content wholesale with the new dictionary's fields. */
-(void)testSetData_Preset
{
	NSDictionary	*preset = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								kProPlugPlugIn_InfoStringProperty: @"Preset Info String",
								kProPlugPlugIn_VersionProperty: @700,
								kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripPlugDataPluginExample.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Diff Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxBaseEffect],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @611,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:preset];
	
	plugin.data = reference;
	
	XCTAssertNotNil(plugin.data);
	XCTAssertNotEqual(plugin.data, reference);
	XCTAssertTrue([plugin.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([plugin.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(plugin.data, reference);
	XCTAssertNotEqualObjects(preset[kProPlugPlugIn_UuidProperty], reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertNotEqualObjects(preset[kProPlugPlugIn_ClassNameProperty], reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertNotEqualObjects(preset[kProPlugPlugIn_DisplayNameProperty], reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertNotEqualObjects(preset[kProPlugPlugIn_GroupUUIDProperty], reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertNotEqualObjects(preset[kProPlugPlugIn_ProtocolNamesProperty], reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertNotEqualObjects(preset[kProPlugPlugIn_InfoStringProperty], reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertNotEqualObjects(preset[kProPlugPlugIn_VersionProperty], reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertNotEqualObjects(preset[kProPlugPlugIn_SupportedPluginsProperty], reference[kProPlugPlugIn_SupportedPluginsProperty]);
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}


/*! @abstract Setting uuid updates the UUID and setting it nil clears it, both leaving the other fields intact. */
-(void)testSetUUID
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	NSString *newUuid = [NSUUID UUID].UUIDString;
	plugin.uuid = newUuid;
	
	XCTAssertEqualObjects(plugin.uuid, newUuid);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	
	plugin.uuid = nil;
	
	XCTAssertNil(plugin.uuid);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}

/*! @abstract Setting pluginClassName updates the class name and setting it nil clears it, both leaving the other fields intact. */
-(void)testSetPluginClassName
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	NSString *newPluginClassName = FxGripPlugDataPluginExample.className;
	plugin.pluginClassName = newPluginClassName;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, newPluginClassName);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	
	plugin.pluginClassName = nil;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertNil(plugin.pluginClassName);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}

/*! @abstract Setting displayName updates the display name and setting it nil clears it, both leaving the other fields intact. */
-(void)testSetDisplayName
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	NSString *newDisplayName = @"New Plugin Display Name";
	plugin.displayName = newDisplayName;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, newDisplayName);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	plugin.displayName = nil;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertNil(plugin.displayName);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}


/*! @abstract Setting groupUuid updates the group UUID and setting it nil clears it, both leaving the other fields intact. */
-(void)testSetGroupUUID
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	NSString *newGroupUUID = [NSUUID UUID].UUIDString;
	plugin.groupUuid = newGroupUUID;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, newGroupUUID);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	plugin.groupUuid = nil;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertNil(plugin.groupUuid);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}


/*! @abstract Setting protocolNames updates the protocol list and setting it nil clears it, both leaving the other fields intact. */
-(void)testSetProtocolNames
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	NSArray *newProtocolName = @[kProPlugPlugIn_ProtocolFxBaseEffect];
	plugin.protocolNames = newProtocolName;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, newProtocolName);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	plugin.protocolNames = nil;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertNil(plugin.protocolNames);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}


/*! @abstract Setting infoString updates the info string and setting it nil clears it, both leaving the other fields intact. */
-(void)testSetInfoString
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	NSString *newInfoString = @"New Info String";
	plugin.infoString = newInfoString;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, newInfoString);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	plugin.infoString = nil;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertNil(plugin.infoString);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}


/*! @abstract Setting version updates the version number and versionInteger, and setting it nil clears both. */
-(void)testSetVersion
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	NSNumber *newVersion = @11;
	plugin.version = newVersion;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, newVersion);
	XCTAssertEqual(plugin.versionInteger, [newVersion unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	plugin.version = nil;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertNil(plugin.version);
	XCTAssertEqual(plugin.versionInteger, 0);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}


/*! @abstract Setting versionInteger updates the version number, and setting it zero clears the version. */
-(void)testSetVersionInteger
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	NSUInteger newVersion = 100;
	plugin.versionInteger = newVersion;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, [NSNumber numberWithUnsignedInteger:newVersion]);
	XCTAssertEqual(plugin.versionInteger, newVersion);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	plugin.versionInteger = 0;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertNil(plugin.version);
	XCTAssertEqual(plugin.versionInteger, 0);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}


/*! @abstract Setting supportedPlugins updates the list and setting it nil clears it, both leaving the other fields intact. */
-(void)testSetSupportedPlugins
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	NSArray *supportedPlugins = @[[NSUUID UUID].UUIDString];
	plugin.supportedPlugins = supportedPlugins;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, supportedPlugins);
	
	plugin.supportedPlugins = nil;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertNil(plugin.supportedPlugins);
}


/*! @abstract The keyed subscript setter updates the group UUID field and clears it when set nil. */
-(void)testObjectForKeyedSubscript
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	NSString *groupUUID = [NSUUID UUID].UUIDString;
	
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	
	plugin[kProPlugPlugIn_GroupUUIDProperty] = groupUUID;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, groupUUID);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	plugin[kProPlugPlugIn_GroupUUIDProperty] = nil;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertNil(plugin.groupUuid);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}


/*! @abstract The keyed subscript normalizes a scalar protocol name into an array and clears the field when set nil. */
-(void)testObjectForKeyedSubscript_ProtocolNames
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	
	NSArray *protocolNames = @[kProPlugPlugIn_ProtocolFxFilter];
	
	plugin[kProPlugPlugIn_ProtocolNamesProperty] = protocolNames;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, protocolNames);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	NSString* protocolNameString = kProPlugPlugIn_ProtocolFxGenerator;
	plugin[kProPlugPlugIn_ProtocolNamesProperty] = protocolNameString;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, @[protocolNameString]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	plugin[kProPlugPlugIn_ProtocolNamesProperty] = nil;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertNil(plugin.protocolNames);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}


/*! @abstract The keyed subscript accepts a version number or numeric string and clears the field when set nil. */
-(void)testObjectForKeyedSubscript_Version
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	
	NSNumber *versionNumber = @1000;
	
	plugin[kProPlugPlugIn_VersionProperty] = versionNumber;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, versionNumber);
	XCTAssertEqual(plugin.versionInteger, [versionNumber unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	NSString* versionString = @"211";
	plugin[kProPlugPlugIn_VersionProperty] = versionString;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, @([versionString integerValue]));
	XCTAssertEqual(plugin.versionInteger, [versionString integerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	plugin[kProPlugPlugIn_VersionProperty] = nil;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertNil(plugin.version);
	XCTAssertEqual(plugin.versionInteger, 0);
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
}


/*! @abstract The keyed subscript normalizes a scalar supported-plugin string into an array and clears the field when set nil. */
-(void)testObjectForKeyedSubscript_supportedPlugins
{
	NSDictionary	*reference = @{kProPlugPlugIn_UuidProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ClassNameProperty: FxGripTileableEffect.class,
								   kProPlugPlugIn_DisplayNameProperty: @"Preset Plugin Display Name",
								   kProPlugPlugIn_GroupUUIDProperty: [NSUUID UUID].UUIDString,
								   kProPlugPlugIn_ProtocolNamesProperty: @[kProPlugPlugIn_ProtocolFxOnScreenControl],
								   kProPlugPlugIn_InfoStringProperty: @"Info String",
								   kProPlugPlugIn_VersionProperty: @700,
								   kProPlugPlugIn_SupportedPluginsProperty: @[[NSUUID UUID].UUIDString]
	};
	
	FxGripPluginData *plugin = [FxGripPluginData newPluginWithDictionary:reference];
	
	XCTAssertEqualObjects(plugin.data, reference);
	
	XCTAssertEqualObjects(plugin.supportedPlugins, reference[kProPlugPlugIn_SupportedPluginsProperty]);
	
	NSArray *supportedPlugins = @[[NSUUID UUID].UUIDString];
	
	plugin[kProPlugPlugIn_SupportedPluginsProperty] = supportedPlugins;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, supportedPlugins);
	
	NSString* supportedPluginsString = [NSUUID UUID].UUIDString;
	plugin[kProPlugPlugIn_SupportedPluginsProperty] = supportedPluginsString;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertEqualObjects(plugin.supportedPlugins, @[supportedPluginsString]);
	
	plugin[kProPlugPlugIn_SupportedPluginsProperty] = nil;
	
	XCTAssertEqualObjects(plugin.uuid, reference[kProPlugPlugIn_UuidProperty]);
	XCTAssertEqualObjects(plugin.pluginClassName, reference[kProPlugPlugIn_ClassNameProperty]);
	XCTAssertEqualObjects(plugin.displayName, reference[kProPlugPlugIn_DisplayNameProperty]);
	XCTAssertEqualObjects(plugin.groupUuid, reference[kProPlugPlugIn_GroupUUIDProperty]);
	XCTAssertEqualObjects(plugin.protocolNames, reference[kProPlugPlugIn_ProtocolNamesProperty]);
	XCTAssertEqualObjects(plugin.infoString, reference[kProPlugPlugIn_InfoStringProperty]);
	XCTAssertEqualObjects(plugin.version, reference[kProPlugPlugIn_VersionProperty]);
	XCTAssertEqual(plugin.versionInteger, [(NSNumber*)reference[kProPlugPlugIn_VersionProperty] unsignedIntegerValue]);
	XCTAssertNil(plugin.supportedPlugins);
}

@end
