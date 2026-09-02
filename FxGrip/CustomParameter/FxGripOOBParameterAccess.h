//
//  FxGripOOBParameterAccess.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripOOBParameterAccess_h
#define FxGripOOBParameterAccess_h

#import <Foundation/Foundation.h>
#import "FxGripTileableEffect.h"

/*!
	@interface  FxGripOOBParameterAccess
	@abstract   Wraps the FxCustomParameterActionAPIv4 in a class that calls -startAction on
 				instancing, and endAction when dealloc.
	@discussion This is a utility call and should only be used when a custom view is called
 				by the OS outside the managed host connection for the plugin.
 				When the OS does UI callbacks on custom Parameter NSView[s], the plugin doesn't
 				know about or have access to the host parameters.  FxCustomParameterActionAPIv4
 				is used to connect to the host application outside the usual managed scope of the
 				FxTileableEffect protocol implementation call stack.
 */
@interface FxGripOOBParameterAccess : NSObject

	@property (readonly) id<FxCustomParameterActionAPI_v4> _Nullable customParameterActionAPIv4;
	@property (readonly) id<FxGripEffectHost> _Nullable effect;

	@property (nonatomic, assign, readonly) CMTime currentTime;
	@property (readwrite, assign, nonatomic) BOOL active;
	@property (readwrite, assign, atomic) BOOL flush;

+ (FxGripOOBParameterAccess*_Nonnull)accessAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI;;
+ (FxGripOOBParameterAccess*_Nonnull)accessAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI
										 delay:(BOOL)delayed;

+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect;
+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect
										 delay:(BOOL)delayed;
+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect
										 flush:(BOOL)flush;
+ (FxGripOOBParameterAccess*_Nonnull)access:(nonnull id<FxGripEffectHost>)effect
										 delay:(BOOL)delayed
										 flush:(BOOL)flush;

- (nullable instancetype)initWithAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI;
- (nullable instancetype)initWithAPI:(nonnull id<FxCustomParameterActionAPI_v4>)customParamActionAPI
							   delay:(BOOL)delayed;
- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect;
- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
							   delay:(BOOL)delayed;
- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
							   flush:(BOOL)flush;
- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
							   delay:(BOOL)delayed
							   flush:(BOOL)flush;

- (CMTime)startAction;
- (void)endAction;

@end

#endif /* FxGripOOBParameterAccess */
