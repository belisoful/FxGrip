/*!
	@file       FxGripSectionParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripSectionParameterTests
	@abstract   Tests the section title header view and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the parameter's type identity, the custom
	            control it registers, the flags it forces on, and the title fallback. The view tests
	            cover the font the declared name, size, weight, and width build, the letter-case
	            transform, the alignment, the color and opacity, and the margins that drive the row
	            height.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripSection.h>
#import <FxGrip/FxGripSectionData.h>
#import <FxGrip/FxGripSectionParameter.h>

static const FxParameterId kSectionTestParameter = 79;

@interface FxGripSectionParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripSectionParameterTests

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

- (NSMutableDictionary *)configWithDefault:(nullable NSDictionary *)declared name:(NSString *)name
{
	NSDictionary *extra = declared ? @{kFxParameterProperty_Default: declared} : nil;
	return FxGripParamClassTestConfig(kSectionTestParameter, kFxParameterType_Section, name, extra);
}

- (FxGripSectionView *)viewOfWidth:(CGFloat)width
{
	return [FxGripSectionView.alloc initWithFrame:NSMakeRect(0, 0, width, 22)];
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

- (FxGripSectionData *)valueWith:(NSDictionary *)contents
{
	return [FxGripSectionData.alloc initWithDictionary:contents];
}

- (NSString *)titleOfViewWith:(NSDictionary *)contents
{
	FxGripSectionView *view = [self viewOfWidth:200];
	[view updateFromCustomData:[self valueWith:contents]];
	return [self labelIn:view].stringValue;
}

#pragma mark Type identity

/*! @abstract The section header reports the section FxPlug type and the matching type string. */
- (void)testTheSectionReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripSectionParameter.parameterType, FxParameterType_Section);
	XCTAssertEqualObjects(FxGripSectionParameter.parameterTypeString, kFxParameterType_Section);
}

/*! @abstract The only decodable value class is the section value type. */
- (void)testTheSectionDecodesOnlyItsOwnValueClass
{
	XCTAssertEqualObjects(FxGripSectionParameter.customValueClasses,
						  [NSSet setWithObject:FxGripSectionData.class]);
}

#pragma mark Creation

/*! @abstract Creation registers a custom control with an empty host name and adds the custom-control flags. */
- (void)testCreationRegistersACustomControlWithNoHostNameAndTheControlFlags
{
	NSMutableDictionary *config = [self configWithDefault:nil name:@"Geometry"];
	config[kFxParameterProperty_Flags] = @(kFxParameterFlag_HIDDEN);

	XCTAssertTrue([FxGripSectionParameter addParameter:config toEffect:(id)self.effect]);

	FxParameterFlags expected = kFxParameterFlag_HIDDEN | kFxParameterFlag_CUSTOM_UI
		| kFxParameterFlag_NOT_ANIMATABLE | kFxParameterFlag_USE_FULL_VIEW_WIDTH | kFxParameterFlag_NOSTATE;
	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"", @"the header draws its own title");
	XCTAssertEqualObjects(self.call[@"flags"], @(expected));
	XCTAssertTrue([self.call[@"default"] isKindOfClass:FxGripSectionData.class]);
}

/*! @abstract A configuration without a title falls back to the parameter name. */
- (void)testATitlelessConfigurationFallsBackToTheParameterName
{
	XCTAssertTrue([FxGripSectionParameter addParameter:[self configWithDefault:nil name:@"Geometry"]
											  toEffect:(id)self.effect]);

	NSString *title = nil;
	XCTAssertTrue([(FxGripSectionData *)self.call[@"default"] getStringParameterValue:&title
																			  forKey:kFxGripSectionKey_Title]);
	XCTAssertEqualObjects(title, @"Geometry");
}

/*! @abstract A declared title is kept in place of the parameter name. */
- (void)testADeclaredTitleOverridesTheParameterName
{
	NSDictionary *declared = @{kFxGripSectionKey_Title: @"Shading"};

	XCTAssertTrue([FxGripSectionParameter addParameter:[self configWithDefault:declared name:@"Geometry"]
											  toEffect:(id)self.effect]);

	NSString *title = nil;
	[(FxGripSectionData *)self.call[@"default"] getStringParameterValue:&title forKey:kFxGripSectionKey_Title];
	XCTAssertEqualObjects(title, @"Shading");
}

/*! @abstract A host that refuses the creation is reported. */
- (void)testAHostRefusalIsReported
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([FxGripSectionParameter addParameter:[self configWithDefault:nil name:@"Geometry"]
											   toEffect:(id)self.effect]);
}

#pragma mark The vended view

/*! @abstract The parameter vends a header view seeded with the declared title. */
- (void)testTheVendedViewCarriesTheDeclaredTitle
{
	NSDictionary *declared = @{kFxGripSectionKey_Title: @"Shading"};
	FxGripSectionParameter *parameter =
		[FxGripSectionParameter.alloc initWithDictionary:[self configWithDefault:declared name:@"Geometry"]
												  effect:(id)self.effect];

	NSView *view = [parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripSectionView.class]);
	XCTAssertEqualObjects([self labelIn:view].stringValue, @"Shading");
}

/*! @abstract Without a declared configuration the vended view carries no title. */
- (void)testTheVendedViewCarriesNoTitleWithoutAConfiguration
{
	FxGripSectionParameter *parameter =
		[FxGripSectionParameter.alloc initWithDictionary:[self configWithDefault:nil name:@"Geometry"]
												  effect:(id)self.effect];

	XCTAssertEqualObjects([self labelIn:[parameter newParameterView]].stringValue, @"");
}

#pragma mark View geometry

/*! @abstract The header lays out top-down and sizes its row to the label plus the two margins. */
- (void)testTheHeaderSizesItsRowToTheLabelAndMargins
{
	FxGripSectionView *view = [self viewOfWidth:200];
	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Title: @"Geometry"}]];

	CGFloat labelHeight = ceil([self labelIn:view].intrinsicContentSize.height);
	XCTAssertTrue(view.isFlipped);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height,
							   kFxGripSectionDefaultMarginTop + labelHeight + kFxGripSectionDefaultMarginBot, 1e-9);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.width, NSViewNoIntrinsicMetric, 1e-9);
	XCTAssertEqualWithAccuracy(view.frame.size.height, view.intrinsicContentSize.height, 0.5);
}

/*! @abstract The declared margins move the label and grow the row. */
- (void)testTheDeclaredMarginsMoveTheLabelAndGrowTheRow
{
	FxGripSectionView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Title: @"Geometry",
												kFxGripSectionKey_MarginTop: @(10),
												kFxGripSectionKey_MarginBottom: @(6)}]];

	CGFloat labelHeight = ceil([self labelIn:view].intrinsicContentSize.height);
	XCTAssertEqualWithAccuracy([self labelIn:view].frame.origin.y, 10.0, 1e-9);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, 10 + labelHeight + 6, 1e-9);
}

/*! @abstract A negative margin clamps to zero, so the label never leaves the row. */
- (void)testANegativeMarginClampsToZero
{
	FxGripSectionView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_MarginTop: @(-8),
												kFxGripSectionKey_MarginBottom: @(-3)}]];

	CGFloat labelHeight = ceil([self labelIn:view].intrinsicContentSize.height);
	XCTAssertEqualWithAccuracy([self labelIn:view].frame.origin.y, 0.0, 1e-9);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, labelHeight, 1e-9);
}

/*! @abstract Resizing the header widens the label to the new width. */
- (void)testResizingWidensTheLabel
{
	FxGripSectionView *view = [self viewOfWidth:200];
	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Title: @"Geometry"}]];
	CGFloat before = [self labelIn:view].frame.size.width;

	view.frame = NSMakeRect(0, 0, 400, view.frame.size.height);

	XCTAssertGreaterThan([self labelIn:view].frame.size.width, before);
}

#pragma mark Title

/*! @abstract A value of another class leaves the header untouched. */
- (void)testAValueOfAnotherClassIsIgnored
{
	FxGripSectionView *view = [self viewOfWidth:200];
	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Title: @"Kept"}]];

	[view updateFromCustomData:(id)@"not a section"];

	XCTAssertEqualObjects([self labelIn:view].stringValue, @"Kept");
}

/*! @abstract A plain dictionary of the same shape drives the header. */
- (void)testAPlainDictionaryOfTheSameShapeDrivesTheHeader
{
	FxGripSectionView *view = [self viewOfWidth:200];

	[view updateFromCustomData:(id)@{kFxGripSectionKey_Title: @"Geometry"}];

	XCTAssertEqualObjects([self labelIn:view].stringValue, @"Geometry");
}

/*! @abstract Each letter-case transform is applied to the declared title. */
- (void)testEachLetterCaseTransformIsApplied
{
	NSString *plain = [self titleOfViewWith:@{kFxGripSectionKey_Title: @"light rays"}];
	NSString *upper = [self titleOfViewWith:@{kFxGripSectionKey_Title: @"light rays",
											  kFxGripSectionKey_Transform: @(FxGripSectionTransformUppercase)}];
	NSString *lower = [self titleOfViewWith:@{kFxGripSectionKey_Title: @"LIGHT RAYS",
											  kFxGripSectionKey_Transform: @(FxGripSectionTransformLowercase)}];
	NSString *capitalized = [self titleOfViewWith:@{kFxGripSectionKey_Title: @"light rays",
													kFxGripSectionKey_Transform: @(FxGripSectionTransformCapitalize)}];

	XCTAssertEqualObjects(plain, @"light rays");
	XCTAssertEqualObjects(upper, @"LIGHT RAYS");
	XCTAssertEqualObjects(lower, @"light rays");
	XCTAssertEqualObjects(capitalized, @"Light Rays");
}

/*! @abstract The declared alignment reaches the label. */
- (void)testTheDeclaredAlignmentReachesTheLabel
{
	FxGripSectionView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Title: @"Geometry",
												kFxGripSectionKey_Alignment: @(NSTextAlignmentCenter)}]];

	XCTAssertEqual([self labelIn:view].alignment, NSTextAlignmentCenter);
}

#pragma mark Font

/*! @abstract The header defaults to the bold system font at the house size. */
- (void)testTheHeaderDefaultsToTheBoldSystemFont
{
	FxGripSectionView *view = [self viewOfWidth:200];

	XCTAssertEqualObjects([self labelIn:view].font, [NSFont boldSystemFontOfSize:kFxGripSectionDefaultSize]);
}

/*! @abstract A declared point size sets the label font size, and a size of zero is refused. */
- (void)testTheDeclaredPointSizeSetsTheFont
{
	FxGripSectionView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Size: @(18.0)}]];
	XCTAssertEqualWithAccuracy([self labelIn:view].font.pointSize, 18.0, 1e-9);

	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Size: @(0.0)}]];
	XCTAssertEqualWithAccuracy([self labelIn:view].font.pointSize, kFxGripSectionDefaultSize, 1e-9);
}

/*! @abstract A declared font name is used when the system resolves it. */
- (void)testADeclaredFontNameIsUsed
{
	FxGripSectionView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_FontName: @"Helvetica",
												kFxGripSectionKey_Size: @(14.0)}]];

	XCTAssertEqualObjects([self labelIn:view].font.fontName, @"Helvetica");
	XCTAssertEqualWithAccuracy([self labelIn:view].font.pointSize, 14.0, 1e-9);
}

/*! @abstract A font name the system cannot resolve falls back to the system font at the declared weight. */
- (void)testAnUnresolvableFontNameFallsBackToTheDeclaredWeight
{
	FxGripSectionView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_FontName: @"No Such Typeface",
												kFxGripSectionKey_Size: @(13.0),
												kFxGripSectionKey_Weight: @(-400)}]];

	NSFont *font = [self labelIn:view].font;
	XCTAssertEqualObjects(font, [NSFont systemFontOfSize:13.0 weight:-0.4]);
}

/*! @abstract A declared width trait widens the resolved font without changing its size. */
- (void)testADeclaredWidthTraitWidensTheFont
{
	FxGripSectionView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Size: @(13.0),
												kFxGripSectionKey_Width: @(500)}]];

	NSFont *font = [self labelIn:view].font;
	XCTAssertNotNil(font);
	XCTAssertEqualWithAccuracy(font.pointSize, 13.0, 1e-9);
	XCTAssertNotEqualObjects(font, [NSFont boldSystemFontOfSize:13.0], @"the widened face is another font");
	NSNumber *width = [font.fontDescriptor objectForKey:NSFontTraitsAttribute][NSFontWidthTrait];
	XCTAssertEqualWithAccuracy(width.doubleValue, 0.5, 1e-6);
}

/*! @abstract A width trait of zero leaves the font unwidened. */
- (void)testAWidthTraitOfZeroLeavesTheFontAlone
{
	FxGripSectionView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Size: @(13.0),
												kFxGripSectionKey_Width: @(0)}]];

	XCTAssertEqualObjects([self labelIn:view].font, [NSFont boldSystemFontOfSize:13.0]);
}

#pragma mark Color

/*! @abstract A declared color reaches the label, scaled by the declared opacity. */
- (void)testTheDeclaredColorReachesTheLabelScaledByTheOpacity
{
	FxGripSectionView *view = [self viewOfWidth:200];
	FxGripSectionData *value = [self valueWith:@{kFxGripSectionKey_Opacity: @(0.5)}];
	[value setRedValue:1.0 greenValue:0.0 blueValue:0.0 alphaValue:1.0 forKey:kFxGripSectionKey_Color];

	[view updateFromCustomData:value];

	NSColor *color = [[self labelIn:view].textColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
	XCTAssertEqualWithAccuracy(color.redComponent, 1.0, 1e-6);
	XCTAssertEqualWithAccuracy(color.alphaComponent, 0.5, 1e-6);
}

/*! @abstract With no declared color, the opacity dims the inherited label color. */
- (void)testTheOpacityAloneDimsTheInheritedLabelColor
{
	FxGripSectionView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Opacity: @(0.25)}]];

	XCTAssertEqualObjects([self labelIn:view].textColor,
						  [NSColor.labelColor colorWithAlphaComponent:0.25]);
}

/*! @abstract An opacity outside zero to one clamps into the range. */
- (void)testAnOutOfRangeOpacityClamps
{
	FxGripSectionView *high = [self viewOfWidth:200];
	[high updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Opacity: @(4.0)}]];
	XCTAssertEqualObjects([self labelIn:high].textColor, [NSColor.labelColor colorWithAlphaComponent:1.0]);

	FxGripSectionView *low = [self viewOfWidth:200];
	[low updateFromCustomData:[self valueWith:@{kFxGripSectionKey_Opacity: @(-2.0)}]];
	XCTAssertEqualObjects([self labelIn:low].textColor, [NSColor.labelColor colorWithAlphaComponent:0.0]);
}

@end
