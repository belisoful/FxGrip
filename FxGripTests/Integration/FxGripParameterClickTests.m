//
//  FxGripParameterClickTests.m
//  FxGripTests
//
//  Unit tests for the standardized button-click dispatch: the synthesized click
//  selector encoding, the runtime resolution that installs the trampoline, the
//  parameter-clicked notification payload, and the default action hook.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/FxGripParameterUtility.h"
#import "FxGrip/FxGripTileableEffect.h"
#import "FxGrip/FxGripTileableEffect+Notifications.h"
#import "FxGrip/FxGripExtension.h"

// FxGripHelpParameter.h is a public header, but it (and FxGripPushButtonParameter.h)
// import their superclass with a flat angled include, so neither resolves outside the
// framework target. The class is reached by name instead.

// The test target links only FxGrip and XCTest. NSPriorityNotificationCenter
// (BEFoundation) is loaded in-process through FxGrip and is reached by name at
// runtime to avoid an unlinked symbol.
static NSNotificationCenter *FxGripClickTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

#pragma mark - Test doubles

// FxGripTileableEffect's designated initializer registers into the process-wide
// notification center, so the click notification tests use a stub exposing the
// two members FxGripExtensionBase reads.
@interface FxGripClickTestStubEffect : NSObject
@property (nonatomic, assign) BOOL addedToDocument;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@end

@implementation FxGripClickTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

@end

// Subclass used only to confirm +resolveInstanceMethod: is inherited.
@interface FxGripClickTestEffectSubclass : FxGripTileableEffect
@end

@implementation FxGripClickTestEffectSubclass
@end

@interface FxGripClickTestClickExtension : FxGripExtensionBase
@property (nonatomic, strong) NSDictionary *lastUserInfo;
@property (nonatomic, assign) BOOL didReceiveClick;
@end

@implementation FxGripClickTestClickExtension
- (void)extParameterClicked:(NSNotification *)notification
{
	self.didReceiveClick = YES;
	self.lastUserInfo = notification.userInfo;
}
@end

@interface FxGripClickTestSilentExtension : FxGripExtensionBase
@end

@implementation FxGripClickTestSilentExtension
@end

#pragma mark - Tests

@interface FxGripParameterClickTests : XCTestCase
@end

@implementation FxGripParameterClickTests

#pragma mark Selector encode / decode

- (void)testClickSelectorNameRoundTripsForRepresentativeParameterIDs
{
	FxParameterId ids[] = { 0, 1, 42, kFxParameterId_InstanceMeta, UINT32_MAX };

	for (size_t i = 0; i < sizeof(ids) / sizeof(ids[0]); i++) {
		FxParameterId expected = ids[i];
		NSString *name = [FxGripParameterUtility clickSelectorNameForParameter:expected];
		XCTAssertNotNil(name);

		SEL selector = NSSelectorFromString(name);
		FxParameterId decoded = 0;
		XCTAssertTrue([FxGripParameterUtility getParameterID:&decoded fromClickSelector:selector],
					  @"selector %@ must decode", name);
		XCTAssertEqual(decoded, expected);
	}
}

- (void)testClickSelectorNameUsesPrefixAndTakesNoArgument
{
	NSArray<NSNumber *> *ids = @[@0u, @1u, @42u, @9995u, @(UINT32_MAX)];

	for (NSNumber *identifier in ids) {
		NSString *name = [FxGripParameterUtility clickSelectorNameForParameter:identifier.unsignedIntValue];
		XCTAssertTrue([name hasPrefix:kFxGripClickSelectorPrefix]);
		// The FxPlug button contract registers a zero-argument selector.
		XCTAssertEqual([name rangeOfString:@":"].location, (NSUInteger)NSNotFound);
	}
}

- (void)testGetParameterIDRejectsMalformedSelectors
{
	NSString *prefix = kFxGripClickSelectorPrefix;
	NSArray<NSString *> *rejected = @[
		prefix,													// no digits
		[prefix stringByAppendingString:@"12x"],				// trailing junk
		[prefix stringByAppendingString:@" 12"],				// embedded space
		@"clickMyButton",										// unrelated plugin selector
		[prefix.lowercaseString stringByAppendingString:@"12"],	// wrong case
		[[prefix substringFromIndex:@"click".length] stringByAppendingString:@"12"],	// missing "click"
		[prefix stringByAppendingString:@"4294967296"],			// greater than UINT32_MAX
	];

	for (NSString *name in rejected) {
		FxParameterId decoded = 12345;
		XCTAssertFalse([FxGripParameterUtility getParameterID:&decoded fromClickSelector:NSSelectorFromString(name)],
					   @"%@ must not decode as a click selector", name);
	}
}

- (void)testGetParameterIDRejectsNullSelectorAndNullOutPointer
{
	FxParameterId decoded = 0;
	SEL nullSelector = NULL;
	XCTAssertFalse([FxGripParameterUtility getParameterID:&decoded fromClickSelector:nullSelector]);

	FxParameterId *nullOut = NULL;
	SEL valid = NSSelectorFromString([FxGripParameterUtility clickSelectorNameForParameter:7]);
	XCTAssertFalse([FxGripParameterUtility getParameterID:nullOut fromClickSelector:valid]);
}

#pragma mark Runtime resolution

- (void)testSynthesizedClickSelectorResolvesOnEffectBase
{
	SEL selector = NSSelectorFromString([FxGripParameterUtility clickSelectorNameForParameter:777]);
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:selector]);
}

- (void)testResolvedClickSelectorInstallsTrampolineMethod
{
	SEL selector = NSSelectorFromString([FxGripParameterUtility clickSelectorNameForParameter:777]);
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:selector]);
	XCTAssertTrue(class_getInstanceMethod(FxGripTileableEffect.class, selector) != NULL);
}

- (void)testNonSynthesizedSelectorsAreNotResolved
{
	XCTAssertFalse([FxGripTileableEffect instancesRespondToSelector:NSSelectorFromString(@"clickMyButton")]);
	XCTAssertFalse([FxGripTileableEffect instancesRespondToSelector:NSSelectorFromString([kFxGripClickSelectorPrefix stringByAppendingString:@"12x"])]);
}

- (void)testSubclassInheritsClickSelectorResolution
{
	SEL selector = NSSelectorFromString([FxGripParameterUtility clickSelectorNameForParameter:31337]);
	XCTAssertTrue([FxGripClickTestEffectSubclass instancesRespondToSelector:selector]);
}

#pragma mark Notification payload contract

- (void)testParameterClickedConstantsAreNonEmptyAndDistinct
{
	XCTAssertNotNil(FxGripTileableEffectParameterClickedName);
	XCTAssertNotNil(FxGripTileableEffectParameterClickedIDKey);
	XCTAssertGreaterThan(FxGripTileableEffectParameterClickedName.length, (NSUInteger)0);
	XCTAssertGreaterThan(FxGripTileableEffectParameterClickedIDKey.length, (NSUInteger)0);

	NSArray<NSString *> *clicked = @[
		FxGripTileableEffectParameterClickedName,
		FxGripTileableEffectParameterClickedIDKey,
	];
	NSArray<NSString *> *changed = @[
		FxGripTileableEffectParameterChangedName,
		FxGripTileableEffectParameterChangedIDKey,
		FxGripTileableEffectParameterChangedAtTimeKey,
	];

	XCTAssertNotEqualObjects(FxGripTileableEffectParameterClickedName, FxGripTileableEffectParameterClickedIDKey);
	for (NSString *clickConstant in clicked) {
		XCTAssertFalse([changed containsObject:clickConstant],
					   @"%@ must be distinct from the parameter-changed constants", clickConstant);
	}
}

- (void)testParameterClickedPayloadRoundTripThroughPriorityCenter
{
	NSNotificationCenter *center = FxGripClickTestMakePriorityCenter();
	id sender = [NSObject.alloc init];
	NSNumber *paramID = @(4207u);

	__block BOOL received = NO;
	__block NSNumber *receivedID = nil;

	id token = [center addObserverForName:FxGripTileableEffectParameterClickedName
								   object:sender
									queue:nil
							   usingBlock:^(NSNotification *note) {
		received = YES;
		receivedID = note.userInfo[FxGripTileableEffectParameterClickedIDKey];
	}];

	[center postNotificationName:FxGripTileableEffectParameterClickedName
						  object:sender
						userInfo:@{FxGripTileableEffectParameterClickedIDKey: paramID}];

	XCTAssertTrue(received);
	XCTAssertEqualObjects(receivedID, paramID);
	XCTAssertEqual(receivedID.unsignedIntValue, (FxParameterId)4207u);

	[center removeObserver:token];
}

- (void)testParameterClickedPayloadDeliveredToExtensionObserver
{
	FxGripClickTestStubEffect *effect = [FxGripClickTestStubEffect.alloc init];
	effect.notifier = FxGripClickTestMakePriorityCenter();

	FxGripClickTestClickExtension *ext = [FxGripClickTestClickExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect]);

	NSNumber *paramID = @(88u);
	[effect.notifier postNotificationName:FxGripTileableEffectParameterClickedName
								   object:effect
								 userInfo:@{FxGripTileableEffectParameterClickedIDKey: paramID}];

	XCTAssertTrue(ext.didReceiveClick);
	XCTAssertEqualObjects(ext.lastUserInfo[FxGripTileableEffectParameterClickedIDKey], paramID);
}

- (void)testParameterClickedNotificationIgnoredByExtensionWithoutHook
{
	FxGripClickTestStubEffect *effect = [FxGripClickTestStubEffect.alloc init];
	effect.notifier = FxGripClickTestMakePriorityCenter();

	FxGripClickTestSilentExtension *ext = [FxGripClickTestSilentExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect]);

	XCTAssertNoThrow([effect.notifier postNotificationName:FxGripTileableEffectParameterClickedName
													object:effect
												  userInfo:@{FxGripTileableEffectParameterClickedIDKey: @(5u)}]);
}

#pragma mark Default action hook

- (void)testHelpParameterRespondsToDefaultParameterAction
{
	Class helpClass = NSClassFromString(@"FxGripHelpParameter");
	XCTAssertNotNil(helpClass);

	id parameter = [[helpClass alloc] init];
	XCTAssertNotNil(parameter);
	// Conformance only; invoking it opens the system help viewer.
	XCTAssertTrue([parameter respondsToSelector:NSSelectorFromString(@"defaultParameterAction")]);
}

@end
