/*!
	@file       FxGripAnalyzerParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripAnalyzerParameterTests
	@abstract   Tests FxGripAnalyzerParameter creation and its click action.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the analyzer button's FxPlug type identity, the push button it registers, the button title precedence, the click-selector prefix validation, and the safe no-op action when the host lacks an analysis pass.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripAnalyzerParameter.h>
#import <FxGrip/FxGripParameterUtility.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Analyze.h>
#import <FxGrip/FxGripAnalysis.h>

static const FxParameterId kAnalyzerTestParameter = 61;

#pragma mark - Host doubles

/*! Stands in for the host's FxAnalysisAPI_v2, recording the direction and location asked for. */
@interface FxGripAnalyzerTestAnalysisAPI : NSObject
@property (nonatomic, assign) BOOL succeeds;
@property (nonatomic, assign) BOOL failsWithError;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *starts;
@end

@implementation FxGripAnalyzerTestAnalysisAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_starts = NSMutableArray.new;
	}
	return self;
}

- (BOOL)record:(NSString *)direction location:(FxAnalysisLocation)location error:(NSError **)error
{
	[self.starts addObject:@{@"direction": direction, @"location": @(location)}];
	if (!self.succeeds && self.failsWithError && error != NULL) {
		*error = [NSError errorWithDomain:@"FxGripAnalyzerTest" code:7 userInfo:nil];
	}
	return self.succeeds;
}

- (BOOL)startForwardAnalysis:(FxAnalysisLocation)location error:(NSError **)error
{
	return [self record:@"forward" location:location error:error];
}

- (BOOL)startBackwardAnalysis:(FxAnalysisLocation)location error:(NSError **)error
{
	return [self record:@"backward" location:location error:error];
}

@end

/*! Carries the analysis API the effect base's analysis category reaches for. */
@interface FxGripAnalyzerTestAPIManager : FxGripParamClassTestAPIManager
@property (nonatomic, strong, nullable) FxGripAnalyzerTestAnalysisAPI *analysisAPIv2;
@end

@implementation FxGripAnalyzerTestAPIManager
@end

/*! A real effect that conforms to FxAnalyzer, so the base reports an analysis pass. */
@interface FxGripAnalyzerTestEffect : FxGripTileableEffect <FxAnalyzer>
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong) FxGripAnalyzerTestAPIManager *stubAPIManager;
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"
@implementation FxGripAnalyzerTestEffect

- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		_privateNotifier = [[NSClassFromString(@"NSPriorityNotificationCenter") alloc] init];
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

- (id<FxGripAPIAccessing>)apiManager
{
	return (id<FxGripAPIAccessing>)_stubAPIManager;
}

- (id)effectBase
{
	return self;
}

- (id<NSSecureCoding, NSCopying>)analyzeImageTile:(FxImageTile *)frame
										  atTime:(CMTime)frameTime
									  frameIndex:(NSInteger)frameIndex
										   error:(NSError * _Nullable * _Nullable)error
{
	return @(frameIndex);
}

@end
#pragma clang diagnostic pop

@interface FxGripAnalyzerParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripAnalyzerParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamClassTestEffect.alloc init];
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

- (BOOL)add:(Class)parameterClass type:(NSString *)type declaredSelector:(NSString *)declaredSelector
{
	NSDictionary *extra = declaredSelector ? @{kFxParameterProperty_Selector: declaredSelector} : nil;
	NSDictionary *config = FxGripParamClassTestConfig(kAnalyzerTestParameter, type, @"Reset", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (NSString *)synthesizedSelectorName
{
	return [FxGripParameterUtility clickSelectorNameForParameter:kAnalyzerTestParameter];
}


/*! A real effect that reports an analysis pass, carrying the recording analysis API. */
- (FxGripAnalyzerTestEffect *)makeAnalyzerEffect
{
	FxGripAnalyzerTestEffect *effect = [FxGripAnalyzerTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	effect.stubAPIManager = [FxGripAnalyzerTestAPIManager.alloc init];
	effect.stubAPIManager.analysisAPIv2 = [FxGripAnalyzerTestAnalysisAPI.alloc init];
	effect.stubAPIManager.analysisAPIv2.succeeds = YES;
	XCTAssertTrue(effect.hasAnalysis, @"the FxAnalyzer conformance loads the analysis extension");
	return effect;
}

- (FxGripAnalyzerParameter *)analyzerWithExtra:(nullable NSDictionary *)extra
									  onEffect:(FxGripAnalyzerTestEffect *)effect
{
	NSDictionary *config = FxGripParamClassTestConfig(kAnalyzerTestParameter, kFxParameterType_Analyzer,
													  @"Analyze", extra);
	return [FxGripAnalyzerParameter.alloc initWithDictionary:config effect:(id)effect];
}

#pragma mark Type identity

/*! @abstract The analyzer button reports FxParameterType_Analyzer and the matching type string. */
- (void)testTheAnalyzerButtonReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripAnalyzerParameter.parameterType, FxParameterType_Analyzer);
	XCTAssertEqualObjects(FxGripAnalyzerParameter.parameterTypeString, kFxParameterType_Analyzer);
}

#pragma mark Creation

/*! @abstract Creation registers a push button whose title is the parameter name and whose selector is the synthesized click selector. */
- (void)testTheAnalyzerButtonRegistersAPushButtonUsingItsParameterNameAsTheTitle
{
	XCTAssertTrue([self add:FxGripAnalyzerParameter.class type:kFxParameterType_Analyzer declaredSelector:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"button",
										@"name": @"Reset",
										@"id": @(kAnalyzerTestParameter),
										@"selector": self.synthesizedSelectorName,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract A configured button title overrides the parameter name for the registered button. */
- (void)testTheAnalyzerButtonPrefersTheConfiguredButtonTitle
{
	NSDictionary *config = FxGripParamClassTestConfig(kAnalyzerTestParameter, kFxParameterType_Analyzer, @"Reset",
													  @{kFxParameterProperty_ButtonTitle: @"Detect Motion"});

	XCTAssertTrue([FxGripAnalyzerParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"name"], @"Detect Motion");
}

/*! @abstract With neither a name nor a button title, the button falls back to the default analyze title. */
- (void)testTheAnalyzerButtonFallsBackToAnalyzeWhenNoNameOrTitleIsGiven
{
	NSDictionary *config = @{kFxParameterProperty_Id: @(kAnalyzerTestParameter),
							 kFxParameterProperty_Type: kFxParameterType_Analyzer};

	XCTAssertTrue([FxGripAnalyzerParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"name"], kFxGripAnalyzerDefaultTitle);
}

/*! @abstract A declared selector lacking the click prefix is rejected and registers no parameter. */
- (void)testTheAnalyzerButtonRefusesADeclaredSelectorWithoutTheClickPrefix
{
	XCTAssertFalse([self add:FxGripAnalyzerParameter.class type:kFxParameterType_Analyzer declaredSelector:@"runAnalysis"]);

	XCTAssertEqualObjects(self.effect.creationCalls, @[]);
}

/*! The click hook is a no-op when the host is not an FxGrip effect that conforms to
	FxAnalyzer, so a misconfigured analyzer button never throws. */
- (void)testTheAnalyzerActionIsSafeOnAHostWithoutAnAnalysisPass
{
	NSDictionary *config = FxGripParamClassTestConfig(kAnalyzerTestParameter, kFxParameterType_Analyzer, @"Analyze", nil);
	FxGripAnalyzerParameter *parameter = [FxGripAnalyzerParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertNoThrow([parameter defaultParameterAction]);
}


#pragma mark Analysis location

/*! @abstract The analyzer runs on the GPU by default and takes the CPU when the configuration asks for it. */
- (void)testTheDeclaredAnalysisLocationIsCarriedIntoTheAction
{
	FxGripAnalyzerTestEffect *effect = [self makeAnalyzerEffect];

	[[self analyzerWithExtra:nil onEffect:effect] defaultParameterAction];
	XCTAssertEqualObjects(effect.stubAPIManager.analysisAPIv2.starts.lastObject[@"location"],
						  @(kFxAnalysisLocation_GPU));

	[[self analyzerWithExtra:@{kFxGripAnalyzerKey_Location: @(kFxAnalysisLocation_CPU)} onEffect:effect]
	 defaultParameterAction];
	XCTAssertEqualObjects(effect.stubAPIManager.analysisAPIv2.starts.lastObject[@"location"],
						  @(kFxAnalysisLocation_CPU));
}

/*! @abstract A location entry that is not the CPU constant leaves the pass on the GPU. */
- (void)testAnUnknownDeclaredLocationStaysOnTheGPU
{
	FxGripAnalyzerTestEffect *effect = [self makeAnalyzerEffect];

	[[self analyzerWithExtra:@{kFxGripAnalyzerKey_Location: @"cpu"} onEffect:effect] defaultParameterAction];

	XCTAssertEqualObjects(effect.stubAPIManager.analysisAPIv2.starts.lastObject[@"location"],
						  @(kFxAnalysisLocation_GPU));
}

#pragma mark Analysis direction

/*! @abstract The click starts the forward pass, and the backward flag starts the reverse pass. */
- (void)testTheClickStartsThePassInTheDeclaredDirection
{
	FxGripAnalyzerTestEffect *effect = [self makeAnalyzerEffect];

	[[self analyzerWithExtra:nil onEffect:effect] defaultParameterAction];
	XCTAssertEqualObjects(effect.stubAPIManager.analysisAPIv2.starts.lastObject[@"direction"], @"forward");

	[[self analyzerWithExtra:@{kFxGripAnalyzerKey_Backward: @YES} onEffect:effect] defaultParameterAction];
	XCTAssertEqualObjects(effect.stubAPIManager.analysisAPIv2.starts.lastObject[@"direction"], @"backward");
}

/*! @abstract A host that refuses to start the pass leaves the click without effect and does not throw. */
- (void)testAHostRefusalToStartThePassIsSurvived
{
	FxGripAnalyzerTestEffect *effect = [self makeAnalyzerEffect];
	effect.stubAPIManager.analysisAPIv2.succeeds = NO;
	effect.stubAPIManager.analysisAPIv2.failsWithError = YES;

	XCTAssertNoThrow([[self analyzerWithExtra:nil onEffect:effect] defaultParameterAction]);

	XCTAssertEqual(effect.stubAPIManager.analysisAPIv2.starts.count, 1u);
}

/*! @abstract An effect that reports no analysis pass starts nothing. */
- (void)testAnEffectWithoutAnAnalysisPassStartsNothing
{
	FxGripAnalyzerTestEffect *effect = [self makeAnalyzerEffect];
	effect.stubAPIManager.analysisAPIv2 = nil;

	XCTAssertNoThrow([[self analyzerWithExtra:nil onEffect:effect] defaultParameterAction]);
}

@end
