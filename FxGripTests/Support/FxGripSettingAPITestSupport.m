/*!
	@file       FxGripSettingAPITestSupport.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSettingAPITestSupport
	@abstract   Shared stubs and an XCTestCase base for the parameter-setting API wrapper tests.
	@discussion Introduced in FxGrip 0.1.0. The stub host API records each set call, the custom-value stub records the setter messages it receives and reports its protocol conformance, and the retrieval stub vends a custom value. The test-case base wires them together, observes the recorded set notifications, and vends the setting wrapper instances under test.
*/

#import "FxGripSettingAPITestSupport.h"
#import <objc/runtime.h>
#import <FxGrip/FxGripAPINotifications.h>

const FxParameterId kSettingTestParameter = 21;

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxGripSettingTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

/*! @abstract Returns a fixed non-zero valid CMTime used across the setting-API tests. */
CMTime FxGripSettingTestTime(void)
{
	return (CMTime){.value = 7, .timescale = 24, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

/*! @abstract Returns a valid zero CMTime. */
CMTime FxGripSettingTestZeroTime(void)
{
	return (CMTime){.value = 0, .timescale = 1, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

/*! @abstract Returns whether two CMTimes are equal field by field. */
BOOL FxGripSettingTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

/*!
	@abstract A stub host setting API that records each set call and its last time.
	@discussion Introduced in FxGrip 0.1.0. Each setter appends its arguments to the calls array, stores the render time, and returns the configured success flag.
*/
@implementation FxGripSettingTestStubAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_calls = NSMutableArray.new;
		_succeeds = YES;
	}
	return self;
}

/*! @abstract Records a call under its method name and returns the configured success flag. */
- (BOOL)record:(NSString *)method arguments:(NSDictionary *)arguments
{
	NSMutableDictionary *call = arguments.mutableCopy;
	call[@"method"] = method;
	[self.calls addObject:call.copy];
	return self.succeeds;
}

- (BOOL)setBoolValue:(BOOL)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastTime = time;
	return [self record:@"bool" arguments:@{@"id": @(parameterID), @"value": @(value)}];
}

- (BOOL)setCustomParameterValue:(NSObject<NSSecureCoding, NSCopying> *)value
					toParameter:(UInt32)parameterID
						 atTime:(CMTime)time
{
	self.lastTime = time;
	return [self record:@"custom" arguments:@{@"id": @(parameterID),
											  @"value": [NSValue valueWithNonretainedObject:value]}];
}

- (BOOL)setFloatValue:(double)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastTime = time;
	return [self record:@"float" arguments:@{@"id": @(parameterID), @"value": @(value)}];
}

- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel
			  fromParameter:(UInt32)parameterID
					 atTime:(CMTime)time
{
	self.lastTime = time;
	return [self record:@"histogram" arguments:@{@"id": @(parameterID),
												 @"blackin": @(blackIn),
												 @"blackout": @(blackOut),
												 @"whitein": @(whiteIn),
												 @"whiteout": @(whiteOut),
												 @"gamma": @(gamma),
												 @"channel": @(channel)}];
}

- (BOOL)setIntValue:(int)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastTime = time;
	return [self record:@"int" arguments:@{@"id": @(parameterID), @"value": @(value)}];
}

- (BOOL)setParameterFlags:(FxParameterFlags)flags toParameter:(UInt32)parameterID
{
	return [self record:@"flags" arguments:@{@"id": @(parameterID), @"value": @(flags)}];
}

- (BOOL)setPathID:(FxPathID)pathID toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastTime = time;
	return [self record:@"pathid" arguments:@{@"id": @(parameterID),
											  @"value": [NSValue valueWithPointer:pathID]}];
}

- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		 alphaValue:(double)alpha
		toParameter:(UInt32)parameterID
			 atTime:(CMTime)time
{
	self.lastTime = time;
	return [self record:@"rgba" arguments:@{@"id": @(parameterID),
											@"red": @(red),
											@"green": @(green),
											@"blue": @(blue),
											@"alpha": @(alpha)}];
}

- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		toParameter:(UInt32)parameterID
			 atTime:(CMTime)time
{
	self.lastTime = time;
	return [self record:@"rgb" arguments:@{@"id": @(parameterID),
										   @"red": @(red),
										   @"green": @(green),
										   @"blue": @(blue)}];
}

- (BOOL)setStringParameterValue:(NSString *)string toParameter:(UInt32)parameterID
{
	return [self record:@"string" arguments:@{@"id": @(parameterID), @"value": string}];
}

- (BOOL)setXValue:(double)x YValue:(double)y toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastTime = time;
	return [self record:@"xy" arguments:@{@"id": @(parameterID), @"x": @(x), @"y": @(y)}];
}

@end

/*!
	@abstract A stub dynamic API that reports a configured parameter type.
	@discussion Introduced in FxGrip 0.1.0. It lets a test mark a parameter custom so the setting wrapper routes the value through the custom-value setter path.
*/
@implementation FxGripSettingTestDynamicAPI

- (FxParameterType)parameterType:(FxParameterId)parameterID
{
	return self.type;
}

@end

/*!
	@abstract A custom parameter value stub that records the setter messages it receives.
	@discussion Introduced in FxGrip 0.1.0. It reports configurable conformance to FxGripMutableParameter, records each typed setter and its value, and returns the configured setter success flag.
*/
@implementation FxGripSettingTestCustomValue

- (instancetype)init
{
	self = [super init];
	if (self) {
		_receivedSetters = NSMutableArray.new;
		_receivedValues = NSMutableDictionary.new;
		_conforms = YES;
		_setterSucceeds = YES;
	}
	return self;
}

/*! @abstract Reports the configured conformance for FxGripMutableParameter and defers otherwise. */
- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
	if (strcmp(protocol_getName(aProtocol), "FxGripMutableParameter") == 0) {
		return self.conforms;
	}
	return [super conformsToProtocol:aProtocol];
}

/*! @abstract Records a received setter and its value, and returns the configured setter success flag. */
- (BOOL)record:(NSString *)setter value:(id)value
{
	[self.receivedSetters addObject:setter];
	if (value) {
		self.receivedValues[setter] = value;
	}
	return self.setterSucceeds;
}

- (BOOL)setBoolValue:(BOOL)value
{
	return [self record:@"bool" value:@(value)];
}

- (BOOL)setFloatValue:(double)value
{
	return [self record:@"float" value:@(value)];
}

- (BOOL)setIntValue:(int)value
{
	return [self record:@"int" value:@(value)];
}

- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel
{
	return [self record:@"histogram" value:@[@(blackIn), @(blackOut), @(whiteIn),
											 @(whiteOut), @(gamma), @(channel)]];
}

- (BOOL)setPathID:(FxPathID)pathID
{
	return [self record:@"pathid" value:[NSValue valueWithPointer:pathID]];
}

- (BOOL)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha
{
	return [self record:@"rgba" value:@[@(red), @(green), @(blue), @(alpha)]];
}

- (BOOL)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue
{
	return [self record:@"rgb" value:@[@(red), @(green), @(blue)]];
}

- (BOOL)setStringParameterValue:(NSString *)string
{
	return [self record:@"string" value:string];
}

- (BOOL)setXValue:(double)x YValue:(double)y
{
	return [self record:@"xy" value:@[@(x), @(y)]];
}

@end

/*!
	@abstract A custom value that claims FxGripMutableParameter conformance but implements no setter.
	@discussion Introduced in FxGrip 0.1.0. It exercises the wrapper's handling of a value that conforms yet does not respond to the typed setter selectors.
*/
@implementation FxGripSettingTestOpaqueValue

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
	if (strcmp(protocol_getName(aProtocol), "FxGripMutableParameter") == 0) {
		return YES;
	}
	return [super conformsToProtocol:aProtocol];
}

@end

/*!
	@abstract A stub retrieval API that vends a custom value and parameter flags and counts reads.
	@discussion Introduced in FxGrip 0.1.0. The setting wrapper reads the existing custom value through this stub before writing setters into it; the stub records the read count and the last time.
*/
@implementation FxGripSettingTestRetrievalAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_succeeds = YES;
		_flagsSucceed = YES;
	}
	return self;
}

- (BOOL)getCustomParameterValue:(NSObject<NSSecureCoding, NSCopying> **)value
				  fromParameter:(UInt32)parameterID
						 atTime:(CMTime)time
{
	self.readCount += 1;
	self.lastTime = time;
	if (!self.succeeds) {
		return NO;
	}
	if (value) {
		*value = (id)self.customValue;
	}
	return YES;
}

- (BOOL)getParameterFlags:(FxParameterFlags *)flags fromParameter:(UInt32)parameterID
{
	if (!self.flagsSucceed) {
		return NO;
	}
	*flags = self.flags;
	return YES;
}

@end

/*!
	@abstract A stub API manager that vends the retrieval stub as its v6 get API.
	@discussion Introduced in FxGrip 0.1.0.
*/
@implementation FxGripSettingTestAPIManager

- (id)paramGetAPIv6
{
	return self.retrievalAPI;
}

@end

/*!
	@abstract A stub effect that stands in for the host effect and carries a priority notification center.
	@discussion Introduced in FxGrip 0.1.0. It answers -effectBase with itself so rich reads route back to the stub, and it creates its notifier from NSPriorityNotificationCenter resolved at runtime.
*/
@implementation FxGripSettingTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxGripSettingTestMakePriorityCenter();
	}
	return self;
}

@end

/*!
	@abstract An XCTestCase base that wires the setting stubs together and observes the recorded set notifications.
	@discussion Introduced in FxGrip 0.1.0. It builds the stubs in -setUp, subscribes to the recorded set-notification names, and vends the v5 and v6 setting wrapper instances under test. Helper accessors expose the posted notifications, their payloads, and the recorded host calls.
*/
@implementation FxGripSettingAPITestCase

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripSettingTestStubEffect.alloc init];
	self.hostAPI = [FxGripSettingTestStubAPI.alloc init];
	self.dynamicAPI = [FxGripSettingTestDynamicAPI.alloc init];
	self.dynamicAPI.type = FxParameterType_Float;
	self.retrievalAPI = [FxGripSettingTestRetrievalAPI.alloc init];
	self.customValue = [FxGripSettingTestCustomValue.alloc init];
	self.retrievalAPI.customValue = self.customValue;

	FxGripSettingTestAPIManager *manager = [FxGripSettingTestAPIManager.alloc init];
	manager.retrievalAPI = self.retrievalAPI;
	self.effect.apiManager = manager;

	self.posted = NSMutableArray.new;
	self.observerTokens = NSMutableArray.new;
	for (NSNotificationName name in self.recordedNotificationNames) {
		[self observeName:name usingBlock:^(NSNotification *notification) {
			[self.posted addObject:notification];
		}];
	}
}

- (void)tearDown
{
	for (id token in self.observerTokens) {
		[self.effect.notifier removeObserver:token];
	}
	self.observerTokens = nil;
	self.posted = nil;
	self.customValue = nil;
	self.retrievalAPI = nil;
	self.dynamicAPI = nil;
	self.hostAPI = nil;
	self.effect = nil;
	[super tearDown];
}

/*! @abstract Returns the set-notification names the base subscribes to in -setUp. */
- (NSArray<NSNotificationName> *)recordedNotificationNames
{
	return @[FxGripNotifyAPI_ParameterSetBoolName,
			 FxGripNotifyAPI_ParameterSetCustomValueName,
			 FxGripNotifyAPI_ParameterSetFloatName,
			 FxGripNotifyAPI_ParameterSetHistogramName,
			 FxGripNotifyAPI_ParameterSetIntName,
			 FxGripNotifyAPI_ParameterSetFlagsPreName,
			 FxGripNotifyAPI_ParameterSetFlagsName,
			 FxGripNotifyAPI_ParameterSetPathIDName,
			 FxGripNotifyAPI_ParameterSetRGBAName,
			 FxGripNotifyAPI_ParameterSetRGBName,
			 FxGripNotifyAPI_ParameterSetStringValuePreName,
			 FxGripNotifyAPI_ParameterSetStringValueName,
			 FxGripNotifyAPI_ParameterSetXYName];
}

/*! @abstract Adds a notification observer to the effect's notifier and tracks its token for teardown. */
- (void)observeName:(NSNotificationName)name usingBlock:(void (^)(NSNotification *notification))block
{
	id token = [self.effect.notifier addObserverForName:name object:nil queue:nil usingBlock:block];
	[self.observerTokens addObject:token];
}

/*! @abstract Returns the names of the notifications posted so far, in order. */
- (NSArray<NSNotificationName> *)postedNames
{
	NSMutableArray<NSNotificationName> *names = NSMutableArray.new;
	for (NSNotification *notification in self.posted) {
		[names addObject:notification.name];
	}
	return names;
}

/*! @abstract Returns the first posted notification with the given name, or nil. */
- (NSNotification *)notificationNamed:(NSNotificationName)name
{
	for (NSNotification *notification in self.posted) {
		if ([notification.name isEqualToString:name]) {
			return notification;
		}
	}
	return nil;
}

/*! @abstract Returns the parameter payload of the first posted notification with the given name. */
- (NSDictionary *)payloadOf:(NSNotificationName)name
{
	return [self notificationNamed:name].userInfo.fxParameter;
}

/*! @abstract Returns the first recorded host call. */
- (NSDictionary *)hostCall
{
	return self.hostAPI.calls.firstObject;
}

/*! @abstract Returns the recorded host-call method names, in order. */
- (NSArray<NSString *> *)hostMethods
{
	NSMutableArray<NSString *> *methods = NSMutableArray.new;
	for (NSDictionary *call in self.hostAPI.calls) {
		[methods addObject:call[@"method"]];
	}
	return methods;
}

/*! A setting wrapper wired to the dynamic and retrieval stubs. */
- (FxGripParameterSettingAPI_v5 *)settingAPI
{
	return [FxGripParameterSettingAPI_v5.alloc initWithAPI:(id)self.hostAPI
											 paramGetAPIv6:(id)self.retrievalAPI
										 parameterInfoAPIv1:(id)self.dynamicAPI
													effect:(id)self.effect];
}

/*! A setting wrapper with no dynamic API, so no setter can intercept. */
- (FxGripParameterSettingAPI_v5 *)settingAPIWithoutDynamicAPI
{
	return [FxGripParameterSettingAPI_v5.alloc initWithAPI:(id)self.hostAPI
											 paramGetAPIv6:(id)self.retrievalAPI
										 parameterInfoAPIv1:nil
													effect:(id)self.effect];
}

/*! @abstract A v6 setting wrapper wired to the dynamic and retrieval stubs. */
- (FxGripParameterSettingAPI_v6 *)settingAPIv6
{
	return [FxGripParameterSettingAPI_v6.alloc initWithAPI:(id)self.hostAPI
											 paramGetAPIv6:(id)self.retrievalAPI
										 parameterInfoAPIv1:(id)self.dynamicAPI
													effect:(id)self.effect];
}

/*! @abstract Marks the parameter custom so the wrapper routes the value through the custom-value setter path. */
- (void)markParameterCustom
{
	self.dynamicAPI.type = FxParameterType_Custom;
}

/*! @abstract Returns the render time boxed in the payload of the named notification. */
- (CMTime)payloadTimeOf:(NSNotificationName)name
{
	id boxed = [self payloadOf:name][kFxParameterProperty_Time];
	return ((id<FxGripSettingTestTimeReading>)boxed).time;
}

@end
