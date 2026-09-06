/*!
	@file       FxGripParameterCreationAPI_v5Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterCreationAPI_v5Tests
	@abstract   Verifies the FxParameterCreationAPI_v5 wrapper's payload building, host forwarding, pre-notification round-trip, failure handling, and subgroup parenting.
	@discussion Introduced in FxGrip 0.1.0. Each test drives the wrapper against a recording stub host API and an isolated notifier. The tests assert the arguments the wrapper forwards, the notifications it posts, and the parent ID it derives from the subgroup stack.
*/

#import <XCTest/XCTest.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripParameterCreationAPI_v5.h>

static const FxParameterId kCreationTestParameter = 11;
static const FxParameterId kCreationTestGroup = 3;
static const FxParameterId kCreationTestInnerGroup = 4;

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxGripCreationTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

#pragma mark - Test doubles

/*!
	Stands in for the host's FxParameterCreationAPI_v5. Each call appends a dictionary
	naming the method and every argument it received, so the arguments the wrapper
	derives from the notification payload are observable.
*/
@interface FxGripCreationTestStubAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *calls;
@property (nonatomic, assign) BOOL succeeds;
@end

@implementation FxGripCreationTestStubAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_calls = NSMutableArray.new;
		_succeeds = YES;
	}
	return self;
}

- (BOOL)record:(NSString *)method arguments:(NSDictionary *)arguments
{
	NSMutableDictionary *call = arguments.mutableCopy;
	call[@"method"] = method;
	[self.calls addObject:call.copy];
	return self.succeeds;
}

- (BOOL)addAngleSliderWithName:(NSString *)name
				   parameterID:(UInt32)parameterID
				defaultDegrees:(double)defaultDegrees
		   parameterMinDegrees:(double)minDegrees
		   parameterMaxDegrees:(double)maxDegrees
				parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"angle" arguments:@{@"name": name,
											 @"id": @(parameterID),
											 @"default": @(defaultDegrees),
											 @"min": @(minDegrees),
											 @"max": @(maxDegrees),
											 @"flags": @(flags)}];
}

- (BOOL)addColorParameterWithName:(NSString *)name
					  parameterID:(UInt32)parameterID
					   defaultRed:(double)red
					 defaultGreen:(double)green
					  defaultBlue:(double)blue
					 defaultAlpha:(double)alpha
				   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"rgba" arguments:@{@"name": name,
											@"id": @(parameterID),
											@"red": @(red),
											@"green": @(green),
											@"blue": @(blue),
											@"alpha": @(alpha),
											@"flags": @(flags)}];
}

- (BOOL)addColorParameterWithName:(NSString *)name
					  parameterID:(UInt32)parameterID
					   defaultRed:(double)red
					 defaultGreen:(double)green
					  defaultBlue:(double)blue
				   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"rgb" arguments:@{@"name": name,
										   @"id": @(parameterID),
										   @"red": @(red),
										   @"green": @(green),
										   @"blue": @(blue),
										   @"flags": @(flags)}];
}

- (BOOL)addCustomParameterWithName:(NSString *)name
					   parameterID:(UInt32)parameterID
					  defaultValue:(NSObject<NSSecureCoding, NSCopying> *)defaultValue
					parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"custom" arguments:@{@"name": name,
											  @"id": @(parameterID),
											  @"default": defaultValue,
											  @"flags": @(flags)}];
}

- (BOOL)addFloatSliderWithName:(NSString *)name
				   parameterID:(UInt32)parameterID
				  defaultValue:(double)defaultValue
				  parameterMin:(double)min
				  parameterMax:(double)max
					 sliderMin:(double)sliderMin
					 sliderMax:(double)sliderMax
						 delta:(double)sliderDelta
				parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"float" arguments:@{@"name": name,
											 @"id": @(parameterID),
											 @"default": @(defaultValue),
											 @"min": @(min),
											 @"max": @(max),
											 @"slidermin": @(sliderMin),
											 @"slidermax": @(sliderMax),
											 @"delta": @(sliderDelta),
											 @"flags": @(flags)}];
}

- (BOOL)addFontMenuWithName:(NSString *)name
				parameterID:(UInt32)parameterID
				   fontName:(NSString *)fontName
			 parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"font" arguments:@{@"name": name,
											@"id": @(parameterID),
											@"default": fontName,
											@"flags": @(flags)}];
}

- (BOOL)addGradientWithName:(NSString *)name
				parameterID:(UInt32)parameterID
			 parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"gradient" arguments:@{@"name": name,
												@"id": @(parameterID),
												@"flags": @(flags)}];
}

- (BOOL)addHelpButtonWithName:(NSString *)name
				  parameterID:(UInt32)parameterID
					 selector:(SEL)selector
			   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"help" arguments:@{@"name": name,
											@"id": @(parameterID),
											@"selector": NSStringFromSelector(selector),
											@"flags": @(flags)}];
}

- (BOOL)addHistogramWithName:(NSString *)name
				 parameterID:(UInt32)parameterID
			  parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"histogram" arguments:@{@"name": name,
												 @"id": @(parameterID),
												 @"flags": @(flags)}];
}

- (BOOL)addImageReferenceWithName:(NSString *)name
					  parameterID:(UInt32)parameterID
				   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"imageref" arguments:@{@"name": name,
												@"id": @(parameterID),
												@"flags": @(flags)}];
}

- (BOOL)addIntSliderWithName:(NSString *)name
				 parameterID:(UInt32)parameterID
				defaultValue:(int)defaultValue
				parameterMin:(int)min
				parameterMax:(int)max
				   sliderMin:(int)sliderMin
				   sliderMax:(int)sliderMax
					   delta:(int)sliderDelta
			  parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"int" arguments:@{@"name": name,
										   @"id": @(parameterID),
										   @"default": @(defaultValue),
										   @"min": @(min),
										   @"max": @(max),
										   @"slidermin": @(sliderMin),
										   @"slidermax": @(sliderMax),
										   @"delta": @(sliderDelta),
										   @"flags": @(flags)}];
}

- (BOOL)addPathPickerWithName:(NSString *)name
				  parameterID:(UInt32)parameterID
			   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"path" arguments:@{@"name": name,
											@"id": @(parameterID),
											@"flags": @(flags)}];
}

- (BOOL)addPercentSliderWithName:(NSString *)name
					 parameterID:(UInt32)parameterID
					defaultValue:(double)defaultValue
					parameterMin:(double)min
					parameterMax:(double)max
					   sliderMin:(double)sliderMin
					   sliderMax:(double)sliderMax
						   delta:(double)sliderDelta
				  parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"percent" arguments:@{@"name": name,
											   @"id": @(parameterID),
											   @"default": @(defaultValue),
											   @"min": @(min),
											   @"max": @(max),
											   @"slidermin": @(sliderMin),
											   @"slidermax": @(sliderMax),
											   @"delta": @(sliderDelta),
											   @"flags": @(flags)}];
}

- (BOOL)addPointParameterWithName:(NSString *)name
					  parameterID:(UInt32)parameterID
						 defaultX:(double)defaultX
						 defaultY:(double)defaultY
				   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"point" arguments:@{@"name": name,
											 @"id": @(parameterID),
											 @"x": @(defaultX),
											 @"y": @(defaultY),
											 @"flags": @(flags)}];
}

- (BOOL)addPopupMenuWithName:(NSString *)name
				 parameterID:(UInt32)parameterID
				defaultValue:(UInt32)defaultValue
				 menuEntries:(NSArray *)entries
			  parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"menu" arguments:@{@"name": name,
											@"id": @(parameterID),
											@"default": @(defaultValue),
											@"items": entries ?: NSNull.null,
											@"flags": @(flags)}];
}

- (BOOL)addPushButtonWithName:(NSString *)name
				  parameterID:(UInt32)parameterID
					 selector:(SEL)selector
			   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"button" arguments:@{@"name": name,
											  @"id": @(parameterID),
											  @"selector": NSStringFromSelector(selector),
											  @"flags": @(flags)}];
}

- (BOOL)addStringParameterWithName:(NSString *)name
					   parameterID:(UInt32)parameterID
					  defaultValue:(NSString *)defaultValue
					parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"string" arguments:@{@"name": name,
											  @"id": @(parameterID),
											  @"default": defaultValue,
											  @"flags": @(flags)}];
}

- (BOOL)addToggleButtonWithName:(NSString *)name
					parameterID:(UInt32)parameterID
				   defaultValue:(BOOL)defaultValue
				 parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"toggle" arguments:@{@"name": name,
											  @"id": @(parameterID),
											  @"default": @(defaultValue),
											  @"flags": @(flags)}];
}

- (BOOL)startParameterSubGroup:(NSString *)name
				   parameterID:(UInt32)parameterID
				parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"startgroup" arguments:@{@"name": name,
												  @"id": @(parameterID),
												  @"flags": @(flags)}];
}

- (BOOL)endParameterSubGroup
{
	return [self record:@"endgroup" arguments:@{}];
}

@end

/*!
	FxGripTileableEffect's designated initializer registers into the process-wide
	notification center, so the wrapper is exercised against a stub carrying an isolated
	notifier. The creation wrapper reads only -notifier from its effect.
*/
@interface FxGripCreationTestStubEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@end

@implementation FxGripCreationTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxGripCreationTestMakePriorityCenter();
	}
	return self;
}

@end

#pragma mark - Tests

@interface FxGripParameterCreationAPI_v5Tests : XCTestCase
@property (nonatomic, strong) FxGripCreationTestStubEffect *effect;
@property (nonatomic, strong) FxGripCreationTestStubAPI *hostAPI;
@property (nonatomic, strong) FxGripParameterCreationAPI_v5 *api;
@property (nonatomic, strong) NSMutableArray<NSNotification *> *posted;
// The notifier holds its observers weakly, so every token is retained for the test.
@property (nonatomic, strong) NSMutableArray *observerTokens;
@end

@implementation FxGripParameterCreationAPI_v5Tests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripCreationTestStubEffect.alloc init];
	self.hostAPI = [FxGripCreationTestStubAPI.alloc init];
	self.api = [FxGripParameterCreationAPI_v5.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
	self.posted = NSMutableArray.new;
	self.observerTokens = NSMutableArray.new;
	for (NSNotificationName name in self.recordedNotificationNames) {
		[self observeName:name usingBlock:^(NSNotification *notification) {
			[self.posted addObject:notification];
		}];
	}
}

- (void)tearDown
{
	for (id token in self.observerTokens) {
		[self.effect.notifier removeObserver:token];
	}
	self.observerTokens = nil;
	self.posted = nil;
	self.api = nil;
	self.hostAPI = nil;
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSArray<NSNotificationName> *)recordedNotificationNames
{
	return @[FxGripNotifyAPI_ParameterSetNamePreName,
			 FxGripNotifyAPI_ParameterAddPreName,
			 FxGripNotifyAPI_ParameterAddName,
			 FxGripNotifyAPI_ParameterStartGroupName,
			 FxGripNotifyAPI_ParameterEndGroupName];
}

- (void)observeName:(NSNotificationName)name usingBlock:(void (^)(NSNotification *notification))block
{
	id token = [self.effect.notifier addObserverForName:name object:nil queue:nil usingBlock:block];
	[self.observerTokens addObject:token];
}

- (NSArray<NSNotificationName> *)postedNames
{
	NSMutableArray<NSNotificationName> *names = NSMutableArray.new;
	for (NSNotification *notification in self.posted) {
		[names addObject:notification.name];
	}
	return names;
}

- (NSNotification *)notificationNamed:(NSNotificationName)name
{
	for (NSNotification *notification in self.posted) {
		if ([notification.name isEqualToString:name]) {
			return notification;
		}
	}
	return nil;
}

/*! The nested parameter dictionary carried by the completed add notification. */
- (NSDictionary *)addedParameter
{
	return [self notificationNamed:FxGripNotifyAPI_ParameterAddName].userInfo.fxParameter;
}

- (NSDictionary *)hostCall
{
	return self.hostAPI.calls.firstObject;
}

/*! Registers an observer that rewrites one key of the nested pre-notification payload. */
- (void)rewriteAddPreKey:(NSString *)key toValue:(id)value
{
	[self observeName:FxGripNotifyAPI_ParameterAddPreName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[key] = value;
	}];
}

- (BOOL)addFloatParameter
{
	return [self.api addFloatSliderWithName:@"Amount"
								parameterID:kCreationTestParameter
							   defaultValue:0.5
							   parameterMin:0.0
							   parameterMax:1.0
								  sliderMin:0.1
								  sliderMax:0.9
									  delta:0.01
							 parameterFlags:kFxParameterFlag_DEFAULT];
}

#pragma mark Per-method forwarding

/*! The maximum travels through -parameterMaximumDouble, which only this method reads. */
- (void)testAddAngleSliderForwardsItsBoundsAndPostsTheAnglePayload
{
	XCTAssertTrue([self.api addAngleSliderWithName:@"Rotation"
									   parameterID:kCreationTestParameter
									defaultDegrees:45.0
							   parameterMinDegrees:-180.0
							   parameterMaxDegrees:180.0
									parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"angle",
											@"name": @"Rotation",
											@"id": @(kCreationTestParameter),
											@"default": @45.0,
											@"min": @(-180.0),
											@"max": @180.0,
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	NSDictionary *parameter = self.addedParameter;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], @(FxParameterType_Angle));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Name], @"Rotation");
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Minimum], @(-180.0));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Maximum], @180.0);
}

/*! @abstract A four-component color forwards each RGBA component to the host and posts an RGBA-typed add payload. */
- (void)testAddColorParameterWithAlphaForwardsEveryComponent
{
	XCTAssertTrue([self.api addColorParameterWithName:@"Tint"
										  parameterID:kCreationTestParameter
										   defaultRed:0.1
										 defaultGreen:0.2
										  defaultBlue:0.3
										 defaultAlpha:0.4
									   parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"rgba",
											@"name": @"Tint",
											@"id": @(kCreationTestParameter),
											@"red": @0.1,
											@"green": @0.2,
											@"blue": @0.3,
											@"alpha": @0.4,
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_RGBA));
}

/*! @abstract A three-component color forwards only RGB to the host, posts an RGB-typed payload, and carries no alpha. */
- (void)testAddColorParameterWithoutAlphaForwardsThreeComponents
{
	XCTAssertTrue([self.api addColorParameterWithName:@"Tint"
										  parameterID:kCreationTestParameter
										   defaultRed:0.1
										 defaultGreen:0.2
										  defaultBlue:0.3
									   parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"rgb",
											@"name": @"Tint",
											@"id": @(kCreationTestParameter),
											@"red": @0.1,
											@"green": @0.2,
											@"blue": @0.3,
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	NSDictionary *parameter = self.addedParameter;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], @(FxParameterType_RGB));
	XCTAssertNil(parameter[kFxParameterProperty_Alpha], @"the three-component payload carries no alpha");
}

/*! @abstract A custom parameter forwards its default object to the host and posts a custom-typed add payload. */
- (void)testAddCustomParameterForwardsTheDefaultObject
{
	NSString *defaultValue = @"CustomDefault";

	XCTAssertTrue([self.api addCustomParameterWithName:@"Data"
										   parameterID:kCreationTestParameter
										  defaultValue:defaultValue
										parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"custom",
											@"name": @"Data",
											@"id": @(kCreationTestParameter),
											@"default": defaultValue,
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_Custom));
}

/*! @abstract A float slider forwards its default, bounds, slider range, and delta to the host and posts a float-typed payload. */
- (void)testAddFloatSliderForwardsEveryBoundAndTheDelta
{
	XCTAssertTrue([self addFloatParameter]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"float",
											@"name": @"Amount",
											@"id": @(kCreationTestParameter),
											@"default": @0.5,
											@"min": @0.0,
											@"max": @1.0,
											@"slidermin": @0.1,
											@"slidermax": @0.9,
											@"delta": @0.01,
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_Float));
}

/*! @abstract A font menu forwards its font name as the default and posts a font-menu-typed payload holding that name. */
- (void)testAddFontMenuCarriesTheFontNameAsTheDefault
{
	XCTAssertTrue([self.api addFontMenuWithName:@"Typeface"
									parameterID:kCreationTestParameter
									   fontName:@"Helvetica"
								 parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"font",
											@"name": @"Typeface",
											@"id": @(kCreationTestParameter),
											@"default": @"Helvetica",
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	NSDictionary *parameter = self.addedParameter;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], @(FxParameterType_FontMenu));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Default], @"Helvetica");
}

/*! @abstract A gradient forwards its name, ID, and flags to the host and posts a gradient-typed payload. */
- (void)testAddGradientForwardsNameIDAndFlags
{
	XCTAssertTrue([self.api addGradientWithName:@"Ramp"
									parameterID:kCreationTestParameter
								 parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"gradient",
											@"name": @"Ramp",
											@"id": @(kCreationTestParameter),
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_Gradient));
}

/*! @abstract A help button forwards its selector as a string to the host and posts a help-typed payload carrying that selector string. */
- (void)testAddHelpButtonRoundTripsTheSelectorThroughTheStringPayload
{
	XCTAssertTrue([self.api addHelpButtonWithName:@"Help"
									  parameterID:kCreationTestParameter
										 selector:@selector(setUp)
								   parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"help",
											@"name": @"Help",
											@"id": @(kCreationTestParameter),
											@"selector": @"setUp",
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	NSDictionary *parameter = self.addedParameter;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], @(FxParameterType_Help));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Selector], @"setUp");
}

/*! @abstract A histogram forwards its name, ID, and flags to the host and posts a histogram-typed payload. */
- (void)testAddHistogramForwardsNameIDAndFlags
{
	XCTAssertTrue([self.api addHistogramWithName:@"Levels"
									 parameterID:kCreationTestParameter
								  parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"histogram",
											@"name": @"Levels",
											@"id": @(kCreationTestParameter),
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_Histogram));
}

/*! @abstract An image reference forwards its name, ID, and flags to the host and posts an image-ref-typed payload. */
- (void)testAddImageReferenceForwardsNameIDAndFlags
{
	XCTAssertTrue([self.api addImageReferenceWithName:@"Source"
										  parameterID:kCreationTestParameter
									   parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"imageref",
											@"name": @"Source",
											@"id": @(kCreationTestParameter),
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_ImageRef));
}

/*! @abstract An int slider posts its default, bounds, slider range, and delta in the int-typed add payload. */
- (void)testAddIntSliderPostsEveryBoundInThePayload
{
	XCTAssertTrue([self.api addIntSliderWithName:@"Count"
									 parameterID:kCreationTestParameter
									defaultValue:5
									parameterMin:1
									parameterMax:100
									   sliderMin:2
									   sliderMax:50
										   delta:3
								  parameterFlags:kFxParameterFlag_DEFAULT]);

	NSDictionary *parameter = self.addedParameter;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], @(FxParameterType_Int));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Default], @5);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Minimum], @1);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Maximum], @100);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_SliderMinimum], @2);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_SliderMaximum], @50);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Delta], @3);
}

/*!
	DEFECT: addIntSliderWithName: reads parameterDefaultValue for the minimum, maximum,
	slider minimum, slider maximum, and delta it forwards, so every bound of an integer
	slider reaches the host as the default value. The float and percent sliders read the
	matching payload keys. This test states the intended forwarding and fails today.
*/
- (void)testAddIntSliderForwardsEachBoundFromItsOwnPayloadKey
{
	[self.api addIntSliderWithName:@"Count"
					   parameterID:kCreationTestParameter
					  defaultValue:5
					  parameterMin:1
					  parameterMax:100
						 sliderMin:2
						 sliderMax:50
							 delta:3
					parameterFlags:kFxParameterFlag_DEFAULT];

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"int",
											@"name": @"Count",
											@"id": @(kCreationTestParameter),
											@"default": @5,
											@"min": @1,
											@"max": @100,
											@"slidermin": @2,
											@"slidermax": @50,
											@"delta": @3,
											@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract A path picker forwards its name, ID, and flags to the host and posts a path-typed payload. */
- (void)testAddPathPickerForwardsNameIDAndFlags
{
	XCTAssertTrue([self.api addPathPickerWithName:@"Shape"
									  parameterID:kCreationTestParameter
								   parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"path",
											@"name": @"Shape",
											@"id": @(kCreationTestParameter),
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_PathID));
}

/*! @abstract A percent slider forwards its default, bounds, slider range, and delta to the host and posts a percent-typed payload. */
- (void)testAddPercentSliderForwardsEveryBoundAndTheDelta
{
	XCTAssertTrue([self.api addPercentSliderWithName:@"Mix"
										 parameterID:kCreationTestParameter
										defaultValue:0.5
										parameterMin:0.0
										parameterMax:2.0
										   sliderMin:0.25
										   sliderMax:1.75
											   delta:0.05
									  parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"percent",
											@"name": @"Mix",
											@"id": @(kCreationTestParameter),
											@"default": @0.5,
											@"min": @0.0,
											@"max": @2.0,
											@"slidermin": @0.25,
											@"slidermax": @1.75,
											@"delta": @0.05,
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_Percent));
}

/*! @abstract A point parameter forwards both default coordinates to the host and posts a point-typed payload. */
- (void)testAddPointParameterForwardsBothCoordinates
{
	XCTAssertTrue([self.api addPointParameterWithName:@"Center"
										  parameterID:kCreationTestParameter
											 defaultX:0.25
											 defaultY:0.75
									   parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"point",
											@"name": @"Center",
											@"id": @(kCreationTestParameter),
											@"x": @0.25,
											@"y": @0.75,
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_Point));
}

/*! @abstract A popup menu forwards its entries to the host and posts a menu-typed payload carrying those entries. */
- (void)testAddPopupMenuForwardsTheEntriesAndPostsTheMenuPayload
{
	NSArray *entries = @[@"One", @"Two", @"Three"];

	XCTAssertTrue([self.api addPopupMenuWithName:@"Mode"
									 parameterID:kCreationTestParameter
									defaultValue:2
									 menuEntries:entries
								  parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall[@"name"], @"Mode");
	XCTAssertEqualObjects(self.hostCall[@"id"], @(kCreationTestParameter));
	XCTAssertEqualObjects(self.hostCall[@"items"], entries);
	NSDictionary *parameter = self.addedParameter;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], @(FxParameterType_Menu));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_MenuItems], entries);
}

/*!
	DEFECT: addPopupMenuWithName: never writes its defaultValue argument into the payload
	it builds, and then reads the default index back out of that payload. Every popup menu
	reaches the host with index 0. This test states the intended forwarding and fails today.
*/
- (void)testAddPopupMenuForwardsTheDefaultIndexToTheHost
{
	[self.api addPopupMenuWithName:@"Mode"
					   parameterID:kCreationTestParameter
					  defaultValue:2
					   menuEntries:@[@"One", @"Two", @"Three"]
					parameterFlags:kFxParameterFlag_DEFAULT];

	XCTAssertEqualObjects(self.hostCall[@"default"], @2);
}

/*! @abstract A push button forwards its selector as a string to the host and posts a push-button-typed payload. */
- (void)testAddPushButtonRoundTripsTheSelectorThroughTheStringPayload
{
	XCTAssertTrue([self.api addPushButtonWithName:@"Reset"
									  parameterID:kCreationTestParameter
										 selector:@selector(tearDown)
								   parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"button",
											@"name": @"Reset",
											@"id": @(kCreationTestParameter),
											@"selector": @"tearDown",
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_PushButton));
}

/*! @abstract A string parameter forwards its default string to the host and posts a string-typed payload. */
- (void)testAddStringParameterForwardsTheDefaultString
{
	XCTAssertTrue([self.api addStringParameterWithName:@"Label"
										   parameterID:kCreationTestParameter
										  defaultValue:@"Hello"
										parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"string",
											@"name": @"Label",
											@"id": @(kCreationTestParameter),
											@"default": @"Hello",
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_String));
}

/*! @abstract A toggle button forwards its default boolean state to the host and posts a toggle-typed payload. */
- (void)testAddToggleButtonForwardsTheDefaultState
{
	XCTAssertTrue([self.api addToggleButtonWithName:@"Enabled"
										parameterID:kCreationTestParameter
									   defaultValue:YES
									 parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"toggle",
											@"name": @"Enabled",
											@"id": @(kCreationTestParameter),
											@"default": @YES,
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_Toggle));
}

#pragma mark Selector rewriting

/*! @abstract An observer that rewrites the selector string in the pre-notification changes the selector the host receives. */
- (void)testAnObserverRewritingTheSelectorStringChangesTheSelectorTheHostReceives
{
	[self rewriteAddPreKey:kFxParameterProperty_Selector toValue:@"tearDown"];

	XCTAssertTrue([self.api addPushButtonWithName:@"Reset"
									  parameterID:kCreationTestParameter
										 selector:@selector(setUp)
								   parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall[@"selector"], @"tearDown");
}

#pragma mark Preprocess round-trip

/*! @abstract A creation posts the name-pre, then the add-pre, then the add notification in that order. */
- (void)testEveryCreationPostsTheNamePreThenTheAddPreThenTheAddNotification
{
	XCTAssertTrue([self addFloatParameter]);

	XCTAssertEqualObjects(self.postedNames, (@[FxGripNotifyAPI_ParameterSetNamePreName,
											   FxGripNotifyAPI_ParameterAddPreName,
											   FxGripNotifyAPI_ParameterAddName]));
}

/*! @abstract The pre-notification runs while the host has not been called, and the host receives exactly one call afterward. */
- (void)testThePreNotificationsRunBeforeTheHostIsCalled
{
	__block NSUInteger callsAtPre = NSUIntegerMax;
	[self observeName:FxGripNotifyAPI_ParameterAddPreName usingBlock:^(NSNotification *notification) {
		callsAtPre = self.hostAPI.calls.count;
	}];

	XCTAssertTrue([self addFloatParameter]);

	XCTAssertEqual(callsAtPre, (NSUInteger)0);
	XCTAssertEqual(self.hostAPI.calls.count, (NSUInteger)1);
}

/*! @abstract The add pre-notification carries the parameter ID both in the top-level userInfo and in the nested parameter payload. */
- (void)testThePreNotificationCarriesTheParameterIDAtBothLevels
{
	__block NSDictionary *seen = nil;
	[self observeName:FxGripNotifyAPI_ParameterAddPreName usingBlock:^(NSNotification *notification) {
		seen = @{@"outer": notification.userInfo[kFxParameterProperty_Id],
				 @"nested": notification.userInfo.fxParameter[kFxParameterProperty_Id]};
	}];

	[self addFloatParameter];

	XCTAssertEqualObjects(seen, (@{@"outer": @(kCreationTestParameter),
								   @"nested": @(kCreationTestParameter)}));
}

/*! @abstract The nested parameter payload of the add pre-notification is mutable so an observer can rewrite it. */
- (void)testTheNestedPreNotificationPayloadIsMutable
{
	__block BOOL mutable = NO;
	[self observeName:FxGripNotifyAPI_ParameterAddPreName usingBlock:^(NSNotification *notification) {
		mutable = notification.userInfo.mutableFxParameter != nil;
	}];

	[self addFloatParameter];

	XCTAssertTrue(mutable);
}

/*! @abstract An observer that rewrites the name in the pre-notification changes the name the host and the completed add payload receive. */
- (void)testAnObserverRewritingTheNameChangesTheNameTheHostReceives
{
	[self rewriteAddPreKey:kFxParameterProperty_Name toValue:@"Rewritten"];

	XCTAssertTrue([self addFloatParameter]);

	XCTAssertEqualObjects(self.hostCall[@"name"], @"Rewritten");
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Name], @"Rewritten");
}

/*! @abstract An observer that rewrites the default, minimum, maximum, and delta in the pre-notification changes each value the host receives. */
- (void)testAnObserverRewritingTheDefaultAndBoundsChangesWhatTheHostReceives
{
	[self observeName:FxGripNotifyAPI_ParameterAddPreName usingBlock:^(NSNotification *notification) {
		NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
		parameter[kFxParameterProperty_Default] = @0.75;
		parameter[kFxParameterProperty_Minimum] = @(-1.0);
		parameter[kFxParameterProperty_Maximum] = @2.0;
		parameter[kFxParameterProperty_Delta] = @0.5;
	}];

	XCTAssertTrue([self addFloatParameter]);

	XCTAssertEqualObjects(self.hostCall[@"default"], @0.75);
	XCTAssertEqualObjects(self.hostCall[@"min"], @(-1.0));
	XCTAssertEqualObjects(self.hostCall[@"max"], @2.0);
	XCTAssertEqualObjects(self.hostCall[@"delta"], @0.5);
}

/*! @abstract An observer that rewrites the flags in the pre-notification changes the flags the host receives. */
- (void)testAnObserverRewritingTheFlagsChangesTheFlagsTheHostReceives
{
	[self rewriteAddPreKey:kFxParameterProperty_Flags
				   toValue:@(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED)];

	XCTAssertTrue([self addFloatParameter]);

	XCTAssertEqualObjects(self.hostCall[@"flags"],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED));
}

/*! @abstract The FxGrip-only flag bits are masked off the value the host receives while the payload keeps them for observers. */
- (void)testTheFxGripOnlyFlagBitsAreMaskedOffBeforeReachingTheHost
{
	FxParameterFlags flags = kFxParameterFlag_HIDDEN | kFxParameterFlag_HIDDEN_PROXY
		| kFxParameterFlag_NO_DEBUG;

	XCTAssertTrue([self.api addGradientWithName:@"Ramp"
									parameterID:kCreationTestParameter
								 parameterFlags:flags]);

	XCTAssertEqualObjects(self.hostCall[@"flags"], @(kFxParameterFlag_HIDDEN),
						  @"only the bits Apple defines survive the mask");
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Flags], @(flags),
						  @"the payload keeps the FxGrip bits for the observers");
}

/*! @abstract An observer's writes to the ID, type, and parent ID in the pre-notification are ignored, and the original values reach the host and the add payload. */
- (void)testAnObserverCannotChangeTheIDTypeOrParentThroughThePreNotification
{
	[self observeName:FxGripNotifyAPI_ParameterAddPreName usingBlock:^(NSNotification *notification) {
		NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
		parameter[kFxParameterProperty_Id] = @999;
		parameter[kFxParameterProperty_Type] = @(FxParameterType_String);
		parameter[kFxParameterProperty_ParentId] = @888;
	}];

	XCTAssertTrue([self addFloatParameter]);

	XCTAssertEqualObjects(self.hostCall[@"id"], @(kCreationTestParameter));
	NSDictionary *parameter = self.addedParameter;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Id], @(kCreationTestParameter));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], @(FxParameterType_Float));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_ParentId], @(kFxParameterId_TopLevelGroup));
}

/*! @abstract The completed add notification carries a frozen, non-mutable nested parameter payload. */
- (void)testTheAddNotificationCarriesAnImmutableNestedPayload
{
	XCTAssertTrue([self addFloatParameter]);

	NSDictionary *parameter = self.addedParameter;
	XCTAssertNotNil(parameter);
	XCTAssertFalse([parameter isKindOfClass:NSMutableDictionary.class],
				   @"the completed add hands observers a frozen copy");
}

#pragma mark Failure paths

/*! @abstract An observer that sets an error on the add pre-notification returns NO, skips the host call, and posts no completed add notification. */
- (void)testAnObserverSettingAnErrorAbortsTheCreationBeforeTheHostIsCalled
{
	[self observeName:FxGripNotifyAPI_ParameterAddPreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError =
			[NSError errorWithDomain:@"FxGripCreationTest" code:1 userInfo:nil];
	}];

	XCTAssertFalse([self addFloatParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertNil([self notificationNamed:FxGripNotifyAPI_ParameterAddName]);
}

/*! @abstract An observer that sets an error on the name pre-notification returns NO and skips the host call. */
- (void)testAnErrorFromTheNamePreNotificationAlsoAbortsTheCreation
{
	[self observeName:FxGripNotifyAPI_ParameterSetNamePreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError =
			[NSError errorWithDomain:@"FxGripCreationTest" code:1 userInfo:nil];
	}];

	XCTAssertFalse([self addFloatParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

/*! @abstract A host refusal returns NO, still calls the host once, posts no completed add notification, and posts only the two pre-notifications. */
- (void)testAHostRefusalReturnsNOAndPostsNoAddNotification
{
	self.hostAPI.succeeds = NO;

	XCTAssertFalse([self addFloatParameter]);

	XCTAssertEqual(self.hostAPI.calls.count, (NSUInteger)1);
	XCTAssertNil([self notificationNamed:FxGripNotifyAPI_ParameterAddName]);
	XCTAssertEqualObjects(self.postedNames, (@[FxGripNotifyAPI_ParameterSetNamePreName,
											   FxGripNotifyAPI_ParameterAddPreName]));
}

/*! @abstract Every creation method and both subgroup methods return NO on a host refusal and post no completed add notification. */
- (void)testEveryCreationMethodReportsAHostRefusal
{
	self.hostAPI.succeeds = NO;

	XCTAssertFalse([self.api addAngleSliderWithName:@"A" parameterID:1 defaultDegrees:0 parameterMinDegrees:0 parameterMaxDegrees:1 parameterFlags:0]);
	XCTAssertFalse([self.api addColorParameterWithName:@"B" parameterID:2 defaultRed:0 defaultGreen:0 defaultBlue:0 defaultAlpha:0 parameterFlags:0]);
	XCTAssertFalse([self.api addColorParameterWithName:@"C" parameterID:3 defaultRed:0 defaultGreen:0 defaultBlue:0 parameterFlags:0]);
	XCTAssertFalse([self.api addCustomParameterWithName:@"D" parameterID:4 defaultValue:@"x" parameterFlags:0]);
	XCTAssertFalse([self.api addFloatSliderWithName:@"E" parameterID:5 defaultValue:0 parameterMin:0 parameterMax:1 sliderMin:0 sliderMax:1 delta:0 parameterFlags:0]);
	XCTAssertFalse([self.api addFontMenuWithName:@"F" parameterID:6 fontName:@"Helvetica" parameterFlags:0]);
	XCTAssertFalse([self.api addGradientWithName:@"G" parameterID:7 parameterFlags:0]);
	XCTAssertFalse([self.api addHelpButtonWithName:@"H" parameterID:8 selector:@selector(setUp) parameterFlags:0]);
	XCTAssertFalse([self.api addHistogramWithName:@"I" parameterID:9 parameterFlags:0]);
	XCTAssertFalse([self.api addImageReferenceWithName:@"J" parameterID:10 parameterFlags:0]);
	XCTAssertFalse([self.api addIntSliderWithName:@"K" parameterID:11 defaultValue:0 parameterMin:0 parameterMax:1 sliderMin:0 sliderMax:1 delta:1 parameterFlags:0]);
	XCTAssertFalse([self.api addPathPickerWithName:@"L" parameterID:12 parameterFlags:0]);
	XCTAssertFalse([self.api addPercentSliderWithName:@"M" parameterID:13 defaultValue:0 parameterMin:0 parameterMax:1 sliderMin:0 sliderMax:1 delta:0 parameterFlags:0]);
	XCTAssertFalse([self.api addPointParameterWithName:@"N" parameterID:14 defaultX:0 defaultY:0 parameterFlags:0]);
	XCTAssertFalse([self.api addPopupMenuWithName:@"O" parameterID:15 defaultValue:0 menuEntries:@[@"x"] parameterFlags:0]);
	XCTAssertFalse([self.api addPushButtonWithName:@"P" parameterID:16 selector:@selector(setUp) parameterFlags:0]);
	XCTAssertFalse([self.api addStringParameterWithName:@"Q" parameterID:17 defaultValue:@"x" parameterFlags:0]);
	XCTAssertFalse([self.api addToggleButtonWithName:@"R" parameterID:18 defaultValue:NO parameterFlags:0]);
	XCTAssertFalse([self.api startParameterSubGroup:@"S" parameterID:19 parameterFlags:0]);
	XCTAssertFalse([self.api endParameterSubGroup]);

	XCTAssertNil([self notificationNamed:FxGripNotifyAPI_ParameterAddName]);
}

/*! @abstract An observer error on the add pre-notification aborts every creation method before the host is called and leaves the subgroup stack at the root. */
- (void)testAnObserverErrorAbortsEveryCreationMethodBeforeTheHostIsCalled
{
	[self observeName:FxGripNotifyAPI_ParameterAddPreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError =
			[NSError errorWithDomain:@"FxGripCreationTest" code:1 userInfo:nil];
	}];

	XCTAssertFalse([self.api addAngleSliderWithName:@"A" parameterID:1 defaultDegrees:0 parameterMinDegrees:0 parameterMaxDegrees:1 parameterFlags:0]);
	XCTAssertFalse([self.api addColorParameterWithName:@"B" parameterID:2 defaultRed:0 defaultGreen:0 defaultBlue:0 defaultAlpha:0 parameterFlags:0]);
	XCTAssertFalse([self.api addColorParameterWithName:@"C" parameterID:3 defaultRed:0 defaultGreen:0 defaultBlue:0 parameterFlags:0]);
	XCTAssertFalse([self.api addCustomParameterWithName:@"D" parameterID:4 defaultValue:@"x" parameterFlags:0]);
	XCTAssertFalse([self.api addFloatSliderWithName:@"E" parameterID:5 defaultValue:0 parameterMin:0 parameterMax:1 sliderMin:0 sliderMax:1 delta:0 parameterFlags:0]);
	XCTAssertFalse([self.api addFontMenuWithName:@"F" parameterID:6 fontName:@"Helvetica" parameterFlags:0]);
	XCTAssertFalse([self.api addGradientWithName:@"G" parameterID:7 parameterFlags:0]);
	XCTAssertFalse([self.api addHelpButtonWithName:@"H" parameterID:8 selector:@selector(setUp) parameterFlags:0]);
	XCTAssertFalse([self.api addHistogramWithName:@"I" parameterID:9 parameterFlags:0]);
	XCTAssertFalse([self.api addImageReferenceWithName:@"J" parameterID:10 parameterFlags:0]);
	XCTAssertFalse([self.api addIntSliderWithName:@"K" parameterID:11 defaultValue:0 parameterMin:0 parameterMax:1 sliderMin:0 sliderMax:1 delta:1 parameterFlags:0]);
	XCTAssertFalse([self.api addPathPickerWithName:@"L" parameterID:12 parameterFlags:0]);
	XCTAssertFalse([self.api addPercentSliderWithName:@"M" parameterID:13 defaultValue:0 parameterMin:0 parameterMax:1 sliderMin:0 sliderMax:1 delta:0 parameterFlags:0]);
	XCTAssertFalse([self.api addPointParameterWithName:@"N" parameterID:14 defaultX:0 defaultY:0 parameterFlags:0]);
	XCTAssertFalse([self.api addPopupMenuWithName:@"O" parameterID:15 defaultValue:0 menuEntries:@[@"x"] parameterFlags:0]);
	XCTAssertFalse([self.api addPushButtonWithName:@"P" parameterID:16 selector:@selector(setUp) parameterFlags:0]);
	XCTAssertFalse([self.api addStringParameterWithName:@"Q" parameterID:17 defaultValue:@"x" parameterFlags:0]);
	XCTAssertFalse([self.api addToggleButtonWithName:@"R" parameterID:18 defaultValue:NO parameterFlags:0]);
	XCTAssertFalse([self.api startParameterSubGroup:@"S" parameterID:19 parameterFlags:0]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertEqualObjects(self.api.subGroupStack, @[@(kFxParameterId_TopLevelGroup)]);
}

#pragma mark Subgroup stack

/*! @abstract The subgroup stack starts holding only the top-level group sentinel. */
- (void)testTheStackStartsAtTheTopLevelGroup
{
	XCTAssertEqualObjects(self.api.subGroupStack, @[@(kFxParameterId_TopLevelGroup)]);
}

/*! @abstract A parameter added outside any subgroup names the top-level group as its parent. */
- (void)testAParameterAddedOutsideAnySubGroupNamesTheTopLevelGroupAsItsParent
{
	XCTAssertTrue([self addFloatParameter]);

	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_ParentId],
						  @(kFxParameterId_TopLevelGroup));
}

/*! @abstract Starting a subgroup forwards the group to the host, pushes it onto the stack, and posts the add and start-group notifications with a group-typed payload. */
- (void)testStartParameterSubGroupPushesTheGroupAndPostsBothGroupNotifications
{
	XCTAssertTrue([self.api startParameterSubGroup:@"Group"
									   parameterID:kCreationTestGroup
									parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects(self.hostCall, (@{@"method": @"startgroup",
											@"name": @"Group",
											@"id": @(kCreationTestGroup),
											@"flags": @(kFxParameterFlag_DEFAULT)}));
	XCTAssertEqualObjects(self.postedNames, (@[FxGripNotifyAPI_ParameterSetNamePreName,
											   FxGripNotifyAPI_ParameterAddPreName,
											   FxGripNotifyAPI_ParameterAddName,
											   FxGripNotifyAPI_ParameterStartGroupName]));
	XCTAssertEqualObjects(self.api.subGroupStack, (@[@(kFxParameterId_TopLevelGroup),
													 @(kCreationTestGroup)]));
	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_Type], @(FxParameterType_Group));
}

/*! @abstract A parameter added inside an open subgroup names that group as its parent. */
- (void)testAParameterAddedInsideASubGroupNamesThatGroupAsItsParent
{
	[self.api startParameterSubGroup:@"Group" parameterID:kCreationTestGroup parameterFlags:0];
	[self.posted removeAllObjects];

	XCTAssertTrue([self addFloatParameter]);

	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_ParentId], @(kCreationTestGroup));
}

/*! @abstract A nested subgroup names its enclosing group as its parent and pushes onto the stack above it. */
- (void)testNestedSubGroupsNameTheirEnclosingGroup
{
	[self.api startParameterSubGroup:@"Outer" parameterID:kCreationTestGroup parameterFlags:0];
	[self.posted removeAllObjects];

	XCTAssertTrue([self.api startParameterSubGroup:@"Inner"
									   parameterID:kCreationTestInnerGroup
									parameterFlags:0]);

	XCTAssertEqualObjects(self.addedParameter[kFxParameterProperty_ParentId], @(kCreationTestGroup));
	XCTAssertEqualObjects(self.api.subGroupStack, (@[@(kFxParameterId_TopLevelGroup),
													 @(kCreationTestGroup),
													 @(kCreationTestInnerGroup)]));
}

/*! @abstract Ending a subgroup calls the host, pops the stack, and posts the end-group notification whose payload names the closed group and its parent. */
- (void)testEndParameterSubGroupPopsTheGroupAndPostsTheEndNotification
{
	[self.api startParameterSubGroup:@"Group" parameterID:kCreationTestGroup parameterFlags:0];
	[self.posted removeAllObjects];
	[self.hostAPI.calls removeAllObjects];

	XCTAssertTrue([self.api endParameterSubGroup]);

	XCTAssertEqualObjects(self.hostCall, @{@"method": @"endgroup"});
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterEndGroupName]);
	XCTAssertEqualObjects(self.api.subGroupStack, @[@(kFxParameterId_TopLevelGroup)]);

	NSDictionary *userInfo = [self notificationNamed:FxGripNotifyAPI_ParameterEndGroupName].userInfo;
	XCTAssertEqualObjects(userInfo[kFxParameterProperty_Id], @(kCreationTestGroup));
	NSDictionary *parameter = userInfo.fxParameter;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], @(FxParameterType_Group));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Id], @(kCreationTestGroup));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_ParentId],
						  @(kFxParameterId_TopLevelGroup),
						  @"the end payload names the group the closed group sat in");
}

/*! @abstract Ending a nested subgroup posts an end payload naming the inner group and its enclosing group, and pops back to the enclosing group. */
- (void)testEndingANestedSubGroupNamesTheEnclosingGroupAsTheParent
{
	[self.api startParameterSubGroup:@"Outer" parameterID:kCreationTestGroup parameterFlags:0];
	[self.api startParameterSubGroup:@"Inner" parameterID:kCreationTestInnerGroup parameterFlags:0];
	[self.posted removeAllObjects];

	XCTAssertTrue([self.api endParameterSubGroup]);

	NSDictionary *parameter = [self notificationNamed:FxGripNotifyAPI_ParameterEndGroupName].userInfo.fxParameter;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Id], @(kCreationTestInnerGroup));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_ParentId], @(kCreationTestGroup));
	XCTAssertEqualObjects(self.api.subGroupStack, (@[@(kFxParameterId_TopLevelGroup),
													 @(kCreationTestGroup)]));
}

/*! @abstract An end with no open group keeps the root sentinel as the stack floor and posts nothing. */
- (void)testAnEndWithNoOpenGroupReportsTheHostAnswerAndPostsNothing
{
	XCTAssertTrue([self.api endParameterSubGroup]);

	XCTAssertEqualObjects(self.api.subGroupStack, @[@(kFxParameterId_TopLevelGroup)],
						  @"the root sentinel is the stack floor");
	XCTAssertEqualObjects(self.posted, @[]);
}

/*! @abstract A subgroup opened after an unbalanced end still pushes and pops correctly and names the top-level group as its parent. */
- (void)testASubGroupStillOpensAndClosesAfterAnUnbalancedEnd
{
	[self.api endParameterSubGroup];
	[self.posted removeAllObjects];

	XCTAssertTrue([self.api startParameterSubGroup:@"Group"
									   parameterID:kCreationTestGroup
									parameterFlags:0]);
	XCTAssertTrue([self.api endParameterSubGroup]);

	XCTAssertEqualObjects(self.api.subGroupStack, @[@(kFxParameterId_TopLevelGroup)]);
	NSDictionary *parameter = [self notificationNamed:FxGripNotifyAPI_ParameterEndGroupName].userInfo.fxParameter;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Id], @(kCreationTestGroup));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_ParentId], @(kFxParameterId_TopLevelGroup));
}

/*! @abstract A group the host refuses is not pushed onto the stack and posts no start-group notification. */
- (void)testAGroupTheHostRefusesIsNotPushed
{
	self.hostAPI.succeeds = NO;

	XCTAssertFalse([self.api startParameterSubGroup:@"Group"
										parameterID:kCreationTestGroup
									 parameterFlags:0]);

	XCTAssertEqualObjects(self.api.subGroupStack, @[@(kFxParameterId_TopLevelGroup)]);
	XCTAssertNil([self notificationNamed:FxGripNotifyAPI_ParameterStartGroupName]);
}

/*! @abstract An end the host refuses leaves the open group on the stack and posts nothing. */
- (void)testAnEndTheHostRefusesLeavesTheStackAndPostsNothing
{
	[self.api startParameterSubGroup:@"Group" parameterID:kCreationTestGroup parameterFlags:0];
	[self.posted removeAllObjects];
	self.hostAPI.succeeds = NO;

	XCTAssertFalse([self.api endParameterSubGroup]);

	XCTAssertEqualObjects(self.api.subGroupStack, (@[@(kFxParameterId_TopLevelGroup),
													 @(kCreationTestGroup)]));
	XCTAssertEqualObjects(self.posted, @[]);
}

/*! @abstract A group aborted by an observer error is not pushed onto the stack and reaches no host call. */
- (void)testAGroupAbortedByAnObserverErrorIsNotPushedAndReachesNoHost
{
	[self observeName:FxGripNotifyAPI_ParameterAddPreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError =
			[NSError errorWithDomain:@"FxGripCreationTest" code:1 userInfo:nil];
	}];

	XCTAssertFalse([self.api startParameterSubGroup:@"Group"
										parameterID:kCreationTestGroup
									 parameterFlags:0]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertEqualObjects(self.api.subGroupStack, @[@(kFxParameterId_TopLevelGroup)]);
}

@end
