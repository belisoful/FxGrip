//
//  FxGripDebugMenuTests.m
//  FxGripTests
//
//  Unit tests for the small host-facing extensions: FxGripDebugMenu's parameter
//  registration, debug-mode flag translation, menu contents and menu command
//  handling; FxGripAboutMenu's registration surface; and FxGripRegression's
//  plugin-property validation pass.
//

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

// The debug menu selections the extension recognizes. The values mirror the private
// enumeration in FxGripDebugMenu.m.
typedef NS_ENUM(NSUInteger, FxGripDebugTestMenuItem) {
	FxGripDebugTestItem_Main = 0,
	FxGripDebugTestItem_ToggleUnhide = 2,
	FxGripDebugTestItem_ToggleShow = 3,
	FxGripDebugTestItem_ToggleMenu = 5,
	FxGripDebugTestItem_RemoveDebug = 7,
	FxGripDebugTestItem_AddParam = 8,
	FxGripDebugTestItem_RemoveParam = 9,
};

static const FxParameterId kFxDebugTestTempParameter = 888;

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
- (BOOL)debugUnhide:(BOOL)active;
- (BOOL)manageDebuggerController:(FxParameterId)parameterID
						  atTime:(CMTime)time
						   error:(NSError * _Nullable * _Nullable)error;
- (NSArray<NSString *> * _Nonnull)debugMenuItems:(BOOL)unhide;
@end

@interface FxGripAboutMenu (FxGripAboutMenuTestAccess)
- (void)extProcessParameters:(nonnull NSMutableArray *)parameters;
- (NSArray * _Nullable)computeAboutMenuFrom:(nullable id)paramGetAPIv6 atTime:(CMTime)time;
- (void)clickResetAboutMenu;
- (void)clickAboutMenu:(unsigned int)selectionIndex paramAPIv6:(nullable id)paramGetAPIv6 atTime:(CMTime)time;
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

@interface FxGripDebugTestStubCreateAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSNumber *> *addedParameters;
@property (nonatomic, assign) BOOL addSucceeds;
@end

@implementation FxGripDebugTestStubCreateAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_addedParameters = NSMutableArray.new;
		_addSucceeds = YES;
	}
	return self;
}

- (BOOL)addStringParameterWithName:(NSString *)name
					   parameterID:(UInt32)parameterID
					  defaultValue:(NSString *)defaultValue
					parameterFlags:(FxParameterFlags)flags
{
	[self.addedParameters addObject:@(parameterID)];
	return self.addSucceeds;
}

@end

@interface FxGripDebugTestStubAPIManager : NSObject
@property (nonatomic, strong) FxGripDebugTestStubDynamicAPI *dynamicParamAPIv3;
@property (nonatomic, strong) FxGripDebugTestStubGetAPI *paramGetAPIv6;
@property (nonatomic, strong) FxGripDebugTestStubSetAPI *paramSetAPIv5;
@property (nonatomic, strong) FxGripDebugTestStubSetAPI *paramSetAPIv6;
@property (nonatomic, strong) FxGripDebugTestStubCreateAPI *paramCreateAPIv5;
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
@end

@implementation FxGripDebugTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
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
		_apiManager.paramCreateAPIv5 = FxGripDebugTestStubCreateAPI.new;
		_pluginProperties = FxGripDebugTestPluginProperties(YES, YES);
		_pluginUUID = @"33333333-3333-3333-3333-333333333333";
	}
	return self;
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

- (void)testTheExtensionUsesTheSharedDebugMenuKeyAndRunsLast
{
	XCTAssertEqualObjects(self.extension.extKey, FxGripDebugMenuExtensionKey);
	XCTAssertEqualObjects(self.extension.extKey, @"FxGripDebugMenu");
	XCTAssertEqual([self.extension extPostProcessPriority], 19);
}

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

- (void)testProcessParametersRegistersOnlyTheVisibleMenuWithoutAnActivator
{
	[self setDebugMenu:YES activator:NO];

	NSMutableArray *parameters = [self runAddParameters];

	XCTAssertEqual(parameters.count, (NSUInteger)1);
	XCTAssertEqualObjects(parameters[0][kFxParameterProperty_Id], @(kFxParameterId_DebugMenu));
	XCTAssertFalse([parameters[0][kFxParameterProperty_Flags] containsObject:kParameterFlagString_HIDDEN]);
}

- (void)testProcessParametersRegistersNothingWithoutADebugMenu
{
	[self setDebugMenu:NO activator:NO];

	NSMutableArray *parameters = [self runAddParameters];

	XCTAssertEqual(parameters.count, (NSUInteger)0);
}

#pragma mark Menu Contents

- (void)testTheMenuListsTheDebugToggleOnlyWithAnActivator
{
	[self setDebugMenu:YES activator:YES];
	NSArray<NSString *> *withActivator = [self.extension debugMenuItems:NO];

	[self setDebugMenu:YES activator:NO];
	NSArray<NSString *> *withoutActivator = [self.extension debugMenuItems:NO];

	XCTAssertEqual(withActivator.count, withoutActivator.count + 1);
	XCTAssertTrue([withActivator containsObject:@"FxGrip::DebugMenu::ToggleDebugToggle"]);
	XCTAssertFalse([withoutActivator containsObject:@"FxGrip::DebugMenu::ToggleDebugToggle"]);
	XCTAssertEqualObjects(withActivator.firstObject, @"FxGrip::DebugMenu::MainItem");
	XCTAssertEqualObjects(withActivator[FxGripDebugTestItem_ToggleUnhide], @"FxGrip::DebugMenu::ToggleUnhideOff");
	XCTAssertEqualObjects(withActivator[FxGripDebugTestItem_ToggleShow], @"FxGrip::DebugMenu::ToggleDebugToggle");
	XCTAssertEqualObjects(withActivator[FxGripDebugTestItem_ToggleMenu], @"FxGrip::DebugMenu::ToggleDebugMenu");
	XCTAssertEqualObjects(withActivator[FxGripDebugTestItem_RemoveDebug], @"FxGrip::DebugMenu::RemoveDebugMenu");
}

- (void)testTheUnhideItemNamesTheStateItSwitchesTo
{
	XCTAssertEqualObjects([self.extension debugMenuItems:YES][FxGripDebugTestItem_ToggleUnhide],
						  @"FxGrip::DebugMenu::ToggleUnhideOn");
	XCTAssertEqualObjects([self.extension debugMenuItems:NO][FxGripDebugTestItem_ToggleUnhide],
						  @"FxGrip::DebugMenu::ToggleUnhideOff");
}

#pragma mark Debug Mode Flag Translation

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

- (void)testReadingFlagsOutsideDebugModeLeavesThemAlone
{
	FxParameterFlags flags = [self runFlagsHandler:@selector(extAPIParameterGetFlags:)
										   onFlags:kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED];

	XCTAssertEqual(flags, (FxParameterFlags)(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED));
}

- (void)testWritingFlagsInDebugModeParksTheHiddenBitInTheProxy
{
	FxParameterFlags flags = [self runFlagsHandler:@selector(extAPIParameterSetFlagsPre:)
										   onFlags:kFxParameterFlag_IN_DEBUG_MODE | kFxParameterFlag_HIDDEN];

	XCTAssertEqual(flags & kFxParameterFlag_HIDDEN, (FxParameterFlags)0);
	XCTAssertTrue((flags & kFxParameterFlag_HIDDEN_PROXY) != 0);
}

- (void)testWritingFlagsInDebugModeClearsAStaleProxy
{
	FxParameterFlags flags = [self runFlagsHandler:@selector(extAPIParameterSetFlagsPre:)
										   onFlags:kFxParameterFlag_IN_DEBUG_MODE | kFxParameterFlag_HIDDEN_PROXY];

	XCTAssertEqual(flags & kFxParameterFlag_HIDDEN_PROXY, (FxParameterFlags)0);
	XCTAssertEqual(flags & kFxParameterFlag_HIDDEN, (FxParameterFlags)0);
}

- (void)testWritingFlagsOutsideDebugModeLeavesThemAlone
{
	FxParameterFlags flags = [self runFlagsHandler:@selector(extAPIParameterSetFlagsPre:)
										   onFlags:kFxParameterFlag_HIDDEN];

	XCTAssertEqual(flags, (FxParameterFlags)kFxParameterFlag_HIDDEN);
}

#pragma mark Unhiding

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

- (void)testEndingTheUnhideClearsTheDebugModeBit
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.getAPI.flags[@1] = @(kFxParameterFlag_IN_DEBUG_MODE | kFxParameterFlag_HIDDEN);

	XCTAssertTrue([self.extension debugUnhide:NO]);

	XCTAssertEqualObjects(self.setAPIv5.flags[@1], @(kFxParameterFlag_HIDDEN));
	XCTAssertEqualObjects(self.dynamicAPI.menuEntries, [self.extension debugMenuItems:NO]);
}

- (void)testUnhidingLeavesParametersThatAreAlreadyInTheWantedStateUntouched
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.getAPI.flags[@1] = @(kFxParameterFlag_IN_DEBUG_MODE);

	XCTAssertTrue([self.extension debugUnhide:YES]);

	XCTAssertNil(self.setAPIv5.flags[@1]);
}

- (void)testUnhidingStopsWhenTheHostRefusesToReportFlags
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.getAPI.flagsReadSucceeds = NO;

	XCTAssertFalse([self.extension debugUnhide:YES]);
	XCTAssertNil(self.dynamicAPI.menuEntries);
}

- (void)testUnhidingStopsWhenTheHostRefusesTheFlagWrite
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.setAPIv5.writeSucceeds = NO;

	XCTAssertFalse([self.extension debugUnhide:YES]);
}

- (void)testTheUnhideStateIsReadFromTheMenuParameterFlags
{
	XCTAssertFalse(self.extension.isDebugUnhiding);

	self.getAPI.flags[@(kFxParameterId_DebugMenu)] = @(kFxParameterFlag_DEBUG_UNHIDE);
	XCTAssertTrue(self.extension.isDebugUnhiding);

	self.getAPI.flagsReadSucceeds = NO;
	XCTAssertFalse(self.extension.isDebugUnhiding);
}

#pragma mark Menu Commands

- (void)testSelectingTheMainItemDoesNothing
{
	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_Main]);

	XCTAssertEqual(self.setAPIv5.flags.count, (NSUInteger)0);
	XCTAssertEqual(self.dynamicAPI.removedParameters.count, (NSUInteger)0);
}

- (void)testAMenuCommandStopsWhenTheSelectionCannotBeRead
{
	self.getAPI.intReadSucceeds = NO;

	NSError *error = nil;
	XCTAssertFalse([self.extension manageDebuggerController:kFxParameterId_DebugMenu
													 atTime:FxGripDebugTestZeroTime()
													  error:&error]);
}

- (void)testSelectingTheUnhideItemTurnsDebugModeOn
{
	self.dynamicAPI.parameterIDList = @[@1];

	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_ToggleUnhide]);

	XCTAssertEqualObjects(self.setAPIv5.flags[@1], @(kFxParameterFlag_IN_DEBUG_MODE));
}

- (void)testSelectingTheUnhideItemStopsWhenTheUnhidePassFails
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.getAPI.flagsReadSucceeds = NO;

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_ToggleUnhide]);
}

- (void)testSelectingTheShowItemFlipsTheActivatorVisibility
{
	self.getAPI.flags[@(kFxParameterId_DebugActivator)] = @(kFxParameterFlag_HIDDEN);

	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_ToggleShow]);

	XCTAssertEqualObjects(self.setAPIv6.flags[@(kFxParameterId_DebugActivator)], @(0));
}

- (void)testSelectingTheMenuItemFlipsTheActivatorValue
{
	self.getAPI.boolValues[@(kFxParameterId_DebugActivator)] = @(NO);

	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_ToggleMenu]);

	XCTAssertEqualObjects(self.setAPIv5.boolValues[@(kFxParameterId_DebugActivator)], @(YES));
}

- (void)testSelectingTheMenuItemStopsWhenTheActivatorCannotBeRead
{
	self.getAPI.boolReadSucceeds = NO;

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_ToggleMenu]);
	XCTAssertEqual(self.setAPIv5.boolValues.count, (NSUInteger)0);
}

- (void)testSelectingTheMenuItemStopsWhenTheActivatorCannotBeWritten
{
	self.getAPI.boolValues[@(kFxParameterId_DebugActivator)] = @(NO);
	self.setAPIv5.writeSucceeds = NO;

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_ToggleMenu]);
}

- (void)testSelectingRemoveEndsTheUnhideFirstAndStopsWhenThatFails
{
	self.dynamicAPI.parameterIDList = @[@1];
	self.getAPI.flags[@(kFxParameterId_DebugMenu)] = @(kFxParameterFlag_DEBUG_UNHIDE);
	self.getAPI.flags[@1] = @(kFxParameterFlag_IN_DEBUG_MODE);
	self.setAPIv5.writeSucceeds = NO;

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_RemoveDebug]);
	XCTAssertEqual(self.dynamicAPI.removedParameters.count, (NSUInteger)0);
}

- (void)testSelectingRemoveDropsTheActivatorAndTheMenu
{
	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_RemoveDebug]);

	XCTAssertEqualObjects(self.dynamicAPI.removedParameters,
						  (@[@(kFxParameterId_DebugActivator), @(kFxParameterId_DebugMenu)]));
}

- (void)testSelectingRemoveDropsOnlyTheMenuWithoutAnActivator
{
	[self setDebugMenu:YES activator:NO];

	// Without the activator the host menu carries one item fewer, so the selection the
	// extension receives is one lower than the enumerated position.
	self.getAPI.intValues[@(kFxParameterId_DebugMenu)] = @(FxGripDebugTestItem_RemoveDebug - 1);
	XCTAssertTrue([self.extension manageDebuggerController:kFxParameterId_DebugMenu
													atTime:FxGripDebugTestZeroTime()
													 error:NULL]);

	XCTAssertEqualObjects(self.dynamicAPI.removedParameters, @[@(kFxParameterId_DebugMenu)]);
}

- (void)testSelectingRemoveReportsTheHostRemovalError
{
	self.dynamicAPI.removeError = [NSError errorWithDomain:@"FxGripDebugTest" code:3 userInfo:nil];

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_RemoveDebug]);
}

- (void)testSelectingAddParameterCreatesTheTemporaryParameter
{
	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_AddParam]);

	XCTAssertEqualObjects(self.effect.apiManager.paramCreateAPIv5.addedParameters,
						  @[@(kFxDebugTestTempParameter)]);
	XCTAssertNotNil(self.setAPIv5.flags[@(kFxDebugTestTempParameter)]);
}

- (void)testSelectingAddParameterStopsWhenTheHostRefuses
{
	self.effect.apiManager.paramCreateAPIv5.addSucceeds = NO;

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_AddParam]);
	XCTAssertNil(self.setAPIv5.flags[@(kFxDebugTestTempParameter)]);
}

- (void)testSelectingRemoveParameterDropsTheTemporaryParameter
{
	XCTAssertTrue([self selectMenuItem:FxGripDebugTestItem_RemoveParam]);

	XCTAssertEqualObjects(self.dynamicAPI.removedParameters, @[@(kFxDebugTestTempParameter)]);
}

- (void)testSelectingRemoveParameterReportsTheHostError
{
	self.dynamicAPI.removeError = [NSError errorWithDomain:@"FxGripDebugTest" code:4 userInfo:nil];

	XCTAssertFalse([self selectMenuItem:FxGripDebugTestItem_RemoveParam]);
}

#pragma mark Effect Category

- (void)testTheEffectExposesItsDebugMenuExtension
{
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(debugMenu)]);
}

@end

#pragma mark - About menu tests

@interface FxGripAboutMenuTests : XCTestCase
@property (nonatomic, strong) FxGripAboutMenu *extension;
@end

@implementation FxGripAboutMenuTests

- (void)setUp
{
	[super setUp];
	self.extension = [FxGripAboutMenu.alloc init];
}

- (void)tearDown
{
	self.extension = nil;
	[super tearDown];
}

- (void)testTheExtensionUsesTheSharedAboutMenuKey
{
	XCTAssertEqualObjects(self.extension.extKey, FxGripAboutMenuExtensionKey);
	XCTAssertEqualObjects(self.extension.extKey, @"FxGripAboutMenu");
	XCTAssertEqual([self.extension ncPriority:nil], FxGripExtensionDefaultPriority);
}

/*!
	The about-menu content is not built yet: the extension registers no parameters and
	computes no menu. The entry points are exercised so a future implementation replaces a
	covered contract rather than dead code.
*/
- (void)testTheAboutMenuContributesNothingYet
{
	NSMutableArray *parameters = NSMutableArray.new;

	[self.extension extProcessParameters:parameters];

	XCTAssertEqual(parameters.count, (NSUInteger)0);
	XCTAssertNil([self.extension computeAboutMenuFrom:nil atTime:FxGripDebugTestZeroTime()]);
}

- (void)testTheAboutMenuClickHandlersAreInert
{
	XCTAssertNoThrow([self.extension clickResetAboutMenu]);
	XCTAssertNoThrow([self.extension clickAboutMenu:0 paramAPIv6:nil atTime:FxGripDebugTestZeroTime()]);
}

@end

#pragma mark - Regression tests

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

- (void)testAValidPluginPassesTheRegressionPass
{
	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect]);
	XCTAssertTrue(self.extension.effect == (id)self.effect);
}

- (void)testAMalformedUUIDStillLoadsTheExtension
{
	[self setPluginProperties:@{kProPlugPlugIn_UuidProperty: @"not-a-uuid"}];

	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect],
				  @"the regression pass reports problems without blocking the plugin");
}

- (void)testAStringVersionAndANonNumericVersionStillLoadTheExtension
{
	[self setPluginProperties:@{kProPlugPlugIn_VersionProperty: @"12"}];
	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect]);

	FxGripRegression *second = [FxGripRegression.alloc init];
	[self setPluginProperties:@{kProPlugPlugIn_VersionProperty: @"1.2.3"}];
	XCTAssertTrue([second extLoadWithEffect:(id)self.effect]);
}

- (void)testAnInactiveExtensionIsNotLoaded
{
	[self.extension setExtActive:NO];

	XCTAssertFalse([self.extension extLoadWithEffect:(id)self.effect]);
}

- (void)testTheEffectBuildsARegressionExtension
{
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(regression)]);
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(newRegressionExtension)]);
}

@end
