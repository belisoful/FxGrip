//
//  FxGripTileableEffectRenderPathTests.m
//  FxGripTests
//
//  Unit tests for FxGripTileableEffect's host render-path entry points: the
//  plist-seeded parameters configuration, the destination-image-rect and
//  source-tile-rect defaults and their forwarding to the subclass pluginCoder:
//  variants, and the scheduleInputs dispatch.
//
//  Every effect is an instance of a local subclass returning a private
//  NSPriorityNotificationCenter, the FxGripTileableEffectCategoriesTests
//  convention, so no test touches the process-wide center. FxImageTile and
//  FxMatrix44 are stood in for by local stubs implementing exactly the messages
//  the base sends (imagePixelBounds, pixelTransform, inversePixelTransform,
//  transform2DPoint:), cast to the FxPlug pointer types.
//

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripTileableEffect.h>

static NSString *FxGripRenderPathExpectedErrorDomain(void)
{
	NSString * __unsafe_unretained *domain = (NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT, "FxPlugErrorDomain");
	return domain ? *domain : FxGripPlugErrorDomainConstant;
}

static CMTime FxGripRenderPathTime(int64_t value, int32_t timescale)
{
	return (CMTime){.value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

/*! Keyed-archive bytes for the host's pluginState argument. */
static NSData *FxGripRenderPathState(void)
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
	[archiver encodeObject:@"probe" forKey:@"probe"];
	[archiver finishEncoding];
	return archiver.encodedData;
}

static BOOL FxGripRenderPathRectsEqual(FxRect lhs, FxRect rhs)
{
	return lhs.left == rhs.left && lhs.bottom == rhs.bottom
		&& lhs.right == rhs.right && lhs.top == rhs.top;
}

#pragma mark - FxPlug stand-ins

/*! Stands in for FxMatrix44: a uniform scale about the origin. */
@interface FxGripRenderPathTestMatrix : NSObject
@property (nonatomic, assign) double scale;
- (FxPoint2D)transform2DPoint:(FxPoint2D)inPoint;
@end

@implementation FxGripRenderPathTestMatrix

- (FxPoint2D)transform2DPoint:(FxPoint2D)inPoint
{
	return (FxPoint2D){ inPoint.x * self.scale, inPoint.y * self.scale };
}

@end

/*! Stands in for FxImageTile: pixel bounds plus scale transforms. */
@interface FxGripRenderPathTestTile : NSObject
@property (nonatomic, assign) FxRect bounds;
@property (nonatomic, assign) double pixelScale;
@property (nonatomic, assign) double inversePixelScale;
@end

@implementation FxGripRenderPathTestTile

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_pixelScale = 1.0;
		_inversePixelScale = 1.0;
	}
	return self;
}

- (FxRect)imagePixelBounds
{
	return self.bounds;
}

- (id)pixelTransform
{
	FxGripRenderPathTestMatrix *matrix = FxGripRenderPathTestMatrix.new;
	matrix.scale = self.pixelScale;
	return matrix;
}

- (id)inversePixelTransform
{
	FxGripRenderPathTestMatrix *matrix = FxGripRenderPathTestMatrix.new;
	matrix.scale = self.inversePixelScale;
	return matrix;
}

@end

static FxGripRenderPathTestTile *FxGripRenderPathTile(SInt32 left, SInt32 bottom, SInt32 right, SInt32 top)
{
	FxGripRenderPathTestTile *tile = FxGripRenderPathTestTile.new;
	tile.bounds = (FxRect){ .left = left, .bottom = bottom, .right = right, .top = top };
	return tile;
}

#pragma mark - Effect doubles

/*! Confines notification traffic to a private center; pluginProperties are stubbable. */
@interface FxGripRenderPathTestEffect : FxGripTileableEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong) NSDictionary<NSString *, id> *stubPluginProperties;
@end

@implementation FxGripRenderPathTestEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_privateNotifier = [[cls alloc] init];
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

- (NSDictionary<NSString *, id> *)pluginProperties
{
	if (_stubPluginProperties) {
		return _stubPluginProperties;
	}
	return [super pluginProperties];
}

@end

/*!
	Conforms to FxGripTileableEffectCoderState and records what the base forwards. It does
	NOT implement the optional scheduleInputs:pluginCoder:atTime:error:, pinning that the
	dispatcher probes with respondsToSelector: rather than calling unconditionally.
*/
@interface FxGripRenderPathCoderEffect : FxGripRenderPathTestEffect <FxGripTileableEffectCoderState>
@property (nonatomic, assign) BOOL destinationCoderCalled;
@property (nonatomic, assign) FxRect coderDestinationRect;
@property (nonatomic, assign) BOOL writesDestinationRect;

@property (nonatomic, assign) BOOL sourceCoderCalled;
@property (nonatomic, assign) NSUInteger sourceCoderIndex;
@property (nonatomic, assign) FxRect sourceCoderSeenRect;
@end

@implementation FxGripRenderPathCoderEffect

- (BOOL)pluginCoder:(NSCoder *)coder
			 atTime:(CMTime)renderTime
			quality:(FxQuality)qualityLevel
			  error:(NSError * _Nullable *)error
{
	return YES;
}

- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *)sourceImages
			destinationImage:(FxImageTile *)destinationImage
				 pluginCoder:(NSCoder *)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)outError
{
	self.destinationCoderCalled = YES;
	if (self.writesDestinationRect) {
		*destinationImageRect = self.coderDestinationRect;
	}
	return YES;
}

- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
	  sourceImageIndex:(NSUInteger)sourceImageIndex
		  sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
	  destinationImage:(FxImageTile *)destinationImage
		   pluginCoder:(NSCoder *)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable *)outError
{
	self.sourceCoderCalled = YES;
	self.sourceCoderIndex = sourceImageIndex;
	self.sourceCoderSeenRect = *sourceTileRect;
	return YES;
}

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *)sourceImages
				   pluginCoder:(NSCoder *)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable *)outError
{
	return YES;
}

@end

/*! Adds the optional scheduling method: returns the staged requests. */
@interface FxGripRenderPathSchedulingEffect : FxGripRenderPathCoderEffect
@property (nonatomic, strong) NSArray *stagedRequests;
@property (nonatomic, assign) BOOL scheduleCalled;
@end

@implementation FxGripRenderPathSchedulingEffect

- (BOOL)scheduleInputs:(NSArray<FxImageTileRequest *> * _Nullable * _Nullable)inputImageRequests
		   pluginCoder:(NSCoder * _Nullable)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable * _Nonnull)error
{
	self.scheduleCalled = YES;
	*inputImageRequests = self.stagedRequests;
	return YES;
}

@end

#pragma mark - Tests

@interface FxGripTileableEffectRenderPathTests : XCTestCase
@end

@implementation FxGripTileableEffectRenderPathTests

- (FxGripRenderPathTestEffect *)makeEffectOfClass:(Class)effectClass
{
	FxGripRenderPathTestEffect *effect = [[effectClass alloc] initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect, @"the effect double must construct");
	return effect;
}

/*! A plugin-qualified properties dictionary (uuid, className, group). */
- (NSMutableDictionary *)pluginPropertiesDictionary
{
	return [NSMutableDictionary dictionaryWithDictionary:@{
		kProPlugPlugIn_UuidProperty: @"AAAABBBB-CCCC-DDDD-EEEE-FFFF00002222",
		kProPlugPlugIn_ClassNameProperty: @"FxGripRenderPathTestEffect",
		kProPlugPlugIn_GroupUUIDProperty: @"22220000-FFFF-EEEE-DDDD-CCCCBBBBAAAA",
	}];
}

#pragma mark Parameters configuration

- (void)testTheParametersConfigurationSeedsFromThePluginPropertiesTable
{
	NSArray<NSDictionary *> *declared = @[
		@{kFxParameterProperty_Id: @1, kFxParameterProperty_Type: @"float", kFxParameterProperty_Name: @"Level"},
		@{kFxParameterProperty_Id: @2, kFxParameterProperty_Type: @"toggle", kFxParameterProperty_Name: @"Invert"},
	];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_ParametersProperty] = declared;

	FxGripRenderPathTestEffect *effect = [self makeEffectOfClass:FxGripRenderPathTestEffect.class];
	effect.stubPluginProperties = properties;

	NSMutableArray<NSDictionary *> *configuration = [effect parametersConfiguration];
	XCTAssertEqualObjects(configuration, declared);
	XCTAssertTrue([configuration isKindOfClass:NSMutableArray.class]);
}

- (void)testTheParametersConfigurationIsEmptyWithoutADeclaredTable
{
	FxGripRenderPathTestEffect *effect = [self makeEffectOfClass:FxGripRenderPathTestEffect.class];
	effect.stubPluginProperties = [self pluginPropertiesDictionary];

	NSMutableArray<NSDictionary *> *configuration = [effect parametersConfiguration];
	XCTAssertNotNil(configuration);
	XCTAssertEqual(configuration.count, (NSUInteger)0);
}

#pragma mark Destination image rect

- (void)testTheDestinationImageRectDefaultsToTheSourcesImageSpaceUnion
{
	FxGripRenderPathTestEffect *effect = [self makeEffectOfClass:FxGripRenderPathTestEffect.class];
	NSArray *sources = @[FxGripRenderPathTile(0, 0, 50, 40), FxGripRenderPathTile(10, -10, 80, 30)];
	FxGripRenderPathTestTile *destination = FxGripRenderPathTile(0, 0, 100, 100);

	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect destinationImageRect:&rect
							  sourceImages:sources
						  destinationImage:(FxImageTile *)destination
							   pluginState:FxGripRenderPathState()
									atTime:FxGripRenderPathTime(1, 24)
									 error:&error];

	XCTAssertTrue(ok);
	XCTAssertNil(error);
	FxRect expected = { .left = 0, .bottom = -10, .right = 80, .top = 40 };
	XCTAssertTrue(FxGripRenderPathRectsEqual(rect, expected),
				  @"expected the union {0,-10,80,40}, got {%d,%d,%d,%d}",
				  rect.left, rect.bottom, rect.right, rect.top);
}

- (void)testTheDestinationImageRectDefaultsToTheOutputBoundsWithoutSources
{
	FxGripRenderPathTestEffect *effect = [self makeEffectOfClass:FxGripRenderPathTestEffect.class];
	FxGripRenderPathTestTile *destination = FxGripRenderPathTile(0, 0, 640, 360);

	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect destinationImageRect:&rect
							  sourceImages:@[]
						  destinationImage:(FxImageTile *)destination
							   pluginState:FxGripRenderPathState()
									atTime:FxGripRenderPathTime(1, 24)
									 error:&error];

	XCTAssertTrue(ok);
	FxRect expected = { .left = 0, .bottom = 0, .right = 640, .top = 360 };
	XCTAssertTrue(FxGripRenderPathRectsEqual(rect, expected));
}

- (void)testTheDestinationImageRectForwardsToTheCoderVariant
{
	FxGripRenderPathCoderEffect *effect =
		(FxGripRenderPathCoderEffect *)[self makeEffectOfClass:FxGripRenderPathCoderEffect.class];
	effect.writesDestinationRect = YES;
	effect.coderDestinationRect = (FxRect){ .left = 7, .bottom = 8, .right = 9, .top = 10 };

	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect destinationImageRect:&rect
							  sourceImages:@[FxGripRenderPathTile(0, 0, 50, 50)]
						  destinationImage:(FxImageTile *)FxGripRenderPathTile(0, 0, 50, 50)
							   pluginState:FxGripRenderPathState()
									atTime:FxGripRenderPathTime(1, 24)
									 error:&error];

	XCTAssertTrue(ok);
	XCTAssertTrue(effect.destinationCoderCalled);
	XCTAssertTrue(FxGripRenderPathRectsEqual(rect, effect.coderDestinationRect),
				  @"the subclass coder method's rect must reach the host");
}

#pragma mark Source tile rect

- (void)testTheSourceTileRectMirrorsTheDestinationTileWhenOutputSizeIsFixed
{
	FxGripRenderPathCoderEffect *effect =
		(FxGripRenderPathCoderEffect *)[self makeEffectOfClass:FxGripRenderPathCoderEffect.class];
	effect.changesOutputSize = NO;
	FxRect destinationTile = { .left = 10, .bottom = 20, .right = 30, .top = 40 };

	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect sourceTileRect:&rect
					sourceImageIndex:0
						sourceImages:@[FxGripRenderPathTile(0, 0, 100, 100)]
				 destinationTileRect:destinationTile
					destinationImage:(FxImageTile *)FxGripRenderPathTile(0, 0, 100, 100)
						 pluginState:FxGripRenderPathState()
							  atTime:FxGripRenderPathTime(1, 24)
							   error:&error];

	XCTAssertTrue(ok);
	XCTAssertTrue(FxGripRenderPathRectsEqual(rect, destinationTile));
	XCTAssertTrue(effect.sourceCoderCalled,
				  @"a fixed-size filter's coder method must still run so it can pad its tiles");
	XCTAssertTrue(FxGripRenderPathRectsEqual(effect.sourceCoderSeenRect, destinationTile),
				  @"the coder method receives the mirrored default as its starting rect");
}

- (void)testTheSourceTileRectUsesTheIndexedSourceWhenOutputSizeChanges
{
	FxGripRenderPathTestEffect *effect = [self makeEffectOfClass:FxGripRenderPathTestEffect.class];
	XCTAssertTrue(effect.changesOutputSize, @"changesOutputSize defaults on; the test rides the default");

	FxGripRenderPathTestTile *narrow = FxGripRenderPathTile(0, 0, 100, 100);
	narrow.pixelScale = 2.0;
	FxGripRenderPathTestTile *wide = FxGripRenderPathTile(0, 0, 100, 100);
	wide.pixelScale = 4.0;

	FxRect destinationTile = { .left = 10, .bottom = 20, .right = 30, .top = 40 };
	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect sourceTileRect:&rect
					sourceImageIndex:1
						sourceImages:@[narrow, wide]
				 destinationTileRect:destinationTile
					destinationImage:(FxImageTile *)FxGripRenderPathTile(0, 0, 100, 100)
						 pluginState:FxGripRenderPathState()
							  atTime:FxGripRenderPathTime(1, 24)
							   error:&error];

	XCTAssertTrue(ok);
	FxRect expected = { .left = 40, .bottom = 80, .right = 120, .top = 160 };
	XCTAssertTrue(FxGripRenderPathRectsEqual(rect, expected),
				  @"the indexed source's transform must be used, got {%d,%d,%d,%d}",
				  rect.left, rect.bottom, rect.right, rect.top);
}

- (void)testTheSourceTileRectRefusesAnOutOfRangeSourceIndex
{
	FxGripRenderPathTestEffect *effect = [self makeEffectOfClass:FxGripRenderPathTestEffect.class];

	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect sourceTileRect:&rect
					sourceImageIndex:2
						sourceImages:@[FxGripRenderPathTile(0, 0, 100, 100)]
				 destinationTileRect:(FxRect){ 0, 0, 10, 10 }
					destinationImage:(FxImageTile *)FxGripRenderPathTile(0, 0, 100, 100)
						 pluginState:FxGripRenderPathState()
							  atTime:FxGripRenderPathTime(1, 24)
							   error:&error];

	XCTAssertFalse(ok);
	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxGripRenderPathExpectedErrorDomain());
}

#pragma mark Schedule inputs

- (void)testScheduleInputsDispatchesThePluginCoderSelector
{
	FxGripRenderPathSchedulingEffect *effect =
		(FxGripRenderPathSchedulingEffect *)[self makeEffectOfClass:FxGripRenderPathSchedulingEffect.class];
	effect.stagedRequests = @[@"request-a", @"request-b"];

	NSArray *requests = nil;
	NSError *error = nil;
	BOOL ok = [effect scheduleInputs:&requests
					 withPluginState:FxGripRenderPathState()
							  atTime:FxGripRenderPathTime(1, 24)
							   error:&error];

	XCTAssertTrue(ok);
	XCTAssertTrue(effect.scheduleCalled);
	XCTAssertEqualObjects(requests, effect.stagedRequests);
}

- (void)testScheduleInputsLeavesTheRequestsUntouchedWithoutAnImplementation
{
	// A coder-state conformer without the optional method: the dispatcher must probe
	// with respondsToSelector: instead of calling unconditionally.
	FxGripRenderPathCoderEffect *effect =
		(FxGripRenderPathCoderEffect *)[self makeEffectOfClass:FxGripRenderPathCoderEffect.class];

	NSArray *requests = nil;
	NSError *error = nil;
	BOOL ok = [effect scheduleInputs:&requests
					 withPluginState:FxGripRenderPathState()
							  atTime:FxGripRenderPathTime(1, 24)
							   error:&error];

	XCTAssertTrue(ok);
	XCTAssertNil(requests, @"an untouched out-parameter keeps the host's default input delivery");
}

@end
