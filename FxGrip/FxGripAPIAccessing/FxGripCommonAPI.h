//
//  FxGripCommonAPI.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripCommonAPI_h
#define FxGripCommonAPI_h

#import <FxPlug/FxPlugSDK.h>

#import "FxGripEffectHost.h"

/*!
	@interface  FxGripCommonAPI
	@abstract   The base object for our FxGrip  API capture layer.
	@discussion	This captures the effect that is instancing the api
*/
@interface FxGripCommonAPI : NSObject

	@property (readonly, nullable) id<FxGripEffectHost> effect;

- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

