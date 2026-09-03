//
//  FxGripObjectTrackerAnalysisTests.m
//  FxGripTests
//
//  The analysis-pass driving on the Object Tracker parameter: a live parameter reads its
//  configuration, seeds from the placed region on the first frame, tracks a moving patch
//  across the following frames, and writes the accumulated samples back through the setting
//  API. This exercises the #3 wiring end to end without an FxPlug host, using the shared
//  parameter-class test harness.
//

#import <XCTest/XCTest.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <FxGrip/FxGripTypes.h>
#import "FxGripParameterClassTestSupport.h"

typedef struct {
	CGPoint location;
	CGFloat rotation;
	CGSize  size;
} FxGripObjectTrackerTransform;

@interface FxGripObjectTrackerSample : NSObject
@property (readonly, nonatomic) CGRect boundingBox;
@property (readonly, nonatomic) CGPoint center;
@end

@interface FxGripObjectTrackerData : NSObject
@property (nonatomic) BOOL enabled;
@property (nonatomic) NSInteger shape;
@property (nonatomic) NSInteger resolution;
@property (nonatomic) CGRect initialBox;
@property (nonatomic) NSInteger centerParameterID;
@property (copy, nonatomic) NSArray<NSNumber *> *anchorParameterIDs;
@property (nonatomic) NSInteger angleParameterID;
@property (readonly, nonatomic) NSUInteger sampleCount;
@property (readonly, nonatomic) NSArray<NSNumber *> *sampleFrameIndexes;
- (nullable FxGripObjectTrackerSample *)sampleAtFrame:(NSInteger)frameIndex;
- (BOOL)transform:(FxGripObjectTrackerTransform *)outTransform atFrame:(NSInteger)frameIndex;
@end

@interface FxGripObjectTrackerParameter : NSObject
- (instancetype)initWithDictionary:(NSDictionary *)dictionary effect:(id)effect;
- (void)beginObjectTrackingAnalysis;
- (void)beginObjectTrackingAnalysisWithFrameDuration:(CMTime)frameDuration;
- (void)analyzeObjectTrackingImage:(CIImage *)image atFrame:(NSInteger)frameIndex;
- (void)endObjectTrackingAnalysis;
@end


static const size_t kW = 480;
static const size_t kH = 270;
static const CGFloat kPatch = 72.0;
static const CGFloat kStartX = 60.0;
static const CGFloat kStepX = 24.0;
static const NSInteger kFrames = 9;
static const FxParameterId kTrackerID = 51;

@interface FxGripObjectTrackerAnalysisTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripObjectTrackerAnalysisTests

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

- (CIImage *)frameWithPatchX:(CGFloat)patchX patchY:(CGFloat)patchY
{
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, kW, kH, 8, 0, space, kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(space);
	CGContextSetRGBFillColor(ctx, 0.08, 0.08, 0.10, 1.0);
	CGContextFillRect(ctx, CGRectMake(0, 0, kW, kH));
	CGRect patch = CGRectMake(patchX, patchY, kPatch, kPatch);
	CGContextSetRGBFillColor(ctx, 0.95, 0.85, 0.10, 1.0);
	CGContextFillRect(ctx, patch);
	CGContextSetRGBFillColor(ctx, 0.10, 0.20, 0.90, 1.0);
	CGContextFillRect(ctx, CGRectInset(patch, kPatch * 0.28, kPatch * 0.28));
	CGContextSetRGBFillColor(ctx, 0.90, 0.10, 0.15, 1.0);
	CGContextMoveToPoint(ctx, patchX, patchY);
	CGContextAddLineToPoint(ctx, patchX + kPatch, patchY + kPatch);
	CGContextAddLineToPoint(ctx, patchX + kPatch, patchY);
	CGContextFillPath(ctx);
	CGImageRef cg = CGBitmapContextCreateImage(ctx);
	CIImage *image = [CIImage imageWithCGImage:cg];
	CGImageRelease(cg);
	CGContextRelease(ctx);
	return image;
}

- (FxGripObjectTrackerParameter *)makeParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kTrackerID, kFxParameterType_ObjectTracker, @"Tracker", nil);
	return [[NSClassFromString(@"FxGripObjectTrackerParameter") alloc] initWithDictionary:config effect:(id)self.effect];
}

- (FxGripObjectTrackerData *)stagedDataEnabled:(BOOL)enabled
{
	CGFloat patchY = (kH - kPatch) / 2.0;
	FxGripObjectTrackerData *data = [NSClassFromString(@"FxGripObjectTrackerData") new];
	data.enabled = enabled;
	data.initialBox = CGRectMake(kStartX / (CGFloat)kW, patchY / (CGFloat)kH,
								 kPatch / (CGFloat)kW, kPatch / (CGFloat)kH);
	// The parameter reads its current value at begin to pick up config and the placed region.
	self.effect.apiManager.paramGetAPIv6.succeeds = YES;
	self.effect.apiManager.paramGetAPIv6.customValue = data;
	return data;
}

- (void)driveParameter:(FxGripObjectTrackerParameter *)parameter
{
	CGFloat patchY = (kH - kPatch) / 2.0;
	[parameter beginObjectTrackingAnalysis];
	for (NSInteger frame = 0; frame < kFrames; frame++) {
		CIImage *image = [self frameWithPatchX:kStartX + frame * kStepX patchY:patchY];
		[parameter analyzeObjectTrackingImage:image atFrame:frame];
	}
	[parameter endObjectTrackingAnalysis];
}

- (void)testAnalysisSeedsTracksAndWritesSamplesBack
{
	[self stagedDataEnabled:YES];
	[self driveParameter:[self makeParameter]];

	NSDictionary *write = self.effect.apiManager.paramSetAPIv6.lastWrite;
	XCTAssertNotNil(write, @"end should write the accumulated value");
	XCTAssertEqualObjects(write[@"id"], @(kTrackerID));

	FxGripObjectTrackerData *result = write[@"value"];
	XCTAssertTrue([result isKindOfClass:NSClassFromString(@"FxGripObjectTrackerData")]);
	XCTAssertGreaterThanOrEqual(result.sampleCount, (NSUInteger)(kFrames - 1), @"a sample per tracked frame");

	// The seed sample at frame 0 is the placed region's center.
	FxGripObjectTrackerSample *seed = [result sampleAtFrame:0];
	XCTAssertNotNil(seed);
	CGFloat seedCenterX = (kStartX + kPatch / 2.0) / (CGFloat)kW;
	XCTAssertEqualWithAccuracy(seed.center.x, seedCenterX, 0.02);

	// The track follows the patch rightward.
	FxGripObjectTrackerTransform last = {0};
	XCTAssertTrue([result transform:&last atFrame:kFrames - 1]);
	XCTAssertGreaterThan(last.location.x, seedCenterX + 0.05,
		@"tracked x %.3f did not advance past the seed %.3f", last.location.x, seedCenterX);
}

- (void)testLinkedCenterPointIsBakedAcrossFrames
{
	FxGripObjectTrackerData *data = [self stagedDataEnabled:YES];
	data.centerParameterID = 61;
	data.anchorParameterIDs = @[@62];
	// The anchor's initial position, read back by the parameter at begin.
	self.effect.apiManager.paramGetAPIv6.x = 0.5;
	self.effect.apiManager.paramGetAPIv6.y = 0.5;

	FxGripObjectTrackerParameter *parameter = [self makeParameter];
	CGFloat patchY = (kH - kPatch) / 2.0;
	[parameter beginObjectTrackingAnalysisWithFrameDuration:CMTimeMake(1, 30)];
	for (NSInteger frame = 0; frame < kFrames; frame++) {
		[parameter analyzeObjectTrackingImage:[self frameWithPatchX:kStartX + frame * kStepX patchY:patchY] atFrame:frame];
	}
	[parameter endObjectTrackingAnalysis];

	NSArray<NSDictionary *> *writes = self.effect.apiManager.paramSetAPIv6.writes;
	NSPredicate *centerWrites = [NSPredicate predicateWithFormat:@"%K == %@", @"id", @61];
	NSArray<NSDictionary *> *centers = [writes filteredArrayUsingPredicate:centerWrites];
	XCTAssertGreaterThanOrEqual(centers.count, (NSUInteger)(kFrames - 1), @"one center keyframe per tracked frame");

	CGFloat seedCenterX = (kStartX + kPatch / 2.0) / (CGFloat)kW;
	XCTAssertGreaterThan([centers.lastObject[@"x"] doubleValue], seedCenterX + 0.05,
		@"the driven center followed the patch rightward");

	NSArray<NSDictionary *> *anchors = [writes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@", @"id", @62]];
	XCTAssertGreaterThan(anchors.count, (NSUInteger)0, @"the anchor point was driven too");
}

- (void)testQuadrilateralShapeDrivesTheLinkedAnglePoint
{
	FxGripObjectTrackerData *data = [self stagedDataEnabled:YES];
	data.shape = 1;   // Quadrilateral: the engine runs the rotation-capable tracker.
	data.angleParameterID = 71;

	FxGripObjectTrackerParameter *parameter = [self makeParameter];
	CGFloat patchY = (kH - kPatch) / 2.0;
	[parameter beginObjectTrackingAnalysisWithFrameDuration:CMTimeMake(1, 30)];
	for (NSInteger frame = 0; frame < kFrames; frame++) {
		[parameter analyzeObjectTrackingImage:[self frameWithPatchX:kStartX + frame * kStepX patchY:patchY] atFrame:frame];
	}
	[parameter endObjectTrackingAnalysis];

	NSArray<NSDictionary *> *writes = self.effect.apiManager.paramSetAPIv6.writes;
	NSMutableArray<NSDictionary *> *angleWrites = [NSMutableArray array];
	for (NSDictionary *write in writes) {
		if ([write[@"accessor"] isEqual:@"float"] && [write[@"id"] isEqual:@71]) {
			[angleWrites addObject:write];
		}
	}
	XCTAssertGreaterThan(angleWrites.count, (NSUInteger)0, @"the angle parameter was driven in degrees");
	XCTAssertFalse(isnan([angleWrites.firstObject[@"value"] doubleValue]), @"angle value is finite");
}

- (void)testHalfResolutionStillTracksTheMovingPatch
{
	FxGripObjectTrackerData *data = [self stagedDataEnabled:YES];
	data.resolution = 1;   // Half: the frame is downscaled before Vision.
	[self driveParameter:[self makeParameter]];

	FxGripObjectTrackerData *result = self.effect.apiManager.paramSetAPIv6.lastWrite[@"value"];
	XCTAssertGreaterThanOrEqual(result.sampleCount, (NSUInteger)(kFrames - 1), @"half-res still records samples");

	FxGripObjectTrackerTransform last = {0};
	XCTAssertTrue([result transform:&last atFrame:kFrames - 1]);
	CGFloat seedCenterX = (kStartX + kPatch / 2.0) / (CGFloat)kW;
	XCTAssertGreaterThan(last.location.x, seedCenterX + 0.05, @"half-res track followed the patch");
}

- (void)testDisabledTrackerRecordsNoSamples
{
	[self stagedDataEnabled:NO];
	[self driveParameter:[self makeParameter]];

	FxGripObjectTrackerData *result = self.effect.apiManager.paramSetAPIv6.lastWrite[@"value"];
	XCTAssertNotNil(result);
	XCTAssertEqual(result.sampleCount, (NSUInteger)0);
}

@end
