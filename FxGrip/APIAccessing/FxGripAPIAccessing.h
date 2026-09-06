/*!
	@file       FxGripAPIAccessing.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripAPIAccessing
	@abstract   The layer over the FxPlug host API that vends FxGrip's wrappers alongside Apple's APIs.
	@discussion Introduced in FxGrip 0.1.0. FxGripAPIAccessing wraps the host's PROAPIAccessing
	            manager. apiForProtocol: returns FxGrip's wrapper for a protocol that FxGrip
	            augments, and the host object for every other protocol. Convenience accessors vend
	            each versioned FxPlug API by name. Each has a parallel _Raw accessor that returns
	            the unwrapped host object. FxGrip's own APIs, such as the parameter tags and presets
	            APIs, resolve through the same path.
*/

#ifndef FxGripAPIAccessing_h
#define FxGripAPIAccessing_h

#import <FxPlug/FxPlugSDK.h>

@class FxGripCustomCreationAPI_v1;
@protocol FxGripCustomCreationAPI_v1, FxGripPresetsAPI_v1;
#import <FxGrip/FxGripParameterInfoAPI_v1.h>
#import <FxGrip/FxGripParameterBoundsAPI_v1.h>
#import <FxGrip/FxGripMetaAPI_v1.h>
#import "FxGripParameterTagsAPI_v1.h"
#import "FxGripAPINotifications.h"


@class FxGripTileableEffect;
@class FxGripPresetsAPI_v1;


/*!
	@protocol	FxGripAPIAccessing
	@abstract	The interface a wrapped API manager exposes to FxGrip effects.
	@discussion	Introduced in FxGrip 0.1.0. The protocol extends PROAPIAccessing with an
				apiForProtocol:bypass: entry point and typed accessors for each FxPlug and FxGrip
				API. Each API has two accessors: the plain accessor vends FxGrip's wrapper when one
				exists, and the _Raw accessor vends the host object with no FxGrip layer. An
				accessor answers nil when the host does not provide the API.
*/
@protocol FxGripAPIAccessing <PROAPIAccessing>

/*!
	@method		apiForProtocol:bypass:
	@abstract	Returns the API for a protocol, optionally skipping the FxGrip wrapper layer.
	@param		apiProtocol			The FxPlug or FxGrip API protocol to resolve.
	@param		bypassFxGripLayer	YES returns the raw host object; NO returns FxGrip's wrapper when one exists.
	@return		The API object, or nil when the host does not provide it.
*/
- (id _Nullable)apiForProtocol:(Protocol * _Nonnull)apiProtocol bypass:(BOOL)bypassFxGripLayer;

	@property (assign, readonly) NSString* _Nullable pluginUUID;
	@property (assign, readonly) unsigned int pluginVersion;
	@property (assign, readonly) unsigned long long sessionID;


/*!
	@method		initWithAPIManager:effect:
	@abstract	Wraps a host API manager for a given effect.
	@param		newApiManager	The host's PROAPIAccessing manager.
	@param		effect			The effect the wrapped APIs act on.
*/
- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>_Nonnull)newApiManager
effect:(id<FxGripEffectHost>_Nonnull)effect;

	@property (assign, readonly, nonnull) id<FxGripEffectHost> effect;
	@property (assign, readonly) id<PROAPIAccessing> _Nonnull apiAccessing;

//- (FxGripAPITransaction* _Nonnull)transaction:(id _Nonnull)key;
//@property (assign, readonly) BOOL hasTransaction;
//- (BOOL)endTransaction:(FxGripAPITransaction* _Nonnull)transaction;

	@property (assign, readonly) id<FxParameterCreationAPI_v5> _Nullable paramCreateAPIv5_Raw;
	@property (assign, readonly) id<FxParameterCreationAPI_v5> _Nullable paramCreateAPIv5;
	@property (assign, readonly) id<FxParameterCreationAPI_v6> _Nullable paramCreateAPIv6_Raw;
	@property (assign, readonly) id<FxParameterCreationAPI_v6> _Nullable paramCreateAPIv6;
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
	@property (assign, readonly) id<FxRemoteWindowAPI_v3> _Nullable remoteWindowAPIv3_Raw;
	@property (assign, readonly) id<FxRemoteWindowAPI_v3> _Nullable remoteWindowAPIv3;

	@property (assign, readonly) id<Fx3DAPI_v5> _Nullable spaceAPIv5_Raw;
	@property (assign, readonly) id<Fx3DAPI_v5> _Nullable spaceAPIv5;
	@property (assign, readonly) id<FxLightingAPI_v3> _Nullable lightingAPIv3_Raw;
	@property (assign, readonly) id<FxLightingAPI_v3> _Nullable lightingAPIv3;

	@property (assign, readonly) id<FxColorGamutAPI_v2> _Nullable colorGamutAPIv2_Raw;
	@property (assign, readonly) id<FxColorGamutAPI_v2> _Nullable colorGamutAPIv2;

	@property (assign, readonly) id<FxTimingAPI_v4> _Nullable timingAPIv4_Raw;
	@property (assign, readonly) id<FxTimingAPI_v4> _Nullable timingAPIv4;
	/*! The FxPlug 4.3.5 timing API with the drop-frame queries; nil on older hosts. */
	@property (assign, readonly) id<FxTimingAPI_v5> _Nullable timingAPIv5_Raw;
	@property (assign, readonly) id<FxTimingAPI_v5> _Nullable timingAPIv5;
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


	// FxGrip's own APIs, in the style of Apple's FxPlug APIs.
	@property (assign, readonly) id<FxGripParameterInfoAPI_v1> _Nullable parameterInfoAPIv1;
	@property (assign, readonly) id<FxGripParameterBoundsAPI_v1> _Nullable parameterBoundsAPIv1;
	@property (assign, readonly) id<FxGripMetaAPI_v1> _Nullable metaAPIv1;
	@property (assign, readonly) id<FxGripParameterTagsAPI_v1> _Nullable paramTagsAPIv1;
	@property (assign, readonly) id<FxGripPresetsAPI_v1> _Nullable presetsAPIv1;

	/*! Creates FxGrip's custom parameters (status, banner, web view, …) in Apple's creation-API
		style; nil when the manager has no effect host. FxGrip-implemented. */
	@property (assign, readonly) id<FxGripCustomCreationAPI_v1> _Nullable customCreationAPIv1;


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
	@class		FxGripAPIAccessing
	@abstract	The layer over the FxPlug API that adds FxGrip functionality.
	@discussion	Introduced in FxGrip 0.1.0. The class keeps and vends metadata about the effect and
				each parameter. A parameter's type can be queried, along with whether the parameter
				is in use. When a parameter is custom, the FxGripInterpolatingDictionary feeds
				specified data to the standard API calls; for example the key "intValue" feeds the
				getIntValue:: call on a custom parameter.
*/
@interface FxGripAPIAccessing : NSObject <PROAPIAccessing, FxGripAPIAccessing>
//PROAPIAccessing Implementation
- (nullable id)apiForProtocol:(nonnull Protocol *)apiProtocol;

// FxGripAPIAccessing Implementation
- (id _Nullable)apiForProtocol:(Protocol * _Nonnull)apiProtocol bypass:(BOOL)bypassFxGripLayer;

	@property (assign, readonly) NSString* _Nullable pluginUUID;
	@property (assign, readonly) unsigned long long sessionID;


- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>_Nonnull)newApiManager
effect:(id<FxGripEffectHost>_Nonnull)effect;

	@property (assign, readonly, nonnull) id<FxGripEffectHost> effect;
	@property (assign, readonly) id<PROAPIAccessing> _Nonnull apiAccessing;

//- (FxGripAPITransaction* _Nonnull)transaction:(id _Nonnull)key;
//@property (assign, readonly) BOOL hasTransaction;
//- (BOOL)endTransaction:(FxGripAPITransaction* _Nonnull)transaction;

	@property (assign, readonly) id<FxParameterCreationAPI_v5> _Nullable paramCreateAPIv5_Raw;
	@property (assign, readonly) id<FxParameterCreationAPI_v5> _Nullable paramCreateAPIv5;
	@property (assign, readonly) id<FxParameterCreationAPI_v6> _Nullable paramCreateAPIv6_Raw;
	@property (assign, readonly) id<FxParameterCreationAPI_v6> _Nullable paramCreateAPIv6;
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
	@property (assign, readonly) id<FxRemoteWindowAPI_v3> _Nullable remoteWindowAPIv3_Raw;
	@property (assign, readonly) id<FxRemoteWindowAPI_v3> _Nullable remoteWindowAPIv3;

	@property (assign, readonly) id<Fx3DAPI_v5> _Nullable spaceAPIv5_Raw;
	@property (assign, readonly) id<Fx3DAPI_v5> _Nullable spaceAPIv5;
   	@property (assign, readonly) id<FxLightingAPI_v3> _Nullable lightingAPIv3_Raw;
	@property (assign, readonly) id<FxLightingAPI_v3> _Nullable lightingAPIv3;

	@property (assign, readonly) id<FxColorGamutAPI_v2> _Nullable colorGamutAPIv2_Raw;
	@property (assign, readonly) id<FxColorGamutAPI_v2> _Nullable colorGamutAPIv2;

	@property (assign, readonly) id<FxTimingAPI_v4> _Nullable timingAPIv4_Raw;
	@property (assign, readonly) id<FxTimingAPI_v4> _Nullable timingAPIv4;
	/*! The FxPlug 4.3.5 timing API with the drop-frame queries; nil on older hosts. */
	@property (assign, readonly) id<FxTimingAPI_v5> _Nullable timingAPIv5_Raw;
	@property (assign, readonly) id<FxTimingAPI_v5> _Nullable timingAPIv5;
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


	// FxGrip's own APIs, in the style of Apple's FxPlug APIs.
	@property (assign, readonly) id<FxGripParameterInfoAPI_v1> _Nullable parameterInfoAPIv1;
	@property (assign, readonly) id<FxGripParameterBoundsAPI_v1> _Nullable parameterBoundsAPIv1;
	@property (assign, readonly) id<FxGripMetaAPI_v1> _Nullable metaAPIv1;
	@property (assign, readonly) id<FxGripParameterTagsAPI_v1> _Nullable paramTagsAPIv1;
	@property (assign, readonly) id<FxGripPresetsAPI_v1> _Nullable presetsAPIv1;

	/*! Creates FxGrip's custom parameters (status, banner, web view, …) in Apple's creation-API
		style; nil when the manager has no effect host. FxGrip-implemented. */
	@property (assign, readonly) id<FxGripCustomCreationAPI_v1> _Nullable customCreationAPIv1;

@end


#endif /* FxGripAPIAccessing_h */
