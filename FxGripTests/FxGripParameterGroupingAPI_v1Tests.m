//
//  FxGripParameterGroupingAPI_v1Tests.m
//  FxGripTests
//
//  Unit tests for the grouping wrapper. The subgroup query reads the parameter type from
//  the dynamic API; every other query walks the effect's own parameter objects rather
//  than a host API, because FxPlug ships no grouping API.
//

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
static NSNotificationCenter *FxGroupingTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

#pragma mark - Test doubles

/*!
	Stands in for one of the effect's parameter objects. It reports conformance to
	FxSubParameters through -conformsToProtocol: so a leaf and a group can be told apart
	without adopting the full parameter protocol.
*/
@interface FxGroupingTestParameter : NSObject
@property (nonatomic, assign) FxParameterId parameterID;
@property (nonatomic, assign) FxParameterId parameterParentID;
@property (nonatomic, strong) NSArray<FxGroupingTestParameter *> *children;
@property (nonatomic, assign) BOOL isSubParameterContainer;
@end

@implementation FxGroupingTestParameter

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
	if (strcmp(protocol_getName(aProtocol), "FxSubParameters") == 0) {
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
@interface FxGroupingTestDynamicAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *types;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *requestedParameters;
@end

@implementation FxGroupingTestDynamicAPI

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
	FxTileableEffectBase's designated initializer registers into the process-wide
	notification center, so the wrapper is exercised against a stub carrying an isolated
	notifier. The grouping queries subscript the effect for each parameter object.
*/
@interface FxGroupingTestStubEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, FxGroupingTestParameter *> *parameters;
@end

@implementation FxGroupingTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxGroupingTestMakePriorityCenter();
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
@property (nonatomic, strong) FxGroupingTestStubEffect *effect;
@property (nonatomic, strong) FxGroupingTestDynamicAPI *dynamicAPI;
@property (nonatomic, strong) FxGripParameterGroupingAPI_v1 *api;
@end

@implementation FxGripParameterGroupingAPI_v1Tests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGroupingTestStubEffect.alloc init];
	self.dynamicAPI = [FxGroupingTestDynamicAPI.alloc init];
	self.api = [FxGripParameterGroupingAPI_v1.alloc initWithAPI:nil
											  dynamicParamAPIv4:(id)self.dynamicAPI
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

- (FxGroupingTestParameter *)addParameter:(FxParameterId)parameterID
								   parent:(FxParameterId)parentID
								container:(BOOL)container
{
	FxGroupingTestParameter *parameter = [FxGroupingTestParameter.alloc init];
	parameter.parameterID = parameterID;
	parameter.parameterParentID = parentID;
	parameter.isSubParameterContainer = container;
	self.effect.parameters[@(parameterID)] = parameter;
	return parameter;
}

/*! A group holding two children, all three registered with the effect. */
- (FxGroupingTestParameter *)installPopulatedGroup
{
	FxGroupingTestParameter *group = [self addParameter:kGroupingTestGroup
												 parent:kFxParameterId_TopLevelGroup
											  container:YES];
	FxGroupingTestParameter *childA = [self addParameter:kGroupingTestChildA
												  parent:kGroupingTestGroup
											   container:NO];
	FxGroupingTestParameter *childB = [self addParameter:kGroupingTestChildB
												  parent:kGroupingTestGroup
											   container:NO];
	group.children = @[childA, childB];
	return group;
}

#pragma mark isSubGroup:

- (void)testAGroupTypedParameterIsASubGroup
{
	self.dynamicAPI.types[@(kGroupingTestGroup)] = @(FxParameterType_Group);

	XCTAssertTrue([self.api isSubGroup:kGroupingTestGroup]);
	XCTAssertEqualObjects(self.dynamicAPI.requestedParameters, @[@(kGroupingTestGroup)]);
}

- (void)testAParameterOfAnyOtherTypeIsNotASubGroup
{
	self.dynamicAPI.types[@(kGroupingTestLeaf)] = @(FxParameterType_Float);

	XCTAssertFalse([self.api isSubGroup:kGroupingTestLeaf]);
}

- (void)testAnUnknownParameterIsNotASubGroup
{
	XCTAssertFalse([self.api isSubGroup:kGroupingTestMissing]);
}

- (void)testWithoutADynamicAPINothingIsASubGroup
{
	FxGripParameterGroupingAPI_v1 *api =
		[FxGripParameterGroupingAPI_v1.alloc initWithAPI:nil
									   dynamicParamAPIv4:nil
												  effect:(id)self.effect];

	XCTAssertFalse([api isSubGroup:kGroupingTestGroup],
				   @"a missing dynamic API reports the None type");
}

#pragma mark hasSubParameters:

- (void)testAGroupHoldingChildrenHasSubParameters
{
	[self installPopulatedGroup];

	XCTAssertTrue([self.api hasSubParameters:kGroupingTestGroup]);
}

- (void)testAnEmptyGroupHasNoSubParameters
{
	[self addParameter:kGroupingTestGroup parent:kFxParameterId_TopLevelGroup container:YES];

	XCTAssertFalse([self.api hasSubParameters:kGroupingTestGroup]);
}

- (void)testAParameterThatHoldsNoChildrenHasNoSubParameters
{
	[self addParameter:kGroupingTestLeaf parent:kFxParameterId_TopLevelGroup container:NO];

	XCTAssertFalse([self.api hasSubParameters:kGroupingTestLeaf]);
}

- (void)testAnUnknownParameterHasNoSubParameters
{
	XCTAssertFalse([self.api hasSubParameters:kGroupingTestMissing]);
}

#pragma mark parameterSubCount:

- (void)testParameterSubCountReportsTheChildCount
{
	[self installPopulatedGroup];

	XCTAssertEqual([self.api parameterSubCount:kGroupingTestGroup], (UInt32)2);
}

- (void)testParameterSubCountIsZeroForAParameterThatHoldsNoChildren
{
	[self addParameter:kGroupingTestLeaf parent:kFxParameterId_TopLevelGroup container:NO];

	XCTAssertEqual([self.api parameterSubCount:kGroupingTestLeaf], (UInt32)0);
}

- (void)testParameterSubCountIsZeroForAnUnknownParameter
{
	XCTAssertEqual([self.api parameterSubCount:kGroupingTestMissing], (UInt32)0);
}

#pragma mark parameterIDAtSubIndex:fromParameter:

- (void)testParameterIDAtSubIndexReportsEachChildInOrder
{
	[self installPopulatedGroup];

	XCTAssertEqual([self.api parameterIDAtSubIndex:0 fromParameter:kGroupingTestGroup],
				   kGroupingTestChildA);
	XCTAssertEqual([self.api parameterIDAtSubIndex:1 fromParameter:kGroupingTestGroup],
				   kGroupingTestChildB);
}

- (void)testParameterIDAtSubIndexIsZeroPastTheLastChild
{
	[self installPopulatedGroup];

	XCTAssertEqual([self.api parameterIDAtSubIndex:2 fromParameter:kGroupingTestGroup],
				   (FxParameterId)0);
}

- (void)testParameterIDAtSubIndexIsZeroForAParameterThatHoldsNoChildren
{
	[self addParameter:kGroupingTestLeaf parent:kFxParameterId_TopLevelGroup container:NO];

	XCTAssertEqual([self.api parameterIDAtSubIndex:0 fromParameter:kGroupingTestLeaf],
				   (FxParameterId)0);
}

- (void)testParameterIDAtSubIndexIsZeroForAnUnknownParameter
{
	XCTAssertEqual([self.api parameterIDAtSubIndex:0 fromParameter:kGroupingTestMissing],
				   (FxParameterId)0);
}

#pragma mark getParameterSubGroup:

- (void)testGetParameterSubGroupReportsTheParentOfAChild
{
	[self installPopulatedGroup];

	XCTAssertEqual([self.api getParameterSubGroup:kGroupingTestChildA], kGroupingTestGroup);
}

- (void)testGetParameterSubGroupReportsTheTopLevelGroupForATopLevelParameter
{
	[self addParameter:kGroupingTestLeaf parent:kFxParameterId_TopLevelGroup container:NO];

	XCTAssertEqual([self.api getParameterSubGroup:kGroupingTestLeaf],
				   (FxParameterId)kFxParameterId_TopLevelGroup);
}

- (void)testGetParameterSubGroupReportsNoneForAnUnknownParameter
{
	XCTAssertEqual([self.api getParameterSubGroup:kGroupingTestMissing],
				   (FxParameterId)kFxParameterId_None);
}

#pragma mark setParameterSubGroup:toParameter:

- (void)testReparentingIsNotSupported
{
	[self installPopulatedGroup];

	XCTAssertFalse([self.api setParameterSubGroup:kGroupingTestGroup
									  toParameter:kGroupingTestChildA]);
	XCTAssertEqual([self.api getParameterSubGroup:kGroupingTestChildA], kGroupingTestGroup,
				   @"the refused call changes nothing");
}

@end
