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
#import <FxGrip/FxGripParameterTagsAPI_v1.h>
#import <FxGrip/FxGripAPINotifications.h>


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

	/*! The registered UUID of the plug-in this manager serves; nil before registration resolves. */
	@property (copy, readonly) NSString* _Nullable pluginUUID;
	/*! The registered version of the plug-in this manager serves; 0 when the host does not report one. */
	@property (assign, readonly) unsigned int pluginVersion;
	/*! The identifier of this manager's session, which labels its log lines. */
	@property (assign, readonly) unsigned long long sessionID;


/*!
	@method		initWithAPIManager:effect:
	@abstract	Wraps a host API manager for a given effect.
	@param		newApiManager	The host's PROAPIAccessing manager.
	@param		effect			The effect the wrapped APIs act on.
*/
- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>_Nonnull)newApiManager
effect:(id<FxGripEffectHost>_Nonnull)effect;

	/*! The effect the wrapped APIs act on. */
	@property (weak, readonly, nullable) id<FxGripEffectHost> effect;
	/*! The host's own API manager, which every _Raw accessor resolves against. */
	@property (strong, readonly) id<PROAPIAccessing> _Nonnull apiAccessing;


	/*! The host's FxParameterCreationAPI_v5 with no FxGrip layer; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterCreationAPI_v5> _Nullable paramCreateAPIv5_Raw;
	/*! FxGrip's creation wrapper, which runs the extension pass over each parameter's properties and notifies FxGrip of every parameter added; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterCreationAPI_v5> _Nullable paramCreateAPIv5;
	/*! The host's FxParameterCreationAPI_v6 with no FxGrip layer; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterCreationAPI_v6> _Nullable paramCreateAPIv6_Raw;
	/*! FxGrip's creation wrapper, which runs the extension pass over each parameter's properties and notifies FxGrip of every parameter added; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterCreationAPI_v6> _Nullable paramCreateAPIv6;
	/*! The host's FxParameterRetrievalAPI_v6 with no FxGrip layer; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterRetrievalAPI_v6> _Nullable paramGetAPIv6_Raw;
	/*! FxGrip's retrieval wrapper, which routes custom parameters through FxGripMutableParameter and posts a read notification; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterRetrievalAPI_v6> _Nullable paramGetAPIv6;
	/*! The host's FxParameterRetrievalAPI_v7 with no FxGrip layer; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterRetrievalAPI_v7> _Nullable paramGetAPIv7_Raw;
	/*! FxGrip's retrieval wrapper, which routes custom parameters through FxGripMutableParameter and posts a read notification; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterRetrievalAPI_v7> _Nullable paramGetAPIv7;
	/*! The host's FxParameterSettingAPI_v5 with no FxGrip layer; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterSettingAPI_v5> _Nullable paramSetAPIv5_Raw;
	/*! FxGrip's setting wrapper, which routes custom parameters through FxGripMutableParameter and posts a write notification; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterSettingAPI_v5> _Nullable paramSetAPIv5;
	/*! The host's FxParameterSettingAPI_v6 with no FxGrip layer; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterSettingAPI_v6> _Nullable paramSetAPIv6_Raw;
	/*! FxGrip's setting wrapper, which routes custom parameters through FxGripMutableParameter and posts a write notification; nil when the host does not vend it. */
	@property (assign, readonly) id<FxParameterSettingAPI_v6> _Nullable paramSetAPIv6;
	/*! The host's FxDynamicParameterAPI_v3 with no FxGrip layer; nil when the host does not vend it. */
	@property (assign, readonly) id<FxDynamicParameterAPI_v3> _Nullable dynamicParamAPIv3_Raw;
	/*! FxGrip's dynamic-parameter wrapper, which notifies FxGrip of each parameter added, removed, or reflagged outside the addParameters pass; nil when the host does not vend it. */
	@property (assign, readonly) id<FxDynamicParameterAPI_v3> _Nullable dynamicParamAPIv3;

	/*! The host's FxCustomParameterActionAPI_v4 fetched with no FxGrip layer. FxGrip adds none, so it matches ``customParameterActionAPIv4``. */
	@property (assign, readonly) id<FxCustomParameterActionAPI_v4> _Nullable customParameterActionAPIv4_Raw;
	/*! The host API that brackets a custom parameter's value changes into one undoable action; nil when the host does not vend it. */
	@property (assign, readonly) id<FxCustomParameterActionAPI_v4> _Nullable customParameterActionAPIv4;

	/*! The host's FxOnScreenControlAPI fetched with no FxGrip layer. FxGrip adds none, so it matches ``onScreenControlAPIv1``. */
	@property (assign, readonly) id<FxOnScreenControlAPI> _Nullable onScreenControlAPIv1_Raw;
	/*! The host API that drives the plug-in's on-screen controls in the host's canvas; nil when the host does not vend it. */
	@property (assign, readonly) id<FxOnScreenControlAPI> _Nullable onScreenControlAPIv1;
	/*! The host's FxOnScreenControlAPI_v2 fetched with no FxGrip layer. FxGrip adds none, so it matches ``onScreenControlAPIv2``. */
	@property (assign, readonly) id<FxOnScreenControlAPI_v2> _Nullable onScreenControlAPIv2_Raw;
	/*! The host API that drives the plug-in's on-screen controls in the host's canvas; nil when the host does not vend it. */
	@property (assign, readonly) id<FxOnScreenControlAPI_v2> _Nullable onScreenControlAPIv2;
	/*! The host's FxOnScreenControlAPI_v3 fetched with no FxGrip layer. FxGrip adds none, so it matches ``onScreenControlAPIv3``. */
	@property (assign, readonly) id<FxOnScreenControlAPI_v3> _Nullable onScreenControlAPIv3_Raw;
	/*! The host API that drives the plug-in's on-screen controls in the host's canvas; nil when the host does not vend it. */
	@property (assign, readonly) id<FxOnScreenControlAPI_v3> _Nullable onScreenControlAPIv3;
	/*! The host's FxOnScreenControlAPI_v4 fetched with no FxGrip layer. FxGrip adds none, so it matches ``onScreenControlAPIv4``. */
	@property (assign, readonly) id<FxOnScreenControlAPI_v4> _Nullable onScreenControlAPIv4_Raw;
	/*! The host API that drives the plug-in's on-screen controls in the host's canvas; nil when the host does not vend it. */
	@property (assign, readonly) id<FxOnScreenControlAPI_v4> _Nullable onScreenControlAPIv4;

	/*! The host's FxPathAPI_v3 fetched with no FxGrip layer. FxGrip adds none, so it matches ``pathAPIv3``. */
	@property (assign, readonly) id<FxPathAPI_v3> _Nullable pathAPIv3_Raw;
	/*! The host API that reads the paths, shapes, and masks the user drew for the effect; nil when the host does not vend it. */
	@property (assign, readonly) id<FxPathAPI_v3> _Nullable pathAPIv3;
	/*! The host's FxUndoAPI fetched with no FxGrip layer. FxGrip adds none, so it matches ``undoAPIv1``. */
	@property (assign, readonly) id<FxUndoAPI> _Nullable undoAPIv1_Raw;
	/*! The host API that registers the plug-in's own undoable actions with the host; nil when the host does not vend it. */
	@property (assign, readonly) id<FxUndoAPI> _Nullable undoAPIv1;
	/*! The host's FxCommandAPI fetched with no FxGrip layer. FxGrip adds none, so it matches ``commandAPIv1``. */
	@property (assign, readonly) id<FxCommandAPI> _Nullable commandAPIv1_Raw;
	/*! The host API that asks the host to perform an editing command; nil when the host does not vend it. */
	@property (assign, readonly) id<FxCommandAPI> _Nullable commandAPIv1;
	/*! The host's FxCommandAPI_v2 fetched with no FxGrip layer. FxGrip adds none, so it matches ``commandAPIv2``. */
	@property (assign, readonly) id<FxCommandAPI_v2> _Nullable commandAPIv2_Raw;
	/*! The host API that asks the host to perform an editing command, and moves the playhead to a timeline time; nil when the host does not vend it. */
	@property (assign, readonly) id<FxCommandAPI_v2> _Nullable commandAPIv2;
	/*! The host's FxRemoteWindowAPI fetched with no FxGrip layer. FxGrip adds none, so it matches ``remoteWindowAPIv1``. */
	@property (assign, readonly) id<FxRemoteWindowAPI> _Nullable remoteWindowAPIv1_Raw;
	/*! The host API that opens and manages the plug-in's out-of-process window; nil when the host does not vend it. */
	@property (assign, readonly) id<FxRemoteWindowAPI> _Nullable remoteWindowAPIv1;
	/*! The host's FxRemoteWindowAPI_v2 fetched with no FxGrip layer. FxGrip adds none, so it matches ``remoteWindowAPIv2``. */
	@property (assign, readonly) id<FxRemoteWindowAPI_v2> _Nullable remoteWindowAPIv2_Raw;
	/*! The host API that opens and manages the plug-in's out-of-process window; nil when the host does not vend it. */
	@property (assign, readonly) id<FxRemoteWindowAPI_v2> _Nullable remoteWindowAPIv2;
	/*! The host's FxRemoteWindowAPI_v3 fetched with no FxGrip layer. FxGrip adds none, so it matches ``remoteWindowAPIv3``. */
	@property (assign, readonly) id<FxRemoteWindowAPI_v3> _Nullable remoteWindowAPIv3_Raw;
	/*! The host API that opens and manages the plug-in's out-of-process window; nil when the host does not vend it. */
	@property (assign, readonly) id<FxRemoteWindowAPI_v3> _Nullable remoteWindowAPIv3;

	/*! The host's Fx3DAPI_v5 fetched with no FxGrip layer. FxGrip adds none, so it matches ``spaceAPIv5``. */
	@property (assign, readonly) id<Fx3DAPI_v5> _Nullable spaceAPIv5_Raw;
	/*! The host API that reports the host's camera, its projection, and the layer's placement in the 3D scene; nil when the host does not vend it. */
	@property (assign, readonly) id<Fx3DAPI_v5> _Nullable spaceAPIv5;
	/*! The host's FxLightingAPI_v3 fetched with no FxGrip layer. FxGrip adds none, so it matches ``lightingAPIv3``. */
	@property (assign, readonly) id<FxLightingAPI_v3> _Nullable lightingAPIv3_Raw;
	/*! The host API that reports the lights in a Motion project's scene; nil when the host does not vend it. */
	@property (assign, readonly) id<FxLightingAPI_v3> _Nullable lightingAPIv3;

	/*! The host's FxColorGamutAPI_v2 fetched with no FxGrip layer. FxGrip adds none, so it matches ``colorGamutAPIv2``. */
	@property (assign, readonly) id<FxColorGamutAPI_v2> _Nullable colorGamutAPIv2_Raw;
	/*! The host API that reports the project's working color space and the matrices that convert between gamuts; nil when the host does not vend it. */
	@property (assign, readonly) id<FxColorGamutAPI_v2> _Nullable colorGamutAPIv2;

	/*! The host's FxTimingAPI_v4 with no FxGrip layer; nil when the host does not vend it. */
	@property (assign, readonly) id<FxTimingAPI_v4> _Nullable timingAPIv4_Raw;
	/*! FxGrip's timing wrapper, which guards each frame, sample, input, and timeline conversion; nil when the host does not vend it. */
	@property (assign, readonly) id<FxTimingAPI_v4> _Nullable timingAPIv4;
	/*! The host's FxTimingAPI_v5 fetched with no FxGrip layer. FxGrip adds none, so it matches ``timingAPIv5``. */
	@property (assign, readonly) id<FxTimingAPI_v5> _Nullable timingAPIv5_Raw;
	/*! The host API that adds the drop-frame queries to the timing API; nil on a host older than FxPlug 4.3.5. */
	@property (assign, readonly) id<FxTimingAPI_v5> _Nullable timingAPIv5;
	/*! The host's FxKeyframeAPI_v3 fetched with no FxGrip layer. FxGrip adds none, so it matches ``keyframeAPIv3``. */
	@property (assign, readonly) id<FxKeyframeAPI_v3> _Nullable keyframeAPIv3_Raw;
	/*! The host API that reads and writes a parameter's keyframes; nil when the host does not vend it. */
	@property (assign, readonly) id<FxKeyframeAPI_v3> _Nullable keyframeAPIv3;
	/*! The host's FxAnalysisAPI fetched with no FxGrip layer. FxGrip adds none, so it matches ``analysisAPIv1``. */
	@property (assign, readonly) id<FxAnalysisAPI> _Nullable analysisAPIv1_Raw;
	/*! The host API that asks the host to run a forward analysis pass over the clip; nil when the host does not vend it. */
	@property (assign, readonly) id<FxAnalysisAPI> _Nullable analysisAPIv1;
	/*! The host's FxAnalysisAPI_v2 fetched with no FxGrip layer. FxGrip adds none, so it matches ``analysisAPIv2``. */
	@property (assign, readonly) id<FxAnalysisAPI_v2> _Nullable analysisAPIv2_Raw;
	/*! The host API that asks the host to run an analysis pass over the clip, forward or backward; nil when the host does not vend it. */
	@property (assign, readonly) id<FxAnalysisAPI_v2> _Nullable analysisAPIv2;

	/*! The host's FxProjectAPI fetched with no FxGrip layer. FxGrip adds none, so it matches ``projectAPIv1``. */
	@property (assign, readonly) id<FxProjectAPI> _Nullable projectAPIv1_Raw;
	/*! The host API that reports the host project's dimensions, frame rate, and field order; nil when the host does not vend it. */
	@property (assign, readonly) id<FxProjectAPI> _Nullable projectAPIv1;
	/*! The host's FxProjectAPI_v2 fetched with no FxGrip layer. FxGrip adds none, so it matches ``projectAPIv2``. */
	@property (assign, readonly) id<FxProjectAPI_v2> _Nullable projectAPIv2_Raw;
	/*! The host API that reports the host project's properties, and adds the project's identifier; nil when the host does not vend it. */
	@property (assign, readonly) id<FxProjectAPI_v2> _Nullable projectAPIv2;

	/*! The host's FxVersioningAPI fetched with no FxGrip layer. FxGrip adds none, so it matches ``versioningAPIv1``. */
	@property (assign, readonly) id<FxVersioningAPI> _Nullable versioningAPIv1_Raw;
	/*! The host API that reports the plug-in version an instance was created with; nil when the host does not vend it. */
	@property (assign, readonly) id<FxVersioningAPI> _Nullable versioningAPIv1;


	// FxGrip's own APIs, in the style of Apple's FxPlug APIs.
	/*! Reports a parameter's type, its flags, and whether it is in use, from FxGrip's own records rather than the host's. */
	@property (assign, readonly) id<FxGripParameterInfoAPI_v1> _Nullable parameterInfoAPIv1;
	/*! Reads and writes a parameter's minimum, maximum, and slider bounds through one interface, whatever the parameter's numeric type. */
	@property (assign, readonly) id<FxGripParameterBoundsAPI_v1> _Nullable parameterBoundsAPIv1;
	/*! Reads and writes the per-parameter and per-instance meta FxGrip stores in the host document. */
	@property (assign, readonly) id<FxGripMetaAPI_v1> _Nullable metaAPIv1;
	/*! Stores parameter tags and resolves a preset against them. FxGrip-implemented, so it is available whatever the host vends. */
	@property (assign, readonly) id<FxGripParameterTagsAPI_v1> _Nullable paramTagsAPIv1;
	/*! Captures, applies, browses, and files presets. FxGrip-implemented, so it is available whatever the host vends. */
	@property (assign, readonly) id<FxGripPresetsAPI_v1> _Nullable presetsAPIv1;

	/*! Creates FxGrip's custom parameters (status, banner, web view, …) in Apple's creation-API
		style; nil when the manager has no effect host. FxGrip-implemented. */
	@property (assign, readonly) id<FxGripCustomCreationAPI_v1> _Nullable customCreationAPIv1;


@end


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

/*!
	@method		apiForProtocol:
	@abstract	Returns the API for a protocol, wrapped by FxGrip when FxGrip wraps it.
	@discussion	The PROAPIAccessing entry point the host calls. It resolves through
				apiForProtocol:bypass: with the wrapper layer in place.
	@param		apiProtocol		The FxPlug or FxGrip API protocol to resolve.
	@return		The API object, or nil when the host does not provide it.
*/
- (nullable id)apiForProtocol:(nonnull Protocol *)apiProtocol;

/*!
	@method		apiForProtocol:bypass:
	@abstract	Returns the API for a protocol, optionally skipping the FxGrip wrapper layer.
	@param		apiProtocol			The FxPlug or FxGrip API protocol to resolve.
	@param		bypassFxGripLayer	YES returns the raw host object; NO returns FxGrip's wrapper when one exists.
	@return		The API object, or nil when the host does not provide it.
*/
- (id _Nullable)apiForProtocol:(Protocol * _Nonnull)apiProtocol bypass:(BOOL)bypassFxGripLayer;

	/*! The registered UUID of the plug-in this manager serves; nil before registration resolves. */
	@property (copy, readonly) NSString* _Nullable pluginUUID;
	/*! The registered version of the plug-in this manager serves; 0 when the host does not report one. */
	@property (assign, readonly) unsigned int pluginVersion;
	/*! The identifier of this manager's session, which labels its log lines. */
	@property (assign, readonly) unsigned long long sessionID;


/*!
	@method		initWithAPIManager:effect:
	@abstract	Wraps a host API manager for a given effect.
	@param		newApiManager	The host's PROAPIAccessing manager.
	@param		effect			The effect the wrapped APIs act on.
	@return		The wrapping manager, or nil when the host manager is unusable.
*/
- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>_Nonnull)newApiManager
effect:(id<FxGripEffectHost>_Nonnull)effect;

	/*! The effect the wrapped APIs act on. */
	@property (weak, readonly, nullable) id<FxGripEffectHost> effect;
	/*! The host's own API manager, which every _Raw accessor resolves against. */
	@property (strong, readonly) id<PROAPIAccessing> _Nonnull apiAccessing;


	// FxGrip's own APIs, in the style of Apple's FxPlug APIs.

	/*! Creates FxGrip's custom parameters (status, banner, web view, …) in Apple's creation-API
		style; nil when the manager has no effect host. FxGrip-implemented. */

@end


#endif /* FxGripAPIAccessing_h */
