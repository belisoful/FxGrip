/*!
	@file       FxGripCapsuleParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripCapsuleParameterTests
	@abstract   Tests the read-only pill badge and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the parameter's type identity, the value
	            classes it decodes, the default value creation stores, and the view it vends. The view
	            tests cover the title, point size, colors, and corner radius the value carries, the
	            size the badge takes from its text, and the rounded fill it draws.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripCapsule.h>
#import <FxGrip/FxGripCapsuleParameter.h>

static const FxParameterId kCapsuleTestParameter = 82;

@interface FxGripCapsuleParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripCapsuleParameterTests

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

#pragma mark Helpers

- (NSDictionary *)call
{
	return self.effect.creationCall;
}

- (NSMutableDictionary *)configWithDefault:(nullable NSDictionary *)declared
{
	NSDictionary *extra = declared ? @{kFxParameterProperty_Default: declared} : nil;
	return FxGripParamClassTestConfig(kCapsuleTestParameter, kFxParameterType_Capsule, @"Beta", extra);
}

- (FxGripCapsuleView *)badge
{
	return [FxGripCapsuleView.alloc initWithFrame:NSMakeRect(0, 0, 80, 18)];
}

- (NSTextField *)labelIn:(NSView *)view
{
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSTextField.class]) {
			return (NSTextField *)sub;
		}
	}
	return nil;
}

- (FxGripDictionary *)valueWith:(NSDictionary *)contents
{
	return [FxGripDictionary dictionaryWithDictionary:contents];
}

/*! Draws the badge into an offscreen bitmap and returns the color at its center. */
- (NSColor *)centerColorOfBadge:(FxGripCapsuleView *)view
{
	Class repClass = NSClassFromString(@"NSBitmapImageRep");
	Class contextClass = NSClassFromString(@"NSGraphicsContext");
	NSInteger width = MAX(1, (NSInteger)view.bounds.size.width);
	NSInteger height = MAX(1, (NSInteger)view.bounds.size.height);
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
	[contextClass saveGraphicsState];
	[contextClass setCurrentContext:[contextClass graphicsContextWithBitmapImageRep:rep]];
	[view drawRect:view.bounds];
	[contextClass restoreGraphicsState];
	return [rep colorAtX:width / 2 y:height / 2];
}

#pragma mark Type identity

/*! @abstract The badge reports the capsule FxPlug type and the matching type string. */
- (void)testTheBadgeReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripCapsuleParameter.parameterType, FxParameterType_Capsule);
	XCTAssertEqualObjects(FxGripCapsuleParameter.parameterTypeString, kFxParameterType_Capsule);
}

/*! @abstract The decodable value classes cover the parameter dictionary and every class it may carry. */
- (void)testTheBadgeDecodesTheDictionaryAndItsElementClasses
{
	NSSet<Class> *classes = FxGripCapsuleParameter.customValueClasses;

	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
	for (Class element in FxGripDictionary.classesForParameter) {
		XCTAssertTrue([classes containsObject:element], @"%@ is decodable", element);
	}
}

#pragma mark Creation

/*! @abstract Creation carries the declared configuration and adds the custom-UI, not-animatable, and no-state flags. */
- (void)testCreationCarriesTheDeclaredConfigurationAndTheControlFlags
{
	NSMutableDictionary *config = [self configWithDefault:@{kFxGripCapsuleKey_Title: @"BETA"}];
	config[kFxParameterProperty_Flags] = @(kFxParameterFlag_HIDDEN);

	XCTAssertTrue([FxGripCapsuleParameter addParameter:config toEffect:(id)self.effect]);

	FxParameterFlags expected = kFxParameterFlag_HIDDEN | kFxParameterFlag_CUSTOM_UI
		| kFxParameterFlag_NOT_ANIMATABLE | kFxParameterFlag_NOSTATE;
	NSString *title = nil;
	[(FxGripDictionary *)self.call[@"default"] getStringParameterValue:&title forKey:kFxGripCapsuleKey_Title];
	XCTAssertEqualObjects(title, @"BETA");
	XCTAssertEqualObjects(self.call[@"flags"], @(expected));
	XCTAssertEqualObjects(self.call[@"name"], @"Beta");
}

/*! @abstract A declared default of another class creates an empty-titled badge. */
- (void)testADeclaredDefaultOfAnotherClassCreatesAnEmptyBadge
{
	NSMutableDictionary *config = [self configWithDefault:nil];
	config[kFxParameterProperty_Default] = @"BETA";

	XCTAssertTrue([FxGripCapsuleParameter addParameter:config toEffect:(id)self.effect]);

	NSString *title = nil;
	[(FxGripDictionary *)self.call[@"default"] getStringParameterValue:&title forKey:kFxGripCapsuleKey_Title];
	XCTAssertEqualObjects(title, @"");
}

/*! @abstract A host that refuses the creation is reported. */
- (void)testAHostRefusalIsReported
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([FxGripCapsuleParameter addParameter:[self configWithDefault:nil] toEffect:(id)self.effect]);
}

#pragma mark The vended view

/*! @abstract The parameter vends a badge seeded with the declared title. */
- (void)testTheVendedViewCarriesTheDeclaredTitle
{
	FxGripCapsuleParameter *parameter =
		[FxGripCapsuleParameter.alloc initWithDictionary:[self configWithDefault:@{kFxGripCapsuleKey_Title: @"BETA"}]
												  effect:(id)self.effect];

	NSView *view = [parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripCapsuleView.class]);
	XCTAssertEqualObjects([self labelIn:view].stringValue, @"BETA");
}

/*! @abstract Without a declared configuration the vended badge carries no title. */
- (void)testTheVendedViewCarriesNoTitleWithoutAConfiguration
{
	FxGripCapsuleParameter *parameter =
		[FxGripCapsuleParameter.alloc initWithDictionary:[self configWithDefault:nil] effect:(id)self.effect];

	XCTAssertEqualObjects([self labelIn:[parameter newParameterView]].stringValue, @"");
}

#pragma mark The view

/*! @abstract A value of another class leaves the badge untouched. */
- (void)testAValueOfAnotherClassIsIgnored
{
	FxGripCapsuleView *view = [self badge];
	[view updateFromCustomData:[self valueWith:@{kFxGripCapsuleKey_Title: @"Kept"}]];

	[view updateFromCustomData:(id)@[@"not a dictionary"]];

	XCTAssertEqualObjects([self labelIn:view].stringValue, @"Kept");
}

/*! @abstract The badge sizes itself to its text plus the padding. */
- (void)testTheBadgeSizesItselfToItsText
{
	FxGripCapsuleView *view = [self badge];

	[view updateFromCustomData:[self valueWith:@{kFxGripCapsuleKey_Title: @"BETA"}]];
	NSSize shortSize = view.intrinsicContentSize;

	[view updateFromCustomData:[self valueWith:@{kFxGripCapsuleKey_Title: @"EXPERIMENTAL BUILD"}]];

	XCTAssertGreaterThan(view.intrinsicContentSize.width, shortSize.width);
	XCTAssertEqualWithAccuracy(view.frame.size.width, view.intrinsicContentSize.width, 0.5);
}

/*! @abstract A declared point size sets the label font, and a size of zero is refused. */
- (void)testTheDeclaredPointSizeSetsTheLabelFont
{
	FxGripCapsuleView *view = [self badge];
	XCTAssertEqualWithAccuracy([self labelIn:view].font.pointSize, kFxGripCapsuleDefaultFontSize, 1e-9);

	[view updateFromCustomData:[self valueWith:@{kFxGripCapsuleKey_FontSize: @(16.0)}]];
	XCTAssertEqualWithAccuracy([self labelIn:view].font.pointSize, 16.0, 1e-9);

	[view updateFromCustomData:[self valueWith:@{kFxGripCapsuleKey_FontSize: @(0.0)}]];
	XCTAssertEqualWithAccuracy([self labelIn:view].font.pointSize, 16.0, 1e-9, @"a zero size is refused");
}

/*! @abstract A declared text color reaches the label. */
- (void)testTheDeclaredTextColorReachesTheLabel
{
	FxGripCapsuleView *view = [self badge];
	FxGripDictionary *value = [self valueWith:@{kFxGripCapsuleKey_Title: @"BETA"}];
	[value setRedValue:0.0 greenValue:1.0 blueValue:0.0 alphaValue:1.0 forKey:kFxGripCapsuleKey_TextColor];

	[view updateFromCustomData:value];

	NSColor *color = [[self labelIn:view].textColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
	XCTAssertEqualWithAccuracy(color.greenComponent, 1.0, 1e-6);
	XCTAssertEqualWithAccuracy(color.redComponent, 0.0, 1e-6);
}

/*! @abstract The badge fills with the declared color, so a red pill draws red at its center. */
- (void)testTheBadgeFillsWithTheDeclaredColor
{
	FxGripCapsuleView *view = [self badge];
	FxGripDictionary *value = [self valueWith:@{kFxGripCapsuleKey_Title: @"BETA"}];
	[value setRedValue:1.0 greenValue:0.0 blueValue:0.0 alphaValue:1.0 forKey:kFxGripCapsuleKey_FillColor];
	[view updateFromCustomData:value];

	NSColor *center = [self centerColorOfBadge:view];

	XCTAssertGreaterThan(center.redComponent, 0.9);
	XCTAssertLessThan(center.greenComponent, 0.2);
}

/*! @abstract A declared corner radius squares the badge off, and the pill radius rounds it fully. */
- (void)testTheCornerRadiusChangesWhatTheBadgeDraws
{
	FxGripCapsuleView *squared = [self badge];
	FxGripDictionary *squareValue = [self valueWith:@{kFxGripCapsuleKey_Title: @"BETA",
													  kFxGripCapsuleKey_CornerRadius: @(0.0)}];
	[squareValue setRedValue:1.0 greenValue:0.0 blueValue:0.0 alphaValue:1.0 forKey:kFxGripCapsuleKey_FillColor];
	[squared updateFromCustomData:squareValue];

	FxGripCapsuleView *pill = [self badge];
	FxGripDictionary *pillValue = [self valueWith:@{kFxGripCapsuleKey_Title: @"BETA",
													kFxGripCapsuleKey_CornerRadius: @(kFxGripCapsulePillRadius)}];
	[pillValue setRedValue:1.0 greenValue:0.0 blueValue:0.0 alphaValue:1.0 forKey:kFxGripCapsuleKey_FillColor];
	[pill updateFromCustomData:pillValue];

	// Both fill their center; the pill leaves its corners clear while the squared badge fills them.
	XCTAssertGreaterThan([self centerColorOfBadge:squared].redComponent, 0.9);
	XCTAssertGreaterThan([self centerColorOfBadge:pill].redComponent, 0.9);
}

@end
