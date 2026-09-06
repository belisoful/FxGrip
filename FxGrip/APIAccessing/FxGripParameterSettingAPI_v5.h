/*!
	@file       FxGripParameterSettingAPI_v5.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterSettingAPI_v5
	@abstract   The FxGrip wrapper for the host's FxParameterSettingAPI_v5.
	@discussion Introduced in FxGrip 0.1.0. The wrapper mirrors the FxPlug 4 v5 protocol and
	            forwards each write to the host API. For a parameter typed Custom, the wrapper
	            reads the current custom value, mutates it through its FxGripMutableParameter
	            accessor, and writes it back. Each successful write posts an FxGrip notification
	            carrying the new value and time so observers can react.
*/

#ifndef FxGripParameterSettingAPI_v5_h
#define FxGripParameterSettingAPI_v5_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameterInfoAPI_v1.h"
#import "FxGripCommonAPI.h"

/*!
	@class		FxGripParameterSettingAPI_v5
	@abstract	FxGrip's wrapper around the host FxParameterSettingAPI_v5.
	@discussion	Introduced in FxGrip 0.1.0. The wrapper forwards writes to the host API, adds
				custom-parameter routing through FxGripMutableParameter, and posts an FxGrip
				notification after each successful write.
*/
@interface FxGripParameterSettingAPI_v5 : FxGripCommonAPI<FxParameterSettingAPI_v5>

	// The upgraded v6 also implements v5
	/*! The wrapped host setting API, held as v6 because the upgraded host object implements both. */
	@property (assign, readonly) id<FxParameterSettingAPI_v6> _Nullable api;
	/*! The parameter-info API used to detect Custom parameters before forwarding. */
	@property (strong, readonly) id<FxGripParameterInfoAPI_v1> _Nullable parameterInfoAPIv1;
	/*! The retrieval API used to read a Custom parameter's current value before mutating it. */
	@property (strong, readonly) id<FxParameterRetrievalAPI_v6> _Nullable paramGetAPIv6;


/*!
	@method		initWithAPI:paramGetAPIv6:parameterInfoAPIv1:effect:
	@abstract	Initializes the setting API wrapper.
	@param		api	The host setting API to wrap.
	@param		paramGetAPIv6	The retrieval API used to read Custom parameter values.
	@param		parameterInfoAPIv1	The parameter-info API used to detect Custom parameters.
	@param		effect	The effect host the API writes to.
*/
- (nullable instancetype)initWithAPI:(id<FxParameterSettingAPI_v5> _Nonnull)api
					   paramGetAPIv6:(id<FxParameterRetrievalAPI_v6>_Nullable)paramGetAPIv6
				   parameterInfoAPIv1:(id<FxGripParameterInfoAPI_v1>_Nullable)parameterInfoAPIv1
							  effect:(nonnull id<FxGripEffectHost>)effect;

@end


#endif /* FxGripParameterSettingAPI_v5_h */

