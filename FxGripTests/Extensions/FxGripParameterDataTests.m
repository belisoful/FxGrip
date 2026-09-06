/*!
	@file       FxGripParameterDataTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterDataTests
	@abstract   Unit tests for the FxGripParameterData extension record cache.
	@discussion Introduced in FxGrip 0.1.0. Stub host API objects supply the stored document value and record the flush writes. The tests cover the hidden ParameterData parameter registration and handler priorities, the record seeding from the creation-API payload, the flag merge and store passes, the menu-item store, the stored accessors, removal, document load, direct record access, and the flush that persists the cache.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <FxGrip/FxGripParameterData.h>

static const FxParameterId kPDataTestParamA = 21;
static const FxParameterId kPDataTestParamB = 22;

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxGripPDataTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

/*!
	The payload the creation API posts: the parameter dictionary sits under
	FxGripNotifyAPI_ParameterKey and the top level repeats the ID. The nested dictionary is
	mutable, matching FxGripParameterCreationAPI_v5.
*/
static NSMutableDictionary *FxGripPDataTestAddUserInfo(FxParameterId parameterID)
{
	return @{
		kFxParameterProperty_Id: @(parameterID),
		FxGripNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_Type: @(FxParameterType_Float),
			kFxParameterProperty_Name: @"Test Parameter",
			kFxParameterProperty_ParentId: @(kFxParameterId_TopLevelGroup),
			kFxParameterProperty_Flags: @(kFxParameterFlag_DISABLED | kFxParameterFlag_NOT_ANIMATABLE),
			kFxParameterProperty_Selector: @"clickTestParameter"
		}.mutableCopy
	}.mutableCopy;
}

static NSNotification *FxGripPDataTestNotification(NSNotificationName name, id object, NSDictionary *userInfo)
{
	return [NSNotification notificationWithName:name object:object userInfo:userInfo];
}

/*! Builds the userInfo shape the flag and menu handlers read. */
static NSMutableDictionary *FxGripPDataTestParameterUserInfo(FxParameterId parameterID, NSDictionary *entries)
{
	NSMutableDictionary *parameter = @{kFxParameterProperty_Id: @(parameterID)}.mutableCopy;
	[parameter addEntriesFromDictionary:entries];
	return @{
		kFxParameterProperty_Id: @(parameterID),
		FxGripNotifyAPI_ParameterKey: parameter
	}.mutableCopy;
}

#pragma mark - Test doubles

// Records every custom-value write the flush performs.
@interface FxGripPDataTestStubSetAPI : NSObject
@property (nonatomic, strong) NSMutableArray *values;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *parameterIDs;
@end

@implementation FxGripPDataTestStubSetAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_values = NSMutableArray.new;
		_parameterIDs = NSMutableArray.new;
	}
	return self;
}

- (BOOL)setCustomParameterValue:(NSObject<NSSecureCoding, NSCopying> *)value
					toParameter:(UInt32)parameterID
						 atTime:(CMTime)time
{
	[self.values addObject:value ?: NSNull.null];
	[self.parameterIDs addObject:@(parameterID)];
	return YES;
}

@end

// Hands the extension the dictionary stored in the document.
@interface FxGripPDataTestStubGetAPI : NSObject
@property (nonatomic, strong) NSObject<NSSecureCoding, NSCopying> *storedValue;
@property (nonatomic, assign) FxParameterId lastRequestedParameter;
@property (nonatomic, assign) NSUInteger requestCount;
@end

@implementation FxGripPDataTestStubGetAPI

- (BOOL)getCustomParameterValue:(NSObject<NSSecureCoding, NSCopying> * _Nullable * _Nonnull)value
				  fromParameter:(UInt32)parameterID
						 atTime:(CMTime)time
{
	self.lastRequestedParameter = parameterID;
	self.requestCount += 1;
	if (!self.storedValue) {
		return NO;
	}
	*value = self.storedValue;
	return YES;
}

@end

@interface FxGripPDataTestStubAPIManager : NSObject
@property (nonatomic, strong) FxGripPDataTestStubGetAPI *paramGetAPIv6;
@property (nonatomic, strong) FxGripPDataTestStubSetAPI *paramSetAPIv5;
@end

@implementation FxGripPDataTestStubAPIManager
@end

// FxGripTileableEffect's designated initializer registers into the process-wide
// notification center, so the extension is exercised against a stub exposing the
// members FxGripParameterData reads.
@interface FxGripPDataTestStubEffect : NSObject
@property (nonatomic, assign) BOOL addedToDocument;
@property (nonatomic, assign) BOOL addedParameters;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, strong) FxGripPDataTestStubAPIManager *apiManager;
@end

@implementation FxGripPDataTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxGripPDataTestMakePriorityCenter();
		_apiManager = FxGripPDataTestStubAPIManager.new;
		_apiManager.paramGetAPIv6 = FxGripPDataTestStubGetAPI.new;
		_apiManager.paramSetAPIv5 = FxGripPDataTestStubSetAPI.new;
	}
	return self;
}

@end

#pragma mark - Tests

@interface FxGripParameterDataTests : XCTestCase
@property (nonatomic, strong) FxGripParameterData *extension;
@property (nonatomic, strong) FxGripPDataTestStubEffect *effect;
@end

@implementation FxGripParameterDataTests

- (void)setUp
{
	[super setUp];
	self.extension = [FxGripParameterData.alloc init];
	self.effect = [FxGripPDataTestStubEffect.alloc init];
	[self.extension extLoadWithEffect:(id)self.effect];
}

- (void)tearDown
{
	self.extension = nil;
	self.effect = nil;
	[super tearDown];
}

- (FxGripPDataTestStubSetAPI *)setAPI
{
	return self.effect.apiManager.paramSetAPIv5;
}

- (FxGripPDataTestStubGetAPI *)getAPI
{
	return self.effect.apiManager.paramGetAPIv6;
}

/*! Drives one creation-API notification, returning the payload that was posted. */
- (NSMutableDictionary *)seedParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *userInfo = FxGripPDataTestAddUserInfo(parameterID);
	[self.extension extAPIParameterAdd:FxGripPDataTestNotification(FxGripNotifyAPI_ParameterAddName,
															   self.effect,
															   userInfo)];
	return userInfo;
}

/*! Marks the extension as belonging to a live parameter so the handlers flush eagerly. */
- (void)attachToLiveParameter
{
	[self.extension parameterForDictionary:@{
		kFxParameterProperty_Id: @(kFxParameterId_ParameterData),
		kFxParameterProperty_Type: kFxParameterType_Custom,
		kFxParameterProperty_Name: @"Plugin Parameter Data",
		kFxParameterProperty_Flags: @(0)
	}];
	// The extension tracks document entry from the notification, as it does under the base.
	[self.effect.notifier postNotificationName:FxGripTileableEffectAddedToDocumentName object:self.effect];
}

#pragma mark Registration

/*! @abstract A freshly initialized extension targets the ParameterData parameter id, starts unloaded and clean, and keys to its class name. */
- (void)testInitTargetsTheParameterDataParameterAndStartsUnloaded
{
	FxGripParameterData *extension = [FxGripParameterData.alloc init];

	XCTAssertEqual(extension.parameterID, (FxParameterId)kFxParameterId_ParameterData);
	XCTAssertEqual(extension.parameterID, (FxParameterId)9998);
	XCTAssertFalse(extension.isLoaded);
	XCTAssertFalse(extension.isCacheDirty);
	XCTAssertNil(extension.data);
	XCTAssertEqualObjects(extension.extKey, @"FxGripParameterData");
}

/*! @abstract The handler priorities order the add, added-to-document, and flush passes around the effect's own passes. */
- (void)testHandlerPriorityOrdersTheRecordPassesAroundTheEffect
{
	XCTAssertEqual([self.extension ncPriority:FxGripNotifyAPI_ParameterAddName], (NSInteger)-20);
	XCTAssertEqual([self.extension ncPriority:FxGripTileableEffectAddedToDocumentName], (NSInteger)-18);
	// Flush persists AFTER the base's −14 flag flush so it captures the flag words that
	// pass writes; a value at or before −14 would flush a store re-dirtied moments later.
	XCTAssertEqual([self.extension ncPriority:FxGripTileableEffectFlushName], (NSInteger)-13);
	XCTAssertEqual([self.extension ncPriority:FxGripTileableEffectInitName], FxGripExtensionDefaultPriority);
	XCTAssertEqual([self.extension ncPriority:nil], FxGripExtensionDefaultPriority);
}

/*! @abstract Adding parameters registers the hidden custom ParameterData parameter with its factory and hidden, no-state flags. */
- (void)testExtAddParametersRegistersTheHiddenParameterDataParameter
{
	NSMutableArray *parameters = NSMutableArray.new;

	[self.extension extAddParameters:FxGripPDataTestNotification(FxGripTileableEffectAddParametersName,
															 self.effect,
															 @{FxGripTileableEffectParametersKey: parameters})];

	XCTAssertEqual(parameters.count, (NSUInteger)1);

	NSDictionary *parameter = parameters.firstObject;
	XCTAssertTrue([parameter isKindOfClass:NSMutableDictionary.class],
				  @"the effect edits the registration entry in place");
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Factory], self.extension);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Id], @(kFxParameterId_ParameterData));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Name], @"Plugin Parameter Data");
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], kFxParameterType_Custom);

	NSArray *flags = parameter[kFxParameterProperty_Flags];
	XCTAssertTrue([flags containsObject:kParameterFlagString_DONT_DISPLAY]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_HIDDEN]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_NOT_ANIMATABLE]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_NO_DEBUG]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_NO_STATE]);
}

#pragma mark Record Seeding

/*! @abstract A parameter add seeds the record from the nested payload and marks the cache loaded and dirty. */
- (void)testParameterAddSeedsTheRecordFromTheNestedPayload
{
	[self seedParameter:kPDataTestParamA];

	XCTAssertTrue(self.extension.isLoaded);
	XCTAssertTrue(self.extension.isCacheDirty);

	NSDictionary *record = self.extension.data[@(kPDataTestParamA)];
	XCTAssertNotNil(record);
	XCTAssertEqualObjects(record[kFxParameterProperty_Id], @(kPDataTestParamA));
	XCTAssertEqualObjects(record[kFxParameterProperty_Name], @"Test Parameter");
}

/*! @abstract A parameter add falls back to the top-level id when the nested payload omits it. */
- (void)testParameterAddFallsBackToTheTopLevelIdWhenTheNestedPayloadOmitsIt
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(kPDataTestParamA),
		FxGripNotifyAPI_ParameterKey: @{kFxParameterProperty_Name: @"No Nested Id"}.mutableCopy
	}.mutableCopy;

	[self.extension extAPIParameterAdd:FxGripPDataTestNotification(FxGripNotifyAPI_ParameterAddName,
															   self.effect,
															   userInfo)];

	XCTAssertNotNil(self.extension.data[@(kPDataTestParamA)]);
	XCTAssertEqualObjects(self.extension.data[@(kPDataTestParamA)][kFxParameterProperty_Name], @"No Nested Id");
}

/*! @abstract A parameter add carrying no id at either level seeds nothing and leaves the cache unloaded. */
- (void)testParameterAddWithoutAnyIdSeedsNothing
{
	[self.extension extAPIParameterAdd:FxGripPDataTestNotification(FxGripNotifyAPI_ParameterAddName,
															   self.effect,
															   @{FxGripNotifyAPI_ParameterKey: @{}.mutableCopy})];

	XCTAssertFalse(self.extension.isLoaded);
	XCTAssertFalse(self.extension.isCacheDirty);
}

/*! @abstract A parameter add stores a copy detached from the posted payload, so mutating the payload afterward does not change the record. */
- (void)testParameterAddStoresACopyDetachedFromThePostedPayload
{
	NSMutableDictionary *userInfo = [self seedParameter:kPDataTestParamA];

	NSMutableDictionary *posted = userInfo[FxGripNotifyAPI_ParameterKey];
	posted[kFxParameterProperty_Name] = @"Renamed After The Post";

	XCTAssertEqualObjects(self.extension.data[@(kPDataTestParamA)][kFxParameterProperty_Name],
						  @"Test Parameter");
}

/*! @abstract A parameter add replaces an earlier record for the same parameter, discarding its stored custom entries. */
- (void)testParameterAddReplacesAnEarlierRecordForTheSameParameter
{
	[self seedParameter:kPDataTestParamA];
	[self.extension setObject:@"stale" forKey:@"custom" toParameter:kPDataTestParamA];

	[self seedParameter:kPDataTestParamA];

	XCTAssertNil([self.extension objectForKey:@"custom" fromParameter:kPDataTestParamA]);
	XCTAssertEqual(self.extension.data.count, (NSUInteger)1);
}

/*! @abstract A parameter add flushes the cache immediately once the parameter is live in the document. */
- (void)testParameterAddFlushesImmediatelyOnceTheParameterIsLiveInTheDocument
{
	[self attachToLiveParameter];

	[self seedParameter:kPDataTestParamA];

	XCTAssertEqual(self.setAPI.values.count, (NSUInteger)1);
	XCTAssertEqualObjects(self.setAPI.parameterIDs.firstObject, @(kFxParameterId_ParameterData));
	XCTAssertFalse(self.extension.isCacheDirty);
}

/*! @abstract A parameter add defers the write and leaves the cache dirty while the effect is not yet in the document. */
- (void)testParameterAddDefersTheWriteWhileTheEffectIsNotInTheDocument
{
	[self seedParameter:kPDataTestParamA];

	XCTAssertEqual(self.setAPI.values.count, (NSUInteger)0);
	XCTAssertTrue(self.extension.isCacheDirty);
}

#pragma mark Stored Accessors

/*! @abstract The stored accessors read back the type, flags, parent id, and selector the seeding stored, with nil menus. */
- (void)testStoredAccessorsReadBackTheEntriesTheSeedingStored
{
	[self seedParameter:kPDataTestParamA];

	XCTAssertEqual([self.extension storedType:kPDataTestParamA], FxParameterType_Float);
	XCTAssertEqual([self.extension storedFlags:kPDataTestParamA],
				   (FxParameterFlags)(kFxParameterFlag_DISABLED | kFxParameterFlag_NOT_ANIMATABLE));
	XCTAssertEqual([self.extension storedParentId:kPDataTestParamA], (FxParameterId)kFxParameterId_TopLevelGroup);
	XCTAssertEqualObjects([self.extension storedSelector:kPDataTestParamA], @"clickTestParameter");
	XCTAssertNil([self.extension storedMenus:kPDataTestParamA]);
}

/*! @abstract The record key constants equal the matching parameter-property key constants. */
- (void)testStoredAccessorsAndTheRecordKeysNameTheSameEntries
{
	XCTAssertEqualObjects(kExtParameterData_Type, kFxParameterProperty_Type);
	XCTAssertEqualObjects(kExtParameterData_Flag, kFxParameterProperty_Flags);
	XCTAssertEqualObjects(kExtParameterData_SubGroup, kFxParameterProperty_ParentId);
	XCTAssertEqualObjects(kExtParameterData_MenuItems, kFxParameterProperty_MenuItems);
	XCTAssertEqualObjects(kExtParameterData_Selector, kFxParameterProperty_Selector);
	XCTAssertEqualObjects(kExtParameterData_MenuItems, @"items");
}

/*! @abstract The stored accessors return sentinel values before anything is seeded. */
- (void)testStoredAccessorsReturnSentinelsBeforeAnythingIsSeeded
{
	XCTAssertEqual([self.extension storedType:kPDataTestParamA], (FxParameterType)0);
	XCTAssertEqual([self.extension storedFlags:kPDataTestParamA], (FxParameterFlags)0);
	XCTAssertEqual([self.extension storedParentId:kPDataTestParamA], (FxParameterId)-1);
	XCTAssertNil([self.extension storedMenus:kPDataTestParamA]);
	XCTAssertNil([self.extension storedSelector:kPDataTestParamA]);
}

/*! @abstract The stored accessors return sentinel values for a parameter with no record. */
- (void)testStoredAccessorsReturnSentinelsForAnUnknownParameter
{
	[self seedParameter:kPDataTestParamA];

	XCTAssertEqual([self.extension storedType:kPDataTestParamB], (FxParameterType)0);
	XCTAssertEqual([self.extension storedFlags:kPDataTestParamB], (FxParameterFlags)0);
	XCTAssertEqual([self.extension storedParentId:kPDataTestParamB], (FxParameterId)-1);
	XCTAssertNil([self.extension storedMenus:kPDataTestParamB]);
	XCTAssertNil([self.extension storedSelector:kPDataTestParamB]);
}

#pragma mark Flags

/*! @abstract The get-flags handler merges the stored application flag bits into the host payload flags. */
- (void)testGetFlagsMergesTheStoredApplicationBitsIntoThePayload
{
	[self seedParameter:kPDataTestParamA];
	[self.extension extAPIParameterSetFlags:
		FxGripPDataTestNotification(FxGripNotifyAPI_ParameterSetFlagsName, self.effect,
			FxGripPDataTestParameterUserInfo(kPDataTestParamA,
				@{kFxParameterProperty_Flags: @(kFxParameterFlag_NO_DEBUG | kFxParameterFlag_HIDDEN_PROXY)}))];

	NSMutableDictionary *userInfo = FxGripPDataTestParameterUserInfo(kPDataTestParamA,
		@{kFxParameterProperty_Flags: @(kFxParameterFlag_DISABLED)});
	[self.extension extAPIParameterGetFlags:
		FxGripPDataTestNotification(FxGripNotifyAPI_ParameterGetFlagsName, self.effect, userInfo)];

	FxParameterFlags merged = ((NSNumber *)userInfo.fxParameter[kFxParameterProperty_Flags]).unsignedIntValue;
	XCTAssertEqual(merged, (FxParameterFlags)(kFxParameterFlag_DISABLED
											  | kFxParameterFlag_NO_DEBUG
											  | kFxParameterFlag_HIDDEN_PROXY));
}

/*! @abstract The get-flags handler leaves the host flags unchanged when the record carries no flags. */
- (void)testGetFlagsLeavesTheHostBitsAloneWhenTheRecordCarriesNoFlags
{
	[self.extension extAPIParameterAdd:FxGripPDataTestNotification(FxGripNotifyAPI_ParameterAddName, self.effect,
		@{
			kFxParameterProperty_Id: @(kPDataTestParamA),
			FxGripNotifyAPI_ParameterKey: @{kFxParameterProperty_Id: @(kPDataTestParamA)}.mutableCopy
		})];

	NSMutableDictionary *userInfo = FxGripPDataTestParameterUserInfo(kPDataTestParamA,
		@{kFxParameterProperty_Flags: @(kFxParameterFlag_DISABLED)});
	[self.extension extAPIParameterGetFlags:
		FxGripPDataTestNotification(FxGripNotifyAPI_ParameterGetFlagsName, self.effect, userInfo)];

	XCTAssertEqualObjects(userInfo.fxParameter[kFxParameterProperty_Flags], @(kFxParameterFlag_DISABLED));
}

/*! @abstract The get-flags handler leaves the host flags unchanged for a parameter with no record. */
- (void)testGetFlagsLeavesTheHostBitsAloneForAnUnknownParameter
{
	[self seedParameter:kPDataTestParamA];

	NSMutableDictionary *userInfo = FxGripPDataTestParameterUserInfo(kPDataTestParamB,
		@{kFxParameterProperty_Flags: @(kFxParameterFlag_DISABLED)});
	[self.extension extAPIParameterGetFlags:
		FxGripPDataTestNotification(FxGripNotifyAPI_ParameterGetFlagsName, self.effect, userInfo)];

	XCTAssertEqualObjects(userInfo.fxParameter[kFxParameterProperty_Flags], @(kFxParameterFlag_DISABLED));
}

/*! @abstract The set-flags handler stores only the application flag bits, dropping the host and temporary bits, and marks the cache dirty. */
- (void)testSetFlagsStoresOnlyTheApplicationBits
{
	[self seedParameter:kPDataTestParamA];
	[self.extension extFlush:FxGripPDataTestNotification(FxGripTileableEffectFlushName, self.effect, nil)];

	FxParameterFlags notified = kFxParameterFlag_DISABLED			// host bit, dropped
							  | kFxParameterFlag_CACHE				// temp bit, dropped
							  | kFxParameterFlag_CACHEDIRTY			// temp bit, dropped
							  | kFxParameterFlag_SAVING				// temp bit, dropped
							  | kFxParameterFlag_NO_DEBUG			// application bit, kept
							  | kFxParameterFlag_PRESETNOMETA;		// application bit, kept
	[self.extension extAPIParameterSetFlags:
		FxGripPDataTestNotification(FxGripNotifyAPI_ParameterSetFlagsName, self.effect,
			FxGripPDataTestParameterUserInfo(kPDataTestParamA, @{kFxParameterProperty_Flags: @(notified)}))];

	XCTAssertEqual([self.extension storedFlags:kPDataTestParamA],
				   (FxParameterFlags)(kFxParameterFlag_NO_DEBUG | kFxParameterFlag_PRESETNOMETA));
	XCTAssertTrue(self.extension.isCacheDirty);
}

/*! @abstract The set-flags handler ignores a parameter with no record and leaves the cache clean. */
- (void)testSetFlagsIgnoresAParameterWithNoRecord
{
	[self seedParameter:kPDataTestParamA];
	[self.extension extFlush:FxGripPDataTestNotification(FxGripTileableEffectFlushName, self.effect, nil)];

	[self.extension extAPIParameterSetFlags:
		FxGripPDataTestNotification(FxGripNotifyAPI_ParameterSetFlagsName, self.effect,
			FxGripPDataTestParameterUserInfo(kPDataTestParamB, @{kFxParameterProperty_Flags: @(kFxParameterFlag_NO_DEBUG)}))];

	XCTAssertNil(self.extension.data[@(kPDataTestParamB)]);
	XCTAssertFalse(self.extension.isCacheDirty);
}

#pragma mark Menus

/*! @abstract The set-menu handler stores the items under the menu-items key the accessor reads and marks the cache dirty. */
- (void)testSetMenuStoresTheItemsUnderTheKeyTheAccessorReads
{
	[self seedParameter:kPDataTestParamA];
	[self.extension extFlush:FxGripPDataTestNotification(FxGripTileableEffectFlushName, self.effect, nil)];

	NSArray *items = @[@"First", @"-", @"Second"];
	[self.extension extAPIParameterSetMenu:
		FxGripPDataTestNotification(FxGripNotifyAPI_ParameterSetMenuName, self.effect,
			FxGripPDataTestParameterUserInfo(kPDataTestParamA, @{kFxParameterProperty_MenuItems: items}))];

	XCTAssertEqualObjects([self.extension storedMenus:kPDataTestParamA], items);
	XCTAssertEqualObjects(self.extension.data[@(kPDataTestParamA)][kExtParameterData_MenuItems], items);
	XCTAssertTrue(self.extension.isCacheDirty);
}

/*! @abstract The set-menu handler ignores a parameter with no record and leaves the cache clean. */
- (void)testSetMenuIgnoresAParameterWithNoRecord
{
	[self seedParameter:kPDataTestParamA];
	[self.extension extFlush:FxGripPDataTestNotification(FxGripTileableEffectFlushName, self.effect, nil)];

	[self.extension extAPIParameterSetMenu:
		FxGripPDataTestNotification(FxGripNotifyAPI_ParameterSetMenuName, self.effect,
			FxGripPDataTestParameterUserInfo(kPDataTestParamB, @{kFxParameterProperty_MenuItems: @[@"x"]}))];

	XCTAssertNil([self.extension storedMenus:kPDataTestParamB]);
	XCTAssertFalse(self.extension.isCacheDirty);
}

#pragma mark Removal

/*! @abstract A parameter remove drops the record the dynamic API names and leaves the others, marking the cache dirty. */
- (void)testParameterRemoveDropsTheRecordTheDynamicAPINames
{
	[self seedParameter:kPDataTestParamA];
	[self seedParameter:kPDataTestParamB];

	[self.extension extAPIParameterRemove:
		FxGripPDataTestNotification(FxGripNotifyAPI_ParameterRemoveName, self.effect,
			FxGripPDataTestParameterUserInfo(kPDataTestParamA, @{}))];

	XCTAssertNil(self.extension.data[@(kPDataTestParamA)]);
	XCTAssertNotNil(self.extension.data[@(kPDataTestParamB)]);
	XCTAssertTrue(self.extension.isCacheDirty);
}

/*! @abstract A parameter remove before anything is loaded leaves the cache unloaded and clean. */
- (void)testParameterRemoveBeforeAnythingIsLoadedDoesNothing
{
	[self.extension extAPIParameterRemove:
		FxGripPDataTestNotification(FxGripNotifyAPI_ParameterRemoveName, self.effect,
			FxGripPDataTestParameterUserInfo(kPDataTestParamA, @{}))];

	XCTAssertFalse(self.extension.isLoaded);
	XCTAssertFalse(self.extension.isCacheDirty);
}

/*! @abstract A parameter remove flushes the cache immediately once the parameter is live in the document. */
- (void)testParameterRemoveFlushesImmediatelyOnceTheParameterIsLiveInTheDocument
{
	[self seedParameter:kPDataTestParamA];
	[self attachToLiveParameter];

	[self.extension extAPIParameterRemove:
		FxGripPDataTestNotification(FxGripNotifyAPI_ParameterRemoveName, self.effect,
			FxGripPDataTestParameterUserInfo(kPDataTestParamA, @{}))];

	XCTAssertEqual(self.setAPI.values.count, (NSUInteger)1);
	XCTAssertFalse(self.extension.isCacheDirty);
}

#pragma mark Persistence

/*! @abstract Flush writes the cache to the ParameterData parameter once per dirty cycle and skips an unchanged cache. */
- (void)testFlushWritesTheCacheOncePerDirtyCycle
{
	[self seedParameter:kPDataTestParamA];
	XCTAssertTrue(self.extension.isCacheDirty);

	NSNotification *flush = FxGripPDataTestNotification(FxGripTileableEffectFlushName, self.effect, nil);
	[self.extension extFlush:flush];

	XCTAssertEqual(self.setAPI.values.count, (NSUInteger)1);
	XCTAssertEqualObjects(self.setAPI.parameterIDs.firstObject, @(kFxParameterId_ParameterData));
	XCTAssertTrue(self.setAPI.values.firstObject == self.extension.data);
	XCTAssertFalse(self.extension.isCacheDirty);

	[self.extension extFlush:flush];
	XCTAssertEqual(self.setAPI.values.count, (NSUInteger)1, @"an unchanged cache is not written again");

	[self.extension setObject:@"value" forKey:@"custom" toParameter:kPDataTestParamA];
	[self.extension extFlush:flush];
	XCTAssertEqual(self.setAPI.values.count, (NSUInteger)2);
}

/*! @abstract Flush writes nothing before anything is loaded. */
- (void)testFlushWritesNothingBeforeAnythingIsLoaded
{
	[self.extension extFlush:FxGripPDataTestNotification(FxGripTileableEffectFlushName, self.effect, nil)];

	XCTAssertEqual(self.setAPI.values.count, (NSUInteger)0);
}

#pragma mark Document Load

/*! @abstract Added-to-document adopts the dictionary stored in the document and reads its records through the stored accessors. */
- (void)testAddedToDocumentAdoptsTheDictionaryStoredInTheDocument
{
	NSMutableDictionary *stored = @{
		@(kPDataTestParamA): @{kFxParameterProperty_Selector: @"storedSelector"}.mutableCopy
	}.mutableCopy;
	self.getAPI.storedValue = stored;

	[self.extension extAddedToDocument:FxGripPDataTestNotification(FxGripTileableEffectAddedToDocumentName,
															   self.effect, nil)];

	XCTAssertTrue(self.extension.isLoaded);
	XCTAssertTrue(self.extension.data == stored);
	XCTAssertEqual(self.getAPI.lastRequestedParameter, (FxParameterId)kFxParameterId_ParameterData);
	XCTAssertEqualObjects([self.extension storedSelector:kPDataTestParamA], @"storedSelector");
}

/*! @abstract Added-to-document keeps the records seeded before the document arrived and does not replace the seeded cache. */
- (void)testAddedToDocumentKeepsRecordsSeededBeforeTheDocumentArrived
{
	[self seedParameter:kPDataTestParamA];
	self.getAPI.storedValue = @{@(kPDataTestParamB): @{}.mutableCopy}.mutableCopy;

	[self.extension extAddedToDocument:FxGripPDataTestNotification(FxGripTileableEffectAddedToDocumentName,
															   self.effect, nil)];

	XCTAssertNotNil(self.extension.data[@(kPDataTestParamA)]);
	XCTAssertNil(self.extension.data[@(kPDataTestParamB)]);
	XCTAssertEqual(self.getAPI.requestCount, (NSUInteger)0, @"the seeded cache is not replaced");
}

/*! @abstract Added-to-document leaves the cache unloaded when the document holds nothing, after one host read. */
- (void)testAddedToDocumentLeavesTheCacheUnloadedWhenTheDocumentHoldsNothing
{
	[self.extension extAddedToDocument:FxGripPDataTestNotification(FxGripTileableEffectAddedToDocumentName,
															   self.effect, nil)];

	XCTAssertFalse(self.extension.isLoaded);
	XCTAssertEqual(self.getAPI.requestCount, (NSUInteger)1);
}

#pragma mark Direct Record Access

/*! @abstract setObject:forKey:toParameter: and objectForKey:fromParameter: round-trip a value on a seeded record and mark the cache dirty. */
- (void)testSetObjectAndObjectForKeyRoundTripOnASeededRecord
{
	[self seedParameter:kPDataTestParamA];
	[self.extension extFlush:FxGripPDataTestNotification(FxGripTileableEffectFlushName, self.effect, nil)];

	[self.extension setObject:@"value" forKey:@"custom" toParameter:kPDataTestParamA];

	XCTAssertEqualObjects([self.extension objectForKey:@"custom" fromParameter:kPDataTestParamA], @"value");
	XCTAssertTrue(self.extension.isCacheDirty);
}

/*! @abstract Writing the same value for a key leaves the cache clean and schedules no write. */
- (void)testSetObjectWithTheSameValueLeavesTheCacheClean
{
	[self seedParameter:kPDataTestParamA];
	[self.extension setObject:@"value" forKey:@"custom" toParameter:kPDataTestParamA];
	[self.extension extFlush:FxGripPDataTestNotification(FxGripTileableEffectFlushName, self.effect, nil)];

	[self.extension setObject:@"value" forKey:@"custom" toParameter:kPDataTestParamA];

	XCTAssertFalse(self.extension.isCacheDirty, @"an unchanged entry does not schedule a write");
}

/*! @abstract objectForKey:fromParameter: returns nil for an unknown parameter or an absent key. */
- (void)testObjectForKeyReturnsNilForAnUnknownParameter
{
	[self seedParameter:kPDataTestParamA];

	XCTAssertNil([self.extension objectForKey:@"custom" fromParameter:kPDataTestParamB]);
	XCTAssertNil([self.extension objectForKey:@"missing" fromParameter:kPDataTestParamA]);
}

/*!
	setObject:forKey:toParameter: writes through the record dictionary, so a parameter that
	was never announced has nowhere to store the entry. The write is dropped, no record
	appears, and the cache stays clean.
*/
/*! @abstract setObject:forKey:toParameter: for a parameter with no record stores nothing and leaves the cache clean. */
- (void)testSetObjectForAParameterWithNoRecordStoresNothing
{
	[self seedParameter:kPDataTestParamA];
	[self.extension extFlush:FxGripPDataTestNotification(FxGripTileableEffectFlushName, self.effect, nil)];

	[self.extension setObject:@"value" forKey:@"custom" toParameter:kPDataTestParamB];

	XCTAssertNil([self.extension objectForKey:@"custom" fromParameter:kPDataTestParamB]);
	XCTAssertNil(self.extension.data[@(kPDataTestParamB)]);
	XCTAssertFalse(self.extension.isCacheDirty);
}

#pragma mark Effect Category

/*! @abstract FxGripTileableEffect exposes the parameterData accessor and its new-extension factory. */
- (void)testTheEffectCategoryBuildsAParameterDataExtension
{
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(parameterData)]);
	XCTAssertTrue([FxGripTileableEffect instancesRespondToSelector:@selector(newParameterDataExtension)]);
}

@end
