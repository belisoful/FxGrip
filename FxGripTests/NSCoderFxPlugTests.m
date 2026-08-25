//
//  NSCoderFxPlugTests.m
//  FxGripTests
//
//  Unit tests for the NSCoder (FxPlug) category: the associated render time and
//  quality level, the byte-blob encoders and decoders for the FxPlug value types,
//  the Fx3D and FxLighting host-API captures, and the double-to-float matrix
//  conversion.
//

#import <XCTest/XCTest.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/NSCoder+FxPlug.h"

// Defined in NSCoder+FxPlug.m and exported by the framework, but not declared in the
// public header. The lighting wire format is pinned through them.
extern NSString * const FxLightingCoderLightCountKey;
extern NSString * const FxLightingCoderLightingKey;

#pragma mark - Stubs

/*!
	Stands in for FxMatrix44 in the encode direction. -encodeFxMatrix44: only sends
	-matrix, so any object answering that selector drives the encoder. FxPlug.framework
	is weak-linked and absent outside a host, so FxMatrix44 itself cannot be instantiated.
*/
@interface FxCoderMatrixStub : NSObject
{
	Matrix44Data _data;
}
- (Matrix44Data *)matrix;
- (void)fillStartingAt:(double)start;
@end

@implementation FxCoderMatrixStub

- (Matrix44Data *)matrix
{
	return &_data;
}

- (void)fillStartingAt:(double)start
{
	double *flat = (double *)&_data;
	for (int i = 0; i < 16; i++) {
		flat[i] = start + i;
	}
}

@end


@interface FxCoder3DMock : NSObject <Fx3DAPI_v5>
@property (nonatomic, strong) FxCoderMatrixStub *model;
@property (nonatomic, strong) FxCoderMatrixStub *view;
@property (nonatomic, strong) FxCoderMatrixStub *projection;
@property (nonatomic) double focalLength;
@property (nonatomic) BOOL frustumSucceeds;
// Index of the accessor that reports an error: 0 model, 1 view, 2 projection,
// 3 focal length, 4 frustum. NSNotFound means every accessor succeeds.
@property (nonatomic) NSUInteger failingStep;
@property (nonatomic) CMTime lastRequestedTime;
@end

@implementation FxCoder3DMock

- (instancetype)init
{
	self = [super init];
	if (self) {
		_model = [FxCoderMatrixStub new];
		[_model fillStartingAt:100.0];
		_view = [FxCoderMatrixStub new];
		[_view fillStartingAt:200.0];
		_projection = [FxCoderMatrixStub new];
		[_projection fillStartingAt:300.0];
		_focalLength = 42.5;
		_frustumSucceeds = YES;
		_failingStep = NSNotFound;
	}
	return self;
}

- (BOOL)reportStep:(NSUInteger)step error:(NSError **)error
{
	if (step != self.failingStep) {
		return YES;
	}
	if (error) {
		*error = [NSError errorWithDomain:@"FxCoderTest" code:(NSInteger)step userInfo:nil];
	}
	return NO;
}

- (double)focalLengthAtTime:(CMTime)time error:(NSError **)error
{
	self.lastRequestedTime = time;
	[self reportStep:3 error:error];
	return self.focalLength;
}

- (FxMatrix44 *)layerMatrixAtTime:(CMTime)time error:(NSError **)error
{
	self.lastRequestedTime = time;
	[self reportStep:0 error:error];
	return (FxMatrix44 *)self.model;
}

- (FxMatrix44 *)viewMatrixAtTime:(CMTime)time error:(NSError **)error
{
	[self reportStep:1 error:error];
	return (FxMatrix44 *)self.view;
}

- (FxMatrix44 *)metalProjectionMatrixAtTime:(CMTime)time error:(NSError **)error
{
	[self reportStep:2 error:error];
	return (FxMatrix44 *)self.projection;
}

- (BOOL)frustumLeft:(double *)left
			  right:(double *)right
			 bottom:(double *)bottom
				top:(double *)top
			   near:(double *)near
				far:(double *)far
			 atTime:(CMTime)time
			  error:(NSError **)error
{
	*left = -1.0;
	*right = 1.0;
	*bottom = -2.0;
	*top = 2.0;
	*near = 0.5;
	*far = 1000.0;
	if (![self reportStep:4 error:error]) {
		return NO;
	}
	return self.frustumSucceeds;
}

@end


@interface FxCoderLightingMock : NSObject <FxLightingAPI_v3>
@property (nonatomic) NSUInteger lightCount;
// Index whose -lightInfo: call fails; NSNotFound means every light reports.
@property (nonatomic) NSUInteger failingLight;
@end

@implementation FxCoderLightingMock

- (instancetype)init
{
	self = [super init];
	if (self) {
		_lightCount = 0;
		_failingLight = NSNotFound;
	}
	return self;
}

- (NSUInteger)numberOfLightsAtTime:(CMTime)time
{
	return self.lightCount;
}

- (BOOL)lightInfo:(FxLight *)light forLight:(NSUInteger)lightIndex atTime:(CMTime)time error:(NSError **)error
{
	if (lightIndex == self.failingLight) {
		if (error) {
			*error = [NSError errorWithDomain:@"FxCoderTest" code:(NSInteger)lightIndex userInfo:nil];
		}
		return NO;
	}
	memset(light, 0, sizeof(*light));
	light->version = kFxLight_V3;
	light->lightType = kFxLightType_Point;
	light->intensity = 1.0f + (float)lightIndex;
	light->position = (FxPoint3D){ (CGFloat)lightIndex, (CGFloat)lightIndex + 1.0, (CGFloat)lightIndex + 2.0 };
	return YES;
}

@end


#pragma mark - Tests

@interface NSCoderFxPlugTests : XCTestCase
@end

@implementation NSCoderFxPlugTests

static NSKeyedArchiver *FxCoderArchiver(void)
{
	return [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
}

static NSKeyedUnarchiver *FxCoderUnarchiver(NSKeyedArchiver *archiver)
{
	[archiver finishEncoding];
	NSError *error = nil;
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:&error];
	unarchiver.requiresSecureCoding = NO;
	return unarchiver;
}

// A valid, non-zero CMTime built without linking CoreMedia: kCMTimeZero and
// CMTimeMake are external, the flag constants are compile-time enumerators.
static CMTime FxCoderTime(int64_t value, int32_t timescale)
{
	CMTime time;
	time.value = value;
	time.timescale = timescale;
	time.flags = kCMTimeFlags_Valid;
	time.epoch = 0;
	return time;
}

static BOOL FxCoderTimesEqual(CMTime a, CMTime b)
{
	return a.value == b.value && a.timescale == b.timescale && a.flags == b.flags && a.epoch == b.epoch;
}

// The archive key -encodeFxLightingAPI:atTime:forKey: writes one light under.
static NSString *FxCoderLightKey(NSString *prefix, long index)
{
	return [prefix stringByAppendingFormat:@"%ld%@", index, FxLightingCoderLightingKey];
}

#pragma mark - Render Time

- (void)testRenderTimeIsInvalidBeforeItIsAssigned
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	CMTime time = archiver.renderTime;

	XCTAssertEqual(time.flags & kCMTimeFlags_Valid, 0);
	XCTAssertEqual(time.timescale, 0);
}

- (void)testRenderTimeRoundTripsThroughTheAssociatedObject
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	CMTime time = FxCoderTime(1500, 600);

	archiver.renderTime = time;

	XCTAssertTrue(FxCoderTimesEqual(archiver.renderTime, time));
}

- (void)testRenderTimeIsIndependentPerCoder
{
	NSKeyedArchiver *first = FxCoderArchiver();
	NSKeyedArchiver *second = FxCoderArchiver();

	first.renderTime = FxCoderTime(10, 30);

	XCTAssertEqual(second.renderTime.timescale, 0);
	XCTAssertEqual(first.renderTime.timescale, 30);
}

- (void)testIsFxPluginStateEncoderTracksWhetherARenderTimeWasAssigned
{
	NSKeyedArchiver *archiver = FxCoderArchiver();

	XCTAssertFalse(archiver.isFxPluginStateEncoder);

	archiver.renderTime = FxCoderTime(0, 1);

	XCTAssertTrue(archiver.isFxPluginStateEncoder);
}

#pragma mark - Quality Level

- (void)testQualityLevelDefaultsToHighWhenTheKeyIsAbsent
{
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(FxCoderArchiver());

	XCTAssertEqual(unarchiver.qualityLevel, (FxQuality)kFxQuality_HIGH);
}

- (void)testQualityLevelRoundTripsForEveryLevel
{
	FxQuality levels[3] = { kFxQuality_LOW, kFxQuality_MEDIUM, kFxQuality_HIGH };

	for (int i = 0; i < 3; i++) {
		NSKeyedArchiver *archiver = FxCoderArchiver();
		archiver.qualityLevel = levels[i];

		NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

		XCTAssertEqual(unarchiver.qualityLevel, levels[i]);
	}
}

- (void)testQualityLevelUsesTheDocumentedArchiveKey
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	archiver.qualityLevel = kFxQuality_MEDIUM;

	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertTrue([unarchiver containsValueForKey:kFxPlugCoderQualityLevelKey]);
	XCTAssertEqual([unarchiver decodeInt64ForKey:kFxPlugCoderQualityLevelKey], (int64_t)kFxQuality_MEDIUM);
}

#pragma mark - FxPoint2D

- (void)testFxPoint2DRoundTrips
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxPoint2D point = { 12.5, -3.25 };

	[archiver encodeFxPoint2D:point forKey:@"p"];
	FxPoint2D decoded = [FxCoderUnarchiver(archiver) decodeFxPoint2D:@"p"];

	XCTAssertEqual(decoded.x, 12.5);
	XCTAssertEqual(decoded.y, -3.25);
}

- (void)testFxPoint2DDecodesToZeroWhenTheKeyIsMissing
{
	FxPoint2D decoded = [FxCoderUnarchiver(FxCoderArchiver()) decodeFxPoint2D:@"absent"];

	XCTAssertEqual(decoded.x, 0.0);
	XCTAssertEqual(decoded.y, 0.0);
}

- (void)testFxPoint2DDecodesToZeroWhenTheStoredBlobIsADifferentSize
{
	NSKeyedArchiver *archiver = FxCoderArchiver();

	[archiver encodeFxPoint3D:(FxPoint3D){ 1.0, 2.0, 3.0 } forKey:@"p"];
	FxPoint2D decoded = [FxCoderUnarchiver(archiver) decodeFxPoint2D:@"p"];

	XCTAssertEqual(decoded.x, 0.0);
	XCTAssertEqual(decoded.y, 0.0);
}

#pragma mark - FxSize

- (void)testFxSizeRoundTrips
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxSize size = { 1920.0, 1080.0 };

	[archiver encodeFxSize:size forKey:@"s"];
	FxSize decoded = [FxCoderUnarchiver(archiver) decodeFxSize:@"s"];

	XCTAssertEqual(decoded.width, 1920.0);
	XCTAssertEqual(decoded.height, 1080.0);
}

- (void)testFxSizeDecodesToZeroWhenTheKeyIsMissing
{
	FxSize decoded = [FxCoderUnarchiver(FxCoderArchiver()) decodeFxSize:@"absent"];

	XCTAssertEqual(decoded.width, 0.0);
	XCTAssertEqual(decoded.height, 0.0);
}

- (void)testFxSizeDecodesToZeroWhenTheStoredBlobIsADifferentSize
{
	NSKeyedArchiver *archiver = FxCoderArchiver();

	[archiver encodeFxPoint3D:(FxPoint3D){ 1.0, 2.0, 3.0 } forKey:@"s"];
	FxSize decoded = [FxCoderUnarchiver(archiver) decodeFxSize:@"s"];

	XCTAssertEqual(decoded.width, 0.0);
	XCTAssertEqual(decoded.height, 0.0);
}

#pragma mark - FxPoint3D

- (void)testFxPoint3DRoundTrips
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxPoint3D point = { -1.5, 2.5, 3.75 };

	[archiver encodeFxPoint3D:point forKey:@"p3"];
	FxPoint3D decoded = [FxCoderUnarchiver(archiver) decodeFxPoint3D:@"p3"];

	XCTAssertEqual(decoded.x, -1.5);
	XCTAssertEqual(decoded.y, 2.5);
	XCTAssertEqual(decoded.z, 3.75);
}

- (void)testFxPoint3DDecodesToZeroWhenTheKeyIsMissing
{
	FxPoint3D decoded = [FxCoderUnarchiver(FxCoderArchiver()) decodeFxPoint3D:@"absent"];

	XCTAssertEqual(decoded.x, 0.0);
	XCTAssertEqual(decoded.y, 0.0);
	XCTAssertEqual(decoded.z, 0.0);
}

- (void)testFxPoint3DDecodesToZeroWhenTheStoredBlobIsADifferentSize
{
	NSKeyedArchiver *archiver = FxCoderArchiver();

	[archiver encodeFxPoint2D:(FxPoint2D){ 1.0, 2.0 } forKey:@"p3"];
	FxPoint3D decoded = [FxCoderUnarchiver(archiver) decodeFxPoint3D:@"p3"];

	XCTAssertEqual(decoded.x, 0.0);
	XCTAssertEqual(decoded.z, 0.0);
}

#pragma mark - FxRect

- (void)testFxRectRoundTrips
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxRect rect = { -10, -20, 30, 40 };

	[archiver encodeFxRect:rect forKey:@"r"];
	FxRect decoded = [FxCoderUnarchiver(archiver) decodeFxRect:@"r"];

	XCTAssertEqual(decoded.left, -10);
	XCTAssertEqual(decoded.bottom, -20);
	XCTAssertEqual(decoded.right, 30);
	XCTAssertEqual(decoded.top, 40);
}

- (void)testFxRectDecodesToZeroWhenTheKeyIsMissing
{
	FxRect decoded = [FxCoderUnarchiver(FxCoderArchiver()) decodeFxRect:@"absent"];

	XCTAssertEqual(decoded.left, 0);
	XCTAssertEqual(decoded.bottom, 0);
	XCTAssertEqual(decoded.right, 0);
	XCTAssertEqual(decoded.top, 0);
}

- (void)testFxRectDecodesToZeroWhenTheStoredBlobIsADifferentSize
{
	NSKeyedArchiver *archiver = FxCoderArchiver();

	[archiver encodeFxPoint3D:(FxPoint3D){ 1.0, 2.0, 3.0 } forKey:@"r"];
	FxRect decoded = [FxCoderUnarchiver(archiver) decodeFxRect:@"r"];

	XCTAssertEqual(decoded.left, 0);
	XCTAssertEqual(decoded.top, 0);
}

#pragma mark - Matrix44Data

- (void)testMatrix44DataRoundTrips
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	Matrix44Data matrix = {
		{  1.0,  2.0,  3.0,  4.0 },
		{  5.0,  6.0,  7.0,  8.0 },
		{  9.0, 10.0, 11.0, 12.0 },
		{ 13.0, 14.0, 15.0, 16.0 }
	};

	[archiver encodeMatrix44Data:&matrix forKey:@"m"];
	Matrix44Data *decoded = [FxCoderUnarchiver(archiver) decodeMatrix44Data:@"m"];

	XCTAssertTrue(decoded != NULL);
	XCTAssertEqual(memcmp(decoded, &matrix, sizeof(Matrix44Data)), 0);
}

- (void)testMatrix44DataDecodesToNullWhenTheKeyIsMissing
{
	XCTAssertTrue([FxCoderUnarchiver(FxCoderArchiver()) decodeMatrix44Data:@"absent"] == NULL);
}

- (void)testMatrix44DataDecodesToNullWhenTheStoredBlobIsADifferentSize
{
	NSKeyedArchiver *archiver = FxCoderArchiver();

	[archiver encodeFxPoint3D:(FxPoint3D){ 1.0, 2.0, 3.0 } forKey:@"m"];

	XCTAssertTrue([FxCoderUnarchiver(archiver) decodeMatrix44Data:@"m"] == NULL);
}

- (void)testEncodeFxMatrix44WritesTheObjectsRawMatrixData
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxCoderMatrixStub *stub = [FxCoderMatrixStub new];
	[stub fillStartingAt:7.0];

	[archiver encodeFxMatrix44:(FxMatrix44 *)stub forKey:@"m"];
	Matrix44Data *decoded = [FxCoderUnarchiver(archiver) decodeMatrix44Data:@"m"];

	XCTAssertTrue(decoded != NULL);
	XCTAssertEqual(memcmp(decoded, stub.matrix, sizeof(Matrix44Data)), 0);
}

/*!
	FxPlug.framework is weak-linked, so outside an FxPlug host FxMatrix44 resolves to Nil
	and the object-returning decoders answer nil for well-formed data. The value-returning
	-decodeMatrix44Data: is the usable path in that configuration.
*/
- (void)testFxMatrix44DecodersAreNilSafeWhenFxPlugIsNotLoaded
{
	if (NSClassFromString(@"FxMatrix44") != Nil) {
		XCTSkip(@"FxPlug is loaded; the object decoders resolve against the real class.");
	}
	NSKeyedArchiver *archiver = FxCoderArchiver();
	Matrix44Data matrix = { { 1.0 } };
	[archiver encodeMatrix44Data:&matrix forKey:@"m"];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertNil([unarchiver decodeFxMatrix44:@"m"]);
	XCTAssertNil([unarchiver decodeFxColorMatrix44:@"m"]);
	XCTAssertNil([unarchiver decodeFxMatrix44:@"absent"]);
	XCTAssertNil([unarchiver decodeFxColorMatrix44:@"absent"]);
}

#pragma mark - Fx3DAPI Capture

- (void)testEncodeFx3DAPIWritesEveryCameraValueUnderTheGivenKey
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxCoder3DMock *api = [FxCoder3DMock new];

	[archiver encodeFx3DAPI:api atTime:FxCoderTime(300, 600) forKey:@"K"];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeFx3DFocalLength:@"K"], 42.5);
	XCTAssertEqual([unarchiver decodeFx3DFrustumLeft:@"K"], -1.0);
	XCTAssertEqual([unarchiver decodeFx3DFrustumRight:@"K"], 1.0);
	XCTAssertEqual([unarchiver decodeFx3DFrustumBottom:@"K"], -2.0);
	XCTAssertEqual([unarchiver decodeFx3DFrustumTop:@"K"], 2.0);
	XCTAssertEqual([unarchiver decodeFx3DFrustumNear:@"K"], 0.5);
	XCTAssertEqual([unarchiver decodeFx3DFrustumFar:@"K"], 1000.0);

	XCTAssertEqual(memcmp([unarchiver decodeFx3DModelMatrixData:@"K"], api.model.matrix, sizeof(Matrix44Data)), 0);
	XCTAssertEqual(memcmp([unarchiver decodeFx3DViewMatrixData:@"K"], api.view.matrix, sizeof(Matrix44Data)), 0);
	XCTAssertEqual(memcmp([unarchiver decodeFx3DProjectionMatrixData:@"K"], api.projection.matrix, sizeof(Matrix44Data)), 0);
}

- (void)testEncodeFx3DAPIComposesKeysFromThePrefixAndTheDocumentedSuffixes
{
	NSKeyedArchiver *archiver = FxCoderArchiver();

	[archiver encodeFx3DAPI:[FxCoder3DMock new] atTime:FxCoderTime(0, 1) forKey:@"K"];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:Fx3DCoderModelMatrixKey]]);
	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:Fx3DCoderViewMatrixKey]]);
	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:Fx3DCoderProjectionMatrixKey]]);
	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:Fx3DCoderFocalLengthKey]]);
	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:Fx3DCoderFrustumLeftKey]]);
	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:Fx3DCoderFrustumFarKey]]);
}

- (void)testEncodeFx3DAPIWithoutAKeyWritesUnderTheCurrentTimeKey
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	archiver.renderTime = FxCoderTime(900, 600);

	[archiver encodeFx3DAPI:[FxCoder3DMock new]];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeFx3DFocalLength], 42.5);
	XCTAssertEqual([unarchiver decodeFx3DFrustumNear], 0.5);
	XCTAssertTrue([unarchiver decodeFx3DModelMatrixData] != NULL);
	XCTAssertTrue([unarchiver decodeFx3DViewMatrixData] != NULL);
	XCTAssertTrue([unarchiver decodeFx3DProjectionMatrixData] != NULL);
}

- (void)testEncodeFx3DAPIPassesTheRenderTimeToTheHostAPI
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	CMTime time = FxCoderTime(1234, 600);
	archiver.renderTime = time;
	FxCoder3DMock *api = [FxCoder3DMock new];

	[archiver encodeFx3DAPI:api];

	XCTAssertTrue(FxCoderTimesEqual(api.lastRequestedTime, time));
}

- (void)testEncodeFx3DAPIUnderTheCurrentTimeKeySkipsATimeOtherThanTheRenderTime
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	archiver.renderTime = FxCoderTime(100, 600);

	[archiver encodeFx3DAPI:[FxCoder3DMock new] atTime:FxCoderTime(200, 600) forKey:Fx3DCoderCurrentTimeKey];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertTrue([unarchiver decodeFx3DModelMatrixData] == NULL);
	XCTAssertEqual([unarchiver decodeFx3DFocalLength], 0.0);
}

/*!
	The value each accessor returns is written before its error is inspected, so a
	failure at step N leaves steps 0 through N in the archive and nothing after.
*/
- (void)testEncodeFx3DAPIStopsAfterTheAccessorThatReportsAnError
{
	NSArray<NSString *> *suffixes = @[
		Fx3DCoderModelMatrixKey,
		Fx3DCoderViewMatrixKey,
		Fx3DCoderProjectionMatrixKey,
		Fx3DCoderFocalLengthKey,
		Fx3DCoderFrustumLeftKey
	];

	for (NSUInteger failingStep = 0; failingStep < suffixes.count; failingStep++) {
		NSKeyedArchiver *archiver = FxCoderArchiver();
		FxCoder3DMock *api = [FxCoder3DMock new];
		api.failingStep = failingStep;

		[archiver encodeFx3DAPI:api atTime:FxCoderTime(0, 1) forKey:@"K"];
		NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

		for (NSUInteger step = 0; step < suffixes.count; step++) {
			BOOL written = [unarchiver containsValueForKey:[@"K" stringByAppendingString:suffixes[step]]];
			// The frustum writes nothing when it reports failure, unlike the accessors before it.
			BOOL expected = (step < failingStep) || (step == failingStep && failingStep < 4);
			XCTAssertEqual(written, expected, "step %lu with a failure at step %lu",
						   (unsigned long)step, (unsigned long)failingStep);
		}
	}
}

- (void)testEncodeFx3DAPIWritesNoFrustumWhenTheFrustumCallFails
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxCoder3DMock *api = [FxCoder3DMock new];
	api.frustumSucceeds = NO;

	[archiver encodeFx3DAPI:api atTime:FxCoderTime(0, 1) forKey:@"K"];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeFx3DFocalLength:@"K"], 42.5);
	XCTAssertFalse([unarchiver containsValueForKey:[@"K" stringByAppendingString:Fx3DCoderFrustumLeftKey]]);
	XCTAssertEqual([unarchiver decodeFx3DFrustumFar:@"K"], 0.0);
}

- (void)testFx3DDecodersReturnZeroAndNullForAnEmptyArchive
{
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(FxCoderArchiver());

	XCTAssertEqual([unarchiver decodeFx3DFocalLength], 0.0);
	XCTAssertEqual([unarchiver decodeFx3DFrustumLeft], 0.0);
	XCTAssertEqual([unarchiver decodeFx3DFrustumRight], 0.0);
	XCTAssertEqual([unarchiver decodeFx3DFrustumBottom], 0.0);
	XCTAssertEqual([unarchiver decodeFx3DFrustumTop], 0.0);
	XCTAssertEqual([unarchiver decodeFx3DFrustumNear], 0.0);
	XCTAssertEqual([unarchiver decodeFx3DFrustumFar], 0.0);
	XCTAssertTrue([unarchiver decodeFx3DModelMatrixData] == NULL);
	XCTAssertTrue([unarchiver decodeFx3DViewMatrixData] == NULL);
	XCTAssertTrue([unarchiver decodeFx3DProjectionMatrixData] == NULL);
	XCTAssertNil([unarchiver decodeFx3DModelMatrix]);
	XCTAssertNil([unarchiver decodeFx3DViewMatrix]);
	XCTAssertNil([unarchiver decodeFx3DProjectionMatrix]);
	XCTAssertNil([unarchiver decodeFx3DModelMatrix:@"K"]);
	XCTAssertNil([unarchiver decodeFx3DViewMatrix:@"K"]);
	XCTAssertNil([unarchiver decodeFx3DProjectionMatrix:@"K"]);
}

#pragma mark - FxLightingAPI Capture

- (void)testEncodeFxLightingAPIWritesTheLightCount
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxCoderLightingMock *api = [FxCoderLightingMock new];
	api.lightCount = 3;

	[archiver encodeFxLightingAPI:api atTime:FxCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeIntegerForKey:[@"L" stringByAppendingString:FxLightingCoderLightCountKey]], (NSInteger)3);
}

- (void)testEncodeFxLightingAPIWithoutAKeyWritesUnderTheCurrentTimeKey
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	archiver.renderTime = FxCoderTime(60, 30);
	FxCoderLightingMock *api = [FxCoderLightingMock new];
	api.lightCount = 2;

	[archiver encodeFxLightingAPI:api];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeIntegerForKey:[Fx3DCoderCurrentTimeKey stringByAppendingString:FxLightingCoderLightCountKey]], (NSInteger)2);
	XCTAssertTrue([unarchiver containsValueForKey:FxCoderLightKey(Fx3DCoderCurrentTimeKey, 0)]);
	XCTAssertTrue([unarchiver containsValueForKey:FxCoderLightKey(Fx3DCoderCurrentTimeKey, 1)]);
}

- (void)testEncodeFxLightingAPIUnderTheCurrentTimeKeySkipsATimeOtherThanTheRenderTime
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	archiver.renderTime = FxCoderTime(10, 30);
	FxCoderLightingMock *api = [FxCoderLightingMock new];
	api.lightCount = 4;

	[archiver encodeFxLightingAPI:api atTime:FxCoderTime(20, 30) forKey:Fx3DCoderCurrentTimeKey];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertFalse([unarchiver containsValueForKey:[Fx3DCoderCurrentTimeKey stringByAppendingString:FxLightingCoderLightCountKey]]);
	XCTAssertFalse([unarchiver containsValueForKey:FxCoderLightKey(Fx3DCoderCurrentTimeKey, 0)]);
	XCTAssertEqual([unarchiver decodeFxLightCount], 0L);
}

- (void)testEncodeFxLightingAPIWritesEachLightUnderItsIndexedKey
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxCoderLightingMock *api = [FxCoderLightingMock new];
	api.lightCount = 2;

	[archiver encodeFxLightingAPI:api atTime:FxCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	for (long index = 0; index < 2; index++) {
		NSUInteger length = 0;
		const FxLight *light = (const FxLight *)[unarchiver decodeBytesForKey:FxCoderLightKey(@"L", index) returnedLength:&length];

		XCTAssertEqual(length, sizeof(FxLight));
		XCTAssertTrue(light != NULL);
		XCTAssertEqual(light->version, (NSUInteger)kFxLight_V3);
		XCTAssertEqual(light->lightType, (FxLightType)kFxLightType_Point);
		XCTAssertEqual(light->intensity, 1.0f + (float)index);
		XCTAssertEqual(light->position.x, (CGFloat)index);
	}
}

- (void)testEncodeFxLightingAPISkipsALightWhoseInfoCallFails
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxCoderLightingMock *api = [FxCoderLightingMock new];
	api.lightCount = 3;
	api.failingLight = 1;

	[archiver encodeFxLightingAPI:api atTime:FxCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeIntegerForKey:[@"L" stringByAppendingString:FxLightingCoderLightCountKey]], (NSInteger)3);
	XCTAssertTrue([unarchiver containsValueForKey:FxCoderLightKey(@"L", 0)]);
	XCTAssertFalse([unarchiver containsValueForKey:FxCoderLightKey(@"L", 1)]);
	XCTAssertTrue([unarchiver containsValueForKey:FxCoderLightKey(@"L", 2)]);
}

- (void)testLightCountUsesTheDocumentedArchiveKey
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxCoderLightingMock *api = [FxCoderLightingMock new];
	api.lightCount = 5;

	[archiver encodeFxLightingAPI:api atTime:FxCoderTime(0, 1) forKey:@"L"];

	XCTAssertTrue([FxCoderUnarchiver(archiver) containsValueForKey:[@"L" stringByAppendingString:FxLightingCoderLightCountKey]]);
}

/*!
	FRAMEWORK DEFECT. -encodeFxLightingAPI:atTime:forKey: writes the count with
	-encodeInteger:forKey: while -decodeFxLightCount: reads it with
	-decodeDoubleForKey:. NSKeyedUnarchiver does not bridge the two representations,
	so the count always decodes as 0 and every light is reported out of range.
	NSCoder+FxPlug.m:177 and NSCoder+FxPlug.m:359.
*/
- (void)testDecodeFxLightCountReadsBackTheEncodedCount
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxCoderLightingMock *api = [FxCoderLightingMock new];
	api.lightCount = 3;

	[archiver encodeFxLightingAPI:api atTime:FxCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeIntegerForKey:[@"L" stringByAppendingString:FxLightingCoderLightCountKey]], (NSInteger)3,
				   "precondition: the count is in the archive");
	XCTAssertEqual([unarchiver decodeFxLightCount:@"L"], 3L);
}

- (void)testLightCountIsZeroForAnEmptyArchive
{
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(FxCoderArchiver());

	XCTAssertEqual([unarchiver decodeFxLightCount], 0L);
	XCTAssertEqual([unarchiver decodeFxLightCount:@"L"], 0L);
}

- (void)testDecodeFxLightRejectsAnIndexOutsideTheStoredCount
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxCoderLightingMock *api = [FxCoderLightingMock new];
	api.lightCount = 2;

	[archiver encodeFxLightingAPI:api atTime:FxCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	XCTAssertTrue([unarchiver decodeFxLight:-1 forKey:@"L"] == NULL);
	XCTAssertTrue([unarchiver decodeFxLight:2 forKey:@"L"] == NULL);
	XCTAssertTrue([unarchiver decodeFxLight:99 forKey:@"L"] == NULL);
	XCTAssertTrue([unarchiver decodeFxLight:0] == NULL);	// nothing under the current-time key
}

- (void)testDecodeFxLightIntoAStructReportsFailureForAnIndexOutsideTheStoredCount
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxCoderLightingMock *api = [FxCoderLightingMock new];
	api.lightCount = 1;

	[archiver encodeFxLightingAPI:api atTime:FxCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	FxLight light;
	memset(&light, 0, sizeof(light));

	XCTAssertFalse([unarchiver decodeFxLight:&light forKey:@"L" index:5]);
	XCTAssertFalse([unarchiver decodeFxLight:&light index:0]);
}

/*!
	FRAMEWORK DEFECT. -encodeFxLightingAPI:atTime:forKey: writes each light under
	`<key><index>` + FxLightingCoderLightingKey, but -decodeFxLight:forKey: reads
	`<key>` itself and ignores the index, so a light that was encoded can never be
	read back. NSCoder+FxPlug.m:376. The count defect above blocks this path as
	well; both have to be fixed for a light to survive the round trip.
*/
- (void)testDecodeFxLightReadsBackALightThatWasEncoded
{
	NSKeyedArchiver *archiver = FxCoderArchiver();
	FxCoderLightingMock *api = [FxCoderLightingMock new];
	api.lightCount = 2;

	[archiver encodeFxLightingAPI:api atTime:FxCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxCoderUnarchiver(archiver);

	const FxLight *first = [unarchiver decodeFxLight:0 forKey:@"L"];

	XCTAssertTrue(first != NULL, "a light encoded at index 0 must decode at index 0");
	if (first != NULL) {
		XCTAssertEqual(first->intensity, 1.0f);
	}

	FxLight second;
	memset(&second, 0, sizeof(second));
	XCTAssertTrue([unarchiver decodeFxLight:&second forKey:@"L" index:1]);
}

#pragma mark - Matrix Conversion

- (void)testFloatMatrixCopiesEveryElementOfTheDoubleMatrix
{
	Matrix44Data source = {
		{  1.5,  2.5,  3.5,  4.5 },
		{  5.5,  6.5,  7.5,  8.5 },
		{  9.5, 10.5, 11.5, 12.5 },
		{ 13.5, 14.5, 15.5, 16.5 }
	};
	matrix_float4x4 destination;
	memset(&destination, 0, sizeof(destination));

	[NSCoder floatMatrix:&destination fromDoubleMatrix:&source];

	const double *flatSource = (const double *)&source;
	const float *flatDestination = (const float *)&destination;
	for (int i = 0; i < 16; i++) {
		XCTAssertEqual(flatDestination[i], (float)flatSource[i]);
	}
}

- (void)testFloatMatrixPreservesTheIdentityMatrix
{
	Matrix44Data source = {
		{ 1.0, 0.0, 0.0, 0.0 },
		{ 0.0, 1.0, 0.0, 0.0 },
		{ 0.0, 0.0, 1.0, 0.0 },
		{ 0.0, 0.0, 0.0, 1.0 }
	};
	matrix_float4x4 destination;
	memset(&destination, 0, sizeof(destination));

	[NSCoder floatMatrix:&destination fromDoubleMatrix:&source];

	for (int column = 0; column < 4; column++) {
		for (int row = 0; row < 4; row++) {
			XCTAssertEqual(destination.columns[column][row], column == row ? 1.0f : 0.0f);
		}
	}
}

@end
