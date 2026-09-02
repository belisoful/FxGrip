//
//  FxGripOOBParameterAccess.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripAPIAccessing.h"
#import "FxGripTileableEffect+Notifications.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGripOOBParameterAccess.h"
#import "FxGrip_ARC.h"

/**
 This will call the customParameterActionAPIv4 startAction and retain until the end where
 dealloc with endAction is called.   adding ```__attribute__((unused))``` removes the warning
 flags if the variable is not used in any other capacity, like to get the currentTime.
 
 ```
 FxGripOOBParameterAccess *__attribute__((unused)) accessor = [FxGripOOBParameterAccess access:effect.apiManager];
 ```
 
 */

@implementation FxGripOOBParameterAccess
{
	@protected
	BOOL _active;
}

@synthesize active = _active;

#pragma mark -
#pragma mark Initialization

+ (FxGripOOBParameterAccess*_Nonnull)accessAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI
{
	return NARC_AUTORELEASE([FxGripOOBParameterAccess.alloc initWithAPI:customParamActionAPI]);
}

+ (FxGripOOBParameterAccess*_Nonnull)accessAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI
										   delay:(BOOL)delayed
{
	return NARC_AUTORELEASE([FxGripOOBParameterAccess.alloc initWithAPI:customParamActionAPI delay:delayed]);
}


+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect
{
	return NARC_AUTORELEASE([FxGripOOBParameterAccess.alloc initWithEffect:effect]);
}

+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect
										   delay:(BOOL)delayed
{
	return NARC_AUTORELEASE([FxGripOOBParameterAccess.alloc initWithEffect:effect delay:delayed]);
}

+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect
									  flush:(BOOL)flush
{
	return NARC_AUTORELEASE([FxGripOOBParameterAccess.alloc initWithEffect:effect flush:flush]);
}

+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect
									  delay:(BOOL)delayed
									  flush:(BOOL)flush
{
	return NARC_AUTORELEASE([FxGripOOBParameterAccess.alloc initWithEffect:effect delay:delayed flush:flush]);
}


- (nullable instancetype)init
{
	self = [super init];
	_active = NO;
	if (self != nil) {
		NSLog(@"MasterFxOOBParameterAccess::init Error - Must have an apiManager to initialize");
		return nil;
	}
	return self;
}

// Initiates an immediate "startAction", active = YES.
- (nullable instancetype)initWithAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI
{
	return [self initWithAPI:customParamActionAPI delay:NO];
}

- (nullable instancetype)initWithAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI
							   delay:(BOOL)delayed
{
	if (!customParamActionAPI) {
		return nil;
	}
	self = [super init];
	
	if (self != nil)
	{
		_active = NO;
		_flush = NO;
		_customParameterActionAPIv4 = customParamActionAPI;
		self.active = !delayed;
	}
	return self;
}


- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
{
	return [self initWithEffect:effect delay:NO flush:NO];
}


- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
								  delay:(BOOL)delayed
{
	return [self initWithEffect:effect delay:delayed flush:NO];
}


- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
							   flush:(BOOL)flush
{
	return [self initWithEffect:effect delay:NO flush:flush];
}

- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
								  delay:(BOOL)delayed
								  flush:(BOOL)flush
{
	if (!effect) {
		return nil;
	}
	self = [super init];
	
	if (self != nil)
	{
	 	_active = NO;
		_flush = flush;
		_customParameterActionAPIv4 = effect.apiManager.customParameterActionAPIv4;
		_effect = effect;
		self.active = !delayed;
	}
	return self;
}



- (void)dealloc
{
	// Call endAction if needed to close the connection.
	if (_active) {
		self.active = NO;
	}
	_customParameterActionAPIv4 = nil;
	
	SUPER_DEALLOC();
}

#pragma mark -
#pragma mark Implementation

- (CMTime)currentTime
{
	return [_customParameterActionAPIv4 currentTime];
}

// return the [self currentTime]
- (CMTime)startAction
{
	[_customParameterActionAPIv4 startAction:self];
	_active = YES;
	return [_customParameterActionAPIv4 currentTime];
}

- (void)endAction
{
	if (_flush && _effect) {
		// The flush is announced on the host's notifier; the extensions observe it there, which is
		// exactly what the effect base's extensionsFlush did.
		NSMutableDictionary *userInfo = @{}.mutableCopy;
		[_effect.notifier postNotificationName:FxGripTileableEffectFlushName object:_effect userInfo:userInfo];
	}
	[_customParameterActionAPIv4 endAction:self];
	_active = NO;
}


- (void) setActive:(BOOL)value
{
	if(value != _active) {
		if(value) {
			[self startAction];
		} else {
			[self endAction];
		}
	}
}

@end
