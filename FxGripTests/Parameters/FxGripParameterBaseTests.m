//
//  FxGripParameterBaseTests.m
//  FxGripTests
//
//  Unit tests for the shared parameter base: the designated initializer's type gate and
//  the state it captures, the abstract class entry points, the name and flag accessors that
//  talk to the host, the state-participation walk, the managed selector, the timing
//  conversions, the coder branch, and the flag-caching notification handlers the
//  initializer installs on the effect's notifier.
//
//  FxGripParameterBase and FxGripParameter are abstract, so the concrete subclasses stand in:
//  FxGripFloatParameter for a state parameter and FxGripPushButtonParameter for one that
//  carries no state.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripParameter.h>
#import <FxGrip/FxGripFloatParameter.h>
#import <FxGrip/FxGripPushButtonParameter.h>
#import <FxGrip/FxGripParameterSettingAPI_v5.h>
#import <FxGrip/FxGripAPINotifications.h>

// Implemented on the base but absent from the public header.
@interface FxGripParameter (FxGripParameterBaseTests)
- (void)removeObservers;
- (BOOL)flagIsDefault;
- (SEL)parameterSelector;
- (BOOL)addTags;
- (void)timelineTime:(CMTime *)timelineTime fromImageTime:(CMTime)time;
- (void)imageTime:(CMTime *)imageTime fromTimelineTime:(CMTime)time;
@end

// NSCoder+FxPlug.h imports BEFoundation, which the test bundle does not link; the two
// accessors the coder branch reads are declared locally instead.
@interface NSCoder (FxGripParameterBaseTests)
@property CMTime renderTime;
@property (readonly) BOOL isFxPluginStateEncoder;
@end

static const FxParameterId kBaseTestParameter = 91;
static const FxParameterId kBaseTestParentParameter = 92;

@interface FxGripParameterBaseTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
// The notifier holds its observers weakly, so every parameter under test is retained.
@property (nonatomic, strong) NSMutableArray *retainedParameters;
@end

@implementation FxGripParameterBaseTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamClassTestEffect.alloc init];
	self.retainedParameters = NSMutableArray.new;
}

- (void)tearDown
{
	self.retainedParameters = nil;
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSMutableDictionary *)floatConfigWithExtra:(NSDictionary *)extra
{
	return FxGripParamClassTestConfig(kBaseTestParameter, kFxParameterType_Float, @"Amount", extra);
}

- (FxGripFloatParameter *)makeParameterWithID:(FxParameterId)parameterID extra:(NSDictionary *)extra
{
	NSMutableDictionary *config = FxGripParamClassTestConfig(parameterID, kFxParameterType_Float, @"Amount", extra);
	FxGripFloatParameter *parameter = [FxGripFloatParameter.alloc initWithDictionary:config effect:(id)self.effect];
	if (parameter) {
		[self.retainedParameters addObject:parameter];
	}
	return parameter;
}

- (FxGripFloatParameter *)makeParameterWithExtra:(NSDictionary *)extra
{
	return [self makeParameterWithID:kBaseTestParameter extra:extra];
}

#pragma mark Designated initializer

- (void)testTheInitializerCapturesTheIdentityDeclaredByTheConfiguration
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:@{kFxParameterProperty_ParentId: @(kBaseTestParentParameter)}];

	XCTAssertNotNil(parameter);
	XCTAssertEqual(parameter.parameterID, kBaseTestParameter);
	XCTAssertEqual(parameter.parameterParentID, kBaseTestParentParameter);
	XCTAssertEqualObjects((id)parameter.effect, self.effect);
	XCTAssertTrue(parameter.addedToEffect);
	XCTAssertNil(parameter.error);
}

- (void)testAParameterOutsideAnyGroupNamesTheTopLevelGroupAsItsParent
{
	XCTAssertEqual([self makeParameterWithExtra:nil].parameterParentID,
				   (FxParameterId)kFxParameterId_TopLevelGroup);
}

- (void)testTheInitializerCapturesTheDeclaredFlags
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];

	XCTAssertEqual(parameter.parameterCurrentFlags, (FxParameterFlags)kFxParameterFlag_HIDDEN);
}

- (void)testTheInitializerRefusesAConfigurationOfAnotherType
{
	NSDictionary *config = FxGripParamClassTestConfig(kBaseTestParameter, kFxParameterType_Toggle, @"Amount", nil);

	XCTAssertNil([FxGripFloatParameter.alloc initWithDictionary:config effect:(id)self.effect]);
}

- (void)testAMutableConfigurationIsAdoptedRatherThanCopied
{
	NSMutableDictionary *config = [self floatConfigWithExtra:@{kFxParameterProperty_Selector: @"manageAmount"}];
	FxGripFloatParameter *parameter = [FxGripFloatParameter.alloc initWithDictionary:config effect:(id)self.effect];
	[self.retainedParameters addObject:parameter];

	config[kFxParameterProperty_Selector] = @"manageOther";

	XCTAssertEqualObjects(NSStringFromSelector(parameter.parameterSelector), @"manageOther:atTime:error:",
						  @"the parameter reads through to the same record");
}

- (void)testAnImmutableConfigurationIsCopiedIntoTheParameter
{
	NSDictionary *config = [self floatConfigWithExtra:@{kFxParameterProperty_Selector: @"manageAmount"}].copy;
	FxGripFloatParameter *parameter = [FxGripFloatParameter.alloc initWithDictionary:config effect:(id)self.effect];
	[self.retainedParameters addObject:parameter];

	XCTAssertEqualObjects(NSStringFromSelector(parameter.parameterSelector), @"manageAmount:atTime:error:");
}

#pragma mark Abstract entry points

- (void)testTheAbstractTypeAccessorsRefuseToAnswer
{
	XCTAssertThrowsSpecificNamed([FxGripParameter parameterType], NSException, NSInternalInconsistencyException);
	XCTAssertThrowsSpecificNamed([FxGripParameter parameterTypeString], NSException, NSInternalInconsistencyException);
}

- (void)testTheAbstractCreationEntryPointRefusesToAnswer
{
	id parameterClass = FxGripParameter.class;
	SEL creation = @selector(addParameter:toEffect:);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	XCTAssertThrowsSpecificNamed([parameterClass performSelector:creation
													  withObject:[self floatConfigWithExtra:nil]
													  withObject:(id)self.effect],
								 NSException,
								 NSInternalInconsistencyException);
#pragma clang diagnostic pop
}

- (void)testAParameterCarriesNoExtensionKeyOfItsOwn
{
	XCTAssertEqualObjects([self makeParameterWithExtra:nil].extKey, @"");
}

- (void)testTheChangeBracketAcceptsEveryTime
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	NSError *error = nil;

	XCTAssertTrue([parameter startChangedTime:FxGripParamClassTestTime(0, 1) error:&error]);
	XCTAssertTrue([parameter endChangedTime:FxGripParamClassTestTime(0, 1) error:&error]);
	XCTAssertNil(error);
}

- (void)testTagInstallationSucceedsWithoutATagsAPI
{
	XCTAssertTrue([[self makeParameterWithExtra:nil] addTags]);
}

#pragma mark Name

- (void)testTheNameIsReadFromTheDynamicParameterAPI
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	self.effect.apiManager.dynamicParamAPIv3.name = @"Renamed";

	XCTAssertEqualObjects(parameter.parameterName, @"Renamed");
}

- (void)testSettingTheNameWritesThroughTheDynamicParameterAPI
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	parameter.parameterName = @"Renamed";

	XCTAssertEqualObjects(self.effect.apiManager.dynamicParamAPIv3.setNameCalls,
						  (@[@{@"id": @(kBaseTestParameter), @"name": @"Renamed"}]));
	XCTAssertNil(parameter.error);
}

- (void)testAFailedNameWriteIsRecordedOnTheParameter
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	NSError *failure = [NSError errorWithDomain:@"FxGripParameterBaseTest" code:2 userInfo:nil];
	self.effect.apiManager.dynamicParamAPIv3.nameError = failure;

	parameter.parameterName = @"Renamed";

	XCTAssertEqualObjects(parameter.error, failure);
}

#pragma mark Flags

- (void)testTheParameterFlagsAreReadFromTheRetrievalAPI
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_DISABLED;

	XCTAssertEqual(parameter.parameterFlags, (FxParameterFlags)kFxParameterFlag_DISABLED);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.getFlagsParameterIDs, @[@(kBaseTestParameter)]);
}

- (void)testAFlagsReadTheHostRefusesReportsTheInvalidMarker
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	XCTAssertEqual(parameter.parameterFlags, (FxParameterFlags)kFxParameterFlag_INVALID);
}

- (void)testSettingTheParameterFlagsWritesThroughTheSettingAPI
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	parameter.parameterFlags = kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls.firstObject[@"flags"],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED));
}

/*!
	The shared flag accessors split their source: the ones the base declares read the flags
	the configuration staged, while -flagDisabled reads the host on every access.
*/
- (void)testTheBaseFlagAccessorsReadTheStagedFlagsWhileDisabledReadsTheHost
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_DISABLED;

	XCTAssertTrue(parameter.flagHidden);
	XCTAssertTrue(parameter.flagDisabled);
	XCTAssertFalse(parameter.flagNoState);
	XCTAssertFalse(parameter.flagInvalid);
	XCTAssertFalse(parameter.flagCaching);
}

- (void)testEveryStagedFlagBitIsReportedByItsOwnAccessor
{
	FxParameterFlags staged = kFxParameterFlag_DONT_DISPLAY_IN_DASHBOARD | kFxParameterFlag_INVALID
		| kFxParameterFlag_NOSTATE | kFxParameterFlag_NO_DEBUG | kFxParameterFlag_IN_DEBUG_MODE
		| kFxParameterFlag_HIDDEN_PROXY | kFxParameterFlag_CACHE | kFxParameterFlag_CACHEDIRTY;
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(staged)}];

	XCTAssertTrue(parameter.flagDontDisplayInDashboard);
	XCTAssertTrue(parameter.flagInvalid);
	XCTAssertTrue(parameter.flagNoState);
	XCTAssertTrue(parameter.flagNoDebug);
	XCTAssertTrue(parameter.flagInDebugMode);
	XCTAssertTrue(parameter.flagHiddenProxy);
	XCTAssertTrue(parameter.flagCaching);
	XCTAssertTrue(parameter.flagCacheDirty);
}

- (void)testTogglingAStagedFlagWritesTheWholeStagedWordBack
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];

	parameter.flagNoDebug = YES;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls.firstObject[@"flags"],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_NO_DEBUG));
}

- (void)testSettingAStagedFlagToItsCurrentStateWritesNothing
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];

	parameter.flagHidden = YES;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls, @[]);
}

- (void)testClearingAStagedFlagWritesTheWordWithoutThatBit
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN | kFxParameterFlag_NOSTATE)}];

	parameter.flagHidden = NO;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls.firstObject[@"flags"],
						  @(kFxParameterFlag_NOSTATE));
}

- (void)testAParameterWithoutDeclaredFlagsStagesTheDefaultFlags
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	XCTAssertEqual(parameter.parameterCurrentFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
	XCTAssertFalse([parameter flagIsDefault], @"the default marker names the absence of every flag");
}

#pragma mark Flush

- (void)testFlushingAParameterThatIsNotCachingWritesNothing
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	[parameter parameterFlush];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls, @[]);
}

- (void)testFlushingACachingParameterClearsTheCacheBitInASingleWrite
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_CACHE | kFxParameterFlag_HIDDEN)}];

	[parameter parameterFlush];

	NSArray *writes = self.effect.apiManager.paramSetAPIv5.setFlagsCalls;
	XCTAssertEqual(writes.count, (NSUInteger)1);
	XCTAssertEqualObjects(writes.firstObject[@"flags"], @(kFxParameterFlag_HIDDEN),
						  @"the flush drops the cache bit and leaves every other flag staged");
	XCTAssertFalse(parameter.flagCaching);
	XCTAssertTrue(parameter.flagHidden);
}

#pragma mark Parent and creation callback

- (void)testTheParentCanBeReassigned
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	[parameter setParameterParentID:kBaseTestParentParameter];

	XCTAssertEqual(parameter.parameterParentID, kBaseTestParentParameter);
}

/*! The creation callback stages a parameter that is not yet in the effect; a parameter
	built from a configuration already is, so the callback changes nothing. */
- (void)testTheCreationCallbackLeavesAnAlreadyAddedParameterAlone
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	[parameter createdWithFlags:kFxParameterFlag_HIDDEN parentID:kBaseTestParentParameter];

	XCTAssertEqual(parameter.parameterParentID, (FxParameterId)kFxParameterId_TopLevelGroup);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls, @[]);
}

#pragma mark State participation

- (void)testAStateParameterOutsideAnyGroupHasState
{
	XCTAssertTrue([self makeParameterWithExtra:nil].hasState);
}

- (void)testAParameterThatIsNotAStateParameterNeverHasState
{
	NSDictionary *config = FxGripParamClassTestConfig(kBaseTestParameter, kFxParameterType_PushButton, @"Reset", nil);
	FxGripPushButtonParameter *button = [FxGripPushButtonParameter.alloc initWithDictionary:config
																					 effect:(id)self.effect];
	[self.retainedParameters addObject:button];

	XCTAssertFalse(button.hasState);
}

- (void)testTheStatelessFlagRemovesTheParameterFromTheState
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_NOSTATE)}];

	XCTAssertFalse(parameter.hasState);
}

- (void)testAStatelessAncestorRemovesTheParameterFromTheState
{
	NSDictionary *parentConfig = FxGripParamClassTestConfig(kBaseTestParentParameter, kFxParameterType_Float, @"Group",
														@{kFxParameterProperty_Flags: @(kFxParameterFlag_NOSTATE)});
	FxGripFloatParameter *parent = [FxGripFloatParameter.alloc initWithDictionary:parentConfig
																		   effect:(id)self.effect];
	[self.retainedParameters addObject:parent];
	self.effect.parameters[@(kBaseTestParentParameter)] = parent;
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_ParentId: @(kBaseTestParentParameter)}];

	XCTAssertFalse(parameter.hasState);
}

- (void)testAParameterInsideAStatefulGroupKeepsItsState
{
	NSDictionary *parentConfig = FxGripParamClassTestConfig(kBaseTestParentParameter, kFxParameterType_Float, @"Group", nil);
	FxGripFloatParameter *parent = [FxGripFloatParameter.alloc initWithDictionary:parentConfig
																		   effect:(id)self.effect];
	[self.retainedParameters addObject:parent];
	self.effect.parameters[@(kBaseTestParentParameter)] = parent;
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_ParentId: @(kBaseTestParentParameter)}];

	XCTAssertTrue(parameter.hasState);
}

#pragma mark Managed selector

- (void)testTheManagedSelectorIsTheDeclaredNameWithTheChangeSignature
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Selector: @"manageAmount"}];

	XCTAssertEqualObjects(NSStringFromSelector(parameter.parameterSelector), @"manageAmount:atTime:error:");
}

- (void)testASelectorWithoutTheManagePrefixIsRefused
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Selector: @"handleAmount"}];

	XCTAssertTrue(parameter.parameterSelector == NULL);
}

- (void)testAParameterWithoutADeclaredSelectorHasNoManagedSelector
{
	XCTAssertTrue([self makeParameterWithExtra:nil].parameterSelector == NULL);
}

#pragma mark Timing conversions

- (void)testTheTimelineConversionAsksTheTimingAPIForThisParameter
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	CMTime timeline = FxGripParamClassTestTime(0, 1);

	[parameter timelineTime:&timeline fromImageTime:FxGripParamClassTestTime(6, 30)];

	XCTAssertEqual(timeline.value, (int64_t)12);
	XCTAssertEqualObjects(self.effect.apiManager.timingAPIv4.queries.lastObject[@"accessor"], @"timeline");
	XCTAssertEqualObjects(self.effect.apiManager.timingAPIv4.queries.lastObject[@"id"], @(kBaseTestParameter));
}

- (void)testTheImageConversionAsksTheTimingAPIForThisParameter
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	CMTime image = FxGripParamClassTestTime(0, 1);

	[parameter imageTime:&image fromTimelineTime:FxGripParamClassTestTime(12, 30)];

	XCTAssertEqual(image.value, (int64_t)6);
	XCTAssertEqualObjects(self.effect.apiManager.timingAPIv4.queries.lastObject[@"accessor"], @"image");
}

#pragma mark Coding

- (void)testAParameterSupportsSecureCoding
{
	XCTAssertTrue(FxGripParameter.supportsSecureCoding);
}

- (void)testDecodingReturnsTheParameterItself
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:NO];

	XCTAssertEqualObjects([parameter initWithCoder:archiver], parameter);
}

- (void)testAPlainCoderIsNotAPluginStateEncoderAndReadsNoValue
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:NO];

	XCTAssertFalse(archiver.isFxPluginStateEncoder);

	[parameter encodeWithCoder:archiver];

	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.reads, @[]);
}

- (void)testAPluginStateCoderReadsTheValueAtTheCodersRenderTime
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:NO];
	archiver.renderTime = FxGripParamClassTestTime(13, 30);

	XCTAssertTrue(archiver.isFxPluginStateEncoder);

	[parameter encodeWithCoder:archiver];

	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"float");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @13);
}

#pragma mark Flag-caching notifications

/*! Posts the payload the API wrappers post: the effect is the notification object and the
	nested parameter dictionary names the parameter the traffic is about. */
- (NSMutableDictionary *)postFlagsNotification:(NSNotificationName)name
									 parameter:(FxGripFloatParameter *)parameter
										 flags:(FxParameterFlags)flags
{
	NSMutableDictionary *nested = NSMutableDictionary.new;
	nested[kFxParameterProperty_Id] = @(parameter.parameterID);
	nested[kFxParameterProperty_Flags] = @(flags);
	NSMutableDictionary *userInfo = NSMutableDictionary.new;
	userInfo[kFxParameterProperty_Id] = @(parameter.parameterID);
	userInfo.fxParameter = nested;

	[self.effect.notifier postNotificationName:name object:self.effect userInfo:userInfo];

	return userInfo;
}

/*! A setting wrapper over the effect's stub APIs, so a flags write travels the path the
	host takes: the pre-notification, the host call, then the completion notification. */
- (FxGripParameterSettingAPI_v5 *)settingAPI
{
	return [FxGripParameterSettingAPI_v5.alloc initWithAPI:(id)self.effect.apiManager.paramSetAPIv5
											paramGetAPIv6:(id)self.effect.apiManager.paramGetAPIv6
										parameterInfoAPIv1:nil
												   effect:(id)self.effect];
}

- (void)testACachingParameterAnswersTheFlagsQueryFromItsStagedFlags
{
	FxParameterFlags staged = kFxParameterFlag_CACHE | kFxParameterFlag_HIDDEN;
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(staged)}];

	NSMutableDictionary *userInfo = [self postFlagsNotification:FxGripNotifyAPI_ParameterGetFlagsPreName
													  parameter:parameter
														  flags:kFxParameterFlag_DEFAULT];

	XCTAssertEqualObjects(userInfo.fxResult, @YES);
	XCTAssertEqualObjects(userInfo.fxParameter[kFxParameterProperty_Flags], @(staged));
}

- (void)testAParameterThatIsNotCachingLeavesTheFlagsQueryToTheHost
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	NSMutableDictionary *userInfo = [self postFlagsNotification:FxGripNotifyAPI_ParameterGetFlagsPreName
													  parameter:parameter
														  flags:kFxParameterFlag_DEFAULT];

	XCTAssertNil(userInfo.fxResult);
}

- (void)testAFlagsWriteThatTurnsCachingOnIsAbsorbedIntoTheStagedFlags
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	NSMutableDictionary *setUserInfo = [self postFlagsNotification:FxGripNotifyAPI_ParameterSetFlagsPreName
														 parameter:parameter
															 flags:kFxParameterFlag_CACHE | kFxParameterFlag_DISABLED];

	XCTAssertEqualObjects(setUserInfo.fxResult, @YES, @"the host is not asked to store a cached write");

	NSMutableDictionary *getUserInfo = [self postFlagsNotification:FxGripNotifyAPI_ParameterGetFlagsPreName
														 parameter:parameter
															 flags:kFxParameterFlag_DEFAULT];

	XCTAssertEqualObjects(getUserInfo.fxParameter[kFxParameterProperty_Flags],
						  @(kFxParameterFlag_CACHE | kFxParameterFlag_DISABLED | kFxParameterFlag_CACHEDIRTY));
}

- (void)testAFlagsWriteWithoutCachingLosesOnlyTheDirtyMarkerAndReachesTheHost
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	NSMutableDictionary *userInfo = [self postFlagsNotification:FxGripNotifyAPI_ParameterSetFlagsPreName
													  parameter:parameter
														  flags:kFxParameterFlag_DISABLED | kFxParameterFlag_CACHEDIRTY];

	XCTAssertNil(userInfo.fxResult);
	XCTAssertEqualObjects(userInfo.fxParameter[kFxParameterProperty_Flags], @(kFxParameterFlag_DISABLED));
}

- (void)testACompletedSavingWriteBecomesTheParametersCurrentFlags
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	[self postFlagsNotification:FxGripNotifyAPI_ParameterSetFlagsName
					  parameter:parameter
						  flags:kFxParameterFlag_SAVING | kFxParameterFlag_HIDDEN | kFxParameterFlag_CACHEDIRTY];

	XCTAssertEqual(parameter.parameterCurrentFlags, (FxParameterFlags)kFxParameterFlag_HIDDEN);
}

- (void)testACompletedWriteThatIsNotSavingLeavesTheCurrentFlagsAlone
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];

	[self postFlagsNotification:FxGripNotifyAPI_ParameterSetFlagsName
					  parameter:parameter
						  flags:kFxParameterFlag_DISABLED];

	XCTAssertEqual(parameter.parameterCurrentFlags, (FxParameterFlags)kFxParameterFlag_HIDDEN);
}

- (void)testACachingParameterDoesNotAnswerAnotherParametersFlagsQuery
{
	[self makeParameterWithID:kBaseTestParentParameter
						extra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_CACHE | kFxParameterFlag_HIDDEN)}];
	FxGripFloatParameter *queried = [self makeParameterWithID:kBaseTestParameter extra:nil];

	NSMutableDictionary *userInfo = [self postFlagsNotification:FxGripNotifyAPI_ParameterGetFlagsPreName
													 parameter:queried
														 flags:kFxParameterFlag_DEFAULT];

	XCTAssertNil(userInfo.fxResult);
	XCTAssertEqualObjects(userInfo.fxParameter[kFxParameterProperty_Flags], @(kFxParameterFlag_DEFAULT));
}

- (void)testACompletedWriteReachesOnlyTheParameterItNames
{
	FxGripFloatParameter *written = [self makeParameterWithID:kBaseTestParameter extra:nil];
	FxParameterFlags bystanderFlags = kFxParameterFlag_CACHE | kFxParameterFlag_HIDDEN;
	FxGripFloatParameter *bystander = [self makeParameterWithID:kBaseTestParentParameter
														 extra:@{kFxParameterProperty_Flags: @(bystanderFlags)}];

	[self postFlagsNotification:FxGripNotifyAPI_ParameterSetFlagsName
					  parameter:written
						  flags:kFxParameterFlag_SAVING | kFxParameterFlag_DISABLED];

	XCTAssertEqual(written.parameterCurrentFlags, (FxParameterFlags)kFxParameterFlag_DISABLED);
	XCTAssertEqual(bystander.parameterCurrentFlags, bystanderFlags);
	XCTAssertTrue(bystander.flagCaching, @"the staged word of the untargeted parameter is untouched");
}

- (void)testRemovingTheObserversEndsTheFlagsTraffic
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_CACHE)}];

	[parameter removeObservers];

	NSMutableDictionary *userInfo = [self postFlagsNotification:FxGripNotifyAPI_ParameterGetFlagsPreName
													 parameter:parameter
														 flags:kFxParameterFlag_DEFAULT];

	XCTAssertNil(userInfo.fxResult);
}

#pragma mark Flag writes through the setting wrapper

- (void)testAHostWriteThroughTheWrapperBecomesTheParametersCurrentFlags
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	XCTAssertTrue([self.settingAPI setParameterFlags:kFxParameterFlag_HIDDEN toParameter:kBaseTestParameter]);

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls.firstObject[@"flags"],
						  @(kFxParameterFlag_HIDDEN));
	XCTAssertEqual(parameter.parameterCurrentFlags, (FxParameterFlags)kFxParameterFlag_HIDDEN);
}

- (void)testACachingParametersWriteThroughTheWrapperStagesWithoutMovingTheCurrentFlags
{
	FxParameterFlags staged = kFxParameterFlag_CACHE | kFxParameterFlag_HIDDEN;
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(staged)}];

	XCTAssertTrue([self.settingAPI setParameterFlags:kFxParameterFlag_CACHE | kFxParameterFlag_DISABLED
										 toParameter:kBaseTestParameter]);

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls, @[]);
	XCTAssertEqual(parameter.parameterCurrentFlags, staged);

	NSMutableDictionary *query = [self postFlagsNotification:FxGripNotifyAPI_ParameterGetFlagsPreName
												  parameter:parameter
													  flags:kFxParameterFlag_DEFAULT];

	XCTAssertEqualObjects(query.fxParameter[kFxParameterProperty_Flags],
						  @(kFxParameterFlag_CACHE | kFxParameterFlag_DISABLED | kFxParameterFlag_CACHEDIRTY),
						  @"the write lands in the staged word");
}

@end
