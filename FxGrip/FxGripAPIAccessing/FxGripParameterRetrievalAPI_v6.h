//
//  FxGripParameterRetrievalAPI_v6.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripParameterRetrievalAPI_v6_h
#define FxGripParameterRetrievalAPI_v6_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripDynamicParameterAPI_v4.h"
#import "FxGripCommonAPI.h"

/*!
	@interface  FxGripParameterRetrievalAPI_v6:
	@abstract   Initializes the API manager for your plug-in.
	@discussion Accesses the apis with error checking.

 */

@interface FxGripParameterRetrievalAPI_v6 : FxGripCommonAPI<FxParameterRetrievalAPI_v6>

	@property (assign, readonly) id<FxParameterRetrievalAPI_v6> _Nullable api;
	@property (strong, readonly) id<FxDynamicParameterAPI_v4> _Nullable dynamicParamAPIv4;

- (nullable instancetype)initWithAPI:(id<FxParameterRetrievalAPI_v6> _Nonnull)api
				   dynamicParamAPIv4:(id<FxDynamicParameterAPI_v4>_Nullable)dynamicParamAPIv4 effect:(nonnull id<FxTileableEffectBase>)effect;

@end


#endif /* FxGripParameterRetrievalAPI_v6_h */

