//
//  FxGripMetaAPI_v1.h
//  FxGrip
//

#ifndef FxGripMetaAPI_v1_h
#define FxGripMetaAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import "FxGripCommonAPI.h"

/*!
	@protocol   FxGripMetaAPI_v1
	@abstract   Per-parameter metadata storage, in the style of Apple's FxPlug APIs.
	@discussion Introduced in FxGrip 1.0. FxGrip's own API; no host vends it. Metadata is
				arbitrary secure-codable data attached to a parameter and persisted with the
				effect's plugin state. Every method resolves through the host's meta manager;
				a host without one answers the not-found result.
*/
@protocol FxGripMetaAPI_v1 <NSObject>

- (SInt32)metaCountFromParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)getMeta:(NSDictionary* _Nullable * _Nonnull)meta fromParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)setMeta:(NSDictionary* _Nonnull)meta toParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)getMetaKeys:(NSArray* _Nullable * _Nonnull)keys fromParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)removeAllMeta:(FxParameterId)parameterID;

- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString* _Nonnull)key error:(NSError* _Nullable * _Nullable)error;
- (BOOL)getMeta:(id<NSSecureCoding, NSCopying> _Nullable * _Nullable)value forKey:(NSString* _Nonnull)key fromParameter:(FxParameterId)parameterID;
- (BOOL)setMeta:(id<NSSecureCoding, NSCopying> _Nonnull)value forKey:(NSString* _Nonnull)key toParameter:(FxParameterId)parameterID;
- (BOOL)removeMetaKey:(NSString* _Nonnull)key fromParameter:(FxParameterId)parameterID;

@end


/*!
	@interface  FxGripMetaAPI_v1
	@abstract   FxGrip's implementation of FxGripMetaAPI_v1.
	@discussion Introduced in FxGrip 1.0. Forwards every call to the host's meta manager
				(hostMeta). Vended by FxGripAPIAccessing's metaAPIv1. Previously these methods
				lived on the fabricated FxGripDynamicParameterAPI_v4; they are their own API now so
				FxGrip does not extend Apple's dynamic-parameter protocol with its own methods.
*/
@interface FxGripMetaAPI_v1 : FxGripCommonAPI <FxGripMetaAPI_v1>

- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif /* FxGripMetaAPI_v1_h */
