/*!
	@file       FxGripOOBParameterAccess.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripOOBParameterAccess
	@abstract   Implements the scoped host-action wrapper for out-of-band parameter edits.
	@discussion Introduced in FxGrip 0.1.0. The active property drives startAction and endAction. The
	            instance closes an open action on dealloc, so a stack variable brackets an edit for its
	            own lifetime.
*/

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

/*!
	@abstract	Brackets a host parameter edit made from outside the managed call stack.
	@discussion	Introduced in FxGrip 0.1.0. The active flag opens and closes the host action, and dealloc
				closes an action still open.
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

/*! @abstract Opens the host action window and returns the host's current time. */
// return the [self currentTime]
- (CMTime)startAction
{
	[_customParameterActionAPIv4 startAction:self];
	_active = YES;
	return [_customParameterActionAPIv4 currentTime];
}

/*! @abstract Posts the flush notification when flush is set, then closes the host action window. */
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


/*! @abstract Starts the action when set to YES and ends it when set to NO, ignoring a no-op change. */
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
