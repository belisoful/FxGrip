//
//  FxGripI18NTests.m
//  FxGripTests
//
//  Unit tests for the internationalization pipeline: the notification round-trip
//  the parameter API wrappers perform around the host API, the FxGripI18N
//  handlers that mutate the nested parameter dictionary, the plist-driven
//  delocalization gating, and the API manager accessor on the init userInfo.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxAPINotifications.h>
#import <FxGrip/FxTileableEffectBase+Notifications.h>
#import <FxGrip/FxGripDynamicParameterAPI_v3.h>
#import <FxGrip/FxGripDynamicParameterAPI_v4.h>
#import <FxGrip/FxGripParameterRetrievalAPI_v6.h>
#import <FxGrip/FxGripI18N.h>

static const FxParameterId kI18NTestParameter = 7;

// FxGripDynamicParameterAPI_v4 implements parameter:entries:, but neither its class
// interface nor FxDynamicParameterAPI_v4 declares the selector, so it is redeclared here.
// The implementation comes from the linked framework.
@interface FxGripDynamicParameterAPI_v4 (FxGripI18NTests)
- (nullable NSError *)parameter:(FxParameterId)parameterID entries:(NSArray<NSString *> *_Nullable *_Nonnull)entries;
@end

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxI18NTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

#pragma mark - Test doubles

/*!
	Stands in for the host's FxDynamicParameterAPI_v3. It hands back a fixed name and
	records the name the wrapper forwards after the pre-notification has run.
*/
@interface FxI18NTestStubDynamicAPI : NSObject
@property (nonatomic, copy) NSString *hostName;
@property (nonatomic, copy) NSArray<NSString *> *hostEntries;
@property (nonatomic, copy) NSString *receivedName;
@property (nonatomic, assign) NSUInteger setNameCallCount;
@end

@implementation FxI18NTestStubDynamicAPI

- (NSError *)parameter:(UInt32)parameterID name:(NSString **)parameterName
{
	if (parameterName) {
		*parameterName = self.hostName;
	}
	return nil;
}

- (NSError *)setParameter:(UInt32)parameterID name:(NSString *)newName
{
	self.receivedName = newName;
	self.setNameCallCount += 1;
	return nil;
}

@end

/*! Stands in for the host's FxParameterRetrievalAPI_v6 string readback. */
@interface FxI18NTestStubRetrievalAPI : NSObject
@property (nonatomic, copy) NSString *hostString;
@property (nonatomic, assign) BOOL succeeds;
@end

@implementation FxI18NTestStubRetrievalAPI

- (BOOL)getStringParameterValue:(NSString * _Nullable * _Nonnull)string fromParameter:(UInt32)parameterID
{
	if (string) {
		*string = self.hostString;
	}
	return self.succeeds;
}

@end

/*!
	A mutable dictionary that records the keys written to it. The I18N handlers write a value
	that a strings-table-free process maps to itself, so the recorded write is the evidence
	that a handler ran and the level at which it wrote.
*/
@interface FxI18NTestRecordingDictionary : NSMutableDictionary
@property (nonatomic, strong) NSMutableArray<NSString *> *writtenKeys;
+ (instancetype)dictionaryWithSeededContents:(NSDictionary *)contents;
@end

// NSMutableDictionary is a class cluster: a subclass implements the primitive methods and
// initializes through -init on the abstract superclass.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation FxI18NTestRecordingDictionary {
	NSMutableDictionary *_storage;
}

+ (instancetype)dictionaryWithSeededContents:(NSDictionary *)contents
{
	FxI18NTestRecordingDictionary *dictionary = [self.alloc initWithCapacity:contents.count];
	[dictionary->_storage addEntriesFromDictionary:contents];
	return dictionary;
}

- (instancetype)init
{
	return [self initWithCapacity:0];
}

- (instancetype)initWithCapacity:(NSUInteger)numItems
{
	self = [super init];
	if (self) {
		_storage = [NSMutableDictionary dictionaryWithCapacity:numItems];
		_writtenKeys = NSMutableArray.new;
	}
	return self;
}

- (instancetype)initWithObjects:(const id _Nonnull __unsafe_unretained [_Nullable])objects
						forKeys:(const id<NSCopying> _Nonnull __unsafe_unretained [_Nullable])keys
						  count:(NSUInteger)count
{
	self = [self initWithCapacity:count];
	if (self) {
		for (NSUInteger index = 0; index < count; index++) {
			[_storage setObject:objects[index] forKey:keys[index]];
		}
	}
	return self;
}

- (NSUInteger)count
{
	return _storage.count;
}

- (id)objectForKey:(id)key
{
	return [_storage objectForKey:key];
}

- (NSEnumerator *)keyEnumerator
{
	return [_storage keyEnumerator];
}

- (void)setObject:(id)object forKey:(id<NSCopying>)key
{
	[self.writtenKeys addObject:(NSString *)key];
	[_storage setObject:object forKey:key];
}

- (void)removeObjectForKey:(id)key
{
	[self.writtenKeys addObject:(NSString *)key];
	[_storage removeObjectForKey:key];
}

@end

#pragma clang diagnostic pop

/*!
	FxTileableEffectBase's designated initializer registers into the process-wide
	notification center, so the wrappers and the extension are exercised against a stub
	carrying an isolated notifier. The wrappers read -notifier and subscript the effect
	for the notification object; FxExtensionBase reads -addedToDocument and FxGripI18N
	reads -pluginProperties during load.
*/
@interface FxI18NTestStubEffect : NSObject
@property (nonatomic, assign) BOOL addedToDocument;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, strong) NSDictionary<NSString *, id> *pluginProperties;
@end

@implementation FxI18NTestStubEffect

- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxI18NTestMakePriorityCenter();
		_pluginProperties = @{};
	}
	return self;
}

- (id)objectAtIndexedSubscript:(NSInteger)index
{
	return nil;
}

@end

// Supplies a fixture localization table so the localize/delocalize round-trip is testable
// without a strings file on disk. The default localizationTable reads the plugin bundle,
// which a headless test process has no fixture for.
@interface FxI18NTestFixtureTable : FxGripI18N
@end

@implementation FxI18NTestFixtureTable
- (NSDictionary<NSString *, NSString *> *)localizationTable
{
	return @{@"Greeting": @"Bonjour", @"Farewell": @"Au revoir"};
}
@end

#pragma mark - Tests

@interface FxGripI18NTests : XCTestCase
@property (nonatomic, strong) FxI18NTestStubEffect *effect;
@property (nonatomic, strong) FxI18NTestStubDynamicAPI *dynamicStub;
@property (nonatomic, strong) FxI18NTestStubRetrievalAPI *retrievalStub;
@property (nonatomic, strong) NSMutableArray *observerTokens;
// The notifier holds its observers weakly, so a loaded extension is retained for the
// lifetime of the test.
@property (nonatomic, strong) FxGripI18N *extension;
@end

@implementation FxGripI18NTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxI18NTestStubEffect.alloc init];
	self.dynamicStub = [FxI18NTestStubDynamicAPI.alloc init];
	self.retrievalStub = [FxI18NTestStubRetrievalAPI.alloc init];
	self.observerTokens = NSMutableArray.new;
}

- (void)tearDown
{
	for (id token in self.observerTokens) {
		[self.effect.notifier removeObserver:token];
	}
	self.observerTokens = nil;
	self.extension = nil;
	self.retrievalStub = nil;
	self.dynamicStub = nil;
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

/*!
	Registers a synchronous observer on the effect's isolated notifier. The object filter is
	nil because a wrapper posts against the parameter object it subscripts from the effect,
	which the stub reports as nil.
*/
- (void)observeName:(NSNotificationName)name usingBlock:(void (^)(NSNotification *notification))block
{
	id token = [self.effect.notifier addObserverForName:name object:nil queue:nil usingBlock:block];
	[self.observerTokens addObject:token];
}

- (FxGripDynamicParameterAPI_v3 *)dynamicAPIv3
{
	return [FxGripDynamicParameterAPI_v3.alloc initWithAPI:(id)self.dynamicStub effect:(id)self.effect];
}

- (FxGripDynamicParameterAPI_v4 *)dynamicAPIv4
{
	return [FxGripDynamicParameterAPI_v4.alloc initWithAPI:(id)self.dynamicStub effect:(id)self.effect];
}

- (FxGripParameterRetrievalAPI_v6 *)retrievalAPIv6
{
	return [FxGripParameterRetrievalAPI_v6.alloc initWithAPI:(id)self.retrievalStub
										  dynamicParamAPIv4:nil
													 effect:(id)self.effect];
}

/*! Loads an I18N extension against the stub effect carrying the given plist properties. */
- (FxGripI18N *)loadedI18NWithProperties:(NSDictionary *)properties
{
	self.effect.pluginProperties = properties;
	self.extension = [FxGripI18N.alloc init];
	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect]);
	return self.extension;
}

/*! The thin payload the wrappers post: an ID at both levels plus the property in play. */
- (FxI18NTestRecordingDictionary *)userInfoWithNestedParameter:(NSMutableDictionary *)parameter
{
	return [FxI18NTestRecordingDictionary dictionaryWithSeededContents:@{
		kFxParameterProperty_Id: @(kI18NTestParameter),
		FxNotifyAPI_ParameterKey: parameter
	}];
}

/*! A nested parameter dictionary carrying the ID plus the property under test. */
- (FxI18NTestRecordingDictionary *)nestedParameterWithProperty:(NSString *)key value:(id)value
{
	NSMutableDictionary *contents = @{kFxParameterProperty_Id: @(kI18NTestParameter)}.mutableCopy;
	if (value) {
		contents[key] = value;
	}
	return [FxI18NTestRecordingDictionary dictionaryWithSeededContents:contents];
}

#pragma mark Wrapper Mutation Round-Trips

- (void)testDynamicAPIv3GetNameReturnsTheNameTheObserverRewrote
{
	self.dynamicStub.hostName = @"HostName";
	__block BOOL nestedWasMutable = NO;
	[self observeName:FxNotifyAPI_ParameterGetNameName usingBlock:^(NSNotification *notification) {
		NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
		nestedWasMutable = parameter != nil;
		XCTAssertEqualObjects(parameter[kFxParameterProperty_Name], @"HostName");
		parameter[kFxParameterProperty_Name] = @"Delocalized";
	}];

	NSString *name = nil;
	NSError *error = [self.dynamicAPIv3 parameter:kI18NTestParameter name:&name];

	XCTAssertNil(error);
	XCTAssertTrue(nestedWasMutable);
	XCTAssertEqualObjects(name, @"Delocalized");
}

- (void)testDynamicAPIv3GetNameWithoutObserversReturnsTheHostName
{
	self.dynamicStub.hostName = @"HostName";

	NSString *name = nil;
	NSError *error = [self.dynamicAPIv3 parameter:kI18NTestParameter name:&name];

	XCTAssertNil(error);
	XCTAssertEqualObjects(name, @"HostName", @"the readback reads the thin payload directly");
}

- (void)testDynamicAPIv3SetNameForwardsTheNameTheObserverRewrote
{
	__block BOOL nestedWasMutable = NO;
	[self observeName:FxNotifyAPI_ParameterSetNamePreName usingBlock:^(NSNotification *notification) {
		NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
		nestedWasMutable = parameter != nil;
		XCTAssertEqualObjects(parameter[kFxParameterProperty_Name], @"Original");
		parameter[kFxParameterProperty_Name] = @"Localized";
	}];

	NSError *error = [self.dynamicAPIv3 setParameter:kI18NTestParameter name:@"Original"];

	XCTAssertNil(error);
	XCTAssertTrue(nestedWasMutable);
	XCTAssertEqual(self.dynamicStub.setNameCallCount, (NSUInteger)1);
	XCTAssertEqualObjects(self.dynamicStub.receivedName, @"Localized");
}

- (void)testDynamicAPIv4EntriesReturnTheEntriesTheObserverMapped
{
	// parameter:entries: asks no host API: the entries come from the observers alone, so
	// the stub's entries are supplied through the observer that maps them.
	self.dynamicStub.hostEntries = @[@"One", @"Two"];
	__block NSArray *seededEntries = nil;
	[self observeName:FxNotifyAPI_ParameterGetMenuName usingBlock:^(NSNotification *notification) {
		NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
		seededEntries = parameter[kFxParameterProperty_MenuItems];
		NSMutableArray *mapped = NSMutableArray.new;
		for (NSString *entry in self.dynamicStub.hostEntries) {
			[mapped addObject:[entry stringByAppendingString:@"-loc"]];
		}
		parameter[kFxParameterProperty_MenuItems] = mapped.copy;
	}];

	NSArray<NSString *> *entries = nil;
	NSError *error = [self.dynamicAPIv4 parameter:kI18NTestParameter entries:&entries];

	XCTAssertNil(error);
	XCTAssertEqualObjects(seededEntries, @[]);
	XCTAssertEqualObjects(entries, (@[@"One-loc", @"Two-loc"]));
}

- (void)testRetrievalAPIv6StringValueReturnsTheValueTheObserverRewrote
{
	self.retrievalStub.hostString = @"HostValue";
	self.retrievalStub.succeeds = YES;
	__block BOOL nestedWasMutable = NO;
	[self observeName:FxNotifyAPI_ParameterGetStringValueName usingBlock:^(NSNotification *notification) {
		NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
		nestedWasMutable = parameter != nil;
		XCTAssertEqualObjects(parameter[kFxParameterProperty_Default], @"HostValue");
		parameter[kFxParameterProperty_Default] = @"Rewritten";
	}];

	NSString *value = nil;
	BOOL success = [self.retrievalAPIv6 getStringParameterValue:&value fromParameter:kI18NTestParameter];

	XCTAssertTrue(success);
	XCTAssertTrue(nestedWasMutable, @"the posted nested dictionary is mutable");
	XCTAssertEqualObjects(value, @"Rewritten");
}

#pragma mark Delocalization Gating

- (void)testInitEnablesEveryLocalizationAndDelocalizationFlag
{
	FxGripI18N *extension = [FxGripI18N.alloc init];

	XCTAssertTrue(extension.isLocalizingNames);
	XCTAssertTrue(extension.isLocalizingValues);
	XCTAssertTrue(extension.isLocalizingMenus);
	XCTAssertTrue(extension.isDelocalizingNames);
	XCTAssertTrue(extension.isDelocalizingValues);
	XCTAssertTrue(extension.isDelocalizingMenus);
}

- (void)testLoadWithDelocalizeNamesDisabledCascadesToValuesAndMenus
{
	FxGripI18N *extension = [self loadedI18NWithProperties:@{kProPlugPlugInX_DelocalizeNamesProperty: @NO}];

	XCTAssertFalse(extension.isDelocalizingNames);
	XCTAssertFalse(extension.isDelocalizingValues);
	XCTAssertFalse(extension.isDelocalizingMenus);
	XCTAssertTrue(extension.isLocalizingNames, @"the localization flags are independent of the plist gating");
}

- (void)testLoadWithDelocalizeValuesEnabledCascadesToMenusOnly
{
	FxGripI18N *extension = [self loadedI18NWithProperties:@{
		kProPlugPlugInX_DelocalizeNamesProperty: @NO,
		kProPlugPlugInX_DelocalizeValuesProperty: @YES
	}];

	XCTAssertFalse(extension.isDelocalizingNames);
	XCTAssertTrue(extension.isDelocalizingValues);
	XCTAssertTrue(extension.isDelocalizingMenus);
}

#pragma mark Handlers

- (void)testSetNamePreHandlerWritesTheNestedParameterAndLeavesTheOuterUserInfo
{
	[self loadedI18NWithProperties:@{}];
	FxI18NTestRecordingDictionary *parameter = [self nestedParameterWithProperty:kFxParameterProperty_Name
																		  value:@"FxGripI18NTestName"];
	FxI18NTestRecordingDictionary *userInfo = [self userInfoWithNestedParameter:parameter];

	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetNamePreName
										object:self.effect
									  userInfo:userInfo];

	XCTAssertEqualObjects(parameter.writtenKeys, @[kFxParameterProperty_Name],
						  @"the handler writes the name at the nested level");
	XCTAssertEqualObjects(userInfo.writtenKeys, @[], @"the outer userInfo is left alone");
	XCTAssertTrue([parameter[kFxParameterProperty_Name] isKindOfClass:NSString.class]);
	// Without a strings table NSLocalizedString returns the key, so the value is unchanged.
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Name], @"FxGripI18NTestName");
	XCTAssertNil(userInfo[kFxParameterProperty_Name]);
}

- (void)testSetNamePreHandlerIgnoresAMissingOrNonStringName
{
	[self loadedI18NWithProperties:@{}];

	FxI18NTestRecordingDictionary *nameless = [self nestedParameterWithProperty:kFxParameterProperty_Name value:nil];
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetNamePreName
										object:self.effect
									  userInfo:[self userInfoWithNestedParameter:nameless]];

	XCTAssertEqualObjects(nameless.writtenKeys, @[]);
	XCTAssertNil(nameless[kFxParameterProperty_Name]);

	FxI18NTestRecordingDictionary *numeric = [self nestedParameterWithProperty:kFxParameterProperty_Name value:@42];
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetNamePreName
										object:self.effect
									  userInfo:[self userInfoWithNestedParameter:numeric]];

	XCTAssertEqualObjects(numeric.writtenKeys, @[]);
	XCTAssertEqualObjects(numeric[kFxParameterProperty_Name], @42);
}

- (void)testSetMenuPreHandlerMapsTheNestedMenuItemsArray
{
	[self loadedI18NWithProperties:@{}];
	FxI18NTestRecordingDictionary *parameter =
		[self nestedParameterWithProperty:kFxParameterProperty_MenuItems
									value:@[@"FxGripI18NTestAlpha", @"FxGripI18NTestBeta"]];
	FxI18NTestRecordingDictionary *userInfo = [self userInfoWithNestedParameter:parameter];

	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetMenuPreName
										object:self.effect
									  userInfo:userInfo];

	XCTAssertEqualObjects(parameter.writtenKeys, @[kFxParameterProperty_MenuItems]);
	XCTAssertEqualObjects(userInfo.writtenKeys, @[]);

	NSArray *entries = parameter[kFxParameterProperty_MenuItems];
	XCTAssertTrue([entries isKindOfClass:NSArray.class]);
	XCTAssertEqual(entries.count, (NSUInteger)2);
	// Without a strings table NSLocalizedString returns each key unchanged.
	XCTAssertEqualObjects(entries, (@[@"FxGripI18NTestAlpha", @"FxGripI18NTestBeta"]));
}

- (void)testSetMenuPreHandlerIgnoresNonArrayMenuItems
{
	[self loadedI18NWithProperties:@{}];
	FxI18NTestRecordingDictionary *parameter = [self nestedParameterWithProperty:kFxParameterProperty_MenuItems
																		  value:@"nope"];

	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetMenuPreName
										object:self.effect
									  userInfo:[self userInfoWithNestedParameter:parameter]];

	XCTAssertEqualObjects(parameter.writtenKeys, @[]);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_MenuItems], @"nope");
}

- (void)testDelocalizePassesThroughStringsAbsentFromTheTable
{
	FxGripI18N *extension = [FxGripI18N.alloc init];

	XCTAssertEqualObjects([extension delocalize:@"abc"], @"abc");
	XCTAssertNil([extension delocalize:nil]);
}

- (void)testLocalizeAndDelocalizeRoundTripThroughTheSameTable
{
	FxI18NTestFixtureTable *extension = [FxI18NTestFixtureTable.alloc init];

	XCTAssertEqualObjects([extension localize:@"Greeting"], @"Bonjour");
	XCTAssertEqualObjects([extension delocalize:@"Bonjour"], @"Greeting");
	// The forward and reverse paths share one table, so a round-trip closes.
	XCTAssertEqualObjects([extension delocalize:[extension localize:@"Farewell"]], @"Farewell");
	// An entry absent from the table passes through unchanged in both directions.
	XCTAssertEqualObjects([extension localize:@"Unknown"], @"Unknown");
	XCTAssertEqualObjects([extension delocalize:@"Unknown"], @"Unknown");
}

#pragma mark Init UserInfo Accessor

- (void)testApiManagerReturnsTheObjectCarriedByTheInitNotification
{
	NSObject *manager = NSObject.new;
	NSDictionary *userInfo = @{FxTileableEffectInitAPIManagerKey: manager};

	XCTAssertTrue((id)[userInfo fxApiManager] == (id)manager);
}

- (void)testApiManagerIsNilWhenTheInitNotificationCarriesNoManager
{
	XCTAssertNil([@{} fxApiManager]);
}

@end
