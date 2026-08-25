//
//  FxGripParameterRetrievalAPI_v6Tests.m
//  FxGripTests
//
//  Unit tests for the parameter retrieval wrapper: the custom-parameter interception
//  each typed getter performs, the effect back-reference installed on a custom view
//  data value, the flag readback notification flow with its observer short circuit,
//  and the string readback.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxParameterFlags.h>
#import <FxGrip/FxAPINotifications.h>
#import <FxGrip/FxGripParameterRetrievalAPI_v6.h>

static const FxParameterId kRetrievalTestParameter = 31;

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxRetrievalTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

// CoreMedia is not linked, so CMTime values are built without its symbols.
static CMTime FxRetrievalTestTime(void)
{
	return (CMTime){.value = 3, .timescale = 30, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static BOOL FxRetrievalTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

#pragma mark - Test doubles

/*!
	Stands in for the host's FxParameterRetrievalAPI_v6. Every getter reports the value
	configured on the stub and records that it ran.
*/
@interface FxRetrievalTestStubAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *calls;
@property (nonatomic, assign) BOOL succeeds;
@property (nonatomic, strong) id customValue;
@property (nonatomic, assign) BOOL boolValue;
@property (nonatomic, assign) double floatValue;
@property (nonatomic, assign) int intValue;
@property (nonatomic, copy) NSString *fontName;
@property (nonatomic, copy) NSString *stringValue;
@property (nonatomic, assign) FxParameterFlags flags;
@property (nonatomic, assign) FxPathID pathID;
@property (nonatomic, assign) CMTime lastTime;
@end

@implementation FxRetrievalTestStubAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_calls = NSMutableArray.new;
		_succeeds = YES;
	}
	return self;
}

- (BOOL)record:(NSString *)method
{
	[self.calls addObject:method];
	return self.succeeds;
}

- (BOOL)getBoolValue:(BOOL *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastTime = time;
	*value = self.boolValue;
	return [self record:@"bool"];
}

- (BOOL)getCustomParameterValue:(NSObject<NSSecureCoding, NSCopying> **)value
				  fromParameter:(UInt32)parameterID
						 atTime:(CMTime)time
{
	self.lastTime = time;
	if (value) {
		*value = (id)self.customValue;
	}
	return [self record:@"custom"];
}

- (BOOL)getFloatValue:(double *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastTime = time;
	*value = self.floatValue;
	return [self record:@"float"];
}

- (BOOL)getFontName:(NSString **)fontName fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastTime = time;
	*fontName = self.fontName;
	return [self record:@"font"];
}

- (BOOL)getGradientSamples:(void *)samples
				numSamples:(NSUInteger)numSamples
					 depth:(FxDepth)sampleDepth
			 fromParameter:(UInt32)parameterID
					atTime:(CMTime)time
{
	self.lastTime = time;
	((int *)samples)[0] = 1;
	return [self record:@"gradient"];
}

- (BOOL)getHistogramBlackIn:(double *)blackIn
				   BlackOut:(double *)blackOut
					WhiteIn:(double *)whiteIn
				   WhiteOut:(double *)whiteOut
					  Gamma:(double *)gamma
				 forChannel:(FxHistogramChannel)channel
			  fromParameter:(UInt32)parameterID
					 atTime:(CMTime)time
{
	self.lastTime = time;
	*blackIn = 1;
	*blackOut = 2;
	*whiteIn = 3;
	*whiteOut = 4;
	*gamma = 5;
	return [self record:@"histogram"];
}

- (BOOL)getIntValue:(int *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastTime = time;
	*value = self.intValue;
	return [self record:@"int"];
}

- (BOOL)getParameterFlags:(FxParameterFlags *)flags fromParameter:(UInt32)parameterID
{
	*flags = self.flags;
	return [self record:@"flags"];
}

- (BOOL)getPathID:(FxPathID *)pathID fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastTime = time;
	*pathID = self.pathID;
	return [self record:@"pathid"];
}

- (BOOL)getRedValue:(double *)red
		 greenValue:(double *)green
		  blueValue:(double *)blue
		 alphaValue:(double *)alpha
	  fromParameter:(UInt32)parameterID
			 atTime:(CMTime)time
{
	self.lastTime = time;
	*red = 0.1;
	*green = 0.2;
	*blue = 0.3;
	*alpha = 0.4;
	return [self record:@"rgba"];
}

- (BOOL)getRedValue:(double *)red
		 greenValue:(double *)green
		  blueValue:(double *)blue
	  fromParameter:(UInt32)parameterID
			 atTime:(CMTime)time
{
	self.lastTime = time;
	*red = 0.1;
	*green = 0.2;
	*blue = 0.3;
	return [self record:@"rgb"];
}

- (BOOL)getStringParameterValue:(NSString **)string fromParameter:(UInt32)parameterID
{
	*string = self.stringValue;
	return [self record:@"string"];
}

- (BOOL)getXValue:(double *)x YValue:(double *)y fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastTime = time;
	*x = 0.25;
	*y = 0.75;
	return [self record:@"xy"];
}

@end

/*! Answers the parameter type the getters branch on. */
@interface FxRetrievalTestDynamicAPI : NSObject
@property (nonatomic, assign) FxParameterType type;
@end

@implementation FxRetrievalTestDynamicAPI

- (FxParameterType)parameterType:(FxParameterId)parameterID
{
	return self.type;
}

@end

/*!
	The custom parameter value the interception branch reads through. It reports
	conformance to FxGripMutableParameter through -conformsToProtocol: so the protocol,
	which is not a public framework header, needs no local redeclaration.
*/
@interface FxRetrievalTestCustomValue : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *receivedGetters;
@property (nonatomic, assign) BOOL conforms;
@property (nonatomic, assign) BOOL getterSucceeds;
@end

@implementation FxRetrievalTestCustomValue

- (instancetype)init
{
	self = [super init];
	if (self) {
		_receivedGetters = NSMutableArray.new;
		_conforms = YES;
		_getterSucceeds = YES;
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

- (BOOL)record:(NSString *)getter
{
	[self.receivedGetters addObject:getter];
	return self.getterSucceeds;
}

- (BOOL)getBoolValue:(BOOL *)value
{
	*value = YES;
	return [self record:@"bool"];
}

- (BOOL)getFloatValue:(double *)value
{
	*value = 9.5;
	return [self record:@"float"];
}

- (BOOL)getIntValue:(int *)value
{
	*value = 42;
	return [self record:@"int"];
}

- (BOOL)getFontName:(NSString **)fontName
{
	*fontName = @"CustomFont";
	return [self record:@"font"];
}

- (BOOL)getGradientSamples:(void *)samples numSamples:(NSUInteger)numSamples depth:(FxDepth)sampleDepth
{
	((int *)samples)[0] = 7;
	return [self record:@"gradient"];
}

- (BOOL)getHistogramBlackIn:(double *)blackIn
				   blackOut:(double *)blackOut
					whiteIn:(double *)whiteIn
				   whiteOut:(double *)whiteOut
					  gamma:(double *)gamma
				 forChannel:(FxHistogramChannel)channel
{
	*blackIn = 10;
	*blackOut = 20;
	*whiteIn = 30;
	*whiteOut = 40;
	*gamma = 50;
	return [self record:@"histogram"];
}

- (BOOL)getPathID:(FxPathID *)pathID
{
	*pathID = NULL;
	return [self record:@"pathid"];
}

- (BOOL)getRedValue:(double *)red greenValue:(double *)green blueValue:(double *)blue alphaValue:(double *)alpha
{
	*red = 1;
	*green = 2;
	*blue = 3;
	*alpha = 4;
	return [self record:@"rgba"];
}

- (BOOL)getRedValue:(double *)red greenValue:(double *)green blueValue:(double *)blue
{
	*red = 1;
	*green = 2;
	*blue = 3;
	return [self record:@"rgb"];
}

- (BOOL)getStringParameterValue:(NSString **)string
{
	*string = @"CustomString";
	return [self record:@"string"];
}

- (BOOL)getXValue:(double *)x YValue:(double *)y
{
	*x = 5;
	*y = 6;
	return [self record:@"xy"];
}

@end

/*! Conforms to FxGripMutableParameter but implements none of its getters. */
@interface FxRetrievalTestOpaqueValue : NSObject
@end

@implementation FxRetrievalTestOpaqueValue

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
	if (strcmp(protocol_getName(aProtocol), "FxGripMutableParameter") == 0) {
		return YES;
	}
	return [super conformsToProtocol:aProtocol];
}

@end

/*!
	A value that adopts FxGripCustomViewData. getCustomParameterValue: installs the effect
	back-reference on such a value before handing back a successful read.
*/
@interface FxRetrievalTestViewDataValue : NSObject
@property (nonatomic, weak) id parameterEffect;
@end

@implementation FxRetrievalTestViewDataValue

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
	if (strcmp(protocol_getName(aProtocol), "FxGripCustomViewData") == 0) {
		return YES;
	}
	return [super conformsToProtocol:aProtocol];
}

@end

/*!
	FxTileableEffectBase's designated initializer registers into the process-wide
	notification center, so the wrapper is exercised against a stub carrying an isolated
	notifier.
*/
@interface FxRetrievalTestStubEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@end

@implementation FxRetrievalTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxRetrievalTestMakePriorityCenter();
	}
	return self;
}

@end

#pragma mark - Tests

@interface FxGripParameterRetrievalAPI_v6Tests : XCTestCase
@property (nonatomic, strong) FxRetrievalTestStubEffect *effect;
@property (nonatomic, strong) FxRetrievalTestStubAPI *hostAPI;
@property (nonatomic, strong) FxRetrievalTestDynamicAPI *dynamicAPI;
@property (nonatomic, strong) FxRetrievalTestCustomValue *customValue;
@property (nonatomic, strong) NSMutableArray<NSNotification *> *posted;
// The notifier holds its observers weakly, so every token is retained for the test.
@property (nonatomic, strong) NSMutableArray *observerTokens;
@end

@implementation FxGripParameterRetrievalAPI_v6Tests

- (void)setUp
{
	[super setUp];
	self.effect = [FxRetrievalTestStubEffect.alloc init];
	self.hostAPI = [FxRetrievalTestStubAPI.alloc init];
	self.dynamicAPI = [FxRetrievalTestDynamicAPI.alloc init];
	self.dynamicAPI.type = FxParameterType_Float;
	self.customValue = [FxRetrievalTestCustomValue.alloc init];
	self.hostAPI.customValue = self.customValue;

	self.posted = NSMutableArray.new;
	self.observerTokens = NSMutableArray.new;
	for (NSNotificationName name in @[FxNotifyAPI_ParameterGetFlagsPreName,
									  FxNotifyAPI_ParameterGetFlagsName,
									  FxNotifyAPI_ParameterGetStringValueName]) {
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
	self.dynamicAPI = nil;
	self.hostAPI = nil;
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

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

- (FxGripParameterRetrievalAPI_v6 *)retrievalAPI
{
	return [FxGripParameterRetrievalAPI_v6.alloc initWithAPI:(id)self.hostAPI
										   dynamicParamAPIv4:(id)self.dynamicAPI
													  effect:(id)self.effect];
}

- (FxGripParameterRetrievalAPI_v6 *)retrievalAPIWithoutDynamicAPI
{
	return [FxGripParameterRetrievalAPI_v6.alloc initWithAPI:(id)self.hostAPI
										   dynamicParamAPIv4:nil
													  effect:(id)self.effect];
}

- (void)markParameterCustom
{
	self.dynamicAPI.type = FxParameterType_Custom;
}

#pragma mark Pass-through readbacks

- (void)testGetBoolValueReadsTheHostValueAtTheGivenTime
{
	self.hostAPI.boolValue = YES;
	BOOL value = NO;

	XCTAssertTrue([self.retrievalAPI getBoolValue:&value
									fromParameter:kRetrievalTestParameter
										   atTime:FxRetrievalTestTime()]);

	XCTAssertTrue(value);
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"bool"]);
	XCTAssertTrue(FxRetrievalTestTimesEqual(self.hostAPI.lastTime, FxRetrievalTestTime()));
}

- (void)testGetFloatValueReadsTheHostValue
{
	self.hostAPI.floatValue = 0.75;
	double value = 0;

	XCTAssertTrue([self.retrievalAPI getFloatValue:&value
									 fromParameter:kRetrievalTestParameter
											atTime:FxRetrievalTestTime()]);

	XCTAssertEqual(value, 0.75);
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"float"]);
}

- (void)testGetIntValueReadsTheHostValue
{
	self.hostAPI.intValue = 12;
	int value = 0;

	XCTAssertTrue([self.retrievalAPI getIntValue:&value
								   fromParameter:kRetrievalTestParameter
										  atTime:FxRetrievalTestTime()]);

	XCTAssertEqual(value, 12);
}

- (void)testGetFontNameReadsTheHostValue
{
	self.hostAPI.fontName = @"Helvetica";
	NSString *fontName = nil;

	XCTAssertTrue([self.retrievalAPI getFontName:&fontName
								   fromParameter:kRetrievalTestParameter
										  atTime:FxRetrievalTestTime()]);

	XCTAssertEqualObjects(fontName, @"Helvetica");
}

- (void)testGetGradientSamplesReadsTheHostBuffer
{
	int samples[4] = {0, 0, 0, 0};

	XCTAssertTrue([self.retrievalAPI getGradientSamples:samples
											 numSamples:4
												  depth:kFxDepth_FLOAT32
										  fromParameter:kRetrievalTestParameter
												 atTime:FxRetrievalTestTime()]);

	XCTAssertEqual(samples[0], 1);
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"gradient"]);
}

- (void)testGetHistogramReadsEveryHostComponent
{
	double blackIn = 0, blackOut = 0, whiteIn = 0, whiteOut = 0, gamma = 0;

	XCTAssertTrue([self.retrievalAPI getHistogramBlackIn:&blackIn
												BlackOut:&blackOut
												 WhiteIn:&whiteIn
												WhiteOut:&whiteOut
												   Gamma:&gamma
											  forChannel:kFxHistogramChannel_RGB
										   fromParameter:kRetrievalTestParameter
												  atTime:FxRetrievalTestTime()]);

	XCTAssertEqual(blackIn, 1);
	XCTAssertEqual(gamma, 5);
}

- (void)testGetPathIDReadsTheHostValue
{
	int storage = 0;
	self.hostAPI.pathID = &storage;
	FxPathID pathID = NULL;

	XCTAssertTrue([self.retrievalAPI getPathID:&pathID
								 fromParameter:kRetrievalTestParameter
										atTime:FxRetrievalTestTime()]);

	XCTAssertEqual(pathID, (FxPathID)&storage);
}

- (void)testGetRedGreenBlueAlphaReadsEveryHostComponent
{
	double red = 0, green = 0, blue = 0, alpha = 0;

	XCTAssertTrue([self.retrievalAPI getRedValue:&red
									  greenValue:&green
									   blueValue:&blue
									  alphaValue:&alpha
								   fromParameter:kRetrievalTestParameter
										  atTime:FxRetrievalTestTime()]);

	XCTAssertEqual(red, 0.1);
	XCTAssertEqual(alpha, 0.4);
}

- (void)testGetRedGreenBlueReadsThreeHostComponents
{
	double red = 0, green = 0, blue = 0;

	XCTAssertTrue([self.retrievalAPI getRedValue:&red
									  greenValue:&green
									   blueValue:&blue
								   fromParameter:kRetrievalTestParameter
										  atTime:FxRetrievalTestTime()]);

	XCTAssertEqual(blue, 0.3);
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"rgb"]);
}

- (void)testGetXYReadsBothHostCoordinates
{
	double x = 0, y = 0;

	XCTAssertTrue([self.retrievalAPI getXValue:&x
										YValue:&y
								 fromParameter:kRetrievalTestParameter
										atTime:FxRetrievalTestTime()]);

	XCTAssertEqual(x, 0.25);
	XCTAssertEqual(y, 0.75);
}

- (void)testAHostRefusalIsReported
{
	self.hostAPI.succeeds = NO;
	BOOL boolValue = NO;
	double floatValue = 0;
	int intValue = 0;

	XCTAssertFalse([self.retrievalAPI getBoolValue:&boolValue fromParameter:kRetrievalTestParameter atTime:FxRetrievalTestTime()]);
	XCTAssertFalse([self.retrievalAPI getFloatValue:&floatValue fromParameter:kRetrievalTestParameter atTime:FxRetrievalTestTime()]);
	XCTAssertFalse([self.retrievalAPI getIntValue:&intValue fromParameter:kRetrievalTestParameter atTime:FxRetrievalTestTime()]);
}

#pragma mark Custom parameter interception

- (void)testEveryTypedGetterInterceptsACustomParameter
{
	[self markParameterCustom];
	FxGripParameterRetrievalAPI_v6 *api = self.retrievalAPI;
	CMTime time = FxRetrievalTestTime();
	BOOL boolValue = NO;
	double floatValue = 0, red = 0, green = 0, blue = 0, alpha = 0, x = 0, y = 0;
	double blackIn = 0, blackOut = 0, whiteIn = 0, whiteOut = 0, gamma = 0;
	int intValue = 0;
	int samples[4] = {0, 0, 0, 0};
	NSString *fontName = nil;
	NSString *stringValue = nil;
	FxPathID pathID = NULL;

	XCTAssertTrue([api getBoolValue:&boolValue fromParameter:kRetrievalTestParameter atTime:time]);
	XCTAssertTrue([api getFloatValue:&floatValue fromParameter:kRetrievalTestParameter atTime:time]);
	XCTAssertTrue([api getIntValue:&intValue fromParameter:kRetrievalTestParameter atTime:time]);
	XCTAssertTrue([api getFontName:&fontName fromParameter:kRetrievalTestParameter atTime:time]);
	XCTAssertTrue([api getGradientSamples:samples numSamples:4 depth:kFxDepth_FLOAT32 fromParameter:kRetrievalTestParameter atTime:time]);
	XCTAssertTrue([api getHistogramBlackIn:&blackIn BlackOut:&blackOut WhiteIn:&whiteIn WhiteOut:&whiteOut Gamma:&gamma forChannel:kFxHistogramChannel_RGB fromParameter:kRetrievalTestParameter atTime:time]);
	XCTAssertTrue([api getPathID:&pathID fromParameter:kRetrievalTestParameter atTime:time]);
	XCTAssertTrue([api getRedValue:&red greenValue:&green blueValue:&blue alphaValue:&alpha fromParameter:kRetrievalTestParameter atTime:time]);
	XCTAssertTrue([api getRedValue:&red greenValue:&green blueValue:&blue fromParameter:kRetrievalTestParameter atTime:time]);
	XCTAssertTrue([api getStringParameterValue:&stringValue fromParameter:kRetrievalTestParameter]);
	XCTAssertTrue([api getXValue:&x YValue:&y fromParameter:kRetrievalTestParameter atTime:time]);

	XCTAssertEqualObjects(self.customValue.receivedGetters, (@[@"bool", @"float", @"int",
															   @"font", @"gradient", @"histogram",
															   @"pathid", @"rgba", @"rgb",
															   @"string", @"xy"]));
	XCTAssertTrue(boolValue);
	XCTAssertEqual(floatValue, 9.5);
	XCTAssertEqual(intValue, 42);
	XCTAssertEqualObjects(fontName, @"CustomFont");
	XCTAssertEqual(samples[0], 7);
	XCTAssertEqual(blackIn, 10);
	XCTAssertEqual(alpha, 4);
	XCTAssertEqualObjects(stringValue, @"CustomString");
	XCTAssertEqual(x, 5);
}

- (void)testACustomParameterWhoseValueCannotBeReadFallsBackToTheHostGetter
{
	[self markParameterCustom];
	self.hostAPI.succeeds = NO;
	self.hostAPI.floatValue = 0.5;
	double value = 0;

	XCTAssertFalse([self.retrievalAPI getFloatValue:&value
									  fromParameter:kRetrievalTestParameter
											 atTime:FxRetrievalTestTime()]);

	XCTAssertEqualObjects(self.hostAPI.calls, (@[@"custom", @"float"]),
						  @"a failed custom read leaves the plain host getter in charge");
	XCTAssertEqualObjects(self.customValue.receivedGetters, @[]);
}

- (void)testACustomValueThatDoesNotAdoptTheMutableProtocolFallsBackToTheHostGetter
{
	[self markParameterCustom];
	self.customValue.conforms = NO;
	self.hostAPI.floatValue = 0.5;
	double value = 0;

	XCTAssertTrue([self.retrievalAPI getFloatValue:&value
									 fromParameter:kRetrievalTestParameter
											atTime:FxRetrievalTestTime()]);

	XCTAssertEqual(value, 0.5);
	XCTAssertEqualObjects(self.hostAPI.calls, (@[@"custom", @"float"]));
}

- (void)testACustomValueThatDoesNotImplementTheGetterFallsBackToTheHostGetter
{
	[self markParameterCustom];
	self.hostAPI.customValue = [FxRetrievalTestOpaqueValue.alloc init];
	self.hostAPI.floatValue = 0.5;
	double value = 0;

	XCTAssertTrue([self.retrievalAPI getFloatValue:&value
									 fromParameter:kRetrievalTestParameter
											atTime:FxRetrievalTestTime()]);

	XCTAssertEqual(value, 0.5);
}

- (void)testACustomGetterThatFailsIsReportedWithoutFallingBack
{
	[self markParameterCustom];
	self.customValue.getterSucceeds = NO;
	double value = 0;

	XCTAssertFalse([self.retrievalAPI getFloatValue:&value
									  fromParameter:kRetrievalTestParameter
											 atTime:FxRetrievalTestTime()]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[@"custom"]);
}

- (void)testWithoutADynamicAPINoGetterIntercepts
{
	[self markParameterCustom];
	self.hostAPI.floatValue = 0.5;
	double value = 0;

	XCTAssertTrue([self.retrievalAPIWithoutDynamicAPI getFloatValue:&value
													 fromParameter:kRetrievalTestParameter
															atTime:FxRetrievalTestTime()]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[@"float"]);
	XCTAssertEqualObjects(self.customValue.receivedGetters, @[]);
}

#pragma mark getCustomParameterValue:

- (void)testGetCustomParameterValueHandsBackTheHostValue
{
	NSObject<NSSecureCoding, NSCopying> *value = nil;

	XCTAssertTrue([self.retrievalAPI getCustomParameterValue:&value
											   fromParameter:kRetrievalTestParameter
													  atTime:FxRetrievalTestTime()]);

	XCTAssertTrue((id)value == (id)self.customValue);
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"custom"]);
}

- (void)testGetCustomParameterValueInstallsTheEffectOnACustomViewDataValue
{
	FxRetrievalTestViewDataValue *viewData = [FxRetrievalTestViewDataValue.alloc init];
	self.hostAPI.customValue = viewData;
	NSObject<NSSecureCoding, NSCopying> *value = nil;

	XCTAssertTrue([self.retrievalAPI getCustomParameterValue:&value
											   fromParameter:kRetrievalTestParameter
													  atTime:FxRetrievalTestTime()]);

	XCTAssertTrue(viewData.parameterEffect == (id)self.effect);
}

- (void)testGetCustomParameterValueHandsBackANilValueUntouched
{
	self.hostAPI.customValue = nil;
	NSObject<NSSecureCoding, NSCopying> *value = nil;

	XCTAssertTrue([self.retrievalAPI getCustomParameterValue:&value
											   fromParameter:kRetrievalTestParameter
													  atTime:FxRetrievalTestTime()]);

	XCTAssertNil(value);
}

- (void)testGetCustomParameterValueLeavesTheEffectUninstalledWhenTheHostReportsFailure
{
	FxRetrievalTestViewDataValue *viewData = [FxRetrievalTestViewDataValue.alloc init];
	self.hostAPI.customValue = viewData;
	self.hostAPI.succeeds = NO;
	NSObject<NSSecureCoding, NSCopying> *value = nil;

	XCTAssertFalse([self.retrievalAPI getCustomParameterValue:&value
												fromParameter:kRetrievalTestParameter
													   atTime:FxRetrievalTestTime()]);

	XCTAssertNil(viewData.parameterEffect,
				 @"a failed read hands back no value the effect can own");
}

#pragma mark getParameterFlags:

- (void)testGetParameterFlagsAsksTheHostAndPostsBothNotifications
{
	self.hostAPI.flags = kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED;
	FxParameterFlags flags = 0;

	XCTAssertTrue([self.retrievalAPI getParameterFlags:&flags fromParameter:kRetrievalTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[@"flags"]);
	XCTAssertEqualObjects(self.postedNames, (@[FxNotifyAPI_ParameterGetFlagsPreName,
											   FxNotifyAPI_ParameterGetFlagsName]));
}

/*!
	DEFECT: getParameterFlags:fromParameter: writes the host's flags into the caller's out
	parameter, then overwrites it with the payload value it seeded as zero before the read.
	The payload is never seeded from the host, so the caller sees zero unless an observer
	writes the flags back. FxGripParameterSettingAPI_v6's addFlags: and removeFlags: build
	on this read. This test states the intended readback and fails today.
*/
- (void)testGetParameterFlagsReportsTheFlagsTheHostSupplies
{
	self.hostAPI.flags = kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED;
	FxParameterFlags flags = 0;

	[self.retrievalAPI getParameterFlags:&flags fromParameter:kRetrievalTestParameter];

	XCTAssertEqual(flags, (FxParameterFlags)(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED));
}

/*! The observers see the flags the host reported, so a mutation acts on the real value. */
- (void)testTheReadFlagsNotificationCarriesTheHostFlags
{
	self.hostAPI.flags = kFxParameterFlag_HIDDEN;
	__block NSDictionary *seen = nil;
	[self observeName:FxNotifyAPI_ParameterGetFlagsName usingBlock:^(NSNotification *notification) {
		seen = notification.userInfo.fxParameter.copy;
	}];
	FxParameterFlags flags = 0;

	[self.retrievalAPI getParameterFlags:&flags fromParameter:kRetrievalTestParameter];

	XCTAssertEqualObjects(seen[kFxParameterProperty_Flags], @(kFxParameterFlag_HIDDEN));
	XCTAssertEqual(flags, (FxParameterFlags)kFxParameterFlag_HIDDEN);
}

- (void)testTheFlagsPreNotificationRunsBeforeTheHostIsAsked
{
	__block NSUInteger callsAtPre = NSUIntegerMax;
	[self observeName:FxNotifyAPI_ParameterGetFlagsPreName usingBlock:^(NSNotification *notification) {
		callsAtPre = self.hostAPI.calls.count;
	}];
	FxParameterFlags flags = 0;

	[self.retrievalAPI getParameterFlags:&flags fromParameter:kRetrievalTestParameter];

	XCTAssertEqual(callsAtPre, (NSUInteger)0);
}

- (void)testAnObserverAnsweringThePreNotificationSuppliesTheFlagsWithoutTheHost
{
	[self observeName:FxNotifyAPI_ParameterGetFlagsPreName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[kFxParameterProperty_Flags] =
			@(kFxParameterFlag_COLLAPSED);
		((NSMutableDictionary *)notification.userInfo).fxResult = @YES;
	}];
	FxParameterFlags flags = 0;

	XCTAssertTrue([self.retrievalAPI getParameterFlags:&flags fromParameter:kRetrievalTestParameter]);

	XCTAssertEqual(flags, (FxParameterFlags)kFxParameterFlag_COLLAPSED);
	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertEqualObjects(self.postedNames, @[FxNotifyAPI_ParameterGetFlagsPreName]);
}

- (void)testAnObserverAnsweringThePreNotificationWithNOReportsFailure
{
	[self observeName:FxNotifyAPI_ParameterGetFlagsPreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxResult = @NO;
	}];
	FxParameterFlags flags = 0xFFFF;

	XCTAssertFalse([self.retrievalAPI getParameterFlags:&flags fromParameter:kRetrievalTestParameter]);

	XCTAssertEqual(flags, (FxParameterFlags)0, @"the answered payload still supplies the flags");
	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

- (void)testAnObserverRewritingTheReadFlagsChangesWhatTheCallerSees
{
	self.hostAPI.flags = kFxParameterFlag_HIDDEN;
	[self observeName:FxNotifyAPI_ParameterGetFlagsName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[kFxParameterProperty_Flags] =
			@(kFxParameterFlag_DISABLED);
	}];
	FxParameterFlags flags = 0;

	XCTAssertTrue([self.retrievalAPI getParameterFlags:&flags fromParameter:kRetrievalTestParameter]);

	XCTAssertEqual(flags, (FxParameterFlags)kFxParameterFlag_DISABLED);
}

- (void)testAnObserverSettingAnErrorOnTheReadFlagsReportsFailure
{
	[self observeName:FxNotifyAPI_ParameterGetFlagsName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError =
			[NSError errorWithDomain:@"FxRetrievalTest" code:1 userInfo:nil];
	}];
	FxParameterFlags flags = 0;

	XCTAssertFalse([self.retrievalAPI getParameterFlags:&flags fromParameter:kRetrievalTestParameter]);
}

- (void)testFlagsTheHostRefusesPostOnlyThePreNotification
{
	self.hostAPI.succeeds = NO;
	FxParameterFlags flags = 0;

	XCTAssertFalse([self.retrievalAPI getParameterFlags:&flags fromParameter:kRetrievalTestParameter]);

	XCTAssertEqualObjects(self.postedNames, @[FxNotifyAPI_ParameterGetFlagsPreName]);
}

#pragma mark getStringParameterValue:

- (void)testGetStringValuePostsTheReadNotificationCarryingTheHostValue
{
	self.hostAPI.stringValue = @"HostValue";
	__block NSString *seen = nil;
	[self observeName:FxNotifyAPI_ParameterGetStringValueName usingBlock:^(NSNotification *notification) {
		seen = notification.userInfo.fxParameter[kFxParameterProperty_Default];
	}];
	NSString *value = nil;

	XCTAssertTrue([self.retrievalAPI getStringParameterValue:&value
											   fromParameter:kRetrievalTestParameter]);

	XCTAssertEqualObjects(seen, @"HostValue");
	XCTAssertEqualObjects(value, @"HostValue");
}

- (void)testAStringValueTheHostRefusesPostsNothing
{
	self.hostAPI.succeeds = NO;
	self.hostAPI.stringValue = @"HostValue";
	NSString *value = nil;

	XCTAssertFalse([self.retrievalAPI getStringParameterValue:&value
												fromParameter:kRetrievalTestParameter]);

	XCTAssertEqualObjects(self.posted, @[]);
}

- (void)testAStringValueOnACustomParameterComesFromTheCustomValueWithoutANotification
{
	[self markParameterCustom];
	NSString *value = nil;

	XCTAssertTrue([self.retrievalAPI getStringParameterValue:&value
											   fromParameter:kRetrievalTestParameter]);

	XCTAssertEqualObjects(value, @"CustomString");
	XCTAssertEqualObjects(self.posted, @[]);
}

@end
