//
//  FxGripObjectTrackerDataTests.m
//  FxGripTests
//
//  The Object Tracker parameter's persisted value: configuration round-trip under secure
//  coding, the sparse frame-indexed sample store with hold-forward seek, box-averaging
//  smoothing, and copy independence. The framework headers use quoted includes that do not
//  resolve from the test target, so the surface under test is re-declared here.
//

#import <XCTest/XCTest.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSInteger, FxGripObjectTrackerShape) {
	FxGripObjectTrackerShapeRectangle		= 0,
	FxGripObjectTrackerShapeQuadrilateral	= 1,
};
typedef NS_ENUM(NSInteger, FxGripObjectTrackerBehavior) {
	FxGripObjectTrackerBehaviorPositionOnly		= 0,
	FxGripObjectTrackerBehaviorPositionAndScale	= 1,
};
typedef NS_ENUM(NSInteger, FxGripObjectTrackerResolution) {
	FxGripObjectTrackerResolutionFull	= 0,
	FxGripObjectTrackerResolutionHalf	= 1,
};
typedef struct {
	CGPoint location;
	CGFloat rotation;
	CGSize  size;
} FxGripObjectTrackerTransform;

@interface FxGripObjectTrackerSample : NSObject <NSSecureCoding, NSCopying>
@property (readonly, nonatomic) CGRect boundingBox;
@property (readonly, nonatomic) CGPoint center;
@property (readonly, nonatomic) float confidence;
@property (readonly, nonatomic) CGFloat rotation;
- (instancetype)initWithBoundingBox:(CGRect)boundingBox confidence:(float)confidence;
- (instancetype)initWithBoundingBox:(CGRect)boundingBox rotation:(CGFloat)rotation confidence:(float)confidence;
@end

@interface FxGripObjectTrackerData : NSObject <NSSecureCoding, NSCopying>
@property (copy, nonatomic) NSString *label;
@property (nonatomic) FxGripObjectTrackerShape shape;
@property (nonatomic) FxGripObjectTrackerBehavior behavior;
@property (nonatomic) FxGripObjectTrackerResolution resolution;
@property (nonatomic) NSInteger smoothing;
@property (nonatomic) BOOL includeLeadingFilters;
@property (nonatomic) BOOL enabled;
@property (nonatomic) CGRect initialBox;
@property (nonatomic) NSInteger lowerLeftParameterID;
@property (nonatomic) NSInteger upperRightParameterID;
@property (nonatomic) NSInteger centerParameterID;
@property (copy, nonatomic) NSArray<NSNumber *> *anchorParameterIDs;
@property (readonly, nonatomic) NSUInteger sampleCount;
@property (readonly, nonatomic) NSArray<NSNumber *> *sampleFrameIndexes;
@property (readonly, nonatomic) NSInteger seedFrame;
- (nullable FxGripObjectTrackerSample *)sampleAtFrame:(NSInteger)frameIndex;
- (void)setSample:(FxGripObjectTrackerSample *)sample atFrame:(NSInteger)frameIndex;
- (nullable FxGripObjectTrackerSample *)latestSampleAtOrBeforeFrame:(NSInteger)frameIndex;
- (void)removeAllSamples;
- (BOOL)transform:(FxGripObjectTrackerTransform *)outTransform atFrame:(NSInteger)frameIndex;
- (BOOL)cornerBoxAtFrame:(NSInteger)frameIndex lowerLeft:(CGPoint *)lowerLeft upperRight:(CGPoint *)upperRight center:(CGPoint *)center;
- (BOOL)anchorPointAtFrame:(NSInteger)frameIndex initialAnchor:(CGPoint)initialAnchor seedFrame:(NSInteger)seedFrame outPoint:(CGPoint *)outPoint;
@end


@interface FxGripObjectTrackerDataTests : XCTestCase
@end

@implementation FxGripObjectTrackerDataTests

- (FxGripObjectTrackerSample *)sampleAtX:(CGFloat)x width:(CGFloat)w
{
	return [[FxGripObjectTrackerSample alloc] initWithBoundingBox:CGRectMake(x, 0.4, w, 0.2) confidence:0.9f];
}

- (void)testDefaultsAreSensible
{
	FxGripObjectTrackerData *data = [[FxGripObjectTrackerData alloc] init];
	XCTAssertTrue(data.enabled);
	XCTAssertEqual(data.shape, FxGripObjectTrackerShapeRectangle);
	XCTAssertEqual(data.behavior, FxGripObjectTrackerBehaviorPositionAndScale);
	XCTAssertEqual(data.sampleCount, 0u);
}

- (void)testConfigurationSurvivesSecureCoding
{
	FxGripObjectTrackerData *data = [[FxGripObjectTrackerData alloc] init];
	data.label = @"Face";
	data.shape = FxGripObjectTrackerShapeQuadrilateral;
	data.behavior = FxGripObjectTrackerBehaviorPositionOnly;
	data.resolution = FxGripObjectTrackerResolutionHalf;
	data.smoothing = 3;
	data.includeLeadingFilters = YES;
	data.enabled = NO;
	data.initialBox = CGRectMake(0.1, 0.2, 0.3, 0.25);
	data.lowerLeftParameterID = 31;
	data.upperRightParameterID = 32;
	data.centerParameterID = 33;
	data.anchorParameterIDs = @[@34, @35];
	[data setSample:[self sampleAtX:0.5 width:0.2] atFrame:7];

	NSError *error = nil;
	NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:YES error:&error];
	XCTAssertNotNil(archive, @"archive failed: %@", error);
	FxGripObjectTrackerData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripObjectTrackerData.class
																		fromData:archive error:&error];
	XCTAssertNotNil(decoded, @"unarchive failed: %@", error);

	XCTAssertEqualObjects(decoded.label, @"Face");
	XCTAssertEqual(decoded.shape, FxGripObjectTrackerShapeQuadrilateral);
	XCTAssertEqual(decoded.behavior, FxGripObjectTrackerBehaviorPositionOnly);
	XCTAssertEqual(decoded.resolution, FxGripObjectTrackerResolutionHalf);
	XCTAssertEqual(decoded.smoothing, 3);
	XCTAssertTrue(decoded.includeLeadingFilters);
	XCTAssertFalse(decoded.enabled);
	XCTAssertTrue(CGRectEqualToRect(decoded.initialBox, CGRectMake(0.1, 0.2, 0.3, 0.25)));
	XCTAssertEqual(decoded.lowerLeftParameterID, 31);
	XCTAssertEqual(decoded.upperRightParameterID, 32);
	XCTAssertEqual(decoded.centerParameterID, 33);
	XCTAssertEqualObjects(decoded.anchorParameterIDs, (@[@34, @35]));
	XCTAssertEqual(decoded.sampleCount, 1u);
	XCTAssertEqualWithAccuracy([decoded sampleAtFrame:7].boundingBox.origin.x, 0.5, 1e-9);
}

- (void)testSparseStoreAndHoldForwardSeek
{
	FxGripObjectTrackerData *data = [[FxGripObjectTrackerData alloc] init];
	[data setSample:[self sampleAtX:0.1 width:0.2] atFrame:0];
	[data setSample:[self sampleAtX:0.5 width:0.2] atFrame:10];

	XCTAssertEqualObjects(data.sampleFrameIndexes, (@[@0, @10]));
	XCTAssertNil([data latestSampleAtOrBeforeFrame:-1]);
	XCTAssertEqualWithAccuracy([data latestSampleAtOrBeforeFrame:5].boundingBox.origin.x, 0.1, 1e-9);
	XCTAssertEqualWithAccuracy([data latestSampleAtOrBeforeFrame:99].boundingBox.origin.x, 0.5, 1e-9);

	[data removeAllSamples];
	XCTAssertEqual(data.sampleCount, 0u);
}

- (void)testTransformReturnsCenterAndSize
{
	FxGripObjectTrackerData *data = [[FxGripObjectTrackerData alloc] init];
	FxGripObjectTrackerTransform t = {0};
	XCTAssertFalse([data transform:&t atFrame:0], @"no samples yet");

	[data setSample:[self sampleAtX:0.30 width:0.20] atFrame:4];
	XCTAssertTrue([data transform:&t atFrame:4]);
	XCTAssertEqualWithAccuracy(t.location.x, 0.40, 1e-9);   // 0.30 + 0.20/2
	XCTAssertEqualWithAccuracy(t.location.y, 0.50, 1e-9);   // 0.40 + 0.20/2
	XCTAssertEqualWithAccuracy(t.size.width, 0.20, 1e-9);
	XCTAssertEqualWithAccuracy(t.rotation, 0.0, 1e-9);
}

- (void)testTransformCarriesSampleRotation
{
	FxGripObjectTrackerData *data = [[FxGripObjectTrackerData alloc] init];
	FxGripObjectTrackerSample *sample =
		[[FxGripObjectTrackerSample alloc] initWithBoundingBox:CGRectMake(0.3, 0.4, 0.2, 0.2)
													  rotation:0.30 confidence:0.9f];
	[data setSample:sample atFrame:2];

	FxGripObjectTrackerTransform t = {0};
	XCTAssertTrue([data transform:&t atFrame:2]);
	XCTAssertEqualWithAccuracy(t.rotation, 0.30, 1e-9);
}

- (void)testSmoothingAveragesTheWindow
{
	FxGripObjectTrackerData *data = [[FxGripObjectTrackerData alloc] init];
	[data setSample:[self sampleAtX:0.0 width:0.2] atFrame:9];
	[data setSample:[self sampleAtX:0.2 width:0.2] atFrame:10];
	[data setSample:[self sampleAtX:0.4 width:0.2] atFrame:11];
	data.smoothing = 1;

	FxGripObjectTrackerTransform t = {0};
	XCTAssertTrue([data transform:&t atFrame:10]);
	// Averaged origin x = (0.0 + 0.2 + 0.4)/3 = 0.2; center = 0.2 + 0.1 = 0.3.
	XCTAssertEqualWithAccuracy(t.location.x, 0.30, 1e-9);
}

- (FxGripObjectTrackerSample *)sampleWithCenterX:(CGFloat)cx centerY:(CGFloat)cy width:(CGFloat)w height:(CGFloat)h
{
	return [[FxGripObjectTrackerSample alloc] initWithBoundingBox:CGRectMake(cx - w / 2, cy - h / 2, w, h)
													  confidence:0.9f];
}

- (void)testCornerBoxDerivesCornersAndCenter
{
	FxGripObjectTrackerData *data = [[FxGripObjectTrackerData alloc] init];
	[data setSample:[self sampleWithCenterX:0.40 centerY:0.50 width:0.20 height:0.20] atFrame:4];

	CGPoint ll = CGPointZero, ur = CGPointZero, c = CGPointZero;
	XCTAssertTrue([data cornerBoxAtFrame:4 lowerLeft:&ll upperRight:&ur center:&c]);
	XCTAssertEqualWithAccuracy(ll.x, 0.30, 1e-9);
	XCTAssertEqualWithAccuracy(ll.y, 0.40, 1e-9);
	XCTAssertEqualWithAccuracy(ur.x, 0.50, 1e-9);
	XCTAssertEqualWithAccuracy(ur.y, 0.60, 1e-9);
	XCTAssertEqualWithAccuracy(c.x, 0.40, 1e-9);
	XCTAssertEqualWithAccuracy(c.y, 0.50, 1e-9);
}

- (void)testAnchorRidesWithBoxPositionAndScale
{
	FxGripObjectTrackerData *data = [[FxGripObjectTrackerData alloc] init];
	// Seed: center (0.4, 0.5), size (0.2, 0.2). Frame 1: moved right and doubled in width.
	[data setSample:[self sampleWithCenterX:0.40 centerY:0.50 width:0.20 height:0.20] atFrame:0];
	[data setSample:[self sampleWithCenterX:0.60 centerY:0.50 width:0.40 height:0.20] atFrame:1];

	CGPoint out = CGPointZero;
	// Anchor started 0.1 to the right of the seed center; width doubles so its offset doubles.
	XCTAssertTrue([data anchorPointAtFrame:1 initialAnchor:CGPointMake(0.5, 0.5) seedFrame:0 outPoint:&out]);
	XCTAssertEqualWithAccuracy(out.x, 0.80, 1e-9);   // 0.60 + 0.10*2
	XCTAssertEqualWithAccuracy(out.y, 0.50, 1e-9);
}

- (void)testSeedFrameIsFirstSample
{
	FxGripObjectTrackerData *data = [[FxGripObjectTrackerData alloc] init];
	XCTAssertEqual(data.seedFrame, NSNotFound);
	[data setSample:[self sampleAtX:0.1 width:0.2] atFrame:5];
	[data setSample:[self sampleAtX:0.2 width:0.2] atFrame:9];
	XCTAssertEqual(data.seedFrame, 5);
}

- (void)testCopyIsIndependent
{
	FxGripObjectTrackerData *data = [[FxGripObjectTrackerData alloc] init];
	data.smoothing = 2;
	[data setSample:[self sampleAtX:0.1 width:0.2] atFrame:0];
	FxGripObjectTrackerData *copy = [data copy];
	[data setSample:[self sampleAtX:0.9 width:0.2] atFrame:1];
	data.smoothing = 5;

	XCTAssertEqual(copy.smoothing, 2);
	XCTAssertEqual(copy.sampleCount, 1u);
}

@end
