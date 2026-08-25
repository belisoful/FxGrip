//
//  FxGripParameterSettingAPITests.m
//  FxGripTests
//
//  Unit tests for the parameter setting wrappers. FxGripParameterSettingAPI_v5 routes
//  every typed setter either into a custom parameter value that adopts
//  FxGripMutableParameter or into the host API followed by a change notification;
//  setParameterFlags: and setStringParameterValue: additionally run a pre-notification
//  the observers can answer or rewrite. FxGripParameterSettingAPI_v6 adds the
//  read-modify-write flag helpers.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxParameterFlags.h>
#import <FxGrip/FxAPINotifications.h>
#import <FxGrip/FxGripParameterSettingAPI_v5.h>
#import <FxGrip/FxGripParameterSettingAPI_v6.h>

static const FxParameterId kSettingTestParameter = 21;

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxSettingTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

// The wrappers box each time as a BEFoundation FxTime. The test target does not link
// BEFoundation, so the wrapped CMTime is read through a locally declared accessor
// rather than through the FxTime class symbol.
@protocol FxSettingTestTimeReading <NSObject>
@property (readonly) CMTime time;
@end

// CoreMedia is not linked either, so CMTime values are built without its symbols.
static CMTime FxSettingTestTime(void)
{
	return (CMTime){.value = 7, .timescale = 24, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static CMTime FxSettingTestZeroTime(void)
{
	return (CMTime){.value = 0, .timescale = 1, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static BOOL FxSettingTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

#pragma mark - Test doubles

/*! Stands in for the host's FxParameterSettingAPI_v6, recording every forwarded call. */
@interface FxSettingTestStubAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *calls;
@property (nonatomic, assign) BOOL succeeds;
@property (nonatomic, assign) CMTime lastTime;
@end

@implementation FxSettingTestStubAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_calls = NSMutableArray.new;
		_succeeds = YES;
	}
	return self;
}

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

/*! Answers the parameter type the setters branch on. */
@interface FxSettingTestDynamicAPI : NSObject
@property (nonatomic, assign) FxParameterType type;
@end

@implementation FxSettingTestDynamicAPI

- (FxParameterType)parameterType:(FxParameterId)parameterID
{
	return self.type;
}

@end

/*!
	The custom parameter value the interception branch mutates. It reports conformance to
	FxGripMutableParameter through -conformsToProtocol: so the protocol, which is not a
	public framework header, needs no local redeclaration.
*/
@interface FxSettingTestCustomValue : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *receivedSetters;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *receivedValues;
@property (nonatomic, assign) BOOL conforms;
@property (nonatomic, assign) BOOL setterSucceeds;
@end

@implementation FxSettingTestCustomValue

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

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
	if (strcmp(protocol_getName(aProtocol), "FxGripMutableParameter") == 0) {
		return self.conforms;
	}
	return [super conformsToProtocol:aProtocol];
}

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

/*! Conforms to FxGripMutableParameter but implements none of its setters. */
@interface FxSettingTestOpaqueValue : NSObject
@end

@implementation FxSettingTestOpaqueValue

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
	if (strcmp(protocol_getName(aProtocol), "FxGripMutableParameter") == 0) {
		return YES;
	}
	return [super conformsToProtocol:aProtocol];
}

@end

/*! Serves the custom parameter read the interception branch performs. */
@interface FxSettingTestRetrievalAPI : NSObject
@property (nonatomic, strong) id customValue;
@property (nonatomic, assign) BOOL succeeds;
@property (nonatomic, assign) NSUInteger readCount;
@property (nonatomic, assign) CMTime lastTime;
@property (nonatomic, assign) FxParameterFlags flags;
@property (nonatomic, assign) BOOL flagsSucceed;
@end

@implementation FxSettingTestRetrievalAPI

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

@interface FxSettingTestAPIManager : NSObject
@property (nonatomic, strong) FxSettingTestRetrievalAPI *retrievalAPI;
@end

@implementation FxSettingTestAPIManager

- (id)paramGetAPIv6
{
	return self.retrievalAPI;
}

@end

/*!
	FxTileableEffectBase's designated initializer registers into the process-wide
	notification center, so the wrappers are exercised against a stub carrying an isolated
	notifier. The v6 flag helpers additionally read -apiManager.
*/
@interface FxSettingTestStubEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, strong) FxSettingTestAPIManager *apiManager;
@end

@implementation FxSettingTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxSettingTestMakePriorityCenter();
	}
	return self;
}

@end

#pragma mark - Tests

@interface FxGripParameterSettingAPITests : XCTestCase
@property (nonatomic, strong) FxSettingTestStubEffect *effect;
@property (nonatomic, strong) FxSettingTestStubAPI *hostAPI;
@property (nonatomic, strong) FxSettingTestDynamicAPI *dynamicAPI;
@property (nonatomic, strong) FxSettingTestRetrievalAPI *retrievalAPI;
@property (nonatomic, strong) FxSettingTestCustomValue *customValue;
@property (nonatomic, strong) NSMutableArray<NSNotification *> *posted;
// The notifier holds its observers weakly, so every token is retained for the test.
@property (nonatomic, strong) NSMutableArray *observerTokens;
@end

@implementation FxGripParameterSettingAPITests

- (void)setUp
{
	[super setUp];
	self.effect = [FxSettingTestStubEffect.alloc init];
	self.hostAPI = [FxSettingTestStubAPI.alloc init];
	self.dynamicAPI = [FxSettingTestDynamicAPI.alloc init];
	self.dynamicAPI.type = FxParameterType_Float;
	self.retrievalAPI = [FxSettingTestRetrievalAPI.alloc init];
	self.customValue = [FxSettingTestCustomValue.alloc init];
	self.retrievalAPI.customValue = self.customValue;

	FxSettingTestAPIManager *manager = [FxSettingTestAPIManager.alloc init];
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

#pragma mark Helpers

- (NSArray<NSNotificationName> *)recordedNotificationNames
{
	return @[FxNotifyAPI_ParameterSetBoolName,
			 FxNotifyAPI_ParameterSetCustomValueName,
			 FxNotifyAPI_ParameterSetFloatName,
			 FxNotifyAPI_ParameterSetHistogramName,
			 FxNotifyAPI_ParameterSetIntName,
			 FxNotifyAPI_ParameterSetFlagsPreName,
			 FxNotifyAPI_ParameterSetFlagsName,
			 FxNotifyAPI_ParameterSetPathIDName,
			 FxNotifyAPI_ParameterSetRGBAName,
			 FxNotifyAPI_ParameterSetRGBName,
			 FxNotifyAPI_ParameterSetStringValuePreName,
			 FxNotifyAPI_ParameterSetStringValueName,
			 FxNotifyAPI_ParameterSetXYName];
}

- (void)observeName:(NSNotificationName)name usingBlock:(void (^)(NSNotification *notification))block
{
	id token = [self.effect.notifier addObserverForName:name object:nil queue:nil usingBlock:block];
	[self.observerTokens addObject:token];
}

- (NSArray<NSNotificationName> *)postedNames
{
	NSMutableArray<NSNotificationName> *names = NSMutableArray.new;
	for (NSNotification *notification in self.posted) {
		[names addObject:notification.name];
	}
	return names;
}

- (NSNotification *)notificationNamed:(NSNotificationName)name
{
	for (NSNotification *notification in self.posted) {
		if ([notification.name isEqualToString:name]) {
			return notification;
		}
	}
	return nil;
}

- (NSDictionary *)payloadOf:(NSNotificationName)name
{
	return [self notificationNamed:name].userInfo.fxParameter;
}

- (NSDictionary *)hostCall
{
	return self.hostAPI.calls.firstObject;
}

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
										 dynamicParamAPIv4:(id)self.dynamicAPI
													effect:(id)self.effect];
}

/*! A setting wrapper with no dynamic API, so no setter can intercept. */
- (FxGripParameterSettingAPI_v5 *)settingAPIWithoutDynamicAPI
{
	return [FxGripParameterSettingAPI_v5.alloc initWithAPI:(id)self.hostAPI
											 paramGetAPIv6:(id)self.retrievalAPI
										 dynamicParamAPIv4:nil
													effect:(id)self.effect];
}

- (FxGripParameterSettingAPI_v6 *)settingAPIv6
{
	return [FxGripParameterSettingAPI_v6.alloc initWithAPI:(id)self.hostAPI
											 paramGetAPIv6:(id)self.retrievalAPI
										 dynamicParamAPIv4:(id)self.dynamicAPI
													effect:(id)self.effect];
}

- (void)markParameterCustom
{
	self.dynamicAPI.type = FxParameterType_Custom;
}

- (CMTime)payloadTimeOf:(NSNotificationName)name
{
	id boxed = [self payloadOf:name][kFxParameterProperty_Time];
	return ((id<FxSettingTestTimeReading>)boxed).time;
}

#pragma mark Plain setter forwarding

- (void)testSetBoolValueForwardsToTheHostAndPostsTheChange
{
	XCTAssertTrue([self.settingAPI setBoolValue:YES
									toParameter:kSettingTestParameter
										 atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"bool",
											@"id": @(kSettingTestParameter),
											@"value": @YES}));
	XCTAssertTrue(FxSettingTestTimesEqual(self.hostAPI.lastTime, FxSettingTestTime()));

	NSDictionary *payload = [self payloadOf:FxNotifyAPI_ParameterSetBoolName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_Id], @(kSettingTestParameter));
	XCTAssertEqualObjects(payload[kFxParameterProperty_Default], @YES);
	XCTAssertTrue(FxSettingTestTimesEqual([self payloadTimeOf:FxNotifyAPI_ParameterSetBoolName],
										  FxSettingTestTime()));
}

- (void)testSetFloatValueForwardsToTheHostAndPostsTheChange
{
	XCTAssertTrue([self.settingAPI setFloatValue:0.25
									 toParameter:kSettingTestParameter
										  atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"float",
											@"id": @(kSettingTestParameter),
											@"value": @0.25}));
	XCTAssertEqualObjects([self payloadOf:FxNotifyAPI_ParameterSetFloatName][kFxParameterProperty_Default],
						  @0.25);
}

- (void)testSetIntValueForwardsToTheHostAndPostsTheChange
{
	XCTAssertTrue([self.settingAPI setIntValue:9
								   toParameter:kSettingTestParameter
										atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"int",
											@"id": @(kSettingTestParameter),
											@"value": @9}));
	XCTAssertEqualObjects([self payloadOf:FxNotifyAPI_ParameterSetIntName][kFxParameterProperty_Default],
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
												atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"histogram",
											@"id": @(kSettingTestParameter),
											@"blackin": @0.1,
											@"blackout": @0.2,
											@"whitein": @0.3,
											@"whiteout": @0.4,
											@"gamma": @0.5,
											@"channel": @(kFxHistogramChannel_Red)}));

	NSDictionary *payload = [self payloadOf:FxNotifyAPI_ParameterSetHistogramName];
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
									  atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall[@"value"], [NSValue valueWithPointer:pathID]);
	XCTAssertEqualObjects([self payloadOf:FxNotifyAPI_ParameterSetPathIDName][kFxParameterPropertyX_PathID],
						  [NSValue valueWithPointer:pathID]);
}

- (void)testSetRedGreenBlueAlphaForwardsEveryComponentAndPostsThem
{
	XCTAssertTrue([self.settingAPI setRedValue:0.1
									greenValue:0.2
									 blueValue:0.3
									alphaValue:0.4
								   toParameter:kSettingTestParameter
										atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"rgba",
											@"id": @(kSettingTestParameter),
											@"red": @0.1,
											@"green": @0.2,
											@"blue": @0.3,
											@"alpha": @0.4}));
	NSDictionary *payload = [self payloadOf:FxNotifyAPI_ParameterSetRGBAName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_Red], @0.1);
	XCTAssertEqualObjects(payload[kFxParameterProperty_Alpha], @0.4);
}

- (void)testSetRedGreenBlueForwardsThreeComponentsAndPostsThem
{
	XCTAssertTrue([self.settingAPI setRedValue:0.1
									greenValue:0.2
									 blueValue:0.3
								   toParameter:kSettingTestParameter
										atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"rgb",
											@"id": @(kSettingTestParameter),
											@"red": @0.1,
											@"green": @0.2,
											@"blue": @0.3}));
	NSDictionary *payload = [self payloadOf:FxNotifyAPI_ParameterSetRGBName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_Blue], @0.3);
	XCTAssertNil(payload[kFxParameterProperty_Alpha]);
}

- (void)testSetXYForwardsBothCoordinatesAndPostsThem
{
	XCTAssertTrue([self.settingAPI setXValue:0.25
									  YValue:0.75
								 toParameter:kSettingTestParameter
									  atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"xy",
											@"id": @(kSettingTestParameter),
											@"x": @0.25,
											@"y": @0.75}));
	NSDictionary *payload = [self payloadOf:FxNotifyAPI_ParameterSetXYName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_X], @0.25);
	XCTAssertEqualObjects(payload[kFxParameterProperty_Y], @0.75);
}

- (void)testSetCustomParameterValueForwardsTheObjectAndPostsIt
{
	NSString *value = @"Payload";

	XCTAssertTrue([self.settingAPI setCustomParameterValue:value
											   toParameter:kSettingTestParameter
													atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.hostMethods, @[@"custom"]);
	XCTAssertEqualObjects([self payloadOf:FxNotifyAPI_ParameterSetCustomValueName][kFxParameterProperty_Default],
						  value);
}

- (void)testAHostRefusalReportsFailureAndPostsNothing
{
	self.hostAPI.succeeds = NO;

	XCTAssertFalse([self.settingAPI setFloatValue:0.25
									  toParameter:kSettingTestParameter
										   atTime:FxSettingTestTime()]);
	XCTAssertFalse([self.settingAPI setBoolValue:YES
									 toParameter:kSettingTestParameter
										  atTime:FxSettingTestTime()]);
	XCTAssertFalse([self.settingAPI setIntValue:1
									toParameter:kSettingTestParameter
										 atTime:FxSettingTestTime()]);
	XCTAssertFalse([self.settingAPI setXValue:0 YValue:0
								  toParameter:kSettingTestParameter
									   atTime:FxSettingTestTime()]);
	XCTAssertFalse([self.settingAPI setCustomParameterValue:@"x"
												toParameter:kSettingTestParameter
													 atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.posted, @[]);
}

#pragma mark Custom parameter interception

- (void)testASetterOnACustomParameterWritesThroughTheCustomValue
{
	[self markParameterCustom];

	XCTAssertTrue([self.settingAPI setFloatValue:0.25
									 toParameter:kSettingTestParameter
										  atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, @[@"float"]);
	XCTAssertEqualObjects(self.customValue.receivedValues[@"float"], @0.25);
	XCTAssertEqualObjects(self.hostMethods, @[@"custom"],
						  @"the mutated value is written back as a custom parameter");
	XCTAssertEqualObjects(self.postedNames, @[FxNotifyAPI_ParameterSetCustomValueName]);
}

- (void)testTheCustomValueIsReadAtTheTimeTheSetterWasGiven
{
	[self markParameterCustom];

	[self.settingAPI setIntValue:3 toParameter:kSettingTestParameter atTime:FxSettingTestTime()];

	XCTAssertEqual(self.retrievalAPI.readCount, (NSUInteger)1);
	XCTAssertTrue(FxSettingTestTimesEqual(self.retrievalAPI.lastTime, FxSettingTestTime()));
	XCTAssertTrue(FxSettingTestTimesEqual(self.hostAPI.lastTime, FxSettingTestTime()));
}

- (void)testEveryTypedSetterInterceptsACustomParameter
{
	[self markParameterCustom];
	FxGripParameterSettingAPI_v5 *api = self.settingAPI;
	CMTime time = FxSettingTestTime();

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
										   atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertEqualObjects(self.posted, @[]);
}

- (void)testACustomValueThatDoesNotAdoptTheMutableProtocolReportsFailure
{
	[self markParameterCustom];
	self.customValue.conforms = NO;

	XCTAssertFalse([self.settingAPI setFloatValue:0.25
									  toParameter:kSettingTestParameter
										   atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, @[]);
	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

- (void)testACustomValueThatDoesNotImplementTheSetterReportsFailure
{
	[self markParameterCustom];
	self.retrievalAPI.customValue = [FxSettingTestOpaqueValue.alloc init];

	XCTAssertFalse([self.settingAPI setFloatValue:0.25
									  toParameter:kSettingTestParameter
										   atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

- (void)testACustomSetterThatRefusesTheValueReportsFailure
{
	[self markParameterCustom];
	self.customValue.setterSucceeds = NO;

	XCTAssertFalse([self.settingAPI setFloatValue:0.25
									  toParameter:kSettingTestParameter
										   atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, @[@"float"]);
	XCTAssertEqualObjects(self.hostAPI.calls, @[], @"a refused mutation is not written back");
}

- (void)testEverySetterReportsFailureWhenTheCustomValueCannotTakeTheMutation
{
	[self markParameterCustom];
	self.customValue.conforms = NO;
	FxGripParameterSettingAPI_v5 *api = self.settingAPI;
	CMTime time = FxSettingTestTime();

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
														  atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, @[]);
	XCTAssertEqualObjects(self.hostMethods, @[@"float"]);
}

- (void)testANonCustomParameterNeverReadsTheCustomValue
{
	XCTAssertTrue([self.settingAPI setFloatValue:0.25
									 toParameter:kSettingTestParameter
										  atTime:FxSettingTestTime()]);

	XCTAssertEqual(self.retrievalAPI.readCount, (NSUInteger)0);
}

- (void)testSetXYReportsFailureAndReachesNoHostWhenTheCustomValueRefusesTheMutation
{
	[self markParameterCustom];
	self.customValue.setterSucceeds = NO;

	XCTAssertFalse([self.settingAPI setXValue:0.25
									   YValue:0.75
								  toParameter:kSettingTestParameter
									   atTime:FxSettingTestTime()]);

	XCTAssertEqualObjects(self.customValue.receivedSetters, @[@"xy"]);
	XCTAssertEqualObjects(self.hostAPI.calls, @[], @"a refused mutation is not written back");
}

#pragma mark setStringParameterValue:

- (void)testSetStringValuePostsThePreNotificationBeforeTheHostCall
{
	__block NSUInteger callsAtPre = NSUIntegerMax;
	[self observeName:FxNotifyAPI_ParameterSetStringValuePreName usingBlock:^(NSNotification *notification) {
		callsAtPre = self.hostAPI.calls.count;
	}];

	XCTAssertTrue([self.settingAPI setStringParameterValue:@"Original"
											  toParameter:kSettingTestParameter]);

	XCTAssertEqual(callsAtPre, (NSUInteger)0);
	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"string",
											@"id": @(kSettingTestParameter),
											@"value": @"Original"}));
	XCTAssertEqualObjects(self.postedNames, (@[FxNotifyAPI_ParameterSetStringValuePreName,
											   FxNotifyAPI_ParameterSetStringValueName]));
}

- (void)testAnObserverRewritingTheStringChangesWhatTheHostReceives
{
	[self observeName:FxNotifyAPI_ParameterSetStringValuePreName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[kFxParameterProperty_Default] = @"Localized";
	}];

	XCTAssertTrue([self.settingAPI setStringParameterValue:@"Original"
											  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostCall[@"value"], @"Localized");
	XCTAssertEqualObjects([self payloadOf:FxNotifyAPI_ParameterSetStringValueName][kFxParameterProperty_Default],
						  @"Localized");
}

- (void)testAStringValueTheHostRefusesPostsOnlyThePreNotification
{
	self.hostAPI.succeeds = NO;

	XCTAssertFalse([self.settingAPI setStringParameterValue:@"Original"
											   toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.postedNames, @[FxNotifyAPI_ParameterSetStringValuePreName]);
}

- (void)testAStringValueOnACustomParameterUsesTheRewrittenStringAtTheZeroTime
{
	[self markParameterCustom];
	[self observeName:FxNotifyAPI_ParameterSetStringValuePreName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[kFxParameterProperty_Default] = @"Localized";
	}];

	XCTAssertTrue([self.settingAPI setStringParameterValue:@"Original"
											  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.customValue.receivedValues[@"string"], @"Localized");
	XCTAssertTrue(FxSettingTestTimesEqual(self.retrievalAPI.lastTime, FxSettingTestZeroTime()));
	XCTAssertEqualObjects(self.postedNames, (@[FxNotifyAPI_ParameterSetStringValuePreName,
											   FxNotifyAPI_ParameterSetCustomValueName]),
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
	XCTAssertEqualObjects(self.postedNames, (@[FxNotifyAPI_ParameterSetFlagsPreName,
											   FxNotifyAPI_ParameterSetFlagsName]));
}

- (void)testThePostedFlagsCarryTheSavingBitAndDropTheCacheBit
{
	FxParameterFlags flags = kFxParameterFlag_HIDDEN | kFxParameterFlag_CACHE;

	XCTAssertTrue([self.settingAPI setParameterFlags:flags toParameter:kSettingTestParameter]);

	NSDictionary *payload = [self payloadOf:FxNotifyAPI_ParameterSetFlagsName];
	XCTAssertEqualObjects(payload[kFxParameterProperty_Flags],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_SAVING));
	XCTAssertEqualObjects(payload[kFxParameterProperty_Id], @(kSettingTestParameter));
}

- (void)testAnObserverRewritingTheFlagsChangesWhatTheHostReceives
{
	[self observeName:FxNotifyAPI_ParameterSetFlagsPreName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[kFxParameterProperty_Flags] =
			@(kFxParameterFlag_DISABLED);
	}];

	XCTAssertTrue([self.settingAPI setParameterFlags:kFxParameterFlag_HIDDEN
										 toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostCall[@"value"], @(kFxParameterFlag_DISABLED));
}

- (void)testAnObserverAnsweringThePreNotificationShortCircuitsTheHostCall
{
	[self observeName:FxNotifyAPI_ParameterSetFlagsPreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxResult = @YES;
	}];

	XCTAssertTrue([self.settingAPI setParameterFlags:kFxParameterFlag_HIDDEN
										 toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertEqualObjects(self.postedNames, @[FxNotifyAPI_ParameterSetFlagsPreName]);
}

- (void)testAnObserverAnsweringThePreNotificationWithNOReportsFailure
{
	[self observeName:FxNotifyAPI_ParameterSetFlagsPreName usingBlock:^(NSNotification *notification) {
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

	XCTAssertEqualObjects(self.postedNames, @[FxNotifyAPI_ParameterSetFlagsPreName]);
}

- (void)testTheFlagsPreNotificationCarriesTheRequestedFlags
{
	__block NSDictionary *seen = nil;
	[self observeName:FxNotifyAPI_ParameterSetFlagsPreName usingBlock:^(NSNotification *notification) {
		seen = notification.userInfo.fxParameter.copy;
	}];

	[self.settingAPI setParameterFlags:kFxParameterFlag_COLLAPSED toParameter:kSettingTestParameter];

	XCTAssertEqualObjects(seen, (@{kFxParameterProperty_Id: @(kSettingTestParameter),
								   kFxParameterProperty_Flags: @(kFxParameterFlag_COLLAPSED)}));
}

#pragma mark FxGripParameterSettingAPI_v6

- (void)testAddFlagsOrsTheNewBitsIntoTheCurrentFlags
{
	self.retrievalAPI.flags = kFxParameterFlag_HIDDEN;

	XCTAssertTrue([self.settingAPIv6 addFlags:kFxParameterFlag_DISABLED
								  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostCall[@"value"],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED));
}

- (void)testRemoveFlagsClearsOnlyTheNamedBits
{
	self.retrievalAPI.flags = kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED;

	XCTAssertTrue([self.settingAPIv6 removeFlags:kFxParameterFlag_HIDDEN
								   fromParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostCall[@"value"], @(kFxParameterFlag_DISABLED));
}

- (void)testAddFlagsReportsFailureWhenTheCurrentFlagsCannotBeRead
{
	self.retrievalAPI.flagsSucceed = NO;

	XCTAssertFalse([self.settingAPIv6 addFlags:kFxParameterFlag_DISABLED
								   toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertEqualObjects(self.posted, @[]);
}

- (void)testRemoveFlagsReportsFailureWhenTheCurrentFlagsCannotBeRead
{
	self.retrievalAPI.flagsSucceed = NO;

	XCTAssertFalse([self.settingAPIv6 removeFlags:kFxParameterFlag_HIDDEN
									fromParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

- (void)testTheV6FlagHelpersRunTheV5NotificationFlow
{
	self.retrievalAPI.flags = kFxParameterFlag_HIDDEN;

	XCTAssertTrue([self.settingAPIv6 addFlags:kFxParameterFlag_DISABLED
								  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.postedNames, (@[FxNotifyAPI_ParameterSetFlagsPreName,
											   FxNotifyAPI_ParameterSetFlagsName]));
}

- (void)testAnObserverAnsweringThePreNotificationAlsoShortCircuitsTheV6Helpers
{
	self.retrievalAPI.flags = kFxParameterFlag_HIDDEN;
	[self observeName:FxNotifyAPI_ParameterSetFlagsPreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxResult = @YES;
	}];

	XCTAssertTrue([self.settingAPIv6 addFlags:kFxParameterFlag_DISABLED
								  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

@end
