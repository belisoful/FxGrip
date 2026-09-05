//
//  FxGripDividerDataTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxPlug/FxTypes.h>

// FxGripDividerData.h is not a public framework header, so the surface under test is
// re-declared locally. The constants mirror FxGripDividerParameter.h and FxGripTypes.h. AppKit is not
// linked into the test bundle, so parameterView is typed id and stands in for the NSView.
typedef double FxGripDividerSize;
static const uint16_t kDividerHeight = 1;
static const double kGoldenRatio = 1.618033988749895;

@protocol FxGripCustomViewDataDelegate
- (void)updateFromCustomData:(NSObject<NSSecureCoding, NSCopying> *)value;
@end

@interface FxGripDividerData : NSObject <NSSecureCoding, NSCopying>
@property (nonatomic, assign) FxGripDividerSize percentWidth;
@property (nonatomic, assign) uint16_t marginTop;
@property (nonatomic, assign) uint16_t marginBottom;
@property (nonatomic, assign) uint16_t parameterHeight;
@property (assign) id parameterView;
@property (assign) id parameterEffect;
+ (instancetype)dataWithDictionary:(NSDictionary *)values;
- (instancetype)initWithDictionary:(NSDictionary *)values;
- (BOOL)getFloatValue:(double *)floatValue;
- (BOOL)setFloatValue:(double)floatValue;
- (BOOL)getIntValue:(int *)intValue;
- (BOOL)setIntValue:(int)intValue;
@end


/*! Stands in for the custom parameter's NSView so the data-changed callbacks are observable. */
@interface FxGripDividerTestView : NSObject <FxGripCustomViewDataDelegate>
@property (nonatomic, assign) NSUInteger updateCount;
@property (nonatomic, weak) id lastValue;
@end

@implementation FxGripDividerTestView
- (void)updateFromCustomData:(NSObject<NSSecureCoding, NSCopying> *)value
{
	self.updateCount += 1;
	self.lastValue = value;
}
@end


@interface FxGripDividerDataTests : XCTestCase
@property (nonatomic, strong) FxGripDividerData *divider;
@end

@implementation FxGripDividerDataTests

- (void)setUp
{
	[super setUp];
	self.divider = [FxGripDividerData.alloc init];
}

- (void)tearDown
{
	self.divider = nil;
	[super tearDown];
}

#pragma mark - Construction

- (void)testInitAppliesTheGoldenRatioWidthAndDefaultMargins
{
	XCTAssertEqualWithAccuracy(self.divider.percentWidth, kGoldenRatio - 1.0, 1e-12);
	XCTAssertEqual(self.divider.marginTop, 7);
	XCTAssertEqual(self.divider.marginBottom, 12);
	XCTAssertEqual(self.divider.parameterHeight, 7 + kDividerHeight + 12);
}

- (void)testDataWithDictionaryReadsTheWidthAndBottomMargin
{
	FxGripDividerData *d = [FxGripDividerData dataWithDictionary:@{@"width": @(0.25), @"marginbottom": @(5)}];

	XCTAssertEqual(d.percentWidth, 0.25);
	XCTAssertEqual(d.marginBottom, 5);
	XCTAssertEqual(d.parameterHeight, 7 + kDividerHeight + 5);
}

- (void)testDataWithAnEmptyOrNilDictionaryKeepsTheDefaults
{
	FxGripDividerData *empty = [FxGripDividerData dataWithDictionary:@{}];
	FxGripDividerData *none = [FxGripDividerData dataWithDictionary:nil];

	XCTAssertEqualWithAccuracy(empty.percentWidth, kGoldenRatio - 1.0, 1e-12);
	XCTAssertEqual(empty.parameterHeight, 20);
	XCTAssertEqualWithAccuracy(none.percentWidth, kGoldenRatio - 1.0, 1e-12);
	XCTAssertEqual(none.parameterHeight, 20);
}

#pragma mark - Derived Geometry

- (void)testSettingTheTopMarginRecomputesTheParameterHeight
{
	self.divider.marginTop = 3;

	XCTAssertEqual(self.divider.marginTop, 3);
	XCTAssertEqual(self.divider.parameterHeight, 3 + kDividerHeight + 12);
}

- (void)testSettingTheBottomMarginRecomputesTheParameterHeight
{
	self.divider.marginBottom = 4;

	XCTAssertEqual(self.divider.marginBottom, 4);
	XCTAssertEqual(self.divider.parameterHeight, 7 + kDividerHeight + 4);
}

- (void)testSettingAnOddParameterHeightSplitsTheMarginsEvenly
{
	self.divider.parameterHeight = 21;

	XCTAssertEqual(self.divider.marginTop, 10);
	XCTAssertEqual(self.divider.marginBottom, 10);
	XCTAssertEqual(self.divider.parameterHeight, 21);
}

- (void)testSettingAnEvenParameterHeightGivesTheExtraPointToTheBottom
{
	self.divider.parameterHeight = 20;

	XCTAssertEqual(self.divider.marginTop, 9);
	XCTAssertEqual(self.divider.marginBottom, 10);
	XCTAssertEqual(self.divider.parameterHeight, 20);
}

- (void)testSettingTheParameterHeightToTheDividerHeightLeavesNoMargins
{
	self.divider.parameterHeight = kDividerHeight;

	XCTAssertEqual(self.divider.marginTop, 0);
	XCTAssertEqual(self.divider.marginBottom, 0);
}

- (void)testSettingTheWidthDoesNotDisturbTheMargins
{
	self.divider.percentWidth = 0.125;

	XCTAssertEqual(self.divider.percentWidth, 0.125);
	XCTAssertEqual(self.divider.marginTop, 7);
	XCTAssertEqual(self.divider.parameterHeight, 20);
}

#pragma mark - Parameter Accessors

- (void)testTheFloatAccessorMapsToTheWidth
{
	double value = 0.0;
	XCTAssertTrue([self.divider getFloatValue:&value]);
	XCTAssertEqualWithAccuracy(value, kGoldenRatio - 1.0, 1e-12);

	XCTAssertTrue([self.divider setFloatValue:0.5]);
	XCTAssertEqual(self.divider.percentWidth, 0.5);

	XCTAssertTrue([self.divider getFloatValue:&value]);
	XCTAssertEqual(value, 0.5);
}

- (void)testTheIntAccessorMapsToTheParameterHeight
{
	int value = 0;
	XCTAssertTrue([self.divider getIntValue:&value]);
	XCTAssertEqual(value, 20);

	XCTAssertTrue([self.divider setIntValue:31]);
	XCTAssertEqual(self.divider.parameterHeight, 31);
	XCTAssertEqual(self.divider.marginTop, 15);
	XCTAssertEqual(self.divider.marginBottom, 15);

	XCTAssertTrue([self.divider getIntValue:&value]);
	XCTAssertEqual(value, 31);
}

#pragma mark - View Notification

- (void)testEveryGeometrySetterNotifiesTheAttachedView
{
	FxGripDividerTestView *view = [FxGripDividerTestView.alloc init];
	self.divider.parameterView = view;

	self.divider.percentWidth = 0.2;
	self.divider.marginTop = 3;
	self.divider.marginBottom = 4;
	self.divider.parameterHeight = 15;

	XCTAssertEqual(view.updateCount, 4u);
	XCTAssertEqualObjects(view.lastValue, self.divider);
}

- (void)testSettersTolerateADetachedView
{
	self.divider.parameterView = nil;

	XCTAssertNoThrow(self.divider.marginTop = 5);
	XCTAssertEqual(self.divider.marginTop, 5);
}

- (void)testAViewThatDoesNotAdoptTheDelegateProtocolIsNotNotified
{
	// parameterView is unsafe_unretained, so the stand-in has to outlive the setter call.
	NSObject *plainView = [NSObject.alloc init];
	self.divider.parameterView = plainView;

	XCTAssertNoThrow(self.divider.parameterHeight = 9);
	XCTAssertEqual(self.divider.parameterHeight, 9);
}

#pragma mark - Copying, Equality, Coding

- (void)testCopyCarriesTheGeometryAndTheViewReferences
{
	FxGripDividerTestView *view = [FxGripDividerTestView.alloc init];
	self.divider.parameterView = view;
	self.divider.parameterEffect = self;
	self.divider.percentWidth = 0.4;
	self.divider.marginTop = 2;
	self.divider.marginBottom = 3;

	FxGripDividerData *copy = [self.divider copy];

	XCTAssertTrue([copy isKindOfClass:FxGripDividerData.class]);
	XCTAssertEqual(copy.percentWidth, 0.4);
	XCTAssertEqual(copy.marginTop, 2);
	XCTAssertEqual(copy.marginBottom, 3);
	XCTAssertEqual(copy.parameterHeight, 2 + kDividerHeight + 3);
	XCTAssertEqual(copy.parameterView, view);
	XCTAssertEqual(copy.parameterEffect, self);
	XCTAssertEqualObjects(self.divider, copy);
}

- (void)testEqualityIgnoresTheViewAndComparesTheGeometry
{
	FxGripDividerTestView *view = [FxGripDividerTestView.alloc init];
	FxGripDividerData *other = [FxGripDividerData.alloc init];
	other.parameterView = view;

	XCTAssertEqualObjects(self.divider, other);

	other.marginTop = 9;
	XCTAssertNotEqualObjects(self.divider, other);

	XCTAssertFalse([self.divider isEqual:nil]);
}

- (void)testTheClassAdvertisesSecureCoding
{
	XCTAssertTrue([FxGripDividerData supportsSecureCoding]);
}

- (void)testSecureCodingRoundTripPreservesTheGeometry
{
	self.divider.percentWidth = 0.375;
	self.divider.marginTop = 4;
	self.divider.marginBottom = 6;

	NSError *encodeError = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.divider requiringSecureCoding:YES error:&encodeError];
	XCTAssertNil(encodeError);

	NSError *decodeError = nil;
	FxGripDividerData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripDividerData.class fromData:data error:&decodeError];

	XCTAssertNil(decodeError);
	XCTAssertEqual(decoded.percentWidth, 0.375);
	XCTAssertEqual(decoded.marginTop, 4);
	XCTAssertEqual(decoded.marginBottom, 6);
	XCTAssertEqual(decoded.parameterHeight, 4 + kDividerHeight + 6);
	XCTAssertEqualObjects(decoded, self.divider);
}

- (void)testADecodedDividerHasNoViewAttachment
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.divider requiringSecureCoding:YES error:NULL];
	FxGripDividerData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripDividerData.class fromData:data error:NULL];

	XCTAssertNil(decoded.parameterView);
	XCTAssertNil(decoded.parameterEffect);
}

#pragma mark - Dictionary Keys

- (void)testDataWithDictionaryReadsTheTopMargin
{
	FxGripDividerData *d = [FxGripDividerData dataWithDictionary:@{@"margintop": @(3)}];

	XCTAssertEqual(d.marginTop, 3);
	XCTAssertEqual(d.parameterHeight, 3 + kDividerHeight + 12);
}

- (void)testDataWithDictionaryReadsBothMarginsTogether
{
	FxGripDividerData *d = [FxGripDividerData dataWithDictionary:@{@"margintop": @(2), @"marginbottom": @(6)}];

	XCTAssertEqual(d.marginTop, 2);
	XCTAssertEqual(d.marginBottom, 6);
	XCTAssertEqual(d.parameterHeight, 2 + kDividerHeight + 6);
}

- (void)testAMisspelledTopMarginKeyIsIgnored
{
	FxGripDividerData *d = [FxGripDividerData dataWithDictionary:@{@"margintpo": @(3)}];

	XCTAssertEqual(d.marginTop, 7);
	XCTAssertEqual(d.marginBottom, 12);
	XCTAssertEqual(d.parameterHeight, 7 + kDividerHeight + 12);
}

#pragma mark - Margin Clamping

- (void)testAParameterHeightBelowTheDividerHeightDoesNotUnderflowTheMargins
{
	self.divider.parameterHeight = 0;

	XCTAssertEqual(self.divider.marginTop, 0);
	XCTAssertEqual(self.divider.marginBottom, 0);
	XCTAssertEqual(self.divider.parameterHeight, 0);
}

#pragma mark - Equality

- (void)testEqualDividersShareAHash
{
	FxGripDividerData *other = [FxGripDividerData.alloc init];

	XCTAssertEqualObjects(self.divider, other);
	XCTAssertEqual(self.divider.hash, other.hash);
}

- (void)testDifferentDividersDoNotShareAHash
{
	FxGripDividerData *other = [FxGripDividerData.alloc init];
	other.marginTop = 9;

	XCTAssertNotEqualObjects(self.divider, other);
	XCTAssertNotEqual(self.divider.hash, other.hash);
}

- (void)testIsEqualToAForeignObjectAnswersFalse
{
	BOOL equal = YES;
	XCTAssertNoThrow(equal = [self.divider isEqual:@"a string"]);
	XCTAssertFalse(equal);
}

- (void)testCopyPreservesAsymmetricMargins
{
	FxGripDividerData *copy = [self.divider copy];

	XCTAssertEqual(copy.marginTop, 7);
	XCTAssertEqual(copy.marginBottom, 12);
	XCTAssertEqualObjects(self.divider, copy);
}

@end
