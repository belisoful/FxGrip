//
//  FxGripLiveImageParameterTests.m
//  FxGripTests
//
//  Unit tests for the live image parameter: type identity, the creation call and the
//  flags it forces on, the slot count derived from the configuration, the view it vends,
//  the in-process publish paths (frame, CGImage, image buffer, Metal texture) and their
//  coalesced push to every attached view, the suppression of a publish while no view is on
//  screen, the seeding of a view registered while another is on screen, and the GPU
//  downscale through the snapshot size.
//
//  The test bundle links only FxGrip and XCTest. The Metal device is reached through the
//  loaded images rather than a link-time reference.
//

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxParameter.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripImageBuffer.h>
#import <FxGrip/FxGripImageCompression.h>
#import <FxGrip/FxGripLiveImage.h>
#import <FxGrip/FxGripLiveFrame.h>
#import <FxGrip/FxGripLiveImageParameter.h>
#import <FxGrip/FxGripCustomCreationAPI_v1.h>

typedef void *(*FxGripLiveImageTestCreateDevice)(void);

static const FxParameterId kLiveImageTestID = 93;

@interface FxGripLiveImageParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@property (nonatomic, strong) FxGripParamClassTestAPIManager *apiManager;
@property (nonatomic, strong) NSMutableArray<NSWindow *> *windows;
@end

@implementation FxGripLiveImageParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamClassTestEffect.alloc init];
	self.apiManager = [FxGripParamClassTestAPIManager.alloc init];
	self.effect.apiManager = self.apiManager;
	self.windows = [NSMutableArray array];
}

- (void)tearDown
{
	self.effect = nil;
	self.apiManager = nil;
	self.windows = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSDictionary *)call
{
	return self.effect.creationCall;
}

- (NSMutableDictionary *)configWithDefault:(nullable NSDictionary *)defaultValue
{
	NSDictionary *extra = defaultValue ? @{kFxParameterProperty_Default: defaultValue} : nil;
	return FxGripParamClassTestConfig(kLiveImageTestID, kFxParameterType_LiveImage, @"Channels", extra);
}

- (FxGripLiveImageParameter *)makeParameterWithDefault:(nullable NSDictionary *)defaultValue
{
	return [FxGripLiveImageParameter.alloc initWithDictionary:[self configWithDefault:defaultValue]
													   effect:(id)self.effect];
}

/*! Hosts a view in an off-screen window so publishing sees an on-screen UI. The test
	bundle does not link AppKit, so NSWindow is reached through the loaded framework. */
- (void)hostView:(NSView *)view
{
	Class windowClass = NSClassFromString(@"NSWindow");
	NSWindow *window = [[windowClass alloc] initWithContentRect:NSMakeRect(0, 0, 240, 160)
													 styleMask:NSWindowStyleMaskBorderless
													   backing:NSBackingStoreBuffered
														 defer:NO];
	[window.contentView addSubview:view];
	[self.windows addObject:window];
}

/*! Vends the parameter's view and hosts it on screen. */
- (FxGripLiveImageView *)hostedViewForParameter:(FxGripLiveImageParameter *)parameter
{
	FxGripLiveImageView *view = (FxGripLiveImageView *)[parameter newParameterView];
	[self hostView:view];
	return view;
}

- (FxGripLiveFrame *)frameWithWidth:(NSUInteger)width height:(NSUInteger)height fill:(uint8_t)fill
{
	NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
	memset(pixels.mutableBytes, fill, pixels.length);
	return [FxGripLiveFrame frameWithBytes:pixels.bytes rowBytes:width * 4 width:width height:height
							   pixelFormat:MTLPixelFormatRGBA8Unorm];
}

/*! Runs the main run loop until the condition holds or the timeout passes. */
- (BOOL)pumpUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition()) {
		if (deadline.timeIntervalSinceNow < 0) {
			return NO;
		}
		[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	}
	return YES;
}

- (BOOL)pumpUntilView:(FxGripLiveImageView *)view showsFrame:(nullable FxGripLiveFrame *)frame inSlot:(NSUInteger)slot
{
	return [self pumpUntil:^BOOL{ return [view frameInSlot:slot] == frame; } timeout:2.0];
}

- (id<MTLDevice>)metalDevice
{
	FxGripLiveImageTestCreateDevice create =
		(FxGripLiveImageTestCreateDevice)dlsym(RTLD_DEFAULT, "MTLCreateSystemDefaultDevice");
	if (create == NULL) {
		return nil;
	}
	return (__bridge_transfer id<MTLDevice>)create();
}

- (id<MTLTexture>)textureWithDevice:(id<MTLDevice>)device
							 format:(MTLPixelFormat)format
							  width:(NSUInteger)width
							 height:(NSUInteger)height
							   fill:(uint8_t)fill
{
	Class descriptorClass = NSClassFromString(@"MTLTextureDescriptor");
	MTLTextureDescriptor *descriptor = [descriptorClass texture2DDescriptorWithPixelFormat:format
																					width:width
																				   height:height
																				mipmapped:NO];
	descriptor.storageMode = device.hasUnifiedMemory ? MTLStorageModeShared : MTLStorageModeManaged;
	id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
	NSUInteger bytesPerPixel = format == MTLPixelFormatRG8Unorm ? 2 : 4;
	NSMutableData *pixels = [NSMutableData dataWithLength:width * height * bytesPerPixel];
	memset(pixels.mutableBytes, fill, pixels.length);
	[texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0
				 withBytes:pixels.bytes bytesPerRow:width * bytesPerPixel];
	return texture;
}

#pragma mark Identity and creation

- (void)testTheParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([FxGripLiveImageParameter parameterType], FxParameterType_LiveImage);
	XCTAssertEqualObjects([FxGripLiveImageParameter parameterTypeString], kFxParameterType_LiveImage);
}

- (void)testTheCustomValueClassesCoverTheDictionaryAndItsContents
{
	NSSet<Class> *classes = [FxGripLiveImageParameter customValueClasses];
	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
	XCTAssertTrue([classes containsObject:NSArray.class]);
	XCTAssertTrue([classes containsObject:NSString.class]);
}

- (void)testCreationIsUnnamedFullWidthStaticAndStateless
{
	XCTAssertTrue([FxGripLiveImageParameter addParameter:[self configWithDefault:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"");
	XCTAssertEqualObjects(self.call[@"id"], @(kLiveImageTestID));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");

	NSInteger flags = [self.call[@"flags"] integerValue];
	XCTAssertTrue((flags & kFxParameterFlag_CUSTOM_UI) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOT_ANIMATABLE) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_USE_FULL_VIEW_WIDTH) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOSTATE) != 0);
}

- (void)testCreationRecordsTheLabelsAndTheSlotCount
{
	NSArray *labels = @[@"Channel A", @"Channel B", @"Channel C", @"Channel D"];
	NSDictionary *config = [self configWithDefault:@{kFxGripLiveImageKey_Labels: labels, kFxGripLiveImageKey_Height: @96.0}];
	XCTAssertTrue([FxGripLiveImageParameter addParameter:config toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	XCTAssertEqualObjects([value objectForKey:kFxGripLiveImageKey_Labels], labels);
	XCTAssertEqualObjects([value objectForKey:kFxGripLiveImageKey_Slots], @4);
	XCTAssertEqualObjects([value objectForKey:kFxGripLiveImageKey_Height], @96.0);
}

- (void)testCreationWithoutLabelsRecordsOneSlot
{
	XCTAssertTrue([FxGripLiveImageParameter addParameter:[self configWithDefault:nil] toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	XCTAssertEqualObjects([value objectForKey:kFxGripLiveImageKey_Labels], @[]);
	XCTAssertEqualObjects([value objectForKey:kFxGripLiveImageKey_Slots], @1);
}

- (void)testTheCreationAPIBuildsTheLabelsAndHeight
{
	FxGripCustomCreationAPI_v1 *api = [FxGripCustomCreationAPI_v1.alloc initWithEffect:(id)self.effect];
	NSArray *labels = @[@"A", @"B"];
	XCTAssertTrue([api addLiveImageWithName:@"Channels" parameterID:kLiveImageTestID
									 labels:labels height:80.0 parameterFlags:kFxParameterFlag_DEFAULT]);

	FxGripDictionary *value = self.call[@"default"];
	XCTAssertEqualObjects([value objectForKey:kFxGripLiveImageKey_Labels], (@[@"A", @"B"]));
	XCTAssertEqualObjects([value objectForKey:kFxGripLiveImageKey_Slots], @2);
	XCTAssertEqualObjects([value objectForKey:kFxGripLiveImageKey_Height], @80.0);
}

#pragma mark Slots

- (void)testTheSlotCountComesFromTheLabels
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:@{kFxGripLiveImageKey_Labels: @[@"A", @"B", @"C"]}];
	XCTAssertEqual(parameter.slotCount, 3u);
}

- (void)testTheSlotCountFallsBackToTheSlotsKeyThenOne
{
	XCTAssertEqual([self makeParameterWithDefault:@{kFxGripLiveImageKey_Slots: @2}].slotCount, 2u);
	XCTAssertEqual([self makeParameterWithDefault:nil].slotCount, 1u);
	XCTAssertEqual([self makeParameterWithDefault:@{kFxGripLiveImageKey_Slots: @0}].slotCount, 1u);
}

- (void)testTheSnapshotSizeDefaultsAndReadsTheConfiguration
{
	XCTAssertEqual([self makeParameterWithDefault:nil].snapshotSize, (NSUInteger)kFxGripLiveImageDefaultSnapshotSize);
	XCTAssertEqual([self makeParameterWithDefault:@{kFxGripLiveImageKey_SnapshotSize: @0}].snapshotSize, 0u);
	XCTAssertEqual([self makeParameterWithDefault:@{kFxGripLiveImageKey_SnapshotSize: @256}].snapshotSize, 256u);
}

#pragma mark View

- (void)testTheParameterVendsAViewConfiguredFromTheDeclaredDefault
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:@{
		kFxGripLiveImageKey_Labels: @[@"Channel A", @"", @"Channel C"],
		kFxGripLiveImageKey_Height: @72.0,
	}];
	NSView *view = [parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripLiveImageView.class]);
	FxGripLiveImageView *liveView = (FxGripLiveImageView *)view;
	XCTAssertEqual(liveView.slotCount, 3u);
	XCTAssertEqualObjects([liveView labelInSlot:0], @"Channel A");
	XCTAssertNil([liveView labelInSlot:1], @"an empty label reads as no label");
	XCTAssertEqualObjects([liveView labelInSlot:2], @"Channel C");
	XCTAssertNil([liveView labelInSlot:3]);
	XCTAssertEqual(liveView.intrinsicContentSize.height, 72.0);
}

- (void)testAViewDefaultsToOneSlotAndTheDefaultHeight
{
	FxGripLiveImageView *view = [FxGripLiveImageView.alloc initWithFrame:NSMakeRect(0, 0, 200, 100)];
	XCTAssertEqual(view.slotCount, 1u);
	XCTAssertEqual(view.intrinsicContentSize.height, kFxGripLiveImageDefaultHeight);
	XCTAssertNil([view frameInSlot:0]);
}

- (void)testTheViewGrowsItsSlotsFromAConfigurationPush
{
	FxGripLiveImageView *view = [FxGripLiveImageView.alloc initWithFrame:NSMakeRect(0, 0, 200, 100)];
	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{kFxGripLiveImageKey_Slots: @4}]];
	XCTAssertEqual(view.slotCount, 4u);

	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{kFxGripLiveImageKey_Labels: @[@"One"]}]];
	XCTAssertEqual(view.slotCount, 1u);
	XCTAssertEqualObjects([view labelInSlot:0], @"One");
}

- (void)testShowingAFrameOutsideTheSlotsIsIgnored
{
	FxGripLiveImageView *view = [FxGripLiveImageView.alloc initWithFrame:NSMakeRect(0, 0, 200, 100)];
	FxGripLiveFrame *frame = [self frameWithWidth:2 height:2 fill:0x80];
	[view showFrame:frame inSlot:5];
	XCTAssertNil([view frameInSlot:5]);

	[view showFrame:frame inSlot:0];
	XCTAssertTrue([view frameInSlot:0] == frame);
	[view showFrame:nil inSlot:0];
	XCTAssertNil([view frameInSlot:0]);
}

- (void)testTheViewDrawsWithAndWithoutFrames
{
	FxGripLiveImageView *view = [FxGripLiveImageView.alloc initWithFrame:NSMakeRect(0, 0, 240, 80)];
	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{kFxGripLiveImageKey_Labels: @[@"A", @"B"]}]];
	[view showFrame:[self frameWithWidth:16 height:9 fill:0xC0] inSlot:0];

	// Drawing off-window exercises the layout, clip, checkerboard, image, and caption paths.
	XCTAssertNoThrow([view cacheDisplayInRect:view.bounds toBitmapImageRep:[view bitmapImageRepForCachingDisplayInRect:view.bounds]]);
}

#pragma mark Publishing

- (void)testAPublishedFrameReachesTheVendedView
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:@{kFxGripLiveImageKey_Slots: @2}];
	FxGripLiveImageView *view = [self hostedViewForParameter:parameter];
	FxGripLiveFrame *frame = [self frameWithWidth:4 height:4 fill:0x10];

	XCTAssertTrue([parameter publishFrame:frame inSlot:1]);
	XCTAssertTrue([parameter frameInSlot:1] == frame, @"the store updates before the flush");
	XCTAssertTrue([self pumpUntilView:view showsFrame:frame inSlot:1]);
	XCTAssertNil([view frameInSlot:0]);
}

- (void)testPublishingIsSuppressedWithNoViewOnScreen
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:@{kFxGripLiveImageKey_Slots: @2}];
	FxGripLiveFrame *frame = [self frameWithWidth:4 height:4 fill:0x10];

	// A render with no inspector (a batch export or a background render) publishes nothing.
	XCTAssertFalse([parameter publishFrame:frame inSlot:0]);
	XCTAssertNil([parameter frameInSlot:0]);

	// A vended but off-screen view is not yet an on-screen UI.
	FxGripLiveImageView *view = (FxGripLiveImageView *)[parameter newParameterView];
	XCTAssertFalse([parameter publishFrame:frame inSlot:0]);
	XCTAssertNil([parameter frameInSlot:0]);

	[self hostView:view];
	XCTAssertTrue([parameter publishFrame:frame inSlot:0]);
	XCTAssertTrue([parameter frameInSlot:0] == frame);
}

- (void)testPublishingOutsideTheSlotsOrANilFrameIsRefused
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:nil];
	[self hostedViewForParameter:parameter];
	XCTAssertFalse([parameter publishFrame:[self frameWithWidth:2 height:2 fill:0] inSlot:1]);
	XCTAssertFalse([parameter publishFrame:(FxGripLiveFrame * _Nonnull)nil inSlot:0]);
	XCTAssertNil([parameter frameInSlot:0]);
	XCTAssertNil([parameter frameInSlot:7]);
}

- (void)testAViewRegisteredWhileAnotherIsOnScreenIsSeededWithTheStoredFrames
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:@{kFxGripLiveImageKey_Slots: @2}];
	FxGripLiveImageView *onscreen = [self hostedViewForParameter:parameter];
	FxGripLiveFrame *first = [self frameWithWidth:2 height:2 fill:0x01];
	FxGripLiveFrame *second = [self frameWithWidth:2 height:2 fill:0x02];
	[parameter publishFrame:first inSlot:0];
	[parameter publishFrame:second inSlot:1];
	XCTAssertTrue([self pumpUntilView:onscreen showsFrame:second inSlot:1]);

	FxGripLiveImageView *seeded = (FxGripLiveImageView *)[parameter newParameterView];

	XCTAssertTrue([seeded frameInSlot:0] == first);
	XCTAssertTrue([seeded frameInSlot:1] == second);
}

- (void)testAnAttachedViewJoinsThePushList
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:nil];
	FxGripLiveImageView *view = [FxGripLiveImageView.alloc initWithFrame:NSMakeRect(0, 0, 200, 100)];
	[self hostView:view];
	[parameter attachCustomView:view];
	XCTAssertTrue(parameter.customView == view);

	FxGripLiveFrame *frame = [self frameWithWidth:2 height:2 fill:0x33];
	XCTAssertTrue([parameter publishFrame:frame inSlot:0]);
	XCTAssertTrue([self pumpUntilView:view showsFrame:frame inSlot:0]);
}

- (void)testRapidPublishesCoalesceToTheLatestFrame
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:nil];
	FxGripLiveImageView *view = [self hostedViewForParameter:parameter];
	FxGripLiveFrame *last = nil;
	for (uint8_t fill = 0; fill < 20; fill++) {
		last = [self frameWithWidth:2 height:2 fill:fill];
		[parameter publishFrame:last inSlot:0];
	}

	XCTAssertTrue([self pumpUntilView:view showsFrame:last inSlot:0]);
}

- (void)testPublishingFromABackgroundThreadReachesTheView
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:nil];
	FxGripLiveImageView *view = [self hostedViewForParameter:parameter];
	FxGripLiveFrame *frame = [self frameWithWidth:2 height:2 fill:0x77];

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		[parameter publishFrame:frame inSlot:0];
	});

	XCTAssertTrue([self pumpUntilView:view showsFrame:frame inSlot:0]);
}

- (void)testClearingASlotEmptiesTheView
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:@{kFxGripLiveImageKey_Slots: @2}];
	FxGripLiveImageView *view = [self hostedViewForParameter:parameter];
	FxGripLiveFrame *frame = [self frameWithWidth:2 height:2 fill:0x55];
	[parameter publishFrame:frame inSlot:0];
	[parameter publishFrame:frame inSlot:1];
	XCTAssertTrue([self pumpUntilView:view showsFrame:frame inSlot:1]);

	[parameter clearSlot:0];
	XCTAssertTrue([self pumpUntilView:view showsFrame:nil inSlot:0]);
	XCTAssertTrue([view frameInSlot:1] == frame);

	[parameter clearAllSlots];
	XCTAssertTrue([self pumpUntilView:view showsFrame:nil inSlot:1]);
	XCTAssertNil([parameter frameInSlot:1]);
}

- (void)testAnImageBufferPublishesAsAFrame
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:nil];
	[self hostedViewForParameter:parameter];
	uint8_t pixels[3 * 2 * 4] = {0};
	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:pixels rowBytes:12 width:3 height:2
																format:FxGripPixelFormatRGBA8U
														   compression:FxGripCompressionNone];

	XCTAssertTrue([parameter publishImageBuffer:buffer inSlot:0]);
	FxGripLiveFrame *frame = [parameter frameInSlot:0];
	XCTAssertEqual(frame.width, 3u);
	XCTAssertEqual(frame.height, 2u);
	XCTAssertFalse([parameter publishImageBuffer:(FxGripImageBuffer * _Nonnull)nil inSlot:0]);
}

- (void)testACGImagePublishesAsAnRGBA8Frame
{
	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:nil];
	[self hostedViewForParameter:parameter];
	FxGripLiveFrame *source = [self frameWithWidth:5 height:3 fill:0xFF];
	XCTSkipIf(source.CGImage == NULL, @"No CoreGraphics.");

	XCTAssertTrue([parameter publishCGImage:source.CGImage inSlot:0]);
	FxGripLiveFrame *frame = [parameter frameInSlot:0];
	XCTAssertEqual(frame.width, 5u);
	XCTAssertEqual(frame.height, 3u);
	XCTAssertEqual(frame.pixelFormat, MTLPixelFormatRGBA8Unorm);
	XCTAssertFalse([parameter publishCGImage:NULL inSlot:0]);
}

#pragma mark Metal

- (void)testATextureIsDownscaledToTheSnapshotSizeAndReadBack
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:@{kFxGripLiveImageKey_SnapshotSize: @16}];
	FxGripLiveImageView *view = [self hostedViewForParameter:parameter];
	id<MTLTexture> texture = [self textureWithDevice:device format:MTLPixelFormatRGBA8Unorm width:64 height:32 fill:0x80];

	XCTAssertTrue([parameter publishTexture:texture inSlot:0]);
	XCTAssertTrue([self pumpUntil:^BOOL{ return [view frameInSlot:0] != nil; } timeout:5.0]);

	FxGripLiveFrame *frame = [view frameInSlot:0];
	XCTAssertEqual(frame.width, 16u);
	XCTAssertEqual(frame.height, 8u);
	XCTAssertEqual(frame.pixelFormat, MTLPixelFormatRGBA8Unorm);
	// A constant source averages to itself through the mipmap chain.
	const uint8_t *bytes = frame.pixels.bytes;
	XCTAssertEqual(bytes[0], 0x80);
	XCTAssertEqual(bytes[frame.pixels.length - 1], 0x80);
}

- (void)testASnapshotSizeOfZeroReadsTheTextureAtFullSize
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:nil];
	parameter.snapshotSize = 0;
	FxGripLiveImageView *view = [self hostedViewForParameter:parameter];
	id<MTLTexture> texture = [self textureWithDevice:device format:MTLPixelFormatBGRA8Unorm width:40 height:24 fill:0x40];

	XCTAssertTrue([parameter publishTexture:texture inSlot:0]);
	XCTAssertTrue([self pumpUntil:^BOOL{ return [view frameInSlot:0] != nil; } timeout:5.0]);

	FxGripLiveFrame *frame = [view frameInSlot:0];
	XCTAssertEqual(frame.width, 40u);
	XCTAssertEqual(frame.height, 24u);
	XCTAssertEqual(frame.pixelFormat, MTLPixelFormatBGRA8Unorm);
	XCTAssertEqual(((const uint8_t *)frame.pixels.bytes)[0], 0x40);
}

- (void)testASourceSmallerThanTheSnapshotSizeIsNotScaled
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:@{kFxGripLiveImageKey_SnapshotSize: @256}];
	[self hostedViewForParameter:parameter];
	id<MTLTexture> texture = [self textureWithDevice:device format:MTLPixelFormatRGBA8Unorm width:12 height:10 fill:0x11];

	XCTAssertTrue([parameter publishTexture:texture inSlot:0]);
	XCTAssertTrue([self pumpUntil:^BOOL{ return [parameter frameInSlot:0] != nil; } timeout:5.0]);
	XCTAssertEqual([parameter frameInSlot:0].width, 12u);
	XCTAssertEqual([parameter frameInSlot:0].height, 10u);
}

- (void)testABatchPublishFillsEverySlotFromOneCommandBuffer
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:@{kFxGripLiveImageKey_Labels: @[@"A", @"B", @"C"],
																		  kFxGripLiveImageKey_SnapshotSize: @8}];
	FxGripLiveImageView *view = [self hostedViewForParameter:parameter];
	id<MTLTexture> first = [self textureWithDevice:device format:MTLPixelFormatRGBA8Unorm width:16 height:16 fill:0x10];
	id<MTLTexture> third = [self textureWithDevice:device format:MTLPixelFormatRGBA8Unorm width:32 height:8 fill:0x30];

	NSArray *batch = @[first, NSNull.null, third];
	XCTAssertTrue([parameter publishTextures:batch]);
	XCTAssertTrue([self pumpUntil:^BOOL{ return [view frameInSlot:0] != nil && [view frameInSlot:2] != nil; } timeout:5.0]);

	XCTAssertEqual([view frameInSlot:0].width, 8u);
	XCTAssertEqual(((const uint8_t *)[view frameInSlot:0].pixels.bytes)[0], 0x10);
	XCTAssertNil([view frameInSlot:1]);
	XCTAssertEqual([view frameInSlot:2].width, 8u);
	XCTAssertEqual([view frameInSlot:2].height, 2u);
	XCTAssertEqual(((const uint8_t *)[view frameInSlot:2].pixels.bytes)[0], 0x30);
}

- (void)testAnUnsupportedTextureFormatIsRefused
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:nil];
	[self hostedViewForParameter:parameter];
	id<MTLTexture> texture = [self textureWithDevice:device format:MTLPixelFormatRG8Unorm width:8 height:8 fill:0];

	XCTAssertFalse([parameter publishTexture:texture inSlot:0]);
	XCTAssertFalse([parameter publishTexture:(id<MTLTexture> _Nonnull)nil inSlot:0]);
	XCTAssertFalse([parameter publishTextures:@[NSNull.null]]);
	XCTAssertFalse([parameter publishTextures:@[]]);
}

- (void)testATexturePublishOutsideTheSlotsIsRefused
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:nil];
	[self hostedViewForParameter:parameter];
	id<MTLTexture> texture = [self textureWithDevice:device format:MTLPixelFormatRGBA8Unorm width:8 height:8 fill:0];

	XCTAssertFalse([parameter publishTexture:texture inSlot:1]);
}

- (void)testAStagingTextureIsReusedAcrossPublishes
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	FxGripLiveImageParameter *parameter = [self makeParameterWithDefault:@{kFxGripLiveImageKey_SnapshotSize: @4}];
	[self hostedViewForParameter:parameter];
	id<MTLTexture> texture = [self textureWithDevice:device format:MTLPixelFormatRGBA8Unorm width:16 height:16 fill:0x20];

	XCTAssertTrue([parameter publishTexture:texture inSlot:0]);
	XCTAssertTrue([self pumpUntil:^BOOL{ return [parameter frameInSlot:0] != nil; } timeout:5.0]);
	FxGripLiveFrame *first = [parameter frameInSlot:0];

	id<MTLTexture> next = [self textureWithDevice:device format:MTLPixelFormatRGBA8Unorm width:16 height:16 fill:0x60];
	XCTAssertTrue([parameter publishTexture:next inSlot:0]);
	XCTAssertTrue([self pumpUntil:^BOOL{ return [parameter frameInSlot:0] != first; } timeout:5.0]);

	XCTAssertEqual([parameter frameInSlot:0].width, 4u);
	XCTAssertEqual(((const uint8_t *)[parameter frameInSlot:0].pixels.bytes)[0], 0x60);
}

@end
