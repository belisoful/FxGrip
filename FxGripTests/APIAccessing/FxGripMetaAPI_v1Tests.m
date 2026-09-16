/*!
	@file       FxGripMetaAPI_v1Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripMetaAPI_v1Tests
	@abstract   Verifies that FxGripMetaAPI_v1 forwards every metadata call to the effect's meta manager and answers the not-found result when the effect has none.
	@discussion Introduced in FxGrip 0.1.0. The stub effect vends a real FxGripMetaManager through -meta, so the dictionary, key-list, and remove-all paths are checked against the manager's stored state. Without a manager, each method answers -1, NO, or an error in the FxGrip plugin domain whose code encodes the parameter ID.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripMetaAPI_v1.h>
#import <FxGrip/FxGripMetaManager.h>

static const FxParameterId kMetaAPITestParam = 33;

/*! The effect the wrapper resolves its meta manager from; nil meta means no manager. */
@interface FxGripMetaAPITestEffect : NSObject
@property (nonatomic, strong, nullable) FxGripMetaManager *meta;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@end

@implementation FxGripMetaAPITestEffect
- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = NSNotificationCenter.new;
	}
	return self;
}
@end

@interface FxGripMetaAPI_v1Tests : XCTestCase
@property (nonatomic, strong) FxGripMetaAPITestEffect *effect;
@end

@implementation FxGripMetaAPI_v1Tests

- (void)setUp
{
	[super setUp];
	self.effect = FxGripMetaAPITestEffect.new;
}

- (void)tearDown
{
	self.effect = nil;
	[super tearDown];
}

- (FxGripMetaAPI_v1 *)api
{
	return [FxGripMetaAPI_v1.alloc initWithEffect:(id)self.effect];
}

- (FxGripMetaManager *)installManager
{
	FxGripMetaManager *manager = [FxGripMetaManager.alloc initWithEffect:nil];
	[manager addParameter:kMetaAPITestParam];
	self.effect.meta = manager;
	return manager;
}

- (void)assertNoMetaError:(NSError *)error
{
	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, kFxError_ThirdPartyDeveloperStart + kMetaAPITestParam);
	XCTAssertTrue([error.localizedDescription containsString:@"33"]);
}

#pragma mark Without a manager

/*! @abstract The dictionary-level methods answer -1 or a no-meta error without a manager, and leave the out-pointers untouched. */
- (void)testDictionaryMethodsAnswerNotFoundWithoutAManager
{
	FxGripMetaAPI_v1 *api = self.api;

	XCTAssertEqual([api metaCountFromParameter:kMetaAPITestParam], -1);

	NSDictionary *meta = nil;
	[self assertNoMetaError:[api getMeta:&meta fromParameter:kMetaAPITestParam]];
	XCTAssertNil(meta);
	[self assertNoMetaError:[api setMeta:@{@"k": @"v"} toParameter:kMetaAPITestParam]];
	NSArray *keys = nil;
	[self assertNoMetaError:[api getMetaKeys:&keys fromParameter:kMetaAPITestParam]];
	XCTAssertNil(keys);
	[self assertNoMetaError:[api removeAllMeta:kMetaAPITestParam]];
}

/*! @abstract The keyed methods answer NO without a manager; hasMetaKey fills the error only when a pointer is given. */
- (void)testKeyedMethodsAnswerNoWithoutAManager
{
	FxGripMetaAPI_v1 *api = self.api;

	NSError *error = nil;
	XCTAssertFalse([api parameter:kMetaAPITestParam hasMetaKey:@"k" error:&error]);
	[self assertNoMetaError:error];
	XCTAssertFalse([api parameter:kMetaAPITestParam hasMetaKey:@"k" error:NULL]);

	id<NSSecureCoding, NSCopying> value = nil;
	XCTAssertFalse([api getMeta:&value forKey:@"k" fromParameter:kMetaAPITestParam]);
	XCTAssertNil(value);
	XCTAssertFalse([api setMeta:@"v" forKey:@"k" toParameter:kMetaAPITestParam]);
	XCTAssertFalse([api removeMetaKey:@"k" fromParameter:kMetaAPITestParam]);
}

#pragma mark With a manager

/*! @abstract setMeta:toParameter: replaces the parameter's dictionary on the manager, and getMetaKeys: lists its keys. */
- (void)testSetMetaDictionaryStoresOnTheManagerAndListsItsKeys
{
	FxGripMetaManager *manager = [self installManager];
	FxGripMetaAPI_v1 *api = self.api;

	XCTAssertNil(([api setMeta:@{@"role": @"primary", @"order": @2} toParameter:kMetaAPITestParam]));

	XCTAssertEqual([manager metaCountFromParameter:kMetaAPITestParam], 2);
	NSArray *keys = nil;
	XCTAssertNil([api getMetaKeys:&keys fromParameter:kMetaAPITestParam]);
	XCTAssertEqualObjects([keys sortedArrayUsingSelector:@selector(compare:)], (@[@"order", @"role"]));

	NSDictionary *meta = nil;
	XCTAssertNil([api getMeta:&meta fromParameter:kMetaAPITestParam]);
	XCTAssertEqualObjects(meta, (@{@"role": @"primary", @"order": @2}));
}

/*! @abstract removeAllMeta: clears the parameter's dictionary on the manager. */
- (void)testRemoveAllMetaClearsTheManagerRecord
{
	FxGripMetaManager *manager = [self installManager];
	FxGripMetaAPI_v1 *api = self.api;
	XCTAssertTrue([api setMeta:@"v" forKey:@"k" toParameter:kMetaAPITestParam]);

	XCTAssertNil([api removeAllMeta:kMetaAPITestParam]);

	XCTAssertEqual([manager metaCountFromParameter:kMetaAPITestParam], 0);
	XCTAssertEqual([api metaCountFromParameter:kMetaAPITestParam], 0);
	NSArray *keys = nil;
	XCTAssertNil([api getMetaKeys:&keys fromParameter:kMetaAPITestParam]);
	XCTAssertEqualObjects(keys, @[]);
}

/*! @abstract The keyed methods round-trip one value through the manager and report presence. */
- (void)testKeyedMethodsRoundTripThroughTheManager
{
	[self installManager];
	FxGripMetaAPI_v1 *api = self.api;

	XCTAssertTrue([api setMeta:@"v" forKey:@"k" toParameter:kMetaAPITestParam]);

	id<NSSecureCoding, NSCopying> value = nil;
	XCTAssertTrue([api getMeta:&value forKey:@"k" fromParameter:kMetaAPITestParam]);
	XCTAssertEqualObjects((id)value, @"v");
	NSError *error = nil;
	XCTAssertTrue([api parameter:kMetaAPITestParam hasMetaKey:@"k" error:&error]);
	XCTAssertNil(error);
	XCTAssertFalse([api parameter:kMetaAPITestParam hasMetaKey:@"absent" error:&error]);

	XCTAssertTrue([api removeMetaKey:@"k" fromParameter:kMetaAPITestParam]);
	XCTAssertFalse([api getMeta:&value forKey:@"k" fromParameter:kMetaAPITestParam]);
}

/*! @abstract The wrapper reports the manager's own refusal for a parameter the manager does not hold. */
- (void)testAnUnregisteredParameterIsRefusedByTheManagerNotTheWrapper
{
	[self installManager];
	FxGripMetaAPI_v1 *api = self.api;

	XCTAssertFalse([api setMeta:@"v" forKey:@"k" toParameter:kMetaAPITestParam + 1]);
	XCTAssertNotNil([api setMeta:@{@"k": @"v"} toParameter:kMetaAPITestParam + 1]);
}

@end
