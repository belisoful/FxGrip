/*!
	@file       NSCoderFxPlugTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     NSCoderFxPlugTests
	@abstract   Verifies the NSCoder (FxPlug) category that archives FxPlug value types and host-API captures.
	@discussion Introduced in FxGrip 0.1.0. The tests round-trip the FxPlug geometry structs and the matrix blob through NSKeyedArchiver, and they capture Fx3DAPI and FxLightingAPI mocks into an archive to check the composed keys and the accessor-failure stop points. FxPlug.framework is weak-linked and absent outside a host, so stubs and mocks stand in for the SDK types.
*/

#import <XCTest/XCTest.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/NSCoder+FxPlug.h"

// Defined in NSCoder+FxPlug.m and exported by the framework, but not declared in the
// public header. The lighting wire format is pinned through them.
extern NSString * const FxGripLightingCoderLightCountKey;
extern NSString * const FxGripLightingCoderLightingKey;

#pragma mark - Stubs

/*!
	Stands in for FxMatrix44 in the encode direction. -encodeFxMatrix44: only sends
	-matrix, so any object answering that selector drives the encoder. FxPlug.framework
	is weak-linked and absent outside a host, so FxMatrix44 itself cannot be instantiated.
*/
@interface FxGripCoderMatrixStub : NSObject
{
	Matrix44Data _data;
}
- (Matrix44Data *)matrix;
- (void)fillStartingAt:(double)start;
@end

@implementation FxGripCoderMatrixStub

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


@interface FxGripCoder3DMock : NSObject <Fx3DAPI_v5>
@property (nonatomic, strong) FxGripCoderMatrixStub *model;
@property (nonatomic, strong) FxGripCoderMatrixStub *view;
@property (nonatomic, strong) FxGripCoderMatrixStub *projection;
@property (nonatomic) double focalLength;
@property (nonatomic) BOOL frustumSucceeds;
// Index of the accessor that reports an error: 0 model, 1 view, 2 projection,
// 3 focal length, 4 frustum. NSNotFound means every accessor succeeds.
@property (nonatomic) NSUInteger failingStep;
@property (nonatomic) CMTime lastRequestedTime;
@end

@implementation FxGripCoder3DMock

- (instancetype)init
{
	self = [super init];
	if (self) {
		_model = [FxGripCoderMatrixStub new];
		[_model fillStartingAt:100.0];
		_view = [FxGripCoderMatrixStub new];
		[_view fillStartingAt:200.0];
		_projection = [FxGripCoderMatrixStub new];
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
		*error = [NSError errorWithDomain:@"FxGripCoderTest" code:(NSInteger)step userInfo:nil];
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


@interface FxGripCoderLightingMock : NSObject <FxLightingAPI_v3>
@property (nonatomic) NSUInteger lightCount;
// Index whose -lightInfo: call fails; NSNotFound means every light reports.
@property (nonatomic) NSUInteger failingLight;
@end

@implementation FxGripCoderLightingMock

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
			*error = [NSError errorWithDomain:@"FxGripCoderTest" code:(NSInteger)lightIndex userInfo:nil];
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

static NSKeyedArchiver *FxGripCoderArchiver(void)
{
	return [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
}

static NSKeyedUnarchiver *FxGripCoderUnarchiver(NSKeyedArchiver *archiver)
{
	[archiver finishEncoding];
	NSError *error = nil;
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:&error];
	unarchiver.requiresSecureCoding = NO;
	return unarchiver;
}

// A valid, non-zero CMTime built without linking CoreMedia: kCMTimeZero and
// CMTimeMake are external, the flag constants are compile-time enumerators.
static CMTime FxGripCoderTime(int64_t value, int32_t timescale)
{
	CMTime time;
	time.value = value;
	time.timescale = timescale;
	time.flags = kCMTimeFlags_Valid;
	time.epoch = 0;
	return time;
}

static BOOL FxGripCoderTimesEqual(CMTime a, CMTime b)
{
	return a.value == b.value && a.timescale == b.timescale && a.flags == b.flags && a.epoch == b.epoch;
}

// The archive key -encodeFxLightingAPI:atTime:forKey: writes one light under.
static NSString *FxGripCoderLightKey(NSString *prefix, long index)
{
	return [prefix stringByAppendingFormat:@"%ld%@", index, FxGripLightingCoderLightingKey];
}

#pragma mark - Render Time

/*! @abstract A coder with no assigned render time reports an invalid, zero-timescale CMTime. */
- (void)testRenderTimeIsInvalidBeforeItIsAssigned
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	CMTime time = archiver.renderTime;

	XCTAssertEqual(time.flags & kCMTimeFlags_Valid, 0);
	XCTAssertEqual(time.timescale, 0);
}

/*! @abstract An assigned render time reads back with every CMTime field intact. */
- (void)testRenderTimeRoundTripsThroughTheAssociatedObject
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	CMTime time = FxGripCoderTime(1500, 600);

	archiver.renderTime = time;

	XCTAssertTrue(FxGripCoderTimesEqual(archiver.renderTime, time));
}

/*! @abstract Assigning a render time to one coder leaves another coder's render time unassigned. */
- (void)testRenderTimeIsIndependentPerCoder
{
	NSKeyedArchiver *first = FxGripCoderArchiver();
	NSKeyedArchiver *second = FxGripCoderArchiver();

	first.renderTime = FxGripCoderTime(10, 30);

	XCTAssertEqual(second.renderTime.timescale, 0);
	XCTAssertEqual(first.renderTime.timescale, 30);
}

/*! @abstract isFxPluginStateEncoder is NO until a render time is assigned and YES afterward. */
- (void)testIsFxPluginStateEncoderTracksWhetherARenderTimeWasAssigned
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();

	XCTAssertFalse(archiver.isFxPluginStateEncoder);

	archiver.renderTime = FxGripCoderTime(0, 1);

	XCTAssertTrue(archiver.isFxPluginStateEncoder);
}

#pragma mark - Quality Level

/*! @abstract A decoder with no stored quality level reports kFxQuality_HIGH. */
- (void)testQualityLevelDefaultsToHighWhenTheKeyIsAbsent
{
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(FxGripCoderArchiver());

	XCTAssertEqual(unarchiver.qualityLevel, (FxQuality)kFxQuality_HIGH);
}

/*! @abstract Each of the low, medium, and high quality levels reads back unchanged. */
- (void)testQualityLevelRoundTripsForEveryLevel
{
	FxQuality levels[3] = { kFxQuality_LOW, kFxQuality_MEDIUM, kFxQuality_HIGH };

	for (int i = 0; i < 3; i++) {
		NSKeyedArchiver *archiver = FxGripCoderArchiver();
		archiver.qualityLevel = levels[i];

		NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

		XCTAssertEqual(unarchiver.qualityLevel, levels[i]);
	}
}

/*! @abstract The quality level is stored as an int64 under kFxPlugCoderQualityLevelKey. */
- (void)testQualityLevelUsesTheDocumentedArchiveKey
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	archiver.qualityLevel = kFxQuality_MEDIUM;

	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	XCTAssertTrue([unarchiver containsValueForKey:kFxPlugCoderQualityLevelKey]);
	XCTAssertEqual([unarchiver decodeInt64ForKey:kFxPlugCoderQualityLevelKey], (int64_t)kFxQuality_MEDIUM);
}

#pragma mark - FxPoint2D

/*! @abstract An encoded FxPoint2D reads back with its x and y preserved. */
- (void)testFxPoint2DRoundTrips
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxPoint2D point = { 12.5, -3.25 };

	[archiver encodeFxPoint2D:point forKey:@"p"];
	FxPoint2D decoded = [FxGripCoderUnarchiver(archiver) decodeFxPoint2D:@"p"];

	XCTAssertEqual(decoded.x, 12.5);
	XCTAssertEqual(decoded.y, -3.25);
}

/*! @abstract Decoding an FxPoint2D from an absent key yields a zero point. */
- (void)testFxPoint2DDecodesToZeroWhenTheKeyIsMissing
{
	FxPoint2D decoded = [FxGripCoderUnarchiver(FxGripCoderArchiver()) decodeFxPoint2D:@"absent"];

	XCTAssertEqual(decoded.x, 0.0);
	XCTAssertEqual(decoded.y, 0.0);
}

/*! @abstract Decoding an FxPoint2D from a blob of a different size yields a zero point. */
- (void)testFxPoint2DDecodesToZeroWhenTheStoredBlobIsADifferentSize
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();

	[archiver encodeFxPoint3D:(FxPoint3D){ 1.0, 2.0, 3.0 } forKey:@"p"];
	FxPoint2D decoded = [FxGripCoderUnarchiver(archiver) decodeFxPoint2D:@"p"];

	XCTAssertEqual(decoded.x, 0.0);
	XCTAssertEqual(decoded.y, 0.0);
}

#pragma mark - FxSize

/*! @abstract An encoded FxSize reads back with its width and height preserved. */
- (void)testFxSizeRoundTrips
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxSize size = { 1920.0, 1080.0 };

	[archiver encodeFxSize:size forKey:@"s"];
	FxSize decoded = [FxGripCoderUnarchiver(archiver) decodeFxSize:@"s"];

	XCTAssertEqual(decoded.width, 1920.0);
	XCTAssertEqual(decoded.height, 1080.0);
}

/*! @abstract Decoding an FxSize from an absent key yields a zero size. */
- (void)testFxSizeDecodesToZeroWhenTheKeyIsMissing
{
	FxSize decoded = [FxGripCoderUnarchiver(FxGripCoderArchiver()) decodeFxSize:@"absent"];

	XCTAssertEqual(decoded.width, 0.0);
	XCTAssertEqual(decoded.height, 0.0);
}

/*! @abstract Decoding an FxSize from a blob of a different size yields a zero size. */
- (void)testFxSizeDecodesToZeroWhenTheStoredBlobIsADifferentSize
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();

	[archiver encodeFxPoint3D:(FxPoint3D){ 1.0, 2.0, 3.0 } forKey:@"s"];
	FxSize decoded = [FxGripCoderUnarchiver(archiver) decodeFxSize:@"s"];

	XCTAssertEqual(decoded.width, 0.0);
	XCTAssertEqual(decoded.height, 0.0);
}

#pragma mark - FxPoint3D

/*! @abstract An encoded FxPoint3D reads back with its x, y, and z preserved. */
- (void)testFxPoint3DRoundTrips
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxPoint3D point = { -1.5, 2.5, 3.75 };

	[archiver encodeFxPoint3D:point forKey:@"p3"];
	FxPoint3D decoded = [FxGripCoderUnarchiver(archiver) decodeFxPoint3D:@"p3"];

	XCTAssertEqual(decoded.x, -1.5);
	XCTAssertEqual(decoded.y, 2.5);
	XCTAssertEqual(decoded.z, 3.75);
}

/*! @abstract Decoding an FxPoint3D from an absent key yields a zero point. */
- (void)testFxPoint3DDecodesToZeroWhenTheKeyIsMissing
{
	FxPoint3D decoded = [FxGripCoderUnarchiver(FxGripCoderArchiver()) decodeFxPoint3D:@"absent"];

	XCTAssertEqual(decoded.x, 0.0);
	XCTAssertEqual(decoded.y, 0.0);
	XCTAssertEqual(decoded.z, 0.0);
}

/*! @abstract Decoding an FxPoint3D from a blob of a different size yields a zero point. */
- (void)testFxPoint3DDecodesToZeroWhenTheStoredBlobIsADifferentSize
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();

	[archiver encodeFxPoint2D:(FxPoint2D){ 1.0, 2.0 } forKey:@"p3"];
	FxPoint3D decoded = [FxGripCoderUnarchiver(archiver) decodeFxPoint3D:@"p3"];

	XCTAssertEqual(decoded.x, 0.0);
	XCTAssertEqual(decoded.z, 0.0);
}

#pragma mark - FxRect

/*! @abstract An encoded FxRect reads back with its four edges preserved. */
- (void)testFxRectRoundTrips
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxRect rect = { -10, -20, 30, 40 };

	[archiver encodeFxRect:rect forKey:@"r"];
	FxRect decoded = [FxGripCoderUnarchiver(archiver) decodeFxRect:@"r"];

	XCTAssertEqual(decoded.left, -10);
	XCTAssertEqual(decoded.bottom, -20);
	XCTAssertEqual(decoded.right, 30);
	XCTAssertEqual(decoded.top, 40);
}

/*! @abstract Decoding an FxRect from an absent key yields a zero rect. */
- (void)testFxRectDecodesToZeroWhenTheKeyIsMissing
{
	FxRect decoded = [FxGripCoderUnarchiver(FxGripCoderArchiver()) decodeFxRect:@"absent"];

	XCTAssertEqual(decoded.left, 0);
	XCTAssertEqual(decoded.bottom, 0);
	XCTAssertEqual(decoded.right, 0);
	XCTAssertEqual(decoded.top, 0);
}

/*! @abstract Decoding an FxRect from a blob of a different size yields a zero rect. */
- (void)testFxRectDecodesToZeroWhenTheStoredBlobIsADifferentSize
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();

	[archiver encodeFxPoint3D:(FxPoint3D){ 1.0, 2.0, 3.0 } forKey:@"r"];
	FxRect decoded = [FxGripCoderUnarchiver(archiver) decodeFxRect:@"r"];

	XCTAssertEqual(decoded.left, 0);
	XCTAssertEqual(decoded.top, 0);
}

#pragma mark - Matrix44Data

/*! @abstract An encoded Matrix44Data reads back byte-identical to the original. */
- (void)testMatrix44DataRoundTrips
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	Matrix44Data matrix = {
		{  1.0,  2.0,  3.0,  4.0 },
		{  5.0,  6.0,  7.0,  8.0 },
		{  9.0, 10.0, 11.0, 12.0 },
		{ 13.0, 14.0, 15.0, 16.0 }
	};

	[archiver encodeMatrix44Data:&matrix forKey:@"m"];
	Matrix44Data *decoded = [FxGripCoderUnarchiver(archiver) decodeMatrix44Data:@"m"];

	XCTAssertTrue(decoded != NULL);
	XCTAssertEqual(memcmp(decoded, &matrix, sizeof(Matrix44Data)), 0);
}

/*! @abstract Decoding a Matrix44Data from an absent key yields NULL. */
- (void)testMatrix44DataDecodesToNullWhenTheKeyIsMissing
{
	XCTAssertTrue([FxGripCoderUnarchiver(FxGripCoderArchiver()) decodeMatrix44Data:@"absent"] == NULL);
}

/*! @abstract Decoding a Matrix44Data from a blob of a different size yields NULL. */
- (void)testMatrix44DataDecodesToNullWhenTheStoredBlobIsADifferentSize
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();

	[archiver encodeFxPoint3D:(FxPoint3D){ 1.0, 2.0, 3.0 } forKey:@"m"];

	XCTAssertTrue([FxGripCoderUnarchiver(archiver) decodeMatrix44Data:@"m"] == NULL);
}

/*! @abstract encodeFxMatrix44: writes the object's raw matrix data, which decodes byte-identical. */
- (void)testEncodeFxMatrix44WritesTheObjectsRawMatrixData
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxGripCoderMatrixStub *stub = [FxGripCoderMatrixStub new];
	[stub fillStartingAt:7.0];

	[archiver encodeFxMatrix44:(FxMatrix44 *)stub forKey:@"m"];
	Matrix44Data *decoded = [FxGripCoderUnarchiver(archiver) decodeMatrix44Data:@"m"];

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
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	Matrix44Data matrix = { { 1.0 } };
	[archiver encodeMatrix44Data:&matrix forKey:@"m"];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	XCTAssertNil([unarchiver decodeFxMatrix44:@"m"]);
	XCTAssertNil([unarchiver decodeFxColorMatrix44:@"m"]);
	XCTAssertNil([unarchiver decodeFxMatrix44:@"absent"]);
	XCTAssertNil([unarchiver decodeFxColorMatrix44:@"absent"]);
}

#pragma mark - Fx3DAPI Capture

/*! @abstract encodeFx3DAPI:atTime:forKey: writes the focal length, frustum edges, and model, view, and projection matrices under the given key. */
- (void)testEncodeFx3DAPIWritesEveryCameraValueUnderTheGivenKey
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxGripCoder3DMock *api = [FxGripCoder3DMock new];

	[archiver encodeFx3DAPI:api atTime:FxGripCoderTime(300, 600) forKey:@"K"];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

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

/*! @abstract encodeFx3DAPI:atTime:forKey: composes each archive key from the prefix and the documented suffix. */
- (void)testEncodeFx3DAPIComposesKeysFromThePrefixAndTheDocumentedSuffixes
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();

	[archiver encodeFx3DAPI:[FxGripCoder3DMock new] atTime:FxGripCoderTime(0, 1) forKey:@"K"];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:FxGrip3DCoderModelMatrixKey]]);
	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:FxGrip3DCoderViewMatrixKey]]);
	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:FxGrip3DCoderProjectionMatrixKey]]);
	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:FxGrip3DCoderFocalLengthKey]]);
	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:FxGrip3DCoderFrustumLeftKey]]);
	XCTAssertTrue([unarchiver containsValueForKey:[@"K" stringByAppendingString:FxGrip3DCoderFrustumFarKey]]);
}

/*! @abstract encodeFx3DAPI: with no key writes under the current-time key, which the keyless decoders read back. */
- (void)testEncodeFx3DAPIWithoutAKeyWritesUnderTheCurrentTimeKey
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	archiver.renderTime = FxGripCoderTime(900, 600);

	[archiver encodeFx3DAPI:[FxGripCoder3DMock new]];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeFx3DFocalLength], 42.5);
	XCTAssertEqual([unarchiver decodeFx3DFrustumNear], 0.5);
	XCTAssertTrue([unarchiver decodeFx3DModelMatrixData] != NULL);
	XCTAssertTrue([unarchiver decodeFx3DViewMatrixData] != NULL);
	XCTAssertTrue([unarchiver decodeFx3DProjectionMatrixData] != NULL);
}

/*! @abstract encodeFx3DAPI: queries the host API at the coder's render time. */
- (void)testEncodeFx3DAPIPassesTheRenderTimeToTheHostAPI
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	CMTime time = FxGripCoderTime(1234, 600);
	archiver.renderTime = time;
	FxGripCoder3DMock *api = [FxGripCoder3DMock new];

	[archiver encodeFx3DAPI:api];

	XCTAssertTrue(FxGripCoderTimesEqual(api.lastRequestedTime, time));
}

/*! @abstract encodeFx3DAPI:atTime:forKey: under the current-time key writes nothing when the time differs from the render time. */
- (void)testEncodeFx3DAPIUnderTheCurrentTimeKeySkipsATimeOtherThanTheRenderTime
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	archiver.renderTime = FxGripCoderTime(100, 600);

	[archiver encodeFx3DAPI:[FxGripCoder3DMock new] atTime:FxGripCoderTime(200, 600) forKey:FxGrip3DCoderCurrentTimeKey];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

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
		FxGrip3DCoderModelMatrixKey,
		FxGrip3DCoderViewMatrixKey,
		FxGrip3DCoderProjectionMatrixKey,
		FxGrip3DCoderFocalLengthKey,
		FxGrip3DCoderFrustumLeftKey
	];

	for (NSUInteger failingStep = 0; failingStep < suffixes.count; failingStep++) {
		NSKeyedArchiver *archiver = FxGripCoderArchiver();
		FxGripCoder3DMock *api = [FxGripCoder3DMock new];
		api.failingStep = failingStep;

		[archiver encodeFx3DAPI:api atTime:FxGripCoderTime(0, 1) forKey:@"K"];
		NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

		for (NSUInteger step = 0; step < suffixes.count; step++) {
			BOOL written = [unarchiver containsValueForKey:[@"K" stringByAppendingString:suffixes[step]]];
			// The frustum writes nothing when it reports failure, unlike the accessors before it.
			BOOL expected = (step < failingStep) || (step == failingStep && failingStep < 4);
			XCTAssertEqual(written, expected, "step %lu with a failure at step %lu",
						   (unsigned long)step, (unsigned long)failingStep);
		}
	}
}

/*! @abstract encodeFx3DAPI:atTime:forKey: writes no frustum values when the frustum call fails, keeping the values captured before it. */
- (void)testEncodeFx3DAPIWritesNoFrustumWhenTheFrustumCallFails
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxGripCoder3DMock *api = [FxGripCoder3DMock new];
	api.frustumSucceeds = NO;

	[archiver encodeFx3DAPI:api atTime:FxGripCoderTime(0, 1) forKey:@"K"];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeFx3DFocalLength:@"K"], 42.5);
	XCTAssertFalse([unarchiver containsValueForKey:[@"K" stringByAppendingString:FxGrip3DCoderFrustumLeftKey]]);
	XCTAssertEqual([unarchiver decodeFx3DFrustumFar:@"K"], 0.0);
}

/*! @abstract The Fx3D decoders return zero scalars, NULL matrix data, and nil matrix objects for an empty archive. */
- (void)testFx3DDecodersReturnZeroAndNullForAnEmptyArchive
{
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(FxGripCoderArchiver());

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

/*! @abstract encodeFxLightingAPI:atTime:forKey: writes the light count under the composed key. */
- (void)testEncodeFxLightingAPIWritesTheLightCount
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxGripCoderLightingMock *api = [FxGripCoderLightingMock new];
	api.lightCount = 3;

	[archiver encodeFxLightingAPI:api atTime:FxGripCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeIntegerForKey:[@"L" stringByAppendingString:FxGripLightingCoderLightCountKey]], (NSInteger)3);
}

/*! @abstract encodeFxLightingAPI: with no key writes the count and each light under the current-time key. */
- (void)testEncodeFxLightingAPIWithoutAKeyWritesUnderTheCurrentTimeKey
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	archiver.renderTime = FxGripCoderTime(60, 30);
	FxGripCoderLightingMock *api = [FxGripCoderLightingMock new];
	api.lightCount = 2;

	[archiver encodeFxLightingAPI:api];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeIntegerForKey:[FxGrip3DCoderCurrentTimeKey stringByAppendingString:FxGripLightingCoderLightCountKey]], (NSInteger)2);
	XCTAssertTrue([unarchiver containsValueForKey:FxGripCoderLightKey(FxGrip3DCoderCurrentTimeKey, 0)]);
	XCTAssertTrue([unarchiver containsValueForKey:FxGripCoderLightKey(FxGrip3DCoderCurrentTimeKey, 1)]);
}

/*! @abstract encodeFxLightingAPI:atTime:forKey: under the current-time key writes nothing when the time differs from the render time. */
- (void)testEncodeFxLightingAPIUnderTheCurrentTimeKeySkipsATimeOtherThanTheRenderTime
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	archiver.renderTime = FxGripCoderTime(10, 30);
	FxGripCoderLightingMock *api = [FxGripCoderLightingMock new];
	api.lightCount = 4;

	[archiver encodeFxLightingAPI:api atTime:FxGripCoderTime(20, 30) forKey:FxGrip3DCoderCurrentTimeKey];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	XCTAssertFalse([unarchiver containsValueForKey:[FxGrip3DCoderCurrentTimeKey stringByAppendingString:FxGripLightingCoderLightCountKey]]);
	XCTAssertFalse([unarchiver containsValueForKey:FxGripCoderLightKey(FxGrip3DCoderCurrentTimeKey, 0)]);
	XCTAssertEqual([unarchiver decodeFxLightCount], 0L);
}

/*! @abstract encodeFxLightingAPI:atTime:forKey: writes each FxLight struct under its indexed key with the version, type, intensity, and position preserved. */
- (void)testEncodeFxLightingAPIWritesEachLightUnderItsIndexedKey
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxGripCoderLightingMock *api = [FxGripCoderLightingMock new];
	api.lightCount = 2;

	[archiver encodeFxLightingAPI:api atTime:FxGripCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	for (long index = 0; index < 2; index++) {
		NSUInteger length = 0;
		const FxLight *light = (const FxLight *)[unarchiver decodeBytesForKey:FxGripCoderLightKey(@"L", index) returnedLength:&length];

		XCTAssertEqual(length, sizeof(FxLight));
		XCTAssertTrue(light != NULL);
		XCTAssertEqual(light->version, (NSUInteger)kFxLight_V3);
		XCTAssertEqual(light->lightType, (FxLightType)kFxLightType_Point);
		XCTAssertEqual(light->intensity, 1.0f + (float)index);
		XCTAssertEqual(light->position.x, (CGFloat)index);
	}
}

/*! @abstract encodeFxLightingAPI:atTime:forKey: skips a light whose info call fails while writing the lights before and after it. */
- (void)testEncodeFxLightingAPISkipsALightWhoseInfoCallFails
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxGripCoderLightingMock *api = [FxGripCoderLightingMock new];
	api.lightCount = 3;
	api.failingLight = 1;

	[archiver encodeFxLightingAPI:api atTime:FxGripCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeIntegerForKey:[@"L" stringByAppendingString:FxGripLightingCoderLightCountKey]], (NSInteger)3);
	XCTAssertTrue([unarchiver containsValueForKey:FxGripCoderLightKey(@"L", 0)]);
	XCTAssertFalse([unarchiver containsValueForKey:FxGripCoderLightKey(@"L", 1)]);
	XCTAssertTrue([unarchiver containsValueForKey:FxGripCoderLightKey(@"L", 2)]);
}

/*! @abstract The light count is stored under the composed light-count archive key. */
- (void)testLightCountUsesTheDocumentedArchiveKey
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxGripCoderLightingMock *api = [FxGripCoderLightingMock new];
	api.lightCount = 5;

	[archiver encodeFxLightingAPI:api atTime:FxGripCoderTime(0, 1) forKey:@"L"];

	XCTAssertTrue([FxGripCoderUnarchiver(archiver) containsValueForKey:[@"L" stringByAppendingString:FxGripLightingCoderLightCountKey]]);
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
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxGripCoderLightingMock *api = [FxGripCoderLightingMock new];
	api.lightCount = 3;

	[archiver encodeFxLightingAPI:api atTime:FxGripCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	XCTAssertEqual([unarchiver decodeIntegerForKey:[@"L" stringByAppendingString:FxGripLightingCoderLightCountKey]], (NSInteger)3,
				   "precondition: the count is in the archive");
	XCTAssertEqual([unarchiver decodeFxLightCount:@"L"], 3L);
}

/*! @abstract decodeFxLightCount reads zero from an empty archive, with and without a key. */
- (void)testLightCountIsZeroForAnEmptyArchive
{
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(FxGripCoderArchiver());

	XCTAssertEqual([unarchiver decodeFxLightCount], 0L);
	XCTAssertEqual([unarchiver decodeFxLightCount:@"L"], 0L);
}

/*! @abstract decodeFxLight:forKey: returns NULL for a negative index, an index at the count, and an index beyond it. */
- (void)testDecodeFxLightRejectsAnIndexOutsideTheStoredCount
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxGripCoderLightingMock *api = [FxGripCoderLightingMock new];
	api.lightCount = 2;

	[archiver encodeFxLightingAPI:api atTime:FxGripCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	XCTAssertTrue([unarchiver decodeFxLight:-1 forKey:@"L"] == NULL);
	XCTAssertTrue([unarchiver decodeFxLight:2 forKey:@"L"] == NULL);
	XCTAssertTrue([unarchiver decodeFxLight:99 forKey:@"L"] == NULL);
	XCTAssertTrue([unarchiver decodeFxLight:0] == NULL);	// nothing under the current-time key
}

/*! @abstract The struct-filling decodeFxLight variants report failure for an index outside the stored count. */
- (void)testDecodeFxLightIntoAStructReportsFailureForAnIndexOutsideTheStoredCount
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxGripCoderLightingMock *api = [FxGripCoderLightingMock new];
	api.lightCount = 1;

	[archiver encodeFxLightingAPI:api atTime:FxGripCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

	FxLight light;
	memset(&light, 0, sizeof(light));

	XCTAssertFalse([unarchiver decodeFxLight:&light forKey:@"L" index:5]);
	XCTAssertFalse([unarchiver decodeFxLight:&light index:0]);
}

/*!
	FRAMEWORK DEFECT. -encodeFxLightingAPI:atTime:forKey: writes each light under
	`<key><index>` + FxGripLightingCoderLightingKey, but -decodeFxLight:forKey: reads
	`<key>` itself and ignores the index, so a light that was encoded can never be
	read back. NSCoder+FxPlug.m:376. The count defect above blocks this path as
	well; both have to be fixed for a light to survive the round trip.
*/
- (void)testDecodeFxLightReadsBackALightThatWasEncoded
{
	NSKeyedArchiver *archiver = FxGripCoderArchiver();
	FxGripCoderLightingMock *api = [FxGripCoderLightingMock new];
	api.lightCount = 2;

	[archiver encodeFxLightingAPI:api atTime:FxGripCoderTime(0, 1) forKey:@"L"];
	NSKeyedUnarchiver *unarchiver = FxGripCoderUnarchiver(archiver);

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

/*! @abstract floatMatrix:fromDoubleMatrix: copies every element of the double matrix as its float value. */
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

/*! @abstract floatMatrix:fromDoubleMatrix: preserves the identity matrix. */
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
