/*!
	@file       FxGripStatusParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripStatusParameterTests
	@abstract   Tests the read-only status indicator and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the parameter's type identity, the value
	            classes it decodes, the dot state and label it stores at creation, and the view it
	            vends. The view tests cover the label the value drives and the layout the control
	            performs on resize.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripStatusParameter.h>

static const FxParameterId kStatusTestParameter = 83;

@interface FxGripStatusParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripStatusParameterTests

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
	return FxGripParamClassTestConfig(kStatusTestParameter, kFxParameterType_Status, @"State", extra);
}

- (FxGripStatusView *)viewOfWidth:(CGFloat)width
{
	return [FxGripStatusView.alloc initWithFrame:NSMakeRect(0, 0, width, 20)];
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

/*! @abstract The status indicator reports the status FxPlug type and the matching type string. */
- (void)testTheStatusIndicatorReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripStatusParameter.parameterType, FxParameterType_Status);
	XCTAssertEqualObjects(FxGripStatusParameter.parameterTypeString, kFxParameterType_Status);
}

/*! @abstract The decodable value classes cover the parameter dictionary and every class it may carry. */
- (void)testTheStatusIndicatorDecodesTheDictionaryAndItsElementClasses
{
	NSSet<Class> *classes = FxGripStatusParameter.customValueClasses;

	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
	for (Class element in FxGripDictionary.classesForParameter) {
		XCTAssertTrue([classes containsObject:element], @"%@ is decodable", element);
	}
}

#pragma mark Creation

/*! @abstract Creation stores the declared dot state and label, and adds the custom-UI and no-state flags. */
- (void)testCreationStoresTheDeclaredStateAndLabel
{
	NSDictionary *declared = @{kCustomAPI_IntKey: @(3), kCustomAPI_StringKey: @"Ready"};

	XCTAssertTrue([FxGripStatusParameter addParameter:[self configWithDefault:declared] toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	int state = 0;
	NSString *text = nil;
	XCTAssertTrue([value getIntValue:&state]);
	XCTAssertTrue([value getStringParameterValue:&text]);
	XCTAssertEqual(state, 3);
	XCTAssertEqualObjects(text, @"Ready");
	XCTAssertEqualObjects(self.call[@"flags"],
						  @(kFxParameterFlag_DEFAULT | kFxParameterFlag_CUSTOM_UI | kFxParameterFlag_NOSTATE));
}

/*! @abstract A declared entry of the wrong class falls back to that entry's default. */
- (void)testADeclaredEntryOfAnotherClassFallsBackToItsDefault
{
	NSDictionary *declared = @{kCustomAPI_IntKey: @"three", kCustomAPI_StringKey: @(5)};

	XCTAssertTrue([FxGripStatusParameter addParameter:[self configWithDefault:declared] toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	int state = -1;
	NSString *text = nil;
	[value getIntValue:&state];
	[value getStringParameterValue:&text];
	XCTAssertEqual(state, 0);
	XCTAssertEqualObjects(text, @"");
}

/*! @abstract A host that refuses the creation is reported. */
- (void)testAHostRefusalIsReported
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([FxGripStatusParameter addParameter:[self configWithDefault:nil] toEffect:(id)self.effect]);
}

#pragma mark The vended view

/*! @abstract The parameter vends a status view seeded from the declared configuration. */
- (void)testTheVendedViewIsSeededFromTheDeclaredConfiguration
{
	FxGripStatusParameter *parameter =
		[FxGripStatusParameter.alloc initWithDictionary:[self configWithDefault:@{kCustomAPI_StringKey: @"Ready"}]
												 effect:(id)self.effect];

	NSView *view = [parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripStatusView.class]);
	XCTAssertEqualObjects([self labelIn:view].stringValue, @"Ready");
}

/*! @abstract Without a declared configuration the vended view stays empty. */
- (void)testTheVendedViewStaysEmptyWithoutAConfiguration
{
	FxGripStatusParameter *parameter =
		[FxGripStatusParameter.alloc initWithDictionary:[self configWithDefault:nil] effect:(id)self.effect];

	XCTAssertEqualObjects([self labelIn:[parameter newParameterView]].stringValue, @"");
}

#pragma mark The view

/*! @abstract The control lays out top-down with the label to the right of the dot. */
- (void)testTheControlPlacesTheLabelRightOfTheDot
{
	FxGripStatusView *view = [self viewOfWidth:200];

	XCTAssertTrue(view.isFlipped);
	XCTAssertGreaterThan([self labelIn:view].frame.origin.x, 0.0);
}

/*! @abstract Resizing the control stretches the label to the new width. */
- (void)testResizingStretchesTheLabel
{
	FxGripStatusView *view = [self viewOfWidth:200];
	CGFloat before = [self labelIn:view].frame.size.width;

	view.frame = NSMakeRect(0, 0, 400, 20);

	XCTAssertGreaterThan([self labelIn:view].frame.size.width, before);
}

/*! @abstract A value of another class leaves the control untouched. */
- (void)testAValueOfAnotherClassIsIgnored
{
	FxGripStatusView *view = [self viewOfWidth:200];
	[view updateFromCustomData:[self valueWith:@{kCustomAPI_StringKey: @"Kept"}]];

	[view updateFromCustomData:(id)@"not a dictionary"];

	XCTAssertEqualObjects([self labelIn:view].stringValue, @"Kept");
}

/*! @abstract The string value sets the label text. */
- (void)testTheStringValueSetsTheLabel
{
	FxGripStatusView *view = [self viewOfWidth:200];

	[view updateFromCustomData:[self valueWith:@{kCustomAPI_IntKey: @(2), kCustomAPI_StringKey: @"Analyzed"}]];

	XCTAssertEqualObjects([self labelIn:view].stringValue, @"Analyzed");
}

@end
