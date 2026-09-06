/*!
	@file       FxGripDebugMenuTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDebugMenuTests
	@abstract   Unit tests for the host-facing FxGripDebugMenu, FxGripAboutMenu, and FxGripRegression extensions.
	@discussion Introduced in FxGrip 0.1.0. Stub host API objects stand in for the dynamic-parameter, get, and set APIs so the extensions run without an FxPlug host. The tests cover FxGripDebugMenu parameter registration, the debug-mode flag translation, the menu contents and menu-command handling, and the activator reveal. They cover the FxGripAboutMenu registration, live layout gating, selection, and refresh, and the FxGripRegression plugin-property validation pass.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripDebugMenu.h>
#import <FxGrip/FxGripAboutMenu.h>
#import <FxGrip/FxGripRegression.h>

// Displayed menu positions with an activator present, mirroring debugMenuLayout: in
// FxGripDebugMenu.m. Dispatch resolves the position through the layout, so these track the
// row order rather than a private command enum.
typedef NS_ENUM(NSUInteger, FxGripDebugTestMenuItem) {
	FxGripDebugTestItem_Main = 0,
	FxGripDebugTestItem_ToggleUnhide = 2,
	FxGripDebugTestItem_ToggleShow = 3,
	FxGripDebugTestItem_ToggleAll = 4,
	FxGripDebugTestItem_ToggleMenu = 6,
	FxGripDebugTestItem_RemoveDebug = 8,
};

// FxGripDebugMenu.h and FxGripAboutMenu.h publish the classes without their members, so
// the members the tests drive are declared here. The implementations come from the
// linked framework.
@interface FxGripDebugMenu (FxGripDebugMenuTestAccess)
@property (readonly) BOOL hasDebugMenu;
@property (readonly) BOOL hasDebugActivator;
@property (readonly) BOOL isDebugUnhiding;
- (int)extPostProcessPriority;
- (void)extAddParameters:(nonnull NSNotification *)notification;
- (void)extAPIParameterGetFlags:(nonnull NSNotification *)notification;
- (void)extAPIParameterSetFlagsPre:(nonnull NSNotification *)notification;
- (void)extParameterChanged:(nonnull NSNotification *)notification;
- (BOOL)setDebugMenuShown:(BOOL)show atTime:(CMTime)time;
- (BOOL)debugUnhide:(BOOL)active;
- (BOOL)manageDebuggerController:(FxParameterId)parameterID
						  atTime:(CMTime)time
						   error:(NSError * _Nullable * _Nullable)error;
- (NSArray<NSString *> * _Nonnull)debugMenuItems:(BOOL)unhide;
@end

@interface FxGripAboutMenu (FxGripAboutMenuTestAccess)
- (BOOL)hasAboutMenu;
- (void)extAddParameters:(nonnull NSNotification *)notification;
- (void)extParameterChanged:(nonnull NSNotification *)notification;
- (NSArray<NSString *> * _Nonnull)aboutMenuItemsReadingValues:(BOOL)readValues atTime:(CMTime)time;
- (BOOL)manageAboutMenu:(FxParameterId)parameterID atTime:(CMTime)time error:(NSError * _Nullable * _Nullable)error;
- (void)openAboutURLStrings:(nonnull NSArray<NSString *> *)urlStrings;
- (void)showAboutDialogWithText:(nullable NSString *)text;
- (NSSet<NSNumber *> * _Nonnull)aboutMenuGatingParameterIDs;
- (void)refreshAboutMenuAtTime:(CMTime)time;
@end

static NSNotificationCenter *FxGripDebugTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

static CMTime FxGripDebugTestZeroTime(void)
{
	return (CMTime){.value = 0, .timescale = 1, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

/*! A dictionary the NSDictionary(FxGripTileableEffect) plugin accessors accept. */
static NSMutableDictionary *FxGripDebugTestPluginProperties(BOOL debugMenu, BOOL debugActivator)
{
	return @{
		kProPlugPlugIn_UuidProperty: @"33333333-3333-3333-3333-333333333333",
		kProPlugPlugIn_ClassNameProperty: @"FxGripDebugTestPlugin",
		kProPlugPlugIn_GroupUUIDProperty: @"44444444-4444-4444-4444-444444444444",
		kProPlugPlugIn_DisplayNameProperty: @"Debug Test Plugin",
		kProPlugPlugIn_VersionProperty: @3,
		kProPlugPlugInX_DebugMenuProperty: @(debugMenu),
		kProPlugPlugInX_DebugActivatorProperty: @(debugActivator)
	}.mutableCopy;
}

#pragma mark - Host API doubles

@interface FxGripDebugTestStubDynamicAPI : NSObject
@property (nonatomic, strong) NSArray<NSNumber *> *parameterIDList;
@property (nonatomic, strong) NSArray *menuEntries;
@property (nonatomic, assign) FxParameterId menuParameter;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *removedParameters;
@property (nonatomic, strong) NSError *removeError;
@end

@implementation FxGripDebugTestStubDynamicAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_parameterIDList = @[];
		_removedParameters = NSMutableArray.new;
	}
	return self;
}

- (UInt32)parameterCount
{
	return (UInt32)self.parameterIDList.count;
}

- (FxParameterId)parameterIDAtIndex:(UInt32)index
{
	return self.parameterIDList[index].unsignedIntValue;
}

- (BOOL)setPopupMenuParameter:(UInt32)parameterID
					  entries:(NSArray *)entries
				 defaultValue:(UInt32)defaultValue
{
	self.menuParameter = parameterID;
	self.menuEntries = entries;
	return YES;
}

- (NSError *)removeParameter:(UInt32)parameterID
{
	[self.removedParameters addObject:@(parameterID)];
	return self.removeError;
}

@end

@interface FxGripDebugTestStubGetAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *flags;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *intValues;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *boolValues;
@property (nonatomic, assign) BOOL flagsReadSucceeds;
@property (nonatomic, assign) BOOL intReadSucceeds;
@property (nonatomic, assign) BOOL boolReadSucceeds;
@end

@implementation FxGripDebugTestStubGetAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_flags = NSMutableDictionary.new;
		_intValues = NSMutableDictionary.new;
		_boolValues = NSMutableDictionary.new;
		_flagsReadSucceeds = YES;
		_intReadSucceeds = YES;
		_boolReadSucceeds = YES;
	}
	return self;
}

- (BOOL)getParameterFlags:(FxParameterFlags *)flags fromParameter:(UInt32)parameterID
{
	if (!self.flagsReadSucceeds) {
		return NO;
	}
	*flags = self.flags[@(parameterID)].unsignedIntValue;
	return YES;
}

- (BOOL)getIntValue:(int *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (!self.intReadSucceeds) {
		return NO;
	}
	*value = self.intValues[@(parameterID)].intValue;
	return YES;
}

- (BOOL)getBoolValue:(BOOL *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (!self.boolReadSucceeds) {
		return NO;
	}
	*value = self.boolValues[@(parameterID)].boolValue;
	return YES;
}

@end

@interface FxGripDebugTestStubSetAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *flags;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *boolValues;
@property (nonatomic, assign) BOOL writeSucceeds;
@end

@implementation FxGripDebugTestStubSetAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_flags = NSMutableDictionary.new;
		_boolValues = NSMutableDictionary.new;
		_writeSucceeds = YES;
	}
	return self;
}

- (BOOL)setParameterFlags:(FxParameterFlags)flags toParameter:(UInt32)parameterID
{
	self.flags[@(parameterID)] = @(flags);
	return self.writeSucceeds;
}

- (BOOL)setBoolValue:(BOOL)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.boolValues[@(parameterID)] = @(value);
	return self.writeSucceeds;
}

@end

@interface FxGripDebugTestStubAPIManager : NSObject
@property (nonatomic, strong) FxGripDebugTestStubDynamicAPI *dynamicParamAPIv3;
@property (nonatomic, strong) FxGripDebugTestStubGetAPI *paramGetAPIv6;
@property (nonatomic, strong) FxGripDebugTestStubSetAPI *paramSetAPIv5;
@property (nonatomic, strong) FxGripDebugTestStubSetAPI *paramSetAPIv6;
@end

@implementation FxGripDebugTestStubAPIManager
@end

// FxGripTileableEffect's designated initializer registers into the process-wide
// notification center, so the extensions run against a stub exposing the members they read.
@interface FxGripDebugTestStubEffect : NSObject
@property (nonatomic, assign) BOOL addedToDocument;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, strong) FxGripDebugTestStubAPIManager *apiManager;
@property (nonatomic, strong) NSDictionary<NSString *, id> *pluginProperties;
@property (nonatomic, copy) NSString *pluginUUID;
// The About menu configuration the extension reads through the effect seam.
@property (nonatomic, strong) NSDictionary *aboutConfig;
@end

@implementation FxGripDebugTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

// The debug gate seam the extension routes through. Defaults mirror the framework category:
// the Info.plist keys reach the bools through the master gate.
- (BOOL)allowsDebugFeatures
{
	return YES;
}

- (BOOL)pluginDebugMenuEnabled
{
	return self.allowsDebugFeatures && [self.pluginProperties[kProPlugPlugInX_DebugMenuProperty] boolValue];
}

- (BOOL)pluginDebugActivatorEnabled
{
	return self.allowsDebugFeatures && [self.pluginProperties[kProPlugPlugInX_DebugActivatorProperty] boolValue];
}

- (BOOL)hasDebugMenu
{
	return self.pluginDebugMenuEnabled || self.pluginDebugActivatorEnabled;
}

// The About gate seam the extension routes through.
- (NSDictionary *)aboutMenuConfiguration
{
	return self.aboutConfig;
}

- (BOOL)hasAboutMenu
{
	return self.aboutConfig != nil;
}

- (NSArray<NSDictionary *> *)aboutMenuItems:(NSArray<NSDictionary *> *)items
{
	return items;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxGripDebugTestMakePriorityCenter();
		_apiManager = FxGripDebugTestStubAPIManager.new;
		_apiManager.dynamicParamAPIv3 = FxGripDebugTestStubDynamicAPI.new;
		_apiManager.paramGetAPIv6 = FxGripDebugTestStubGetAPI.new;
		_apiManager.paramSetAPIv5 = FxGripDebugTestStubSetAPI.new;
		_apiManager.paramSetAPIv6 = FxGripDebugTestStubSetAPI.new;
		_pluginProperties = FxGripDebugTestPluginProperties(YES, YES);
		_pluginUUID = @"33333333-3333-3333-3333-333333333333";
	}
	return self;
}

@end

// A plugin that blocks debug features in compiled code even though its Info.plist asks for them.
@interface FxGripDebugTestBlockedEffect : FxGripDebugTestStubEffect
@end

@implementation FxGripDebugTestBlockedEffect

- (BOOL)allowsDebugFeatures
{
	return NO;
}

@end

#pragma mark - Debug menu tests

@interface FxGripDebugMenuTests : XCTestCase
@property (nonatomic, strong) FxGripDebugMenu *extension;
@property (nonatomic, strong) FxGripDebugTestStubEffect *effect;
@end

@implementation FxGripDebugMenuTests

- (void)setUp
{
	[super setUp];
	self.extension = [FxGripDebugMenu.alloc init];
	self.effect = [FxGripDebugTestStubEffect.alloc init];
	[self.extension extLoadWithEffect:(id)self.effect];
}

- (void)tearDown
{
	self.extension = nil;
	self.effect = nil;
	[super tearDown];
}

- (void)setDebugMenu:(BOOL)debugMenu activator:(BOOL)activator
{
	self.effect.pluginProperties = FxGripDebugTestPluginProperties(debugMenu, activator);
}

- (FxGripDebugTestStubDynamicAPI *)dynamicAPI { return self.effect.apiManager.dynamicParamAPIv3; }
- (FxGripDebugTestStubGetAPI *)getAPI { return self.effect.apiManager.paramGetAPIv6; }
- (FxGripDebugTestStubSetAPI *)setAPIv5 { return self.effect.apiManager.paramSetAPIv5; }
- (FxGripDebugTestStubSetAPI *)setAPIv6 { return self.effect.apiManager.paramSetAPIv6; }

- (BOOL)selectMenuItem:(NSUInteger)selection
{
	self.getAPI.intValues[@(kFxParameterId_DebugMenu)] = @(selection);
	NSError *error = nil;
	return [self.extension manageDebuggerController:kFxParameterId_DebugMenu
											 atTime:FxGripDebugTestZeroTime()
											  error:&error];
}

// The displayed position of a labeled row in the current menu layout, so a test names the row
// it drives instead of hard-coding an index the layout can shift.
- (NSUInteger)menuIndexForLabel:(NSString *)label
{
	NSUInteger index = [[self.extension debugMenuItems:NO] indexOfObject:label];
	XCTAssertNotEqual(index, (NSUInteger)NSNotFound, @"menu row %@ is missing", label);
	return index;
}

- (void)postParameterChangedForID:(FxParameterId)parameterID
{
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
														object:self.effect
													  userInfo:@{FxGripTileableEffectParameterChangedIDKey: @(parameterID)}];
	[self.extension extParameterChanged:note];
}

// The add-parameters handler reads its list from the notification's FxGripEffectParameters entry.
- (NSMutableArray *)runAddParameters
{
	NSMutableArray *parameters = NSMutableArray.new;
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectAddParametersName
														object:self.effect
													  userInfo:@{FxGripTileableEffectParametersKey: parameters}];
	[self.extension extAddParameters:note];
	return parameters;
}

// The flags handlers read and rewrite the flags in the nested parameter dictionary.
- (FxParameterFlags)runFlagsHandler:(SEL)handler onFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *parameter = [@{kFxParameterProperty_Id: @12,
										kFxParameterProperty_Flags: @(flags)} mutableCopy];
	NSNotification *note = [NSNotification notificationWithName:@"flags"
														object:self.effect
													  userInfo:@{FxGripNotifyAPI_ParameterKey: parameter}];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[self.extension performSelector:handler withObject:note];
#pragma clang diagnostic pop
	return ((NSNumber *)parameter[kFxParameterProperty_Flags]).unsignedIntValue;
}

#pragma mark Registration

/*! @abstract The extension uses the shared debug-menu key and runs at post-process priority 19. */
- (void)testTheExtensionUsesTheSharedDebugMenuKeyAndRunsLast
{
	XCTAssertEqualObjects(self.extension.extKey, FxGripDebugMenuExtensionKey);
	XCTAssertEqualObjects(self.extension.extKey, @"FxGripDebugMenu");
	XCTAssertEqual([self.extension extPostProcessPriority], 19);
}

/*! @abstract The debug menu is offered when either the debug-menu or the activator plugin property is set, and the activator implies the menu. */
- (void)testTheDebugMenuIsOfferedWhenEitherPluginPropertyAsksForIt
{
	[self setDebugMenu:NO activator:NO];
	XCTAssertFalse(self.extension.hasDebugMenu);
	XCTAssertFalse(self.extension.hasDebugActivator);

	[self setDebugMenu:YES activator:NO];
	XCTAssertTrue(self.extension.hasDebugMenu);
	XCTAssertFalse(self.extension.hasDebugActivator);

	[self setDebugMenu:NO activator:YES];
	XCTAssertTrue(self.extension.hasDebugMenu, @"the activator implies the menu");
	XCTAssertTrue(self.extension.hasDebugActivator);
}

/*! @abstract Adding parameters with an activator registers both the activator toggle and the hidden debug menu with the expected type, factory, and flags. */
- (void)testProcessParametersRegistersTheActivatorAndTheMenu
{
	[self setDebugMenu:YES activator:YES];

	NSMutableArray *parameters = [self runAddParameters];

	XCTAssertEqual(parameters.count, (NSUInteger)2);

	NSDictionary *activator = parameters[0];
	XCTAssertEqualObjects(activator[kFxParameterProperty_Id], @(kFxParameterId_DebugActivator));
	XCTAssertEqualObjects(activator[kFxParameterProperty_Type], kFxParameterType_Toggle);
	XCTAssertEqualObjects(activator[kFxParameterProperty_Default], @(NO));
	XCTAssertEqual([activator[kFxParameterProperty_TargetPreset] count], (NSUInteger)2,
				   @"the activator carries an on and an off target preset");

	NSDictionary *menu = parameters[1];
	XCTAssertEqualObjects(menu[kFxParameterProperty_Id], @(kFxParameterId_DebugMenu));
	XCTAssertEqualObjects(menu[kFxParameterProperty_Type], kFxParameterType_Menu);
	XCTAssertEqualObjects(menu[kFxParameterProperty_Factory], self.extension);
	XCTAssertEqualObjects(menu[kFxParameterProperty_Selector], @"manageDebuggerController");
	XCTAssertEqualObjects(menu[kFxParameterProperty_MenuItems], [self.extension debugMenuItems:NO]);

	NSArray *flags = menu[kFxParameterProperty_Flags];
	XCTAssertTrue([flags containsObject:kParameterFlagString_NOT_ANIMATABLE]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_DONT_DISPLAY]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_HIDDEN],
				  @"the activator owns the menu's visibility");
}

/*! @abstract Adding parameters without an activator registers only the visible debug menu, with no hidden flag. */
- (void)testProcessParametersRegistersOnlyTheVisibleMenuWithoutAnActivator
{
	[self setDebugMenu:YES activator:NO];

	NSMutableArray *parameters = [self runAddParameters];

	XCTAssertEqual(parameters.count, (NSUInteger)1);
	XCTAssertEqualObjects(parameters[0][kFxParameterProperty_Id], @(kFxParameterId_DebugMenu));
	XCTAssertFalse([parameters[0][kFxParameterProperty_Flags] containsObject:kParameterFlagString_HIDDEN]);
}

/*! @abstract Adding parameters registers nothing when no debug menu is enabled. */
- (void)testProcessParametersRegistersNothingWithoutADebugMenu
{
	[self setDebugMenu:NO activator:NO];

	NSMutableArray *parameters = [self runAddParameters];

	XCTAssertEqual(parameters.count, (NSUInteger)0);
}

#pragma mark Menu Contents

/*! @abstract The menu lists the debug toggle and toggle-all rows only when an activator is present, and each labeled row sits at its expected position. */
- (void)testTheMenuListsTheDebugToggleOnlyWithAnActivator
{
	[self setDebugMenu:YES activator:YES];
	NSArray<NSString *> *withActivator = [self.extension debugMenuItems:NO];

	[self setDebugMenu:YES activator:NO];
	NSArray<NSString *> *withoutActivator = [self.extension debugMenuItems:NO];

	XCTAssertEqual(withActivator.count, withoutActivator.count + 2,
				   @"the activator adds both its visibility toggle and Toggle All Debug");
	XCTAssertTrue([withActivator containsObject:@"FxGrip::DebugMenu::ToggleDebugToggle"]);
	XCTAssertTrue([withActivator containsObject:@"FxGrip::DebugMenu::ToggleAllDebug"]);
	XCTAssertFalse([withoutActivator containsObject:@"FxGrip::DebugMenu::ToggleDebugToggle"]);
	XCTAssertFalse([withoutActivator containsObject:@"FxGrip::DebugMenu::ToggleAllDebug"]);
	XCTAssertEqualObjects(withActivator.firstObject, @"FxGrip::DebugMenu::MainItem");
	XCTAssertEqualObjects(withActivator[FxGripDebugTestItem_ToggleUnhide], @"FxGrip::DebugMenu::ToggleUnhideOff");
	XCTAssertEqualObjects(withActivator[FxGripDebugTestItem_ToggleShow], @"FxGrip::DebugMenu::ToggleDebugToggle");
	XCTAssertEqualObjects(withActivator[FxGripDebugTestItem_ToggleAll], @"FxGrip::DebugMenu::ToggleAllDebug");
	XCTAssertEqualObjects(withActivator[FxGripDebugTestItem_ToggleMenu], @"FxGrip::DebugMenu::ToggleDebugMenu");
	XCTAssertEqualObjects(withActivator[FxGripDebugTestItem_RemoveDebug], @"FxGrip::DebugMenu::RemoveDebugMenu");
}

/*! @abstract The unhide row names the state it switches to, on when currently unhiding and off otherwise. */
- (void)testTheUnhideItemNamesTheStateItSwitchesTo
{
	XCTAssertEqualObjects([self.extension debugMenuItems:YES][FxGripDebugTestItem_ToggleUnhide],
						  @"FxGrip::DebugMenu::ToggleUnhideOn");
	XCTAssertEqualObjects([self.extension debugMenuItems:NO][FxGripDebugTestItem_ToggleUnhide],
						  @"FxGrip::DebugMenu::ToggleUnhideOff");
}

#pragma mark Debug Mode Flag Translation

/*! @abstract Reading flags in debug mode clears the hidden bit and restores a hidden-proxy bit to a real hidden bit. */
- (void)testReadingFlagsInDebugModeShowsHiddenParametersAndRestoresTheProxy
{
	FxParameterFlags shown = [self runFlagsHandler:@selector(extAPIParameterGetFlags:)
										   onFlags:kFxParameterFlag_IN_DEBUG_MODE | kFxParameterFlag_HIDDEN];
	XCTAssertEqual(shown & kFxParameterFlag_HIDDEN, (FxParameterFlags)0,
				   @"a hidden parameter is shown while debugging");

	FxParameterFlags proxied = [self runFlagsHandler:@selector(extAPIParameterGetFlags:)
											 onFlags:kFxParameterFlag_IN_DEBUG_MODE | kFxParameterFlag_HIDDEN_PROXY];
	XCTAssertTrue((proxied & kFxParameterFlag_HIDDEN) != 0);
	XCTAssertEqual(proxied & kFxParameterFlag_HIDDEN_PROXY, (FxParameterFlags)0);
}

/*! @abstract Reading flags outside debug mode leaves them unchanged. */
- (void)testReadingFlagsOutsideDebugModeLeavesThemAlone
{
	FxParameterFlags flags = [self runFlagsHandler:@selector(extAPIParameterGetFlags:)
										   onFlags:kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED];

	XCTAssertEqual(flags, (FxParameterFlags)(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED));
}

/*! @abstract Writing flags in debug mode parks the hidden bit in the hidden-proxy bit. */
- (void)testWritingFlagsInDebugModeParksTheHiddenBitInTheProxy
{
	FxParameterFlags flags = [self runFlagsHandler:@selector(extAPIParameterSetFlagsPre:)
										   onFlags:kFxParameterFlag_IN_DEBUG_MODE | kFxParameterFlag_HIDDEN];

	XCTAssertEqual(flags & kFxParameterFlag_HIDDEN, (FxParameterFlags)0);
	XCTAssertTrue((flags & kFxParameterFlag_HIDDEN_PROXY) != 0);
}

/*! @abstract Writing flags in debug mode clears a stale hidden-proxy bit without setting the hidden bit. */
- (void)testWritingFlagsInDebugModeClearsAStaleProxy
{
	FxParameterFlags flags = [self runFlagsHandler:@selector(extAPIParameterSetFlagsPre:)
										   onFlags:kFxParameterFlag_IN_DEBUG_MODE | kFxParameterFlag_HIDDEN_PROXY];

	XCTAssertEqual(flags & kFxParameterFlag_HIDDEN_PROXY, (FxParameterFlags)0);
	XCTAssertEqual(flags & kFxParameterFlag_HIDDEN, (FxParameterFlags)0);
}

/*! @abstract Writing flags outside debug mode leaves them unchanged. */
- (void)testWritingFlagsOutsideDebugModeLeavesThemAlone
{
	FxParameterFlags flags = [self runFlagsHandler:@selector(extAPIParameterSetFlagsPre:)
										   onFlags:kFxParameterFlag_HIDDEN];

	XCTAssertEqual(flags, (FxParameterFlags)kFxParameterFlag_HIDDEN);
}

#pragma mark Unhiding

/*! @abstract Unhiding sets the debug-mode bit on every parameter except those flagged no-debug and refreshes the menu entries. */
- (void)testUnhidingMarksEveryParameterExceptTheOnesOptedOut
{
	self.dynamicAPI.parameterIDList = @[@1, @2, @3];
	self.getAPI.flags[@2] = @(kFxParameterFlag_NO_DEBUG);

	XCTAssertTrue([self.extension debugUnhide:YES]);

	XCTAssertEqualObjects(self.setAPIv5.flags[@1], @(kFxParameterFlag_IN_DEBUG_MODE));
	XCTAssertNil(self.setAPIv5.flags[@2], @"a parameter flagged NO_DEBUG is left alone");
	XCTAssertEqualObjects(self.setAPIv5.flags[@3], @(kFxParameterFlag_IN_DEBUG_MODE));
	XCTAssertEqual(self.dynamicAPI.menuParameter, (FxParameterId)kFxParameterId_DebugMenu);
	XCTAssertEqualObjects(self.dynamicAPI.menuEntries, [self.extension debugMenuItems:YES]);
}

/*! @abstract Ending the unhide clears the debug-mode bit and refreshes the menu entries to the non-unhide list. */
- (void)testEndingTheUnhideClearsTheDebugModeBit
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.getAPI.flags[@1] = @(kFxParameterFlag_IN_DEBUG_MODE | kFxParameterFlag_HIDDEN);

	XCTAssertTrue([self.extension debugUnhide:NO]);

	XCTAssertEqualObjects(self.setAPIv5.flags[@1], @(kFxParameterFlag_HIDDEN));
	XCTAssertEqualObjects(self.dynamicAPI.menuEntries, [self.extension debugMenuItems:NO]);
}

/*! @abstract Unhiding writes nothing for a parameter already in the wanted debug-mode state. */
- (void)testUnhidingLeavesParametersThatAreAlreadyInTheWantedStateUntouched
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.getAPI.flags[@1] = @(kFxParameterFlag_IN_DEBUG_MODE);

	XCTAssertTrue([self.extension debugUnhide:YES]);

	XCTAssertNil(self.setAPIv5.flags[@1]);
}

/*! @abstract Unhiding stops and refreshes nothing when the host refuses to report flags. */
- (void)testUnhidingStopsWhenTheHostRefusesToReportFlags
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.getAPI.flagsReadSucceeds = NO;

	XCTAssertFalse([self.extension debugUnhide:YES]);
	XCTAssertNil(self.dynamicAPI.menuEntries);
}

/*! @abstract Unhiding stops when the host refuses the flag write. */
- (void)testUnhidingStopsWhenTheHostRefusesTheFlagWrite
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.setAPIv5.writeSucceeds = NO;

	XCTAssertFalse([self.extension debugUnhide:YES]);
}

/*! @abstract isDebugUnhiding reads the debug-unhide bit from the menu parameter flags and is false when the read fails. */
- (void)testTheUnhideStateIsReadFromTheMenuParameterFlags
{
	XCTAssertFalse(self.extension.isDebugUnhiding);

	self.getAPI.flags[@(kFxParameterId_DebugMenu)] = @(kFxParameterFlag_DEBUG_UNHIDE);
	XCTAssertTrue(self.extension.isDebugUnhiding);

	self.getAPI.flagsReadSucceeds = NO;
	XCTAssertFalse(self.extension.isDebugUnhiding);
}

#pragma mark Menu Commands

/*! @abstract Selecting the main menu item performs no flag writes or parameter removals. */
- (void)testSelectingTheMainItemDoesNothing
{
	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_Main]);

	XCTAssertEqual(self.setAPIv5.flags.count, (NSUInteger)0);
	XCTAssertEqual(self.dynamicAPI.removedParameters.count, (NSUInteger)0);
}

/*! @abstract A debug menu command fails when the selected menu index cannot be read. */
- (void)testAMenuCommandStopsWhenTheSelectionCannotBeRead
{
	self.getAPI.intReadSucceeds = NO;

	NSError *error = nil;
	XCTAssertFalse([self.extension manageDebuggerController:kFxParameterId_DebugMenu
													 atTime:FxGripDebugTestZeroTime()
													  error:&error]);
}

/*! @abstract Selecting the unhide item turns debug mode on for the parameters. */
- (void)testSelectingTheUnhideItemTurnsDebugModeOn
{
	self.dynamicAPI.parameterIDList = @[@1];

	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_ToggleUnhide]);

	XCTAssertEqualObjects(self.setAPIv5.flags[@1], @(kFxParameterFlag_IN_DEBUG_MODE));
}

/*! @abstract Selecting the unhide item fails when the unhide pass cannot read flags. */
- (void)testSelectingTheUnhideItemStopsWhenTheUnhidePassFails
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.getAPI.flagsReadSucceeds = NO;

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_ToggleUnhide]);
}

/*! @abstract Selecting the show item clears the activator's hidden bit to reveal it. */
- (void)testSelectingTheShowItemFlipsTheActivatorVisibility
{
	self.getAPI.flags[@(kFxParameterId_DebugActivator)] = @(kFxParameterFlag_HIDDEN);

	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_ToggleShow]);

	XCTAssertEqualObjects(self.setAPIv6.flags[@(kFxParameterId_DebugActivator)], @(0));
}

/*! @abstract Selecting the toggle-menu item flips the activator's boolean value. */
- (void)testSelectingTheMenuItemFlipsTheActivatorValue
{
	self.getAPI.boolValues[@(kFxParameterId_DebugActivator)] = @(NO);

	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_ToggleMenu]);

	XCTAssertEqualObjects(self.setAPIv5.boolValues[@(kFxParameterId_DebugActivator)], @(YES));
}

/*! @abstract Selecting the toggle-menu item fails and writes nothing when the activator value cannot be read. */
- (void)testSelectingTheMenuItemStopsWhenTheActivatorCannotBeRead
{
	self.getAPI.boolReadSucceeds = NO;

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_ToggleMenu]);
	XCTAssertEqual(self.setAPIv5.boolValues.count, (NSUInteger)0);
}

/*! @abstract Selecting the toggle-menu item fails when the activator value cannot be written. */
- (void)testSelectingTheMenuItemStopsWhenTheActivatorCannotBeWritten
{
	self.getAPI.boolValues[@(kFxParameterId_DebugActivator)] = @(NO);
	self.setAPIv5.writeSucceeds = NO;

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_ToggleMenu]);
}

/*! @abstract Selecting remove ends the unhide first and stops without removing parameters when that pass fails. */
- (void)testSelectingRemoveEndsTheUnhideFirstAndStopsWhenThatFails
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.getAPI.flags[@(kFxParameterId_DebugMenu)] = @(kFxParameterFlag_DEBUG_UNHIDE);
	self.getAPI.flags[@1] = @(kFxParameterFlag_IN_DEBUG_MODE);
	self.setAPIv5.writeSucceeds = NO;

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_RemoveDebug]);
	XCTAssertEqual(self.dynamicAPI.removedParameters.count, (NSUInteger)0);
}

/*! @abstract Selecting remove drops both the activator and the debug menu parameters. */
- (void)testSelectingRemoveDropsTheActivatorAndTheMenu
{
	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_RemoveDebug]);

	XCTAssertEqualObjects(self.dynamicAPI.removedParameters,
						  (@[@(kFxParameterId_DebugActivator), @(kFxParameterId_DebugMenu)]));
}

/*! @abstract Selecting remove without an activator drops only the debug menu parameter. */
- (void)testSelectingRemoveDropsOnlyTheMenuWithoutAnActivator
{
	[self setDebugMenu:YES activator:NO];

	// Without the activator the layout is shorter; the row is resolved by name so the test
	// does not track the shifted index.
	XCTAssertTrue([self selectMenuItem:[self menuIndexForLabel:@"FxGrip::DebugMenu::RemoveDebugMenu"]]);

	XCTAssertEqualObjects(self.dynamicAPI.removedParameters, @[@(kFxParameterId_DebugMenu)]);
}

/*! @abstract Selecting remove fails when the host reports a removal error. */
- (void)testSelectingRemoveReportsTheHostRemovalError
{
	self.dynamicAPI.removeError = [NSError errorWithDomain:@"FxGripDebugTest" code:3 userInfo:nil];

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_RemoveDebug]);
}

#pragma mark Activator Reveal

/*! @abstract Turning the activator on clears the menu's hidden bit and turning it off hides the menu again. */
- (void)testTheActivatorRevealsTheMenuIndependentOfManageMeta
{
	self.getAPI.flags[@(kFxParameterId_DebugMenu)] = @(kFxParameterFlag_HIDDEN);
	self.getAPI.boolValues[@(kFxParameterId_DebugActivator)] = @(YES);

	[self postParameterChangedForID:kFxParameterId_DebugActivator];

	XCTAssertEqualObjects(self.setAPIv5.flags[@(kFxParameterId_DebugMenu)], @(0),
						  @"turning the activator on clears the menu's hidden bit");

	self.getAPI.flags[@(kFxParameterId_DebugMenu)] = @(0);
	self.getAPI.boolValues[@(kFxParameterId_DebugActivator)] = @(NO);

	[self postParameterChangedForID:kFxParameterId_DebugActivator];

	XCTAssertEqualObjects(self.setAPIv5.flags[@(kFxParameterId_DebugMenu)], @(kFxParameterFlag_HIDDEN),
						  @"turning the activator off hides the menu again");
}

/*! @abstract A parameter-changed notification for a parameter other than the activator writes nothing. */
- (void)testParameterChangedIgnoresParametersOtherThanTheActivator
{
	[self postParameterChangedForID:12345];

	XCTAssertEqual(self.setAPIv5.flags.count, (NSUInteger)0);
}

/*! @abstract A parameter-changed notification for the activator writes nothing when no activator is configured. */
- (void)testParameterChangedIgnoresTheActivatorWhenNoActivatorIsConfigured
{
	[self setDebugMenu:YES activator:NO];

	[self postParameterChangedForID:kFxParameterId_DebugActivator];

	XCTAssertEqual(self.setAPIv5.flags.count, (NSUInteger)0);
}

/*! @abstract setDebugMenuShown: toggles only the menu's hidden bit and leaves its other flags intact. */
- (void)testSetDebugMenuShownTogglesOnlyTheHiddenBit
{
	self.getAPI.flags[@(kFxParameterId_DebugMenu)] = @(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED);

	XCTAssertTrue([self.extension setDebugMenuShown:YES atTime:FxGripDebugTestZeroTime()]);

	XCTAssertEqualObjects(self.setAPIv5.flags[@(kFxParameterId_DebugMenu)], @(kFxParameterFlag_DISABLED));
}

#pragma mark Toggle All Debug

/*! @abstract Selecting toggle-all hides the activator and menu, keeps the activator control for rigging, and parks its value off. */
- (void)testSelectingToggleAllHidesBothAndParksTheActivatorOff
{
	self.getAPI.flags[@(kFxParameterId_DebugActivator)] = @(0);

	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_ToggleAll]);

	XCTAssertEqualObjects(self.setAPIv6.flags[@(kFxParameterId_DebugActivator)], @(kFxParameterFlag_HIDDEN),
						  @"the activator control is hidden but kept for rigging");
	XCTAssertEqualObjects(self.setAPIv5.boolValues[@(kFxParameterId_DebugActivator)], @(NO));
	XCTAssertEqualObjects(self.setAPIv5.flags[@(kFxParameterId_DebugMenu)], @(kFxParameterFlag_HIDDEN));
}

/*! @abstract Selecting toggle-all from the hidden state shows the activator and menu and turns the activator on. */
- (void)testSelectingToggleAllFromDarkShowsBothAndTurnsTheActivatorOn
{
	self.getAPI.flags[@(kFxParameterId_DebugActivator)] = @(kFxParameterFlag_HIDDEN);

	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_ToggleAll]);

	XCTAssertEqualObjects(self.setAPIv6.flags[@(kFxParameterId_DebugActivator)], @(0));
	XCTAssertEqualObjects(self.setAPIv5.boolValues[@(kFxParameterId_DebugActivator)], @(YES));
	XCTAssertEqualObjects(self.setAPIv5.flags[@(kFxParameterId_DebugMenu)], @(0));
}

#pragma mark Compiled Block

/*! @abstract A compiled block on debug features forces the plist debug keys off and registers no debug parameters. */
- (void)testACompiledBlockOverridesThePlistDebugKeys
{
	FxGripDebugTestBlockedEffect *blocked = FxGripDebugTestBlockedEffect.new;
	FxGripDebugMenu *extension = FxGripDebugMenu.new;
	[extension extLoadWithEffect:(id)blocked];

	XCTAssertFalse(blocked.hasDebugMenu, @"the master gate forces the plist keys off");
	XCTAssertFalse(extension.hasDebugMenu);
	XCTAssertFalse(extension.hasDebugActivator);

	NSMutableArray *parameters = NSMutableArray.new;
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectAddParametersName
														object:blocked
													  userInfo:@{FxGripTileableEffectParametersKey: parameters}];
	[extension extAddParameters:note];

	XCTAssertEqual(parameters.count, (NSUInteger)0, @"a blocked plugin registers no debug parameters");
}

#pragma mark Effect Category

/*! @abstract FxGripTileableEffect exposes a debugMenu accessor. */
- (void)testTheEffectExposesItsDebugMenuExtension
{
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(debugMenu)]);
}

/*! @abstract FxGripTileableEffect exposes the debug gate seam accessors. */
- (void)testTheEffectExposesTheDebugGateSeam
{
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(allowsDebugFeatures)]);
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(pluginDebugMenuEnabled)]);
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(pluginDebugActivatorEnabled)]);
}

@end

#pragma mark - About menu tests

// Captures the two side-effecting primitives so dispatch is verified without touching
// NSWorkspace or NSAlert.
@interface FxGripAboutTestMenu : FxGripAboutMenu
@property (nonatomic, strong) NSArray<NSString *> *openedURLs;
@property (nonatomic, assign) NSUInteger dialogCount;
@property (nonatomic, copy) NSString *lastDialogText;
@end

@implementation FxGripAboutTestMenu
- (void)openAboutURLStrings:(NSArray<NSString *> *)urlStrings { self.openedURLs = urlStrings; }
- (void)showAboutDialogWithText:(NSString *)text { self.dialogCount += 1; self.lastDialogText = text; }
@end

// Exercises the "both" content source: a subclass hook that extends the plist items.
@interface FxGripAboutHookEffect : FxGripDebugTestStubEffect
@end

@implementation FxGripAboutHookEffect
- (NSArray<NSDictionary *> *)aboutMenuItems:(NSArray<NSDictionary *> *)items
{
	return [items arrayByAddingObject:@{FxGripAboutEntryLabelKey: @"About::Extra",
										FxGripAboutEntryUrlKey: @"https://extra.example"}];
}
@end

static const FxParameterId kFxAboutTestToggleParameter = 500;
static const FxParameterId kFxAboutTestAgreementParameter = 600;

static NSDictionary *FxGripAboutTestConfiguration(BOOL withAgreement)
{
	NSMutableDictionary *config = @{
		FxGripAboutMenuNameKey: @"About::Name",
		FxGripAboutMenuMainTextKey: @"About::Main",
		FxGripAboutMenuFallbackUrlKey: @"https://fallback.example",
		FxGripAboutMenuItemsKey: @[
			@{FxGripAboutEntryLabelKey: @"About::Help",
			  FxGripAboutEntryKindKey: FxGripAboutEntryKindLink,
			  FxGripAboutEntryUrlKey: @"https://help.example",
			  FxGripAboutEntryFallbacksKey: @[@"https://help2.example"]},
			@{FxGripAboutEntryKindKey: FxGripAboutEntryKindSeparator},
			@{FxGripAboutEntryLabelKey: @"About::Toggle",
			  FxGripAboutEntryUrlKey: @"https://toggle.example",
			  FxGripAboutEntryDisplayIdKey: @(kFxAboutTestToggleParameter)},
			@{FxGripAboutEntryLabelKey: @"About::Follow",
			  FxGripAboutEntryUrlKey: @"https://follow.example"},
		]
	}.mutableCopy;
	if (withAgreement) {
		config[FxGripAboutMenuAgreementIdKey] = @(kFxAboutTestAgreementParameter);
		config[FxGripAboutMenuAgreementAcceptedValueKey] = @(1);
		config[FxGripAboutMenuWarningKey] = @[@"About::Warn1", @"About::Warn2"];
		config[FxGripAboutMenuWarningDialogTextKey] = @"About::MustAccept";
	}
	return config.copy;
}

@interface FxGripAboutMenuTests : XCTestCase
@property (nonatomic, strong) FxGripAboutTestMenu *extension;
@property (nonatomic, strong) FxGripDebugTestStubEffect *effect;
@end

@implementation FxGripAboutMenuTests

- (void)setUp
{
	[super setUp];
	self.extension = [FxGripAboutTestMenu.alloc init];
	self.effect = [FxGripDebugTestStubEffect.alloc init];
	self.effect.aboutConfig = FxGripAboutTestConfiguration(NO);
	[self.extension extLoadWithEffect:(id)self.effect];
}

- (void)tearDown
{
	self.extension = nil;
	self.effect = nil;
	[super tearDown];
}

- (FxGripDebugTestStubDynamicAPI *)dynamicAPI { return self.effect.apiManager.dynamicParamAPIv3; }
- (FxGripDebugTestStubGetAPI *)getAPI { return self.effect.apiManager.paramGetAPIv6; }

- (NSMutableArray *)runAddParameters
{
	NSMutableArray *parameters = NSMutableArray.new;
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectAddParametersName
														object:self.effect
													  userInfo:@{FxGripTileableEffectParametersKey: parameters}];
	[self.extension extAddParameters:note];
	return parameters;
}

- (BOOL)selectAboutItemLabeled:(NSString *)label
{
	NSArray<NSString *> *items = [self.extension aboutMenuItemsReadingValues:YES atTime:FxGripDebugTestZeroTime()];
	NSUInteger index = [items indexOfObject:label];
	XCTAssertNotEqual(index, (NSUInteger)NSNotFound, @"about row %@ is missing", label);
	self.getAPI.intValues[@(kFxParameterId_AboutMenu)] = @(index);
	return [self.extension manageAboutMenu:kFxParameterId_AboutMenu atTime:FxGripDebugTestZeroTime() error:NULL];
}

#pragma mark Registration

/*! @abstract The About extension uses the shared about-menu key and the default notification priority. */
- (void)testTheExtensionUsesTheSharedAboutMenuKey
{
	XCTAssertEqualObjects(self.extension.extKey, FxGripAboutMenuExtensionKey);
	XCTAssertEqualObjects(self.extension.extKey, @"FxGripAboutMenu");
	XCTAssertEqual([self.extension ncPriority:nil], FxGripExtensionDefaultPriority);
}

/*! @abstract Adding parameters registers the About menu with its id, type, factory, name, flags, and baseline item list. */
- (void)testAddParametersRegistersTheAboutMenu
{
	NSMutableArray *parameters = [self runAddParameters];

	XCTAssertEqual(parameters.count, (NSUInteger)1);
	NSDictionary *menu = parameters[0];
	XCTAssertEqualObjects(menu[kFxParameterProperty_Id], @(kFxParameterId_AboutMenu));
	XCTAssertEqualObjects(menu[kFxParameterProperty_Type], kFxParameterType_Menu);
	XCTAssertEqualObjects(menu[kFxParameterProperty_Factory], self.extension);
	XCTAssertEqualObjects(menu[kFxParameterProperty_Selector], @"manageAboutMenu");
	XCTAssertEqualObjects(menu[kFxParameterProperty_Name], @"About::Name");

	NSArray *flags = menu[kFxParameterProperty_Flags];
	XCTAssertTrue([flags containsObject:kParameterFlagString_NOT_ANIMATABLE]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_NO_STATE]);

	// The baseline includes every gated entry, before parameter values exist.
	NSArray<NSString *> *items = menu[kFxParameterProperty_MenuItems];
	XCTAssertEqualObjects(items, (@[@"About::Main", @"About::Help", @"-", @"About::Toggle", @"About::Follow"]));
}

/*! @abstract Adding parameters registers nothing when the effect has no About configuration. */
- (void)testAddParametersRegistersNothingWithoutAConfiguration
{
	self.effect.aboutConfig = nil;

	XCTAssertEqual([self runAddParameters].count, (NSUInteger)0);
}

#pragma mark Live layout

/*! @abstract The live menu hides an entry whose display-toggle parameter is off and shows it when on. */
- (void)testTheLiveMenuHidesAnEntryWhoseDisplayToggleIsOff
{
	self.getAPI.boolValues[@(kFxAboutTestToggleParameter)] = @(NO);
	NSArray<NSString *> *hidden = [self.extension aboutMenuItemsReadingValues:YES atTime:FxGripDebugTestZeroTime()];
	XCTAssertFalse([hidden containsObject:@"About::Toggle"]);

	self.getAPI.boolValues[@(kFxAboutTestToggleParameter)] = @(YES);
	NSArray<NSString *> *shown = [self.extension aboutMenuItemsReadingValues:YES atTime:FxGripDebugTestZeroTime()];
	XCTAssertTrue([shown containsObject:@"About::Toggle"]);
}

/*! @abstract The agreement gate prepends the warning lines until the agreement parameter reaches its accepted value. */
- (void)testTheAgreementGatePrependsWarningsUntilAccepted
{
	self.effect.aboutConfig = FxGripAboutTestConfiguration(YES);

	self.getAPI.intValues[@(kFxAboutTestAgreementParameter)] = @(0);
	NSArray<NSString *> *gated = [self.extension aboutMenuItemsReadingValues:YES atTime:FxGripDebugTestZeroTime()];
	XCTAssertEqualObjects(gated.firstObject, @"About::Warn1");
	XCTAssertTrue([gated containsObject:@"About::Warn2"]);

	self.getAPI.intValues[@(kFxAboutTestAgreementParameter)] = @(1);
	NSArray<NSString *> *accepted = [self.extension aboutMenuItemsReadingValues:YES atTime:FxGripDebugTestZeroTime()];
	XCTAssertFalse([accepted containsObject:@"About::Warn1"]);
	XCTAssertEqualObjects(accepted.firstObject, @"About::Main");
}

/*! @abstract A subclass aboutMenuItems: hook extends the plist item list with its extra entry. */
- (void)testTheSubclassHookExtendsThePlistItems
{
	FxGripAboutHookEffect *hookEffect = FxGripAboutHookEffect.new;
	hookEffect.aboutConfig = FxGripAboutTestConfiguration(NO);
	FxGripAboutTestMenu *extension = FxGripAboutTestMenu.new;
	[extension extLoadWithEffect:(id)hookEffect];

	NSArray<NSString *> *items = [extension aboutMenuItemsReadingValues:NO atTime:FxGripDebugTestZeroTime()];
	XCTAssertEqualObjects(items.lastObject, @"About::Extra");
}

#pragma mark Selection

/*! @abstract Selecting a link opens its URL, then its per-entry fallbacks, then the global fallback last. */
- (void)testSelectingALinkOpensItsFallbackChainWithTheGlobalFallbackLast
{
	XCTAssertTrue([self selectAboutItemLabeled:@"About::Help"]);

	XCTAssertEqualObjects(self.extension.openedURLs,
						  (@[@"https://help.example", @"https://help2.example", @"https://fallback.example"]));
	XCTAssertEqual(self.extension.dialogCount, (NSUInteger)0);
}

/*! @abstract Selecting the main line opens no URL and shows no dialog. */
- (void)testSelectingTheMainLineDoesNothing
{
	XCTAssertTrue([self selectAboutItemLabeled:@"About::Main"]);

	XCTAssertNil(self.extension.openedURLs);
	XCTAssertEqual(self.extension.dialogCount, (NSUInteger)0);
}

/*! @abstract Selecting a warning line shows the must-accept dialog and opens no URL. */
- (void)testSelectingAWarningShowsTheDialog
{
	self.effect.aboutConfig = FxGripAboutTestConfiguration(YES);
	self.getAPI.intValues[@(kFxAboutTestAgreementParameter)] = @(0);

	XCTAssertTrue([self selectAboutItemLabeled:@"About::Warn1"]);

	XCTAssertEqual(self.extension.dialogCount, (NSUInteger)1);
	XCTAssertEqualObjects(self.extension.lastDialogText, @"About::MustAccept");
	XCTAssertNil(self.extension.openedURLs);
}

/*! @abstract An About menu command fails when the selected menu index cannot be read. */
- (void)testAMenuCommandStopsWhenTheSelectionCannotBeRead
{
	self.getAPI.intReadSucceeds = NO;

	XCTAssertFalse([self.extension manageAboutMenu:kFxParameterId_AboutMenu
											atTime:FxGripDebugTestZeroTime()
											 error:NULL]);
}

#pragma mark Gating and refresh

/*! @abstract The gating parameter IDs cover the agreement parameter and the entry display toggles. */
- (void)testGatingParameterIDsCoverTheAgreementAndTheDisplayToggles
{
	self.effect.aboutConfig = FxGripAboutTestConfiguration(YES);

	NSSet<NSNumber *> *ids = [self.extension aboutMenuGatingParameterIDs];

	XCTAssertEqualObjects(ids, ([NSSet setWithArray:@[@(kFxAboutTestAgreementParameter), @(kFxAboutTestToggleParameter)]]));
}

/*! @abstract A change to a gating parameter rebuilds the About menu entries. */
- (void)testAChangeToAGatingParameterRebuildsTheMenu
{
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
														object:self.effect
													  userInfo:@{FxGripTileableEffectParameterChangedIDKey: @(kFxAboutTestToggleParameter)}];
	[self.extension extParameterChanged:note];

	XCTAssertEqual(self.dynamicAPI.menuParameter, (FxParameterId)kFxParameterId_AboutMenu);
	XCTAssertNotNil(self.dynamicAPI.menuEntries);
}

/*! @abstract A change to an unrelated parameter leaves the About menu entries alone. */
- (void)testAChangeToAnUnrelatedParameterLeavesTheMenuAlone
{
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
														object:self.effect
													  userInfo:@{FxGripTileableEffectParameterChangedIDKey: @(4242)}];
	[self.extension extParameterChanged:note];

	XCTAssertNil(self.dynamicAPI.menuEntries);
}

#pragma mark Effect Category

/*! @abstract FxGripTileableEffect exposes the About menu accessor and its configuration and item hook seam. */
- (void)testTheEffectExposesItsAboutMenuAndSeam
{
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(aboutMenu)]);
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(hasAboutMenu)]);
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(aboutMenuConfiguration)]);
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(aboutMenuItems:)]);
}

@end

#pragma mark - Regression tests

@interface FxGripRegression (FxGripRegressionTestAccess)
- (BOOL)validatePluginUUID:(id)effect;
- (BOOL)validatePluginVersion:(id)effect;
@end

@interface FxGripRegressionTests : XCTestCase
@property (nonatomic, strong) FxGripRegression *extension;
@property (nonatomic, strong) FxGripDebugTestStubEffect *effect;
@end

@implementation FxGripRegressionTests

- (void)setUp
{
	[super setUp];
	self.extension = [FxGripRegression.alloc init];
	self.effect = [FxGripDebugTestStubEffect.alloc init];
}

- (void)tearDown
{
	self.extension = nil;
	self.effect = nil;
	[super tearDown];
}

- (void)setPluginProperties:(NSDictionary *)overrides
{
	NSMutableDictionary *properties = FxGripDebugTestPluginProperties(NO, NO);
	[properties addEntriesFromDictionary:overrides];
	self.effect.pluginProperties = properties;
}

/*! @abstract A valid plugin loads the regression extension and binds it to the effect. */
- (void)testAValidPluginPassesTheRegressionPass
{
	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect]);
	XCTAssertTrue(self.extension.effect == (id)self.effect);
}

/*! @abstract A valid plugin passes both the UUID and the version validation checks. */
- (void)testAValidPluginPassesUUIDAndVersionValidation
{
	XCTAssertTrue([self.extension validatePluginUUID:self.effect]);
	XCTAssertTrue([self.extension validatePluginVersion:self.effect]);
}

/*! @abstract A malformed UUID fails validation but the regression pass still loads the extension. */
- (void)testAMalformedUUIDStillLoadsTheExtension
{
	[self setPluginProperties:@{kProPlugPlugIn_UuidProperty: @"not-a-uuid"}];

	XCTAssertFalse([self.extension validatePluginUUID:self.effect]);
	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect],
				  @"the regression pass reports problems without blocking the plugin");
}

/*! @abstract A missing resolved plugin UUID fails validation but the extension still loads. */
- (void)testAMissingResolvedPluginUUIDIsReportedButStillLoads
{
	self.effect.pluginUUID = nil;

	XCTAssertFalse([self.extension validatePluginUUID:self.effect],
				   @"a valid plist string is not enough; the resolved pluginUUID must be present");
	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect]);
}

/*! @abstract A version that is neither a string nor a number fails validation without crashing and still loads. */
- (void)testANonStringNonNumberVersionIsReportedWithoutCrashing
{
	[self setPluginProperties:@{kProPlugPlugIn_VersionProperty: @[@1, @2, @3]}];

	XCTAssertFalse([self.extension validatePluginVersion:self.effect]);
	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect]);
}

/*! @abstract A plain-digit version string passes validation while a dotted version string fails. */
- (void)testADigitStringVersionIsAcceptedAndANonDigitStringIsRejected
{
	[self setPluginProperties:@{kProPlugPlugIn_VersionProperty: @"12"}];
	XCTAssertTrue([self.extension validatePluginVersion:self.effect]);

	[self setPluginProperties:@{kProPlugPlugIn_VersionProperty: @"1.2.3"}];
	XCTAssertFalse([self.extension validatePluginVersion:self.effect]);
}

/*! @abstract Both a digit-string version and a dotted version load the regression extension. */
- (void)testAStringVersionAndANonNumericVersionStillLoadTheExtension
{
	[self setPluginProperties:@{kProPlugPlugIn_VersionProperty: @"12"}];
	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect]);

	FxGripRegression *second = [FxGripRegression.alloc init];
	[self setPluginProperties:@{kProPlugPlugIn_VersionProperty: @"1.2.3"}];
	XCTAssertTrue([second extLoadWithEffect:(id)self.effect]);
}

/*! @abstract An inactive regression extension does not load. */
- (void)testAnInactiveExtensionIsNotLoaded
{
	[self.extension setExtActive:NO];

	XCTAssertFalse([self.extension extLoadWithEffect:(id)self.effect]);
}

/*! @abstract FxGripTileableEffect exposes the regression accessor and its new-extension factory. */
- (void)testTheEffectBuildsARegressionExtension
{
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(regression)]);
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(newRegressionExtension)]);
}

@end
