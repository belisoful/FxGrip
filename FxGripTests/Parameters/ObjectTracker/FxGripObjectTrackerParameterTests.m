/*!
	@file       FxGripObjectTrackerParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerParameterTests
	@abstract   Tests the FxGripObjectTrackerParameter type, creation, and default parse.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the type identity, the custom value classes, the hidden custom-UI parameter it creates holding tracker data, the configuration it parses from its declared default, and the host-refusal result.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameterFlags.h>
#import "FxGripParameterClassTestSupport.h"

typedef NS_ENUM(NSInteger, FxGripObjectTrackerShape) {
	FxGripObjectTrackerShapeRectangle		= 0,
	FxGripObjectTrackerShapeQuadrilateral	= 1,
};

@interface FxGripObjectTrackerData : NSObject
@property (copy, nonatomic) NSString *label;
@property (nonatomic) NSInteger shape;
@property (nonatomic) NSInteger behavior;
@property (nonatomic) NSInteger resolution;
@property (nonatomic) NSInteger smoothing;
@property (nonatomic) BOOL includeLeadingFilters;
@property (nonatomic) BOOL enabled;
@property (nonatomic) CGRect initialBox;
@end

@interface FxGripObjectTrackerParameter : NSObject
+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (nullable NSSet<Class> *)customValueClasses;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id)effect;
@end


static const FxParameterId kTrackerTestParameter = 41;

@interface FxGripObjectTrackerParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripObjectTrackerParameterTests

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

- (Class)trackerClass
{
	return NSClassFromString(@"FxGripObjectTrackerParameter");
}

- (BOOL)addWithDefault:(nullable NSDictionary *)declared
{
	NSDictionary *extra = declared ? @{kFxParameterProperty_Default: declared} : nil;
	NSDictionary *config = FxGripParamClassTestConfig(kTrackerTestParameter,
													  kFxParameterType_ObjectTracker, @"Tracker", extra);
	return [[self trackerClass] addParameter:config toEffect:(id)self.effect];
}

/*! @abstract The parameter reports the object-tracker FxPlug type and the matching type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual([[self trackerClass] parameterType], FxParameterType_ObjectTracker);
	XCTAssertEqualObjects([[self trackerClass] parameterTypeString], kFxParameterType_ObjectTracker);
}

/*! @abstract The custom value classes cover the tracker data and its sample class. */
- (void)testCustomValueClassesCoverTheStoredGraph
{
	NSSet<Class> *classes = [[self trackerClass] customValueClasses];
	XCTAssertTrue([classes containsObject:NSClassFromString(@"FxGripObjectTrackerData")]);
	XCTAssertTrue([classes containsObject:NSClassFromString(@"FxGripObjectTrackerSample")]);
}

/*! @abstract Creation registers a custom-UI parameter whose default value is an enabled tracker data object. */
- (void)testAddCreatesACustomUIParameterHoldingTrackerData
{
	XCTAssertTrue([self addWithDefault:nil]);
	NSDictionary *call = self.effect.creationCall;
	XCTAssertEqualObjects(call[@"method"], @"custom");
	XCTAssertEqualObjects(call[@"id"], @(kTrackerTestParameter));

	FxParameterFlags flags = [call[@"flags"] unsignedLongLongValue];
	XCTAssertTrue((flags & kFxParameterFlag_CUSTOM_UI) != 0, @"the options view is a custom UI");

	id value = call[@"default"];
	XCTAssertTrue([value isKindOfClass:NSClassFromString(@"FxGripObjectTrackerData")]);
	XCTAssertTrue([(FxGripObjectTrackerData *)value enabled], @"default tracker is enabled");
}

/*! @abstract A declared configuration is parsed into the default tracker data's shape, smoothing, enabled flag, label, and initial box. */
- (void)testDeclaredConfigurationIsParsedIntoTheDefault
{
	BOOL ok = [self addWithDefault:@{
		@"shape": @(FxGripObjectTrackerShapeQuadrilateral),
		@"smoothing": @4,
		@"enabled": @NO,
		@"label": @"Ball",
		@"initialBox": @[@0.1, @0.2, @0.3, @0.25],
	}];
	XCTAssertTrue(ok);

	FxGripObjectTrackerData *value = self.effect.creationCall[@"default"];
	XCTAssertEqual(value.shape, FxGripObjectTrackerShapeQuadrilateral);
	XCTAssertEqual(value.smoothing, 4);
	XCTAssertFalse(value.enabled);
	XCTAssertEqualObjects(value.label, @"Ball");
	XCTAssertTrue(CGRectEqualToRect(value.initialBox, CGRectMake(0.1, 0.2, 0.3, 0.25)));
}

/*! @abstract A host that refuses creation makes the add call return false. */
- (void)testHostRefusalIsReported
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;
	XCTAssertFalse([self addWithDefault:nil]);
}

@end
