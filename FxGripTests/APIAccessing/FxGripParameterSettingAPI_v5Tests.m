/*!
	@file       FxGripParameterSettingAPI_v5Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterSettingAPI_v5Tests
	@abstract   Verifies the typed setters of FxGripParameterSettingAPI_v5, their host forwarding, change notifications, and custom-parameter interception.
	@discussion Introduced in FxGrip 0.1.0. Each typed setter forwards to the host API and posts a change notification carrying the written value. A custom parameter intercepts the setter, mutates its own value through FxGripMutableParameter, and writes the result back as a custom value. setStringParameterValue: and setParameterFlags: post a pre-notification that observers can answer or rewrite before the host call.
*/

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

/*! @abstract setBoolValue: forwards the boolean and time to the host and posts the bool-change notification carrying the id, value, and time. */
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

/*! @abstract setFloatValue: forwards the float to the host and posts the float-change notification carrying the value. */
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

/*! @abstract setIntValue: forwards the integer to the host and posts the int-change notification carrying the value. */
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

/*! @abstract setHistogram... forwards black-in, black-out, white-in, white-out, gamma, and channel to the host and posts each component in the histogram-change notification. */
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

/*! @abstract setPathID: forwards the path pointer to the host and posts it boxed as an NSValue in the path-change notification. */
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

/*! @abstract setRed:green:blue:alpha: forwards all four color components to the host and posts them in the RGBA-change notification. */
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

/*! @abstract setRed:green:blue: forwards the three color components to the host and posts them in the RGB-change notification, leaving alpha absent. */
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

/*! @abstract setX:Y: forwards both coordinates to the host and posts them in the XY-change notification. */
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

/*! @abstract setCustomParameterValue: forwards the object to the host through the custom method and posts it in the custom-value-change notification. */
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

/*! @abstract When the host refuses, each typed setter returns NO and no change notification is posted. */
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

/*! @abstract A setter on a custom parameter mutates the custom value, then writes the mutated value back through the host custom method and posts the custom-value-change notification. */
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

/*! @abstract The custom value is read once, at the same time passed to the setter, and the host write uses that time. */
- (void)testTheCustomValueIsReadAtTheTimeTheSetterWasGiven
{
	[self markParameterCustom];

	[self.settingAPI setIntValue:3 toParameter:kSettingTestParameter atTime:FxGripSettingTestTime()];

	XCTAssertEqual(self.retrievalAPI.readCount, (NSUInteger)1);
	XCTAssertTrue(FxGripSettingTestTimesEqual(self.retrievalAPI.lastTime, FxGripSettingTestTime()));
	XCTAssertTrue(FxGripSettingTestTimesEqual(self.hostAPI.lastTime, FxGripSettingTestTime()));
}

/*! @abstract Every typed setter routes through the custom value, which records the setters in call order: bool, float, int, histogram, pathid, rgba, rgb, xy, string. */
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

/*! @abstract When the custom value cannot be read, the setter returns NO, reaches no host, and posts nothing. */
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

/*! @abstract When the custom value does not adopt FxGripMutableParameter, the setter returns NO, invokes no setter on the value, and reaches no host. */
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

/*! @abstract When the custom value does not implement the requested setter, the write returns NO and reaches no host. */
- (void)testACustomValueThatDoesNotImplementTheSetterReportsFailure
{
	[self markParameterCustom];
	self.retrievalAPI.customValue = [FxGripSettingTestOpaqueValue.alloc init];

	XCTAssertFalse([self.settingAPI setFloatValue:0.25
									  toParameter:kSettingTestParameter
										   atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

/*! @abstract When the custom setter refuses the mutation, the write returns NO and the refused mutation is not written back to the host. */
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

/*! @abstract When the custom value cannot take the mutation, every typed setter returns NO and reaches no host. */
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

/*! @abstract Without a dynamic API the custom value is never consulted, and the setter forwards the plain typed value to the host. */
- (void)testWithoutADynamicAPINoSetterIntercepts
{
	[self markParameterCustom];

	XCTAssertTrue([self.settingAPIWithoutDynamicAPI setFloatValue:0.25
													 toParameter:kSettingTestParameter
														  atTime:FxGripSettingTestTime()]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, @[]);
	XCTAssertEqualObjects(self.hostMethods, @[@"float"]);
}

/*! @abstract A setter on a non-custom parameter never reads a custom value. */
- (void)testANonCustomParameterNeverReadsTheCustomValue
{
	XCTAssertTrue([self.settingAPI setFloatValue:0.25
									 toParameter:kSettingTestParameter
										  atTime:FxGripSettingTestTime()]);

	XCTAssertEqual(self.retrievalAPI.readCount, (NSUInteger)0);
}

/*! @abstract When the custom value refuses the XY mutation, setX:Y: returns NO and the refused mutation is not written back to the host. */
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

/*! @abstract setStringParameterValue: posts the pre-notification before the host call and posts the pre and post notifications around the write. */
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

/*! @abstract An observer that rewrites the string in the pre-notification changes the value the host and the change payload receive. */
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

/*! @abstract A string value the host refuses posts only the pre-notification. */
- (void)testAStringValueTheHostRefusesPostsOnlyThePreNotification
{
	self.hostAPI.succeeds = NO;

	XCTAssertFalse([self.settingAPI setStringParameterValue:@"Original"
											   toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetStringValuePreName]);
}

/*! @abstract A string value on a custom parameter writes the observer-rewritten string through the custom value at the zero time and reports a custom value change. */
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

/*! @abstract setParameterFlags: forwards only the Apple-defined bits to the host and posts the pre and post flag notifications. */
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

/*! @abstract The posted flags carry the saving bit and drop the cache bit. */
- (void)testThePostedFlagsCarryTheSavingBitAndDropTheCacheBit
{
	FxParameterFlags flags = kFxParameterFlag_HIDDEN | kFxParameterFlag_CACHE;

	XCTAssertTrue([self.settingAPI setParameterFlags:flags toParameter:kSettingTestParameter]);

	NSDictionary *payload = [self payloadOf:FxGripNotifyAPI_ParameterSetFlagsName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_Flags],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_SAVING));
	XCTAssertEqualObjects(payload[kFxParameterProperty_Id], @(kSettingTestParameter));
}

/*! @abstract An observer that rewrites the flags in the pre-notification changes the value the host receives. */
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

/*! @abstract An observer that answers the flags pre-notification short-circuits the host call and posts only the pre-notification. */
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

/*! @abstract An observer that answers the flags pre-notification with NO reports failure and does not call the host. */
- (void)testAnObserverAnsweringThePreNotificationWithNOReportsFailure
{
	[self observeName:FxGripNotifyAPI_ParameterSetFlagsPreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxResult = @NO;
	}];

	XCTAssertFalse([self.settingAPI setParameterFlags:kFxParameterFlag_HIDDEN
										  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

/*! @abstract Flags the host refuses post only the pre-notification. */
- (void)testFlagsTheHostRefusesPostOnlyThePreNotification
{
	self.hostAPI.succeeds = NO;

	XCTAssertFalse([self.settingAPI setParameterFlags:kFxParameterFlag_HIDDEN
										  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetFlagsPreName]);
}

/*! @abstract The flags pre-notification carries the requested flags and the parameter ID. */
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
