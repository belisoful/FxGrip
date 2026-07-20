//
//  FxGripParameterSettingAPI_v5.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripParameterSettingAPI_v5_h
#define FxGripParameterSettingAPI_v5_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripDynamicParameterAPI_v4.h"
#import "FxGripCommonAPI.h"

/*!
	@interface  FxGripParameterRetrievalAPI_v6:
	@abstract   Initializes the API manager for your plug-in.
	@discussion Accesses the apis with error checking.

 */

@interface FxGripParameterSettingAPI_v5 : FxGripCommonAPI<FxParameterSettingAPI_v5>

	// The upgraded v6 also impleents v5
	@property (assign, readonly) id<FxParameterSettingAPI_v6> _Nullable api;
	@property (strong, readonly) id<FxDynamicParameterAPI_v4> _Nullable dynamicParamAPIv4;
	@property (strong, readonly) id<FxParameterRetrievalAPI_v6> _Nullable paramGetAPIv6;


- (nullable instancetype)initWithAPI:(id<FxParameterSettingAPI_v5> _Nonnull)api
					   paramGetAPIv6:(id<FxParameterRetrievalAPI_v6>_Nullable)paramGetAPIv6
				   dynamicParamAPIv4:(id<FxDynamicParameterAPI_v4>_Nullable)dynamicParamAPIv4
							  effect:(nonnull id<FxTileableEffectBase>)effect;

@end


#endif /* FxGripParameterSettingAPI_v5_h */

