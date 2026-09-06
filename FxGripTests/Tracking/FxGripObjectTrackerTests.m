/*!
	@file       FxGripObjectTrackerTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerTests
	@abstract   Verifies the Vision-backed FxGripObjectTracker follows a moving patch across a synthetic frame sequence.
	@discussion Introduced in FxGrip 0.1.0. A high-contrast textured patch is drawn on a dark ground and stepped horizontally across frames, and the tracker is seeded on the first frame and tracked on the rest. The tests confirm the track follows the patch rightward within tolerance, rotation mode seeds and reports a finite rotation, and reset clears the last sample.
*/

#import <XCTest/XCTest.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSInteger, FxGripObjectTrackerLevel) {
	FxGripObjectTrackerLevelFast		= 0,
	FxGripObjectTrackerLevelAccurate	= 1,
};

@interface FxGripObjectTrackerSample : NSObject <NSCopying>
@property (readonly, nonatomic) CGRect boundingBox;
@property (readonly, nonatomic) CGPoint center;
@property (readonly, nonatomic) float confidence;
@property (readonly, nonatomic) CGFloat rotation;
@end

@interface FxGripObjectTracker : NSObject
@property (nonatomic) FxGripObjectTrackerLevel level;
@property (nonatomic) BOOL tracksRotation;
@property (readonly, nullable, nonatomic) FxGripObjectTrackerSample *lastSample;
- (instancetype)initWithLevel:(FxGripObjectTrackerLevel)level;
- (BOOL)startTrackingImage:(CIImage *)image boundingBox:(CGRect)normalizedBox error:(NSError **)error;
- (nullable FxGripObjectTrackerSample *)trackImage:(CIImage *)image error:(NSError **)error;
- (void)reset;
@end


static const size_t kFrameWidth  = 480;
static const size_t kFrameHeight = 270;
static const CGFloat kPatchSize  = 72.0;
static const CGFloat kStartX     = 60.0;
static const CGFloat kStepX      = 24.0;
static const NSInteger kFrameCount = 9;

@interface FxGripObjectTrackerTests : XCTestCase
@end

@implementation FxGripObjectTrackerTests

// A high-contrast, textured patch (corners and edges Vision can lock onto) drawn on a dark
// ground at pixel origin (patchX, patchY), returned as a CIImage. The CG context origin is
// lower-left, matching Vision's normalized bounding-box convention.
- (CIImage *)frameWithPatchX:(CGFloat)patchX patchY:(CGFloat)patchY
{
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, kFrameWidth, kFrameHeight, 8, 0, space,
											 kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(space);

	CGContextSetRGBFillColor(ctx, 0.08, 0.08, 0.10, 1.0);
	CGContextFillRect(ctx, CGRectMake(0, 0, kFrameWidth, kFrameHeight));

	CGRect patch = CGRectMake(patchX, patchY, kPatchSize, kPatchSize);
	CGContextSetRGBFillColor(ctx, 0.95, 0.85, 0.10, 1.0);
	CGContextFillRect(ctx, patch);
	CGContextSetRGBFillColor(ctx, 0.10, 0.20, 0.90, 1.0);
	CGContextFillRect(ctx, CGRectInset(patch, kPatchSize * 0.28, kPatchSize * 0.28));
	CGContextSetRGBFillColor(ctx, 0.90, 0.10, 0.15, 1.0);
	CGContextMoveToPoint(ctx, patchX, patchY);
	CGContextAddLineToPoint(ctx, patchX + kPatchSize, patchY + kPatchSize);
	CGContextAddLineToPoint(ctx, patchX + kPatchSize, patchY);
	CGContextFillPath(ctx);

	CGImageRef cg = CGBitmapContextCreateImage(ctx);
	CIImage *image = [CIImage imageWithCGImage:cg];
	CGImageRelease(cg);
	CGContextRelease(ctx);
	return image;
}

- (CGFloat)groundTruthCenterXForFrame:(NSInteger)frame
{
	return (kStartX + frame * kStepX + kPatchSize / 2.0) / (CGFloat)kFrameWidth;
}

/*! @abstract The tracker follows the patch across frames, staying within tolerance of the ground-truth center and ending further right than it started. */
- (void)testTrackerFollowsHorizontallyMovingPatch
{
	FxGripObjectTracker *tracker = [[FxGripObjectTracker alloc] initWithLevel:FxGripObjectTrackerLevelAccurate];

	CGFloat patchY = (kFrameHeight - kPatchSize) / 2.0;
	CGRect seedBox = CGRectMake(kStartX / (CGFloat)kFrameWidth,
								patchY / (CGFloat)kFrameHeight,
								kPatchSize / (CGFloat)kFrameWidth,
								kPatchSize / (CGFloat)kFrameHeight);

	CIImage *firstFrame = [self frameWithPatchX:kStartX patchY:patchY];
	NSError *error = nil;
	XCTAssertTrue([tracker startTrackingImage:firstFrame boundingBox:seedBox error:&error],
				  @"seed failed: %@", error);

	CGFloat firstTrackedX = 0.0;
	CGFloat lastTrackedX = 0.0;
	for (NSInteger frame = 1; frame < kFrameCount; frame++) {
		CGFloat patchX = kStartX + frame * kStepX;
		CIImage *image = [self frameWithPatchX:patchX patchY:patchY];
		FxGripObjectTrackerSample *sample = [tracker trackImage:image error:&error];
		XCTAssertNotNil(sample, @"frame %ld returned no sample: %@", (long)frame, error);
		if (sample == nil) {
			return;
		}
		if (frame == 1) {
			firstTrackedX = sample.center.x;
		}
		lastTrackedX = sample.center.x;

		CGFloat truth = [self groundTruthCenterXForFrame:frame];
		XCTAssertEqualWithAccuracy(sample.center.x, truth, 0.12,
			@"frame %ld tracked x %.3f drifted from truth %.3f", (long)frame, sample.center.x, truth);
	}

	XCTAssertGreaterThan(lastTrackedX, firstTrackedX + 0.15,
		@"the track did not follow the patch rightward (first %.3f, last %.3f)", firstTrackedX, lastTrackedX);
}

/*! @abstract With rotation tracking enabled, the pass produces at least one sample and each reports a finite rotation. */
- (void)testRotationModeSeedsTracksAndReportsFiniteRotation
{
	FxGripObjectTracker *tracker = [[FxGripObjectTracker alloc] initWithLevel:FxGripObjectTrackerLevelAccurate];
	tracker.tracksRotation = YES;

	CGFloat patchY = (kFrameHeight - kPatchSize) / 2.0;
	CGRect seedBox = CGRectMake(kStartX / (CGFloat)kFrameWidth, patchY / (CGFloat)kFrameHeight,
								kPatchSize / (CGFloat)kFrameWidth, kPatchSize / (CGFloat)kFrameHeight);
	XCTAssertTrue([tracker startTrackingImage:[self frameWithPatchX:kStartX patchY:patchY]
								  boundingBox:seedBox error:NULL]);

	NSInteger tracked = 0;
	for (NSInteger frame = 1; frame < kFrameCount; frame++) {
		FxGripObjectTrackerSample *sample = [tracker trackImage:[self frameWithPatchX:kStartX + frame * kStepX patchY:patchY]
														 error:NULL];
		if (sample != nil) {
			tracked += 1;
			XCTAssertFalse(isnan(sample.rotation), @"rotation must be finite");
		}
	}
	// Whether Vision seeds the rectangle tracker or falls back to the box tracker, the pass
	// produces samples for the moving patch.
	XCTAssertGreaterThan(tracked, 0, @"the rotation-mode pass produced no samples");
}

/*! @abstract Reset clears the last sample after a successful seed. */
- (void)testResetClearsLastSample
{
	FxGripObjectTracker *tracker = [[FxGripObjectTracker alloc] initWithLevel:FxGripObjectTrackerLevelFast];
	CGFloat patchY = (kFrameHeight - kPatchSize) / 2.0;
	CGRect seedBox = CGRectMake(kStartX / (CGFloat)kFrameWidth, patchY / (CGFloat)kFrameHeight,
								kPatchSize / (CGFloat)kFrameWidth, kPatchSize / (CGFloat)kFrameHeight);
	[tracker startTrackingImage:[self frameWithPatchX:kStartX patchY:patchY] boundingBox:seedBox error:NULL];
	XCTAssertNotNil(tracker.lastSample);
	[tracker reset];
	XCTAssertNil(tracker.lastSample);
}

@end
