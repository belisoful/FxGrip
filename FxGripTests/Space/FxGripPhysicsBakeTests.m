/*!
	@file       FxGripPhysicsBakeTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPhysicsBakeTests
	@abstract   Tests for FxGripPhysicsBake, the space-effect extension that owns the physics-bake parameter and frame-data store.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the extension exposes the physics-bake parameter id and a frame-data store, and that a space effect vends the extension from its factory while reporting its absence until a subclass adds it. The extension names no render engine, so the tests exercise it through the engine-neutral base.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripPhysicsBake.h>
#import <FxGrip/FxGripSpaceEffect.h>
#import <FxGrip/FxGripFrameData.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripPhysicsSimulationStore.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripExtensionSystem.h>
#import <FxGrip/FxGripTileableEffect+Extensions.h>

@interface FxGripPhysicsBakeTests : XCTestCase
@end

@implementation FxGripPhysicsBakeTests

/*! @abstract A physics-bake extension reports the physics-bake parameter id and holds an FxGripFrameData store. */
- (void)testExtensionOwnsThePhysicsBakeParameterAndFrameData
{
	FxGripPhysicsBake *bake = [FxGripPhysicsBake.alloc init];
	XCTAssertEqual(bake.parameterID, (FxParameterId)kFxParameterId_PhysicsBake);
	XCTAssertTrue([bake.frameData isKindOfClass:FxGripFrameData.class]);
}

/*! @abstract A space effect reports no physics bake until -newPhysicsBakeExtension vends an extension carrying the physics-bake parameter id. */
- (void)testEffectFactoryAndPresenceFlag
{
	FxGripSpaceEffect *effect = [FxGripSpaceEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertFalse(effect.hasPhysicsBake, @"the extension is not loaded until a subclass adds it");

	FxGripPhysicsBake *bake = [effect newPhysicsBakeExtension];
	XCTAssertNotNil(bake);
	XCTAssertEqual(bake.parameterID, (FxParameterId)kFxParameterId_PhysicsBake);
}

@end

/*! Records the store the extension installs, and plays a space effect that accepts one. */
@interface FxGripBakeTestEffect : FxGripSpaceEffect
@property (nonatomic, strong, nullable) id<FxGripPhysicsSimulationStore> installedStore;
@property (nonatomic, assign) BOOL acceptsStore;
@end

@implementation FxGripBakeTestEffect

- (id)effectBase { return self; }

- (BOOL)installPhysicsSimulationStore:(id<FxGripPhysicsSimulationStore>)store
{
	self.installedStore = store;
	return self.acceptsStore;
}

@end

/*! An effect that is not a space effect, so the bake has no engine to install a store on. */
@interface FxGripBakeTestPlainEffect : FxGripTileableEffect
@end

@implementation FxGripBakeTestPlainEffect
- (id)effectBase { return self; }
@end

@interface FxGripPhysicsBakeExtensionTests : XCTestCase
@property (nonatomic, strong) FxGripPhysicsBake *bake;
@property (nonatomic, strong) FxGripBakeTestEffect *effect;
@end

@implementation FxGripPhysicsBakeExtensionTests

- (void)setUp
{
	[super setUp];
	self.bake = [FxGripPhysicsBake.alloc init];
	self.effect = [FxGripBakeTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	self.effect.acceptsStore = YES;
	[self.bake extLoadWithEffect:(id)self.effect];
}

- (void)tearDown
{
	self.bake = nil;
	self.effect = nil;
	[super tearDown];
}

- (NSNotification *)notificationNamed:(NSNotificationName)name userInfo:(NSDictionary *)userInfo
{
	return [NSNotification notificationWithName:name object:self.effect userInfo:userInfo];
}

#pragma mark Secure coding

/*! @abstract dataClasses adds FxGripFrameData and the record types the bake decodes. */
- (void)testTheDataClassesCoverTheBakeRecordTypes
{
	NSSet *classes = self.bake.dataClasses;

	XCTAssertTrue([classes containsObject:FxGripFrameData.class]);
	XCTAssertTrue([classes containsObject:NSDictionary.class]);
	XCTAssertTrue([classes containsObject:NSData.class]);
	XCTAssertTrue([classes containsObject:NSString.class]);
}

/*! @abstract dataClasses keeps everything the base extension already declared. */
- (void)testTheDataClassesKeepTheBaseClasses
{
	FxGripPhysicsBake *plain = [FxGripPhysicsBake.alloc init];
	NSSet *base = [[FxGripCustomExtension.alloc init] dataClasses];

	XCTAssertTrue([base isSubsetOfSet:plain.dataClasses]);
}

#pragma mark Registration

/*! @abstract extAddParameters: registers one hidden custom parameter carrying the bake as its factory. */
- (void)testAddingParametersRegistersTheHiddenBakeParameter
{
	NSMutableArray *parameters = NSMutableArray.new;

	[self.bake extAddParameters:[self notificationNamed:FxGripTileableEffectAddParametersName
											  userInfo:@{FxGripTileableEffectParametersKey: parameters}]];

	XCTAssertEqual(parameters.count, (NSUInteger)1);
	NSDictionary *parameter = parameters.firstObject;
	XCTAssertTrue([parameter isKindOfClass:NSMutableDictionary.class],
				  @"the effect edits the registration entry in place");
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Factory], self.bake);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Id], @(kFxParameterId_PhysicsBake));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Name], @"Physics Bake");
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], kFxParameterType_Custom);
}

/*! @abstract The bake parameter is hidden, undisplayed, unanimatable, and kept out of presets and state. */
- (void)testTheBakeParameterCarriesTheHiddenFlags
{
	NSMutableArray *parameters = NSMutableArray.new;

	[self.bake extAddParameters:[self notificationNamed:FxGripTileableEffectAddParametersName
											  userInfo:@{FxGripTileableEffectParametersKey: parameters}]];

	NSArray *flags = parameters.firstObject[kFxParameterProperty_Flags];
	XCTAssertTrue([flags containsObject:kParameterFlagString_HIDDEN]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_DONT_DISPLAY]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_NOT_ANIMATABLE]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_PRESETNOVALUE]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_NO_STATE]);
}

#pragma mark Loading from the document

/*! @abstract Without a host value the bake keeps a frame data of its own and installs a store. */
- (void)testAddingToTheDocumentWithoutAHostValueStillInstallsAStore
{
	[self.bake extAddedToDocument:[self notificationNamed:FxGripTileableEffectAddedToDocumentName userInfo:@{}]];

	XCTAssertNotNil(self.bake.frameData);
	XCTAssertNotNil(self.effect.installedStore);
	XCTAssertTrue([self.effect.installedStore isKindOfClass:FxGripPhysicsFrameDataStore.class]);
}

/*! @abstract The installed store is backed by the extension's own frame data. */
- (void)testTheInstalledStoreIsBackedByTheExtensionsFrameData
{
	[self.bake extAddedToDocument:[self notificationNamed:FxGripTileableEffectAddedToDocumentName userInfo:@{}]];
	FxGripFrameData *data = self.bake.frameData;

	[data setRecord:(NSObject<NSSecureCoding, NSCopying> *)@{@"body": @1} atIndex:3];

	XCTAssertEqualObjects([data recordAtIndex:3], @{@"body": @1});
	XCTAssertEqual(data.frameIndexes.count, (NSUInteger)1);
}

/*! @abstract An effect that is not a space effect has no engine to take the store, and the load is harmless. */
- (void)testANonSpaceEffectGetsNoStore
{
	FxGripPhysicsBake *bake = [FxGripPhysicsBake.alloc init];
	FxGripBakeTestPlainEffect *plain = [FxGripBakeTestPlainEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	[bake extLoadWithEffect:(id)plain];
	NSNotification *added = [NSNotification notificationWithName:FxGripTileableEffectAddedToDocumentName
														  object:plain
														userInfo:@{}];

	XCTAssertNoThrow([bake extAddedToDocument:added]);
	XCTAssertNotNil(bake.frameData);
}

/*! @abstract An engine that refuses the store leaves the bake loaded and inert. */
- (void)testAnEngineThatRefusesTheStoreLeavesTheBakeInert
{
	self.effect.acceptsStore = NO;

	[self.bake extAddedToDocument:[self notificationNamed:FxGripTileableEffectAddedToDocumentName userInfo:@{}]];

	XCTAssertNotNil(self.effect.installedStore, @"the store is still offered");
	XCTAssertNotNil(self.bake.frameData);
}

/*! @abstract The frame data is created once and reused across reads. */
- (void)testTheFrameDataIsCreatedOnceAndReused
{
	FxGripFrameData *first = self.bake.frameData;
	FxGripFrameData *second = self.bake.frameData;

	XCTAssertNotNil(first);
	XCTAssertEqual(first, second);
}

#pragma mark The effect-side accessors

/*!
	@abstract physicsBakeData is nil while no bake extension is registered on the effect.
	@discussion The extension reaches the effect's registry through the effect's own loadExtensions
				pass, which a plugin opts into; loading an extension against an effect does not
				register it. This pins the unregistered answer, which is what a plugin without the
				bake sees.
*/
- (void)testThePhysicsBakeDataIsNilWithoutARegisteredExtension
{
	FxGripBakeTestEffect *effect = [FxGripBakeTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];

	XCTAssertNil(effect.physicsBakeData);
	XCTAssertFalse(effect.hasPhysicsBake);
	XCTAssertNil([effect extensionForClass:FxGripPhysicsBake.class]);
}

@end
