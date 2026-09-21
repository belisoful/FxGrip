/*!
	@file       FxGripMetaAPI_v1.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMetaAPI_v1
	@abstract   Per-parameter metadata storage, in the style of Apple's FxPlug APIs.
	@discussion Introduced in FxGrip 0.1.0. The API is FxGrip's own; no host vends it. Metadata is
	            secure-codable data attached to a parameter and persisted with the effect's plugin
	            state. Every method resolves through the host's meta manager, and a host without one
	            answers the not-found result.
*/

#ifndef FxGripMetaAPI_v1_h
#define FxGripMetaAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripCommonAPI.h>

/*!
	@protocol   FxGripMetaAPI_v1
	@abstract   Per-parameter metadata storage, in the style of Apple's FxPlug APIs.
	@discussion Introduced in FxGrip 0.1.0. FxGrip's own API; no host vends it. Metadata is
				arbitrary secure-codable data attached to a parameter and persisted with the
				effect's plugin state. Every method resolves through the host's meta manager;
				a host without one answers the not-found result.
*/
@protocol FxGripMetaAPI_v1 <NSObject>

/*! The number of meta entries a parameter carries; -1 when the effect has no meta manager. */
- (SInt32)metaCountFromParameter:(FxParameterId)parameterID;
/*! Reads a parameter's whole meta dictionary. Answers the error that stopped the read, or nil. */
- (NSError* _Nullable)getMeta:(NSDictionary* _Nullable * _Nonnull)meta fromParameter:(FxParameterId)parameterID;
/*! Replaces a parameter's whole meta dictionary. Answers the error that stopped the write, or nil. */
- (NSError* _Nullable)setMeta:(NSDictionary* _Nonnull)meta toParameter:(FxParameterId)parameterID;
/*! Reads the keys a parameter's meta carries. Answers the error that stopped the read, or nil. */
- (NSError* _Nullable)getMetaKeys:(NSArray* _Nullable * _Nonnull)keys fromParameter:(FxParameterId)parameterID;
/*! Removes every meta entry from a parameter. Answers the error that stopped the write, or nil. */
- (NSError* _Nullable)removeAllMeta:(FxParameterId)parameterID;

/*! Answers whether a parameter's meta carries a key, reporting through error why a read failed. */
- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString* _Nonnull)key error:(NSError* _Nullable * _Nullable)error;
/*! Reads one meta value from a parameter. Answers YES when the key was present. */
- (BOOL)getMeta:(id<NSSecureCoding, NSCopying> _Nullable * _Nullable)value forKey:(NSString* _Nonnull)key fromParameter:(FxParameterId)parameterID;
/*! Writes one meta value to a parameter. The value must support secure coding and copying. */
- (BOOL)setMeta:(id<NSSecureCoding, NSCopying> _Nonnull)value forKey:(NSString* _Nonnull)key toParameter:(FxParameterId)parameterID;
/*! Removes one meta entry from a parameter. Answers YES when the key was present. */
- (BOOL)removeMetaKey:(NSString* _Nonnull)key fromParameter:(FxParameterId)parameterID;

@end


/*!
	@interface  FxGripMetaAPI_v1
	@abstract   FxGrip's implementation of FxGripMetaAPI_v1.
	@discussion Introduced in FxGrip 0.1.0. Forwards every call to the host's meta manager
				(hostMeta). Vended by FxGripAPIAccessing's metaAPIv1. Previously these methods
				lived on the fabricated FxGripDynamicParameterAPI_v4; they are their own API now so
				FxGrip does not extend Apple's dynamic-parameter protocol with its own methods.
*/
@interface FxGripMetaAPI_v1 : FxGripCommonAPI <FxGripMetaAPI_v1>

/*!
	@method		initWithEffect:
	@abstract	Creates the meta API over an effect host's meta manager.
	@param		effect	The effect host whose meta manager stores the metadata.
	@return		The meta API, or nil when it cannot be built.
*/
- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif /* FxGripMetaAPI_v1_h */
