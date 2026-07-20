//
//  MasterFxAPIAccess.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripAPIAccessing_h
#define FxGripAPIAccessing_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripDynamicParameterAPI_v4.h>
#import "FxParameterTagsAPI_v1.h"
#import "FxAPINotifications.h"


@class FxTileableEffectBase;


@protocol FxGripAPIAccessing <PROAPIAccessing>

- (id _Nullable)apiForProtocol:(Protocol * _Nonnull)apiProtocol bypass:(BOOL)bypassFxGripLayer;

	@property (assign, readonly) NSString* _Nullable pluginUUID;
	@property (assign, readonly) unsigned int pluginVersion;
	@property (assign, readonly) unsigned long long sessionID;


- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>_Nonnull)newApiManager
effect:(FxTileableEffectBase*_Nonnull)effect;

	@property (assign, readonly, nonnull) id<FxTileableEffectBase> effect;
	@property (assign, readonly) id<PROAPIAccessing> _Nonnull apiAccessing;

//- (FxGripAPITransaction* _Nonnull)transaction:(id _Nonnull)key;
//@property (assign, readonly) BOOL hasTransaction;
//- (BOOL)endTransaction:(FxGripAPITransaction* _Nonnull)transaction;

	@property (assign, readonly) id<FxParameterCreationAPI_v5> _Nullable paramCreateAPIv5_Raw;
	@property (assign, readonly) id<FxParameterCreationAPI_v5> _Nullable paramCreateAPIv5;
	@property (assign, readonly) id<FxParameterRetrievalAPI_v6> _Nullable paramGetAPIv6_Raw;
	@property (assign, readonly) id<FxParameterRetrievalAPI_v6> _Nullable paramGetAPIv6;
	@property (assign, readonly) id<FxParameterRetrievalAPI_v7> _Nullable paramGetAPIv7_Raw;
	@property (assign, readonly) id<FxParameterRetrievalAPI_v7> _Nullable paramGetAPIv7;
	@property (assign, readonly) id<FxParameterSettingAPI_v5> _Nullable paramSetAPIv5_Raw;
	@property (assign, readonly) id<FxParameterSettingAPI_v5> _Nullable paramSetAPIv5;
	@property (assign, readonly) id<FxParameterSettingAPI_v6> _Nullable paramSetAPIv6_Raw;
	@property (assign, readonly) id<FxParameterSettingAPI_v6> _Nullable paramSetAPIv6;
	@property (assign, readonly) id<FxDynamicParameterAPI_v3> _Nullable dynamicParamAPIv3_Raw;
	@property (assign, readonly) id<FxDynamicParameterAPI_v3> _Nullable dynamicParamAPIv3;

	@property (assign, readonly) id<FxCustomParameterActionAPI_v4> _Nullable customParameterActionAPIv4_Raw;
	@property (assign, readonly) id<FxCustomParameterActionAPI_v4> _Nullable customParameterActionAPIv4;

	@property (assign, readonly) id<FxOnScreenControlAPI> _Nullable onScreenControlAPIv1_Raw;
	@property (assign, readonly) id<FxOnScreenControlAPI> _Nullable onScreenControlAPIv1;
	@property (assign, readonly) id<FxOnScreenControlAPI_v2> _Nullable onScreenControlAPIv2_Raw;
	@property (assign, readonly) id<FxOnScreenControlAPI_v2> _Nullable onScreenControlAPIv2;
	@property (assign, readonly) id<FxOnScreenControlAPI_v3> _Nullable onScreenControlAPIv3_Raw;
	@property (assign, readonly) id<FxOnScreenControlAPI_v3> _Nullable onScreenControlAPIv3;
	@property (assign, readonly) id<FxOnScreenControlAPI_v4> _Nullable onScreenControlAPIv4_Raw;
	@property (assign, readonly) id<FxOnScreenControlAPI_v4> _Nullable onScreenControlAPIv4;

	@property (assign, readonly) id<FxPathAPI_v3> _Nullable pathAPIv3_Raw;
	@property (assign, readonly) id<FxPathAPI_v3> _Nullable pathAPIv3;
	@property (assign, readonly) id<FxUndoAPI> _Nullable undoAPIv1_Raw;
	@property (assign, readonly) id<FxUndoAPI> _Nullable undoAPIv1;
	@property (assign, readonly) id<FxCommandAPI> _Nullable commandAPIv1_Raw;
	@property (assign, readonly) id<FxCommandAPI> _Nullable commandAPIv1;
	@property (assign, readonly) id<FxCommandAPI_v2> _Nullable commandAPIv2_Raw;
	@property (assign, readonly) id<FxCommandAPI_v2> _Nullable commandAPIv2;
	@property (assign, readonly) id<FxRemoteWindowAPI> _Nullable remoteWindowAPIv1_Raw;
	@property (assign, readonly) id<FxRemoteWindowAPI> _Nullable remoteWindowAPIv1;
	@property (assign, readonly) id<FxRemoteWindowAPI_v2> _Nullable remoteWindowAPIv2_Raw;
	@property (assign, readonly) id<FxRemoteWindowAPI_v2> _Nullable remoteWindowAPIv2;

	@property (assign, readonly) id<Fx3DAPI_v5> _Nullable spaceAPIv5_Raw;
	@property (assign, readonly) id<Fx3DAPI_v5> _Nullable spaceAPIv5;
	@property (assign, readonly) id<FxLightingAPI_v3> _Nullable lightingAPIv3_Raw;
	@property (assign, readonly) id<FxLightingAPI_v3> _Nullable lightingAPIv3;

	@property (assign, readonly) id<FxColorGamutAPI_v2> _Nullable colorGamutAPIv2_Raw;
	@property (assign, readonly) id<FxColorGamutAPI_v2> _Nullable colorGamutAPIv2;

	@property (assign, readonly) id<FxTimingAPI_v4> _Nullable timingAPIv4_Raw;
	@property (assign, readonly) id<FxTimingAPI_v4> _Nullable timingAPIv4;
	@property (assign, readonly) id<FxKeyframeAPI_v3> _Nullable keyframeAPIv3_Raw;
	@property (assign, readonly) id<FxKeyframeAPI_v3> _Nullable keyframeAPIv3;
	@property (assign, readonly) id<FxAnalysisAPI> _Nullable analysisAPIv1_Raw;
	@property (assign, readonly) id<FxAnalysisAPI> _Nullable analysisAPIv1;
	@property (assign, readonly) id<FxAnalysisAPI_v2> _Nullable analysisAPIv2_Raw;
	@property (assign, readonly) id<FxAnalysisAPI_v2> _Nullable analysisAPIv2;

	@property (assign, readonly) id<FxProjectAPI> _Nullable projectAPIv1_Raw;
	@property (assign, readonly) id<FxProjectAPI> _Nullable projectAPIv1;
	@property (assign, readonly) id<FxProjectAPI_v2> _Nullable projectAPIv2_Raw;
	@property (assign, readonly) id<FxProjectAPI_v2> _Nullable projectAPIv2;

	@property (assign, readonly) id<FxVersioningAPI> _Nullable versioningAPIv1_Raw;
	@property (assign, readonly) id<FxVersioningAPI> _Nullable versioningAPIv1;


	//New Custom protocols that Apple might consider implementing.
	@property (assign, readonly) id<FxDynamicParameterAPI_v4> _Nullable dynamicParamAPIv4_Raw;
	@property (assign, readonly) id<FxDynamicParameterAPI_v4> _Nullable dynamicParamAPIv4;
	@property (assign, readonly) id<FxParameterTagsAPI_v1> _Nullable paramTagsAPIv1;


@end


/*
@class FxGripAPIAccessing;

@interface FxGripAPITransaction : NSObject <NSCopying>

- (nullable instancetype)initWithAPIManager:(FxGripAPIAccessing*_Nonnull)apiManager;

@property (strong, readonly) NSUUID* _Nonnull uuid;
@property (assign, readonly) FxGripAPIAccessing* _Nonnull apiManager;

@property (assign, readonly) BOOL  active;

- (void)commit;
- (void)commit:(BOOL)saveMeta;

@end
 
 example usage
{
	FxGripAPITransaction *tx = [_apiManager transaction:@(__func__)];
	#pragma unused(tx)
}
 */



/*!
	@interface  FxGripAPIAccessing:
	@abstract   This class serves as a layer on top of the FxPlug API for additional funcitonality.
	@discussion This class adds furher functionality to the FxPlug API.
 				It allows for metadata about the effect and each parameter to be kept and accessed.
 				The type of parameter can be queried, along with whether or not a parameter is in use.
 				When a parameter is Custom, the  FxGripInterpolatingDictionary can feed specified
 				data to the normal API calls.
 					eg the key "intValue" will feed the getIntValue:: api call on a custom parameter

 */
@interface FxGripAPIAccessing : NSObject <PROAPIAccessing, FxGripAPIAccessing>
//PROAPIAccessing Implementation
- (nullable id)apiForProtocol:(nonnull Protocol *)apiProtocol;

// FxGripAPIAccessing Implementation
- (id _Nullable)apiForProtocol:(Protocol * _Nonnull)apiProtocol bypass:(BOOL)bypassFxGripLayer;

	@property (assign, readonly) NSString* _Nullable pluginUUID;
	@property (assign, readonly) unsigned long long sessionID;


- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>_Nonnull)newApiManager
effect:(FxTileableEffectBase*_Nonnull)effect;

	@property (assign, readonly, nonnull) id<FxTileableEffectBase> effect;
	@property (assign, readonly) id<PROAPIAccessing> _Nonnull apiAccessing;

//- (FxGripAPITransaction* _Nonnull)transaction:(id _Nonnull)key;
//@property (assign, readonly) BOOL hasTransaction;
//- (BOOL)endTransaction:(FxGripAPITransaction* _Nonnull)transaction;

	@property (assign, readonly) id<FxParameterCreationAPI_v5> _Nullable paramCreateAPIv5_Raw;
	@property (assign, readonly) id<FxParameterCreationAPI_v5> _Nullable paramCreateAPIv5;
	@property (assign, readonly) id<FxParameterRetrievalAPI_v6> _Nullable paramGetAPIv6_Raw;
	@property (assign, readonly) id<FxParameterRetrievalAPI_v6> _Nullable paramGetAPIv6;
	@property (assign, readonly) id<FxParameterRetrievalAPI_v7> _Nullable paramGetAPIv7_Raw;
	@property (assign, readonly) id<FxParameterRetrievalAPI_v7> _Nullable paramGetAPIv7;
	@property (assign, readonly) id<FxParameterSettingAPI_v5> _Nullable paramSetAPIv5_Raw;
	@property (assign, readonly) id<FxParameterSettingAPI_v5> _Nullable paramSetAPIv5;
	@property (assign, readonly) id<FxParameterSettingAPI_v6> _Nullable paramSetAPIv6_Raw;
	@property (assign, readonly) id<FxParameterSettingAPI_v6> _Nullable paramSetAPIv6;
	@property (assign, readonly) id<FxDynamicParameterAPI_v3> _Nullable dynamicParamAPIv3_Raw;
	@property (assign, readonly) id<FxDynamicParameterAPI_v3> _Nullable dynamicParamAPIv3;

	@property (assign, readonly) id<FxCustomParameterActionAPI_v4> _Nullable customParameterActionAPIv4_Raw;
	@property (assign, readonly) id<FxCustomParameterActionAPI_v4> _Nullable customParameterActionAPIv4;

	@property (assign, readonly) id<FxOnScreenControlAPI> _Nullable onScreenControlAPIv1_Raw;
	@property (assign, readonly) id<FxOnScreenControlAPI> _Nullable onScreenControlAPIv1;
	@property (assign, readonly) id<FxOnScreenControlAPI_v2> _Nullable onScreenControlAPIv2_Raw;
	@property (assign, readonly) id<FxOnScreenControlAPI_v2> _Nullable onScreenControlAPIv2;
	@property (assign, readonly) id<FxOnScreenControlAPI_v3> _Nullable onScreenControlAPIv3_Raw;
	@property (assign, readonly) id<FxOnScreenControlAPI_v3> _Nullable onScreenControlAPIv3;
	@property (assign, readonly) id<FxOnScreenControlAPI_v4> _Nullable onScreenControlAPIv4_Raw;
	@property (assign, readonly) id<FxOnScreenControlAPI_v4> _Nullable onScreenControlAPIv4;

	@property (assign, readonly) id<FxPathAPI_v3> _Nullable pathAPIv3_Raw;
	@property (assign, readonly) id<FxPathAPI_v3> _Nullable pathAPIv3;
	@property (assign, readonly) id<FxUndoAPI> _Nullable undoAPIv1_Raw;
	@property (assign, readonly) id<FxUndoAPI> _Nullable undoAPIv1;
	@property (assign, readonly) id<FxCommandAPI> _Nullable commandAPIv1_Raw;
	@property (assign, readonly) id<FxCommandAPI> _Nullable commandAPIv1;
	@property (assign, readonly) id<FxCommandAPI_v2> _Nullable commandAPIv2_Raw;
	@property (assign, readonly) id<FxCommandAPI_v2> _Nullable commandAPIv2;
	@property (assign, readonly) id<FxRemoteWindowAPI> _Nullable remoteWindowAPIv1_Raw;
	@property (assign, readonly) id<FxRemoteWindowAPI> _Nullable remoteWindowAPIv1;
	@property (assign, readonly) id<FxRemoteWindowAPI_v2> _Nullable remoteWindowAPIv2_Raw;
	@property (assign, readonly) id<FxRemoteWindowAPI_v2> _Nullable remoteWindowAPIv2;

	@property (assign, readonly) id<Fx3DAPI_v5> _Nullable spaceAPIv5_Raw;
	@property (assign, readonly) id<Fx3DAPI_v5> _Nullable spaceAPIv5;
   	@property (assign, readonly) id<FxLightingAPI_v3> _Nullable lightingAPIv3_Raw;
	@property (assign, readonly) id<FxLightingAPI_v3> _Nullable lightingAPIv3;

	@property (assign, readonly) id<FxColorGamutAPI_v2> _Nullable colorGamutAPIv2_Raw;
	@property (assign, readonly) id<FxColorGamutAPI_v2> _Nullable colorGamutAPIv2;

	@property (assign, readonly) id<FxTimingAPI_v4> _Nullable timingAPIv4_Raw;
	@property (assign, readonly) id<FxTimingAPI_v4> _Nullable timingAPIv4;
	@property (assign, readonly) id<FxKeyframeAPI_v3> _Nullable keyframeAPIv3_Raw;
	@property (assign, readonly) id<FxKeyframeAPI_v3> _Nullable keyframeAPIv3;
	@property (assign, readonly) id<FxAnalysisAPI> _Nullable analysisAPIv1_Raw;
	@property (assign, readonly) id<FxAnalysisAPI> _Nullable analysisAPIv1;
	@property (assign, readonly) id<FxAnalysisAPI_v2> _Nullable analysisAPIv2_Raw;
	@property (assign, readonly) id<FxAnalysisAPI_v2> _Nullable analysisAPIv2;

   	@property (assign, readonly) id<FxProjectAPI> _Nullable projectAPIv1_Raw;
	@property (assign, readonly) id<FxProjectAPI> _Nullable projectAPIv1;
   	@property (assign, readonly) id<FxProjectAPI_v2> _Nullable projectAPIv2_Raw;
	@property (assign, readonly) id<FxProjectAPI_v2> _Nullable projectAPIv2;

	@property (assign, readonly) id<FxVersioningAPI> _Nullable versioningAPIv1_Raw;
	@property (assign, readonly) id<FxVersioningAPI> _Nullable versioningAPIv1;


	//New Custom protocols that Apple might consider implementing.
	@property (assign, readonly) id<FxDynamicParameterAPI_v4> _Nullable dynamicParamAPIv4_Raw;
	@property (assign, readonly) id<FxDynamicParameterAPI_v4> _Nullable dynamicParamAPIv4;
	@property (assign, readonly) id<FxParameterTagsAPI_v1> _Nullable paramTagsAPIv1;

@end


#endif /* FxGripAPIAccessing_h */
