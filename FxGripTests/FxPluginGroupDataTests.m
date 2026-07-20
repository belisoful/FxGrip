//
//  FxGripPluginTests.m
//  FxGripPluginTests
//
//  Created by ~ ~ on 3/15/24.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxPluginGroupData.h>

@interface FxPluginGroupDataDataTests : XCTestCase

@end

@implementation FxPluginGroupDataDataTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

-(void)testInit
{
	FxPluginGroupData *group = [FxPluginGroupData.alloc init];
	
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, @{});
	XCTAssertNil(group.uuid);
	XCTAssertNil(group.name);
	
	
	group = FxPluginGroupData.new;
	
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, @{});
	XCTAssertNil(group.uuid);
	XCTAssertNil(group.name);
}

-(void)testInitWithGroup
{
	NSString	*uuid = [NSUUID UUID].UUIDString;
	NSString	*groupName = @"Custom Group Name";
	
	FxPluginGroupData *group = [FxPluginGroupData.alloc initWithGroupUUID:uuid groupName:groupName];
	
	NSDictionary *reference = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName};
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, reference);
	XCTAssertEqualObjects(group.uuid, uuid);
	XCTAssertEqualObjects(group.name, groupName);
}


-(void)testNewPluginGroup
{
	NSString	*uuid = [NSUUID UUID].UUIDString;
	NSString	*groupName = @"Custom New Group Name";
	
	FxPluginGroupData *group = [FxPluginGroupData newPluginGroupUUID:uuid groupName:groupName];
	
	NSDictionary *reference = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName};
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, reference);
	XCTAssertEqualObjects(group.uuid, uuid);
	XCTAssertEqualObjects(group.name, groupName);
}



-(void)testSetData_Full
{
	NSString	*uuid = [NSUUID UUID].UUIDString;
	NSString	*groupName = @"Custom setData Group Name";
	
	FxPluginGroupData *group = FxPluginGroupData.new;
	
	group.data = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName, @"irrelevant" : @"other Data"};
	
	NSDictionary *reference = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName};
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, reference);
	XCTAssertEqualObjects(group.uuid, uuid);
	XCTAssertEqualObjects(group.name, groupName);
}

-(void)testSetData_Preset
{
	NSString	*presetUuid = [NSUUID UUID].UUIDString;
	NSString	*presetGroupName = @"Preset Group Name";
	
	NSString	*uuid = [NSUUID UUID].UUIDString;
	NSString	*groupName = @"Custom setData Group Name";
	
	FxPluginGroupData *group = [FxPluginGroupData newPluginGroupUUID:presetUuid groupName:presetGroupName];
	
	group.data = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName, @"irrelevant" : @"other Data"};
	
	NSDictionary *reference = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, kProPlugPlugInX_RegGroupNameProperty: groupName};
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, reference);
	XCTAssertEqualObjects(group.uuid, uuid);
	XCTAssertEqualObjects(group.name, groupName);
}


-(void)testSetData_UUID
{
	NSString	*presetUuid = [NSUUID UUID].UUIDString;
	NSString	*presetGroupName = @"Preset Group Name";
	
	NSString	*uuid = [NSUUID UUID].UUIDString;
	
	FxPluginGroupData *group = [FxPluginGroupData newPluginGroupUUID:presetUuid groupName:presetGroupName];
	
	group.data = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid, @"irrelevant" : @"other Data"};
	
	NSDictionary *reference = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid};
	XCTAssertNotNil(group.data);
	XCTAssertTrue([group.data isKindOfClass:NSDictionary.class]);
	XCTAssertFalse([group.data isKindOfClass:NSMutableDictionary.class]);
	XCTAssertEqualObjects(group.data, reference);
	XCTAssertEqualObjects(group.uuid, uuid);
	XCTAssertNil(group.name);
}

-(void)testSetData_Name
{
	NSString	*presetUuid = [NSUUID UUID].UUIDString;
	NSString	*presetGroupName = @"Preset Group Name";
	
	NSString	*groupName = @"Custom setData Group Name";
	
	FxPluginGroupData *group = [FxPluginGroupData newPluginGroupUUID:presetUuid groupName:presetGroupName];
	
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
