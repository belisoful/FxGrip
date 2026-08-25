//
//  FxGripStructuredParameterTests.m
//  FxGripTests
//
//  Unit tests for the parameter classes whose creation carries no default and whose value
//  is a structured record: FxGripGradientParameter, FxGripHistogramParameter,
//  FxGripImageRefParameter, FxGripPathParameter, and FxGripCustomParameter. Coverage spans
//  the type identity, the name-ID-flags payload each hands the creation API, the value
//  reads, the image-parameter timing queries, and the custom parameter's data classes.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripGradientParameter.h>
#import <FxGrip/FxGripHistogramParameter.h>
#import <FxGrip/FxGripImageRefParameter.h>
#import <FxGrip/FxGripPathParameter.h>
#import <FxGrip/FxGripCustomParameter.h>

// Implemented as the subclass hook but absent from the public header.
@interface FxGripCustomParameter (FxGripStructuredParameterTests)
- (void)initializeCustomData:(NSObject<NSSecureCoding, NSCopying> *_Nullable *_Nonnull)customDefaultValue
				 parameterID:(FxParameterId)parameterID;
@end

static const FxParameterId kStructuredTestParameter = 51;

@interface FxGripStructuredParameterTests : XCTestCase
@property (nonatomic, strong) FxParamClassTestEffect *effect;
@end

@implementation FxGripStructuredParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxParamClassTestEffect.alloc init];
}

- (void)tearDown
{
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSDictionary *)call
{
	return self.effect.creationCall;
}

- (BOOL)add:(Class)parameterClass type:(NSString *)type extra:(NSDictionary *)extra
{
	NSDictionary *config = FxParamClassTestConfig(kStructuredTestParameter, type, @"Levels", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (id)makeParameter:(Class)parameterClass type:(NSString *)type
{
	NSDictionary *config = FxParamClassTestConfig(kStructuredTestParameter, type, @"Levels", nil);
	return [[parameterClass alloc] initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

- (void)testEachStructuredClassReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripGradientParameter.parameterType, FxParameterType_Gradient);
	XCTAssertEqualObjects(FxGripGradientParameter.parameterTypeString, kFxParameterType_Gradient);

	XCTAssertEqual(FxGripHistogramParameter.parameterType, FxParameterType_Histogram);
	XCTAssertEqualObjects(FxGripHistogramParameter.parameterTypeString, kFxParameterType_Histogram);

	XCTAssertEqual(FxGripImageRefParameter.parameterType, FxParameterType_ImageRef);
	XCTAssertEqualObjects(FxGripImageRefParameter.parameterTypeString, kFxParameterType_ImageRef);

	XCTAssertEqual(FxGripPathParameter.parameterType, FxParameterType_PathID);
	XCTAssertEqualObjects(FxGripPathParameter.parameterTypeString, kFxParameterType_PathID);

	XCTAssertEqual(FxGripCustomParameter.parameterType, FxParameterType_Custom);
	XCTAssertEqualObjects(FxGripCustomParameter.parameterTypeString, kFxParameterType_Custom);
}

#pragma mark Creation payloads

- (void)testGradientForwardsOnlyTheNameIDAndFlags
{
	XCTAssertTrue([self add:FxGripGradientParameter.class type:kFxParameterType_Gradient extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"gradient",
										@"name": @"Levels",
										@"id": @(kStructuredTestParameter),
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testHistogramForwardsOnlyTheNameIDAndFlags
{
	XCTAssertTrue([self add:FxGripHistogramParameter.class type:kFxParameterType_Histogram extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"histogram",
										@"name": @"Levels",
										@"id": @(kStructuredTestParameter),
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testImageReferenceForwardsOnlyTheNameIDAndFlags
{
	XCTAssertTrue([self add:FxGripImageRefParameter.class type:kFxParameterType_ImageRef extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"imageref",
										@"name": @"Levels",
										@"id": @(kStructuredTestParameter),
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testPathPickerForwardsOnlyTheNameIDAndFlags
{
	XCTAssertTrue([self add:FxGripPathParameter.class type:kFxParameterType_PathID extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"path",
										@"name": @"Levels",
										@"id": @(kStructuredTestParameter),
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testCustomSendsAFreshEmptyDictionaryAsItsDefault
{
	XCTAssertTrue([self add:FxGripCustomParameter.class type:kFxParameterType_Custom extra:nil]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"default"], NSMutableDictionary.new);
	XCTAssertTrue([self.call[@"default"] isKindOfClass:NSMutableDictionary.class]);
}

/*! The custom creation ignores any declared default, so the host always sees the empty record. */
- (void)testCustomIgnoresADeclaredDefault
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @{@"seed": @7}};

	XCTAssertTrue([self add:FxGripCustomParameter.class type:kFxParameterType_Custom extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], NSMutableDictionary.new);
}

- (void)testEveryStructuredClassCarriesTheConfiguredFlags
{
	NSArray *declared = @[kParameterFlagString_HIDDEN];
	NSDictionary *extra = @{kFxParameterProperty_Flags: declared};

	XCTAssertTrue([self add:FxGripGradientParameter.class type:kFxParameterType_Gradient extra:extra]);

	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_HIDDEN));
}

- (void)testEveryStructuredClassReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripGradientParameter.class type:kFxParameterType_Gradient extra:nil]);
	XCTAssertFalse([self add:FxGripHistogramParameter.class type:kFxParameterType_Histogram extra:nil]);
	XCTAssertFalse([self add:FxGripImageRefParameter.class type:kFxParameterType_ImageRef extra:nil]);
	XCTAssertFalse([self add:FxGripPathParameter.class type:kFxParameterType_PathID extra:nil]);
	XCTAssertFalse([self add:FxGripCustomParameter.class type:kFxParameterType_Custom extra:nil]);
	XCTAssertEqual(self.effect.creationCalls.count, (NSUInteger)5);
}

#pragma mark Gradient values

- (FxGripGradientParameter *)makeGradientParameter
{
	return [self makeParameter:FxGripGradientParameter.class type:kFxParameterType_Gradient];
}

- (void)testGradientValueAtTimeAsksForTheConfiguredSampleCountAndDepth
{
	FxGripGradientParameter *parameter = [self makeGradientParameter];
	parameter.samples = 8;
	parameter.byteDepth = 4;
	parameter.fxDepth = kFxDepth_FLOAT32;

	FxGripGradient *gradient = [parameter valueAtTime:FxParamClassTestTime(2, 30)];

	XCTAssertTrue(gradient != NULL);
	XCTAssertEqual(gradient->count, (NSUInteger)8);
	XCTAssertEqual(gradient->depth, kFxDepth_FLOAT32);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"gradient");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"samples"], @8);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"depth"], @(kFxDepth_FLOAT32));
}

- (void)testGradientValueAtTimeIsNullWhenTheReadFails
{
	FxGripGradientParameter *parameter = [self makeGradientParameter];
	parameter.samples = 4;
	parameter.byteDepth = 4;
	parameter.fxDepth = kFxDepth_FLOAT32;
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	XCTAssertTrue([parameter valueAtTime:FxParamClassTestTime(0, 1)] == NULL);
}

- (void)testRepeatedGradientReadsReplaceTheBuffer
{
	FxGripGradientParameter *parameter = [self makeGradientParameter];
	parameter.samples = 4;
	parameter.byteDepth = 1;
	parameter.fxDepth = kFxDepth_UINT8;

	[parameter valueAtTime:FxParamClassTestTime(0, 1)];
	FxGripGradient *second = [parameter valueAtTime:FxParamClassTestTime(1, 30)];

	XCTAssertTrue(second != NULL);
	XCTAssertEqual(self.effect.apiManager.paramGetAPIv6.reads.count, (NSUInteger)2);
}

#pragma mark Histogram values

- (FxGripHistogramParameter *)makeHistogramParameter
{
	return [self makeParameter:FxGripHistogramParameter.class type:kFxParameterType_Histogram];
}

- (void)testHistogramValueAtTimeReadsEveryChannel
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	FxParamClassTestRetrievalAPI *retrieval = self.effect.apiManager.paramGetAPIv6;
	retrieval.blackIn = 0.05;
	retrieval.blackOut = 0.1;
	retrieval.whiteIn = 0.8;
	retrieval.whiteOut = 0.9;
	retrieval.gamma = 1.5;

	FxGripHistogram *histogram = [parameter valueAtTime:FxParamClassTestTime(11, 30)];

	XCTAssertTrue(histogram != NULL);
	XCTAssertEqual(retrieval.reads.count, (NSUInteger)5);
	for (int channel = 0; channel < 5; channel++) {
		XCTAssertEqual(histogram->component[channel].blackIn, 0.05);
		XCTAssertEqual(histogram->component[channel].whiteOut, 0.9);
		XCTAssertEqual(histogram->component[channel].gamma, 1.5);
		XCTAssertEqual(histogram->component[channel].channel, channel);
		XCTAssertEqualObjects(retrieval.reads[channel][@"channel"], @(channel));
	}
}

- (void)testAChannelTheHostRefusesKeepsItsZeroHistogramValues
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	FxParamClassTestRetrievalAPI *retrieval = self.effect.apiManager.paramGetAPIv6;
	retrieval.blackIn = 0.05;
	retrieval.gamma = 1.5;
	[retrieval.refusedHistogramChannels addObject:@2];

	FxGripHistogram *histogram = [parameter valueAtTime:FxParamClassTestTime(0, 1)];

	XCTAssertEqual(histogram->component[1].blackIn, 0.05);
	XCTAssertEqual(histogram->component[2].blackIn, 0.0);
	XCTAssertEqual(histogram->component[2].gamma, 1.0, @"the zero histogram leaves gamma at one");
}

#pragma mark Image reference

- (FxGripImageRefParameter *)makeImageRefParameter
{
	return [self makeParameter:FxGripImageRefParameter.class type:kFxParameterType_ImageRef];
}

- (void)testAnImageReferenceAlwaysIncludesFilters
{
	XCTAssertTrue([self makeImageRefParameter].includeFilters);
}

- (void)testImageReferenceStartTimeComesFromTheTimingAPI
{
	FxGripImageRefParameter *parameter = [self makeImageRefParameter];
	self.effect.apiManager.timingAPIv4.startTime = FxParamClassTestTime(15, 30);

	CMTime start = parameter.startTime;

	XCTAssertEqual(start.value, (int64_t)15);
	XCTAssertEqual(start.timescale, (int32_t)30);
	XCTAssertEqualObjects(self.effect.apiManager.timingAPIv4.queries.lastObject,
						  (@{@"accessor": @"start", @"id": @(kStructuredTestParameter)}));
}

- (void)testImageReferenceDurationComesFromTheTimingAPI
{
	FxGripImageRefParameter *parameter = [self makeImageRefParameter];
	self.effect.apiManager.timingAPIv4.durationTime = FxParamClassTestTime(90, 30);

	CMTime duration = parameter.durationTime;

	XCTAssertEqual(duration.value, (int64_t)90);
	XCTAssertEqualObjects(self.effect.apiManager.timingAPIv4.queries.lastObject[@"accessor"], @"duration");
}

#pragma mark Path

- (void)testPathValueAtTimeReadsThePathIDForItsParameter
{
	FxGripPathParameter *parameter = [self makeParameter:FxGripPathParameter.class type:kFxParameterType_PathID];

	[parameter valueAtTime:FxParamClassTestTime(8, 30)];

	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"path");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"id"], @(kStructuredTestParameter));
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @8);
}

#pragma mark Custom values

- (FxGripCustomParameter *)makeCustomParameter
{
	return [self makeParameter:FxGripCustomParameter.class type:kFxParameterType_Custom];
}

- (void)testTheCustomParameterAdvertisesTheCodableDataClassesItAccepts
{
	NSSet<Class> *classes = [self makeCustomParameter].dataClasses;

	XCTAssertTrue([classes containsObject:NSMutableDictionary.class]);
	XCTAssertTrue([classes containsObject:NSString.class]);
	XCTAssertTrue([classes containsObject:NSNumber.class]);
	XCTAssertTrue([classes containsObject:NSUUID.class]);
	XCTAssertTrue([classes containsObject:NSClassFromString(@"FxGripInterpolatingDictionary")]);
	XCTAssertFalse([classes containsObject:XCTestCase.class]);
}

- (void)testCustomValueAtTimeReturnsWhatTheRetrievalAPIProvides
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];
	NSDictionary *stored = @{@"seed": @7};
	self.effect.apiManager.paramGetAPIv6.customValue = stored;

	XCTAssertEqualObjects([parameter valueAtTime:FxParamClassTestTime(3, 30)], stored);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"custom");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @3);
}

- (void)testTheCustomValueAccessorReadsAtTheZeroTime
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];
	self.effect.apiManager.paramGetAPIv6.customValue = @"stored";

	XCTAssertEqualObjects(parameter.value, @"stored");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @0);
}

- (void)testCustomValueAtTimeIsNilWhenTheReadFails
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];
	self.effect.apiManager.paramGetAPIv6.customValue = @"stored";
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	XCTAssertNil([parameter valueAtTime:FxParamClassTestTime(0, 1)]);
}

- (void)testSettingTheCustomValueWritesThroughTheVersionSixSettingAPI
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];

	[parameter setValue:@"stored" atTime:FxParamClassTestTime(5, 30)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv6.lastWrite,
						  (@{@"accessor": @"custom",
							 @"id": @(kStructuredTestParameter),
							 @"value": @"stored",
							 @"timevalue": @5}));
}

- (void)testTheCustomValueSetterWritesAtTheZeroTime
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];

	parameter.value = @"stored";

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv6.lastWrite[@"timevalue"], @0);
}

- (void)testTheCustomDataInitializationHookLeavesTheValueUntouched
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];
	NSObject<NSSecureCoding, NSCopying> *value = nil;

	[parameter initializeCustomData:&value parameterID:kStructuredTestParameter];

	XCTAssertNil(value, @"the base hook is the subclass extension point and stages nothing");
}

@end
