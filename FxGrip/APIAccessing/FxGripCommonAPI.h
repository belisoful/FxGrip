/*!
	@file       FxGripCommonAPI.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCommonAPI
	@abstract   The base class for FxGrip's API capture-layer wrappers.
	@discussion Introduced in FxGrip 0.1.0. FxGripCommonAPI holds the effect that instanced the API
	            wrapper. It resolves the host's meta manager and parameter data once per wrapper and
	            caches them, so a per-call meta bridge does not repeat the resolve notification on a
	            plain host. The versioned FxGrip API wrappers subclass it.
*/

#ifndef FxGripCommonAPI_h
#define FxGripCommonAPI_h

#import <FxPlug/FxPlugSDK.h>

#import <FxGrip/FxGripEffectHost.h>

@protocol FxGripParameterInfoAPI_v1;

/*!
	@class		FxGripCommonAPI
	@abstract	The base object for FxGrip's API capture layer.
	@discussion	Introduced in FxGrip 0.1.0. Holds the effect that instanced the API and lazily
				resolves the host's meta manager and parameter data.
*/
@interface FxGripCommonAPI : NSObject

	/*! The effect that instanced this API wrapper, held weakly. The effect's API manager caches
		some wrappers, so a strong reference would keep the effect alive. */
	@property (weak, readonly, nullable) id<FxGripEffectHost> effect;

/*! @abstract Creates the wrapper bound to an effect. */
- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect;

/*! The host's meta manager, resolved once per vended wrapper and cached, so the per-call meta
	bridge does not repeat the resolve notification on a plain host. */
- (nullable FxGripMetaManager *)hostMeta;

/*! YES when hostMeta resolves. */
- (BOOL)hostHasMeta;

/*! The host's parameter data, resolved once per vended wrapper and cached. */
- (nullable FxGripParameterData *)hostParameterData;

/*!
	@method		isCustomParameter:infoAPI:
	@abstract	YES when a parameter's type is FxParameterType_Custom.
	@param		parameterID	The parameter to test.
	@param		infoAPI		The info API that answers when the effect has no record, or nil.
	@return		YES for a custom parameter.
	@discussion	Introduced in FxGrip 0.1.0. The registered type from FxGripHostParameterType
				decides without a notification. When the effect has no record of the parameter,
				the info API's parameterType: answers through the get-type notification. The value
				wrappers call this on every read and write to route a custom value's accessors.
*/
- (BOOL)isCustomParameter:(FxParameterId)parameterID infoAPI:(nullable id<FxGripParameterInfoAPI_v1>)infoAPI;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

