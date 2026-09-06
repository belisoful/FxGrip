/*!
	@file       FxGripParameterGroupingAPI_v1Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterGroupingAPI_v1Tests
	@abstract   Verifies the grouping wrapper's subgroup, child-count, child-enumeration, and parent queries against the effect's own parameter objects.
	@discussion Introduced in FxGrip 0.1.0. The subgroup query reads the parameter type from the dynamic API. The child and parent queries walk the effect's parameter objects. Reparenting is refused.
*/

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameterGroupingAPI_v1.h>

static const FxParameterId kGroupingTestGroup = 61;
static const FxParameterId kGroupingTestChildA = 62;
static const FxParameterId kGroupingTestChildB = 63;
static const FxParameterId kGroupingTestLeaf = 64;
static const FxParameterId kGroupingTestMissing = 65;

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxGripGroupingTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

#pragma mark - Test doubles

/*!
	Stands in for one of the effect's parameter objects. It reports conformance to
	FxGripSubParameters through -conformsToProtocol: so a leaf and a group can be told apart
	without adopting the full parameter protocol.
*/
@interface FxGripGroupingTestParameter : NSObject
@property (nonatomic, assign) FxParameterId parameterID;
@property (nonatomic, assign) FxParameterId parameterParentID;
@property (nonatomic, strong) NSArray<FxGripGroupingTestParameter *> *children;
@property (nonatomic, assign) BOOL isSubParameterContainer;
@end

@implementation FxGripGroupingTestParameter

- (instancetype)init
{
	self = [super init];
	if (self) {
		_children = @[];
	}
	return self;
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
	if (strcmp(protocol_getName(aProtocol), "FxGripSubParameters") == 0) {
		return self.isSubParameterContainer;
	}
	return [super conformsToProtocol:aProtocol];
}

- (NSUInteger)count
{
	return self.children.count;
}

- (id)objectAtIndexedSubscript:(NSInteger)index
{
	return self.children[index];
}

@end

/*! Answers the parameter type the subgroup query branches on. */
@interface FxGripGroupingTestDynamicAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *types;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *requestedParameters;
@end

@implementation FxGripGroupingTestDynamicAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_types = NSMutableDictionary.new;
		_requestedParameters = NSMutableArray.new;
	}
	return self;
}

- (FxParameterType)parameterType:(FxParameterId)parameterID
{
	[self.requestedParameters addObject:@(parameterID)];
	NSNumber *type = self.types[@(parameterID)];
	return type ? (FxParameterType)type.integerValue : FxParameterType_None;
}

@end

/*!
	FxGripTileableEffect's designated initializer registers into the process-wide
	notification center, so the wrapper is exercised against a stub carrying an isolated
	notifier. The grouping queries subscript the effect for each parameter object.
*/
@interface FxGripGroupingTestStubEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, FxGripGroupingTestParameter *> *parameters;
@end

@implementation FxGripGroupingTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxGripGroupingTestMakePriorityCenter();
		_parameters = NSMutableDictionary.new;
	}
	return self;
}

- (id)objectAtIndexedSubscript:(NSInteger)index
{
	return self.parameters[@(index)];
}

@end

#pragma mark - Tests

@interface FxGripParameterGroupingAPI_v1Tests : XCTestCase
@property (nonatomic, strong) FxGripGroupingTestStubEffect *effect;
@property (nonatomic, strong) FxGripGroupingTestDynamicAPI *dynamicAPI;
@property (nonatomic, strong) FxGripParameterGroupingAPI_v1 *api;
@end

@implementation FxGripParameterGroupingAPI_v1Tests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripGroupingTestStubEffect.alloc init];
	self.dynamicAPI = [FxGripGroupingTestDynamicAPI.alloc init];
	self.api = [FxGripParameterGroupingAPI_v1.alloc initWithAPI:nil
											  parameterInfoAPIv1:(id)self.dynamicAPI
														 effect:(id)self.effect];
}

- (void)tearDown
{
	self.api = nil;
	self.dynamicAPI = nil;
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

- (FxGripGroupingTestParameter *)addParameter:(FxParameterId)parameterID
								   parent:(FxParameterId)parentID
								container:(BOOL)container
{
	FxGripGroupingTestParameter *parameter = [FxGripGroupingTestParameter.alloc init];
	parameter.parameterID = parameterID;
	parameter.parameterParentID = parentID;
	parameter.isSubParameterContainer = container;
	self.effect.parameters[@(parameterID)] = parameter;
	return parameter;
}

/*! A group holding two children, all three registered with the effect. */
- (FxGripGroupingTestParameter *)installPopulatedGroup
{
	FxGripGroupingTestParameter *group = [self addParameter:kGroupingTestGroup
												 parent:kFxParameterId_TopLevelGroup
											  container:YES];
	FxGripGroupingTestParameter *childA = [self addParameter:kGroupingTestChildA
												  parent:kGroupingTestGroup
											   container:NO];
	FxGripGroupingTestParameter *childB = [self addParameter:kGroupingTestChildB
												  parent:kGroupingTestGroup
											   container:NO];
	group.children = @[childA, childB];
	return group;
}

#pragma mark isSubGroup:

/*! @abstract A group-typed parameter is a subgroup, and the query reads the type from the dynamic API. */
- (void)testAGroupTypedParameterIsASubGroup
{
	self.dynamicAPI.types[@(kGroupingTestGroup)] = @(FxParameterType_Group);

	XCTAssertTrue([self.api isSubGroup:kGroupingTestGroup]);
	XCTAssertEqualObjects(self.dynamicAPI.requestedParameters, @[@(kGroupingTestGroup)]);
}

/*! @abstract A parameter of a non-group type is not a subgroup. */
- (void)testAParameterOfAnyOtherTypeIsNotASubGroup
{
	self.dynamicAPI.types[@(kGroupingTestLeaf)] = @(FxParameterType_Float);

	XCTAssertFalse([self.api isSubGroup:kGroupingTestLeaf]);
}

/*! @abstract An unknown parameter is not a subgroup. */
- (void)testAnUnknownParameterIsNotASubGroup
{
	XCTAssertFalse([self.api isSubGroup:kGroupingTestMissing]);
}

/*! @abstract Without a dynamic API the type reads as None, so nothing is a subgroup. */
- (void)testWithoutADynamicAPINothingIsASubGroup
{
	FxGripParameterGroupingAPI_v1 *api =
		[FxGripParameterGroupingAPI_v1.alloc initWithAPI:nil
									   parameterInfoAPIv1:nil
												  effect:(id)self.effect];

	XCTAssertFalse([api isSubGroup:kGroupingTestGroup],
				   @"a missing dynamic API reports the None type");
}

#pragma mark hasSubParameters:

/*! @abstract A group holding children has subparameters. */
- (void)testAGroupHoldingChildrenHasSubParameters
{
	[self installPopulatedGroup];

	XCTAssertTrue([self.api hasSubParameters:kGroupingTestGroup]);
}

/*! @abstract An empty group holds no subparameters. */
- (void)testAnEmptyGroupHasNoSubParameters
{
	[self addParameter:kGroupingTestGroup parent:kFxParameterId_TopLevelGroup container:YES];

	XCTAssertFalse([self.api hasSubParameters:kGroupingTestGroup]);
}

/*! @abstract A non-container parameter holds no subparameters. */
- (void)testAParameterThatHoldsNoChildrenHasNoSubParameters
{
	[self addParameter:kGroupingTestLeaf parent:kFxParameterId_TopLevelGroup container:NO];

	XCTAssertFalse([self.api hasSubParameters:kGroupingTestLeaf]);
}

/*! @abstract An unknown parameter holds no subparameters. */
- (void)testAnUnknownParameterHasNoSubParameters
{
	XCTAssertFalse([self.api hasSubParameters:kGroupingTestMissing]);
}

#pragma mark parameterSubCount:

/*! @abstract The subcount reports the number of children a group holds. */
- (void)testParameterSubCountReportsTheChildCount
{
	[self installPopulatedGroup];

	XCTAssertEqual([self.api parameterSubCount:kGroupingTestGroup], (UInt32)2);
}

/*! @abstract The subcount is zero for a parameter that holds no children. */
- (void)testParameterSubCountIsZeroForAParameterThatHoldsNoChildren
{
	[self addParameter:kGroupingTestLeaf parent:kFxParameterId_TopLevelGroup container:NO];

	XCTAssertEqual([self.api parameterSubCount:kGroupingTestLeaf], (UInt32)0);
}

/*! @abstract The subcount is zero for an unknown parameter. */
- (void)testParameterSubCountIsZeroForAnUnknownParameter
{
	XCTAssertEqual([self.api parameterSubCount:kGroupingTestMissing], (UInt32)0);
}

#pragma mark parameterIDAtSubIndex:fromParameter:

/*! @abstract The child at each subindex reports the group's children in order. */
- (void)testParameterIDAtSubIndexReportsEachChildInOrder
{
	[self installPopulatedGroup];

	XCTAssertEqual([self.api parameterIDAtSubIndex:0 fromParameter:kGroupingTestGroup],
				   kGroupingTestChildA);
	XCTAssertEqual([self.api parameterIDAtSubIndex:1 fromParameter:kGroupingTestGroup],
				   kGroupingTestChildB);
}

/*! @abstract The child at a subindex past the last child is zero. */
- (void)testParameterIDAtSubIndexIsZeroPastTheLastChild
{
	[self installPopulatedGroup];

	XCTAssertEqual([self.api parameterIDAtSubIndex:2 fromParameter:kGroupingTestGroup],
				   (FxParameterId)0);
}

/*! @abstract The child at a subindex is zero for a parameter that holds no children. */
- (void)testParameterIDAtSubIndexIsZeroForAParameterThatHoldsNoChildren
{
	[self addParameter:kGroupingTestLeaf parent:kFxParameterId_TopLevelGroup container:NO];

	XCTAssertEqual([self.api parameterIDAtSubIndex:0 fromParameter:kGroupingTestLeaf],
				   (FxParameterId)0);
}

/*! @abstract The child at a subindex is zero for an unknown parameter. */
- (void)testParameterIDAtSubIndexIsZeroForAnUnknownParameter
{
	XCTAssertEqual([self.api parameterIDAtSubIndex:0 fromParameter:kGroupingTestMissing],
				   (FxParameterId)0);
}

#pragma mark getParameterSubGroup:

/*! @abstract The subgroup query reports the parent group of a child. */
- (void)testGetParameterSubGroupReportsTheParentOfAChild
{
	[self installPopulatedGroup];

	XCTAssertEqual([self.api getParameterSubGroup:kGroupingTestChildA], kGroupingTestGroup);
}

/*! @abstract The subgroup query reports the top-level group for a top-level parameter. */
- (void)testGetParameterSubGroupReportsTheTopLevelGroupForATopLevelParameter
{
	[self addParameter:kGroupingTestLeaf parent:kFxParameterId_TopLevelGroup container:NO];

	XCTAssertEqual([self.api getParameterSubGroup:kGroupingTestLeaf],
				   (FxParameterId)kFxParameterId_TopLevelGroup);
}

/*! @abstract The subgroup query reports None for an unknown parameter. */
- (void)testGetParameterSubGroupReportsNoneForAnUnknownParameter
{
	XCTAssertEqual([self.api getParameterSubGroup:kGroupingTestMissing],
				   (FxParameterId)kFxParameterId_None);
}

#pragma mark setParameterSubGroup:toParameter:

/*! @abstract Reparenting is refused and leaves the child's parent unchanged. */
- (void)testReparentingIsNotSupported
{
	[self installPopulatedGroup];

	XCTAssertFalse([self.api setParameterSubGroup:kGroupingTestGroup
									  toParameter:kGroupingTestChildA]);
	XCTAssertEqual([self.api getParameterSubGroup:kGroupingTestChildA], kGroupingTestGroup,
				   @"the refused call changes nothing");
}

@end
