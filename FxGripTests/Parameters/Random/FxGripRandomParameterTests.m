/*!
	@file       FxGripRandomParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripRandomParameterTests
	@abstract   Tests the random integer control and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the parameter's type identity, the value,
	            range, and step it stores at creation, and the view it vends. The view tests cover the
	            range and step the value carries, the clamp every edit passes through, the reload that
	            draws a uniform integer in the range, and the out-of-band write each edit performs.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripRandom.h>
#import <FxGrip/FxGripRandomParameter.h>

static const FxParameterId kRandomTestParameter = 73;

#pragma mark - Probes

/*! The control actions the field, stepper, and reload button are wired to. */
@interface FxGripRandomView (FxGripRandomParameterTests)
- (void)fieldChanged:(nullable id)sender;
- (void)stepperChanged:(nullable id)sender;
- (void)reloadClicked:(nullable id)sender;
@end

#pragma mark - Doubles

/*! Stands in for the host's FxCustomParameterActionAPI_v4 the out-of-band write brackets. */
@interface FxGripRandomTestActionAPI : NSObject
@property (nonatomic, assign) CMTime currentTime;
@property (nonatomic, assign) NSUInteger startCount;
@property (nonatomic, assign) NSUInteger endCount;
@end

@implementation FxGripRandomTestActionAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_currentTime = FxGripParamClassTestTime(90, 30);
	}
	return self;
}

- (void)startAction:(id)sender { self.startCount += 1; }
- (void)endAction:(id)sender { self.endCount += 1; }

@end

/*! Adds the action API the shared manager double does not carry. */
@interface FxGripRandomTestAPIManager : FxGripParamClassTestAPIManager
@property (nonatomic, strong) FxGripRandomTestActionAPI *customParameterActionAPIv4;
@end

@implementation FxGripRandomTestAPIManager

- (instancetype)init
{
	self = [super init];
	if (self) {
		_customParameterActionAPIv4 = [FxGripRandomTestActionAPI.alloc init];
	}
	return self;
}

@end

@interface FxGripRandomTestEffect : FxGripParamClassTestEffect
@property (nonatomic, strong) FxGripRandomTestAPIManager *randomManager;
@end

@implementation FxGripRandomTestEffect

- (instancetype)init
{
	self = [super init];
	if (self) {
		_randomManager = [FxGripRandomTestAPIManager.alloc init];
		self.apiManager = _randomManager;
	}
	return self;
}

@end

#pragma mark - Tests

@interface FxGripRandomParameterTests : XCTestCase
@property (nonatomic, strong) FxGripRandomTestEffect *effect;
@end

@implementation FxGripRandomParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripRandomTestEffect.alloc init];
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
	return FxGripParamClassTestConfig(kRandomTestParameter, kFxParameterType_Random, @"Seed", extra);
}

- (FxGripRandomView *)wiredView
{
	FxGripRandomView *view = [FxGripRandomView.alloc initWithFrame:NSMakeRect(0, 0, 120, 22)];
	view.parameterEffect = (id)self.effect;
	view.parameterID = kRandomTestParameter;
	return view;
}

- (NSTextField *)fieldIn:(NSView *)view
{
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSTextField.class]) {
			return (NSTextField *)sub;
		}
	}
	return nil;
}

- (NSStepper *)stepperIn:(NSView *)view
{
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSStepper.class]) {
			return (NSStepper *)sub;
		}
	}
	return nil;
}

- (NSButton *)reloadIn:(NSView *)view
{
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSButton.class] && ![sub isKindOfClass:NSStepper.class]) {
			return (NSButton *)sub;
		}
	}
	return nil;
}

- (FxGripParamClassTestSettingAPI *)setter
{
	return self.effect.apiManager.paramSetAPIv5;
}

- (FxGripDictionary *)writtenValue
{
	return self.setter.lastWrite[@"value"];
}

- (FxGripDictionary *)valueWith:(NSDictionary *)contents
{
	return [FxGripDictionary dictionaryWithDictionary:contents];
}

- (int)writtenInteger
{
	int value = 0;
	XCTAssertTrue([[self writtenValue] getIntValue:&value forKey:kFxGripRandomKey_Value]);
	return value;
}

#pragma mark Type identity

/*! @abstract The random parameter reports the random FxPlug type and the matching type string. */
- (void)testTheRandomParameterReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripRandomParameter.parameterType, FxParameterType_Random);
	XCTAssertEqualObjects(FxGripRandomParameter.parameterTypeString, kFxParameterType_Random);
}

/*! @abstract The decodable value classes cover the parameter dictionary and every class it may carry. */
- (void)testTheRandomParameterDecodesTheDictionaryAndItsElementClasses
{
	NSSet<Class> *classes = FxGripRandomParameter.customValueClasses;

	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
	for (Class element in FxGripDictionary.classesForParameter) {
		XCTAssertTrue([classes containsObject:element], @"%@ is decodable", element);
	}
}

#pragma mark Creation

/*! @abstract Creation stores the declared value, range, and step, and adds the custom-UI and no-state flags. */
- (void)testCreationStoresTheDeclaredValueRangeAndStep
{
	NSMutableDictionary *config = [self configWithDefault:@{kFxGripRandomKey_Value: @(7),
															kFxGripRandomKey_Min: @(2),
															kFxGripRandomKey_Max: @(9),
															kFxGripRandomKey_Step: @(3)}];
	config[kFxParameterProperty_Flags] = @(kFxParameterFlag_HIDDEN);

	XCTAssertTrue([FxGripRandomParameter addParameter:config toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	int stored = 0;
	XCTAssertTrue([value getIntValue:&stored forKey:kFxGripRandomKey_Value]);
	XCTAssertEqual(stored, 7);
	XCTAssertEqualObjects([value objectForKey:kFxGripRandomKey_Min], @(2));
	XCTAssertEqualObjects([value objectForKey:kFxGripRandomKey_Max], @(9));
	XCTAssertEqualObjects([value objectForKey:kFxGripRandomKey_Step], @(3));
	XCTAssertEqualObjects(self.call[@"name"], @"Seed", @"the control draws no label of its own");
	XCTAssertEqualObjects(self.call[@"flags"],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_CUSTOM_UI | kFxParameterFlag_NOSTATE));
}

/*! @abstract A configuration naming nothing falls back to the house defaults. */
- (void)testCreationFallsBackToTheHouseDefaults
{
	XCTAssertTrue([FxGripRandomParameter addParameter:[self configWithDefault:nil] toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	XCTAssertEqualObjects([value objectForKey:kFxGripRandomKey_Min], @(kFxGripRandomDefaultMin));
	XCTAssertEqualObjects([value objectForKey:kFxGripRandomKey_Max], @(kFxGripRandomDefaultMax));
	XCTAssertEqualObjects([value objectForKey:kFxGripRandomKey_Step], @(kFxGripRandomDefaultStep));
}

/*! @abstract A declared entry of the wrong class falls back to that entry's default. */
- (void)testADeclaredEntryOfAnotherClassFallsBackToItsDefault
{
	NSDictionary *declared = @{kFxGripRandomKey_Value: @"seven", kFxGripRandomKey_Max: @(50)};

	XCTAssertTrue([FxGripRandomParameter addParameter:[self configWithDefault:declared] toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	int stored = 0;
	[value getIntValue:&stored forKey:kFxGripRandomKey_Value];
	XCTAssertEqual(stored, kFxGripRandomDefaultValue);
	XCTAssertEqualObjects([value objectForKey:kFxGripRandomKey_Max], @(50));
}

/*! @abstract A host that refuses the creation is reported. */
- (void)testAHostRefusalIsReported
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([FxGripRandomParameter addParameter:[self configWithDefault:nil] toEffect:(id)self.effect]);
}

#pragma mark The vended view

/*! @abstract The parameter vends a view wired to itself and seeded from the declared configuration. */
- (void)testTheVendedViewIsWiredAndSeeded
{
	NSDictionary *declared = @{kFxGripRandomKey_Value: @(5), kFxGripRandomKey_Min: @(1), kFxGripRandomKey_Max: @(9)};
	FxGripRandomParameter *parameter =
		[FxGripRandomParameter.alloc initWithDictionary:[self configWithDefault:declared] effect:(id)self.effect];

	FxGripRandomView *view = (FxGripRandomView *)[parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripRandomView.class]);
	XCTAssertEqual(view.parameterID, kRandomTestParameter);
	XCTAssertEqualObjects((id)view.parameterEffect, self.effect);
	XCTAssertEqual([self fieldIn:view].integerValue, 5);
	XCTAssertEqualWithAccuracy([self stepperIn:view].minValue, 1.0, 1e-9);
	XCTAssertEqualWithAccuracy([self stepperIn:view].maxValue, 9.0, 1e-9);
}

/*! @abstract Without a declared configuration the vended view keeps the house defaults. */
- (void)testTheVendedViewKeepsTheDefaultsWithoutAConfiguration
{
	FxGripRandomParameter *parameter =
		[FxGripRandomParameter.alloc initWithDictionary:[self configWithDefault:nil] effect:(id)self.effect];

	FxGripRandomView *view = (FxGripRandomView *)[parameter newParameterView];

	XCTAssertEqual([self fieldIn:view].integerValue, kFxGripRandomDefaultValue);
	XCTAssertEqualWithAccuracy([self stepperIn:view].maxValue, (double)kFxGripRandomDefaultMax, 1e-9);
}

#pragma mark View layout

/*! @abstract The control lays out top-down and sizes itself to the field, stepper, and reload button. */
- (void)testTheControlSizesItselfToItsThreeParts
{
	FxGripRandomView *view = [self wiredView];

	XCTAssertTrue(view.isFlipped);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, 22.0, 1e-9);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.width, 60.0 + 19.0 + 28.0 + 2.0 * 4.0, 1e-9);
	XCTAssertNotNil([self reloadIn:view]);
	XCTAssertEqualObjects([self reloadIn:view].toolTip, @"Randomize");
}

#pragma mark Pushed value

/*! @abstract A pushed range and step reconfigure the stepper. */
- (void)testAPushedRangeAndStepReconfigureTheStepper
{
	FxGripRandomView *view = [self wiredView];

	[view updateFromCustomData:[self valueWith:@{kFxGripRandomKey_Min: @(10),
												kFxGripRandomKey_Max: @(20),
												kFxGripRandomKey_Step: @(5)}]];

	NSStepper *stepper = [self stepperIn:view];
	XCTAssertEqualWithAccuracy(stepper.minValue, 10.0, 1e-9);
	XCTAssertEqualWithAccuracy(stepper.maxValue, 20.0, 1e-9);
	XCTAssertEqualWithAccuracy(stepper.increment, 5.0, 1e-9);
}

/*! @abstract A reversed range is read low to high, so the stepper still counts upward. */
- (void)testAReversedRangeIsReadLowToHigh
{
	FxGripRandomView *view = [self wiredView];

	[view updateFromCustomData:[self valueWith:@{kFxGripRandomKey_Min: @(30), kFxGripRandomKey_Max: @(10)}]];

	XCTAssertEqualWithAccuracy([self stepperIn:view].minValue, 10.0, 1e-9);
	XCTAssertEqualWithAccuracy([self stepperIn:view].maxValue, 30.0, 1e-9);
}

/*! @abstract A step below one is raised to one, so the stepper always moves. */
- (void)testAStepBelowOneIsRaisedToOne
{
	FxGripRandomView *view = [self wiredView];

	[view updateFromCustomData:[self valueWith:@{kFxGripRandomKey_Step: @(0)}]];

	XCTAssertEqualWithAccuracy([self stepperIn:view].increment, 1.0, 1e-9);
}

/*! @abstract A pushed value is clamped into the range before it is shown, and it is not written back. */
- (void)testAPushedValueIsClampedAndNotWrittenBack
{
	FxGripRandomView *view = [self wiredView];

	[view updateFromCustomData:[self valueWith:@{kFxGripRandomKey_Min: @(1),
												kFxGripRandomKey_Max: @(9),
												kFxGripRandomKey_Value: @(50)}]];

	XCTAssertEqual([self fieldIn:view].integerValue, 9);
	XCTAssertEqual([self stepperIn:view].integerValue, 9);
	XCTAssertEqual(self.setter.writes.count, 0u, @"a pushed value is not an edit");
}

/*! @abstract A value of another class leaves the control untouched. */
- (void)testAValueOfAnotherClassIsIgnored
{
	FxGripRandomView *view = [self wiredView];
	[view updateFromCustomData:[self valueWith:@{kFxGripRandomKey_Value: @(4)}]];

	[view updateFromCustomData:(id)@"not a dictionary"];

	XCTAssertEqual([self fieldIn:view].integerValue, 4);
}

#pragma mark Edits

/*! @abstract An edit with no owning effect writes nothing. */
- (void)testAnEditWithoutAnEffectWritesNothing
{
	FxGripRandomView *view = [FxGripRandomView.alloc initWithFrame:NSMakeRect(0, 0, 120, 22)];
	[self fieldIn:view].integerValue = 3;

	[view fieldChanged:nil];

	XCTAssertEqual([self fieldIn:view].integerValue, 3, @"the control still shows the value");
	XCTAssertEqual(self.setter.writes.count, 0u);
}

/*! @abstract A typed value is clamped, shown, and written back at the host's current time inside one action bracket. */
- (void)testATypedValueIsClampedAndWrittenBack
{
	FxGripRandomView *view = [self wiredView];
	[view updateFromCustomData:[self valueWith:@{kFxGripRandomKey_Min: @(1), kFxGripRandomKey_Max: @(9)}]];
	[self fieldIn:view].integerValue = 40;

	@autoreleasepool {
		[view fieldChanged:nil];
	}

	XCTAssertEqual([self fieldIn:view].integerValue, 9);
	XCTAssertEqual(self.setter.writes.count, 1u);
	XCTAssertEqualObjects(self.setter.lastWrite[@"id"], @(kRandomTestParameter));
	XCTAssertEqualObjects(self.setter.lastWrite[@"timevalue"], @(90));
	XCTAssertEqual([self writtenInteger], 9);
	XCTAssertEqual(self.effect.randomManager.customParameterActionAPIv4.startCount, 1u);
	XCTAssertEqual(self.effect.randomManager.customParameterActionAPIv4.endCount, 1u);
}

/*! @abstract A stepper move is clamped, shown, and written back. */
- (void)testAStepperMoveIsClampedAndWrittenBack
{
	FxGripRandomView *view = [self wiredView];
	[view updateFromCustomData:[self valueWith:@{kFxGripRandomKey_Min: @(1), kFxGripRandomKey_Max: @(9)}]];
	[self stepperIn:view].integerValue = -5;

	[view stepperChanged:nil];

	XCTAssertEqual([self fieldIn:view].integerValue, 1);
	XCTAssertEqual([self writtenInteger], 1);
}

/*! @abstract The reload button draws a value inside the range and writes it back. */
- (void)testReloadDrawsAValueInsideTheRangeAndWritesItBack
{
	FxGripRandomView *view = [self wiredView];
	[view updateFromCustomData:[self valueWith:@{kFxGripRandomKey_Min: @(10), kFxGripRandomKey_Max: @(20)}]];

	for (NSUInteger draw = 0; draw < 25; draw++) {
		[view reloadClicked:nil];

		NSInteger shown = [self fieldIn:view].integerValue;
		XCTAssertGreaterThanOrEqual(shown, 10);
		XCTAssertLessThanOrEqual(shown, 20);
		XCTAssertEqual([self writtenInteger], (int)shown);
	}
	XCTAssertEqual(self.setter.writes.count, 25u);
}

/*! @abstract A single-value range always reloads to that value. */
- (void)testASingleValueRangeAlwaysReloadsToThatValue
{
	FxGripRandomView *view = [self wiredView];
	[view updateFromCustomData:[self valueWith:@{kFxGripRandomKey_Min: @(4), kFxGripRandomKey_Max: @(4)}]];

	[view reloadClicked:nil];

	XCTAssertEqual([self fieldIn:view].integerValue, 4);
}

/*! @abstract The full integer range reloads without overflowing its span arithmetic. */
- (void)testTheFullIntegerRangeReloadsWithoutOverflow
{
	FxGripRandomView *view = [self wiredView];
	[view updateFromCustomData:[self valueWith:@{kFxGripRandomKey_Min: @(INT32_MIN),
												kFxGripRandomKey_Max: @(INT32_MAX)}]];

	XCTAssertNoThrow([view reloadClicked:nil]);
	XCTAssertEqual(self.setter.writes.count, 1u);
}

/*! @abstract An edit against a host holding no dictionary writes a fresh one carrying the value. */
- (void)testAnEditWithoutAStoredValueWritesAFreshDictionary
{
	FxGripRandomView *view = [self wiredView];
	self.effect.apiManager.paramGetAPIv6.customValue = @"not a dictionary";
	[self fieldIn:view].integerValue = 6;

	[view fieldChanged:nil];

	XCTAssertTrue([[self writtenValue] isKindOfClass:FxGripDictionary.class]);
	XCTAssertEqual([self writtenInteger], 6);
}

/*! @abstract An edit unlocks the stored dictionary, so the value key writes even when the host locked it. */
- (void)testAnEditUnlocksTheStoredDictionaryBeforeWriting
{
	FxGripRandomView *view = [self wiredView];
	FxGripDictionary *stored = [self valueWith:@{}];
	stored.locked = YES;
	self.effect.apiManager.paramGetAPIv6.customValue = stored;
	[self fieldIn:view].integerValue = 6;

	[view fieldChanged:nil];

	XCTAssertFalse([self writtenValue].isLocked);
	XCTAssertEqual([self writtenInteger], 6);
}

@end
