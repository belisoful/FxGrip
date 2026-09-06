/*!
	@file       FxGripParameterInfoAPI_v1.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterInfoAPI_v1
	@abstract   The read-only parameter query API in the style of Apple's FxPlug APIs.
	@discussion Introduced in FxGrip 0.1.0. The API reports parameter existence, type, menu
	            entries, and the full ID list. FxGrip owns this API; no host vends it. Existence
	            and the ID list walk Apple's dynamic-parameter roster; type and menu entries
	            resolve through the effect's notification seam.
*/

#ifndef FxGripParameterInfoAPI_v1_h
#define FxGripParameterInfoAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import "FxGripCommonAPI.h"

/*!
	@protocol   FxGripParameterInfoAPI_v1
	@abstract   Read-only queries about a plug-in's parameters, in the style of Apple's FxPlug APIs.
	@discussion Introduced in FxGrip 0.1.0. FxGrip's own API. Reports parameter existence, type,
				menu entries, and the full ID list. Existence and the ID list walk Apple's
				dynamic-parameter roster (parameterCount/parameterIDAtIndex:); type and menu
				entries resolve through the effect's notification seam.
*/
@protocol FxGripParameterInfoAPI_v1 <NSObject>

/*! YES when a parameter with this ID is registered. */
- (BOOL)parameterExists:(FxParameterId)parameterID;

/*! The parameter's type, or FxParameterType_None when it does not resolve. */
- (FxParameterType)parameterType:(FxParameterId)parameterID;

/*! Fills `entries` with a menu parameter's item titles. */
- (NSError* _Nullable)parameter:(FxParameterId)parameterID entries:(NSArray<NSString*>* _Nonnull * _Nonnull)entries;

/*! Every registered parameter ID, in roster order. */
- (NSArray<NSNumber*>* _Nonnull)allParameterIDs;

@end


/*!
	@interface  FxGripParameterInfoAPI_v1
	@abstract   FxGrip's implementation of FxGripParameterInfoAPI_v1.
	@discussion Introduced in FxGrip 0.1.0. Wraps Apple's FxDynamicParameterAPI_v3 for the roster
				walk. Vended by FxGripAPIAccessing's parameterInfoAPIv1. Previously these queries
				lived on the fabricated FxGripDynamicParameterAPI_v4.
*/
@interface FxGripParameterInfoAPI_v1 : FxGripCommonAPI <FxGripParameterInfoAPI_v1>

@property (assign, readonly) id<FxDynamicParameterAPI_v3> _Nullable api;

- (nullable instancetype)initWithAPI:(id<FxDynamicParameterAPI_v3> _Nullable)api
							  effect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif /* FxGripParameterInfoAPI_v1_h */
