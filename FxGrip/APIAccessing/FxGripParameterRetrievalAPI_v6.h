/*!
	@file       FxGripParameterRetrievalAPI_v6.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterRetrievalAPI_v6
	@abstract   The FxGrip wrapper for the host's FxParameterRetrievalAPI_v6.
	@discussion Introduced in FxGrip 0.1.0. The wrapper mirrors the FxPlug 4 v6 protocol and
	            forwards each read to the host API. For a parameter typed Custom, the wrapper
	            reads the custom value and routes the request to the value's FxGripMutableParameter
	            accessor when it responds. String and flag reads post FxGrip notifications so
	            observers can supply or amend the value.
*/

#ifndef FxGripParameterRetrievalAPI_v6_h
#define FxGripParameterRetrievalAPI_v6_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameterInfoAPI_v1.h"
#import "FxGripCommonAPI.h"

/*!
	@class		FxGripParameterRetrievalAPI_v6
	@abstract	FxGrip's wrapper around the host FxParameterRetrievalAPI_v6.
	@discussion	Introduced in FxGrip 0.1.0. The wrapper forwards reads to the host API, adds
				custom-parameter routing through FxGripMutableParameter, and posts FxGrip
				notifications for string and flag reads.
*/
@interface FxGripParameterRetrievalAPI_v6 : FxGripCommonAPI<FxParameterRetrievalAPI_v6>

	/*! The wrapped host retrieval API. */
	@property (assign, readonly) id<FxParameterRetrievalAPI_v6> _Nullable api;
	/*! The parameter-info API used to detect Custom parameters before forwarding. */
	@property (strong, readonly) id<FxGripParameterInfoAPI_v1> _Nullable parameterInfoAPIv1;

/*!
	@method		initWithAPI:parameterInfoAPIv1:effect:
	@abstract	Initializes the retrieval API wrapper.
	@param		api	The host retrieval API to wrap.
	@param		parameterInfoAPIv1	The parameter-info API used to detect Custom parameters.
	@param		effect	The effect host the API queries.
*/
- (nullable instancetype)initWithAPI:(id<FxParameterRetrievalAPI_v6> _Nonnull)api
				   parameterInfoAPIv1:(id<FxGripParameterInfoAPI_v1>_Nullable)parameterInfoAPIv1 effect:(nonnull id<FxGripEffectHost>)effect;

@end


#endif /* FxGripParameterRetrievalAPI_v6_h */

