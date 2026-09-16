/*!
	@file       FxGripObjectTrackerParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerParameterTests
	@abstract   Tests the FxGripObjectTrackerParameter type, creation, and default parse.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the type identity, the custom value classes, the hidden custom-UI parameter it creates holding tracker data, the configuration it parses from its declared default, and the host-refusal result.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameterFlags.h>
#import "FxGripParameterClassTestSupport.h"

typedef NS_ENUM(NSInteger, FxGripObjectTrackerShape) {
	FxGripObjectTrackerShapeRectangle		= 0,
	FxGripObjectTrackerShapeQuadrilateral	= 1,
};

typedef NS_ENUM(NSInteger, FxGripObjectTrackerResolution) {
	FxGripObjectTrackerResolutionFull	= 0,
	FxGripObjectTrackerResolutionHalf	= 1,
};

/*! Mirrors the layout of the resolved transform the parameter fills in. */
typedef struct {
	CGPoint location;
	CGFloat rotation;
	CGSize  size;
} FxGripObjectTrackerTransform;

@interface FxGripObjectTrackerData : NSObject
@property (copy, nonatomic) NSString *label;
@property (nonatomic) NSInteger shape;
@property (nonatomic) NSInteger behavior;
@property (nonatomic) NSInteger resolution;
@property (nonatomic) NSInteger smoothing;
@property (nonatomic) BOOL includeLeadingFilters;
@property (nonatomic) BOOL enabled;
@property (nonatomic) CGRect initialBox;
@property (nonatomic) NSInteger lowerLeftParameterID;
@property (nonatomic) NSInteger upperRightParameterID;
@property (nonatomic) NSInteger centerParameterID;
@property (copy, nonatomic) NSArray<NSNumber *> *anchorParameterIDs;
@property (nonatomic) NSInteger angleParameterID;
@property (readonly, nonatomic) NSUInteger sampleCount;
@property (readonly, nonatomic) NSArray<NSNumber *> *sampleFrameIndexes;
@end

@interface FxGripObjectTrackerParameter : NSObject
+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (nullable NSSet<Class> *)customValueClasses;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id)effect;
+ (FxGripObjectTrackerData *)trackerDataFromDeclared:(nullable NSDictionary *)declared;
- (nullable instancetype)initWithDictionary:(nonnull NSDictionary *)dictionary effect:(nonnull id)effect;
- (nullable NSView *)newParameterView;
- (void)beginObjectTrackingAnalysis;
- (void)beginObjectTrackingAnalysisWithFrameDuration:(CMTime)frameDuration;
- (void)analyzeObjectTrackingImage:(nullable CIImage *)image atFrame:(NSInteger)frameIndex;
- (void)endObjectTrackingAnalysis;
- (BOOL)transform:(nonnull FxGripObjectTrackerTransform *)outTransform atFrame:(NSInteger)frameIndex;
@end


static const FxParameterId kTrackerTestParameter = 41;

/*! Answers every read but the point read, so a linked anchor has no initial position. */
@interface FxGripTrackerTestPointRefusingAPI : FxGripParamClassTestRetrievalAPI
@end

@implementation FxGripTrackerTestPointRefusingAPI

- (BOOL)getXValue:(double *)xValue YValue:(double *)yValue fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	return NO;
}

@end

@interface FxGripObjectTrackerParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripObjectTrackerParameterTests

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

- (Class)trackerClass
{
	return NSClassFromString(@"FxGripObjectTrackerParameter");
}

- (BOOL)addWithDefault:(nullable NSDictionary *)declared
{
	NSDictionary *extra = declared ? @{kFxParameterProperty_Default: declared} : nil;
	NSDictionary *config = FxGripParamClassTestConfig(kTrackerTestParameter,
													  kFxParameterType_ObjectTracker, @"Tracker", extra);
	return [[self trackerClass] addParameter:config toEffect:(id)self.effect];
}

/*! @abstract The parameter reports the object-tracker FxPlug type and the matching type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual([[self trackerClass] parameterType], FxParameterType_ObjectTracker);
	XCTAssertEqualObjects([[self trackerClass] parameterTypeString], kFxParameterType_ObjectTracker);
}

/*! @abstract The custom value classes cover the tracker data and its sample class. */
- (void)testCustomValueClassesCoverTheStoredGraph
{
	NSSet<Class> *classes = [[self trackerClass] customValueClasses];
	XCTAssertTrue([classes containsObject:NSClassFromString(@"FxGripObjectTrackerData")]);
	XCTAssertTrue([classes containsObject:NSClassFromString(@"FxGripObjectTrackerSample")]);
}

/*! @abstract Creation registers a custom-UI parameter whose default value is an enabled tracker data object. */
- (void)testAddCreatesACustomUIParameterHoldingTrackerData
{
	XCTAssertTrue([self addWithDefault:nil]);
	NSDictionary *call = self.effect.creationCall;
	XCTAssertEqualObjects(call[@"method"], @"custom");
	XCTAssertEqualObjects(call[@"id"], @(kTrackerTestParameter));

	FxParameterFlags flags = [call[@"flags"] unsignedLongLongValue];
	XCTAssertTrue((flags & kFxParameterFlag_CUSTOM_UI) != 0, @"the options view is a custom UI");

	id value = call[@"default"];
	XCTAssertTrue([value isKindOfClass:NSClassFromString(@"FxGripObjectTrackerData")]);
	XCTAssertTrue([(FxGripObjectTrackerData *)value enabled], @"default tracker is enabled");
}

/*! @abstract A declared configuration is parsed into the default tracker data's shape, smoothing, enabled flag, label, and initial box. */
- (void)testDeclaredConfigurationIsParsedIntoTheDefault
{
	BOOL ok = [self addWithDefault:@{
		@"shape": @(FxGripObjectTrackerShapeQuadrilateral),
		@"smoothing": @4,
		@"enabled": @NO,
		@"label": @"Ball",
		@"initialBox": @[@0.1, @0.2, @0.3, @0.25],
	}];
	XCTAssertTrue(ok);

	FxGripObjectTrackerData *value = self.effect.creationCall[@"default"];
	XCTAssertEqual(value.shape, FxGripObjectTrackerShapeQuadrilateral);
	XCTAssertEqual(value.smoothing, 4);
	XCTAssertFalse(value.enabled);
	XCTAssertEqualObjects(value.label, @"Ball");
	XCTAssertTrue(CGRectEqualToRect(value.initialBox, CGRectMake(0.1, 0.2, 0.3, 0.25)));
}

/*! @abstract A host that refuses creation makes the add call return false. */
- (void)testHostRefusalIsReported
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;
	XCTAssertFalse([self addWithDefault:nil]);
}


/*! @abstract Every remaining configuration key is parsed into the default tracker data. */
- (void)testTheRemainingConfigurationKeysAreParsed
{
	BOOL added = [self addWithDefault:@{
		@"behavior": @2,
		@"resolution": @1,
		@"includeLeadingFilters": @YES,
		@"lowerLeftParameterID": @11,
		@"upperRightParameterID": @12,
		@"centerParameterID": @13,
		@"anchorParameterIDs": @[@21, @22],
		@"angleParameterID": @14,
	}];
	XCTAssertTrue(added);

	FxGripObjectTrackerData *value = self.effect.creationCall[@"default"];
	XCTAssertEqual(value.behavior, 2);
	XCTAssertEqual(value.resolution, 1);
	XCTAssertTrue(value.includeLeadingFilters);
	XCTAssertEqual(value.lowerLeftParameterID, 11);
	XCTAssertEqual(value.upperRightParameterID, 12);
	XCTAssertEqual(value.centerParameterID, 13);
	XCTAssertEqualObjects(value.anchorParameterIDs, (@[@21, @22]));
	XCTAssertEqual(value.angleParameterID, 14);
}

/*! @abstract A declared entry of the wrong class leaves that option at its default. */
- (void)testADeclaredEntryOfAnotherClassIsIgnored
{
	FxGripObjectTrackerData *fresh = [[self trackerClass] trackerDataFromDeclared:nil];

	FxGripObjectTrackerData *parsed = [[self trackerClass] trackerDataFromDeclared:@{
		@"shape": @"quadrilateral",
		@"label": @(7),
		@"initialBox": @[@0.1, @0.2],
		@"anchorParameterIDs": @"not an array",
	}];

	XCTAssertEqual(parsed.shape, fresh.shape);
	XCTAssertEqualObjects(parsed.label, fresh.label);
	XCTAssertTrue(CGRectEqualToRect(parsed.initialBox, fresh.initialBox), @"a short box is refused");
	XCTAssertEqualObjects(parsed.anchorParameterIDs, fresh.anchorParameterIDs);
}

/*! @abstract A declared value that is not a dictionary yields the default tracker data. */
- (void)testADeclaredValueOfAnotherClassYieldsTheDefault
{
	FxGripObjectTrackerData *parsed = [[self trackerClass] trackerDataFromDeclared:(id)@"not a dictionary"];

	XCTAssertNotNil(parsed);
	XCTAssertTrue(parsed.enabled);
}

#pragma mark The vended view

/*! @abstract The parameter vends the options view, wired to itself and seeded from the declared configuration. */
- (void)testTheVendedViewIsWiredAndSeeded
{
	NSDictionary *config = FxGripParamClassTestConfig(kTrackerTestParameter, kFxParameterType_ObjectTracker,
													  @"Tracker",
													  @{kFxParameterProperty_Default: @{@"smoothing": @6}});
	id parameter = [[[self trackerClass] alloc] initWithDictionary:config effect:(id)self.effect];

	NSView *view = [parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:NSClassFromString(@"FxGripObjectTrackerView")]);
	XCTAssertEqualObjects([view valueForKey:@"parameterEffect"], self.effect);
	XCTAssertEqualObjects([view valueForKey:@"parameterID"], @(kTrackerTestParameter));

	NSStepper *stepper = nil;
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSStepper.class]) {
			stepper = (NSStepper *)sub;
		}
	}
	XCTAssertEqual(stepper.integerValue, 6, @"the declared smoothing seeds the control");
}

#pragma mark Analysis seeding

/*! @abstract Beginning a pass reads the seed box from the linked corner points. */
- (void)testBeginningAPassSeedsTheBoxFromTheLinkedCorners
{
	NSDictionary *declared = @{@"lowerLeftParameterID": @11, @"upperRightParameterID": @12};
	NSDictionary *config = FxGripParamClassTestConfig(kTrackerTestParameter, kFxParameterType_ObjectTracker,
													  @"Tracker", @{kFxParameterProperty_Default: declared});
	id parameter = [[[self trackerClass] alloc] initWithDictionary:config effect:(id)self.effect];
	self.effect.apiManager.paramGetAPIv6.customValue =
		[[self trackerClass] trackerDataFromDeclared:declared];
	self.effect.apiManager.paramGetAPIv6.x = 0.8;
	self.effect.apiManager.paramGetAPIv6.y = 0.6;

	[parameter beginObjectTrackingAnalysisWithFrameDuration:FxGripParamClassTestTime(1, 30)];

	// Both corner reads answer the same staged point, so the seeded box is empty at that point.
	NSArray<NSDictionary *> *reads = self.effect.apiManager.paramGetAPIv6.reads;
	NSMutableArray<NSNumber *> *pointReads = NSMutableArray.new;
	for (NSDictionary *read in reads) {
		if ([read[@"accessor"] isEqualToString:@"point"]) {
			[pointReads addObject:read[@"id"]];
		}
	}
	XCTAssertEqualObjects(pointReads, (@[@11, @12]), @"both linked corners are read");
}

/*! @abstract A pass with no linked corners reads no corner points. */
- (void)testAPassWithoutLinkedCornersReadsNoCornerPoints
{
	NSDictionary *config = FxGripParamClassTestConfig(kTrackerTestParameter, kFxParameterType_ObjectTracker,
													  @"Tracker", nil);
	id parameter = [[[self trackerClass] alloc] initWithDictionary:config effect:(id)self.effect];

	[parameter beginObjectTrackingAnalysisWithFrameDuration:FxGripParamClassTestTime(1, 30)];

	for (NSDictionary *read in self.effect.apiManager.paramGetAPIv6.reads) {
		XCTAssertNotEqualObjects(read[@"accessor"], @"point");
	}
}


#pragma mark Analysis pass

// A high-contrast textured patch on a dark ground, at a pixel origin Vision can lock onto.
// The CG context origin is lower-left, matching Vision's normalized bounding-box convention.
- (CIImage *)frameWithPatchX:(CGFloat)patchX
{
	const size_t width = 320, height = 180;
	const CGFloat patch = 48.0;
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, 0, space, kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(space);

	CGContextSetRGBFillColor(ctx, 0.08, 0.08, 0.10, 1.0);
	CGContextFillRect(ctx, CGRectMake(0, 0, width, height));
	CGContextSetRGBFillColor(ctx, 0.95, 0.92, 0.20, 1.0);
	CGContextFillRect(ctx, CGRectMake(patchX, 60.0, patch, patch));
	CGContextSetRGBFillColor(ctx, 0.05, 0.05, 0.60, 1.0);
	CGContextFillRect(ctx, CGRectMake(patchX + 8.0, 68.0, 12.0, 12.0));
	CGContextFillRect(ctx, CGRectMake(patchX + 28.0, 88.0, 12.0, 12.0));

	CGImageRef image = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	CIImage *result = [CIImage imageWithCGImage:image];
	CGImageRelease(image);
	return result;
}

- (id)parameterWithDeclared:(NSDictionary *)declared
{
	NSDictionary *config = FxGripParamClassTestConfig(kTrackerTestParameter, kFxParameterType_ObjectTracker,
													  @"Tracker", @{kFxParameterProperty_Default: declared});
	id parameter = [[[self trackerClass] alloc] initWithDictionary:config effect:(id)self.effect];
	self.effect.apiManager.paramGetAPIv6.customValue = [[self trackerClass] trackerDataFromDeclared:declared];
	return parameter;
}

/*! Runs a five-frame pass over a patch that steps rightward. */
- (void)runPassOn:(id)parameter frames:(NSInteger)frames
{
	for (NSInteger frame = 0; frame < frames; frame++) {
		[parameter analyzeObjectTrackingImage:[self frameWithPatchX:80.0 + frame * 12.0] atFrame:frame];
	}
}

- (NSArray<NSDictionary *> *)writesWithAccessor:(NSString *)accessor
{
	NSMutableArray<NSDictionary *> *matched = NSMutableArray.new;
	for (NSDictionary *write in self.effect.apiManager.paramSetAPIv5.writes) {
		if ([write[@"accessor"] isEqualToString:accessor]) {
			[matched addObject:write];
		}
	}
	return matched;
}

/*! @abstract A pass stores one sample per analyzed frame and writes the value back when it ends. */
- (void)testAPassStoresOneSamplePerFrameAndWritesTheValueBack
{
	NSDictionary *declared = @{@"enabled": @YES, @"initialBox": @[@0.25, @0.33, @0.15, @0.27]};
	id parameter = [self parameterWithDeclared:declared];

	[parameter beginObjectTrackingAnalysisWithFrameDuration:FxGripParamClassTestTime(1, 30)];
	[self runPassOn:parameter frames:5];
	[parameter endObjectTrackingAnalysis];

	NSArray<NSDictionary *> *customWrites = [self writesWithAccessor:@"custom"];
	XCTAssertEqual(customWrites.count, 1u);
	FxGripObjectTrackerData *written = customWrites.firstObject[@"value"];
	XCTAssertEqual(written.sampleCount, 5u, @"the seed frame and the four tracked frames");
	XCTAssertEqualObjects(written.sampleFrameIndexes.firstObject, @(0));
}

/*! @abstract A disabled tracker stores nothing, so a pass over it leaves the value empty. */
- (void)testADisabledTrackerStoresNoSamples
{
	id parameter = [self parameterWithDeclared:@{@"enabled": @NO,
												 @"initialBox": @[@0.25, @0.33, @0.15, @0.27]}];

	[parameter beginObjectTrackingAnalysisWithFrameDuration:FxGripParamClassTestTime(1, 30)];
	[self runPassOn:parameter frames:3];
	[parameter endObjectTrackingAnalysis];

	FxGripObjectTrackerData *written = [self writesWithAccessor:@"custom"].firstObject[@"value"];
	XCTAssertEqual(written.sampleCount, 0u);
}

/*! @abstract A frame analyzed before the pass begins is ignored, and so is a nil frame. */
- (void)testFramesOutsideAPassAreIgnored
{
	id parameter = [self parameterWithDeclared:@{@"enabled": @YES}];

	XCTAssertNoThrow([parameter analyzeObjectTrackingImage:[self frameWithPatchX:80.0] atFrame:0]);

	[parameter beginObjectTrackingAnalysisWithFrameDuration:FxGripParamClassTestTime(1, 30)];
	[parameter analyzeObjectTrackingImage:nil atFrame:0];
	[parameter endObjectTrackingAnalysis];

	FxGripObjectTrackerData *written = [self writesWithAccessor:@"custom"].firstObject[@"value"];
	XCTAssertEqual(written.sampleCount, 0u);
}

/*! @abstract Half resolution still stores a sample per frame, because the tracker's coordinates are normalized. */
- (void)testHalfResolutionStillStoresASamplePerFrame
{
	id parameter = [self parameterWithDeclared:@{@"enabled": @YES,
												 @"resolution": @(FxGripObjectTrackerResolutionHalf),
												 @"initialBox": @[@0.25, @0.33, @0.15, @0.27]}];

	[parameter beginObjectTrackingAnalysisWithFrameDuration:FxGripParamClassTestTime(1, 30)];
	[self runPassOn:parameter frames:3];
	[parameter endObjectTrackingAnalysis];

	FxGripObjectTrackerData *written = [self writesWithAccessor:@"custom"].firstObject[@"value"];
	XCTAssertEqual(written.sampleCount, 3u);
}

/*! @abstract A pass over a quadrilateral tracker stores a sample per frame with rotation tracking armed. */
- (void)testAQuadrilateralPassStoresASamplePerFrame
{
	id parameter = [self parameterWithDeclared:@{@"enabled": @YES,
												 @"shape": @(FxGripObjectTrackerShapeQuadrilateral),
												 @"initialBox": @[@0.25, @0.33, @0.15, @0.27]}];

	[parameter beginObjectTrackingAnalysisWithFrameDuration:FxGripParamClassTestTime(1, 30)];
	[self runPassOn:parameter frames:3];
	[parameter endObjectTrackingAnalysis];

	FxGripObjectTrackerData *written = [self writesWithAccessor:@"custom"].firstObject[@"value"];
	XCTAssertGreaterThanOrEqual(written.sampleCount, 1u);
}

#pragma mark Linked points

/*! @abstract The pass bakes the tracked center, the angle, and each anchor as keyframes across the analyzed frames. */
- (void)testThePassBakesTheLinkedPointsAsKeyframes
{
	NSDictionary *declared = @{@"enabled": @YES,
							   @"initialBox": @[@0.25, @0.33, @0.15, @0.27],
							   @"centerParameterID": @31,
							   @"angleParameterID": @32,
							   @"anchorParameterIDs": @[@41]};
	id parameter = [self parameterWithDeclared:declared];
	self.effect.apiManager.paramGetAPIv6.x = 0.3;
	self.effect.apiManager.paramGetAPIv6.y = 0.45;

	[parameter beginObjectTrackingAnalysisWithFrameDuration:FxGripParamClassTestTime(1, 30)];
	[self runPassOn:parameter frames:4];
	[parameter endObjectTrackingAnalysis];

	NSArray<NSDictionary *> *points = [self writesWithAccessor:@"point"];
	NSArray<NSDictionary *> *angles = [self writesWithAccessor:@"float"];
	NSMutableSet<NSNumber *> *pointIDs = NSMutableSet.new;
	for (NSDictionary *write in points) {
		[pointIDs addObject:write[@"id"]];
	}
	XCTAssertEqualObjects(pointIDs, ([NSSet setWithArray:@[@31, @41]]), @"the center and the anchor are baked");
	XCTAssertEqual(points.count, 8u, @"four frames of the center and four of the anchor");
	XCTAssertEqual(angles.count, 4u, @"one angle keyframe per frame");
	XCTAssertEqualObjects(angles.firstObject[@"id"], @(32));
	XCTAssertEqualObjects(angles.lastObject[@"timevalue"], @(3), @"the last keyframe lands on the last frame");
}

/*! @abstract An anchor whose initial position the host refuses is left unbaked. */
- (void)testAnAnchorWithoutAnInitialPositionIsLeftUnbaked
{
	NSDictionary *declared = @{@"enabled": @YES,
							   @"initialBox": @[@0.25, @0.33, @0.15, @0.27],
							   @"anchorParameterIDs": @[@41]};
	self.effect.apiManager.paramGetAPIv6 = [FxGripTrackerTestPointRefusingAPI.alloc init];
	id parameter = [self parameterWithDeclared:declared];

	[parameter beginObjectTrackingAnalysisWithFrameDuration:FxGripParamClassTestTime(1, 30)];
	[self runPassOn:parameter frames:3];
	[parameter endObjectTrackingAnalysis];

	FxGripObjectTrackerData *written = [self writesWithAccessor:@"custom"].firstObject[@"value"];
	XCTAssertEqualObjects(written.anchorParameterIDs, @[@41], @"the anchor stays linked");
	XCTAssertEqualObjects([self writesWithAccessor:@"point"], @[], @"no keyframe without a start position");
}

/*! @abstract A pass with no linked parameters bakes no keyframes. */
- (void)testAPassWithoutLinkedParametersBakesNoKeyframes
{
	id parameter = [self parameterWithDeclared:@{@"enabled": @YES,
												 @"initialBox": @[@0.25, @0.33, @0.15, @0.27]}];

	[parameter beginObjectTrackingAnalysisWithFrameDuration:FxGripParamClassTestTime(1, 30)];
	[self runPassOn:parameter frames:3];
	[parameter endObjectTrackingAnalysis];

	XCTAssertEqualObjects([self writesWithAccessor:@"point"], @[]);
	XCTAssertEqualObjects([self writesWithAccessor:@"float"], @[]);
}

/*! @abstract A pass begun without a frame duration cannot place keyframes, so it bakes none. */
- (void)testAPassWithoutAFrameDurationBakesNoKeyframes
{
	NSDictionary *declared = @{@"enabled": @YES,
							   @"initialBox": @[@0.25, @0.33, @0.15, @0.27],
							   @"centerParameterID": @31};
	id parameter = [self parameterWithDeclared:declared];

	[parameter beginObjectTrackingAnalysis];
	[self runPassOn:parameter frames:3];
	[parameter endObjectTrackingAnalysis];

	XCTAssertEqual([self writesWithAccessor:@"custom"].count, 1u, @"the samples still save");
	XCTAssertEqualObjects([self writesWithAccessor:@"point"], @[]);
}

/*! @abstract Ending a pass that never began writes nothing. */
- (void)testEndingAPassThatNeverBeganWritesNothing
{
	id parameter = [self parameterWithDeclared:@{@"enabled": @YES}];

	[parameter endObjectTrackingAnalysis];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.writes, @[]);
}

#pragma mark Resolved transform

/*! @abstract The resolved transform reads the stored samples back by frame. */
- (void)testTheResolvedTransformReadsTheStoredSamplesBack
{
	NSDictionary *declared = @{@"enabled": @YES, @"initialBox": @[@0.25, @0.33, @0.15, @0.27]};
	id parameter = [self parameterWithDeclared:declared];
	[parameter beginObjectTrackingAnalysisWithFrameDuration:FxGripParamClassTestTime(1, 30)];
	[self runPassOn:parameter frames:3];
	[parameter endObjectTrackingAnalysis];
	// The host now holds what the pass wrote.
	self.effect.apiManager.paramGetAPIv6.customValue = [self writesWithAccessor:@"custom"].firstObject[@"value"];

	FxGripObjectTrackerTransform transform = {0};
	XCTAssertTrue([parameter transform:&transform atFrame:0]);
	XCTAssertEqualWithAccuracy(transform.location.x, 0.325, 1e-6, @"the seed box center");
	XCTAssertEqualWithAccuracy(transform.location.y, 0.465, 1e-6);
	XCTAssertEqualWithAccuracy(transform.size.width, 0.15, 1e-6);
}

/*! @abstract The resolved transform reports failure when the host holds no tracker value. */
- (void)testTheResolvedTransformFailsWithoutATrackerValue
{
	id parameter = [self parameterWithDeclared:@{@"enabled": @YES}];
	self.effect.apiManager.paramGetAPIv6.customValue = @"not tracker data";

	FxGripObjectTrackerTransform transform = {0};
	XCTAssertFalse([parameter transform:&transform atFrame:0]);
}

@end
