//
//  FxGripParameterSettingAPI_v5Tests.m
//  FxGripTests
//
//  Unit tests for FxGripParameterSettingAPI_v5. Every typed setter routes either into a
//  custom parameter value that adopts FxGripMutableParameter or into the host API followed
//  by a change notification; setParameterFlags: and setStringParameterValue: additionally
//  run a pre-notification the observers can answer or rewrite.
//

#import "FxGripSettingAPITestSupport.h"
#import <objc/runtime.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripParameterSettingAPI_v5.h>

@interface FxGripParameterSettingAPI_v5Tests : FxGripSettingAPITestCase
@end

@implementation FxGripParameterSettingAPI_v5Tests

#pragma mark Plain setter forwarding

- (void)testSetBoolValueForwardsToTheHostAndPostsTheChange
{
	XCTAssertTrue([self.settingAPI setBoolValue:YES
									toParameter:kSettingTestParameter
										 atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"bool",
											@"id": @(kSettingTestParameter),
											@"value": @YES}));
	XCTAssertTrue(FxGripSettingTestTimesEqual(self.hostAPI.lastTime, FxGripSettingTestTime()));

	NSDictionary *payload = [self payloadOf:FxGripNotifyAPI_ParameterSetBoolName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_Id], @(kSettingTestParameter));
	XCTAssertEqualObjects(payload[kFxParameterProperty_Default], @YES);
	XCTAssertTrue(FxGripSettingTestTimesEqual([self payloadTimeOf:FxGripNotifyAPI_ParameterSetBoolName],
										  FxGripSettingTestTime()));
}

- (void)testSetFloatValueForwardsToTheHostAndPostsTheChange
{
	XCTAssertTrue([self.settingAPI setFloatValue:0.25
									 toParameter:kSettingTestParameter
										  atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"float",
											@"id": @(kSettingTestParameter),
											@"value": @0.25}));
	XCTAssertEqualObjects([self payloadOf:FxGripNotifyAPI_ParameterSetFloatName][kFxParameterProperty_Default],
						  @0.25);
}

- (void)testSetIntValueForwardsToTheHostAndPostsTheChange
{
	XCTAssertTrue([self.settingAPI setIntValue:9
								   toParameter:kSettingTestParameter
										atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"int",
											@"id": @(kSettingTestParameter),
											@"value": @9}));
	XCTAssertEqualObjects([self payloadOf:FxGripNotifyAPI_ParameterSetIntName][kFxParameterProperty_Default],
						  @9);
}

- (void)testSetHistogramForwardsEveryComponentAndPostsThem
{
	XCTAssertTrue([self.settingAPI setHistogramBlackIn:0.1
											  blackOut:0.2
											   whiteIn:0.3
											  whiteOut:0.4
												 gamma:0.5
											forChannel:kFxHistogramChannel_Red
										 fromParameter:kSettingTestParameter
												atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"histogram",
											@"id": @(kSettingTestParameter),
											@"blackin": @0.1,
											@"blackout": @0.2,
											@"whitein": @0.3,
											@"whiteout": @0.4,
											@"gamma": @0.5,
											@"channel": @(kFxHistogramChannel_Red)}));

	NSDictionary *payload = [self payloadOf:FxGripNotifyAPI_ParameterSetHistogramName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_BlackIn], @0.1);
	XCTAssertEqualObjects(payload[kFxParameterProperty_BlackOut], @0.2);
	XCTAssertEqualObjects(payload[kFxParameterProperty_WhiteIn], @0.3);
	XCTAssertEqualObjects(payload[kFxParameterProperty_WhiteOut], @0.4);
	XCTAssertEqualObjects(payload[kFxParameterProperty_Gamma], @0.5);
	XCTAssertEqualObjects(payload[kFxParameterProperty_Channel], @(kFxHistogramChannel_Red));
}

- (void)testSetPathIDForwardsThePointerAndPostsItBoxed
{
	int storage = 0;
	FxPathID pathID = &storage;

	XCTAssertTrue([self.settingAPI setPathID:pathID
								 toParameter:kSettingTestParameter
									  atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall[@"value"], [NSValue valueWithPointer:pathID]);
	XCTAssertEqualObjects([self payloadOf:FxGripNotifyAPI_ParameterSetPathIDName][kFxParameterPropertyX_PathID],
						  [NSValue valueWithPointer:pathID]);
}

- (void)testSetRedGreenBlueAlphaForwardsEveryComponentAndPostsThem
{
	XCTAssertTrue([self.settingAPI setRedValue:0.1
									greenValue:0.2
									 blueValue:0.3
									alphaValue:0.4
								   toParameter:kSettingTestParameter
										atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"rgba",
											@"id": @(kSettingTestParameter),
											@"red": @0.1,
											@"green": @0.2,
											@"blue": @0.3,
											@"alpha": @0.4}));
	NSDictionary *payload = [self payloadOf:FxGripNotifyAPI_ParameterSetRGBAName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_Red], @0.1);
	XCTAssertEqualObjects(payload[kFxParameterProperty_Alpha], @0.4);
}

- (void)testSetRedGreenBlueForwardsThreeComponentsAndPostsThem
{
	XCTAssertTrue([self.settingAPI setRedValue:0.1
									greenValue:0.2
									 blueValue:0.3
								   toParameter:kSettingTestParameter
										atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"rgb",
											@"id": @(kSettingTestParameter),
											@"red": @0.1,
											@"green": @0.2,
											@"blue": @0.3}));
	NSDictionary *payload = [self payloadOf:FxGripNotifyAPI_ParameterSetRGBName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_Blue], @0.3);
	XCTAssertNil(payload[kFxParameterProperty_Alpha]);
}

- (void)testSetXYForwardsBothCoordinatesAndPostsThem
{
	XCTAssertTrue([self.settingAPI setXValue:0.25
									  YValue:0.75
								 toParameter:kSettingTestParameter
									  atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"xy",
											@"id": @(kSettingTestParameter),
											@"x": @0.25,
											@"y": @0.75}));
	NSDictionary *payload = [self payloadOf:FxGripNotifyAPI_ParameterSetXYName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_X], @0.25);
	XCTAssertEqualObjects(payload[kFxParameterProperty_Y], @0.75);
}

- (void)testSetCustomParameterValueForwardsTheObjectAndPostsIt
{
	NSString *value = @"Payload";

	XCTAssertTrue([self.settingAPI setCustomParameterValue:value
											   toParameter:kSettingTestParameter
													atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostMethods, @[@"custom"]);
	XCTAssertEqualObjects([self payloadOf:FxGripNotifyAPI_ParameterSetCustomValueName][kFxParameterProperty_Default],
						  value);
}

- (void)testAHostRefusalReportsFailureAndPostsNothing
{
	self.hostAPI.succeeds = NO;

	XCTAssertFalse([self.settingAPI setFloatValue:0.25
									  toParameter:kSettingTestParameter
										   atTime:FxGripSettingTestTime()]);
	XCTAssertFalse([self.settingAPI setBoolValue:YES
									 toParameter:kSettingTestParameter
										  atTime:FxGripSettingTestTime()]);
	XCTAssertFalse([self.settingAPI setIntValue:1
									toParameter:kSettingTestParameter
										 atTime:FxGripSettingTestTime()]);
	XCTAssertFalse([self.settingAPI setXValue:0 YValue:0
								  toParameter:kSettingTestParameter
									   atTime:FxGripSettingTestTime()]);
	XCTAssertFalse([self.settingAPI setCustomParameterValue:@"x"
												toParameter:kSettingTestParameter
													 atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.posted, @[]);
}

#pragma mark Custom parameter interception

- (void)testASetterOnACustomParameterWritesThroughTheCustomValue
{
	[self markParameterCustom];

	XCTAssertTrue([self.settingAPI setFloatValue:0.25
									 toParameter:kSettingTestParameter
										  atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, @[@"float"]);
	XCTAssertEqualObjects(self.customValue.receivedValues[@"float"], @0.25);
	XCTAssertEqualObjects(self.hostMethods, @[@"custom"],
						  @"the mutated value is written back as a custom parameter");
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetCustomValueName]);
}

- (void)testTheCustomValueIsReadAtTheTimeTheSetterWasGiven
{
	[self markParameterCustom];

	[self.settingAPI setIntValue:3 toParameter:kSettingTestParameter atTime:FxGripSettingTestTime()];

	XCTAssertEqual(self.retrievalAPI.readCount, (NSUInteger)1);
	XCTAssertTrue(FxGripSettingTestTimesEqual(self.retrievalAPI.lastTime, FxGripSettingTestTime()));
	XCTAssertTrue(FxGripSettingTestTimesEqual(self.hostAPI.lastTime, FxGripSettingTestTime()));
}

- (void)testEveryTypedSetterInterceptsACustomParameter
{
	[self markParameterCustom];
	FxGripParameterSettingAPI_v5 *api = self.settingAPI;
	CMTime time = FxGripSettingTestTime();

	XCTAssertTrue([api setBoolValue:YES toParameter:kSettingTestParameter atTime:time]);
	XCTAssertTrue([api setFloatValue:0.5 toParameter:kSettingTestParameter atTime:time]);
	XCTAssertTrue([api setIntValue:2 toParameter:kSettingTestParameter atTime:time]);
	XCTAssertTrue([api setHistogramBlackIn:0 blackOut:1 whiteIn:0 whiteOut:1 gamma:1
								forChannel:kFxHistogramChannel_RGB
							 fromParameter:kSettingTestParameter atTime:time]);
	XCTAssertTrue([api setPathID:(FxPathID _Nonnull)NULL toParameter:kSettingTestParameter atTime:time]);
	XCTAssertTrue([api setRedValue:0 greenValue:0 blueValue:0 alphaValue:1
					   toParameter:kSettingTestParameter atTime:time]);
	XCTAssertTrue([api setRedValue:0 greenValue:0 blueValue:0
					   toParameter:kSettingTestParameter atTime:time]);
	XCTAssertTrue([api setXValue:0 YValue:0 toParameter:kSettingTestParameter atTime:time]);
	XCTAssertTrue([api setStringParameterValue:@"text" toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, (@[@"bool", @"float", @"int",
															   @"histogram", @"pathid", @"rgba",
															   @"rgb", @"xy", @"string"]));
}

- (void)testACustomParameterWhoseValueCannotBeReadReportsFailure
{
	[self markParameterCustom];
	self.retrievalAPI.succeeds = NO;

	XCTAssertFalse([self.settingAPI setFloatValue:0.25
									  toParameter:kSettingTestParameter
										   atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertEqualObjects(self.posted, @[]);
}

- (void)testACustomValueThatDoesNotAdoptTheMutableProtocolReportsFailure
{
	[self markParameterCustom];
	self.customValue.conforms = NO;

	XCTAssertFalse([self.settingAPI setFloatValue:0.25
									  toParameter:kSettingTestParameter
										   atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, @[]);
	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

- (void)testACustomValueThatDoesNotImplementTheSetterReportsFailure
{
	[self markParameterCustom];
	self.retrievalAPI.customValue = [FxGripSettingTestOpaqueValue.alloc init];

	XCTAssertFalse([self.settingAPI setFloatValue:0.25
									  toParameter:kSettingTestParameter
										   atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

- (void)testACustomSetterThatRefusesTheValueReportsFailure
{
	[self markParameterCustom];
	self.customValue.setterSucceeds = NO;

	XCTAssertFalse([self.settingAPI setFloatValue:0.25
									  toParameter:kSettingTestParameter
										   atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, @[@"float"]);
	XCTAssertEqualObjects(self.hostAPI.calls, @[], @"a refused mutation is not written back");
}

- (void)testEverySetterReportsFailureWhenTheCustomValueCannotTakeTheMutation
{
	[self markParameterCustom];
	self.customValue.conforms = NO;
	FxGripParameterSettingAPI_v5 *api = self.settingAPI;
	CMTime time = FxGripSettingTestTime();

	XCTAssertFalse([api setBoolValue:YES toParameter:kSettingTestParameter atTime:time]);
	XCTAssertFalse([api setFloatValue:0.5 toParameter:kSettingTestParameter atTime:time]);
	XCTAssertFalse([api setIntValue:2 toParameter:kSettingTestParameter atTime:time]);
	XCTAssertFalse([api setHistogramBlackIn:0 blackOut:1 whiteIn:0 whiteOut:1 gamma:1
								 forChannel:kFxHistogramChannel_RGB
							  fromParameter:kSettingTestParameter atTime:time]);
	XCTAssertFalse([api setPathID:(FxPathID _Nonnull)NULL toParameter:kSettingTestParameter atTime:time]);
	XCTAssertFalse([api setRedValue:0 greenValue:0 blueValue:0 alphaValue:1
						toParameter:kSettingTestParameter atTime:time]);
	XCTAssertFalse([api setRedValue:0 greenValue:0 blueValue:0
						toParameter:kSettingTestParameter atTime:time]);
	XCTAssertFalse([api setStringParameterValue:@"text" toParameter:kSettingTestParameter]);
	XCTAssertFalse([api setXValue:0.25 YValue:0.75 toParameter:kSettingTestParameter atTime:time]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

- (void)testWithoutADynamicAPINoSetterIntercepts
{
	[self markParameterCustom];

	XCTAssertTrue([self.settingAPIWithoutDynamicAPI setFloatValue:0.25
													 toParameter:kSettingTestParameter
														  atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, @[]);
	XCTAssertEqualObjects(self.hostMethods, @[@"float"]);
}

- (void)testANonCustomParameterNeverReadsTheCustomValue
{
	XCTAssertTrue([self.settingAPI setFloatValue:0.25
									 toParameter:kSettingTestParameter
										  atTime:FxGripSettingTestTime()]);

	XCTAssertEqual(self.retrievalAPI.readCount, (NSUInteger)0);
}

- (void)testSetXYReportsFailureAndReachesNoHostWhenTheCustomValueRefusesTheMutation
{
	[self markParameterCustom];
	self.customValue.setterSucceeds = NO;

	XCTAssertFalse([self.settingAPI setXValue:0.25
									   YValue:0.75
								  toParameter:kSettingTestParameter
									   atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, @[@"xy"]);
	XCTAssertEqualObjects(self.hostAPI.calls, @[], @"a refused mutation is not written back");
}

#pragma mark setStringParameterValue:

- (void)testSetStringValuePostsThePreNotificationBeforeTheHostCall
{
	__block NSUInteger callsAtPre = NSUIntegerMax;
	[self observeName:FxGripNotifyAPI_ParameterSetStringValuePreName usingBlock:^(NSNotification *notification) {
		callsAtPre = self.hostAPI.calls.count;
	}];

	XCTAssertTrue([self.settingAPI setStringParameterValue:@"Original"
											  toParameter:kSettingTestParameter]);

	XCTAssertEqual(callsAtPre, (NSUInteger)0);
	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"string",
											@"id": @(kSettingTestParameter),
											@"value": @"Original"}));
	XCTAssertEqualObjects(self.postedNames, (@[FxGripNotifyAPI_ParameterSetStringValuePreName,
											   FxGripNotifyAPI_ParameterSetStringValueName]));
}

- (void)testAnObserverRewritingTheStringChangesWhatTheHostReceives
{
	[self observeName:FxGripNotifyAPI_ParameterSetStringValuePreName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[kFxParameterProperty_Default] = @"Localized";
	}];

	XCTAssertTrue([self.settingAPI setStringParameterValue:@"Original"
											  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostCall[@"value"], @"Localized");
	XCTAssertEqualObjects([self payloadOf:FxGripNotifyAPI_ParameterSetStringValueName][kFxParameterProperty_Default],
						  @"Localized");
}

- (void)testAStringValueTheHostRefusesPostsOnlyThePreNotification
{
	self.hostAPI.succeeds = NO;

	XCTAssertFalse([self.settingAPI setStringParameterValue:@"Original"
											   toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetStringValuePreName]);
}

- (void)testAStringValueOnACustomParameterUsesTheRewrittenStringAtTheZeroTime
{
	[self markParameterCustom];
	[self observeName:FxGripNotifyAPI_ParameterSetStringValuePreName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[kFxParameterProperty_Default] = @"Localized";
	}];

	XCTAssertTrue([self.settingAPI setStringParameterValue:@"Original"
											  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.customValue.receivedValues[@"string"], @"Localized");
	XCTAssertTrue(FxGripSettingTestTimesEqual(self.retrievalAPI.lastTime, FxGripSettingTestZeroTime()));
	XCTAssertEqualObjects(self.postedNames, (@[FxGripNotifyAPI_ParameterSetStringValuePreName,
											   FxGripNotifyAPI_ParameterSetCustomValueName]),
						  @"the intercepted write reports a custom value change");
}

#pragma mark setParameterFlags:

- (void)testSetParameterFlagsForwardsTheMaskedFlagsAndPostsBothNotifications
{
	FxParameterFlags flags = kFxParameterFlag_HIDDEN | kFxParameterFlag_NO_DEBUG;

	XCTAssertTrue([self.settingAPI setParameterFlags:flags toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"flags",
											@"id": @(kSettingTestParameter),
											@"value": @(kFxParameterFlag_HIDDEN)}),
						  @"only the bits Apple defines reach the host");
	XCTAssertEqualObjects(self.postedNames, (@[FxGripNotifyAPI_ParameterSetFlagsPreName,
											   FxGripNotifyAPI_ParameterSetFlagsName]));
}

- (void)testThePostedFlagsCarryTheSavingBitAndDropTheCacheBit
{
	FxParameterFlags flags = kFxParameterFlag_HIDDEN | kFxParameterFlag_CACHE;

	XCTAssertTrue([self.settingAPI setParameterFlags:flags toParameter:kSettingTestParameter]);

	NSDictionary *payload = [self payloadOf:FxGripNotifyAPI_ParameterSetFlagsName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_Flags],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_SAVING));
	XCTAssertEqualObjects(payload[kFxParameterProperty_Id], @(kSettingTestParameter));
}

- (void)testAnObserverRewritingTheFlagsChangesWhatTheHostReceives
{
	[self observeName:FxGripNotifyAPI_ParameterSetFlagsPreName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[kFxParameterProperty_Flags] =
			@(kFxParameterFlag_DISABLED);
	}];

	XCTAssertTrue([self.settingAPI setParameterFlags:kFxParameterFlag_HIDDEN
										 toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostCall[@"value"], @(kFxParameterFlag_DISABLED));
}

- (void)testAnObserverAnsweringThePreNotificationShortCircuitsTheHostCall
{
	[self observeName:FxGripNotifyAPI_ParameterSetFlagsPreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxResult = @YES;
	}];

	XCTAssertTrue([self.settingAPI setParameterFlags:kFxParameterFlag_HIDDEN
										 toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetFlagsPreName]);
}

- (void)testAnObserverAnsweringThePreNotificationWithNOReportsFailure
{
	[self observeName:FxGripNotifyAPI_ParameterSetFlagsPreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxResult = @NO;
	}];

	XCTAssertFalse([self.settingAPI setParameterFlags:kFxParameterFlag_HIDDEN
										  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

- (void)testFlagsTheHostRefusesPostOnlyThePreNotification
{
	self.hostAPI.succeeds = NO;

	XCTAssertFalse([self.settingAPI setParameterFlags:kFxParameterFlag_HIDDEN
										  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetFlagsPreName]);
}

- (void)testTheFlagsPreNotificationCarriesTheRequestedFlags
{
	__block NSDictionary *seen = nil;
	[self observeName:FxGripNotifyAPI_ParameterSetFlagsPreName usingBlock:^(NSNotification *notification) {
		seen = notification.userInfo.fxParameter.copy;
	}];

	[self.settingAPI setParameterFlags:kFxParameterFlag_COLLAPSED toParameter:kSettingTestParameter];

	XCTAssertEqualObjects(seen, (@{kFxParameterProperty_Id: @(kSettingTestParameter),
								   kFxParameterProperty_Flags: @(kFxParameterFlag_COLLAPSED)}));
}

@end
