/*!
	@file       FxGripFxFactoryTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripFxFactoryTests
	@abstract   Unit tests for the FxGripFxFactory extension's licensing, contact form, watermark, and settings behavior.
	@discussion Introduced in FxGrip 0.1.0. Mock subclasses override the FxFactory SDK seams so the licensing, contact-form, watermark-render, and handler-registration logic runs end to end without a live FxFactory installation. The tests cover the ported notification dispatch selectors, the inactive-configuration and missing-payload guards, the contact-form recipient guard, the debug license override, the watermark render decision, handler re-registration teardown, a settings-object watermark opt-out, and cache invalidation on a product UUID change.
*/

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
- (void)unregisterLicenseHandler;
- (void)showProductUpdates;
- (void)setBoolValue:(BOOL)value;
- (BOOL)boolValue;
- (void)setFxFactorySettingsObject:(nullable id)settingsObject;
- (BOOL)fxFactoryHasWaterMarkUnlicensed;
- (void)extParameterChanged:(nonnull NSNotification *)notification;
// Overridable FxFactory SDK seams.
- (BOOL)factoryInstalled;
- (NSUInteger)factoryLicensingStatusForProduct:(nullable NSString *)productUUID;
- (nullable id)factoryRegisterLicensingHandlerForProduct:(nullable NSString *)productUUID handler:(nonnull id)handler;
- (void)factoryUnregisterLicensingHandler:(nullable id)handle forProduct:(nullable NSString *)productUUID;
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

// Records the product UUID passed to the unregister seam, and stubs the register seam so a
// handler is installed without a live FxFactory. Drives the register/unregister UUID pairing.
@interface FxGripFxFactoryHandlerMock : FxGripFxFactoryMock
@property (nonatomic, strong) NSMutableArray<NSString *> *unregisteredUUIDs;
@end

@implementation FxGripFxFactoryHandlerMock
- (instancetype)init
{
	self = [super init];
	if (self) {
		_unregisteredUUIDs = NSMutableArray.new;
	}
	return self;
}
- (id)factoryRegisterLicensingHandlerForProduct:(NSString *)productUUID handler:(id)handler
{
	return @"handle";
}
- (void)factoryUnregisterLicensingHandler:(id)handle forProduct:(NSString *)productUUID
{
	[self.unregisteredUUIDs addObject:productUUID ?: @""];
}
@end

// A hard-coded settings object: the plugin declares its FxFactory preferences in code rather
// than through the plist parameter. respondsToSelector drives the extAddParameters branches.
@interface FxGripFxFactorySettingsMock : NSObject
@property (nonatomic, assign) BOOL watermark;
@end

@implementation FxGripFxFactorySettingsMock
- (BOOL)fxFactoryActive { return YES; }
- (NSString *)fxFactoryProductUUID { return @"settings-uuid"; }
- (BOOL)fxFactoryWaterMarkUnlicensed { return self.watermark; }
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

/*! @abstract The extension responds to the single-notification dispatch selectors for parameters, changes, document add, and render. */
- (void)testTheExtensionRespondsToThePortedNotificationSelectors
{
	// The live dispatch table delivers each hook a single NSNotification; the legacy
	// signatures were never called.
	XCTAssertTrue([self.factory respondsToSelector:@selector(extAddParameters:)]);
	XCTAssertTrue([self.factory respondsToSelector:@selector(extParameterChanged:)]);
	XCTAssertTrue([self.factory respondsToSelector:@selector(extAddedToDocument:)]);
	XCTAssertTrue([self.factory respondsToSelector:@selector(extRenderDestinationImage:)]);
}

/*! @abstract The extension no longer responds to the legacy multi-argument hook selectors. */
- (void)testTheExtensionNoLongerRespondsToTheLegacySelectors
{
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extProcessParameters:")]);
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extAddedToDocument")]);
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extParameterChanged:atTime:error:")]);
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extRenderDestinationImage:sourceImages:pluginState:atTime:error:")]);
}

#pragma mark Handler behavior

/*! @abstract An inactive configuration adds no parameters to the list. */
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

/*! @abstract The parameter-changed handler ignores a notification carrying no parameter id without throwing. */
- (void)testParameterChangedIgnoresANotificationWithoutAParameterID
{
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
														object:nil
													  userInfo:@{}];
	XCTAssertNoThrow([self.factory extParameterChanged:note]);
}

/*! @abstract The render handler ignores a notification carrying no destination image without throwing. */
- (void)testRenderIgnoresANotificationWithoutADestinationImage
{
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectRenderDestinationImageName
														object:nil
													  userInfo:@{}];
	XCTAssertNoThrow([self.factory extRenderDestinationImage:note]);
}

#pragma mark #35 — contact-form recipient guard

/*! @abstract The contact form refuses an external recipient address. */
- (void)testTheContactFormRejectsExternalRecipients
{
	// An external recipient is refused. On a machine without FxFactory the SDK guard also
	// refuses, so the assertion holds either way; the fix keeps it from silently allowing
	// external addresses when FxFactory is present.
	XCTAssertFalse([self.factory showContactForm:@"someone@external.example" subject:@"s" message:@"m"]);
}

#pragma mark End-to-end via the mock seams

/*! @abstract pluginIsLicensed follows the licensing seam status, true for licensed and false for unlicensed. */
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

/*! @abstract The contact form sends to an fxfactory.com recipient and refuses an external recipient before the send. */
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

/*! @abstract The debug override forces licensed over an unlicensed real status and applies the licensed UI state. */
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

/*! @abstract The debug override forces unlicensed over a licensed real status and applies the unlicensed UI state. */
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

/*! @abstract An absent debug override falls through to the real licensing status and syncs the toggle to it. */
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

/*! @abstract An unlicensed plugin with watermarking enabled runs the watermark render once. */
- (void)testUnlicensedWithWatermarkingRunsTheWatermarkRender
{
	// 2 == ProductUnlicensed
	XCTAssertEqual([self renderCountForWatermark:YES licensedStatus:2], (NSUInteger)1);
}

/*! @abstract A licensed plugin skips the watermark render. */
- (void)testLicensedSkipsTheWatermarkRender
{
	// 3 == ProductLicensed
	XCTAssertEqual([self renderCountForWatermark:YES licensedStatus:3], (NSUInteger)0);
}

/*! @abstract Disabled watermarking skips the render even when unlicensed. */
- (void)testWatermarkingDisabledSkipsTheRender
{
	XCTAssertEqual([self renderCountForWatermark:NO licensedStatus:2], (NSUInteger)0);
}

#pragma mark License handler unregisters the UUID it registered

/*! @abstract Re-registering a license handler first unregisters the previous product's UUID. */
- (void)testReRegisteringTearsDownThePreviousProductsHandler
{
	FxGripFxFactoryHandlerMock *mock = [FxGripFxFactoryHandlerMock.alloc init];

	[mock registerLicenseHandler:@"uuid-A"];
	[mock registerLicenseHandler:@"uuid-B"];   // re-register must first unregister uuid-A

	XCTAssertEqualObjects(mock.unregisteredUUIDs, (@[@"uuid-A"]),
						  @"unregister targets the UUID the handler was registered with, not the current one");
}

#pragma mark A settings-object watermark preference is honored

/*! @abstract A settings-object watermark opt-out registers as present and is honored rather than overridden to YES. */
- (void)testASettingsObjectWatermarkOptOutIsHonored
{
	FxGripFxFactory *factory = [NSClassFromString(@"FxGripFxFactory") alloc];
	factory = [factory init];

	FxGripFxFactorySettingsMock *settings = FxGripFxFactorySettingsMock.new;
	settings.watermark = NO;   // the plugin explicitly opts out of the unlicensed watermark
	[factory setFxFactorySettingsObject:(id)settings];

	// A fxfactory-typed parameter with a parent id, so the fallback parameters the path may add
	// carry a non-nil parent id.
	NSMutableDictionary *fxFactoryParameter = @{ kFxParameterProperty_Type: @"fxfactory",
												 kFxParameterProperty_ParentId: @0 }.mutableCopy;
	NSMutableArray *parameters = @[ fxFactoryParameter ].mutableCopy;
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectAddParametersName
														object:nil
													  userInfo:@{FxGripTileableEffectParametersKey: parameters}];
	[factory extAddParameters:note];

	XCTAssertTrue([factory fxFactoryHasWaterMarkUnlicensed],
				  @"a settings-object value registers as present, like every other configuration flag");
	XCTAssertFalse([factory fxFactoryWaterMarkUnlicensed],
				   @"the explicit opt-out is honored, not overridden to YES by the product default");
}

#pragma mark Changing the product UUID invalidates the cached license verdict

/*! @abstract Changing the product UUID clears the cached license verdict so it recomputes for the new product. */
- (void)testChangingTheProductUUIDInvalidatesTheCachedLicenseVerdict
{
	FxGripFxFactoryDocumentMock *mock = [FxGripFxFactoryDocumentMock.alloc init];
	mock.mockStatus = 3;   // the current product is Licensed
	XCTAssertTrue([mock pluginIsLicensed], @"first read caches the verdict");

	mock.mockStatus = 2;   // the newly chosen product is Unlicensed
	// paramID = parameterID (0) + kParameterFxFactoryProductUUIDOffset (2)
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
														object:nil
													  userInfo:@{FxGripTileableEffectParameterChangedIDKey: @(2)}];
	[mock extParameterChanged:note];

	XCTAssertFalse([mock pluginIsLicensed],
				   @"the UUID change clears the cached verdict so it recomputes for the new product");
}

@end
