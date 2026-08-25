//
//  FxGripParameterCreationAPI_v5.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripDynamicParameterAPI_v3_h
#define FxGripDynamicParameterAPI_v3_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripCommonAPI.h>

/*!
	@interface  FxGripDynamicParameterAPI_v3
	@abstract   Allows your plugin to create parameters on-the-fly
	@discussion With this API your plugin can create and remove parameters outside of its
				-addParameters method. It can also get and set various properties of parameters
				during run-time, as well, such as the minimum and maximum allowable values.
				NOTE: You should only implement this protocol in plug-ins that use FxPlug 4
				or later. It will not be called in plug-ins that are written with FxPlug 2 or 3.
*/
@interface FxGripDynamicParameterAPI_v3 : FxGripCommonAPI<FxDynamicParameterAPI_v3>

	@property (assign, readonly) id<FxDynamicParameterAPI_v3> _Nonnull api;

- (nullable instancetype)initWithAPI:(id<FxDynamicParameterAPI_v3> _Nonnull)api effect:(nonnull id<FxGripEffectHost>)effect;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

