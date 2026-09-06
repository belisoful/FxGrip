/*!
	@file       FxGripParameterBaseTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterBaseTests
	@abstract   Tests the shared parameter base: the designated initializer, the abstract entry
	            points, the name and flag accessors, state participation, timing conversions,
	            coding, and the flag-caching notification handlers.
	@discussion Introduced in FxGrip 0.1.0. FxGripParameterBase and FxGripParameter are abstract,
	            so the concrete subclasses stand in. FxGripFloatParameter exercises a state
	            parameter and FxGripPushButtonParameter exercises a stateless one. The tests drive
	            a stub effect and inspect the recorded host API calls.
*/

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

/*! @abstract The initializer records the parameter id, parent id, effect, and added state from the configuration, leaving no error. */
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

/*! @abstract A parameter declared with no parent reports the top-level group as its parent id. */
- (void)testAParameterOutsideAnyGroupNamesTheTopLevelGroupAsItsParent
{
	XCTAssertEqual([self makeParameterWithExtra:nil].parameterParentID,
				   (FxParameterId)kFxParameterId_TopLevelGroup);
}

/*! @abstract The declared flag word becomes the parameter's current staged flags. */
- (void)testTheInitializerCapturesTheDeclaredFlags
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];

	XCTAssertEqual(parameter.parameterCurrentFlags, (FxParameterFlags)kFxParameterFlag_HIDDEN);
}

/*! @abstract Initializing a float parameter from a toggle configuration returns nil. */
- (void)testTheInitializerRefusesAConfigurationOfAnotherType
{
	NSDictionary *config = FxGripParamClassTestConfig(kBaseTestParameter, kFxParameterType_Toggle, @"Amount", nil);

	XCTAssertNil([FxGripFloatParameter.alloc initWithDictionary:config effect:(id)self.effect]);
}

/*! @abstract A mutable configuration is retained by reference, so a later mutation of the dictionary is visible through the parameter. */
- (void)testAMutableConfigurationIsAdoptedRatherThanCopied
{
	NSMutableDictionary *config = [self floatConfigWithExtra:@{kFxParameterProperty_Selector: @"manageAmount"}];
	FxGripFloatParameter *parameter = [FxGripFloatParameter.alloc initWithDictionary:config effect:(id)self.effect];
	[self.retainedParameters addObject:parameter];

	config[kFxParameterProperty_Selector] = @"manageOther";

	XCTAssertEqualObjects(NSStringFromSelector(parameter.parameterSelector), @"manageOther:atTime:error:",
						  @"the parameter reads through to the same record");
}

/*! @abstract An immutable configuration is copied, so the parameter keeps the selector it was built with. */
- (void)testAnImmutableConfigurationIsCopiedIntoTheParameter
{
	NSDictionary *config = [self floatConfigWithExtra:@{kFxParameterProperty_Selector: @"manageAmount"}].copy;
	FxGripFloatParameter *parameter = [FxGripFloatParameter.alloc initWithDictionary:config effect:(id)self.effect];
	[self.retainedParameters addObject:parameter];

	XCTAssertEqualObjects(NSStringFromSelector(parameter.parameterSelector), @"manageAmount:atTime:error:");
}

#pragma mark Abstract entry points

/*! @abstract The abstract type accessors on FxGripParameter raise an internal inconsistency exception. */
- (void)testTheAbstractTypeAccessorsRefuseToAnswer
{
	XCTAssertThrowsSpecificNamed([FxGripParameter parameterType], NSException, NSInternalInconsistencyException);
	XCTAssertThrowsSpecificNamed([FxGripParameter parameterTypeString], NSException, NSInternalInconsistencyException);
}

/*! @abstract The abstract +addParameter:toEffect: on FxGripParameter raises an internal inconsistency exception. */
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

/*! @abstract The base parameter's extension key is the empty string. */
- (void)testAParameterCarriesNoExtensionKeyOfItsOwn
{
	XCTAssertEqualObjects([self makeParameterWithExtra:nil].extKey, @"");
}

/*! @abstract The start and end change-bracket calls succeed and set no error. */
- (void)testTheChangeBracketAcceptsEveryTime
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	NSError *error = nil;

	XCTAssertTrue([parameter startChangedTime:FxGripParamClassTestTime(0, 1) error:&error]);
	XCTAssertTrue([parameter endChangedTime:FxGripParamClassTestTime(0, 1) error:&error]);
	XCTAssertNil(error);
}

/*! @abstract Installing tags succeeds when the host exposes no tags API. */
- (void)testTagInstallationSucceedsWithoutATagsAPI
{
	XCTAssertTrue([[self makeParameterWithExtra:nil] addTags]);
}

#pragma mark Name

/*! @abstract Reading the parameter name returns the value the dynamic parameter API reports. */
- (void)testTheNameIsReadFromTheDynamicParameterAPI
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	self.effect.apiManager.dynamicParamAPIv3.name = @"Renamed";

	XCTAssertEqualObjects(parameter.parameterName, @"Renamed");
}

/*! @abstract Setting the parameter name calls the dynamic parameter API with the id and new name and sets no error. */
- (void)testSettingTheNameWritesThroughTheDynamicParameterAPI
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	parameter.parameterName = @"Renamed";

	XCTAssertEqualObjects(self.effect.apiManager.dynamicParamAPIv3.setNameCalls,
						  (@[@{@"id": @(kBaseTestParameter), @"name": @"Renamed"}]));
	XCTAssertNil(parameter.error);
}

/*! @abstract A name write that the host rejects records the host error on the parameter. */
- (void)testAFailedNameWriteIsRecordedOnTheParameter
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	NSError *failure = [NSError errorWithDomain:@"FxGripParameterBaseTest" code:2 userInfo:nil];
	self.effect.apiManager.dynamicParamAPIv3.nameError = failure;

	parameter.parameterName = @"Renamed";

	XCTAssertEqualObjects(parameter.error, failure);
}

#pragma mark Flags

/*! @abstract Reading parameterFlags queries the retrieval API for this parameter id and returns its flags. */
- (void)testTheParameterFlagsAreReadFromTheRetrievalAPI
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_DISABLED;

	XCTAssertEqual(parameter.parameterFlags, (FxParameterFlags)kFxParameterFlag_DISABLED);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.getFlagsParameterIDs, @[@(kBaseTestParameter)]);
}

/*! @abstract A flags read that the host refuses returns the invalid flag marker. */
- (void)testAFlagsReadTheHostRefusesReportsTheInvalidMarker
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	XCTAssertEqual(parameter.parameterFlags, (FxParameterFlags)kFxParameterFlag_INVALID);
}

/*! @abstract Setting parameterFlags forwards the combined flag word to the setting API. */
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

/*! @abstract Each staged flag bit is reported true by its dedicated boolean accessor. */
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

/*! @abstract Turning a flag on writes the whole staged word, including the previously staged bits. */
- (void)testTogglingAStagedFlagWritesTheWholeStagedWordBack
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];

	parameter.flagNoDebug = YES;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls.firstObject[@"flags"],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_NO_DEBUG));
}

/*! @abstract Setting a flag that is already set writes nothing to the host. */
- (void)testSettingAStagedFlagToItsCurrentStateWritesNothing
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];

	parameter.flagHidden = YES;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls, @[]);
}

/*! @abstract Clearing a staged flag writes the remaining flag word without that bit. */
- (void)testClearingAStagedFlagWritesTheWordWithoutThatBit
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN | kFxParameterFlag_NOSTATE)}];

	parameter.flagHidden = NO;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls.firstObject[@"flags"],
						  @(kFxParameterFlag_NOSTATE));
}

/*! @abstract A parameter with no declared flags stages the default flag word, and flagIsDefault reports false since default names the absence of every flag. */
- (void)testAParameterWithoutDeclaredFlagsStagesTheDefaultFlags
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	XCTAssertEqual(parameter.parameterCurrentFlags, (FxParameterFlags)kFxParameterFlag_DEFAULT);
	XCTAssertFalse([parameter flagIsDefault], @"the default marker names the absence of every flag");
}

#pragma mark Flush

/*! @abstract Flushing a non-caching parameter writes no flags. */
- (void)testFlushingAParameterThatIsNotCachingWritesNothing
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	[parameter parameterFlush];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls, @[]);
}

/*! @abstract Flushing a caching parameter issues one write that drops the cache bit and keeps every other staged flag. */
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

/*! @abstract Setting the parent id updates the reported parent. */
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

/*! @abstract A state parameter with no group participates in the plugin state. */
- (void)testAStateParameterOutsideAnyGroupHasState
{
	XCTAssertTrue([self makeParameterWithExtra:nil].hasState);
}

/*! @abstract A push-button parameter, which carries no value, never participates in the state. */
- (void)testAParameterThatIsNotAStateParameterNeverHasState
{
	NSDictionary *config = FxGripParamClassTestConfig(kBaseTestParameter, kFxParameterType_PushButton, @"Reset", nil);
	FxGripPushButtonParameter *button = [FxGripPushButtonParameter.alloc initWithDictionary:config
																					 effect:(id)self.effect];
	[self.retainedParameters addObject:button];

	XCTAssertFalse(button.hasState);
}

/*! @abstract The no-state flag removes an otherwise stateful parameter from the state. */
- (void)testTheStatelessFlagRemovesTheParameterFromTheState
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_NOSTATE)}];

	XCTAssertFalse(parameter.hasState);
}

/*! @abstract A parameter inside a no-state ancestor group is removed from the state. */
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

/*! @abstract A parameter inside a stateful group keeps its state participation. */
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

/*! @abstract A declared manage selector name resolves to the full change-signature selector. */
- (void)testTheManagedSelectorIsTheDeclaredNameWithTheChangeSignature
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Selector: @"manageAmount"}];

	XCTAssertEqualObjects(NSStringFromSelector(parameter.parameterSelector), @"manageAmount:atTime:error:");
}

/*! @abstract A declared selector name that lacks the manage prefix yields a NULL managed selector. */
- (void)testASelectorWithoutTheManagePrefixIsRefused
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Selector: @"handleAmount"}];

	XCTAssertTrue(parameter.parameterSelector == NULL);
}

/*! @abstract A parameter with no declared selector has a NULL managed selector. */
- (void)testAParameterWithoutADeclaredSelectorHasNoManagedSelector
{
	XCTAssertTrue([self makeParameterWithExtra:nil].parameterSelector == NULL);
}

#pragma mark Timing conversions

/*! @abstract Converting an image time to a timeline time queries the timing API for this parameter and returns the converted value. */
- (void)testTheTimelineConversionAsksTheTimingAPIForThisParameter
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	CMTime timeline = FxGripParamClassTestTime(0, 1);

	[parameter timelineTime:&timeline fromImageTime:FxGripParamClassTestTime(6, 30)];

	XCTAssertEqual(timeline.value, (int64_t)12);
	XCTAssertEqualObjects(self.effect.apiManager.timingAPIv4.queries.lastObject[@"accessor"], @"timeline");
	XCTAssertEqualObjects(self.effect.apiManager.timingAPIv4.queries.lastObject[@"id"], @(kBaseTestParameter));
}

/*! @abstract Converting a timeline time to an image time queries the timing API and returns the converted value. */
- (void)testTheImageConversionAsksTheTimingAPIForThisParameter
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	CMTime image = FxGripParamClassTestTime(0, 1);

	[parameter imageTime:&image fromTimelineTime:FxGripParamClassTestTime(12, 30)];

	XCTAssertEqual(image.value, (int64_t)6);
	XCTAssertEqualObjects(self.effect.apiManager.timingAPIv4.queries.lastObject[@"accessor"], @"image");
}

#pragma mark Coding

/*! @abstract FxGripParameter reports support for secure coding. */
- (void)testAParameterSupportsSecureCoding
{
	XCTAssertTrue(FxGripParameter.supportsSecureCoding);
}

/*! @abstract initWithCoder returns the same parameter instance. */
- (void)testDecodingReturnsTheParameterItself
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:NO];

	XCTAssertEqualObjects([parameter initWithCoder:archiver], parameter);
}

/*! @abstract Encoding with a plain coder, which is not a plugin state encoder, reads no value from the host. */
- (void)testAPlainCoderIsNotAPluginStateEncoderAndReadsNoValue
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];
	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:NO];

	XCTAssertFalse(archiver.isFxPluginStateEncoder);

	[parameter encodeWithCoder:archiver];

	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.reads, @[]);
}

/*! @abstract Encoding with a plugin state coder reads the parameter value at the coder's render time. */
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

/*! @abstract A caching parameter answers a pre-get-flags notification from its staged flags and marks the query handled. */
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

/*! @abstract A non-caching parameter leaves a pre-get-flags notification unanswered so the host handles it. */
- (void)testAParameterThatIsNotCachingLeavesTheFlagsQueryToTheHost
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	NSMutableDictionary *userInfo = [self postFlagsNotification:FxGripNotifyAPI_ParameterGetFlagsPreName
													  parameter:parameter
														  flags:kFxParameterFlag_DEFAULT];

	XCTAssertNil(userInfo.fxResult);
}

/*! @abstract A set-flags notification that turns caching on is absorbed into the staged flags with the dirty bit added, and the host is not asked to store it. */
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

/*! @abstract A set-flags notification without the cache bit drops only the dirty marker and passes to the host. */
- (void)testAFlagsWriteWithoutCachingLosesOnlyTheDirtyMarkerAndReachesTheHost
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	NSMutableDictionary *userInfo = [self postFlagsNotification:FxGripNotifyAPI_ParameterSetFlagsPreName
													  parameter:parameter
														  flags:kFxParameterFlag_DISABLED | kFxParameterFlag_CACHEDIRTY];

	XCTAssertNil(userInfo.fxResult);
	XCTAssertEqualObjects(userInfo.fxParameter[kFxParameterProperty_Flags], @(kFxParameterFlag_DISABLED));
}

/*! @abstract A completed set-flags notification carrying the saving flag stores the saved flags, minus the saving and dirty bits, as the current flags. */
- (void)testACompletedSavingWriteBecomesTheParametersCurrentFlags
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	[self postFlagsNotification:FxGripNotifyAPI_ParameterSetFlagsName
					  parameter:parameter
						  flags:kFxParameterFlag_SAVING | kFxParameterFlag_HIDDEN | kFxParameterFlag_CACHEDIRTY];

	XCTAssertEqual(parameter.parameterCurrentFlags, (FxParameterFlags)kFxParameterFlag_HIDDEN);
}

/*! @abstract A completed set-flags notification without the saving flag leaves the current flags unchanged. */
- (void)testACompletedWriteThatIsNotSavingLeavesTheCurrentFlagsAlone
{
	FxGripFloatParameter *parameter =
		[self makeParameterWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];

	[self postFlagsNotification:FxGripNotifyAPI_ParameterSetFlagsName
					  parameter:parameter
						  flags:kFxParameterFlag_DISABLED];

	XCTAssertEqual(parameter.parameterCurrentFlags, (FxParameterFlags)kFxParameterFlag_HIDDEN);
}

/*! @abstract A caching parameter leaves a flags query about a different parameter unanswered. */
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

/*! @abstract A completed set-flags notification updates only the named parameter and leaves an untargeted parameter's staged word untouched. */
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

/*! @abstract After removeObservers, the parameter no longer answers flags notifications. */
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

/*! @abstract A flags write through the setting wrapper reaches the host and becomes the parameter's current flags. */
- (void)testAHostWriteThroughTheWrapperBecomesTheParametersCurrentFlags
{
	FxGripFloatParameter *parameter = [self makeParameterWithExtra:nil];

	XCTAssertTrue([self.settingAPI setParameterFlags:kFxParameterFlag_HIDDEN toParameter:kBaseTestParameter]);

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls.firstObject[@"flags"],
						  @(kFxParameterFlag_HIDDEN));
	XCTAssertEqual(parameter.parameterCurrentFlags, (FxParameterFlags)kFxParameterFlag_HIDDEN);
}

/*! @abstract A caching parameter's write through the setting wrapper stages the flags without a host call and without moving the current flags. */
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
