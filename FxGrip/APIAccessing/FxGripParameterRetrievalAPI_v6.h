//
//  FxGripParameterRetrievalAPI_v6.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripParameterRetrievalAPI_v6_h
#define FxGripParameterRetrievalAPI_v6_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameterInfoAPI_v1.h"
#import "FxGripCommonAPI.h"

/*!
	@interface  FxGripParameterRetrievalAPI_v6:
	@abstract   Initializes the API manager for your plug-in.
	@discussion Accesses the apis with error checking.

 */

@interface FxGripParameterRetrievalAPI_v6 : FxGripCommonAPI<FxParameterRetrievalAPI_v6>

	@property (assign, readonly) id<FxParameterRetrievalAPI_v6> _Nullable api;
	@property (strong, readonly) id<FxParameterInfoAPI_v1> _Nullable parameterInfoAPIv1;

- (nullable instancetype)initWithAPI:(id<FxParameterRetrievalAPI_v6> _Nonnull)api
				   parameterInfoAPIv1:(id<FxParameterInfoAPI_v1>_Nullable)parameterInfoAPIv1 effect:(nonnull id<FxGripEffectHost>)effect;

@end


#endif /* FxGripParameterRetrievalAPI_v6_h */

