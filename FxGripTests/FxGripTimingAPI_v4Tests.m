//
//  FxGripTimingAPI_v4Tests.m
//  FxGripTests
//
//  Unit tests for the timing wrapper. Every query forwards to the host timing API and
//  fills the caller's CMTime; a NULL out-parameter suppresses the host call entirely.
//

#import <XCTest/XCTest.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripTimingAPI_v4.h>

static const FxParameterId kTimingTestParameter = 51;

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxTimingTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

// CoreMedia is not linked, so CMTime values are built without its symbols.
static CMTime FxTimingTestMakeTime(int64_t value)
{
	return (CMTime){.value = value, .timescale = 600, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static BOOL FxTimingTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

#pragma mark - Test doubles

/*!
	Stands in for the host's FxTimingAPI_v4. Each query records that it ran and writes a
	value derived from the query's position in -answers, so the wrapper's routing of each
	out-parameter is observable.
*/
@interface FxTimingTestStubAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *calls;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *inputValues;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *parameterIDs;
@property (nonatomic, assign) FxFieldOrder fieldOrder;
@property (nonatomic, assign) NSUInteger fpsNumerator;
@property (nonatomic, assign) NSUInteger fpsDenominator;
@property (nonatomic, strong) id lastFilter;
@end

@implementation FxTimingTestStubAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_calls = NSMutableArray.new;
		_inputValues = NSMutableDictionary.new;
		_parameterIDs = NSMutableDictionary.new;
	}
	return self;
}

/*! Each answer is the 1-based call order, so a misrouted out-parameter is visible. */
- (CMTime)answerFor:(NSString *)method
{
	[self.calls addObject:method];
	return FxTimingTestMakeTime((int64_t)self.calls.count);
}

- (void)frameDuration:(CMTime *)duration
{
	*duration = [self answerFor:@"frameDuration"];
}

- (void)sampleDuration:(CMTime *)duration
{
	*duration = [self answerFor:@"sampleDuration"];
}

- (void)startTimeForEffect:(CMTime *)startTime
{
	*startTime = [self answerFor:@"startTimeForEffect"];
}

- (void)durationTimeForEffect:(CMTime *)duration
{
	*duration = [self answerFor:@"durationTimeForEffect"];
}

- (void)startTimeOfInputToFilter:(CMTime *)startTime
{
	*startTime = [self answerFor:@"startTimeOfInputToFilter"];
}

- (void)durationTimeOfInputToFilter:(CMTime *)duration
{
	*duration = [self answerFor:@"durationTimeOfInputToFilter"];
}

- (void)startTime:(CMTime *)startTime ofImageParameter:(UInt32)parameterID
{
	self.parameterIDs[@"startTimeOfImageParameter"] = @(parameterID);
	*startTime = [self answerFor:@"startTimeOfImageParameter"];
}

- (void)durationTime:(CMTime *)duration ofImageParameter:(UInt32)parameterID
{
	self.parameterIDs[@"durationTimeOfImageParameter"] = @(parameterID);
	*duration = [self answerFor:@"durationTimeOfImageParameter"];
}

- (void)inPointTimeOfTimelineForEffect:(CMTime *)inPoint
{
	*inPoint = [self answerFor:@"inPointTimeOfTimelineForEffect"];
}

- (void)outPointTimeOfTimelineForEffect:(CMTime *)outPoint
{
	*outPoint = [self answerFor:@"outPointTimeOfTimelineForEffect"];
}

- (void)timelineTime:(CMTime *)timelineTime fromInputTime:(CMTime)time
{
	self.inputValues[@"timelineTimeFromInputTime"] = @(time.value);
	*timelineTime = [self answerFor:@"timelineTimeFromInputTime"];
}

- (void)timelineTime:(CMTime *)timelineTime fromImageTime:(CMTime)time forParameterID:(UInt32)parameterID
{
	self.inputValues[@"timelineTimeFromImageTime"] = @(time.value);
	self.parameterIDs[@"timelineTimeFromImageTime"] = @(parameterID);
	*timelineTime = [self answerFor:@"timelineTimeFromImageTime"];
}

- (void)inputTime:(CMTime *)inputTime fromTimelineTime:(CMTime)time
{
	self.inputValues[@"inputTimeFromTimelineTime"] = @(time.value);
	*inputTime = [self answerFor:@"inputTimeFromTimelineTime"];
}

- (void)imageTime:(CMTime *)imageTime forParameterID:(UInt32)parameterID fromTimelineTime:(CMTime)time
{
	self.inputValues[@"imageTimeFromTimelineTime"] = @(time.value);
	self.parameterIDs[@"imageTimeFromTimelineTime"] = @(parameterID);
	*imageTime = [self answerFor:@"imageTimeFromTimelineTime"];
}

- (FxFieldOrder)fieldOrderForInputToFilter:(id)filter
{
	self.lastFilter = filter;
	[self.calls addObject:@"fieldOrder"];
	return self.fieldOrder;
}

- (NSUInteger)timelineFpsNumeratorForEffect:(id)effect
{
	self.lastFilter = effect;
	[self.calls addObject:@"fpsNumerator"];
	return self.fpsNumerator;
}

- (NSUInteger)timelineFpsDenominatorForEffect:(id)effect
{
	self.lastFilter = effect;
	[self.calls addObject:@"fpsDenominator"];
	return self.fpsDenominator;
}

@end

/*!
	FxTileableEffectBase's designated initializer registers into the process-wide
	notification center, so the wrapper is exercised against a stub carrying an isolated
	notifier.
*/
@interface FxTimingTestStubEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, assign) BOOL hasMeta;
@end

@implementation FxTimingTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxTimingTestMakePriorityCenter();
	}
	return self;
}

@end

#pragma mark - Tests

@interface FxGripTimingAPI_v4Tests : XCTestCase
@property (nonatomic, strong) FxTimingTestStubEffect *effect;
@property (nonatomic, strong) FxTimingTestStubAPI *hostAPI;
@property (nonatomic, strong) FxGripTimingAPI_v4 *api;
@end

@implementation FxGripTimingAPI_v4Tests

- (void)setUp
{
	[super setUp];
	self.effect = [FxTimingTestStubEffect.alloc init];
	self.hostAPI = [FxTimingTestStubAPI.alloc init];
	self.api = [FxGripTimingAPI_v4.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
}

- (void)tearDown
{
	self.api = nil;
	self.hostAPI = nil;
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

/*! The value the stub writes for the first query it answers. */
- (CMTime)firstAnswer
{
	return FxTimingTestMakeTime(1);
}

#pragma mark Effect and input timing

- (void)testFrameDurationFillsTheHostValue
{
	CMTime duration = FxTimingTestMakeTime(0);

	[self.api frameDuration:&duration];

	XCTAssertTrue(FxTimingTestTimesEqual(duration, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"frameDuration"]);
}

- (void)testSampleDurationFillsTheHostValue
{
	CMTime duration = FxTimingTestMakeTime(0);

	[self.api sampleDuration:&duration];

	XCTAssertTrue(FxTimingTestTimesEqual(duration, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"sampleDuration"]);
}

- (void)testStartTimeForEffectFillsTheHostValue
{
	CMTime startTime = FxTimingTestMakeTime(0);

	[self.api startTimeForEffect:&startTime];

	XCTAssertTrue(FxTimingTestTimesEqual(startTime, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"startTimeForEffect"]);
}

- (void)testDurationTimeForEffectFillsTheHostValue
{
	CMTime duration = FxTimingTestMakeTime(0);

	[self.api durationTimeForEffect:&duration];

	XCTAssertTrue(FxTimingTestTimesEqual(duration, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"durationTimeForEffect"]);
}

- (void)testStartTimeOfInputToFilterFillsTheHostValue
{
	CMTime startTime = FxTimingTestMakeTime(0);

	[self.api startTimeOfInputToFilter:&startTime];

	XCTAssertTrue(FxTimingTestTimesEqual(startTime, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"startTimeOfInputToFilter"]);
}

- (void)testDurationTimeOfInputToFilterFillsTheHostValue
{
	CMTime duration = FxTimingTestMakeTime(0);

	[self.api durationTimeOfInputToFilter:&duration];

	XCTAssertTrue(FxTimingTestTimesEqual(duration, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"durationTimeOfInputToFilter"]);
}

- (void)testInPointTimeOfTimelineFillsTheHostValue
{
	CMTime inPoint = FxTimingTestMakeTime(0);

	[self.api inPointTimeOfTimelineForEffect:&inPoint];

	XCTAssertTrue(FxTimingTestTimesEqual(inPoint, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"inPointTimeOfTimelineForEffect"]);
}

- (void)testOutPointTimeOfTimelineFillsTheHostValue
{
	CMTime outPoint = FxTimingTestMakeTime(0);

	[self.api outPointTimeOfTimelineForEffect:&outPoint];

	XCTAssertTrue(FxTimingTestTimesEqual(outPoint, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.calls, @[@"outPointTimeOfTimelineForEffect"]);
}

#pragma mark Image parameter timing

- (void)testStartTimeOfImageParameterForwardsTheParameterID
{
	CMTime startTime = FxTimingTestMakeTime(0);

	[self.api startTime:&startTime ofImageParameter:kTimingTestParameter];

	XCTAssertTrue(FxTimingTestTimesEqual(startTime, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.parameterIDs[@"startTimeOfImageParameter"],
						  @(kTimingTestParameter));
}

- (void)testDurationTimeOfImageParameterForwardsTheParameterID
{
	CMTime duration = FxTimingTestMakeTime(0);

	[self.api durationTime:&duration ofImageParameter:kTimingTestParameter];

	XCTAssertTrue(FxTimingTestTimesEqual(duration, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.parameterIDs[@"durationTimeOfImageParameter"],
						  @(kTimingTestParameter));
}

#pragma mark Time conversion

- (void)testTimelineTimeFromInputTimeForwardsTheSourceTime
{
	CMTime timelineTime = FxTimingTestMakeTime(0);

	[self.api timelineTime:&timelineTime fromInputTime:FxTimingTestMakeTime(300)];

	XCTAssertTrue(FxTimingTestTimesEqual(timelineTime, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.inputValues[@"timelineTimeFromInputTime"], @300);
}

- (void)testTimelineTimeFromImageTimeForwardsTheSourceTimeAndTheParameterID
{
	CMTime timelineTime = FxTimingTestMakeTime(0);

	[self.api timelineTime:&timelineTime
			 fromImageTime:FxTimingTestMakeTime(450)
			forParameterID:kTimingTestParameter];

	XCTAssertTrue(FxTimingTestTimesEqual(timelineTime, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.inputValues[@"timelineTimeFromImageTime"], @450);
	XCTAssertEqualObjects(self.hostAPI.parameterIDs[@"timelineTimeFromImageTime"],
						  @(kTimingTestParameter));
}

- (void)testInputTimeFromTimelineTimeForwardsTheSourceTime
{
	CMTime inputTime = FxTimingTestMakeTime(0);

	[self.api inputTime:&inputTime fromTimelineTime:FxTimingTestMakeTime(120)];

	XCTAssertTrue(FxTimingTestTimesEqual(inputTime, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.inputValues[@"inputTimeFromTimelineTime"], @120);
}

- (void)testImageTimeFromTimelineTimeForwardsTheSourceTimeAndTheParameterID
{
	CMTime imageTime = FxTimingTestMakeTime(0);

	[self.api imageTime:&imageTime
		 forParameterID:kTimingTestParameter
	   fromTimelineTime:FxTimingTestMakeTime(240)];

	XCTAssertTrue(FxTimingTestTimesEqual(imageTime, self.firstAnswer));
	XCTAssertEqualObjects(self.hostAPI.inputValues[@"imageTimeFromTimelineTime"], @240);
	XCTAssertEqualObjects(self.hostAPI.parameterIDs[@"imageTimeFromTimelineTime"],
						  @(kTimingTestParameter));
}

#pragma mark NULL out-parameters

- (void)testANullOutParameterSuppressesEveryHostQuery
{
	[self.api frameDuration:NULL];
	[self.api sampleDuration:NULL];
	[self.api startTimeForEffect:NULL];
	[self.api durationTimeForEffect:NULL];
	[self.api startTimeOfInputToFilter:NULL];
	[self.api durationTimeOfInputToFilter:NULL];
	[self.api startTime:NULL ofImageParameter:kTimingTestParameter];
	[self.api durationTime:NULL ofImageParameter:kTimingTestParameter];
	[self.api inPointTimeOfTimelineForEffect:NULL];
	[self.api outPointTimeOfTimelineForEffect:NULL];
	[self.api timelineTime:NULL fromInputTime:FxTimingTestMakeTime(1)];
	[self.api timelineTime:NULL fromImageTime:FxTimingTestMakeTime(1) forParameterID:kTimingTestParameter];
	[self.api inputTime:NULL fromTimelineTime:FxTimingTestMakeTime(1)];
	[self.api imageTime:NULL forParameterID:kTimingTestParameter fromTimelineTime:FxTimingTestMakeTime(1)];

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

#pragma mark Scalar queries

- (void)testFieldOrderReportsTheHostValueForTheGivenFilter
{
	self.hostAPI.fieldOrder = kFxFieldOrder_LOWER_FIRST;

	XCTAssertEqual([self.api fieldOrderForInputToFilter:(id)self.effect],
				   (FxFieldOrder)kFxFieldOrder_LOWER_FIRST);
	XCTAssertTrue(self.hostAPI.lastFilter == (id)self.effect);
}

- (void)testTimelineFpsNumeratorReportsTheHostValue
{
	self.hostAPI.fpsNumerator = 30000;

	XCTAssertEqual([self.api timelineFpsNumeratorForEffect:(id)self.effect], (NSUInteger)30000);
}

- (void)testTimelineFpsDenominatorReportsTheHostValue
{
	self.hostAPI.fpsDenominator = 1001;

	XCTAssertEqual([self.api timelineFpsDenominatorForEffect:(id)self.effect], (NSUInteger)1001);
}

@end
