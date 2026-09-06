/*!
	@file       FxGripDynamicAPITestSupport.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDynamicAPITestSupport
	@abstract   Shared stubs and an XCTestCase base for the dynamic-parameter API wrapper tests.
	@discussion Introduced in FxGrip 0.1.0. The stub host API records every call and vends canned values, the stub effect carries a priority notification center resolved by name, and the test-case base wires them together, observes the recorded notification names, and vends the wrapper instances under test.
*/

#import "FxGripDynamicAPITestSupport.h"
#import <FxGrip/FxGripAPINotifications.h>

const FxParameterId kDynamicTestParameter = 41;

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxGripDynamicTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

/*! @abstract Returns a fixed valid CMTime used across the dynamic-API tests. */
CMTime FxGripDynamicTestTime(void)
{
	return (CMTime){.value = 4, .timescale = 25, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

/*! @abstract Returns a fixed error used to drive the wrappers' failure paths. */
NSError *FxGripDynamicTestError(void)
{
	return [NSError errorWithDomain:@"FxGripDynamicTest" code:7 userInfo:nil];
}

/*!
	@abstract A stub host dynamic-parameter API that records every call and returns configured values.
	@discussion Introduced in FxGrip 0.1.0. Each protocol method appends its arguments to the calls array and returns the configured value or error, so a test asserts on the recorded calls and the values the wrapper reads back.
*/
@implementation FxGripDynamicTestStubAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_calls = NSMutableArray.new;
		_parameterIDs = @[];
		_defaultsSucceed = YES;
	}
	return self;
}

/*! @abstract Records a call under its method name and returns the configured next error. */
- (NSError *)record:(NSString *)method arguments:(NSDictionary *)arguments
{
	NSMutableDictionary *call = arguments.mutableCopy;
	call[@"method"] = method;
	[self.calls addObject:call.copy];
	return self.nextError;
}

- (UInt32)parameterCount
{
	[self record:@"count" arguments:@{}];
	return (UInt32)self.parameterIDs.count;
}

- (UInt32)parameterIDAtIndex:(UInt32)index
{
	[self record:@"idatindex" arguments:@{@"index": @(index)}];
	return self.parameterIDs[index].unsignedIntValue;
}

- (NSError *)removeParameter:(UInt32)parameterID
{
	return [self record:@"remove" arguments:@{@"id": @(parameterID)}];
}

- (NSError *)parameter:(UInt32)parameterID name:(NSString **)parameterName
{
	NSError *error = [self record:@"getname" arguments:@{@"id": @(parameterID)}];
	if (!error && parameterName) {
		*parameterName = self.hostName;
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID name:(NSString *)newName
{
	return [self record:@"setname" arguments:@{@"id": @(parameterID), @"name": newName ?: NSNull.null}];
}

- (NSError *)parameter:(UInt32)parameterID
		  floatMinimum:(double *)min
			   maximum:(double *)max
		 sliderMinimum:(double *)sliderMin
		 sliderMaximum:(double *)sliderMax
{
	NSError *error = [self record:@"getfloatbounds" arguments:@{@"id": @(parameterID)}];
	if (error) {
		return error;
	}
	*min = self.floatMinimum;
	*max = self.floatMaximum;
	*sliderMin = self.floatSliderMinimum;
	*sliderMax = self.floatSliderMaximum;
	return nil;
}

- (NSError *)setParameter:(UInt32)parameterID
			 floatMinimum:(double)min
				  maximum:(double)max
			sliderMinimum:(double)sliderMin
			sliderMaximum:(double)sliderMax
{
	return [self record:@"setfloatbounds" arguments:@{@"id": @(parameterID),
													  @"min": @(min),
													  @"max": @(max),
													  @"slidermin": @(sliderMin),
													  @"slidermax": @(sliderMax)}];
}

- (NSError *)parameter:(UInt32)parameterID
			intMinimum:(int *)min
			   maximum:(int *)max
		 sliderMinimum:(int *)sliderMin
		 sliderMaximum:(int *)sliderMax
{
	NSError *error = [self record:@"getintbounds" arguments:@{@"id": @(parameterID)}];
	if (error) {
		return error;
	}
	*min = self.intMinimum;
	*max = self.intMaximum;
	*sliderMin = self.intSliderMinimum;
	*sliderMax = self.intSliderMaximum;
	return nil;
}

- (NSError *)setParameter:(UInt32)parameterID
			   intMinimum:(int)min
				  maximum:(int)max
			sliderMinimum:(int)sliderMin
			sliderMaximum:(int)sliderMax
{
	return [self record:@"setintbounds" arguments:@{@"id": @(parameterID),
													@"min": @(min),
													@"max": @(max),
													@"slidermin": @(sliderMin),
													@"slidermax": @(sliderMax)}];
}

- (NSError *)setPopupMenuParameter:(UInt32)parameterID
						   entries:(NSArray<NSString *> *)newEntries
					  defaultValue:(UInt32)defaultIndex
{
	return [self record:@"setmenu" arguments:@{@"id": @(parameterID),
											   @"items": newEntries ?: NSNull.null,
											   @"default": @(defaultIndex)}];
}

- (BOOL)setAsDefaultsAtTime:(CMTime)time withError:(NSError **)error
{
	self.lastDefaultsTime = time;
	[self record:@"setdefaults" arguments:@{}];
	if (!self.defaultsSucceed && error) {
		*error = FxGripDynamicTestError();
	}
	return self.defaultsSucceed;
}

@end

/*!
	@abstract A stub effect that stands in for the host effect and carries a priority notification center.
	@discussion Introduced in FxGrip 0.1.0. It answers -effectBase with itself so rich reads route back to the stub, and it creates its notifier from NSPriorityNotificationCenter resolved at runtime.
*/
@implementation FxGripDynamicTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxGripDynamicTestMakePriorityCenter();
	}
	return self;
}

- (id)objectAtIndexedSubscript:(NSInteger)index
{
	return nil;
}

@end

/*!
	@abstract An XCTestCase base that wires the stub effect and host API together and observes the recorded notifications.
	@discussion Introduced in FxGrip 0.1.0. It builds the stubs in -setUp, subscribes to the recorded notification names, and vends the dynamic, info, and bounds wrapper instances under test. Helper accessors expose the posted notifications and recorded host calls.
*/
@implementation FxGripDynamicAPITestCase

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripDynamicTestStubEffect.alloc init];
	self.hostAPI = [FxGripDynamicTestStubAPI.alloc init];
	self.posted = NSMutableArray.new;
	self.observerTokens = NSMutableArray.new;
	for (NSNotificationName name in self.recordedNotificationNames) {
		[self observeName:name usingBlock:^(NSNotification *notification) {
			[self.posted addObject:notification];
		}];
	}
}

- (void)tearDown
{
	for (id token in self.observerTokens) {
		[self.effect.notifier removeObserver:token];
	}
	self.observerTokens = nil;
	self.posted = nil;
	self.hostAPI = nil;
	self.effect = nil;
	[super tearDown];
}

/*! @abstract Returns the notification names the base subscribes to in -setUp. */
- (NSArray<NSNotificationName> *)recordedNotificationNames
{
	return @[FxGripNotifyAPI_ParameterRemoveName,
			 FxGripNotifyAPI_ParameterGetNameName,
			 FxGripNotifyAPI_ParameterSetNamePreName,
			 FxGripNotifyAPI_ParameterSetNameName,
			 FxGripNotifyAPI_ParameterGetTypeName,
			 FxGripNotifyAPI_ParameterSetFloatBoundsName,
			 FxGripNotifyAPI_ParameterSetIntBoundsName,
			 FxGripNotifyAPI_ParameterGetMenuName,
			 FxGripNotifyAPI_ParameterSetMenuPreName,
			 FxGripNotifyAPI_ParameterSetMenuName];
}

/*! @abstract Adds a notification observer to the effect's notifier and tracks its token for teardown. */
- (void)observeName:(NSNotificationName)name usingBlock:(void (^)(NSNotification *notification))block
{
	id token = [self.effect.notifier addObserverForName:name object:nil queue:nil usingBlock:block];
	[self.observerTokens addObject:token];
}

/*! @abstract Returns the names of the notifications posted so far, in order. */
- (NSArray<NSNotificationName> *)postedNames
{
	NSMutableArray<NSNotificationName> *names = NSMutableArray.new;
	for (NSNotification *notification in self.posted) {
		[names addObject:notification.name];
	}
	return names;
}

/*! @abstract Returns the first posted notification with the given name, or nil. */
- (NSNotification *)notificationNamed:(NSNotificationName)name
{
	for (NSNotification *notification in self.posted) {
		if ([notification.name isEqualToString:name]) {
			return notification;
		}
	}
	return nil;
}

/*! @abstract Returns the recorded host-call method names, in order. */
- (NSArray<NSString *> *)hostMethods
{
	NSMutableArray<NSString *> *methods = NSMutableArray.new;
	for (NSDictionary *call in self.hostAPI.calls) {
		[methods addObject:call[@"method"]];
	}
	return methods;
}

/*! @abstract Returns the first recorded host call with the given method name, or nil. */
- (NSDictionary *)hostCallNamed:(NSString *)method
{
	for (NSDictionary *call in self.hostAPI.calls) {
		if ([call[@"method"] isEqualToString:method]) {
			return call;
		}
	}
	return nil;
}

/*! @abstract Vends a dynamic-parameter v3 wrapper over the stub host API and effect. */
- (FxGripDynamicParameterAPI_v3 *)apiV3
{
	return [FxGripDynamicParameterAPI_v3.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
}

/*! @abstract Vends a parameter-info v1 wrapper over the stub host API and effect. */
- (FxGripParameterInfoAPI_v1 *)apiInfo
{
	return [FxGripParameterInfoAPI_v1.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
}

/*! @abstract Vends a parameter-bounds v1 wrapper over the stub host API and effect. */
- (FxGripParameterBoundsAPI_v1 *)apiBounds
{
	return [FxGripParameterBoundsAPI_v1.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
}

@end
