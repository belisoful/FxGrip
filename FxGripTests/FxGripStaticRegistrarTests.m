//
//  FxGripPluginTests.m
//  FxGripPluginTests
//
//  Created by ~ ~ on 3/15/24.
//

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

- (void)testClassProtocols {
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(PROPlugInRegistering)]);
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(FxGripStaticRegistrarSubclass)]);
}

- (void)testRegistrationProtocols {
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(PROPlugInRegistering)]);
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(FxGripStaticRegistrarSubclass)]);
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(FxRegisteringGroups)]);
	XCTAssertTrue([FxGripStaticRegistrar conformsToProtocol:@protocol(FxRegisteringPlugins)]);
}


- (void)testInit {
	FxGripStaticRegistrar *staticRegistrar = [FxGripStaticRegistrar.alloc init];
	
	XCTAssertTrue(staticRegistrar.isLoadable);
	
	NSError *error = nil;
	XCTAssertTrue([staticRegistrar shouldLoadFirstInstanceOfPlugInWithError:&error]);
	XCTAssertNil(error);
	XCTAssertNil(staticRegistrar.registeredPlugInGroups);
	XCTAssertNil(staticRegistrar.registeredPlugIns);
}

- (void)testSharedInstance
{
	FxGripStaticRegistrar *globalStaticRegistrar = [FxGripStaticRegistrar sharedInstance];
	XCTAssertTrue([globalStaticRegistrar isKindOfClass:FxGripStaticRegistrar.class]);
}


- (void)testRegisteredPlugInGroupsWithError_Baseline {
	FxGripStaticRegistrar *staticRegistrar = [FxGripStaticRegistrar.alloc init];
	
	NSError *error = nil;
	XCTAssertNil([staticRegistrar registeredPlugInGroupsWithError:&error]);
	XCTAssertNotNil(error);
}

- (void)testRegisteredPlugInsWithError_Baseline {
	FxGripStaticRegistrar *staticRegistrar = [FxGripStaticRegistrar.alloc init];
	
	NSError *error = nil;
	XCTAssertNil([staticRegistrar registeredPlugInsWithError:&error]);
	XCTAssertNotNil(error);
}



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

- (void)testRegisteredPlugIns_Property {
	FxGripStaticRegistrar *staticRegistrar = [StaticRegistrarPropertiesClass.alloc init];
	
	NSError *error = nil;
	XCTAssertNil([staticRegistrar registeredPlugInsWithError:&error]);
	XCTAssertNotNil(error);
}


- (void)testPlugInGroupsWithError_Baseline {
	FxGripStaticRegistrar *staticRegistrar = [FxGripStaticRegistrar.alloc init];
	
	NSError *error = nil;
	XCTAssertNil([staticRegistrar registeredPlugInGroupsWithError:&error]);
	XCTAssertNotNil(error);
}

- (void)testPlugInsWithError_Baseline {
	FxGripStaticRegistrar *staticRegistrar = [FxGripStaticRegistrar.alloc init];
	
	NSError *error = nil;
	XCTAssertNil([staticRegistrar registeredPlugInsWithError:&error]);
	XCTAssertNotNil(error);
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
