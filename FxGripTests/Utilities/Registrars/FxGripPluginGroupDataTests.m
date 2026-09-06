/*!
	@file       FxGripPluginGroupDataTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPluginGroupDataTests
	@abstract   Unit tests for the FxGripPluginGroupData model object.
	@discussion Introduced in FxGrip 0.1.0. The tests verify construction, the uuid and name accessors, and the -setData: filter that retains only the group UUID and group name keys while producing an immutable backing dictionary.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripPluginGroupData.h>

@interface FxGripPluginGroupDataDataTests : XCTestCase

@end

@implementation FxGripPluginGroupDataDataTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

/*! @abstract A freshly initialized group holds an empty immutable dictionary with nil uuid and name, for both -init and +new. */
-(void)testInit
{
	FxGripPluginGroupData *group = [FxGripPluginGroupData.alloc init];
	
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, @{});
	XCTAssertNil(group.uuid);
	XCTAssertNil(group.name);
	
	
	group = FxGripPluginGroupData.new;
	
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, @{});
	XCTAssertNil(group.uuid);
	XCTAssertNil(group.name);
}

/*! @abstract -initWithGroupUUID:groupName: stores the UUID and name and exposes them through data, uuid, and name. */
-(void)testInitWithGroup
{
	NSString	*uuid = [NSUUID UUID].UUIDString;
	NSString	*groupName = @"Custom Group Name";
	
	FxGripPluginGroupData *group = [FxGripPluginGroupData.alloc initWithGroupUUID:uuid groupName:groupName];
	
	NSDictionary *reference = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName};
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, reference);
	XCTAssertEqualObjects(group.uuid, uuid);
	XCTAssertEqualObjects(group.name, groupName);
}


/*! @abstract +newPluginGroupUUID:groupName: builds a group carrying the given UUID and name. */
-(void)testNewPluginGroup
{
	NSString	*uuid = [NSUUID UUID].UUIDString;
	NSString	*groupName = @"Custom New Group Name";
	
	FxGripPluginGroupData *group = [FxGripPluginGroupData newPluginGroupUUID:uuid groupName:groupName];
	
	NSDictionary *reference = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName};
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, reference);
	XCTAssertEqualObjects(group.uuid, uuid);
	XCTAssertEqualObjects(group.name, groupName);
}



/*! @abstract -setData: keeps the UUID and name keys and drops unrelated keys from the stored dictionary. */
-(void)testSetData_Full
{
	NSString	*uuid = [NSUUID UUID].UUIDString;
	NSString	*groupName = @"Custom setData Group Name";
	
	FxGripPluginGroupData *group = FxGripPluginGroupData.new;
	
	group.data = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName, @"irrelevant" : @"other Data"};
	
	NSDictionary *reference = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName};
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, reference);
	XCTAssertEqualObjects(group.uuid, uuid);
	XCTAssertEqualObjects(group.name, groupName);
}

/*! @abstract -setData: replaces preset content, keeping only the new UUID and name keys. */
-(void)testSetData_Preset
{
	NSString	*presetUuid = [NSUUID UUID].UUIDString;
	NSString	*presetGroupName = @"Preset Group Name";

	NSString	*uuid = [NSUUID UUID].UUIDString;
	NSString	*groupName = @"Custom setData Group Name";
	
	FxGripPluginGroupData *group = [FxGripPluginGroupData newPluginGroupUUID:presetUuid groupName:presetGroupName];
	
	group.data = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName, @"irrelevant" : @"other Data"};
	
	NSDictionary *reference = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName};
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, reference);
	XCTAssertEqualObjects(group.uuid, uuid);
	XCTAssertEqualObjects(group.name, groupName);
}


/*! @abstract -setData: with only a UUID key leaves the name nil. */
-(void)testSetData_UUID
{
	NSString	*presetUuid = [NSUUID UUID].UUIDString;
	NSString	*presetGroupName = @"Preset Group Name";
	
	NSString	*uuid = [NSUUID UUID].UUIDString;
	
	FxGripPluginGroupData *group = [FxGripPluginGroupData newPluginGroupUUID:presetUuid groupName:presetGroupName];
	
	group.data = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, @"irrelevant" : @"other Data"};
	
	NSDictionary *reference = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid};
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, reference);
	XCTAssertEqualObjects(group.uuid, uuid);
	XCTAssertNil(group.name);
}

/*! @abstract -setData: with only a name key leaves the uuid nil. */
-(void)testSetData_Name
{
	NSString	*presetUuid = [NSUUID UUID].UUIDString;
	NSString	*presetGroupName = @"Preset Group Name";
	
	NSString	*groupName = @"Custom setData Group Name";
	
	FxGripPluginGroupData *group = [FxGripPluginGroupData newPluginGroupUUID:presetUuid groupName:presetGroupName];
	
	group.data = @{kProPlugPlugInX_RegGroupNameProperty: groupName, @"irrelevant" : @"other Data"};
	
	NSDictionary *reference = @{kProPlugPlugInX_RegGroupNameProperty: groupName};
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, reference);
	XCTAssertNil(group.uuid);
	XCTAssertEqualObjects(group.name, groupName);
}

@end
