/*!
	@file       FxGripAboutMenuTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripAboutMenuTests
	@abstract   Unit tests for the About menu's link fallback chain, warning dialog, and effect-side accessors.
	@discussion Introduced in FxGrip 0.1.0. The tests substitute the extension's two side-effecting
	            primitives, the single NSWorkspace open and the single modal run, so the ordered URL
	            fallback, the link broadcast, and the warning dialog are driven without opening a URL
	            or running a modal. A real effect that resolves an About menu configuration covers the
	            effect-side accessors and the extension factory.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripAboutMenu.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Extensions.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>

static CMTime FxGripAboutLinkTestZeroTime(void)
{
	return (CMTime){.value = 0, .timescale = 1, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

// FxGripAboutMenu.h publishes the class without its members, so the link and dialog
// primitives the tests drive are declared here. The implementation comes from the framework.
@interface FxGripAboutMenu (FxGripAboutMenuLinkTestAccess)
- (nonnull NSArray<NSString *> *)aboutMenuItemsReadingValues:(BOOL)readValues atTime:(CMTime)time;
- (BOOL)manageAboutMenu:(FxParameterId)parameterID atTime:(CMTime)time error:(NSError *_Nullable *_Nullable)error;
- (void)extAddParameters:(nonnull NSNotification *)notification;
- (void)extParameterChanged:(nonnull NSNotification *)notification;
- (void)openAboutURLStrings:(nonnull NSArray<NSString *> *)urlStrings;
- (void)openURLQueue:(nonnull NSArray<NSURL *> *)urls atIndex:(NSUInteger)index;
- (void)openAboutURL:(nonnull NSURL *)url
   completionHandler:(nonnull void (^)(NSRunningApplication *_Nullable, NSError *_Nullable))completionHandler;
- (void)broadcastAboutLink:(nonnull NSURL *)url;
- (void)showAboutDialogWithText:(nullable NSString *)text;
- (void)presentAboutAlert:(nonnull NSAlert *)alert;
@end

/*!
	Substitutes the two side-effecting primitives: the single NSWorkspace open replies with a
	scripted success or failure, and the single modal run records the alert.
*/
@interface FxGripAboutLinkTestMenu : FxGripAboutMenu
@property (nonatomic, strong) NSMutableArray<NSString *> *attemptedURLs;
@property (nonatomic, copy) NSString *succeedingURL;
@property (nonatomic, strong) NSMutableArray<NSAlert *> *presentedAlerts;
@end

@implementation FxGripAboutLinkTestMenu

- (instancetype)init
{
	self = [super init];
	if (self) {
		_attemptedURLs = NSMutableArray.new;
		_presentedAlerts = NSMutableArray.new;
	}
	return self;
}

- (void)openAboutURL:(NSURL *)url completionHandler:(void (^)(NSRunningApplication *, NSError *))completionHandler
{
	[self.attemptedURLs addObject:url.absoluteString];
	if ([url.absoluteString isEqualToString:self.succeedingURL]) {
		completionHandler(nil, nil);
	} else {
		completionHandler(nil, [NSError errorWithDomain:@"FxGripAboutMenuTests" code:1 userInfo:nil]);
	}
}

- (void)presentAboutAlert:(NSAlert *)alert
{
	[self.presentedAlerts addObject:alert];
}

@end

/*! Stands in for the host's value readback, with each read independently failable. */
@interface FxGripAboutLinkTestGetAPI : NSObject
@property (nonatomic, assign) BOOL intReadSucceeds;
@property (nonatomic, assign) BOOL boolReadSucceeds;
@property (nonatomic, assign) int intValue;
@property (nonatomic, assign) BOOL boolValue;
@end

@implementation FxGripAboutLinkTestGetAPI

- (BOOL)getIntValue:(int *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (value) {
		*value = self.intValue;
	}
	return self.intReadSucceeds;
}

- (BOOL)getBoolValue:(BOOL *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (value) {
		*value = self.boolValue;
	}
	return self.boolReadSucceeds;
}

@end

/*! Vends the readback stub; the dynamic API the refresh writes through is absent. */
@interface FxGripAboutLinkTestAPIManager : NSObject
@property (nonatomic, strong) FxGripAboutLinkTestGetAPI *paramGetAPIv6;
@end

@implementation FxGripAboutLinkTestAPIManager

- (instancetype)init
{
	self = [super init];
	if (self) {
		_paramGetAPIv6 = [FxGripAboutLinkTestGetAPI.alloc init];
	}
	return self;
}

- (id)dynamicParamAPIv3 { return nil; }

@end

/*! Stands in for the effect the extension broadcasts through and reads its configuration from. */
@interface FxGripAboutLinkTestEffect : NSObject
@property (nonatomic, strong, readonly) NSNotificationCenter *notifier;
@property (nonatomic, strong) FxGripAboutLinkTestAPIManager *apiManager;
@property (nonatomic, strong) id aboutMenuConfiguration;
@property (nonatomic, strong) NSArray<NSDictionary *> *injectedItems;
@end

@implementation FxGripAboutLinkTestEffect

- (instancetype)init
{
	self = [super init];
	if (self) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_notifier = [[cls alloc] init];
		_apiManager = [FxGripAboutLinkTestAPIManager.alloc init];
	}
	return self;
}

- (id)effectBase { return self; }

- (BOOL)hasAboutMenu { return self.aboutMenuConfiguration != nil; }

- (NSArray<NSDictionary *> *)aboutMenuItems:(NSArray<NSDictionary *> *)items
{
	return self.injectedItems ? [items arrayByAddingObjectsFromArray:self.injectedItems] : items;
}

@end

/*! A real effect that resolves an About menu configuration, so the loader installs the
	extension and the effect-side accessors resolve it. */
@interface FxGripAboutLinkHostEffect : FxGripTileableEffect
@end

@implementation FxGripAboutLinkHostEffect

- (NSDictionary *)aboutMenuConfiguration
{
	return @{FxGripAboutMenuNameKey: @"About",
			 FxGripAboutMenuItemsKey: @[@{FxGripAboutEntryLabelKey: @"Help",
										  FxGripAboutEntryUrlKey: @"https://help.example"}]};
}

@end

/*! An effect that extends the configured entries through the subclass item hook. */
@interface FxGripAboutLinkHookEffect : FxGripAboutLinkHostEffect
@end

@implementation FxGripAboutLinkHookEffect

- (NSArray<NSDictionary *> *)aboutMenuItems:(NSArray<NSDictionary *> *)items
{
	return [items arrayByAddingObject:@{FxGripAboutEntryLabelKey: @"Extra"}];
}

@end

@interface FxGripAboutMenuLinkTests : XCTestCase
@property (nonatomic, strong) FxGripAboutLinkTestMenu *extension;
@property (nonatomic, strong) FxGripAboutLinkTestEffect *effect;
@end

@implementation FxGripAboutMenuLinkTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripAboutLinkTestEffect.alloc init];
	self.extension = [FxGripAboutLinkTestMenu.alloc init];
	[self.extension extLoadWithEffect:(id)self.effect];
}

- (void)tearDown
{
	self.extension = nil;
	self.effect = nil;
	[super tearDown];
}

/*! Waits for the link broadcast, which hops to the main queue before it posts. */
- (NSString *)awaitBroadcastWhileRunning:(void (^)(void))work
{
	__block NSString *broadcast = nil;
	XCTestExpectation *posted = [self expectationWithDescription:@"about link broadcast"];
	id token = [self.effect.notifier addObserverForName:FxGripAboutMenuLinkName object:nil queue:nil
											 usingBlock:^(NSNotification *note) {
		broadcast = note.userInfo[FxGripAboutMenuLinkURLKey];
		[posted fulfill];
	}];
	work();
	[self waitForExpectations:@[posted] timeout:2.0];
	[self.effect.notifier removeObserver:token];
	return broadcast;
}

#pragma mark The ordered URL fallback

/*! @abstract Opening a link tries the primary URL first and broadcasts it when the open succeeds. */
- (void)testAWorkingPrimaryURLIsOpenedAndBroadcast
{
	self.extension.succeedingURL = @"https://primary.example";

	NSString *broadcast = [self awaitBroadcastWhileRunning:^{
		[self.extension openAboutURLStrings:@[@"https://primary.example", @"https://fallback.example"]];
	}];

	XCTAssertEqualObjects(self.extension.attemptedURLs, (@[@"https://primary.example"]),
						  @"a working primary URL stops the chain");
	XCTAssertEqualObjects(broadcast, @"https://primary.example");
}

/*! @abstract A failing URL falls through to the next one in the chain, which is the one broadcast. */
- (void)testAFailingURLFallsThroughToTheNextInTheChain
{
	self.extension.succeedingURL = @"https://third.example";

	NSString *broadcast = [self awaitBroadcastWhileRunning:^{
		[self.extension openAboutURLStrings:@[@"https://first.example",
											  @"https://second.example",
											  @"https://third.example"]];
	}];

	XCTAssertEqualObjects(self.extension.attemptedURLs, (@[@"https://first.example",
														   @"https://second.example",
														   @"https://third.example"]),
						  @"each failure advances to the next URL");
	XCTAssertEqualObjects(broadcast, @"https://third.example");
}

/*! @abstract A chain in which every URL fails is exhausted and broadcasts nothing. */
- (void)testAChainThatFailsThroughoutBroadcastsNothing
{
	self.extension.succeedingURL = nil;

	__block NSUInteger broadcasts = 0;
	id token = [self.effect.notifier addObserverForName:FxGripAboutMenuLinkName object:nil queue:nil
											 usingBlock:^(NSNotification *note) { broadcasts += 1; }];
	[self.extension openAboutURLStrings:@[@"https://first.example", @"https://second.example"]];
	[self.effect.notifier removeObserver:token];

	XCTAssertEqualObjects(self.extension.attemptedURLs, (@[@"https://first.example", @"https://second.example"]));
	XCTAssertEqual(broadcasts, (NSUInteger)0, @"an exhausted chain reports no opened link");
}

/*! @abstract Empty strings and non-string entries are dropped, and a chain with nothing usable opens nothing. */
- (void)testAnUnusableURLListOpensNothing
{
	[self.extension openAboutURLStrings:(NSArray<NSString *> *)(@[@"", @42, [NSNull null]])];

	XCTAssertEqualObjects(self.extension.attemptedURLs, @[]);
}

/*! @abstract An index past the end of the queue opens nothing. */
- (void)testAnIndexPastTheEndOfTheQueueOpensNothing
{
	[self.extension openURLQueue:@[[NSURL URLWithString:@"https://only.example"]] atIndex:1];

	XCTAssertEqualObjects(self.extension.attemptedURLs, @[]);
}

/*! @abstract The link broadcast carries the opened URL string under the link URL key. */
- (void)testTheLinkBroadcastCarriesTheOpenedURL
{
	NSString *broadcast = [self awaitBroadcastWhileRunning:^{
		[self.extension broadcastAboutLink:[NSURL URLWithString:@"https://broadcast.example"]];
	}];

	XCTAssertEqualObjects(broadcast, @"https://broadcast.example");
}

#pragma mark The warning dialog

/*! @abstract The About dialog presents one alert carrying the warning text and an OK button. */
- (void)testTheAboutDialogPresentsTheWarningText
{
	[self.extension showAboutDialogWithText:@"You must accept the agreement."];

	XCTAssertEqual(self.extension.presentedAlerts.count, (NSUInteger)1);
	NSAlert *alert = self.extension.presentedAlerts.firstObject;
	XCTAssertEqualObjects(alert.informativeText, @"You must accept the agreement.");
	XCTAssertEqual(alert.buttons.count, (NSUInteger)1);
}

/*! @abstract An absent warning text presents an alert with empty informative text. */
- (void)testTheAboutDialogPresentsAnEmptyInformativeTextWithoutAWarning
{
	[self.extension showAboutDialogWithText:nil];

	XCTAssertEqual(self.extension.presentedAlerts.count, (NSUInteger)1);
	XCTAssertEqualObjects(self.extension.presentedAlerts.firstObject.informativeText, @"");
}

#pragma mark Layout guards

- (NSArray<NSString *> *)liveItems
{
	return [self.extension aboutMenuItemsReadingValues:YES atTime:FxGripAboutLinkTestZeroTime()];
}

/*! @abstract A configuration that is not a dictionary yields an empty menu. */
- (void)testANonDictionaryConfigurationYieldsAnEmptyMenu
{
	self.effect.aboutMenuConfiguration = @[@"not a configuration"];

	XCTAssertEqualObjects([self liveItems], @[]);
}

/*! @abstract Entries that are not an array of dictionaries are dropped from the menu. */
- (void)testNonDictionaryEntriesAreDropped
{
	self.effect.aboutMenuConfiguration = @{FxGripAboutMenuItemsKey: @"not an array"};
	XCTAssertEqualObjects([self liveItems], @[], @"a non-array items value contributes nothing");

	self.effect.aboutMenuConfiguration = @{FxGripAboutMenuItemsKey: @[@"not a dictionary",
																	  @{FxGripAboutEntryLabelKey: @"Kept",
																		FxGripAboutEntryKindKey: FxGripAboutEntryKindText}]};
	XCTAssertEqualObjects([self liveItems], (@[@"Kept"]));
}

/*! @abstract An entry the subclass hook injects that is not a dictionary is skipped. */
- (void)testANonDictionaryInjectedEntryIsSkipped
{
	self.effect.aboutMenuConfiguration = @{FxGripAboutMenuItemsKey: @[@{FxGripAboutEntryLabelKey: @"Configured",
																		FxGripAboutEntryKindKey: FxGripAboutEntryKindText}]};
	self.effect.injectedItems = (NSArray<NSDictionary *> *)(@[@"not a dictionary"]);

	XCTAssertEqualObjects([self liveItems], (@[@"Configured"]));
}

/*! @abstract The text, separator, and dialog entry kinds each render their own row. */
- (void)testEachEntryKindRendersItsOwnRow
{
	self.effect.aboutMenuConfiguration = @{FxGripAboutMenuMainTextKey: @"Main",
										   FxGripAboutMenuItemsKey: @[
											   @{FxGripAboutEntryKindKey: FxGripAboutEntryKindSeparator},
											   @{FxGripAboutEntryLabelKey: @"Plain",
												 FxGripAboutEntryKindKey: FxGripAboutEntryKindText},
											   @{FxGripAboutEntryLabelKey: @"Warn",
												 FxGripAboutEntryKindKey: FxGripAboutEntryKindDialog}]};

	XCTAssertEqualObjects([self liveItems], (@[@"Main", @"-", @"Plain", @"Warn"]));
}

/*! @abstract An agreement gate that is not a parameter ID, or whose read fails, is treated as accepted. */
- (void)testAnUnreadableAgreementGateIsTreatedAsAccepted
{
	NSDictionary *warned = @{FxGripAboutMenuWarningKey: @[@"Accept first"],
							 FxGripAboutMenuAgreementIdKey: @"not a parameter id",
							 FxGripAboutMenuItemsKey: @[]};
	self.effect.aboutMenuConfiguration = warned;
	XCTAssertEqualObjects([self liveItems], @[], @"a gate that names no parameter cannot withhold the menu");

	self.effect.aboutMenuConfiguration = @{FxGripAboutMenuWarningKey: @[@"Accept first"],
										   FxGripAboutMenuAgreementIdKey: @600,
										   FxGripAboutMenuItemsKey: @[]};
	self.effect.apiManager.paramGetAPIv6.intReadSucceeds = NO;
	XCTAssertEqualObjects([self liveItems], @[],
						  @"a failed host read leaves the plugin's own menu reachable");
}

/*! @abstract An entry display gate whose read fails leaves the entry shown. */
- (void)testAnUnreadableEntryDisplayGateLeavesTheEntryShown
{
	self.effect.aboutMenuConfiguration = @{FxGripAboutMenuItemsKey: @[
		@{FxGripAboutEntryLabelKey: @"Gated",
		  FxGripAboutEntryKindKey: FxGripAboutEntryKindText,
		  FxGripAboutEntryDisplayIdKey: @500}]};
	self.effect.apiManager.paramGetAPIv6.boolReadSucceeds = NO;

	XCTAssertEqualObjects([self liveItems], (@[@"Gated"]));
}

/*! @abstract A selection past the end of the menu is handled without acting on a row. */
- (void)testASelectionPastTheEndOfTheMenuActsOnNothing
{
	self.effect.aboutMenuConfiguration = @{FxGripAboutMenuItemsKey: @[
		@{FxGripAboutEntryLabelKey: @"Help", FxGripAboutEntryUrlKey: @"https://help.example"}]};
	self.effect.apiManager.paramGetAPIv6.intReadSucceeds = YES;
	self.effect.apiManager.paramGetAPIv6.intValue = 99;

	BOOL handled = [self.extension manageAboutMenu:kFxParameterId_AboutMenu
											atTime:FxGripAboutLinkTestZeroTime()
											 error:NULL];
	XCTAssertTrue(handled);
	XCTAssertEqualObjects(self.extension.attemptedURLs, @[]);
	XCTAssertEqual(self.extension.presentedAlerts.count, (NSUInteger)0);
}

/*! @abstract A configuration with no name registers the popup under the default name. */
- (void)testAConfigurationWithoutANameUsesTheDefaultName
{
	self.effect.aboutMenuConfiguration = @{FxGripAboutMenuItemsKey: @[]};

	NSMutableArray<NSMutableDictionary *> *parameters = NSMutableArray.new;
	[self.extension extAddParameters:[NSNotification notificationWithName:FxGripTileableEffectAddParametersName
																   object:self.effect
																 userInfo:@{FxGripTileableEffectParametersKey: parameters}]];

	XCTAssertEqual(parameters.count, (NSUInteger)1);
	XCTAssertEqualObjects(parameters.firstObject[kFxParameterProperty_Name], @"FxGrip::AboutMenu::Name");
}

/*! @abstract A gating change carrying a time dictionary rebuilds the menu at that time. */
- (void)testAGatingChangeCarryingATimeRebuildsTheMenu
{
	self.effect.aboutMenuConfiguration = @{FxGripAboutMenuAgreementIdKey: @600,
										   FxGripAboutMenuItemsKey: @[]};
	CMTime time = (CMTime){.value = 5, .timescale = 30, .flags = kCMTimeFlags_Valid, .epoch = 0};
	NSDictionary *timeDictionary = (__bridge_transfer NSDictionary *)CMTimeCopyAsDictionary(time, kCFAllocatorDefault);

	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
														object:self.effect
													  userInfo:@{FxGripTileableEffectParameterChangedIDKey: @600,
																 FxGripTileableEffectParameterChangedAtTimeKey: timeDictionary}];

	XCTAssertNoThrow([self.extension extParameterChanged:note]);
}

#pragma mark The effect-side accessors

/*! @abstract An effect that resolves an About menu configuration installs the extension and resolves it. */
- (void)testAnEffectWithAnAboutConfigurationInstallsAndResolvesTheExtension
{
	FxGripAboutLinkHostEffect *effect = [FxGripAboutLinkHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];

	XCTAssertTrue(effect.hasAboutMenu);
	XCTAssertNotNil(effect.aboutMenu);
	XCTAssertEqual((id)effect.aboutMenu, (id)[effect extensionForClass:FxGripAboutMenu.class]);
	XCTAssertTrue([[effect newAboutMenuExtension] isKindOfClass:FxGripAboutMenu.class]);
}

/*! @abstract The default item hook returns the configured entries unchanged, and a subclass extends them. */
- (void)testTheItemHookPassesEntriesThroughAndASubclassExtendsThem
{
	FxGripAboutLinkHostEffect *plain = [FxGripAboutLinkHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	NSArray<NSDictionary *> *items = @[@{FxGripAboutEntryLabelKey: @"Help"}];

	XCTAssertEqualObjects([plain aboutMenuItems:items], items, @"the default hook is a pass-through");

	FxGripAboutLinkHookEffect *hooked = [FxGripAboutLinkHookEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	NSArray<NSDictionary *> *extended = [hooked aboutMenuItems:items];

	XCTAssertEqual(extended.count, (NSUInteger)2);
	XCTAssertEqualObjects(extended.lastObject[FxGripAboutEntryLabelKey], @"Extra");
}

@end
