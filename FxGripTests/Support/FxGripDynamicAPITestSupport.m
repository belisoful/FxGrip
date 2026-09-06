//
//  FxGripDynamicAPITestSupport.m
//  FxGripTests
//

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

CMTime FxGripDynamicTestTime(void)
{
	return (CMTime){.value = 4, .timescale = 25, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

NSError *FxGripDynamicTestError(void)
{
	return [NSError errorWithDomain:@"FxGripDynamicTest" code:7 userInfo:nil];
}

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

- (void)observeName:(NSNotificationName)name usingBlock:(void (^)(NSNotification *notification))block
{
	id token = [self.effect.notifier addObserverForName:name object:nil queue:nil usingBlock:block];
	[self.observerTokens addObject:token];
}

- (NSArray<NSNotificationName> *)postedNames
{
	NSMutableArray<NSNotificationName> *names = NSMutableArray.new;
	for (NSNotification *notification in self.posted) {
		[names addObject:notification.name];
	}
	return names;
}

- (NSNotification *)notificationNamed:(NSNotificationName)name
{
	for (NSNotification *notification in self.posted) {
		if ([notification.name isEqualToString:name]) {
			return notification;
		}
	}
	return nil;
}

- (NSArray<NSString *> *)hostMethods
{
	NSMutableArray<NSString *> *methods = NSMutableArray.new;
	for (NSDictionary *call in self.hostAPI.calls) {
		[methods addObject:call[@"method"]];
	}
	return methods;
}

- (NSDictionary *)hostCallNamed:(NSString *)method
{
	for (NSDictionary *call in self.hostAPI.calls) {
		if ([call[@"method"] isEqualToString:method]) {
			return call;
		}
	}
	return nil;
}

- (FxGripDynamicParameterAPI_v3 *)apiV3
{
	return [FxGripDynamicParameterAPI_v3.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
}

- (FxGripParameterInfoAPI_v1 *)apiInfo
{
	return [FxGripParameterInfoAPI_v1.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
}

- (FxGripParameterBoundsAPI_v1 *)apiBounds
{
	return [FxGripParameterBoundsAPI_v1.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
}

@end
