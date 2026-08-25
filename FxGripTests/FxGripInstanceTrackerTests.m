//
//  FxGripInstanceTrackerTests.m
//  FxGripTests
//
//  Unit tests for FxGripInstanceTracker: the process-wide registry of effect
//  instances keyed by plugin UUID, the add/remove notification handlers, the
//  neighbour-start-time searches, and the FxTileableEffectBase accessors.
//
//  The registry only accepts real FxTileableEffectBase instances, so the effects
//  here are instances of a local subclass whose -notifier returns a private
//  NSPriorityNotificationCenter. No test touches the process-wide center.
//

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxTileableEffectBase.h>
#import <FxGrip/FxTileableEffectBase+Notifications.h>
#import <FxGrip/FxTileableEffectBase+Extensions.h>
#import <FxGrip/FxGripInstanceTracker.h>

static NSString * const kTrackTestUUIDOne = @"11111111-1111-1111-1111-111111111111";
static NSString * const kTrackTestUUIDTwo = @"22222222-2222-2222-2222-222222222222";

static CMTime FxTrackTestMakeTime(int64_t value, int32_t timescale)
{
	return (CMTime){.value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static BOOL FxTrackTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

#pragma mark - Effect double

@interface FxTrackTestEffect : FxTileableEffectBase
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, copy) NSString *trackedUUID;
@property (nonatomic, assign) CMTime timelineStartTime;
@end

@implementation FxTrackTestEffect

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
@interface FxTrackTestUntrackedEffect : FxTrackTestEffect
@end

@implementation FxTrackTestUntrackedEffect

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

#pragma mark - Tests

@interface FxGripInstanceTrackerTests : XCTestCase
@property (nonatomic, strong) NSMutableArray<FxTrackTestEffect *> *effects;
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
	for (FxTrackTestEffect *effect in self.effects) {
		[effect.instanceTracker extRemovedFromDocument:[self documentNotificationFor:effect removed:YES]];
	}
	self.effects = nil;
	[super tearDown];
}

- (FxTrackTestEffect *)makeEffectWithUUID:(NSString *)uuid startSeconds:(int64_t)seconds
{
	FxTrackTestEffect *effect = [FxTrackTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);
	effect.trackedUUID = uuid;
	effect.timelineStartTime = FxTrackTestMakeTime(seconds, 1);
	[self.effects addObject:effect];
	return effect;
}

- (NSNotification *)documentNotificationFor:(id)object removed:(BOOL)removed
{
	return [NSNotification notificationWithName:(removed ? FxTileableEffectRemovedFromDocumentName
													     : FxTileableEffectAddedToDocumentName)
										 object:object
									   userInfo:nil];
}

- (void)addToDocument:(FxTrackTestEffect *)effect through:(FxGripInstanceTracker *)tracker
{
	[tracker extAddedToDocument:[self documentNotificationFor:effect removed:NO]];
}

#pragma mark Loading

- (void)testTheEffectLoadsATrackerWhenItTracksInstances
{
	FxTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];

	XCTAssertNotNil(effect.instanceTracker);
	XCTAssertTrue([effect.instanceTracker isKindOfClass:FxGripInstanceTracker.class]);
	XCTAssertEqualObjects(effect.instanceTracker.extKey, @"FxGripInstanceTracker");
	XCTAssertTrue(effect.instanceTracker.effect == effect);
	XCTAssertNotNil([effect newFxInstanceTracker]);
}

- (void)testAnEffectThatDoesNotTrackInstancesHasNoTracker
{
	FxTrackTestUntrackedEffect *plain = [FxTrackTestUntrackedEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(plain);
	[self.effects addObject:plain];

	XCTAssertFalse(plain.isTrackingInstances, @"tracking is off unless the effect opts in");
	XCTAssertNil(plain.instanceTracker);
	XCTAssertEqual(plain.instanceCount, (NSUInteger)0);
	XCTAssertNotNil(plain.instances, @"-instances is nonnull with or without a tracker");
	XCTAssertEqualObjects(plain.instances, @[]);
}

#pragma mark Registration

- (void)testAddingToTheDocumentRegistersTheInstance
{
	FxTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];

	XCTAssertEqualObjects(effect.instances, @[]);
	XCTAssertEqual(effect.instanceCount, (NSUInteger)0);

	[self addToDocument:effect through:effect.instanceTracker];

	XCTAssertEqual(effect.instanceCount, (NSUInteger)1);
	XCTAssertEqual(effect.instances.count, (NSUInteger)1);
	XCTAssertTrue(effect.instances.firstObject == effect);
	XCTAssertTrue([effect instanceAtIndex:0] == effect);
}

- (void)testRegisteringTheSameInstanceTwiceKeepsOneEntry
{
	FxTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];

	[self addToDocument:effect through:effect.instanceTracker];
	[self addToDocument:effect through:effect.instanceTracker];

	XCTAssertEqual(effect.instanceCount, (NSUInteger)1);
}

- (void)testInstancesOfOnePluginShareTheRegistryEntry
{
	FxTrackTestEffect *first = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	FxTrackTestEffect *second = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:2];

	[self addToDocument:first through:first.instanceTracker];
	[self addToDocument:second through:second.instanceTracker];

	XCTAssertEqual(first.instanceCount, (NSUInteger)2);
	XCTAssertEqual(second.instanceCount, (NSUInteger)2);
	XCTAssertTrue([first.instances containsObject:second]);
	XCTAssertTrue([second.instances containsObject:first]);
	XCTAssertTrue([first instanceAtIndex:1] == second);
}

- (void)testInstancesOfDifferentPluginsAreTrackedSeparately
{
	FxTrackTestEffect *first = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	FxTrackTestEffect *other = [self makeEffectWithUUID:kTrackTestUUIDTwo startSeconds:1];

	[self addToDocument:first through:first.instanceTracker];
	[self addToDocument:other through:other.instanceTracker];

	XCTAssertEqual(first.instanceCount, (NSUInteger)1);
	XCTAssertEqual(other.instanceCount, (NSUInteger)1);
	XCTAssertFalse([first.instances containsObject:other]);
}

- (void)testAnObjectThatIsNotAnEffectIsNeverRegistered
{
	FxTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];

	[effect.instanceTracker extAddedToDocument:[self documentNotificationFor:NSObject.new removed:NO]];

	XCTAssertEqual(effect.instanceCount, (NSUInteger)0);
}

#pragma mark Removal

- (void)testRemovingFromTheDocumentDropsTheInstance
{
	FxTrackTestEffect *first = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	FxTrackTestEffect *second = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:2];
	[self addToDocument:first through:first.instanceTracker];
	[self addToDocument:second through:second.instanceTracker];

	[first.instanceTracker extRemovedFromDocument:[self documentNotificationFor:first removed:YES]];

	XCTAssertEqual(second.instanceCount, (NSUInteger)1);
	XCTAssertTrue(second.instances.firstObject == second);
}

- (void)testRemovingTheLastInstanceEmptiesTheRegistryEntry
{
	FxTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	[self addToDocument:effect through:effect.instanceTracker];

	[effect.instanceTracker extRemovedFromDocument:[self documentNotificationFor:effect removed:YES]];

	XCTAssertEqual(effect.instanceCount, (NSUInteger)0);
	XCTAssertEqualObjects(effect.instances, @[]);
	XCTAssertNil([effect instanceAtIndex:0]);
}

- (void)testRemovingAnUnregisteredInstanceOrANonEffectDoesNothing
{
	FxTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	FxTrackTestEffect *stranger = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:9];
	[self addToDocument:effect through:effect.instanceTracker];

	[effect.instanceTracker extRemovedFromDocument:[self documentNotificationFor:stranger removed:YES]];
	[effect.instanceTracker extRemovedFromDocument:[self documentNotificationFor:NSObject.new removed:YES]];

	XCTAssertEqual(effect.instanceCount, (NSUInteger)1);
}

- (void)testInstanceAtIndexIsBoundedAndDoesNotThrow
{
	FxTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	[self addToDocument:effect through:effect.instanceTracker];

	XCTAssertTrue([effect instanceAtIndex:0] == effect);
	XCTAssertNil([effect instanceAtIndex:1], @"one past the end returns nil, not a range exception");
	XCTAssertNil([effect instanceAtIndex:-1], @"a negative index returns nil");
}

#pragma mark Teardown / retain-cycle regression

// An effect owns its extensions; the extension's back-reference to the effect must be
// weak, or the effect (and every observer it registered) leaks for the process lifetime.
- (void)testAnEffectWithATrackerDeallocatesWhenReleased
{
	__weak FxTrackTestEffect *weakEffect = nil;
	@autoreleasepool {
		FxTrackTestEffect *effect = [FxTrackTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
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
- (void)testAnEffectDeallocRemovesItsRegistryEntryWithoutANotification
{
	FxTrackTestEffect *survivor = [self makeEffectWithUUID:kTrackTestUUIDTwo startSeconds:0];
	[self addToDocument:survivor through:survivor.instanceTracker];

	@autoreleasepool {
		FxTrackTestEffect *transient = [FxTrackTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
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

- (NSArray<FxTrackTestEffect *> *)threeRegisteredEffects
{
	FxTrackTestEffect *early = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	FxTrackTestEffect *middle = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:5];
	FxTrackTestEffect *late = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:9];

	[self addToDocument:early through:early.instanceTracker];
	[self addToDocument:middle through:middle.instanceTracker];
	[self addToDocument:late through:late.instanceTracker];

	return @[early, middle, late];
}

- (void)testTheNextEffectIsTheNearestLaterInstance
{
	NSArray<FxTrackTestEffect *> *effects = [self threeRegisteredEffects];
	FxGripInstanceTracker *tracker = effects[0].instanceTracker;

	XCTAssertTrue(FxTrackTestTimesEqual([tracker startTimeOfNextEffect:effects[0]],
										FxTrackTestMakeTime(5, 1)));
	XCTAssertTrue(FxTrackTestTimesEqual([tracker startTimeOfNextEffect:effects[1]],
										FxTrackTestMakeTime(9, 1)));
}

- (void)testTheNextEffectIsInvalidForTheLastInstance
{
	NSArray<FxTrackTestEffect *> *effects = [self threeRegisteredEffects];

	CMTime next = [effects[0].instanceTracker startTimeOfNextEffect:effects[2]];

	XCTAssertEqual(next.flags & kCMTimeFlags_Valid, (CMTimeFlags)0,
				   @"an instance with no later neighbour yields an invalid time");
}

- (void)testThePreviousEffectIsTheNearestEarlierInstance
{
	NSArray<FxTrackTestEffect *> *effects = [self threeRegisteredEffects];
	FxGripInstanceTracker *tracker = effects[0].instanceTracker;

	XCTAssertTrue(FxTrackTestTimesEqual([tracker startTimeOfPreviousEffect:effects[2]],
										FxTrackTestMakeTime(5, 1)));
	XCTAssertTrue(FxTrackTestTimesEqual([tracker startTimeOfPreviousEffect:effects[1]],
										FxTrackTestMakeTime(1, 1)));
}

- (void)testThePreviousEffectIsInvalidForTheFirstInstance
{
	NSArray<FxTrackTestEffect *> *effects = [self threeRegisteredEffects];

	CMTime previous = [effects[0].instanceTracker startTimeOfPreviousEffect:effects[0]];

	XCTAssertEqual(previous.flags & kCMTimeFlags_Valid, (CMTimeFlags)0,
				   @"an instance with no earlier neighbour yields an invalid time");
}

- (void)testAnUnregisteredPluginHasNoNextStartTime
{
	FxTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	[self addToDocument:effect through:effect.instanceTracker];
	FxTrackTestEffect *unregistered = [self makeEffectWithUUID:kTrackTestUUIDTwo startSeconds:3];

	CMTime next = [effect.instanceTracker startTimeOfNextEffect:unregistered];

	XCTAssertEqual(next.flags & kCMTimeFlags_Valid, (CMTimeFlags)0,
				   @"an unknown plugin UUID yields an invalid time");
}

- (void)testAnUnregisteredPluginHasNoPreviousStartTime
{
	FxTrackTestEffect *effect = [self makeEffectWithUUID:kTrackTestUUIDOne startSeconds:1];
	[self addToDocument:effect through:effect.instanceTracker];
	FxTrackTestEffect *unregistered = [self makeEffectWithUUID:kTrackTestUUIDTwo startSeconds:3];

	CMTime previous = [effect.instanceTracker startTimeOfPreviousEffect:unregistered];

	XCTAssertEqual(previous.flags & kCMTimeFlags_Valid, (CMTimeFlags)0,
				   @"an unknown plugin UUID yields an invalid time");
}

@end
