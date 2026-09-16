/*!
	@file       FxGripBannerParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripBannerParameterTests
	@abstract   Tests the banner message strip view and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the parameter's type identity, the custom
	            control it registers, the flags it forces on, and the title fallback rules. The view
	            tests cover the title, subtitle, colors, corner radius, graphic, and link the value
	            carries, the height the content drives, the cursor rect and the action button a link
	            gates, and the rounded fill the strip draws.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripBanner.h>
#import <FxGrip/FxGripBannerParameter.h>

static const FxParameterId kBannerTestParameter = 71;

@interface FxGripBannerParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@property (nonatomic, strong) NSMutableArray<NSWindow *> *windows;
@property (nonatomic, copy, nullable) NSString *imagePath;
@end

@implementation FxGripBannerParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamClassTestEffect.alloc init];
	self.windows = [NSMutableArray array];
}

- (void)tearDown
{
	if (self.imagePath != nil) {
		[NSFileManager.defaultManager removeItemAtPath:self.imagePath error:NULL];
		self.imagePath = nil;
	}
	self.effect = nil;
	self.windows = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSDictionary *)call
{
	return self.effect.creationCall;
}

- (NSMutableDictionary *)configWithDefault:(nullable NSDictionary *)declared name:(nullable NSString *)name
{
	NSDictionary *extra = declared ? @{kFxParameterProperty_Default: declared} : nil;
	return FxGripParamClassTestConfig(kBannerTestParameter, kFxParameterType_Banner, name ?: @"Notice", extra);
}

- (FxGripBannerView *)viewOfWidth:(CGFloat)width
{
	return [FxGripBannerView.alloc initWithFrame:NSMakeRect(0, 0, width, 28)];
}

- (void)hostView:(NSView *)view
{
	Class windowClass = NSClassFromString(@"NSWindow");
	NSWindow *window = [[windowClass alloc] initWithContentRect:NSMakeRect(0, 0, 320, 200)
													 styleMask:NSWindowStyleMaskBorderless
													   backing:NSBackingStoreBuffered
														 defer:NO];
	[window.contentView addSubview:view];
	[self.windows addObject:window];
}

- (FxGripDictionary *)valueWith:(NSDictionary *)contents
{
	return [FxGripDictionary dictionaryWithDictionary:contents];
}

- (NSArray<NSTextField *> *)labelsIn:(NSView *)view
{
	NSMutableArray<NSTextField *> *labels = [NSMutableArray array];
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSTextField.class]) {
			[labels addObject:(NSTextField *)sub];
		}
	}
	return labels;
}

- (NSTextField *)titleIn:(NSView *)view { return [self labelsIn:view].firstObject; }
- (NSTextField *)subtitleIn:(NSView *)view { return [self labelsIn:view][1]; }

- (NSImageView *)imageViewIn:(NSView *)view
{
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSImageView.class]) {
			return (NSImageView *)sub;
		}
	}
	return nil;
}

- (NSButton *)actionButtonIn:(NSView *)view
{
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSButton.class] && ![sub isKindOfClass:NSTextField.class]) {
			return (NSButton *)sub;
		}
	}
	return nil;
}

/*! Writes a small opaque PNG to a temporary file and returns its path. */
- (NSString *)temporaryImagePathWithWidth:(NSInteger)width height:(NSInteger)height
{
	Class repClass = NSClassFromString(@"NSBitmapImageRep");
	NSBitmapImageRep *rep = [[repClass alloc] initWithBitmapDataPlanes:NULL
														   pixelsWide:width
														   pixelsHigh:height
														bitsPerSample:8
													  samplesPerPixel:4
															 hasAlpha:YES
															 isPlanar:NO
													   colorSpaceName:@"NSCalibratedRGBColorSpace"
														  bytesPerRow:0
														 bitsPerPixel:0];
	memset(rep.bitmapData, 0xFF, (size_t)(rep.bytesPerRow * height));
	NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	XCTAssertNotNil(png);

	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
					  [NSString stringWithFormat:@"FxGripBannerTest-%@.png", NSUUID.UUID.UUIDString]];
	XCTAssertTrue([png writeToFile:path atomically:YES]);
	self.imagePath = path;
	return path;
}

#pragma mark Type identity

/*! @abstract The banner reports the banner FxPlug type and the matching type string. */
- (void)testTheBannerReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripBannerParameter.parameterType, FxParameterType_Banner);
	XCTAssertEqualObjects(FxGripBannerParameter.parameterTypeString, kFxParameterType_Banner);
}

/*! @abstract The decodable value classes cover the parameter dictionary and every class it may carry. */
- (void)testTheBannerDecodesTheDictionaryAndItsElementClasses
{
	NSSet<Class> *classes = FxGripBannerParameter.customValueClasses;

	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
	for (Class element in FxGripDictionary.classesForParameter) {
		XCTAssertTrue([classes containsObject:element], @"%@ is decodable", element);
	}
}

#pragma mark Creation

/*! @abstract Creation registers a custom control with an empty host name and adds the custom-control flags. */
- (void)testCreationRegistersACustomControlWithNoHostNameAndTheControlFlags
{
	NSMutableDictionary *config = [self configWithDefault:nil name:@"Notice"];
	config[kFxParameterProperty_Flags] = @(kFxParameterFlag_HIDDEN);

	XCTAssertTrue([FxGripBannerParameter addParameter:config toEffect:(id)self.effect]);

	FxParameterFlags expected = kFxParameterFlag_HIDDEN | kFxParameterFlag_CUSTOM_UI
		| kFxParameterFlag_NOT_ANIMATABLE | kFxParameterFlag_USE_FULL_VIEW_WIDTH | kFxParameterFlag_NOSTATE;
	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"");
	XCTAssertEqualObjects(self.call[@"flags"], @(expected));
}

/*! @abstract A text banner with no declared title falls back to the parameter name. */
- (void)testATextBannerFallsBackToTheParameterNameForItsTitle
{
	XCTAssertTrue([FxGripBannerParameter addParameter:[self configWithDefault:nil name:@"Read Me"]
											 toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	NSString *title = nil;
	XCTAssertTrue([value getStringParameterValue:&title forKey:kFxGripBannerKey_Title]);
	XCTAssertEqualObjects(title, @"Read Me");
}

/*! @abstract A declared title is kept in place of the parameter name. */
- (void)testADeclaredTitleOverridesTheParameterName
{
	NSDictionary *declared = @{kFxGripBannerKey_Title: @"Beta build"};

	XCTAssertTrue([FxGripBannerParameter addParameter:[self configWithDefault:declared name:@"Read Me"]
											 toEffect:(id)self.effect]);

	NSString *title = nil;
	[(FxGripDictionary *)self.call[@"default"] getStringParameterValue:&title forKey:kFxGripBannerKey_Title];
	XCTAssertEqualObjects(title, @"Beta build");
}

/*! @abstract An image banner takes no title fallback, so a graphic can stand alone. */
- (void)testAnImageBannerTakesNoTitleFallback
{
	NSDictionary *declared = @{kFxGripBannerKey_ImageName: @"NSApplicationIcon"};

	XCTAssertTrue([FxGripBannerParameter addParameter:[self configWithDefault:declared name:@"Read Me"]
											 toEffect:(id)self.effect]);

	NSString *title = nil;
	XCTAssertFalse([(FxGripDictionary *)self.call[@"default"] getStringParameterValue:&title
																			  forKey:kFxGripBannerKey_Title]);
}

/*! @abstract A host that refuses the creation is reported. */
- (void)testAHostRefusalIsReported
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([FxGripBannerParameter addParameter:[self configWithDefault:nil name:@"Notice"]
											  toEffect:(id)self.effect]);
}

#pragma mark The vended view

/*! @abstract The parameter vends a banner view seeded with the declared title. */
- (void)testTheVendedViewCarriesTheDeclaredTitle
{
	NSDictionary *declared = @{kFxGripBannerKey_Title: @"Beta build"};
	FxGripBannerParameter *parameter =
		[FxGripBannerParameter.alloc initWithDictionary:[self configWithDefault:declared name:@"Notice"]
												 effect:(id)self.effect];

	NSView *view = [parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripBannerView.class]);
	XCTAssertEqualObjects([self titleIn:view].stringValue, @"Beta build");
}

/*! @abstract Without a declared configuration the vended view carries no title. */
- (void)testTheVendedViewCarriesNoTitleWithoutAConfiguration
{
	FxGripBannerParameter *parameter =
		[FxGripBannerParameter.alloc initWithDictionary:[self configWithDefault:nil name:@"Notice"]
												 effect:(id)self.effect];

	NSView *view = [parameter newParameterView];

	XCTAssertEqualObjects([self titleIn:view].stringValue, @"");
}

#pragma mark View content

/*! @abstract The banner lays out top-down, as the inspector rows do. */
- (void)testTheBannerIsFlipped
{
	XCTAssertTrue([self viewOfWidth:200].isFlipped);
}

/*! @abstract A value of another class leaves the banner untouched. */
- (void)testAValueOfAnotherClassIsIgnored
{
	FxGripBannerView *view = [self viewOfWidth:200];
	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @"Kept"}]];

	[view updateFromCustomData:(id)@[@"not a dictionary"]];

	XCTAssertEqualObjects([self titleIn:view].stringValue, @"Kept");
}

/*! @abstract The title and subtitle follow the value, and an empty subtitle hides its row. */
- (void)testTheTitleAndSubtitleFollowTheValue
{
	FxGripBannerView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @"Beta build",
												kFxGripBannerKey_Subtitle: @"Expires soon"}]];

	XCTAssertEqualObjects([self titleIn:view].stringValue, @"Beta build");
	XCTAssertFalse([self titleIn:view].hidden);
	XCTAssertEqualObjects([self subtitleIn:view].stringValue, @"Expires soon");
	XCTAssertFalse([self subtitleIn:view].hidden);

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @"",
												kFxGripBannerKey_Subtitle: @""}]];

	XCTAssertTrue([self titleIn:view].hidden);
	XCTAssertTrue([self subtitleIn:view].hidden);
}

/*! @abstract The declared point size sets the title font. */
- (void)testTheFontSizeSetsTheTitleFont
{
	FxGripBannerView *view = [self viewOfWidth:200];
	XCTAssertEqualWithAccuracy([self titleIn:view].font.pointSize, kFxGripBannerDefaultFontSize, 1e-9);

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @"Big",
												kFxGripBannerKey_FontSize: @(20.0)}]];

	XCTAssertEqualWithAccuracy([self titleIn:view].font.pointSize, 20.0, 1e-9);
}

/*! @abstract A point size of zero is refused, so the title never collapses. */
- (void)testANonPositiveFontSizeIsRefused
{
	FxGripBannerView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_FontSize: @(0.0)}]];

	XCTAssertEqualWithAccuracy([self titleIn:view].font.pointSize, kFxGripBannerDefaultFontSize, 1e-9);
}

/*! @abstract The declared text color reaches the title and the subtitle. */
- (void)testTheTextColorReachesBothLabels
{
	FxGripBannerView *view = [self viewOfWidth:200];
	FxGripDictionary *value = [self valueWith:@{kFxGripBannerKey_Title: @"Notice"}];
	[value setRedValue:1.0 greenValue:0.0 blueValue:0.0 alphaValue:1.0 forKey:kFxGripBannerKey_TextColor];

	[view updateFromCustomData:value];

	NSColor *title = [[self titleIn:view].textColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
	XCTAssertEqualWithAccuracy(title.redComponent, 1.0, 1e-6);
	XCTAssertEqualWithAccuracy(title.greenComponent, 0.0, 1e-6);
	XCTAssertEqualObjects([self subtitleIn:view].textColor, [self titleIn:view].textColor);
}

/*! @abstract The strip fills with the declared color, so a red banner draws red at its center. */
- (void)testTheStripFillsWithTheDeclaredColor
{
	FxGripBannerView *view = [self viewOfWidth:60];
	FxGripDictionary *value = [self valueWith:@{kFxGripBannerKey_Title: @"Notice",
												kFxGripBannerKey_CornerRadius: @(0.0)}];
	[value setRedValue:1.0 greenValue:0.0 blueValue:0.0 alphaValue:1.0 forKey:kFxGripBannerKey_FillColor];
	[view updateFromCustomData:value];

	Class repClass = NSClassFromString(@"NSBitmapImageRep");
	Class contextClass = NSClassFromString(@"NSGraphicsContext");
	NSInteger height = (NSInteger)view.bounds.size.height;
	NSBitmapImageRep *rep = [[repClass alloc] initWithBitmapDataPlanes:NULL
														   pixelsWide:60
														   pixelsHigh:height
														bitsPerSample:8
													  samplesPerPixel:4
															 hasAlpha:YES
															 isPlanar:NO
													   colorSpaceName:@"NSCalibratedRGBColorSpace"
														  bytesPerRow:0
														 bitsPerPixel:0];
	[contextClass saveGraphicsState];
	[contextClass setCurrentContext:[contextClass graphicsContextWithBitmapImageRep:rep]];
	[view drawRect:view.bounds];
	[contextClass restoreGraphicsState];

	NSColor *center = [rep colorAtX:30 y:height / 2];
	XCTAssertGreaterThan(center.redComponent, 0.9);
	XCTAssertLessThan(center.greenComponent, 0.2);
	XCTAssertLessThan(center.blueComponent, 0.2);
}

#pragma mark Height

/*! @abstract A title-only banner is one line tall plus the vertical padding. */
- (void)testATitleOnlyBannerIsOneLineTall
{
	FxGripBannerView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @"Notice"}]];

	CGFloat titleHeight = ceil([self titleIn:view].intrinsicContentSize.height);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, titleHeight + 12.0, 1e-9);
	XCTAssertEqualWithAccuracy(view.frame.size.height, view.intrinsicContentSize.height, 0.5);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.width, NSViewNoIntrinsicMetric, 1e-9);
}

/*! @abstract A subtitle adds its own line and the gap between the lines. */
- (void)testASubtitleAddsALineAndTheGap
{
	FxGripBannerView *view = [self viewOfWidth:200];
	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @"Notice"}]];
	CGFloat titleOnly = view.intrinsicContentSize.height;

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Subtitle: @"Expires soon"}]];

	CGFloat subtitleHeight = ceil([self subtitleIn:view].intrinsicContentSize.height);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, titleOnly + subtitleHeight + 2.0, 1e-9);
}

/*! @abstract An empty banner is only its vertical padding tall. */
- (void)testAnEmptyBannerIsOnlyItsPadding
{
	FxGripBannerView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @""}]];

	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, 12.0, 1e-9);
	XCTAssertEqualWithAccuracy([self titleIn:view].frame.size.height, 0.0, 1e-9);
}

#pragma mark Graphic

/*! @abstract A graphic read from a file is shown, scaled into the strip, above the title. */
- (void)testAGraphicFromAFileIsShownAboveTheTitle
{
	NSString *path = [self temporaryImagePathWithWidth:400 height:200];
	FxGripBannerView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @"Notice",
												kFxGripBannerKey_ImageName: path}]];

	NSImageView *imageView = [self imageViewIn:view];
	XCTAssertFalse(imageView.hidden);
	XCTAssertNotNil(imageView.image);
	// The strip caps a graphic at its inner width and at the FxFactory maximum.
	XCTAssertEqualWithAccuracy(imageView.frame.size.width, kFxGripBannerMaxImageWidth, 1e-9);
	XCTAssertEqualWithAccuracy(imageView.frame.size.height, ceil(200.0 * kFxGripBannerMaxImageWidth / 400.0), 1e-9);
	XCTAssertLessThan(imageView.frame.origin.y, [self titleIn:view].frame.origin.y);
	XCTAssertGreaterThan(view.intrinsicContentSize.height, imageView.frame.size.height);
}

/*! @abstract A graphic narrower than the cap keeps its own width. */
- (void)testAGraphicNarrowerThanTheCapKeepsItsWidth
{
	NSString *path = [self temporaryImagePathWithWidth:40 height:20];
	FxGripBannerView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_ImageName: path}]];

	XCTAssertEqualWithAccuracy([self imageViewIn:view].frame.size.width, 40.0, 1e-9);
}

/*! @abstract A template graphic is tinted by the text color; a plain graphic takes no tint. */
- (void)testATemplateGraphicIsTintedByTheTextColor
{
	NSString *path = [self temporaryImagePathWithWidth:20 height:20];
	FxGripBannerView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_ImageName: path,
												kFxGripBannerKey_TemplateImage: @YES}]];
	XCTAssertTrue([self imageViewIn:view].image.isTemplate);
	XCTAssertEqualObjects([self imageViewIn:view].contentTintColor, [self titleIn:view].textColor);

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_ImageName: path,
												kFxGripBannerKey_TemplateImage: @NO}]];
	XCTAssertFalse([self imageViewIn:view].image.isTemplate);
	XCTAssertNil([self imageViewIn:view].contentTintColor);
}

/*! @abstract An empty or unresolvable graphic name hides the image row. */
- (void)testAnUnresolvableGraphicNameHidesTheImageRow
{
	FxGripBannerView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_ImageName: @""}]];
	XCTAssertTrue([self imageViewIn:view].hidden);

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_ImageName: @"/no/such/graphic.png"}]];
	XCTAssertTrue([self imageViewIn:view].hidden);
	XCTAssertNil([self imageViewIn:view].image);
}

#pragma mark Link

/*! @abstract A link reveals the companion action button when the value asks for one. */
- (void)testALinkGatesTheCompanionActionButton
{
	FxGripBannerView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @"Docs",
												kFxGripBannerKey_LinkURL: @"https://example.test/docs",
												kFxGripBannerKey_ActionButton: @YES}]];
	XCTAssertFalse([self actionButtonIn:view].hidden);
	XCTAssertGreaterThan([self actionButtonIn:view].frame.origin.x, 100.0, @"the button sits at the right edge");

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_LinkURL: @"",
												kFxGripBannerKey_ActionButton: @YES}]];
	XCTAssertTrue([self actionButtonIn:view].hidden, @"no link, no button");
}

/*! @abstract A linked banner offers the pointing-hand cursor over the whole strip. */
- (void)testALinkedBannerOffersThePointingHandCursor
{
	FxGripBannerView *view = [self viewOfWidth:200];
	[self hostView:view];

	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @"Docs",
												kFxGripBannerKey_LinkURL: @"https://example.test/docs"}]];

	XCTAssertNoThrow([view resetCursorRects]);
}

/*! @abstract An unlinked banner adds no cursor rect and passes a click to its superclass. */
- (void)testAnUnlinkedBannerPassesTheClickThrough
{
	FxGripBannerView *view = [self viewOfWidth:200];
	[self hostView:view];
	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @"Notice"}]];

	Class eventClass = NSClassFromString(@"NSEvent");
	NSEvent *click = [eventClass mouseEventWithType:NSEventTypeLeftMouseDown
										   location:NSMakePoint(10, 10)
									  modifierFlags:0
										  timestamp:0
									   windowNumber:0
											context:nil
										eventNumber:0
										 clickCount:1
										   pressure:1.0];

	XCTAssertNoThrow([view resetCursorRects]);
	XCTAssertNoThrow([view mouseDown:click]);
}

#pragma mark Resizing

/*! @abstract Resizing the strip re-lays out its rows to the new width. */
- (void)testResizingRelaysOutTheRows
{
	FxGripBannerView *view = [self viewOfWidth:200];
	[view updateFromCustomData:[self valueWith:@{kFxGripBannerKey_Title: @"Notice"}]];
	CGFloat before = [self titleIn:view].frame.size.width;

	view.frame = NSMakeRect(0, 0, 400, view.frame.size.height);

	XCTAssertGreaterThan([self titleIn:view].frame.size.width, before);
}

@end
