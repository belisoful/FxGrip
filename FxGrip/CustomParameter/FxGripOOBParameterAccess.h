/*!
	@file       FxGripOOBParameterAccess.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripOOBParameterAccess
	@abstract   Scoped wrapper that brackets host parameter edits from outside the managed call stack.
	@discussion Introduced in FxGrip 0.1.0. A custom parameter view receives AppKit callbacks outside
	            the host's managed plugin call stack, where the plugin cannot reach the host parameters.
	            This class wraps FxCustomParameterActionAPI_v4, calling startAction when it becomes active
	            and endAction when it deactivates or deallocates. Holding an instance for the duration of
	            an edit opens an out-of-band window in which the standard parameter set API reaches the host.
*/

#ifndef FxGripOOBParameterAccess_h
#define FxGripOOBParameterAccess_h

#import <Foundation/Foundation.h>
#import "FxGripTileableEffect.h"

/*!
	@class		FxGripOOBParameterAccess
	@abstract	Brackets a host parameter edit made from outside the managed call stack.
	@discussion	Introduced in FxGrip 0.1.0. The instance calls startAction on FxCustomParameterActionAPI_v4
				when it becomes active and endAction when it deactivates or deallocates. Use it only when a
				custom view is driven by the OS outside the managed host connection for the plugin.
 */
@interface FxGripOOBParameterAccess : NSObject

	/*! The wrapped host action API. */
	@property (readonly) id<FxCustomParameterActionAPI_v4> _Nullable customParameterActionAPIv4;
	/*! The effect host, when the accessor was created from one. */
	@property (readonly) id<FxGripEffectHost> _Nullable effect;

	/*! The host's current time, read from the action API. */
	@property (nonatomic, assign, readonly) CMTime currentTime;
	/*! Whether the action window is open. Setting it calls startAction or endAction. */
	@property (readwrite, assign, nonatomic) BOOL active;
	/*! When YES, endAction posts the effect's flush notification before closing the action. */
	@property (readwrite, assign, atomic) BOOL flush;

/*! Creates an autoreleased accessor from an action API and starts the action. */
+ (FxGripOOBParameterAccess*_Nonnull)accessAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI;;
/*! Creates an autoreleased accessor from an action API; delayed defers the startAction. */
+ (FxGripOOBParameterAccess*_Nonnull)accessAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI
										 delay:(BOOL)delayed;

/*! Creates an autoreleased accessor from an effect host and starts the action. */
+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect;
/*! Creates an autoreleased accessor from an effect host; delayed defers the startAction. */
+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect
										 delay:(BOOL)delayed;
/*! Creates an autoreleased accessor from an effect host; flush posts the flush notification on endAction. */
+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect
										 flush:(BOOL)flush;
/*! Creates an autoreleased accessor from an effect host with explicit delay and flush. */
+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect
										 delay:(BOOL)delayed
										 flush:(BOOL)flush;

/*! Initializes from an action API and starts the action. Returns nil for a nil API. */
- (nullable instancetype)initWithAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI;
/*! Initializes from an action API; delayed defers the startAction. */
- (nullable instancetype)initWithAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI
							   delay:(BOOL)delayed;
/*! Initializes from an effect host and starts the action. Returns nil for a nil effect. */
- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect;
/*! Initializes from an effect host; delayed defers the startAction. */
- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
							   delay:(BOOL)delayed;
/*! Initializes from an effect host; flush posts the flush notification on endAction. */
- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
							   flush:(BOOL)flush;
/*! Initializes from an effect host with explicit delay and flush. */
- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
							   delay:(BOOL)delayed
							   flush:(BOOL)flush;

/*! Opens the action window and returns the host's current time. */
- (CMTime)startAction;
/*! Closes the action window, posting the flush notification first when flush is set. */
- (void)endAction;

@end

#endif /* FxGripOOBParameterAccess */
