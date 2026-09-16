/*!
	@file       FxGripEffectHostTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripEffectHostTests
	@abstract   Unit tests for the FxGripEffectHost service-resolution functions.
	@discussion Introduced in FxGrip 0.1.0. The meta manager and the parameter-data store resolve
	            in two steps: the host's own member when it has one, else a resolve notification an
	            owning extension answers. The tests cover a nil host, a plain host answered through
	            the notification, and a host that carries the members itself.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripEffectHost.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <BEFoundation/NSPriorityNotificationCenter.h>

/*! A host with the required members only, so every service resolves through a notification. */
@interface FxGripEffectHostTestPlainHost : NSObject <FxGripEffectHost>
@property (nonatomic, strong) NSPriorityNotificationCenter *center;
@end

@implementation FxGripEffectHostTestPlainHost

- (id<FxGripAPIAccessing>)apiManager
{
	return (id)nil;
}

- (NSPriorityNotificationCenter *)notifier
{
	return self.center;
}

- (FxGripTileableEffect *)effectBase
{
	return nil;
}

@end


/*! A host that carries the meta and parameter-data members directly. */
@interface FxGripEffectHostTestMemberHost : FxGripEffectHostTestPlainHost
@property (nonatomic, strong) id metaObject;
@property (nonatomic, strong) id parameterDataObject;
@property (nonatomic, assign) BOOL hasMetaAnswer;
@end

@implementation FxGripEffectHostTestMemberHost

- (id)meta
{
	return self.metaObject;
}

- (BOOL)hasMeta
{
	return self.hasMetaAnswer;
}

- (id)parameterData
{
	return self.parameterDataObject;
}

@end


@interface FxGripEffectHostTests : XCTestCase
@property (nonatomic, strong) NSPriorityNotificationCenter *center;
@property (nonatomic, strong) NSMutableArray *tokens;
@end

@implementation FxGripEffectHostTests

- (void)setUp
{
	[super setUp];
	// The test target does not link BEFoundation, so the class resolves by name.
	self.center = [[NSClassFromString(@"NSPriorityNotificationCenter") alloc] init];
	XCTAssertNotNil(self.center);
	self.tokens = [NSMutableArray array];
}

- (void)tearDown
{
	for (id token in self.tokens) {
		[self.center removeObserver:token];
	}
	[super tearDown];
}

- (FxGripEffectHostTestPlainHost *)plainHost
{
	FxGripEffectHostTestPlainHost *host = [[FxGripEffectHostTestPlainHost alloc] init];
	host.center = self.center;
	return host;
}

- (void)answerNotification:(NSNotificationName)name forHost:(id)host withObject:(id)object
{
	id token = [self.center addObserverForName:name object:host queue:nil usingBlock:^(NSNotification *note) {
		NSMutableDictionary *userInfo = (NSMutableDictionary *)note.userInfo;
		userInfo[FxGripTileableEffectResolvedObjectKey] = object;
	}];
	[self.tokens addObject:token];
}

/*! @abstract A nil host resolves no meta manager, no parameter data, and reports no meta. */
- (void)testNilHostResolvesNothing
{
	XCTAssertNil(FxGripHostMeta(nil));
	XCTAssertNil(FxGripHostParameterData(nil));
	XCTAssertFalse(FxGripHostHasMeta(nil));
}

/*! @abstract A plain host with no answering observer resolves no meta manager and reports no meta. */
- (void)testPlainHostWithoutAnObserverResolvesNoMeta
{
	FxGripEffectHostTestPlainHost *host = [self plainHost];

	XCTAssertNil(FxGripHostMeta(host));
	XCTAssertFalse(FxGripHostHasMeta(host));
	XCTAssertNil(FxGripHostParameterData(host));
}

/*! @abstract A plain host resolves the meta manager an observer sets in the resolve notification. */
- (void)testPlainHostResolvesMetaThroughTheNotification
{
	FxGripEffectHostTestPlainHost *host = [self plainHost];
	id resolved = [[NSObject alloc] init];
	[self answerNotification:FxGripTileableEffectResolveMetaName forHost:host withObject:resolved];

	XCTAssertTrue(FxGripHostMeta(host) == resolved);
	XCTAssertTrue(FxGripHostHasMeta(host));
}

/*! @abstract A plain host resolves the parameter data an observer sets in the resolve notification. */
- (void)testPlainHostResolvesParameterDataThroughTheNotification
{
	FxGripEffectHostTestPlainHost *host = [self plainHost];
	id resolved = [[NSObject alloc] init];
	[self answerNotification:FxGripTileableEffectResolveParameterDataName forHost:host withObject:resolved];

	XCTAssertTrue(FxGripHostParameterData(host) == resolved);
}

/*! @abstract A host that carries the members answers through them without posting a notification. */
- (void)testMemberHostAnswersThroughItsOwnMembers
{
	FxGripEffectHostTestMemberHost *host = [[FxGripEffectHostTestMemberHost alloc] init];
	host.center = self.center;
	host.metaObject = [[NSObject alloc] init];
	host.parameterDataObject = [[NSObject alloc] init];
	host.hasMetaAnswer = NO;
	__block BOOL posted = NO;
	id token = [self.center addObserverForName:FxGripTileableEffectResolveMetaName object:host queue:nil usingBlock:^(NSNotification *note) {
		posted = YES;
	}];
	[self.tokens addObject:token];

	XCTAssertTrue(FxGripHostMeta(host) == host.metaObject);
	XCTAssertTrue(FxGripHostParameterData(host) == host.parameterDataObject);
	XCTAssertFalse(FxGripHostHasMeta(host));
	XCTAssertFalse(posted);
}

@end
