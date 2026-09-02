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

/*! The host's meta manager, resolved once per vended wrapper and cached, so the per-call meta
	bridge does not repeat the resolve notification on a plain host. */
- (nullable FxGripMetaManager *)hostMeta;

/*! YES when hostMeta resolves. */
- (BOOL)hostHasMeta;

/*! The host's parameter data, resolved once per vended wrapper and cached. */
- (nullable FxGripParameterData *)hostParameterData;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

