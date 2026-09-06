/*!
	@file       FxGripInstanceTrackerTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInstanceTrackerTests
	@abstract   Tests FxGripInstanceTracker registration, removal, teardown, and neighbour-start-time searches.
	@discussion Introduced in FxGrip 0.1.0. Effects are instances of a local FxGripTileableEffect subclass whose
	            notifier is a private center, so the process-wide registry is exercised without touching the shared
	            center. The tests cover tracker loading, per-UUID grouping, add and remove handlers, dealloc cleanup,
	            and the next and previous start-time queries.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <FxGrip/FxGripTileableEffect+Extensions.h>
#import <FxGrip/FxGripInstanceTracker.h>

static NSString * const kTrackTestUUIDOne = @"11111111-1111-1111-1111-111111111111";
static NSString * const kTrackTestUUIDTwo = @"22222222-2222-2222-2222-222222222222";

static CMTime FxGripTrackTestMakeTime(int64_t value, int32_t timescale)
{
	return (CMTime){.value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static BOOL FxGripTrackTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

#pragma mark - Effect double

@interface FxGripTrackTestEffect : FxGripTileableEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, copy) NSString *trackedUUID;
@property (nonatomic, assign) CMTime timelineStartTime;
@end

@implementation FxGripTrackTestEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_privateNotifier = [[cls alloc] init];
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

// The registry keys on the plugin UUID, which a host would supply through the API manager.
- (NSString *)pluginUUID
{
	return _trackedUUID ?: kTrackTestUUIDOne;
}

- (BOOL)isTrackingInstances
{
	return YES;
}

- (CMTime)effectStartTimeInTimeline
{
	return _timelineStartTime;
}

@end

// Carries the private notifier without opting into instance tracking.
@interface FxGripTrackTestUntrackedEffect : FxGripTrackTestEffect
@end

@implementation FxGripTrackTestUntrackedEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (BOOL)isTrackingInstances
{
	return NO;
}

@end

// Reports no plugin UUID: the registry cannot key on it, so registration must no-op.
@interface FxGripTrackTestNilUUIDEffect : FxGripTrackTestEffect
@end

@implementation FxGripTrackTestNilUUIDEffect

- (NSString *)pluginUUID
{
	return nil;
}

@end

#pragma mark - Tests

@interface FxGripInstanceTrackerTests : XCTestCase
@property (nonatomic, strong) NSMutableArray<FxGripTrackTestEffect *> *effects;
@end

@implementation FxGripInstanceTrackerTests

- (void)setUp
{
	[super setUp];
	self.effects = NSMutableArray.new;
}

// The registry outlives the effects, so every registration is undone.
- (void)tearDown
{
	for (FxGripTrackTestEffect *effect in self.effects) {
		[effect.instanceTracker extRemovedFromDocument:[self documentNotificationFor:effect removed:YES]];
	}
	self.effects = nil;
	[super tearDown];
}

- (FxGripTrackTestEffect *)makeEffectWithUUID:(NSString *)uuid startSeconds:(int64_t)seconds
{
	FxGripTrackTestEffect *effect = [FxGripTrackTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);
	effect.trackedUUID = uuid;
	effect.timelineStartTime = FxGripTrackTestMakeTime(seconds, 1);
	[self.effects addObject:effect];
	return effect;
}

- (NSNotification *)documentNotificationFor:(id)object removed:(BOOL)removed
{
	return [NSNotification notificationWithName:(removed ? FxGripTileableEffectRemovedFromDocumentName
													     : FxGripTileableEffectAddedToDocumentName)
										 object:object
									   userInfo:nil];
}

- (void)addToDocument:(FxGripTrackTestEffect *)effect through:(FxGripInstanceTracker *)tracker
{
	[tracker extAddedToDocument:[self documentNotificationFor:effect removed:NO]];
}

#pragma mark Loading

/*! @abstract Verifies an effect that tracks instances loads an FxGripInstanceTracker keyed to it. */
- (void)testTheEffectLoadsATrackerWhenItTracksInstances
{
	FxGripTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];

	XCTAssertNotNil(effect.instanceTracker);
	XCTAssertTrue([effect.instanceTracker isKindOfClass:FxGripInstanceTracker.class]);
	XCTAssertEqualObjects(effect.instanceTracker.extKey, @"FxGripInstanceTracker");
	XCTAssertTrue(effect.instanceTracker.effect == effect);
	XCTAssertNotNil([effect newFxInstanceTracker]);
}

/*! @abstract Verifies an effect that does not opt into tracking has no tracker, zero instance count, and an empty non-nil instances array. */
- (void)testAnEffectThatDoesNotTrackInstancesHasNoTracker
{
	FxGripTrackTestUntrackedEffect *plain = [FxGripTrackTestUntrackedEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(plain);
	[self.effects addObject:plain];

	XCTAssertFalse(plain.isTrackingInstances, @"tracking is off unless the effect opts in");
	XCTAssertNil(plain.instanceTracker);
	XCTAssertEqual(plain.instanceCount, (NSUInteger)0);
	XCTAssertNotNil(plain.instances, @"-instances is nonnull with or without a tracker");
	XCTAssertEqualObjects(plain.instances, @[]);
}

#pragma mark Registration

/*! @abstract Verifies the added-to-document handler registers the instance and exposes it through the count, array, and index accessors. */
- (void)testAddingToTheDocumentRegistersTheInstance
{
	FxGripTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];

	XCTAssertEqualObjects(effect.instances, @[]);
	XCTAssertEqual(effect.instanceCount, (NSUInteger)0);

	[self addToDocument:effect through:effect.instanceTracker];

	XCTAssertEqual(effect.instanceCount, (NSUInteger)1);
	XCTAssertEqual(effect.instances.count, (NSUInteger)1);
	XCTAssertTrue(effect.instances.firstObject == effect);
	XCTAssertTrue([effect instanceAtIndex:0] == effect);
}

/*! @abstract Verifies an effect with a nil plugin UUID skips registration without raising on a nil registry key. */
- (void)testAddingAnEffectWithoutAUUIDRegistersNothingAndDoesNotThrow
{
	FxGripTrackTestNilUUIDEffect *effect = [FxGripTrackTestNilUUIDEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);
	[self.effects addObject:effect];

	XCTAssertNil(effect.pluginUUID, @"the double reports no UUID");
	XCTAssertNoThrow([effect.instanceTracker extAddedToDocument:[self documentNotificationFor:effect removed:NO]],
					 @"a nil UUID cannot key the registry, so registration is skipped rather than raising on a nil key");
}

/*! @abstract Verifies registering one instance twice leaves a single registry entry. */
- (void)testRegisteringTheSameInstanceTwiceKeepsOneEntry
{
	FxGripTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];

	[self addToDocument:effect through:effect.instanceTracker];
	[self addToDocument:effect through:effect.instanceTracker];

	XCTAssertEqual(effect.instanceCount, (NSUInteger)1);
}

/*! @abstract Verifies two effects of one plugin UUID share the registry entry and see each other. */
- (void)testInstancesOfOnePluginShareTheRegistryEntry
{
	FxGripTrackTestEffect *first = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	FxGripTrackTestEffect *second = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:2];

	[self addToDocument:first through:first.instanceTracker];
	[self addToDocument:second through:second.instanceTracker];

	XCTAssertEqual(first.instanceCount, (NSUInteger)2);
	XCTAssertEqual(second.instanceCount, (NSUInteger)2);
	XCTAssertTrue([first.instances containsObject:second]);
	XCTAssertTrue([second.instances containsObject:first]);
	XCTAssertTrue([first instanceAtIndex:1] == second);
}

/*! @abstract Verifies effects with different plugin UUIDs keep separate registry entries. */
- (void)testInstancesOfDifferentPluginsAreTrackedSeparately
{
	FxGripTrackTestEffect *first = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	FxGripTrackTestEffect *other = [self makeEffectWithUUID:kTrackTestUUIDTwo startSeconds:1];

	[self addToDocument:first through:first.instanceTracker];
	[self addToDocument:other through:other.instanceTracker];

	XCTAssertEqual(first.instanceCount, (NSUInteger)1);
	XCTAssertEqual(other.instanceCount, (NSUInteger)1);
	XCTAssertFalse([first.instances containsObject:other]);
}

/*! @abstract Verifies an added-to-document notification whose object is not an effect registers nothing. */
- (void)testAnObjectThatIsNotAnEffectIsNeverRegistered
{
	FxGripTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];

	[effect.instanceTracker extAddedToDocument:[self documentNotificationFor:NSObject.new removed:NO]];

	XCTAssertEqual(effect.instanceCount, (NSUInteger)0);
}

#pragma mark Removal

/*! @abstract Verifies the removed-from-document handler drops the named instance and leaves the rest. */
- (void)testRemovingFromTheDocumentDropsTheInstance
{
	FxGripTrackTestEffect *first = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	FxGripTrackTestEffect *second = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:2];
	[self addToDocument:first through:first.instanceTracker];
	[self addToDocument:second through:second.instanceTracker];

	[first.instanceTracker extRemovedFromDocument:[self documentNotificationFor:first removed:YES]];

	XCTAssertEqual(second.instanceCount, (NSUInteger)1);
	XCTAssertTrue(second.instances.firstObject == second);
}

/*! @abstract Verifies removing the last instance empties the count, the array, and the index accessor. */
- (void)testRemovingTheLastInstanceEmptiesTheRegistryEntry
{
	FxGripTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	[self addToDocument:effect through:effect.instanceTracker];

	[effect.instanceTracker extRemovedFromDocument:[self documentNotificationFor:effect removed:YES]];

	XCTAssertEqual(effect.instanceCount, (NSUInteger)0);
	XCTAssertEqualObjects(effect.instances, @[]);
	XCTAssertNil([effect instanceAtIndex:0]);
}

/*! @abstract Verifies removing an unregistered instance or a non-effect object leaves the registry unchanged. */
- (void)testRemovingAnUnregisteredInstanceOrANonEffectDoesNothing
{
	FxGripTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	FxGripTrackTestEffect *stranger = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:9];
	[self addToDocument:effect through:effect.instanceTracker];

	[effect.instanceTracker extRemovedFromDocument:[self documentNotificationFor:stranger removed:YES]];
	[effect.instanceTracker extRemovedFromDocument:[self documentNotificationFor:NSObject.new removed:YES]];

	XCTAssertEqual(effect.instanceCount, (NSUInteger)1);
}

/*! @abstract Verifies instanceAtIndex: returns nil for an out-of-range or negative index instead of throwing. */
- (void)testInstanceAtIndexIsBoundedAndDoesNotThrow
{
	FxGripTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	[self addToDocument:effect through:effect.instanceTracker];

	XCTAssertTrue([effect instanceAtIndex:0] == effect);
	XCTAssertNil([effect instanceAtIndex:1], @"one past the end returns nil, not a range exception");
	XCTAssertNil([effect instanceAtIndex:-1], @"a negative index returns nil");
}

#pragma mark Teardown / retain-cycle regression

// An effect owns its extensions; the extension's back-reference to the effect must be
// weak, or the effect (and every observer it registered) leaks for the process lifetime.
/*! @abstract Verifies an effect that loaded a tracker deallocates when released, confirming the extension back-reference is weak. */
- (void)testAnEffectWithATrackerDeallocatesWhenReleased
{
	__weak FxGripTrackTestEffect *weakEffect = nil;
	@autoreleasepool {
		FxGripTrackTestEffect *effect = [FxGripTrackTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
		effect.trackedUUID = kTrackTestUUIDOne;
		weakEffect = effect;
		XCTAssertNotNil(effect.instanceTracker, @"the tracker must load so the back-reference path is exercised");
		effect = nil;
	}
	XCTAssertNil(weakEffect, @"a strong extension back-reference would keep the effect alive");
}

// The registry entry is removed by the effect's own deallocation, with no
// RemovedFromDocument notification — the teardown post never matches a weak object
// filter, so the tracker cannot depend on it.
/*! @abstract Verifies a transient effect's dealloc removes its registry entry without a removal notification, so a surviving sibling counts correctly. */
- (void)testAnEffectDeallocRemovesItsRegistryEntryWithoutANotification
{
	FxGripTrackTestEffect *survivor = [self makeEffectWithUUID:kTrackTestUUIDTwo startSeconds:0];
	[self addToDocument:survivor through:survivor.instanceTracker];

	@autoreleasepool {
		FxGripTrackTestEffect *transient = [FxGripTrackTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
		transient.trackedUUID = kTrackTestUUIDTwo;
		[self addToDocument:transient through:transient.instanceTracker];
		XCTAssertEqual(survivor.instanceCount, (NSUInteger)2);
		transient = nil;
	}

	// Before the fix the transient's pointer dangled here and instanceCount walked freed memory.
	XCTAssertEqual(survivor.instanceCount, (NSUInteger)1);
	XCTAssertTrue([survivor instanceAtIndex:0] == survivor);
}

#pragma mark Neighbour Start Times

- (NSArray<FxGripTrackTestEffect *> *)threeRegisteredEffects
{
	FxGripTrackTestEffect *early = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	FxGripTrackTestEffect *middle = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:5];
	FxGripTrackTestEffect *late = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:9];

	[self addToDocument:early through:early.instanceTracker];
	[self addToDocument:middle through:middle.instanceTracker];
	[self addToDocument:late through:late.instanceTracker];

	return @[early, middle, late];
}

/*! @abstract Verifies startTimeOfNextEffect: returns the nearest later instance's start time. */
- (void)testTheNextEffectIsTheNearestLaterInstance
{
	NSArray<FxGripTrackTestEffect *> *effects = [self threeRegisteredEffects];
	FxGripInstanceTracker *tracker = effects[0].instanceTracker;

	XCTAssertTrue(FxGripTrackTestTimesEqual([tracker startTimeOfNextEffect:effects[0]],
										FxGripTrackTestMakeTime(5, 1)));
	XCTAssertTrue(FxGripTrackTestTimesEqual([tracker startTimeOfNextEffect:effects[1]],
										FxGripTrackTestMakeTime(9, 1)));
}

/*! @abstract Verifies startTimeOfNextEffect: yields an invalid time for the last instance. */
- (void)testTheNextEffectIsInvalidForTheLastInstance
{
	NSArray<FxGripTrackTestEffect *> *effects = [self threeRegisteredEffects];

	CMTime next = [effects[0].instanceTracker startTimeOfNextEffect:effects[2]];

	XCTAssertEqual(next.flags & kCMTimeFlags_Valid, (CMTimeFlags)0,
				   @"an instance with no later neighbour yields an invalid time");
}

/*! @abstract Verifies startTimeOfPreviousEffect: returns the nearest earlier instance's start time. */
- (void)testThePreviousEffectIsTheNearestEarlierInstance
{
	NSArray<FxGripTrackTestEffect *> *effects = [self threeRegisteredEffects];
	FxGripInstanceTracker *tracker = effects[0].instanceTracker;

	XCTAssertTrue(FxGripTrackTestTimesEqual([tracker startTimeOfPreviousEffect:effects[2]],
										FxGripTrackTestMakeTime(5, 1)));
	XCTAssertTrue(FxGripTrackTestTimesEqual([tracker startTimeOfPreviousEffect:effects[1]],
										FxGripTrackTestMakeTime(1, 1)));
}

/*! @abstract Verifies startTimeOfPreviousEffect: yields an invalid time for the first instance. */
- (void)testThePreviousEffectIsInvalidForTheFirstInstance
{
	NSArray<FxGripTrackTestEffect *> *effects = [self threeRegisteredEffects];

	CMTime previous = [effects[0].instanceTracker startTimeOfPreviousEffect:effects[0]];

	XCTAssertEqual(previous.flags & kCMTimeFlags_Valid, (CMTimeFlags)0,
				   @"an instance with no earlier neighbour yields an invalid time");
}

/*! @abstract Verifies startTimeOfNextEffect: yields an invalid time for an effect whose plugin UUID is not in the registry. */
- (void)testAnUnregisteredPluginHasNoNextStartTime
{
	FxGripTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	[self addToDocument:effect through:effect.instanceTracker];
	FxGripTrackTestEffect *unregistered = [self makeEffectWithUUID:kTrackTestUUIDTwo startSeconds:3];

	CMTime next = [effect.instanceTracker startTimeOfNextEffect:unregistered];

	XCTAssertEqual(next.flags & kCMTimeFlags_Valid, (CMTimeFlags)0,
				   @"an unknown plugin UUID yields an invalid time");
}

/*! @abstract Verifies startTimeOfPreviousEffect: yields an invalid time for an effect whose plugin UUID is not in the registry. */
- (void)testAnUnregisteredPluginHasNoPreviousStartTime
{
	FxGripTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	[self addToDocument:effect through:effect.instanceTracker];
	FxGripTrackTestEffect *unregistered = [self makeEffectWithUUID:kTrackTestUUIDTwo startSeconds:3];

	CMTime previous = [effect.instanceTracker startTimeOfPreviousEffect:unregistered];

	XCTAssertEqual(previous.flags & kCMTimeFlags_Valid, (CMTimeFlags)0,
				   @"an unknown plugin UUID yields an invalid time");
}

@end
