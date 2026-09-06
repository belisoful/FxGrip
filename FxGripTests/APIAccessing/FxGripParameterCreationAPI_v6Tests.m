/*!
	@file       FxGripParameterCreationAPI_v6Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterCreationAPI_v6Tests
	@abstract   Verifies that the v6 creation wrapper forwards the tagged popup menu to the host, posts the add notification, and remains a v5 wrapper.
	@discussion Introduced in FxGrip 0.1.0. The tests drive the wrapper against a recording stub host and an isolated notifier. They assert the forwarded arguments, the notification on success, the suppressed notification on failure, and the v5 protocol conformance.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripParameterCreationAPI_v6.h>
#import <FxGrip/FxGripAPINotifications.h>

/*! A stand-in host v6 creation API recording the tagged-popup request. */
@interface FxGripCreate6StubAPI : NSObject
@property (nonatomic, copy) NSString *lastName;
@property (nonatomic, assign) UInt32 lastParameterID;
@property (nonatomic, assign) UInt32 lastDefaultValue;
@property (nonatomic, strong) NSArray *lastEntries;
@property (nonatomic, assign) BOOL stagedResult;
@end

@implementation FxGripCreate6StubAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_stagedResult = YES;
	}
	return self;
}

- (BOOL)addTaggedPopupMenuWithName:(NSString *)name
					   parameterID:(UInt32)parameterID
					  defaultValue:(UInt32)defaultValue
					   menuEntries:(NSArray *)entries
					parameterFlags:(FxParameterFlags)flags
{
	self.lastName = name;
	self.lastParameterID = parameterID;
	self.lastDefaultValue = defaultValue;
	self.lastEntries = entries;
	return self.stagedResult;
}

@end

@interface FxGripCreate6StubEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@end

@implementation FxGripCreate6StubEffect
- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = [NSNotificationCenter new];
	}
	return self;
}
@end

@interface FxGripParameterCreationAPI_v6Tests : XCTestCase
@property (nonatomic, strong) FxGripCreate6StubAPI *host;
@property (nonatomic, strong) FxGripCreate6StubEffect *effect;
@property (nonatomic, strong) FxGripParameterCreationAPI_v6 *wrapper;
@property (nonatomic, strong) NSMutableArray<NSNotificationName> *posted;
@property (nonatomic, strong) NSMutableArray *tokens;
@end

@implementation FxGripParameterCreationAPI_v6Tests

- (void)setUp
{
	[super setUp];
	self.host = FxGripCreate6StubAPI.new;
	self.effect = FxGripCreate6StubEffect.new;
	self.wrapper = [FxGripParameterCreationAPI_v6.alloc initWithAPI:(id)self.host effect:(id)self.effect];

	self.posted = NSMutableArray.new;
	self.tokens = NSMutableArray.new;
	for (NSNotificationName name in @[FxGripNotifyAPI_ParameterAddName, FxGripNotifyAPI_ParameterAddPreName]) {
		id token = [self.effect.notifier addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
			[self.posted addObject:note.name];
		}];
		[self.tokens addObject:token];
	}
}

- (void)tearDown
{
	for (id token in self.tokens) {
		[self.effect.notifier removeObserver:token];
	}
	[super tearDown];
}

/*! @abstract Adding a tagged popup menu forwards the name, ID, default value, and entries to the host and posts the add notification on success. */
- (void)testAddTaggedPopupForwardsToTheHostAndPostsTheAddNotification
{
	NSArray *entries = @[NSObject.new, NSObject.new];
	BOOL ok = [self.wrapper addTaggedPopupMenuWithName:@"Mode"
										  parameterID:7
										 defaultValue:2
										  menuEntries:(id)entries
									   parameterFlags:kFxParameterFlag_DEFAULT];

	XCTAssertTrue(ok);
	XCTAssertEqualObjects(self.host.lastName, @"Mode");
	XCTAssertEqual(self.host.lastParameterID, (UInt32)7);
	XCTAssertEqual(self.host.lastDefaultValue, (UInt32)2);
	XCTAssertEqual(self.host.lastEntries.count, (NSUInteger)2);
	XCTAssertTrue([self.posted containsObject:FxGripNotifyAPI_ParameterAddName], @"a successful add posts the notification");
}

/*! @abstract A failing host add returns NO and posts no add notification. */
- (void)testAFailingHostAddReturnsNOAndDoesNotPostTheAdd
{
	self.host.stagedResult = NO;
	BOOL ok = [self.wrapper addTaggedPopupMenuWithName:@"Mode"
										  parameterID:7
										 defaultValue:0
										  menuEntries:(id)@[]
									   parameterFlags:kFxParameterFlag_DEFAULT];

	XCTAssertFalse(ok);
	XCTAssertFalse([self.posted containsObject:FxGripNotifyAPI_ParameterAddName], @"a failed add does not post the add notification");
}

/*! @abstract The v6 wrapper conforms to both the v6 and v5 creation protocols and subclasses the v5 wrapper. */
- (void)testTheV6WrapperIsAlsoAV5Wrapper
{
	XCTAssertTrue([self.wrapper conformsToProtocol:@protocol(FxParameterCreationAPI_v6)]);
	XCTAssertTrue([self.wrapper conformsToProtocol:@protocol(FxParameterCreationAPI_v5)]);
	XCTAssertTrue([self.wrapper isKindOfClass:FxGripParameterCreationAPI_v5.class]);
}

@end
