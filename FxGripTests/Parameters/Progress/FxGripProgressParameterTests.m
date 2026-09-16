/*!
	@file       FxGripProgressParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripProgressParameterTests
	@abstract   Tests the read-only progress display and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the parameter's type identity, the value
	            classes it decodes, the fraction, dot state, and label it stores at creation, and the
	            view it vends. The view tests cover the determinate and indeterminate bar, the label,
	            and the layout the control performs on resize.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripProgressParameter.h>

static const FxParameterId kProgressTestParameter = 81;

@interface FxGripProgressParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripProgressParameterTests

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
	return FxGripParamClassTestConfig(kProgressTestParameter, kFxParameterType_Progress, @"Analyzing", extra);
}

- (FxGripProgressView *)viewOfWidth:(CGFloat)width
{
	return [FxGripProgressView.alloc initWithFrame:NSMakeRect(0, 0, width, 34)];
}

- (NSProgressIndicator *)barIn:(NSView *)view
{
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSProgressIndicator.class]) {
			return (NSProgressIndicator *)sub;
		}
	}
	return nil;
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

#pragma mark Type identity

/*! @abstract The progress display reports the progress FxPlug type and the matching type string. */
- (void)testTheProgressDisplayReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripProgressParameter.parameterType, FxParameterType_Progress);
	XCTAssertEqualObjects(FxGripProgressParameter.parameterTypeString, kFxParameterType_Progress);
}

/*! @abstract The decodable value classes cover the parameter dictionary and every class it may carry. */
- (void)testTheProgressDisplayDecodesTheDictionaryAndItsElementClasses
{
	NSSet<Class> *classes = FxGripProgressParameter.customValueClasses;

	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
	for (Class element in FxGripDictionary.classesForParameter) {
		XCTAssertTrue([classes containsObject:element], @"%@ is decodable", element);
	}
}

#pragma mark Creation

/*! @abstract Creation stores the declared fraction, dot state, and label, and adds the custom-UI and no-state flags. */
- (void)testCreationStoresTheDeclaredFractionStateAndLabel
{
	NSDictionary *declared = @{kCustomAPI_FloatKey: @(0.4), kCustomAPI_IntKey: @(2), kCustomAPI_StringKey: @"Half"};

	XCTAssertTrue([FxGripProgressParameter addParameter:[self configWithDefault:declared] toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	double fraction = 0.0;
	int state = 0;
	NSString *text = nil;
	XCTAssertTrue([value getFloatValue:&fraction]);
	XCTAssertTrue([value getIntValue:&state]);
	XCTAssertTrue([value getStringParameterValue:&text]);
	XCTAssertEqualWithAccuracy(fraction, 0.4, 1e-12);
	XCTAssertEqual(state, 2);
	XCTAssertEqualObjects(text, @"Half");
	XCTAssertEqualObjects(self.call[@"flags"],
						  @(kFxParameterFlag_DEFAULT | kFxParameterFlag_CUSTOM_UI | kFxParameterFlag_NOSTATE));
}

/*! @abstract A declared entry of the wrong class falls back to that entry's default. */
- (void)testADeclaredEntryOfAnotherClassFallsBackToItsDefault
{
	NSDictionary *declared = @{kCustomAPI_FloatKey: @"half", kCustomAPI_StringKey: @(3)};

	XCTAssertTrue([FxGripProgressParameter addParameter:[self configWithDefault:declared] toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	double fraction = -1.0;
	NSString *text = nil;
	[value getFloatValue:&fraction];
	[value getStringParameterValue:&text];
	XCTAssertEqualWithAccuracy(fraction, 0.0, 1e-12);
	XCTAssertEqualObjects(text, @"");
}

/*! @abstract A host that refuses the creation is reported. */
- (void)testAHostRefusalIsReported
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([FxGripProgressParameter addParameter:[self configWithDefault:nil] toEffect:(id)self.effect]);
}

#pragma mark The vended view

/*! @abstract The parameter vends a progress view seeded from the declared configuration. */
- (void)testTheVendedViewIsSeededFromTheDeclaredConfiguration
{
	NSDictionary *declared = @{kCustomAPI_FloatKey: @(0.5), kCustomAPI_StringKey: @"Halfway"};
	FxGripProgressParameter *parameter =
		[FxGripProgressParameter.alloc initWithDictionary:[self configWithDefault:declared] effect:(id)self.effect];

	NSView *view = [parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripProgressView.class]);
	XCTAssertEqualObjects([self labelIn:view].stringValue, @"Halfway");
	XCTAssertEqualWithAccuracy([self barIn:view].doubleValue, 0.5, 1e-9);
}

/*! @abstract Without a declared configuration the vended view stays empty. */
- (void)testTheVendedViewStaysEmptyWithoutAConfiguration
{
	FxGripProgressParameter *parameter =
		[FxGripProgressParameter.alloc initWithDictionary:[self configWithDefault:nil] effect:(id)self.effect];

	XCTAssertEqualObjects([self labelIn:[parameter newParameterView]].stringValue, @"");
}

#pragma mark The view

/*! @abstract The control lays out top-down with the bar below the label. */
- (void)testTheControlLaysOutTopDownWithTheBarBelowTheLabel
{
	FxGripProgressView *view = [self viewOfWidth:200];

	XCTAssertTrue(view.isFlipped);
	XCTAssertGreaterThan([self barIn:view].frame.origin.y, [self labelIn:view].frame.origin.y);
}

/*! @abstract Resizing the control stretches the bar and the label to the new width. */
- (void)testResizingStretchesTheBarAndLabel
{
	FxGripProgressView *view = [self viewOfWidth:200];
	CGFloat barBefore = [self barIn:view].frame.size.width;
	CGFloat labelBefore = [self labelIn:view].frame.size.width;

	view.frame = NSMakeRect(0, 0, 400, 34);

	XCTAssertGreaterThan([self barIn:view].frame.size.width, barBefore);
	XCTAssertGreaterThan([self labelIn:view].frame.size.width, labelBefore);
}

/*! @abstract A value of another class leaves the control untouched. */
- (void)testAValueOfAnotherClassIsIgnored
{
	FxGripProgressView *view = [self viewOfWidth:200];
	[view updateFromCustomData:[self valueWith:@{kCustomAPI_StringKey: @"Kept"}]];

	[view updateFromCustomData:(id)@"not a dictionary"];

	XCTAssertEqualObjects([self labelIn:view].stringValue, @"Kept");
}

/*! @abstract A fraction inside zero to one drives the determinate bar and clamps above one. */
- (void)testAFractionDrivesTheDeterminateBar
{
	FxGripProgressView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kCustomAPI_FloatKey: @(0.25)}]];
	XCTAssertFalse([self barIn:view].isIndeterminate);
	XCTAssertEqualWithAccuracy([self barIn:view].doubleValue, 0.25, 1e-9);

	[view updateFromCustomData:[self valueWith:@{kCustomAPI_FloatKey: @(4.0)}]];
	XCTAssertEqualWithAccuracy([self barIn:view].doubleValue, 1.0, 1e-9);
}

/*! @abstract A negative fraction spins the indeterminate bar, and a later fraction returns it to determinate. */
- (void)testANegativeFractionSpinsTheIndeterminateBar
{
	FxGripProgressView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kCustomAPI_FloatKey: @(-1.0)}]];
	XCTAssertTrue([self barIn:view].isIndeterminate);

	[view updateFromCustomData:[self valueWith:@{kCustomAPI_FloatKey: @(0.6)}]];
	XCTAssertFalse([self barIn:view].isIndeterminate);
	XCTAssertEqualWithAccuracy([self barIn:view].doubleValue, 0.6, 1e-9);
}

/*! @abstract The string value sets the label text. */
- (void)testTheStringValueSetsTheLabel
{
	FxGripProgressView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kCustomAPI_StringKey: @"Analyzing frame 12"}]];

	XCTAssertEqualObjects([self labelIn:view].stringValue, @"Analyzing frame 12");
}

@end
