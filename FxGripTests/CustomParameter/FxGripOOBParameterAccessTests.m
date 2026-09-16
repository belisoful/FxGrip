/*!
	@file       FxGripOOBParameterAccessTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripOOBParameterAccessTests
	@abstract   Tests the scoped host-action wrapper for out-of-band parameter edits.
	@discussion Introduced in FxGrip 0.1.0. The tests cover every factory and initializer, the action
	            bracket the active property drives, the delayed open, the close on deallocation, the
	            current-time passthrough, the flush notification, and the nil results the refused
	            initializers return.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripOOBParameterAccess.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>

#pragma mark - Doubles

/*! Stands in for the host's FxCustomParameterActionAPI_v4, counting each bracket call. */
@interface FxGripOOBTestActionAPI : NSObject
@property (nonatomic, assign) CMTime currentTime;
@property (nonatomic, assign) NSUInteger startCount;
@property (nonatomic, assign) NSUInteger endCount;
@property (nonatomic, strong) NSMutableArray<NSString *> *order;
@end

@implementation FxGripOOBTestActionAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_currentTime = FxGripParamClassTestTime(45, 30);
		_order = NSMutableArray.new;
	}
	return self;
}

- (void)startAction:(id)sender
{
	self.startCount += 1;
	[self.order addObject:@"start"];
}

- (void)endAction:(id)sender
{
	self.endCount += 1;
	[self.order addObject:@"end"];
}

@end

/*! Adds the action API the shared manager double does not carry. */
@interface FxGripOOBTestAPIManager : FxGripParamClassTestAPIManager
@property (nonatomic, strong, nullable) FxGripOOBTestActionAPI *customParameterActionAPIv4;
@end

@implementation FxGripOOBTestAPIManager

- (instancetype)init
{
	self = [super init];
	if (self) {
		_customParameterActionAPIv4 = [FxGripOOBTestActionAPI.alloc init];
	}
	return self;
}

@end

/*! An effect double carrying the action API, on the isolated notifier the base double builds. */
@interface FxGripOOBTestEffect : FxGripParamClassTestEffect
@property (nonatomic, strong) FxGripOOBTestAPIManager *actionManager;
@end

@implementation FxGripOOBTestEffect

- (instancetype)init
{
	self = [super init];
	if (self) {
		_actionManager = [FxGripOOBTestAPIManager.alloc init];
		self.apiManager = _actionManager;
	}
	return self;
}

@end

#pragma mark - Tests

@interface FxGripOOBParameterAccessTests : XCTestCase
@property (nonatomic, strong) FxGripOOBTestEffect *effect;
@end

@implementation FxGripOOBParameterAccessTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripOOBTestEffect.alloc init];
}

- (void)tearDown
{
	self.effect = nil;
	[super tearDown];
}

- (FxGripOOBTestActionAPI *)actionAPI
{
	return self.effect.actionManager.customParameterActionAPIv4;
}

#pragma mark Effect factories

/*! @abstract access: opens the host action immediately and reports the accessor active. */
- (void)testAccessOpensTheHostActionImmediately
{
	@autoreleasepool {
		FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:(id)self.effect];

		XCTAssertTrue(access.active);
		XCTAssertEqual(self.actionAPI.startCount, (NSUInteger)1);
		XCTAssertEqual(self.actionAPI.endCount, (NSUInteger)0);
		XCTAssertEqualObjects(access.effect, self.effect);
		XCTAssertFalse(access.flush, @"a plain access does not flush");
	}

	XCTAssertEqual(self.actionAPI.endCount, (NSUInteger)1, @"deallocation closes the action");
}

/*! @abstract access:delay: leaves the action closed until the active property opens it. */
- (void)testADelayedAccessOpensNoActionUntilItIsMadeActive
{
	@autoreleasepool {
		FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:(id)self.effect delay:YES];

		XCTAssertFalse(access.active);
		XCTAssertEqual(self.actionAPI.startCount, (NSUInteger)0);

		access.active = YES;
		XCTAssertEqual(self.actionAPI.startCount, (NSUInteger)1);
		XCTAssertEqual(self.actionAPI.endCount, (NSUInteger)0);
	}

	XCTAssertEqualObjects(self.actionAPI.order, (@[@"start", @"end"]));
}

/*! @abstract access:flush: opens the action at once and carries the flush flag. */
- (void)testAccessWithFlushOpensTheActionAndSetsTheFlushFlag
{
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:(id)self.effect flush:YES];

	XCTAssertTrue(access.active);
	XCTAssertTrue(access.flush);
	XCTAssertEqual(self.actionAPI.startCount, (NSUInteger)1);
}

/*! @abstract access:delay:flush: honors both the delay and the flush flag. */
- (void)testAccessWithDelayAndFlushHonorsBoth
{
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:(id)self.effect delay:YES flush:YES];

	XCTAssertFalse(access.active);
	XCTAssertTrue(access.flush);
	XCTAssertEqual(self.actionAPI.startCount, (NSUInteger)0);
}

#pragma mark API factories

/*! @abstract accessAPI: brackets the action on the API alone and keeps no effect. */
- (void)testAccessAPIOpensTheActionAndHoldsNoEffect
{
	@autoreleasepool {
		FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess accessAPI:(id)self.actionAPI];

		XCTAssertTrue(access.active);
		XCTAssertNil(access.effect);
		XCTAssertEqualObjects((id)access.customParameterActionAPIv4, self.actionAPI);
	}

	XCTAssertEqual(self.actionAPI.endCount, (NSUInteger)1);
}

/*! @abstract accessAPI:delay: leaves the action closed until the accessor is made active. */
- (void)testADelayedAPIAccessOpensNoAction
{
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess accessAPI:(id)self.actionAPI delay:YES];

	XCTAssertFalse(access.active);
	XCTAssertEqual(self.actionAPI.startCount, (NSUInteger)0);
}

#pragma mark Initializers

/*! @abstract initWithEffect: opens the action, and initWithEffect:delay: defers it. */
- (void)testTheEffectInitializersMatchTheirFactories
{
	FxGripOOBParameterAccess *immediate = [FxGripOOBParameterAccess.alloc initWithEffect:(id)self.effect];
	XCTAssertTrue(immediate.active);

	FxGripOOBParameterAccess *delayed = [FxGripOOBParameterAccess.alloc initWithEffect:(id)self.effect delay:YES];
	XCTAssertFalse(delayed.active);

	FxGripOOBParameterAccess *flushing = [FxGripOOBParameterAccess.alloc initWithEffect:(id)self.effect flush:YES];
	XCTAssertTrue(flushing.active);
	XCTAssertTrue(flushing.flush);
}

/*! @abstract initWithAPI: opens the action, and initWithAPI:delay: defers it. */
- (void)testTheAPIInitializersMatchTheirFactories
{
	FxGripOOBParameterAccess *immediate = [FxGripOOBParameterAccess.alloc initWithAPI:(id)self.actionAPI];
	XCTAssertTrue(immediate.active);

	FxGripOOBParameterAccess *delayed = [FxGripOOBParameterAccess.alloc initWithAPI:(id)self.actionAPI delay:YES];
	XCTAssertFalse(delayed.active);
}

/*! @abstract The plain init refuses, because an accessor without a host action API can bracket nothing. */
- (void)testThePlainInitializerRefuses
{
	XCTAssertNil([FxGripOOBParameterAccess.alloc init]);
}

/*! @abstract An initializer given no API or no effect returns nil. */
- (void)testAnInitializerWithoutAHostReturnsNil
{
	id noAPI = nil;
	id noEffect = nil;

	XCTAssertNil([FxGripOOBParameterAccess.alloc initWithAPI:noAPI]);
	XCTAssertNil([FxGripOOBParameterAccess.alloc initWithAPI:noAPI delay:YES]);
	XCTAssertNil([FxGripOOBParameterAccess.alloc initWithEffect:noEffect]);
	XCTAssertNil([FxGripOOBParameterAccess.alloc initWithEffect:noEffect delay:YES]);
	XCTAssertNil([FxGripOOBParameterAccess.alloc initWithEffect:noEffect flush:YES]);
	XCTAssertNil([FxGripOOBParameterAccess.alloc initWithEffect:noEffect delay:NO flush:NO]);
}

#pragma mark Bracket

/*! @abstract Setting active to its current value calls neither startAction nor endAction. */
- (void)testANoOpChangeOfActiveTouchesNoHostAction
{
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:(id)self.effect delay:YES];

	access.active = NO;
	XCTAssertEqual(self.actionAPI.startCount, (NSUInteger)0);

	access.active = YES;
	access.active = YES;
	XCTAssertEqual(self.actionAPI.startCount, (NSUInteger)1);
}

/*! @abstract Setting active back to NO closes the action, and the accessor may reopen it. */
- (void)testTheActionReopensAfterItIsClosed
{
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:(id)self.effect];

	access.active = NO;
	XCTAssertEqual(self.actionAPI.endCount, (NSUInteger)1);

	access.active = YES;
	XCTAssertEqual(self.actionAPI.startCount, (NSUInteger)2);
	XCTAssertEqualObjects(self.actionAPI.order, (@[@"start", @"end", @"start"]));

	access.active = NO;
}

/*! @abstract startAction opens the action and answers the host's current time. */
- (void)testStartActionReturnsTheHostsCurrentTime
{
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:(id)self.effect delay:YES];

	CMTime time = [access startAction];

	XCTAssertTrue(access.active);
	XCTAssertEqual(time.value, (int64_t)45);
	XCTAssertEqual(time.timescale, (int32_t)30);

	access.active = NO;
}

/*! @abstract The accessor's current time is the host action API's current time. */
- (void)testTheCurrentTimeComesFromTheHostActionAPI
{
	self.actionAPI.currentTime = FxGripParamClassTestTime(120, 60);
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:(id)self.effect];

	CMTime time = access.currentTime;

	XCTAssertEqual(time.value, (int64_t)120);
	XCTAssertEqual(time.timescale, (int32_t)60);
}

#pragma mark Flush

/*! @abstract Closing a flushing accessor posts the effect flush notification on the host's notifier. */
- (void)testClosingAFlushingAccessorPostsTheFlushNotification
{
	__block NSUInteger posts = 0;
	__block id posted = nil;
	id observer = [self.effect.notifier addObserverForName:FxGripTileableEffectFlushName
												   object:nil
													queue:nil
											   usingBlock:^(NSNotification *note) {
		posts += 1;
		posted = note.object;
	}];

	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:(id)self.effect flush:YES];
	access.active = NO;

	XCTAssertEqual(posts, (NSUInteger)1);
	XCTAssertEqualObjects(posted, self.effect);
	XCTAssertEqual(self.actionAPI.endCount, (NSUInteger)1, @"the action still closes");

	[self.effect.notifier removeObserver:observer];
}

/*! @abstract Closing a non-flushing accessor posts no flush notification. */
- (void)testClosingAPlainAccessorPostsNoFlushNotification
{
	__block NSUInteger posts = 0;
	id observer = [self.effect.notifier addObserverForName:FxGripTileableEffectFlushName
												   object:nil
													queue:nil
											   usingBlock:^(NSNotification *note) { posts += 1; }];

	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:(id)self.effect];
	access.active = NO;

	XCTAssertEqual(posts, (NSUInteger)0);

	[self.effect.notifier removeObserver:observer];
}

/*! @abstract An accessor built from the API alone flushes nothing, because it holds no effect to announce on. */
- (void)testAnAPIOnlyAccessorWithFlushPostsNothing
{
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess accessAPI:(id)self.actionAPI];
	access.flush = YES;

	XCTAssertNoThrow(access.active = NO);
	XCTAssertEqual(self.actionAPI.endCount, (NSUInteger)1);
}

@end
