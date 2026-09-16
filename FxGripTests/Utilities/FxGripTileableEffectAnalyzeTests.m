/*!
	@file       FxGripTileableEffectAnalyzeTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripTileableEffectAnalyzeTests
	@abstract   Verifies the frame-analysis pass, its per-frame storage, and the tile averages.
	@discussion Introduced in FxGrip 0.1.0. The tests drive the FxAnalyzer callbacks the host calls
	            on an effect that declares the protocol: the setup that stores the frame duration,
	            the per-frame hook whose record lands at the frame's index, and the cleanup that
	            persists the data. IOSurface-backed tiles with known pixel content exercise the
	            Core Image area average and the Rec. 709 luminance, and an object-tracker parameter
	            exercises the tracker legs of the pass.
*/

#import <XCTest/XCTest.h>
#import <CoreVideo/CoreVideo.h>
#import "FxPlugStub.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Analyze.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <FxGrip/FxGripAnalysis.h>
#import <FxGrip/FxGripFrameData.h>
#import <FxGrip/FxTileImage+FxGrip.h>
#import "FxGripParameterClassTestSupport.h"

/*! The FxAnalyzer callbacks the Analyze category implements on the base but declares nowhere. */
@interface FxGripTileableEffect (FxGripTileableEffectAnalyzeTests)
- (BOOL)desiredAnalysisTimeRange:(CMTimeRange *)desiredRange
		   forInputWithTimeRange:(CMTimeRange)inputTimeRange
						   error:(NSError * _Nullable * _Nullable)error;
- (BOOL)setupAnalysisForTimeRange:(CMTimeRange)analysisRange
					frameDuration:(CMTime)frameDuration
							error:(NSError * _Nullable * _Nullable)error;
- (BOOL)analyzeFrame:(FxImageTile *)frame atTime:(CMTime)frameTime error:(NSError * _Nullable * _Nullable)error;
- (BOOL)cleanupAnalysis:(NSError * _Nullable * _Nullable)error;
@end

static const FxParameterId kAnalyzeTestFloat = 21;
static const FxParameterId kAnalyzeTestTracker = 22;

static CMTime FxGripAnalyzeTestTime(int64_t value, int32_t timescale)
{
	return (CMTime){ .value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0 };
}

#pragma mark - Effect doubles

/*! Confines notification traffic to a private center; it declares no FxAnalyzer conformance. */
@interface FxGripAnalyzeTestPlainEffect : FxGripTileableEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@end

@implementation FxGripAnalyzeTestPlainEffect

- (id)effectBase
{
	return self;
}

- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		_privateNotifier = (NSNotificationCenter *)FxGripParamClassTestMakePriorityCenter();
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

@end

/*!
	Declares FxAnalyzer, so the extension loader installs the analysis storage. The compute
	hook boxes the frame index, and a staged flag makes it return nothing.
*/
@interface FxGripAnalyzeTestEffect : FxGripAnalyzeTestPlainEffect <FxAnalyzer>
@property (nonatomic, assign) BOOL computesNoRecord;
@property (nonatomic, assign) NSInteger lastAnalyzedFrame;
@property (nonatomic, strong, nullable) FxImageTile *lastAnalyzedTile;
@end

// The host-called FxAnalyzer methods live on the real base's Analyze category.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"
@implementation FxGripAnalyzeTestEffect

- (id<NSSecureCoding, NSCopying>)analyzeImageTile:(FxImageTile *)frame
										   atTime:(CMTime)frameTime
									   frameIndex:(NSInteger)frameIndex
											error:(NSError * _Nullable * _Nullable)error
{
	self.lastAnalyzedFrame = frameIndex;
	self.lastAnalyzedTile = frame;
	return self.computesNoRecord ? nil : @(frameIndex);
}

@end
#pragma clang diagnostic pop

#pragma mark - Tests

@interface FxGripTileableEffectAnalyzeTests : XCTestCase
@property (nonatomic, strong) id effect;
@property (nonatomic, strong) id<MTLDevice> device;
@end

@implementation FxGripTileableEffectAnalyzeTests

- (void)setUp
{
	[super setUp];
	self.device = MTLCreateSystemDefaultDevice();
}

- (void)tearDown
{
	self.effect = nil;
	[super tearDown];
}

- (FxGripAnalyzeTestEffect *)makeAnalysisEffect
{
	FxGripAnalyzeTestEffect *effect = [FxGripAnalyzeTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);
	self.effect = effect;
	return effect;
}

- (FxGripAnalyzeTestPlainEffect *)makePlainEffect
{
	FxGripAnalyzeTestPlainEffect *effect = [FxGripAnalyzeTestPlainEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);
	self.effect = effect;
	return effect;
}

/*! A 32BGRA tile whose every pixel carries one color, written through its Metal texture. */
- (FxImageTile *)tileFilledWithBlue:(uint8_t)blue green:(uint8_t)green red:(uint8_t)red alpha:(uint8_t)alpha
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
												 pixelFormat:kCVPixelFormatType_32BGRA
													  device:self.device];
	id<MTLTexture> texture = tile.metalTexture;
	XCTAssertNotNil(texture);
	NSUInteger rowBytes = texture.width * 4;
	NSMutableData *bytes = [NSMutableData dataWithLength:rowBytes * texture.height];
	uint8_t *pixel = bytes.mutableBytes;
	for (NSUInteger index = 0; index < texture.width * texture.height; index++, pixel += 4) {
		pixel[0] = blue;
		pixel[1] = green;
		pixel[2] = red;
		pixel[3] = alpha;
	}
	[texture replaceRegion:MTLRegionMake2D(0, 0, texture.width, texture.height)
			   mipmapLevel:0
				 withBytes:bytes.bytes
			   bytesPerRow:rowBytes];
	return tile;
}

#pragma mark Analysis lifecycle

/*! @abstract The setup stores the frame duration, so a time maps to the matching frame index. */
- (void)testSetupStoresTheFrameDurationForFrameIndexing
{
	FxGripAnalyzeTestEffect *effect = [self makeAnalysisEffect];
	CMTimeRange range = { .start = FxGripAnalyzeTestTime(0, 1), .duration = FxGripAnalyzeTestTime(60, 30) };
	NSError *error = nil;

	XCTAssertTrue([effect setupAnalysisForTimeRange:range frameDuration:FxGripAnalyzeTestTime(1, 30) error:&error]);

	XCTAssertNotNil([effect.analysisData objectForKey:kFxGripFrameDataKey_FrameDuration]);
	XCTAssertEqual([effect analysisFrameIndexForTime:FxGripAnalyzeTestTime(45, 30)], (NSInteger)45);
}

/*! @abstract An effect with no analysis storage still accepts the setup call. */
- (void)testSetupSucceedsWithoutAnalysisStorage
{
	FxGripAnalyzeTestPlainEffect *effect = [self makePlainEffect];
	CMTimeRange range = { .start = FxGripAnalyzeTestTime(0, 1), .duration = FxGripAnalyzeTestTime(60, 30) };
	NSError *error = nil;

	XCTAssertNil(effect.analysisData);
	XCTAssertTrue([effect setupAnalysisForTimeRange:range frameDuration:FxGripAnalyzeTestTime(1, 30) error:&error]);
}

/*! @abstract The frame index is zero before the setup stores a duration, and for a zero duration. */
- (void)testTheFrameIndexIsZeroWithoutAUsableFrameDuration
{
	FxGripAnalyzeTestEffect *effect = [self makeAnalysisEffect];

	XCTAssertEqual([effect analysisFrameIndexForTime:FxGripAnalyzeTestTime(45, 30)], (NSInteger)0);

	CMTimeRange range = { .start = FxGripAnalyzeTestTime(0, 1), .duration = FxGripAnalyzeTestTime(60, 30) };
	[effect setupAnalysisForTimeRange:range frameDuration:FxGripAnalyzeTestTime(0, 30) error:NULL];

	XCTAssertEqual([effect analysisFrameIndexForTime:FxGripAnalyzeTestTime(45, 30)], (NSInteger)0);
}

/*! @abstract The per-frame hook receives the tile and frame index, and its record is stored at that index. */
- (void)testTheFrameHookReceivesTheTileAndItsRecordIsStored
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxGripAnalyzeTestEffect *effect = [self makeAnalysisEffect];
	CMTimeRange range = { .start = FxGripAnalyzeTestTime(0, 1), .duration = FxGripAnalyzeTestTime(60, 30) };
	[effect setupAnalysisForTimeRange:range frameDuration:FxGripAnalyzeTestTime(1, 30) error:NULL];
	FxImageTile *tile = [self tileFilledWithBlue:0 green:0 red:255 alpha:255];
	NSError *error = nil;

	XCTAssertTrue([effect analyzeFrame:tile atTime:FxGripAnalyzeTestTime(12, 30) error:&error]);

	XCTAssertEqual(effect.lastAnalyzedFrame, (NSInteger)12);
	XCTAssertEqualObjects(effect.lastAnalyzedTile, tile);
	XCTAssertEqualObjects([effect analysisRecordAtTime:FxGripAnalyzeTestTime(12, 30)], @12);
}

/*! @abstract A hook that computes nothing stores nothing for the frame. */
- (void)testAFrameHookThatComputesNothingStoresNothing
{
	FxGripAnalyzeTestEffect *effect = [self makeAnalysisEffect];
	effect.computesNoRecord = YES;
	CMTimeRange range = { .start = FxGripAnalyzeTestTime(0, 1), .duration = FxGripAnalyzeTestTime(60, 30) };
	[effect setupAnalysisForTimeRange:range frameDuration:FxGripAnalyzeTestTime(1, 30) error:NULL];

	XCTAssertTrue([effect analyzeFrame:(FxImageTile * _Nonnull)nil atTime:FxGripAnalyzeTestTime(3, 30) error:NULL]);

	XCTAssertNil([effect analysisRecordAtTime:FxGripAnalyzeTestTime(3, 30)]);
}

/*! @abstract The base hook stores nothing, so an effect that does not override it records no frames. */
- (void)testTheBaseFrameHookComputesNoRecord
{
	FxGripAnalyzeTestPlainEffect *effect = [self makePlainEffect];

	XCTAssertNil([effect analyzeImageTile:(FxImageTile * _Nonnull)nil
								   atTime:FxGripAnalyzeTestTime(0, 1)
							   frameIndex:0
									error:NULL]);
}

/*! @abstract The cleanup ends the pass and leaves the analyzed records readable. */
- (void)testCleanupEndsThePassAndKeepsTheRecords
{
	FxGripAnalyzeTestEffect *effect = [self makeAnalysisEffect];
	CMTimeRange range = { .start = FxGripAnalyzeTestTime(0, 1), .duration = FxGripAnalyzeTestTime(60, 30) };
	[effect setupAnalysisForTimeRange:range frameDuration:FxGripAnalyzeTestTime(1, 30) error:NULL];
	[effect analyzeFrame:(FxImageTile * _Nonnull)nil atTime:FxGripAnalyzeTestTime(6, 30) error:NULL];

	XCTAssertTrue([effect cleanupAnalysis:NULL]);

	XCTAssertEqualObjects([effect analysisRecordAtTime:FxGripAnalyzeTestTime(6, 30)], @6);
}

/*! @abstract An effect with no analysis extension persists nothing and does not throw. */
- (void)testSavingWithoutTheAnalysisExtensionDoesNothing
{
	FxGripAnalyzeTestPlainEffect *effect = [self makePlainEffect];

	XCTAssertNoThrow([effect saveAnalysisData]);
	XCTAssertTrue([effect cleanupAnalysis:NULL]);
}

#pragma mark Driving the pass

/*! @abstract Without the host's analysis API the effect reports it is not analyzing and refuses to start a pass. */
- (void)testTheAnalysisDriversReportNothingWithoutTheHostAPI
{
	FxGripAnalyzeTestEffect *effect = [self makeAnalysisEffect];
	NSError *error = nil;

	XCTAssertEqual(effect.analysisState, (FxAnalysisState)kFxAnalysisState_NotAnalyzing);
	XCTAssertFalse([effect startForwardAnalysisAtLocation:kFxAnalysisLocation_CPU error:&error]);
	XCTAssertFalse([effect startBackwardAnalysisAtLocation:kFxAnalysisLocation_CPU error:&error]);
}

#pragma mark Tile averages

/*! @abstract The area average of a uniformly red tile reports full red with no green or blue. */
- (void)testTheAreaAverageOfAUniformTileReportsItsColor
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [self tileFilledWithBlue:0 green:0 red:255 alpha:255];
	double red = -1.0, green = -1.0, blue = -1.0, alpha = -1.0;

	XCTAssertTrue([FxGripTileableEffect averageColorOfImageTile:tile red:&red green:&green blue:&blue alpha:&alpha]);

	XCTAssertGreaterThan(red, 0.9);
	XCTAssertLessThan(green, 0.1);
	XCTAssertLessThan(blue, 0.1);
	XCTAssertGreaterThan(alpha, 0.9);
}

/*! @abstract Every output channel pointer is optional. */
- (void)testTheAreaAverageAcceptsNoOutputPointers
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [self tileFilledWithBlue:255 green:255 red:255 alpha:255];

	XCTAssertTrue([FxGripTileableEffect averageColorOfImageTile:tile red:NULL green:NULL blue:NULL alpha:NULL]);
}

/*! @abstract A nil tile and a tile with no surface are both refused. */
- (void)testTheAreaAverageRefusesATileWithoutAReadableSurface
{
	double red = -1.0;

	XCTAssertFalse([FxGripTileableEffect averageColorOfImageTile:(FxImageTile * _Nonnull)nil
															 red:&red green:NULL blue:NULL alpha:NULL]);
	XCTAssertFalse([FxGripTileableEffect averageColorOfImageTile:[FxImageTile stubTileWithPixelBounds:((FxRect){ 0, 0, 8, 8 })]
															 red:&red green:NULL blue:NULL alpha:NULL]);
	XCTAssertEqual(red, -1.0, @"a refused average writes no channel");
}

/*! @abstract The luminance of a uniformly green tile is the Rec. 709 green weight. */
- (void)testTheLuminanceOfAUniformTileUsesTheRec709Weights
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *green = [self tileFilledWithBlue:0 green:255 red:0 alpha:255];
	FxImageTile *blue = [self tileFilledWithBlue:255 green:0 red:0 alpha:255];

	XCTAssertEqualWithAccuracy([FxGripTileableEffect averageLuminanceOfImageTile:green], 0.7152, 0.05);
	XCTAssertEqualWithAccuracy([FxGripTileableEffect averageLuminanceOfImageTile:blue], 0.0722, 0.05);
}

/*! @abstract A tile with no readable surface has no luminance. */
- (void)testTheLuminanceOfATileWithoutASurfaceIsZero
{
	XCTAssertEqual([FxGripTileableEffect averageLuminanceOfImageTile:(FxImageTile * _Nonnull)nil], 0.0);
}

#pragma mark Object trackers

/*! Registers an object-tracker parameter on the effect through the host's add notification. */
- (FxGripAnalyzeTestEffect *)makeEffectWithTracker
{
	FxGripAnalyzeTestEffect *effect = [self makeAnalysisEffect];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kAnalyzeTestTracker, kFxParameterType_ObjectTracker, @"Tracker", nil)];
	XCTAssertNotNil(effect.parameters[@(kAnalyzeTestTracker)], @"the tracker parameter must register");
	return effect;
}

/*! @abstract The pass drives the effect's object-tracker parameters over the analyzed frames. */
- (void)testThePassDrivesTheObjectTrackerParameters
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxGripAnalyzeTestEffect *effect = [self makeEffectWithTracker];
	CMTimeRange range = { .start = FxGripAnalyzeTestTime(0, 1), .duration = FxGripAnalyzeTestTime(60, 30) };
	FxImageTile *tile = [self tileFilledWithBlue:0 green:128 red:0 alpha:255];

	XCTAssertTrue([effect setupAnalysisForTimeRange:range frameDuration:FxGripAnalyzeTestTime(1, 30) error:NULL]);
	XCTAssertTrue([effect analyzeFrame:tile atTime:FxGripAnalyzeTestTime(0, 30) error:NULL]);
	XCTAssertTrue([effect cleanupAnalysis:NULL]);

	XCTAssertEqualObjects([effect analysisRecordAtTime:FxGripAnalyzeTestTime(0, 30)], @0);
}

/*! @abstract A frame with no readable surface leaves the object trackers untouched. */
- (void)testAFrameWithoutASurfaceLeavesTheTrackersUntouched
{
	FxGripAnalyzeTestEffect *effect = [self makeEffectWithTracker];
	CMTimeRange range = { .start = FxGripAnalyzeTestTime(0, 1), .duration = FxGripAnalyzeTestTime(60, 30) };
	[effect setupAnalysisForTimeRange:range frameDuration:FxGripAnalyzeTestTime(1, 30) error:NULL];

	XCTAssertTrue([effect analyzeFrame:[FxImageTile stubTileWithPixelBounds:((FxRect){ 0, 0, 8, 8 })]
								atTime:FxGripAnalyzeTestTime(1, 30)
								 error:NULL]);
}

/*! @abstract A tracker with no analyzed sample reports no transform, and a non-tracker parameter is refused outright. */
- (void)testTheTrackerTransformIsRefusedWithoutASample
{
	FxGripAnalyzeTestEffect *effect = [self makeEffectWithTracker];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kAnalyzeTestFloat, kFxParameterType_Float, @"Level", nil)];
	FxGripObjectTrackerTransform transform = { 0 };

	XCTAssertFalse([effect objectTrackerTransform:&transform
									 forParameter:kAnalyzeTestTracker
										   atTime:FxGripAnalyzeTestTime(0, 1)]);
	XCTAssertFalse([effect objectTrackerTransform:&transform
									 forParameter:kAnalyzeTestFloat
										   atTime:FxGripAnalyzeTestTime(0, 1)],
				   @"a parameter that is not an object tracker has no transform");
}

/*! @abstract The desired analysis range defaults to the full input range. */
- (void)testTheDesiredRangeDefaultsToTheFullInput
{
	FxGripAnalyzeTestEffect *effect = [self makeAnalysisEffect];
	CMTimeRange input = { .start = FxGripAnalyzeTestTime(10, 30), .duration = FxGripAnalyzeTestTime(50, 30) };
	CMTimeRange desired = { 0 };

	XCTAssertTrue([effect desiredAnalysisTimeRange:&desired forInputWithTimeRange:input error:NULL]);

	XCTAssertEqual(desired.start.value, (int64_t)10);
	XCTAssertEqual(desired.duration.value, (int64_t)50);
	XCTAssertTrue([effect desiredAnalysisTimeRange:NULL forInputWithTimeRange:input error:NULL]);
}

@end
