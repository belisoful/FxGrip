//
//  FxGripGroupParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripGroupParameter: the subgroup bracket +addParameter:toEffect: opens
//  around the effect's recursion into the group's children, the failure paths of that
//  bracket, and the child collection an instance maintains.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripGroupParameter.h>
#import <FxGrip/FxGripFloatParameter.h>

static const FxParameterId kGroupTestParameter = 71;

/*! Records how far creation had progressed at the moment the recursion ran. */
@interface FxGripGroupTestEffect : FxGripParamClassTestEffect
@property (nonatomic, assign) NSUInteger creationCallsAtRecursion;
@end

@implementation FxGripGroupTestEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError *_Nullable *_Nullable)error
{
	self.creationCallsAtRecursion = self.apiManager.paramCreateAPIv5.calls.count;
	return [super addParametersWithGroupID:groupID error:error];
}

@end

@interface FxGripGroupParameterTests : XCTestCase
@property (nonatomic, strong) FxGripGroupTestEffect *effect;
@end

@implementation FxGripGroupParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripGroupTestEffect.alloc init];
}

- (void)tearDown
{
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSArray<NSDictionary *> *)calls
{
	return self.effect.creationCalls;
}

- (NSArray<NSString *> *)calledMethods
{
	NSMutableArray<NSString *> *methods = NSMutableArray.new;
	for (NSDictionary *call in self.calls) {
		[methods addObject:call[@"method"]];
	}
	return methods;
}

- (BOOL)addGroupWithExtra:(NSDictionary *)extra
{
	NSDictionary *config = FxGripParamClassTestConfig(kGroupTestParameter, kFxParameterType_Group, @"Shape", extra);
	return [FxGripGroupParameter addParameter:config toEffect:(id)self.effect];
}

- (FxGripGroupParameter *)makeGroupWithID:(FxParameterId)parameterID
{
	NSDictionary *config = FxGripParamClassTestConfig(parameterID, kFxParameterType_Group, @"Shape", nil);
	return [FxGripGroupParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

- (FxGripFloatParameter *)makeLeafWithID:(FxParameterId)parameterID
{
	NSDictionary *config = FxGripParamClassTestConfig(parameterID, kFxParameterType_Float, @"Amount", nil);
	return [FxGripFloatParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

- (void)testTheGroupClassReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripGroupParameter.parameterType, FxParameterType_Group);
	XCTAssertEqualObjects(FxGripGroupParameter.parameterTypeString, kFxParameterType_Group);
}

#pragma mark Creation

- (void)testAGroupOpensASubGroupRecursesAndClosesIt
{
	XCTAssertTrue([self addGroupWithExtra:nil]);

	XCTAssertEqualObjects(self.calledMethods, (@[@"startgroup", @"endgroup"]));
	XCTAssertEqualObjects(self.calls.firstObject, (@{@"method": @"startgroup",
													 @"name": @"Shape",
													 @"id": @(kGroupTestParameter),
													 @"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.effect.addedGroupIDs, @[@(kGroupTestParameter)]);
}

- (void)testTheRecursionRunsInsideTheOpenSubGroup
{
	XCTAssertTrue([self addGroupWithExtra:nil]);

	XCTAssertEqual(self.effect.creationCallsAtRecursion, (NSUInteger)1,
				   @"the subgroup is open and not yet closed when the children are added");
}

- (void)testAGroupCarriesTheConfiguredFlags
{
	NSArray *declared = @[kParameterFlagString_COLLAPSED];

	XCTAssertTrue([self addGroupWithExtra:@{kFxParameterProperty_Flags: declared}]);

	XCTAssertEqualObjects(self.calls.firstObject[@"flags"], @(kFxParameterFlag_COLLAPSED));
}

- (void)testASubGroupTheHostRefusesSkipsTheRecursionAndTheClose
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self addGroupWithExtra:nil]);

	XCTAssertEqualObjects(self.calledMethods, @[@"startgroup"]);
	XCTAssertEqualObjects(self.effect.addedGroupIDs, @[]);
}

- (void)testACloseTheHostRefusesFailsTheGroupAfterTheChildrenAreAdded
{
	[self.effect.apiManager.paramCreateAPIv5.refusedMethods addObject:@"endgroup"];

	XCTAssertFalse([self addGroupWithExtra:nil]);

	XCTAssertEqualObjects(self.calledMethods, (@[@"startgroup", @"endgroup"]));
	XCTAssertEqualObjects(self.effect.addedGroupIDs, @[@(kGroupTestParameter)],
						  @"the children are added before the close is attempted");
}

/*! The recursion's result folds into the group's result, and the subgroup is closed either
	way so the parameter tree stays balanced. */
- (void)testAFailingChildListFailsTheGroupButStillClosesIt
{
	self.effect.groupRecursionSucceeds = NO;
	self.effect.groupRecursionError = [NSError errorWithDomain:@"FxGripGroupTest" code:1 userInfo:nil];

	XCTAssertFalse([self addGroupWithExtra:nil]);

	XCTAssertEqualObjects(self.calledMethods, (@[@"startgroup", @"endgroup"]));
}

#pragma mark Instance identity

- (void)testAGroupBuiltFromAConfigurationKnowsItsParameterID
{
	FxGripGroupParameter *group = [self makeGroupWithID:kGroupTestParameter];

	XCTAssertEqual(group.parameterID, kGroupTestParameter);
}

- (void)testAGroupBuiltFromAConfigurationKnowsItsEffect
{
	FxGripGroupParameter *group = [self makeGroupWithID:kGroupTestParameter];

	XCTAssertEqualObjects((id)group.effect, self.effect);
}

#pragma mark Children

- (void)testANewGroupHasNoChildren
{
	FxGripGroupParameter *group = [self makeGroupWithID:kGroupTestParameter];

	XCTAssertEqual(group.count, (NSUInteger)0);
	XCTAssertEqualObjects(group.children, @[]);
	XCTAssertEqual(group.allCount, (NSUInteger)0);
	XCTAssertEqualObjects(group.allChildren, @[]);
}

- (void)testAddingAChildAppendsItOnce
{
	FxGripGroupParameter *group = [self makeGroupWithID:kGroupTestParameter];
	FxGripFloatParameter *leaf = [self makeLeafWithID:72];

	XCTAssertTrue([group addChildParameter:leaf]);
	XCTAssertFalse([group addChildParameter:leaf], @"a parameter already in the group is refused");

	XCTAssertEqual(group.count, (NSUInteger)1);
	XCTAssertEqualObjects(group.children, @[leaf]);
	XCTAssertEqualObjects((id)group[0], leaf);
}

- (void)testRemovingAChildDropsItAndRefusesASecondRemoval
{
	FxGripGroupParameter *group = [self makeGroupWithID:kGroupTestParameter];
	FxGripFloatParameter *leaf = [self makeLeafWithID:72];
	[group addChildParameter:leaf];

	XCTAssertTrue([group removeChildParameter:leaf]);
	XCTAssertFalse([group removeChildParameter:leaf]);

	XCTAssertEqual(group.count, (NSUInteger)0);
}

- (void)testRemovingAParameterThatWasNeverAddedIsRefused
{
	FxGripGroupParameter *group = [self makeGroupWithID:kGroupTestParameter];

	XCTAssertFalse([group removeChildParameter:[self makeLeafWithID:72]]);
}

- (void)testAGroupEnumeratesItsChildrenInOrder
{
	FxGripGroupParameter *group = [self makeGroupWithID:kGroupTestParameter];
	FxGripFloatParameter *first = [self makeLeafWithID:72];
	FxGripFloatParameter *second = [self makeLeafWithID:73];
	[group addChildParameter:first];
	[group addChildParameter:second];

	NSMutableArray *seen = NSMutableArray.new;
	for (id<FxParameter> child in group) {
		[seen addObject:child];
	}

	XCTAssertEqualObjects(seen, (@[first, second]));
}

- (void)testAllChildrenFlattensEveryLevelOfTheTree
{
	FxGripGroupParameter *root = [self makeGroupWithID:kGroupTestParameter];
	FxGripGroupParameter *middle = [self makeGroupWithID:72];
	FxGripGroupParameter *inner = [self makeGroupWithID:73];
	FxGripFloatParameter *leaf = [self makeLeafWithID:74];
	[inner addChildParameter:leaf];
	[middle addChildParameter:inner];
	[root addChildParameter:middle];

	XCTAssertEqualObjects(root.allChildren, (@[leaf, inner, middle]),
						  @"each level lists its descendants before itself");
	XCTAssertEqual(root.count, (NSUInteger)1);
}

- (void)testAllCountMatchesTheNumberOfFlattenedChildren
{
	FxGripGroupParameter *root = [self makeGroupWithID:kGroupTestParameter];
	FxGripGroupParameter *middle = [self makeGroupWithID:72];
	FxGripGroupParameter *inner = [self makeGroupWithID:73];
	[inner addChildParameter:[self makeLeafWithID:74]];
	[middle addChildParameter:inner];
	[root addChildParameter:middle];

	XCTAssertEqual(root.allCount, (NSUInteger)3);
	XCTAssertEqual(root.allCount, root.allChildren.count);
}

- (void)testAllCountAgreesWithTheFlattenedListForATwoLevelTree
{
	FxGripGroupParameter *root = [self makeGroupWithID:kGroupTestParameter];
	FxGripGroupParameter *middle = [self makeGroupWithID:72];
	[middle addChildParameter:[self makeLeafWithID:73]];
	[root addChildParameter:middle];

	XCTAssertEqual(root.allCount, (NSUInteger)2);
	XCTAssertEqual(root.allChildren.count, (NSUInteger)2);
}

#pragma mark Collapsed flag

- (void)testTheCollapsedFlagIsReadFromTheParameterFlags
{
	FxGripGroupParameter *group = [self makeGroupWithID:kGroupTestParameter];

	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_DEFAULT;
	XCTAssertFalse(group.flagCollapsed);

	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_COLLAPSED;
	XCTAssertTrue(group.flagCollapsed);
}

- (void)testSettingTheCollapsedFlagWritesTheUpdatedFlagsToTheHost
{
	FxGripGroupParameter *group = [self makeGroupWithID:kGroupTestParameter];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_DEFAULT;

	group.flagCollapsed = YES;

	NSDictionary *write = self.effect.apiManager.paramSetAPIv5.setFlagsCalls.lastObject;
	XCTAssertEqualObjects(write[@"id"], @(kGroupTestParameter));
	XCTAssertTrue(((NSNumber *)write[@"flags"]).unsignedIntegerValue & kFxParameterFlag_COLLAPSED);
}

@end
