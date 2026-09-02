//
//  FxGripFxFactoryTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>

// FxGripFxFactory.h is not a public framework header (it imports the third-party FxFactory
// SDK), so the surface under test is redeclared locally. The implementation comes from the
// linked framework.
@interface FxGripFxFactory : NSObject
- (instancetype)init;
- (void)extAddParameters:(nonnull NSNotification *)notification;
- (void)extParameterChanged:(nonnull NSNotification *)notification;
- (void)extAddedToDocument:(nonnull NSNotification *)notification;
- (void)extRenderDestinationImage:(nonnull NSNotification *)notification;
- (BOOL)showContactForm:(nullable NSString *)recipient subject:(nullable NSString *)subject message:(nullable NSString *)message;
- (BOOL)pluginIsLicensed;
- (void)setFxFactoryPluginUUID:(nonnull NSString *)uuid;
- (BOOL)extLoadWithEffect:(nonnull id)effect;
- (BOOL)fxFactoryActive;
- (void)registerLicenseHandler:(nullable NSString *)productUUID;
- (void)showProductUpdates;
- (void)setBoolValue:(BOOL)value;
- (BOOL)boolValue;
// Overridable FxFactory SDK seams.
- (BOOL)factoryInstalled;
- (NSUInteger)factoryLicensingStatusForProduct:(nullable NSString *)productUUID;
- (BOOL)factoryContactFormAvailable;
- (BOOL)factoryShowContactFormToRecipient:(nullable NSString *)recipient subject:(nullable NSString *)subject message:(nullable NSString *)message;
- (BOOL)fxFactoryWaterMarkUnlicensed;
- (BOOL)renderWatermarkOntoImage:(nullable id)destinationImage error:(NSError *_Nullable *_Nullable)outError;
@end

// A mock end that overrides the SDK seams, so the licensing and contact-form logic runs end
// to end without a live FxFactory installation. FxFactoryLicensingStatus is an NSUInteger
// enum; ProductUnlicensed is 2 and ProductLicensed is 3.
@interface FxGripFxFactoryMock : FxGripFxFactory
@property (nonatomic, assign) NSUInteger mockStatus;
@property (nonatomic, strong) NSMutableArray<NSString *> *contactRecipients;
@end

@implementation FxGripFxFactoryMock
- (instancetype)init
{
	self = [super init];
	if (self) {
		_mockStatus = 2;
		_contactRecipients = NSMutableArray.new;
	}
	return self;
}
- (BOOL)factoryInstalled { return YES; }
- (NSUInteger)factoryLicensingStatusForProduct:(NSString *)productUUID { return self.mockStatus; }
- (BOOL)factoryContactFormAvailable { return YES; }
- (BOOL)factoryShowContactFormToRecipient:(NSString *)recipient subject:(NSString *)subject message:(NSString *)message
{
	[self.contactRecipients addObject:recipient ?: @""];
	return YES;
}
@end

// A stub effect the extAddedToDocument: path reads: the debug property, the regression gate,
// and the license-state application (a category on the real effect, redeclared here as a
// plain method the stub answers).
@interface FxGripFxFactoryStubEffect : NSObject
@property (nonatomic, strong) NSDictionary<NSString *, id> *pluginProperties;
@property (nonatomic, assign) BOOL licenseStateApplied;
@property (nonatomic, assign) BOOL appliedLicenseState;
@end

@implementation FxGripFxFactoryStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

- (NSNotificationCenter *)notifier
{
	// extLoadWithEffect: reads the notifier to register observers; a real priority center
	// keeps that registration harmless.
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}
- (BOOL)hasExtensionClass:(Class)cls { return NO; }
- (void)setFxFactoryLicenseState:(BOOL)licensed
{
	self.licenseStateApplied = YES;
	self.appliedLicenseState = licensed;
}
@end

// Extends the mock so extAddedToDocument: runs without touching a host: it is active, its
// side-effecting handler installs are no-ops, and the license toggle records locally.
@interface FxGripFxFactoryDocumentMock : FxGripFxFactoryMock
@property (nonatomic, assign) BOOL recordedBoolValue;
@property (nonatomic, assign) BOOL boolValueWasSet;
@end

@implementation FxGripFxFactoryDocumentMock
- (BOOL)fxFactoryActive { return YES; }
- (NSString *)fxFactoryPluginUUID { return @"test-uuid"; }
- (void)registerLicenseHandler:(NSString *)productUUID {}
- (void)showProductUpdates {}
- (void)setBoolValue:(BOOL)value { self.recordedBoolValue = value; self.boolValueWasSet = YES; }
- (BOOL)boolValue { return self.recordedBoolValue; }
@end

// Records the watermark-render seam so the render DECISION is testable without the GPU.
@interface FxGripFxFactoryWatermarkMock : FxGripFxFactoryMock
@property (nonatomic, assign) BOOL watermarkEnabled;
@property (nonatomic, assign) NSUInteger renderCount;
@end

@implementation FxGripFxFactoryWatermarkMock
- (BOOL)fxFactoryWaterMarkUnlicensed { return self.watermarkEnabled; }
- (BOOL)renderWatermarkOntoImage:(id)destinationImage error:(NSError *_Nullable *_Nullable)outError
{
	self.renderCount += 1;
	return YES;
}
@end

@interface FxGripFxFactoryTests : XCTestCase
@property (nonatomic, strong) FxGripFxFactory *factory;
@end

@implementation FxGripFxFactoryTests

- (void)setUp
{
	[super setUp];
	self.factory = [NSClassFromString(@"FxGripFxFactory") alloc];
	self.factory = [self.factory init];
}

- (void)tearDown
{
	self.factory = nil;
	[super tearDown];
}

#pragma mark The notification-dispatch port

- (void)testTheExtensionRespondsToThePortedNotificationSelectors
{
	// The live dispatch table delivers each hook a single NSNotification; the legacy
	// signatures were never called.
	XCTAssertTrue([self.factory respondsToSelector:@selector(extAddParameters:)]);
	XCTAssertTrue([self.factory respondsToSelector:@selector(extParameterChanged:)]);
	XCTAssertTrue([self.factory respondsToSelector:@selector(extAddedToDocument:)]);
	XCTAssertTrue([self.factory respondsToSelector:@selector(extRenderDestinationImage:)]);
}

- (void)testTheExtensionNoLongerRespondsToTheLegacySelectors
{
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extProcessParameters:")]);
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extAddedToDocument")]);
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extParameterChanged:atTime:error:")]);
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extRenderDestinationImage:sourceImages:pluginState:atTime:error:")]);
}

#pragma mark Handler behavior

- (void)testAnInactiveConfigurationAddsNoParameters
{
	// Without an FxFactory settings object or an FxFactoryActive property the extension is
	// inactive and contributes nothing to the parameter list.
	NSMutableArray<NSMutableDictionary *> *parameters = NSMutableArray.new;
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectAddParametersName
														object:nil
													  userInfo:@{FxGripTileableEffectParametersKey: parameters}];

	XCTAssertNoThrow([self.factory extAddParameters:note]);
	XCTAssertEqual(parameters.count, (NSUInteger)0);
}

- (void)testParameterChangedIgnoresANotificationWithoutAParameterID
{
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
														object:nil
													  userInfo:@{}];
	XCTAssertNoThrow([self.factory extParameterChanged:note]);
}

- (void)testRenderIgnoresANotificationWithoutADestinationImage
{
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectRenderDestinationImageName
														object:nil
													  userInfo:@{}];
	XCTAssertNoThrow([self.factory extRenderDestinationImage:note]);
}

#pragma mark #35 — contact-form recipient guard

- (void)testTheContactFormRejectsExternalRecipients
{
	// An external recipient is refused. On a machine without FxFactory the SDK guard also
	// refuses, so the assertion holds either way; the fix keeps it from silently allowing
	// external addresses when FxFactory is present.
	XCTAssertFalse([self.factory showContactForm:@"someone@external.example" subject:@"s" message:@"m"]);
}

#pragma mark End-to-end via the mock seams

- (void)testLicenseDecisionFollowsTheLicensingSeam
{
	FxGripFxFactoryMock *licensed = [FxGripFxFactoryMock.alloc init];
	[licensed setFxFactoryPluginUUID:@"test-uuid"];
	licensed.mockStatus = 3;   // ProductLicensed
	XCTAssertTrue([licensed pluginIsLicensed]);

	FxGripFxFactoryMock *unlicensed = [FxGripFxFactoryMock.alloc init];
	[unlicensed setFxFactoryPluginUUID:@"test-uuid"];
	unlicensed.mockStatus = 2; // ProductUnlicensed
	XCTAssertFalse([unlicensed pluginIsLicensed]);
}

- (void)testTheContactFormGuardRunsEndToEndThroughTheSeam
{
	FxGripFxFactoryMock *mock = [FxGripFxFactoryMock.alloc init];

	// With the form "available" via the seam, the recipient guard is reached: an
	// @fxfactory.com address is sent, an external address is refused before the send.
	XCTAssertTrue([mock showContactForm:@"support@fxfactory.com" subject:@"s" message:@"m"]);
	XCTAssertEqualObjects(mock.contactRecipients, (@[@"support@fxfactory.com"]));

	XCTAssertFalse([mock showContactForm:@"someone@external.example" subject:@"s" message:@"m"]);
	XCTAssertEqual(mock.contactRecipients.count, (NSUInteger)1,
				   @"the external recipient was rejected before the send");
}

#pragma mark #34 — the DEBUG license override (end to end)

- (FxGripFxFactoryDocumentMock *)runAddedToDocumentWithDebugProperty:(nullable id)debugValue
													  realStatus:(NSUInteger)realStatus
														  effect:(FxGripFxFactoryStubEffect **)outEffect
{
	FxGripFxFactoryDocumentMock *mock = [FxGripFxFactoryDocumentMock.alloc init];
	mock.mockStatus = realStatus;   // what the real FxFactory seam would report

	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	effect.pluginProperties = debugValue ? @{@"FxFactoryDebugSetLicensed": debugValue} : @{};
	[mock extLoadWithEffect:(id)effect];

	[mock extAddedToDocument:[NSNotification notificationWithName:@"added" object:effect userInfo:nil]];
	if (outEffect) {
		*outEffect = effect;
	}
	return mock;
}

- (void)testTheDebugOverrideForcesLicensedOverTheRealStatus
{
	FxGripFxFactoryStubEffect *effect = nil;
	// Real status is Unlicensed (2); the debug override forces licensed.
	FxGripFxFactoryDocumentMock *mock = [self runAddedToDocumentWithDebugProperty:@YES realStatus:2 effect:&effect];

	XCTAssertTrue([mock pluginIsLicensed], @"the debug override drives pluginIsLicensed, not the real status");
	XCTAssertTrue(mock.boolValueWasSet);
	XCTAssertTrue(mock.recordedBoolValue, @"the license toggle mirrors the override");
	XCTAssertTrue(effect.appliedLicenseState, @"the license UI state is applied");
}

- (void)testTheDebugOverrideForcesUnlicensedOverTheRealStatus
{
	FxGripFxFactoryStubEffect *effect = nil;
	// Real status is Licensed (3); the debug override forces unlicensed.
	FxGripFxFactoryDocumentMock *mock = [self runAddedToDocumentWithDebugProperty:@NO realStatus:3 effect:&effect];

	XCTAssertFalse([mock pluginIsLicensed]);
	XCTAssertTrue(mock.boolValueWasSet);
	XCTAssertFalse(mock.recordedBoolValue);
	XCTAssertFalse(effect.appliedLicenseState);
}

- (void)testAnAbsentDebugPropertyFallsThroughToTheRealLicensingSync
{
	FxGripFxFactoryStubEffect *effect = nil;
	// No override property: the real status (Licensed) is used. The prior #34 bug forced
	// every debug build unlicensed here; now it must honor the real status.
	FxGripFxFactoryDocumentMock *mock = [self runAddedToDocumentWithDebugProperty:nil realStatus:3 effect:&effect];

	XCTAssertTrue([mock pluginIsLicensed], @"an absent override falls through to the real licensed status");
	XCTAssertTrue(mock.recordedBoolValue, @"the toggle syncs to the real licensed state");
}

#pragma mark #36 — the watermark render decision (end to end)

- (NSUInteger)renderCountForWatermark:(BOOL)watermark licensedStatus:(NSUInteger)status
{
	FxGripFxFactoryWatermarkMock *mock = [FxGripFxFactoryWatermarkMock.alloc init];
	mock.watermarkEnabled = watermark;
	mock.mockStatus = status;
	[mock setFxFactoryPluginUUID:@"test-uuid"];

	// A non-nil placeholder passes the destination-image guard; the mock's render seam
	// records the call rather than touching the GPU.
	NSNotification *note = [NSNotification notificationWithName:@"render"
														object:nil
													  userInfo:@{FxGripTileableEffectRenderDestinationImageKey: NSObject.new}];
	[mock extRenderDestinationImage:note];
	return mock.renderCount;
}

- (void)testUnlicensedWithWatermarkingRunsTheWatermarkRender
{
	// 2 == ProductUnlicensed
	XCTAssertEqual([self renderCountForWatermark:YES licensedStatus:2], (NSUInteger)1);
}

- (void)testLicensedSkipsTheWatermarkRender
{
	// 3 == ProductLicensed
	XCTAssertEqual([self renderCountForWatermark:YES licensedStatus:3], (NSUInteger)0);
}

- (void)testWatermarkingDisabledSkipsTheRender
{
	XCTAssertEqual([self renderCountForWatermark:NO licensedStatus:2], (NSUInteger)0);
}

@end
