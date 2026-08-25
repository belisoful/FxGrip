//
//  FxTileableEffectRenderPathTests.m
//  FxGripTests
//
//  Unit tests for FxTileableEffectBase's host render-path entry points: the
//  plist-seeded parameters configuration, the destination-image-rect and
//  source-tile-rect defaults and their forwarding to the subclass pluginCoder:
//  variants, and the scheduleInputs dispatch.
//
//  Every effect is an instance of a local subclass returning a private
//  NSPriorityNotificationCenter, the FxTileableEffectBaseCategoriesTests
//  convention, so no test touches the process-wide center. FxImageTile and
//  FxMatrix44 are stood in for by local stubs implementing exactly the messages
//  the base sends (imagePixelBounds, pixelTransform, inversePixelTransform,
//  transform2DPoint:), cast to the FxPlug pointer types.
//

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxTileableEffectBase.h>

static NSString *FxRenderPathExpectedErrorDomain(void)
{
	NSString * __unsafe_unretained *domain = (NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT, "FxPlugErrorDomain");
	return domain ? *domain : FxGripPlugErrorDomainConstant;
}

static CMTime FxRenderPathTime(int64_t value, int32_t timescale)
{
	return (CMTime){.value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

/*! Keyed-archive bytes for the host's pluginState argument. */
static NSData *FxRenderPathState(void)
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
	[archiver encodeObject:@"probe" forKey:@"probe"];
	[archiver finishEncoding];
	return archiver.encodedData;
}

static BOOL FxRenderPathRectsEqual(FxRect lhs, FxRect rhs)
{
	return lhs.left == rhs.left && lhs.bottom == rhs.bottom
		&& lhs.right == rhs.right && lhs.top == rhs.top;
}

#pragma mark - FxPlug stand-ins

/*! Stands in for FxMatrix44: a uniform scale about the origin. */
@interface FxRenderPathTestMatrix : NSObject
@property (nonatomic, assign) double scale;
- (FxPoint2D)transform2DPoint:(FxPoint2D)inPoint;
@end

@implementation FxRenderPathTestMatrix

- (FxPoint2D)transform2DPoint:(FxPoint2D)inPoint
{
	return (FxPoint2D){ inPoint.x * self.scale, inPoint.y * self.scale };
}

@end

/*! Stands in for FxImageTile: pixel bounds plus scale transforms. */
@interface FxRenderPathTestTile : NSObject
@property (nonatomic, assign) FxRect bounds;
@property (nonatomic, assign) double pixelScale;
@property (nonatomic, assign) double inversePixelScale;
@end

@implementation FxRenderPathTestTile

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
	FxRenderPathTestMatrix *matrix = FxRenderPathTestMatrix.new;
	matrix.scale = self.pixelScale;
	return matrix;
}

- (id)inversePixelTransform
{
	FxRenderPathTestMatrix *matrix = FxRenderPathTestMatrix.new;
	matrix.scale = self.inversePixelScale;
	return matrix;
}

@end

static FxRenderPathTestTile *FxRenderPathTile(SInt32 left, SInt32 bottom, SInt32 right, SInt32 top)
{
	FxRenderPathTestTile *tile = FxRenderPathTestTile.new;
	tile.bounds = (FxRect){ .left = left, .bottom = bottom, .right = right, .top = top };
	return tile;
}

#pragma mark - Effect doubles

/*! Confines notification traffic to a private center; pluginProperties are stubbable. */
@interface FxRenderPathTestEffect : FxTileableEffectBase
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong) NSDictionary<NSString *, id> *stubPluginProperties;
@end

@implementation FxRenderPathTestEffect

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
	Conforms to FxTileableEffectCoderState and records what the base forwards. It does
	NOT implement the optional scheduleInputs:pluginCoder:atTime:error:, pinning that the
	dispatcher probes with respondsToSelector: rather than calling unconditionally.
*/
@interface FxRenderPathCoderEffect : FxRenderPathTestEffect <FxTileableEffectCoderState>
@property (nonatomic, assign) BOOL destinationCoderCalled;
@property (nonatomic, assign) FxRect coderDestinationRect;
@property (nonatomic, assign) BOOL writesDestinationRect;

@property (nonatomic, assign) BOOL sourceCoderCalled;
@property (nonatomic, assign) NSUInteger sourceCoderIndex;
@property (nonatomic, assign) FxRect sourceCoderSeenRect;
@end

@implementation FxRenderPathCoderEffect

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
@interface FxRenderPathSchedulingEffect : FxRenderPathCoderEffect
@property (nonatomic, strong) NSArray *stagedRequests;
@property (nonatomic, assign) BOOL scheduleCalled;
@end

@implementation FxRenderPathSchedulingEffect

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

@interface FxTileableEffectRenderPathTests : XCTestCase
@end

@implementation FxTileableEffectRenderPathTests

- (FxRenderPathTestEffect *)makeEffectOfClass:(Class)effectClass
{
	FxRenderPathTestEffect *effect = [[effectClass alloc] initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect, @"the effect double must construct");
	return effect;
}

/*! A plugin-qualified properties dictionary (uuid, className, group). */
- (NSMutableDictionary *)pluginPropertiesDictionary
{
	return [NSMutableDictionary dictionaryWithDictionary:@{
		kProPlugPlugIn_UuidProperty: @"AAAABBBB-CCCC-DDDD-EEEE-FFFF00002222",
		kProPlugPlugIn_ClassNameProperty: @"FxRenderPathTestEffect",
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

	FxRenderPathTestEffect *effect = [self makeEffectOfClass:FxRenderPathTestEffect.class];
	effect.stubPluginProperties = properties;

	NSMutableArray<NSDictionary *> *configuration = [effect parametersConfiguration];
	XCTAssertEqualObjects(configuration, declared);
	XCTAssertTrue([configuration isKindOfClass:NSMutableArray.class]);
}

- (void)testTheParametersConfigurationIsEmptyWithoutADeclaredTable
{
	FxRenderPathTestEffect *effect = [self makeEffectOfClass:FxRenderPathTestEffect.class];
	effect.stubPluginProperties = [self pluginPropertiesDictionary];

	NSMutableArray<NSDictionary *> *configuration = [effect parametersConfiguration];
	XCTAssertNotNil(configuration);
	XCTAssertEqual(configuration.count, (NSUInteger)0);
}

#pragma mark Destination image rect

- (void)testTheDestinationImageRectDefaultsToTheSourcesImageSpaceUnion
{
	FxRenderPathTestEffect *effect = [self makeEffectOfClass:FxRenderPathTestEffect.class];
	NSArray *sources = @[FxRenderPathTile(0, 0, 50, 40), FxRenderPathTile(10, -10, 80, 30)];
	FxRenderPathTestTile *destination = FxRenderPathTile(0, 0, 100, 100);

	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect destinationImageRect:&rect
							  sourceImages:sources
						  destinationImage:(FxImageTile *)destination
							   pluginState:FxRenderPathState()
									atTime:FxRenderPathTime(1, 24)
									 error:&error];

	XCTAssertTrue(ok);
	XCTAssertNil(error);
	FxRect expected = { .left = 0, .bottom = -10, .right = 80, .top = 40 };
	XCTAssertTrue(FxRenderPathRectsEqual(rect, expected),
				  @"expected the union {0,-10,80,40}, got {%d,%d,%d,%d}",
				  rect.left, rect.bottom, rect.right, rect.top);
}

- (void)testTheDestinationImageRectDefaultsToTheOutputBoundsWithoutSources
{
	FxRenderPathTestEffect *effect = [self makeEffectOfClass:FxRenderPathTestEffect.class];
	FxRenderPathTestTile *destination = FxRenderPathTile(0, 0, 640, 360);

	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect destinationImageRect:&rect
							  sourceImages:@[]
						  destinationImage:(FxImageTile *)destination
							   pluginState:FxRenderPathState()
									atTime:FxRenderPathTime(1, 24)
									 error:&error];

	XCTAssertTrue(ok);
	FxRect expected = { .left = 0, .bottom = 0, .right = 640, .top = 360 };
	XCTAssertTrue(FxRenderPathRectsEqual(rect, expected));
}

- (void)testTheDestinationImageRectForwardsToTheCoderVariant
{
	FxRenderPathCoderEffect *effect =
		(FxRenderPathCoderEffect *)[self makeEffectOfClass:FxRenderPathCoderEffect.class];
	effect.writesDestinationRect = YES;
	effect.coderDestinationRect = (FxRect){ .left = 7, .bottom = 8, .right = 9, .top = 10 };

	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect destinationImageRect:&rect
							  sourceImages:@[FxRenderPathTile(0, 0, 50, 50)]
						  destinationImage:(FxImageTile *)FxRenderPathTile(0, 0, 50, 50)
							   pluginState:FxRenderPathState()
									atTime:FxRenderPathTime(1, 24)
									 error:&error];

	XCTAssertTrue(ok);
	XCTAssertTrue(effect.destinationCoderCalled);
	XCTAssertTrue(FxRenderPathRectsEqual(rect, effect.coderDestinationRect),
				  @"the subclass coder method's rect must reach the host");
}

#pragma mark Source tile rect

- (void)testTheSourceTileRectMirrorsTheDestinationTileWhenOutputSizeIsFixed
{
	FxRenderPathCoderEffect *effect =
		(FxRenderPathCoderEffect *)[self makeEffectOfClass:FxRenderPathCoderEffect.class];
	effect.changesOutputSize = NO;
	FxRect destinationTile = { .left = 10, .bottom = 20, .right = 30, .top = 40 };

	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect sourceTileRect:&rect
					sourceImageIndex:0
						sourceImages:@[FxRenderPathTile(0, 0, 100, 100)]
				 destinationTileRect:destinationTile
					destinationImage:(FxImageTile *)FxRenderPathTile(0, 0, 100, 100)
						 pluginState:FxRenderPathState()
							  atTime:FxRenderPathTime(1, 24)
							   error:&error];

	XCTAssertTrue(ok);
	XCTAssertTrue(FxRenderPathRectsEqual(rect, destinationTile));
	XCTAssertTrue(effect.sourceCoderCalled,
				  @"a fixed-size filter's coder method must still run so it can pad its tiles");
	XCTAssertTrue(FxRenderPathRectsEqual(effect.sourceCoderSeenRect, destinationTile),
				  @"the coder method receives the mirrored default as its starting rect");
}

- (void)testTheSourceTileRectUsesTheIndexedSourceWhenOutputSizeChanges
{
	FxRenderPathTestEffect *effect = [self makeEffectOfClass:FxRenderPathTestEffect.class];
	XCTAssertTrue(effect.changesOutputSize, @"changesOutputSize defaults on; the test rides the default");

	FxRenderPathTestTile *narrow = FxRenderPathTile(0, 0, 100, 100);
	narrow.pixelScale = 2.0;
	FxRenderPathTestTile *wide = FxRenderPathTile(0, 0, 100, 100);
	wide.pixelScale = 4.0;

	FxRect destinationTile = { .left = 10, .bottom = 20, .right = 30, .top = 40 };
	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect sourceTileRect:&rect
					sourceImageIndex:1
						sourceImages:@[narrow, wide]
				 destinationTileRect:destinationTile
					destinationImage:(FxImageTile *)FxRenderPathTile(0, 0, 100, 100)
						 pluginState:FxRenderPathState()
							  atTime:FxRenderPathTime(1, 24)
							   error:&error];

	XCTAssertTrue(ok);
	FxRect expected = { .left = 40, .bottom = 80, .right = 120, .top = 160 };
	XCTAssertTrue(FxRenderPathRectsEqual(rect, expected),
				  @"the indexed source's transform must be used, got {%d,%d,%d,%d}",
				  rect.left, rect.bottom, rect.right, rect.top);
}

- (void)testTheSourceTileRectRefusesAnOutOfRangeSourceIndex
{
	FxRenderPathTestEffect *effect = [self makeEffectOfClass:FxRenderPathTestEffect.class];

	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;
	BOOL ok = [effect sourceTileRect:&rect
					sourceImageIndex:2
						sourceImages:@[FxRenderPathTile(0, 0, 100, 100)]
				 destinationTileRect:(FxRect){ 0, 0, 10, 10 }
					destinationImage:(FxImageTile *)FxRenderPathTile(0, 0, 100, 100)
						 pluginState:FxRenderPathState()
							  atTime:FxRenderPathTime(1, 24)
							   error:&error];

	XCTAssertFalse(ok);
	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxRenderPathExpectedErrorDomain());
}

#pragma mark Schedule inputs

- (void)testScheduleInputsDispatchesThePluginCoderSelector
{
	FxRenderPathSchedulingEffect *effect =
		(FxRenderPathSchedulingEffect *)[self makeEffectOfClass:FxRenderPathSchedulingEffect.class];
	effect.stagedRequests = @[@"request-a", @"request-b"];

	NSArray *requests = nil;
	NSError *error = nil;
	BOOL ok = [effect scheduleInputs:&requests
					 withPluginState:FxRenderPathState()
							  atTime:FxRenderPathTime(1, 24)
							   error:&error];

	XCTAssertTrue(ok);
	XCTAssertTrue(effect.scheduleCalled);
	XCTAssertEqualObjects(requests, effect.stagedRequests);
}

- (void)testScheduleInputsLeavesTheRequestsUntouchedWithoutAnImplementation
{
	// A coder-state conformer without the optional method: the dispatcher must probe
	// with respondsToSelector: instead of calling unconditionally.
	FxRenderPathCoderEffect *effect =
		(FxRenderPathCoderEffect *)[self makeEffectOfClass:FxRenderPathCoderEffect.class];

	NSArray *requests = nil;
	NSError *error = nil;
	BOOL ok = [effect scheduleInputs:&requests
					 withPluginState:FxRenderPathState()
							  atTime:FxRenderPathTime(1, 24)
							   error:&error];

	XCTAssertTrue(ok);
	XCTAssertNil(requests, @"an untouched out-parameter keeps the host's default input delivery");
}

@end
