//
//  FxGripDocImageGen.m
//  FxGripTests
//
//  Renders each FxGrip custom-parameter view to a PNG for the DocC catalog. It is a generator, not
//  an assertion suite: it is gated by a marker file so an ordinary test run skips it, and it writes
//  into the source tree. To regenerate the images:
//
//      touch /tmp/fxgrip-gen-doc
//      xcodebuild test -project FxGrip.xcodeproj -scheme FxGrip -destination 'platform=macOS' \
//          -only-testing:FxGripTests/FxGripDocImageGen
//
//  It must run in a logged-in session: NSView bitmap caching needs a window server. The test bundle
//  does not link AppKit; every AppKit class is reached by name, and the render path is instance
//  messages the linked FxGrip views already answer, so nothing AppKit is referenced at link time.
//

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripWebViewParameter.h>
#import <FxGrip/FxGripWebView.h>
#import <FxGrip/FxGripVideoViewParameter.h>
#import <FxGrip/FxGripVideoView.h>
#import <FxGrip/FxGripLiveImageParameter.h>
#import <FxGrip/FxGripLiveImage.h>
#import <FxGrip/FxGripLiveFrame.h>
#import <FxGrip/FxGripStatusParameter.h>
#import <FxGrip/FxGripProgressParameter.h>
#import <FxGrip/FxGripBannerParameter.h>
#import <FxGrip/FxGripBanner.h>
#import <FxGrip/FxGripCapsuleParameter.h>
#import <FxGrip/FxGripCapsule.h>
#import <FxGrip/FxGripSectionParameter.h>
#import <FxGrip/FxGripSection.h>
#import <FxGrip/FxGripRandomParameter.h>
#import <FxGrip/FxGripRandom.h>
#import <FxGrip/FxGripSwitchParameter.h>
#import <FxGrip/FxGripCurveEditorView.h>
#import <FxGrip/FxGripCurveData.h>
#import <BEFoundation/BEDotView.h>

static NSString *FxGripDocImageMarkerPath = @"/tmp/fxgrip-gen-doc";

/*! NSEvent's synthetic-mouse factory, reached by name so the bundle links no AppKit. */
@protocol FxGripDocEventFactory <NSObject>
+ (nullable id)mouseEventWithType:(NSEventType)type
						 location:(NSPoint)location
					modifierFlags:(NSEventModifierFlags)flags
						timestamp:(NSTimeInterval)time
					 windowNumber:(NSInteger)windowNumber
						  context:(nullable id)context
					  eventNumber:(NSInteger)eventNumber
					   clickCount:(NSInteger)clickCount
						 pressure:(float)pressure;
@end

/*! The curve editor's internal geometry, used to place a synthetic click on a point. */
@interface FxGripCurveEditorView (FxGripDocImageGen)
- (NSPoint)viewPointForCurvePoint:(CGPoint)point;
@end

@interface FxGripDocImageGen : XCTestCase
@end

@implementation FxGripDocImageGen

- (void)setUp
{
	[super setUp];
	if (![NSFileManager.defaultManager fileExistsAtPath:FxGripDocImageMarkerPath]) {
		XCTSkip("Doc-image generator is gated; touch %@ to run it.", FxGripDocImageMarkerPath);
	}
	// NSView display caching needs an application and a window-server connection.
	[NSClassFromString(@"NSApplication") sharedApplication];
}

#pragma mark Output location

/*! The DocC image directory, derived from this source file's path so the generator writes into the
	repository regardless of the build's working directory. */
- (NSString *)imageDirectory
{
	NSString *thisFile = @(__FILE__);                                  // .../FxGripTests/FxGripDocImageGen.m
	NSString *repoRoot = thisFile.stringByDeletingLastPathComponent    // .../FxGripTests
							  .stringByDeletingLastPathComponent;        // repo root
	NSString *directory = [repoRoot stringByAppendingPathComponent:@"FxGrip/FxGrip.docc/Resources/img/CustomControls"];
	[NSFileManager.defaultManager createDirectoryAtPath:directory
							withIntermediateDirectories:YES
											 attributes:nil
												  error:NULL];
	return directory;
}

#pragma mark Render

// The images render at 2x for retina DocC display. The filename carries the @2x suffix DocC reads.
static const CGFloat kFxGripDocImageScale = 2.0;

/*! Sizes the view, caches its display into a 2x bitmap, and writes an @2x PNG. */
- (void)renderView:(NSView *)view size:(NSSize)size named:(NSString *)name
{
	view.frame = NSMakeRect(0, 0, size.width, size.height);
	[view layoutSubtreeIfNeeded];
	[self writeView:view named:name];
}

/*! Caches the view's display into a 2x bitmap rep and writes it as <name>@2x.png. NSBitmapImageRep
	is reached by name and given a literal color-space name so the test bundle links no AppKit. */
- (void)writeView:(NSView *)view named:(NSString *)name
{
	NSRect bounds = view.bounds;
	Class repClass = NSClassFromString(@"NSBitmapImageRep");
	NSBitmapImageRep *rep = [[repClass alloc]
		initWithBitmapDataPlanes:NULL
					  pixelsWide:(NSInteger)(bounds.size.width * kFxGripDocImageScale)
					  pixelsHigh:(NSInteger)(bounds.size.height * kFxGripDocImageScale)
				   bitsPerSample:8
				 samplesPerPixel:4
						hasAlpha:YES
						isPlanar:NO
				  colorSpaceName:@"NSDeviceRGBColorSpace"
					 bytesPerRow:0
					bitsPerPixel:0];
	XCTAssertNotNil(rep, @"%@: no bitmap rep", name);
	rep.size = bounds.size;   // point size with 2x pixels sets the backing scale
	[view cacheDisplayInRect:bounds toBitmapImageRep:rep];

	[self writeRep:rep named:name];
}

/*! Encodes a bitmap rep as PNG and writes it as <name>@2x.png. */
- (void)writeRep:(NSBitmapImageRep *)rep named:(NSString *)name
{
	NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	XCTAssertGreaterThan(png.length, 0u, @"%@: empty PNG", name);

	NSString *file = [NSString stringWithFormat:@"%@@2x.png", name];
	NSString *path = [self.imageDirectory stringByAppendingPathComponent:file];
	XCTAssertTrue([png writeToFile:path atomically:YES], @"%@: could not write %@", name, path);
	NSLog(@"[doc-image] wrote %@ (%lu bytes)", path, (unsigned long)png.length);
}

#pragma mark Controls

- (void)testStatus
{
	FxGripStatusView *view = [FxGripStatusView.alloc initWithFrame:NSZeroRect];
	FxGripDictionary *value = [FxGripDictionary dictionaryWithDictionary:@{
		kCustomAPI_IntKey:    @(BEDotStateOk),
		kCustomAPI_StringKey: @"Ready",
	}];
	[view updateFromCustomData:value];
	[self renderView:view size:NSMakeSize(220, 22) named:@"status"];
}

- (void)testProgress
{
	FxGripProgressView *view = [FxGripProgressView.alloc initWithFrame:NSZeroRect];
	FxGripDictionary *value = [FxGripDictionary dictionaryWithDictionary:@{
		kCustomAPI_IntKey:    @(BEDotStateActive),
		kCustomAPI_StringKey: @"Exporting",
		kCustomAPI_FloatKey:  @0.62,
	}];
	[view updateFromCustomData:value];
	[self renderView:view size:NSMakeSize(240, 40) named:@"progress"];
}

- (void)testBanner
{
	FxGripBannerView *view = [FxGripBannerView.alloc initWithFrame:NSZeroRect];
	FxGripDictionary *value = [FxGripDictionary dictionaryWithDictionary:@{
		kFxGripBannerKey_Title:    @"Rendering",
		kFxGripBannerKey_Subtitle: @"Frame 120 of 240",
	}];
	[view updateFromCustomData:value];
	[self renderView:view size:NSMakeSize(300, 48) named:@"banner"];
}

- (void)testCapsule
{
	FxGripCapsuleView *view = [FxGripCapsuleView.alloc initWithFrame:NSZeroRect];
	FxGripDictionary *value = [FxGripDictionary dictionaryWithDictionary:@{
		kFxGripCapsuleKey_Title: @"Beta",
	}];
	[view updateFromCustomData:value];
	// Size the pill from the measured label so the tail is not clipped: the control's own
	// intrinsic size is read before the label's cell settles and comes out a character wide.
	NSTextField *label = (NSTextField *)view.subviews.firstObject;
	[label sizeToFit];
	NSSize text = label.frame.size;
	NSSize fitting = NSMakeSize(ceil(text.width) + 24.0, ceil(text.height) + 8.0);
	label.frame = NSMakeRect(12.0, 4.0, fitting.width - 24.0, fitting.height - 8.0);
	[self renderView:view size:fitting named:@"capsule"];
}

- (void)testSection
{
	FxGripSectionView *view = [FxGripSectionView.alloc initWithFrame:NSZeroRect];
	// The section view reads an FxGripSectionData or a plain dictionary of the section keys.
	NSDictionary *value = @{
		kFxGripSectionKey_Title:     @"Color",
		kFxGripSectionKey_Transform: @(FxGripSectionTransformUppercase),
		kFxGripSectionKey_Size:      @13.0,
	};
	[view updateFromCustomData:value];
	[self renderView:view size:NSMakeSize(300, 24) named:@"section"];
}

- (void)testDivider
{
	// FXBox is an internal class; the divider control vends it. Reach it by name.
	NSView *box = [[NSClassFromString(@"FXBox") alloc] initWithFrame:NSZeroRect];
	XCTAssertNotNil(box, @"FXBox not found in the runtime");
	[self renderView:box size:NSMakeSize(300, 11) named:@"divider"];
}

- (void)testRandom
{
	FxGripRandomView *view = [FxGripRandomView.alloc initWithFrame:NSZeroRect];
	FxGripDictionary *value = [FxGripDictionary dictionaryWithDictionary:@{
		kFxGripRandomKey_Value: @1234,
		kFxGripRandomKey_Min:   @1,
		kFxGripRandomKey_Max:   @100000,
		kFxGripRandomKey_Step:  @1,
	}];
	[view updateFromCustomData:value];
	[self renderView:view size:NSMakeSize(200, 24) named:@"random"];
}

- (void)testSwitch
{
	FxGripSwitchView *view = [FxGripSwitchView.alloc initWithFrame:NSZeroRect];
	FxGripDictionary *value = [FxGripDictionary dictionaryWithDictionary:@{
		kCustomAPI_BoolKey: @YES,
	}];
	[view updateFromCustomData:value];
	NSSize fitting = view.intrinsicContentSize;
	if (fitting.width <= 0 || fitting.height <= 0) {
		fitting = NSMakeSize(42, 22);
	}
	[self renderView:view size:fitting named:@"switch"];
}

- (void)testCurve
{
	CGPoint points[4] = { {0.0, 0.0}, {0.3, 0.12}, {0.7, 0.88}, {1.0, 1.0} };
	FxGripCurveData *curve = [FxGripCurveData curveWithPoints:points
													   count:4
														role:FxGripCurveRoleRemap
													  domain:FxGripCurveDomainLinear];
	FxGripCurveEditorView *view = [FxGripCurveEditorView.alloc initWithFrame:NSZeroRect];
	view.curve = curve;
	[self renderView:view size:NSMakeSize(180, 110) named:@"curve"];
}

- (void)testCurveHue
{
	// The hue-spectrum background renders the hue across the x-axis, for a curve over hue.
	FxGripCurveEditorView *view = [FxGripCurveEditorView.alloc initWithFrame:NSZeroRect
																	   role:FxGripCurveRoleShift
																	 domain:FxGripCurveDomainCircular
																 background:FxGripCurveBackgroundHueSpectrum];
	CGPoint points[3] = { {0.0, 0.5}, {0.5, 0.72}, {1.0, 0.5} };
	view.curve = [FxGripCurveData curveWithPoints:points count:3
											 role:FxGripCurveRoleShift domain:FxGripCurveDomainCircular];
	[self renderView:view size:NSMakeSize(180, 110) named:@"curve-hue"];
}

- (void)testCurveColoredLine
{
	// A channel curve colors its line; here a red line over the red ramp.
	FxGripCurveEditorView *view = [FxGripCurveEditorView.alloc initWithFrame:NSZeroRect
																	   role:FxGripCurveRoleRemap
																	 domain:FxGripCurveDomainLinear
																 background:FxGripCurveBackgroundRedRamp];
	CGPoint points[4] = { {0.0, 0.0}, {0.3, 0.18}, {0.7, 0.82}, {1.0, 1.0} };
	view.curve = [FxGripCurveData curveWithPoints:points count:4
											 role:FxGripCurveRoleRemap domain:FxGripCurveDomainLinear];
	view.lineColor = [(id)NSClassFromString(@"NSColor") redColor];
	[self renderView:view size:NSMakeSize(180, 110) named:@"curve-color"];
}

- (FxGripCurveEditorView *)galleryCurveEditor
{
	FxGripCurveEditorView *view = [FxGripCurveEditorView.alloc initWithFrame:NSZeroRect
																	   role:FxGripCurveRoleRemap
																	 domain:FxGripCurveDomainLinear
																 background:FxGripCurveBackgroundGrid];
	CGPoint points[4] = { {0.0, 0.0}, {0.3, 0.18}, {0.7, 0.82}, {1.0, 1.0} };
	view.curve = [FxGripCurveData curveWithPoints:points count:4
											 role:FxGripCurveRoleRemap domain:FxGripCurveDomainLinear];
	return view;
}

- (void)testCurveLineHue
{
	// The line itself stroked as the hue spectrum, over a grid.
	FxGripCurveEditorView *view = [self galleryCurveEditor];
	view.lineStyle = FxGripCurveLineStyleHue;
	[self renderView:view size:NSMakeSize(180, 110) named:@"curve-line-hue"];
}

- (void)testCurveVerticalHueFade
{
	// Hue on the y: full spectrum at the top, fading to the base at the bottom.
	FxGripCurveEditorView *view = [self galleryCurveEditor];
	view.topPaint = [FxGripCurvePaint huePaint];
	view.bottomPaint = [FxGripCurvePaint nonePaint];
	[self renderView:view size:NSMakeSize(180, 110) named:@"curve-v-huefade"];
}

- (void)testCurveVerticalTwoColor
{
	// Two-color vertical fade: top color to bottom color, no center stop.
	Class colorClass = NSClassFromString(@"NSColor");
	FxGripCurveEditorView *view = [self galleryCurveEditor];
	view.topPaint = [FxGripCurvePaint paintWithColor:[colorClass systemPurpleColor]];
	view.bottomPaint = [FxGripCurvePaint paintWithColor:[colorClass systemTealColor]];
	[self renderView:view size:NSMakeSize(180, 110) named:@"curve-v-twocolor"];
}

- (void)testCurveCenterHueBand
{
	// A hue band through the center, fading to the base top and bottom.
	FxGripCurveEditorView *view = [self galleryCurveEditor];
	view.topPaint = [FxGripCurvePaint nonePaint];
	view.centerPaint = [FxGripCurvePaint huePaint];
	view.bottomPaint = [FxGripCurvePaint nonePaint];
	[self renderView:view size:NSMakeSize(180, 110) named:@"curve-v-hueband"];
}

- (void)testCurveBlackHueWhite
{
	// Black at top, the hue spectrum through the center, white at bottom: shade above, tint below.
	Class colorClass = NSClassFromString(@"NSColor");
	FxGripCurveEditorView *view = [self galleryCurveEditor];
	view.topPaint = [FxGripCurvePaint paintWithColor:[colorClass blackColor]];
	view.centerPaint = [FxGripCurvePaint huePaint];
	view.bottomPaint = [FxGripCurvePaint paintWithColor:[colorClass whiteColor]];
	[self renderView:view size:NSMakeSize(180, 110) named:@"curve-v-blackhuewhite"];
}

/*! Selects a curve point by sending the editor a synthetic click at its location (no window needed:
	an eventless view maps window coordinates through the identity transform). */
- (void)selectPointIndex:(NSUInteger)index inEditor:(FxGripCurveEditorView *)view
{
	NSPoint at = [view viewPointForCurvePoint:[view.curve pointAtIndex:index]];
	id<FxGripDocEventFactory> factory = (id<FxGripDocEventFactory>)NSClassFromString(@"NSEvent");
	NSEvent *down = [factory mouseEventWithType:NSEventTypeLeftMouseDown location:at modifierFlags:0
									 timestamp:0 windowNumber:0 context:nil eventNumber:0 clickCount:1 pressure:1.0];
	[view mouseDown:down];
	NSEvent *up = [factory mouseEventWithType:NSEventTypeLeftMouseUp location:at modifierFlags:0
								   timestamp:0 windowNumber:0 context:nil eventNumber:0 clickCount:1 pressure:1.0];
	[view mouseUp:up];
}

- (FxGripCurveEditorView *)readoutEditorWithStyle:(FxGripCurveReadoutStyle)style units:(FxGripCurveReadoutUnits)units
{
	FxGripCurveEditorView *view = [self galleryCurveEditor];
	view.frame = NSMakeRect(0, 0, 200, 120);
	[self selectPointIndex:2 inEditor:view];   // an interior point
	view.pointReadoutStyle = style;
	view.pointReadoutUnits = units;
	return view;
}

- (void)testCurveReadoutFloatingChip
{
	FxGripCurveEditorView *view = [self readoutEditorWithStyle:FxGripCurveReadoutStyleFloatingChip
														units:FxGripCurveReadoutUnitsEightBit];
	[self renderView:view size:NSMakeSize(200, 120) named:@"curve-readout-chip"];
}

- (void)testCurveReadoutAxis
{
	FxGripCurveEditorView *view = [self readoutEditorWithStyle:FxGripCurveReadoutStyleAxis
														units:FxGripCurveReadoutUnitsPercent];
	[self renderView:view size:NSMakeSize(200, 120) named:@"curve-readout-axis"];
}

- (void)testCurveReadoutCorner
{
	FxGripCurveEditorView *view = [self readoutEditorWithStyle:FxGripCurveReadoutStyleCorner
														units:FxGripCurveReadoutUnitsNormalized];
	[self renderView:view size:NSMakeSize(200, 120) named:@"curve-readout-corner"];
}

#pragma mark Out-of-process capture helpers

/*! Puts the view in a borderless window so a control that defers its WKWebView / AVPlayerView until
	it enters a window creates it. The window renders at the main screen's 2x backing scale. */
- (NSWindow *)windowHostingView:(NSView *)view size:(NSSize)size
{
	view.frame = NSMakeRect(0, 0, size.width, size.height);
	NSWindow *window = [[NSClassFromString(@"NSWindow") alloc]
		initWithContentRect:NSMakeRect(0, 0, size.width, size.height)
				  styleMask:NSWindowStyleMaskBorderless
					backing:NSBackingStoreBuffered
					  defer:NO];
	window.contentView = view;
	[window orderFrontRegardless];   // realize the surface so the web/video content renders
	return window;
}

/*! Spins the run loop until the predicate returns YES or the timeout elapses. Async WebKit and
	AVFoundation callbacks land on the main run loop, so the generator must pump it to receive them. */
- (BOOL)pumpUntil:(BOOL (^)(void))ready timeout:(NSTimeInterval)timeout
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!ready() && deadline.timeIntervalSinceNow > 0.0) {
		[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode
							   beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	}
	return ready();
}

/*! The first WKWebView in the view tree, found by name so the bundle links no WebKit. */
- (nullable WKWebView *)webViewInside:(NSView *)view
{
	Class webViewClass = NSClassFromString(@"WKWebView");
	for (NSView *subview in view.subviews) {
		if ([subview isKindOfClass:webViewClass]) {
			return (WKWebView *)subview;
		}
		WKWebView *found = [self webViewInside:subview];
		if (found != nil) {
			return found;
		}
	}
	return nil;
}

/*! Writes an NSImage as <name>@2x.png at its pixel resolution. */
- (void)writeImage:(NSImage *)image named:(NSString *)name
{
	CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
	XCTAssertTrue(cgImage != NULL, @"%@: no CGImage from snapshot", name);
	Class repClass = NSClassFromString(@"NSBitmapImageRep");
	NSBitmapImageRep *rep = [[repClass alloc] initWithCGImage:cgImage];
	[self writeRep:rep named:name];
}

#pragma mark Web and video

/*! Loads HTML into the control's embedded WKWebView, waits for it to render, snapshots it, and
	writes the result. The web control hosts a WKWebView directly; the video control hosts one in its
	embed mode, so both capture through this one path. */
- (void)captureEmbedInView:(NSView *)view size:(NSSize)size html:(NSString *)html named:(NSString *)name
{
	NSWindow *window = [self windowHostingView:view size:size];
	WKWebView *webView = [self webViewInside:view];
	XCTAssertNotNil(webView, @"%@: the control did not create a WKWebView on screen", name);

	// The control's navigation delegate gates every URL against its whitelist, which cancels a
	// direct loadHTMLString: (base about:blank). Detach it so the generator's own content renders.
	webView.navigationDelegate = nil;
	[webView loadHTMLString:html baseURL:nil];

	[self pumpUntil:^BOOL{ return NO; } timeout:0.3];   // let the load begin
	XCTAssertTrue([self pumpUntil:^BOOL{ return webView.estimatedProgress >= 1.0 && !webView.isLoading; }
						  timeout:8.0], @"%@: the page did not finish loading", name);
	[self pumpUntil:^BOOL{ return NO; } timeout:0.5];   // let the first paint settle

	__block NSImage *snapshot = nil;
	__block BOOL done = NO;
	[webView takeSnapshotWithConfiguration:nil completionHandler:^(NSImage *image, NSError *error) {
		snapshot = image;
		done = YES;
	}];
	XCTAssertTrue([self pumpUntil:^BOOL{ return done; } timeout:8.0], @"%@: snapshot timed out", name);
	XCTAssertNotNil(snapshot, @"%@: nil snapshot", name);

	[self writeImage:snapshot named:name];
	(void)window;
}

- (void)testWebView
{
	FxGripWebPageView *view = [FxGripWebPageView.alloc initWithFrame:NSZeroRect];
	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{
		kFxGripWebViewKey_URL:       @"about:blank",
		kFxGripWebViewKey_Whitelist: @[ @"*" ],
	}]];

	NSString *html =
		@"<html><head><meta name='viewport' content='width=device-width'>"
		 "<style>body{font:14px -apple-system,system-ui;margin:0;padding:22px;color:#1d1d1f;"
		 "background:#fff}h1{font-size:20px;margin:0 0 10px}p{line-height:1.55;color:#4b4b50;margin:0}"
		 ".tag{display:inline-block;background:#7A1FA2;color:#fff;padding:2px 9px;border-radius:10px;"
		 "font-size:12px;margin-bottom:12px}</style></head><body>"
		 "<span class='tag'>FxGrip</span><h1>Plugin Help</h1>"
		 "<p>The web view parameter embeds a whitelisted page in the inspector, so a plugin ships "
		 "its documentation next to its controls.</p></body></html>";
	[self captureEmbedInView:view size:NSMakeSize(320, 180) html:html named:@"webview"];
}

- (void)testVideo
{
	// A remote, whitelisted, non-media URL routes the video control to its WKWebView embed mode,
	// where a hosted player page shows. Local player-style content keeps the image offline.
	FxGripVideoView *view = [FxGripVideoView.alloc initWithFrame:NSZeroRect];
	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{
		kFxGripVideoKey_URL:       @"https://example.com/embed",
		kFxGripVideoKey_Whitelist: @[ @"*" ],
	}]];

	NSString *html =
		@"<html><head><style>html,body{margin:0;height:100%;background:#000;"
		 "font:13px -apple-system,system-ui}"
		 ".stage{position:relative;height:100%;background:linear-gradient(135deg,#2a2a35,#0e0e12)}"
		 ".play{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:62px;"
		 "height:62px;border-radius:50%;background:rgba(255,255,255,.92);display:flex;"
		 "align-items:center;justify-content:center}"
		 ".play:after{content:'';border-style:solid;border-width:11px 0 11px 19px;"
		 "border-color:transparent transparent transparent #111;margin-left:5px}"
		 ".bar{position:absolute;left:0;right:0;bottom:0;padding:10px 14px;color:#fff;"
		 "background:linear-gradient(transparent,rgba(0,0,0,.55))}"
		 ".track{height:4px;border-radius:2px;background:rgba(255,255,255,.3)}"
		 ".fill{height:4px;width:38%;border-radius:2px;background:#7A1FA2}"
		 ".time{font-size:12px;margin-top:6px;opacity:.9}</style></head><body>"
		 "<div class='stage'><div class='play'></div>"
		 "<div class='bar'><div class='track'><div class='fill'></div></div>"
		 "<div class='time'>0:34 / 1:30</div></div></div></body></html>";
	[self captureEmbedInView:view size:NSMakeSize(320, 180) html:html named:@"video"];
}

#pragma mark Live image

/*! An RGBA8 frame shading a horizontal ramp of the tint over a vertical luminance ramp, so
	each slot reads as a distinct picture. */
- (FxGripLiveFrame *)liveFrameWithWidth:(NSUInteger)width height:(NSUInteger)height tint:(NSUInteger)tint
{
	NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
	uint8_t *bytes = pixels.mutableBytes;
	for (NSUInteger y = 0; y < height; y++) {
		for (NSUInteger x = 0; x < width; x++) {
			uint8_t *pixel = bytes + (y * width + x) * 4;
			uint8_t ramp = (uint8_t)(255 * x / (width - 1));
			uint8_t shade = (uint8_t)(255 - 200 * y / (height - 1));
			pixel[0] = (uint8_t)((tint & 1) ? shade : ramp / 3);
			pixel[1] = (uint8_t)((tint & 2) ? shade : ramp / 2);
			pixel[2] = (uint8_t)((tint & 4) ? shade : ramp);
			pixel[3] = 255;
		}
	}
	return [FxGripLiveFrame frameWithBytes:pixels.bytes rowBytes:width * 4 width:width height:height
							   pixelFormat:MTLPixelFormatRGBA8Unorm];
}

- (void)testLiveImage
{
	FxGripLiveImageView *view = [FxGripLiveImageView.alloc initWithFrame:NSZeroRect];
	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{
		kFxGripLiveImageKey_Labels: @[@"Channel A", @"Channel B", @"Channel C", @"Channel D"],
		kFxGripLiveImageKey_Height: @96.0,
	}]];
	[view showFrame:[self liveFrameWithWidth:160 height:90 tint:1] inSlot:0];
	[view showFrame:[self liveFrameWithWidth:160 height:90 tint:2] inSlot:1];
	[view showFrame:[self liveFrameWithWidth:90 height:90 tint:4] inSlot:2];
	[self renderView:view size:NSMakeSize(360, 96) named:@"liveimage"];
}

@end
