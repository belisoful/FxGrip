/*!
	@file       FxGripPresetTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPresetTests
	@abstract   Tests the typed preset value primitives that write and read FxParameter values through the FxGrip setting APIs.
	@discussion Introduced in FxGrip 0.1.0. The tests exercise type-directed dispatch in +setParameterValue:toParameter:atTime:withAPI:. They cover the shape-based fallback used when no dynamic API is reachable. They cover the recursive merge of custom dictionary values. They cover the inverse encoding produced by +getParameterValue:toParameter:atTime:withAPI:.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxPlug/FxTypes.h>
#import "FxGrip/FxGripTypes.h"

// FxGripPreset.h is not a public framework header, so the two class methods under test
// are declared here; the implementation comes from the linked framework.
@interface FxGripPreset : NSObject
+ (BOOL)setParameterValue:(id)value toParameter:(FxParameterId)parameterID atTime:(CMTime)time withAPI:(id<FxParameterSettingAPI_v5>)setterAPI;
+ (BOOL)getParameterValue:(id*)value toParameter:(FxParameterId)parameterID atTime:(CMTime)time withAPI:(id<FxParameterSettingAPI_v5>)setterAPI;
@end

static const FxParameterId kPresetTestParamID = 42;

// The test bundle links only FxGrip and XCTest, so CMTime values are built and compared
// without the CoreMedia symbols.
static CMTime FxGripPresetTestTime(void)
{
	return (CMTime){.value = 3, .timescale = 30, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static CMTime FxGripPresetTestUnsetTime(void)
{
	return (CMTime){.value = 0, .timescale = 0, .flags = 0, .epoch = 0};
}

static BOOL FxGripPresetTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

#pragma mark - Test doubles

// Stands in for the dynamic API the FxGrip setting wrapper exposes; supplies the
// parameter type the primitives dispatch on.
@interface FxGripPresetTestDynamicAPI : NSObject
@property (nonatomic, assign) FxParameterType typeToReturn;
@property (nonatomic, assign) FxParameterId lastParameterID;
@end

@implementation FxGripPresetTestDynamicAPI
- (FxParameterType)parameterType:(FxParameterId)parameterID
{
	self.lastParameterID = parameterID;
	return self.typeToReturn;
}
@end

// Serves the get path and the custom-merge read-back.
@interface FxGripPresetTestRetrievalAPI : NSObject
@property (nonatomic, assign) BOOL succeeds;
@property (nonatomic, assign) double red;
@property (nonatomic, assign) double green;
@property (nonatomic, assign) double blue;
@property (nonatomic, assign) double alpha;
@property (nonatomic, assign) double x;
@property (nonatomic, assign) double y;
@property (nonatomic, assign) double floatToReturn;
@property (nonatomic, assign) int intToReturn;
@property (nonatomic, assign) BOOL boolToReturn;
@property (nonatomic, strong) NSString *stringToReturn;
@property (nonatomic, strong) NSObject<NSSecureCoding, NSCopying> *customToReturn;
@property (nonatomic, assign) NSUInteger customReadCount;
@end

@implementation FxGripPresetTestRetrievalAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_succeeds = YES;
	}
	return self;
}

- (BOOL)getFloatValue:(double *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (!self.succeeds) {
		return NO;
	}
	*value = self.floatToReturn;
	return YES;
}

- (BOOL)getIntValue:(int *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (!self.succeeds) {
		return NO;
	}
	*value = self.intToReturn;
	return YES;
}

- (BOOL)getBoolValue:(BOOL *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (!self.succeeds) {
		return NO;
	}
	*value = self.boolToReturn;
	return YES;
}

- (BOOL)getRedValue:(double *)red greenValue:(double *)green blueValue:(double *)blue
	  fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (!self.succeeds) {
		return NO;
	}
	*red = self.red;
	*green = self.green;
	*blue = self.blue;
	return YES;
}

- (BOOL)getRedValue:(double *)red greenValue:(double *)green blueValue:(double *)blue alphaValue:(double *)alpha
	  fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (!self.succeeds) {
		return NO;
	}
	*red = self.red;
	*green = self.green;
	*blue = self.blue;
	*alpha = self.alpha;
	return YES;
}

- (BOOL)getXValue:(double *)x YValue:(double *)y fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (!self.succeeds) {
		return NO;
	}
	*x = self.x;
	*y = self.y;
	return YES;
}

- (BOOL)getStringParameterValue:(NSString * _Nonnull * _Nullable)string fromParameter:(UInt32)parameterID
{
	if (!self.succeeds) {
		return NO;
	}
	*string = self.stringToReturn;
	return YES;
}

- (BOOL)getCustomParameterValue:(NSObject<NSSecureCoding, NSCopying>* _Nullable * _Nonnull)value
				  fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.customReadCount += 1;
	if (!self.succeeds) {
		return NO;
	}
	*value = self.customToReturn;
	return YES;
}

@end

/*!
	Records which setter the primitive chose and the arguments it passed. This root class
	deliberately implements neither -paramGetAPIv6 nor -parameterInfoAPIv1, so it also stands
	for a raw host API that carries no type source.
*/
@interface FxGripPresetTestSetter : NSObject
@property (nonatomic, copy) NSString *recordedSelector;
@property (nonatomic, assign) NSUInteger callCount;
@property (nonatomic, assign) FxParameterId recordedParameterID;
@property (nonatomic, assign) CMTime recordedTime;
@property (nonatomic, assign) double recordedRed;
@property (nonatomic, assign) double recordedGreen;
@property (nonatomic, assign) double recordedBlue;
@property (nonatomic, assign) double recordedAlpha;
@property (nonatomic, assign) double recordedX;
@property (nonatomic, assign) double recordedY;
@property (nonatomic, assign) double recordedFloat;
@property (nonatomic, assign) int recordedInt;
@property (nonatomic, assign) BOOL recordedBool;
@property (nonatomic, copy) NSString *recordedString;
@property (nonatomic, strong) id recordedCustom;
@property (nonatomic, assign) BOOL setterResult;
@end

@implementation FxGripPresetTestSetter

- (instancetype)init
{
	self = [super init];
	if (self) {
		_setterResult = YES;
		_recordedTime = FxGripPresetTestUnsetTime();
	}
	return self;
}

- (void)recordSelector:(SEL)selector parameter:(UInt32)parameterID time:(CMTime)time
{
	self.recordedSelector = NSStringFromSelector(selector);
	self.recordedParameterID = parameterID;
	self.recordedTime = time;
	self.callCount += 1;
}

- (BOOL)setFloatValue:(double)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self recordSelector:_cmd parameter:parameterID time:time];
	self.recordedFloat = value;
	return self.setterResult;
}

- (BOOL)setIntValue:(int)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self recordSelector:_cmd parameter:parameterID time:time];
	self.recordedInt = value;
	return self.setterResult;
}

- (BOOL)setBoolValue:(BOOL)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self recordSelector:_cmd parameter:parameterID time:time];
	self.recordedBool = value;
	return self.setterResult;
}

- (BOOL)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue
		toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self recordSelector:_cmd parameter:parameterID time:time];
	self.recordedRed = red;
	self.recordedGreen = green;
	self.recordedBlue = blue;
	return self.setterResult;
}

- (BOOL)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha
		toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self recordSelector:_cmd parameter:parameterID time:time];
	self.recordedRed = red;
	self.recordedGreen = green;
	self.recordedBlue = blue;
	self.recordedAlpha = alpha;
	return self.setterResult;
}

- (BOOL)setXValue:(double)x YValue:(double)y toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self recordSelector:_cmd parameter:parameterID time:time];
	self.recordedX = x;
	self.recordedY = y;
	return self.setterResult;
}

- (BOOL)setStringParameterValue:(NSString *)string toParameter:(UInt32)parameterID
{
	[self recordSelector:_cmd parameter:parameterID time:FxGripPresetTestUnsetTime()];
	self.recordedString = string;
	return self.setterResult;
}

- (BOOL)setCustomParameterValue:(NSObject<NSSecureCoding, NSCopying>*)value
					toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self recordSelector:_cmd parameter:parameterID time:time];
	self.recordedCustom = value;
	return self.setterResult;
}

@end

// Adds the retrieval API the custom merge and the get path read through.
@interface FxGripPresetTestSetterWithGetter : FxGripPresetTestSetter
@property (nonatomic, strong) FxGripPresetTestRetrievalAPI *retrievalAPI;
@end

@implementation FxGripPresetTestSetterWithGetter
- (id)paramGetAPIv6
{
	return self.retrievalAPI;
}
@end

// Adds the dynamic API, matching the FxGrip setting wrapper that supplies the type.
@interface FxGripPresetTestFullSetter : FxGripPresetTestSetterWithGetter
@property (nonatomic, strong) FxGripPresetTestDynamicAPI *dynamicAPI;
@end

@implementation FxGripPresetTestFullSetter
- (id)parameterInfoAPIv1
{
	return self.dynamicAPI;
}
@end

#pragma mark - Tests

@interface FxGripPresetTests : XCTestCase
@end

@implementation FxGripPresetTests
{
	FxGripPresetTestFullSetter *_setter;
}

- (void)setUp
{
	[super setUp];
	_setter = [[FxGripPresetTestFullSetter alloc] init];
	_setter.dynamicAPI = [[FxGripPresetTestDynamicAPI alloc] init];
	_setter.retrievalAPI = [[FxGripPresetTestRetrievalAPI alloc] init];
}

- (void)tearDown
{
	_setter = nil;
	[super tearDown];
}

- (BOOL)setValue:(id)value withType:(FxParameterType)type
{
	_setter.dynamicAPI.typeToReturn = type;
	return [FxGripPreset setParameterValue:value toParameter:kPresetTestParamID
									atTime:FxGripPresetTestTime() withAPI:(id)_setter];
}

- (id)getValueWithType:(FxParameterType)type success:(BOOL*)success
{
	_setter.dynamicAPI.typeToReturn = type;
	id value = nil;
	BOOL result = [FxGripPreset getParameterValue:&value toParameter:kPresetTestParamID
										   atTime:FxGripPresetTestTime() withAPI:(id)_setter];
	if (success) {
		*success = result;
	}
	return value;
}

#pragma mark Set path — numeric types

/*! @abstract An Int type routes the value to setIntValue:toParameter:atTime: with the parameter ID and time preserved. */
- (void)testSetIntTypeCallsIntSetterWithParameterAndTime
{
	XCTAssertTrue([self setValue:@7 withType:FxParameterType_Int]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setIntValue:toParameter:atTime:");
	XCTAssertEqual(_setter.recordedInt, 7);
	XCTAssertEqual(_setter.recordedParameterID, kPresetTestParamID);
	XCTAssertTrue(FxGripPresetTestTimesEqual(_setter.recordedTime, FxGripPresetTestTime()));
	XCTAssertEqual(_setter.callCount, 1u);
	XCTAssertEqual(_setter.dynamicAPI.lastParameterID, kPresetTestParamID);
}

/*! @abstract A Menu type routes the value to the integer setter. */
- (void)testSetMenuTypeCallsIntSetter
{
	XCTAssertTrue([self setValue:@3 withType:FxParameterType_Menu]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setIntValue:toParameter:atTime:");
	XCTAssertEqual(_setter.recordedInt, 3);
}

/*! @abstract A Toggle type routes the value to the boolean setter. */
- (void)testSetToggleTypeCallsBoolSetter
{
	XCTAssertTrue([self setValue:@YES withType:FxParameterType_Toggle]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setBoolValue:toParameter:atTime:");
	XCTAssertTrue(_setter.recordedBool);
}

/*! @abstract A Float type routes the value to setFloatValue:toParameter:atTime: as a double at the supplied time. */
- (void)testSetFloatTypeCallsFloatSetterWithDoubleValue
{
	XCTAssertTrue([self setValue:@0.25 withType:FxParameterType_Float]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setFloatValue:toParameter:atTime:");
	XCTAssertEqual(_setter.recordedFloat, 0.25);
	XCTAssertTrue(FxGripPresetTestTimesEqual(_setter.recordedTime, FxGripPresetTestTime()));
}

/*! @abstract A Percent type falls to the default float branch and calls the float setter. */
- (void)testSetPercentTypeTakesTheDefaultFloatBranch
{
	XCTAssertTrue([self setValue:@1.5 withType:FxParameterType_Percent]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setFloatValue:toParameter:atTime:");
	XCTAssertEqual(_setter.recordedFloat, 1.5);
}

/*! @abstract An Angle type falls to the default float branch and calls the float setter. */
- (void)testSetAngleTypeTakesTheDefaultFloatBranch
{
	XCTAssertTrue([self setValue:@(-45.0) withType:FxParameterType_Angle]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setFloatValue:toParameter:atTime:");
	XCTAssertEqual(_setter.recordedFloat, -45.0);
}

#pragma mark Set path — string types

/*! @abstract A String type routes the value to the untimed setStringParameterValue:toParameter: setter. */
- (void)testSetStringTypeCallsUntimedStringSetter
{
	XCTAssertTrue([self setValue:@"headline" withType:FxParameterType_String]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setStringParameterValue:toParameter:");
	XCTAssertEqualObjects(_setter.recordedString, @"headline");
	XCTAssertEqual(_setter.recordedParameterID, kPresetTestParamID);
}

/*! @abstract A FontMenu type routes the value to the string setter. */
- (void)testSetFontMenuTypeCallsStringSetter
{
	XCTAssertTrue([self setValue:@"Helvetica" withType:FxParameterType_FontMenu]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setStringParameterValue:toParameter:");
	XCTAssertEqualObjects(_setter.recordedString, @"Helvetica");
}

#pragma mark Set path — color and point

/*! @abstract An RGB type reads the red, green, and blue keys and calls the three-component color setter. */
- (void)testSetRGBTypeCallsThreeComponentColorSetter
{
	NSDictionary *color = @{kFxParameterProperty_Red: @0.1,
							kFxParameterProperty_Green: @0.2,
							kFxParameterProperty_Blue: @0.3};
	XCTAssertTrue([self setValue:color withType:FxParameterType_RGB]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setRedValue:greenValue:blueValue:toParameter:atTime:");
	XCTAssertEqual(_setter.recordedRed, 0.1);
	XCTAssertEqual(_setter.recordedGreen, 0.2);
	XCTAssertEqual(_setter.recordedBlue, 0.3);
	XCTAssertTrue(FxGripPresetTestTimesEqual(_setter.recordedTime, FxGripPresetTestTime()));
}

/*! @abstract An RGBA type carrying an alpha key calls the four-component color setter with all four components. */
- (void)testSetRGBATypeWithAlphaCallsFourComponentColorSetter
{
	NSDictionary *color = @{kFxParameterProperty_Red: @0.4,
							kFxParameterProperty_Green: @0.5,
							kFxParameterProperty_Blue: @0.6,
							kFxParameterProperty_Alpha: @0.7};
	XCTAssertTrue([self setValue:color withType:FxParameterType_RGBA]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setRedValue:greenValue:blueValue:alphaValue:toParameter:atTime:");
	XCTAssertEqual(_setter.recordedRed, 0.4);
	XCTAssertEqual(_setter.recordedGreen, 0.5);
	XCTAssertEqual(_setter.recordedBlue, 0.6);
	XCTAssertEqual(_setter.recordedAlpha, 0.7);
}

/*! @abstract An RGBA type carrying no alpha key falls through to the three-component color setter. */
- (void)testSetRGBATypeWithoutAlphaFallsThroughToThreeComponentColorSetter
{
	NSDictionary *color = @{kFxParameterProperty_Red: @0.4,
							kFxParameterProperty_Green: @0.5,
							kFxParameterProperty_Blue: @0.6};
	XCTAssertTrue([self setValue:color withType:FxParameterType_RGBA]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setRedValue:greenValue:blueValue:toParameter:atTime:");
	XCTAssertEqual(_setter.recordedRed, 0.4);
	XCTAssertEqual(_setter.recordedGreen, 0.5);
	XCTAssertEqual(_setter.recordedBlue, 0.6);
}

/*! @abstract A Point type reads the x and y keys and calls the point setter. */
- (void)testSetPointTypeCallsPointSetter
{
	NSDictionary *point = @{kFxParameterProperty_X: @0.75, kFxParameterProperty_Y: @0.25};
	XCTAssertTrue([self setValue:point withType:FxParameterType_Point]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setXValue:YValue:toParameter:atTime:");
	XCTAssertEqual(_setter.recordedX, 0.75);
	XCTAssertEqual(_setter.recordedY, 0.25);
}

#pragma mark Set path — custom

/*! @abstract A Custom dictionary value merges recursively into the parameter's current dictionary before the custom setter is called. */
- (void)testSetCustomTypeMergesRecursivelyIntoTheCurrentDictionary
{
	_setter.retrievalAPI.customToReturn = (NSDictionary*)@{@"keptTop": @1,
														   @"shared": @"current",
														   @"nested": @{@"keptNested": @10, @"nestedShared": @20}};
	NSDictionary *preset = @{@"newTop": @2,
							 @"shared": @"preset",
							 @"nested": @{@"newNested": @30, @"nestedShared": @99}};

	XCTAssertTrue([self setValue:preset withType:FxParameterType_Custom]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setCustomParameterValue:toParameter:atTime:");
	XCTAssertEqual(_setter.retrievalAPI.customReadCount, 1u);

	NSDictionary *merged = _setter.recordedCustom;
	XCTAssertTrue([merged isKindOfClass:NSDictionary.class]);
	XCTAssertEqualObjects(merged[@"keptTop"], @1);
	XCTAssertEqualObjects(merged[@"newTop"], @2);
	// A preset value must win over the parameter's current value on a key conflict.
	// -mergeEntriesFromDictionaryRecursive: preserves existing entries instead, so the
	// current value survives and the preset is discarded at both levels.
	XCTAssertEqualObjects(merged[@"shared"], @"preset");

	NSDictionary *nested = merged[@"nested"];
	XCTAssertTrue([nested isKindOfClass:NSDictionary.class]);
	XCTAssertEqualObjects(nested[@"keptNested"], @10);
	XCTAssertEqualObjects(nested[@"newNested"], @30);
	XCTAssertEqualObjects(nested[@"nestedShared"], @99);
}

/*! @abstract A Custom value with no current dictionary is set directly without merging. */
- (void)testSetCustomTypeWithNoCurrentDictionarySetsTheSuppliedValueDirectly
{
	_setter.retrievalAPI.customToReturn = nil;
	NSDictionary *preset = @{@"only": @"value"};

	XCTAssertTrue([self setValue:preset withType:FxParameterType_Custom]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setCustomParameterValue:toParameter:atTime:");
	XCTAssertEqualObjects(_setter.recordedCustom, preset);
}

#pragma mark Set path — shape inference

/*! @abstract Without a dynamic API the setter infers RGBA from the color component keys. */
- (void)testSetInfersRGBAFromComponentKeysWhenNoDynamicAPI
{
	FxGripPresetTestSetterWithGetter *bare = [[FxGripPresetTestSetterWithGetter alloc] init];
	NSDictionary *color = @{kFxParameterProperty_Red: @0.1,
							kFxParameterProperty_Green: @0.2,
							kFxParameterProperty_Blue: @0.3,
							kFxParameterProperty_Alpha: @0.4};

	XCTAssertTrue([FxGripPreset setParameterValue:color toParameter:kPresetTestParamID
										   atTime:FxGripPresetTestTime() withAPI:(id)bare]);
	XCTAssertEqualObjects(bare.recordedSelector, @"setRedValue:greenValue:blueValue:alphaValue:toParameter:atTime:");
	XCTAssertEqual(bare.recordedAlpha, 0.4);
}

/*! @abstract Without a dynamic API the setter infers a point from the x and y keys. */
- (void)testSetInfersPointFromXYKeysWhenNoDynamicAPI
{
	FxGripPresetTestSetterWithGetter *bare = [[FxGripPresetTestSetterWithGetter alloc] init];
	NSDictionary *point = @{kFxParameterProperty_X: @0.6, kFxParameterProperty_Y: @0.9};

	XCTAssertTrue([FxGripPreset setParameterValue:point toParameter:kPresetTestParamID
										   atTime:FxGripPresetTestTime() withAPI:(id)bare]);
	XCTAssertEqualObjects(bare.recordedSelector, @"setXValue:YValue:toParameter:atTime:");
	XCTAssertEqual(bare.recordedX, 0.6);
	XCTAssertEqual(bare.recordedY, 0.9);
}

/*! @abstract Without a dynamic API the setter infers a string from an NSString value. */
- (void)testSetInfersStringFromNSStringWhenNoDynamicAPI
{
	FxGripPresetTestSetterWithGetter *bare = [[FxGripPresetTestSetterWithGetter alloc] init];

	XCTAssertTrue([FxGripPreset setParameterValue:@"inferred" toParameter:kPresetTestParamID
										   atTime:FxGripPresetTestTime() withAPI:(id)bare]);
	XCTAssertEqualObjects(bare.recordedSelector, @"setStringParameterValue:toParameter:");
	XCTAssertEqualObjects(bare.recordedString, @"inferred");
}

/*! @abstract Without a dynamic API the setter infers a float from an NSNumber value. */
- (void)testSetInfersFloatFromNSNumberWhenNoDynamicAPI
{
	FxGripPresetTestSetterWithGetter *bare = [[FxGripPresetTestSetterWithGetter alloc] init];

	XCTAssertTrue([FxGripPreset setParameterValue:@2.5 toParameter:kPresetTestParamID
										   atTime:FxGripPresetTestTime() withAPI:(id)bare]);
	XCTAssertEqualObjects(bare.recordedSelector, @"setFloatValue:toParameter:atTime:");
	XCTAssertEqual(bare.recordedFloat, 2.5);
}

/*! @abstract The setter infers the value shape when the dynamic API is nil. */
- (void)testSetInfersShapeWhenTheDynamicAPIIsNil
{
	_setter.dynamicAPI = nil;

	XCTAssertTrue([FxGripPreset setParameterValue:@"inferred" toParameter:kPresetTestParamID
										   atTime:FxGripPresetTestTime() withAPI:(id)_setter]);
	XCTAssertEqualObjects(_setter.recordedSelector, @"setStringParameterValue:toParameter:");
}

#pragma mark Set path — rejections

/*! @abstract The set path rejects a nil value without calling a setter. */
- (void)testSetRejectsNilValueWithoutCallingASetter
{
	XCTAssertFalse([self setValue:nil withType:FxParameterType_Float]);
	XCTAssertEqual(_setter.callCount, 0u);
}

/*! @abstract The set path rejects NSNull without calling a setter. */
- (void)testSetRejectsNSNullWithoutCallingASetter
{
	XCTAssertFalse([self setValue:NSNull.null withType:FxParameterType_Float]);
	XCTAssertEqual(_setter.callCount, 0u);
}

/*! @abstract The set path rejects a nil setter API. */
- (void)testSetRejectsNilSetterAPI
{
	XCTAssertFalse([FxGripPreset setParameterValue:@1 toParameter:kPresetTestParamID
											atTime:FxGripPresetTestTime() withAPI:nil]);
}

/*! @abstract The set path rejects a non-number value for an Int type without calling a setter. */
- (void)testSetRejectsNonNumberForIntType
{
	XCTAssertFalse([self setValue:@"twelve" withType:FxParameterType_Int]);
	XCTAssertEqual(_setter.callCount, 0u);
}

/*! @abstract The set path rejects a non-dictionary value for a Point type without calling a setter. */
- (void)testSetRejectsNonDictionaryForPointType
{
	XCTAssertFalse([self setValue:@5 withType:FxParameterType_Point]);
	XCTAssertEqual(_setter.callCount, 0u);
}

/*! @abstract The set path rejects a non-string value for a String type without calling a setter. */
- (void)testSetRejectsNonStringForStringType
{
	XCTAssertFalse([self setValue:@5 withType:FxParameterType_String]);
	XCTAssertEqual(_setter.callCount, 0u);
}

#pragma mark Get path

/*! @abstract The get path for an RGBA type produces all four color component keys. */
- (void)testGetRGBAProducesAllFourComponentKeys
{
	_setter.retrievalAPI.red = 0.1;
	_setter.retrievalAPI.green = 0.2;
	_setter.retrievalAPI.blue = 0.3;
	_setter.retrievalAPI.alpha = 0.4;

	BOOL success = NO;
	NSDictionary *value = [self getValueWithType:FxParameterType_RGBA success:&success];
	XCTAssertTrue(success);
	XCTAssertEqual(value.count, 4u);
	XCTAssertEqualObjects(value[kFxParameterProperty_Red], @0.1);
	XCTAssertEqualObjects(value[kFxParameterProperty_Green], @0.2);
	XCTAssertEqualObjects(value[kFxParameterProperty_Blue], @0.3);
	XCTAssertEqualObjects(value[kFxParameterProperty_Alpha], @0.4);
}

/*! @abstract The get path for an RGB type produces three color component keys and no alpha. */
- (void)testGetRGBProducesThreeComponentKeysWithoutAlpha
{
	_setter.retrievalAPI.red = 0.5;
	_setter.retrievalAPI.green = 0.6;
	_setter.retrievalAPI.blue = 0.7;

	BOOL success = NO;
	NSDictionary *value = [self getValueWithType:FxParameterType_RGB success:&success];
	XCTAssertTrue(success);
	XCTAssertEqual(value.count, 3u);
	XCTAssertEqualObjects(value[kFxParameterProperty_Red], @0.5);
	XCTAssertEqualObjects(value[kFxParameterProperty_Green], @0.6);
	XCTAssertEqualObjects(value[kFxParameterProperty_Blue], @0.7);
	XCTAssertNil(value[kFxParameterProperty_Alpha]);
}

/*! @abstract The get path for a Point type produces the x and y keys. */
- (void)testGetPointProducesXAndYKeys
{
	_setter.retrievalAPI.x = 0.125;
	_setter.retrievalAPI.y = 0.875;

	BOOL success = NO;
	NSDictionary *value = [self getValueWithType:FxParameterType_Point success:&success];
	XCTAssertTrue(success);
	XCTAssertEqual(value.count, 2u);
	XCTAssertEqualObjects(value[kFxParameterProperty_X], @0.125);
	XCTAssertEqualObjects(value[kFxParameterProperty_Y], @0.875);
}

/*! @abstract The get path for a String type produces the string. */
- (void)testGetStringProducesTheString
{
	_setter.retrievalAPI.stringToReturn = @"caption";

	BOOL success = NO;
	id value = [self getValueWithType:FxParameterType_String success:&success];
	XCTAssertTrue(success);
	XCTAssertEqualObjects(value, @"caption");
}

/*! @abstract The get path for a FontMenu type produces the string. */
- (void)testGetFontMenuProducesTheString
{
	_setter.retrievalAPI.stringToReturn = @"Futura";

	BOOL success = NO;
	id value = [self getValueWithType:FxParameterType_FontMenu success:&success];
	XCTAssertTrue(success);
	XCTAssertEqualObjects(value, @"Futura");
}

/*! @abstract The get path for a Toggle type produces a boolean number. */
- (void)testGetToggleProducesABooleanNumber
{
	_setter.retrievalAPI.boolToReturn = YES;

	BOOL success = NO;
	NSNumber *value = [self getValueWithType:FxParameterType_Toggle success:&success];
	XCTAssertTrue(success);
	XCTAssertEqualObjects(value, @YES);
}

/*! @abstract The get path for an Int type produces an integer number. */
- (void)testGetIntProducesAnIntegerNumber
{
	_setter.retrievalAPI.intToReturn = 12;

	BOOL success = NO;
	NSNumber *value = [self getValueWithType:FxParameterType_Int success:&success];
	XCTAssertTrue(success);
	XCTAssertEqualObjects(value, @12);
}

/*! @abstract The get path for a Menu type produces an integer number. */
- (void)testGetMenuProducesAnIntegerNumber
{
	_setter.retrievalAPI.intToReturn = 4;

	BOOL success = NO;
	NSNumber *value = [self getValueWithType:FxParameterType_Menu success:&success];
	XCTAssertTrue(success);
	XCTAssertEqualObjects(value, @4);
}

/*! @abstract The get path for a default type produces a double number. */
- (void)testGetDefaultTypeProducesADoubleNumber
{
	_setter.retrievalAPI.floatToReturn = 3.75;

	BOOL success = NO;
	NSNumber *value = [self getValueWithType:FxParameterType_Percent success:&success];
	XCTAssertTrue(success);
	XCTAssertEqualObjects(value, @3.75);
}

/*! @abstract The get path for a Custom type produces the custom object. */
- (void)testGetCustomProducesTheCustomObject
{
	NSDictionary *custom = @{@"payload": @[@1, @2]};
	_setter.retrievalAPI.customToReturn = (NSDictionary*)custom;

	BOOL success = NO;
	id value = [self getValueWithType:FxParameterType_Custom success:&success];
	XCTAssertTrue(success);
	XCTAssertEqualObjects(value, custom);
}

#pragma mark Get path — rejections

/*! @abstract The get path rejects a NULL out-pointer. */
- (void)testGetRejectsNullOutPointer
{
	_setter.dynamicAPI.typeToReturn = FxParameterType_Float;
	XCTAssertFalse([FxGripPreset getParameterValue:NULL toParameter:kPresetTestParamID
											atTime:FxGripPresetTestTime() withAPI:(id)_setter]);
}

/*! @abstract The get path rejects a nil setter API and leaves the out-value nil. */
- (void)testGetRejectsNilSetterAPI
{
	id value = nil;
	XCTAssertFalse([FxGripPreset getParameterValue:&value toParameter:kPresetTestParamID
											atTime:FxGripPresetTestTime() withAPI:nil]);
	XCTAssertNil(value);
}

/*! @abstract The get path rejects a setter that exposes no retrieval API. */
- (void)testGetRejectsASetterWithoutARetrievalAPI
{
	FxGripPresetTestSetter *bare = [[FxGripPresetTestSetter alloc] init];
	id value = nil;
	XCTAssertFalse([FxGripPreset getParameterValue:&value toParameter:kPresetTestParamID
											atTime:FxGripPresetTestTime() withAPI:(id)bare]);
	XCTAssertNil(value);
}

/*! @abstract The get path rejects a nil retrieval API and leaves the out-value nil. */
- (void)testGetRejectsANilRetrievalAPI
{
	_setter.retrievalAPI = nil;
	id value = nil;
	XCTAssertFalse([FxGripPreset getParameterValue:&value toParameter:kPresetTestParamID
											atTime:FxGripPresetTestTime() withAPI:(id)_setter]);
	XCTAssertNil(value);
}

/*! @abstract The get path returns NO and no value when the underlying getter fails. */
- (void)testGetReturnsNoWhenTheUnderlyingGetterFails
{
	_setter.retrievalAPI.succeeds = NO;

	BOOL success = YES;
	id value = [self getValueWithType:FxParameterType_Float success:&success];
	XCTAssertFalse(success);
	XCTAssertNil(value);
}

/*! @abstract The get path returns NO and no value for the None type. */
- (void)testGetReturnsNoForTheNoneType
{
	BOOL success = YES;
	id value = [self getValueWithType:FxParameterType_None success:&success];
	XCTAssertFalse(success);
	XCTAssertNil(value);
}

@end
