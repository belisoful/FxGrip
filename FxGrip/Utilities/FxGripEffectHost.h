//
//  FxGripEffectHost.h
//  FxGrip
//

#ifndef FxGripEffectHost_h
#define FxGripEffectHost_h

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@protocol FxGripAPIAccessing;
@protocol FxParameter;
@class NSPriorityNotificationCenter;
@class FxGripMetaManager;
@class FxGripParameterData;
@class FxGripOOBParameterAccess;
@class FxGripTileableEffect;

NS_ASSUME_NONNULL_BEGIN

/*!
	@protocol   FxGripEffectHost
	@abstract   The narrow contract FxGrip's parameter subsystem requires of its owner.
	@discussion Introduced in FxGrip 1.0. The parameter classes, the custom controls, and the
				out-of-band access context reach their owner only through this protocol: the
				wrapped API manager and the notification center. FxGripTileableEffect conforms, so
				a subclassed effect passes itself. An existing FxPlug plug-in that does not use the
				effect base conforms directly, or uses FxGripPluginHost, and gains plist parameter
				registration and the custom controls without adopting the rest of FxGrip.

				The optional members serve individual parameter classes: the color and RGB
				parameters read the gamut flags, the font menu reads the default font name, and the
				presets parameter reads the meta and parameter-data extensions. A host without one
				of these gets the parameter's neutral behavior.
*/
@protocol FxGripEffectHost <NSObject>

@required

/*! The FxGrip-wrapped API manager the parameter classes create and access parameters through. */
@property (readonly, nonnull) id<FxGripAPIAccessing> apiManager;

/*! The notification center the parameter subsystem observes and posts through. */
@property (readonly, nonnull, assign) NSPriorityNotificationCenter *notifier;

/*!
	@abstract   The full effect base behind this host, or nil when there is none.
	@discussion FxGripTileableEffect returns itself; FxGripPluginHost and a plug-in's own host
				return nil. Code that needs the full base reads it through here and degrades on
				nil, which Objective-C nil messaging makes safe: `host.effectBase.pluginProperties`
				is nil without a base. The subsystems never cast a host to the base class.
*/
@property (readonly, nullable, nonatomic) FxGripTileableEffect *effectBase;

@optional

/*! The plug-in's registration dictionary, for hosts that can answer it directly. The plug-in's
	UUID is not a host member: the API manager carries it. */
@property (readonly, nonnull, retain) NSDictionary<NSString *, id> *pluginProperties;

/*! The plist configuration of a registered parameter, for hosts that carry one. */
- (NSDictionary * _Nullable)configurationForParameter:(UInt32)parameterID;

/*! The registered parameter for an ID, for group walks and companion checks; a minimal host has
	none and skips those checks. */
- (id<FxParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;

@end

#pragma mark Host attribute access

/*!
	The read pattern for the host's richer attributes: the host's own member when it answers,
	else through its effect base, else nil. The parameter subsystem and the API wrappers read
	through these, so a plain host supplies exactly the attributes it has and inherits safe
	nil behavior for the rest.
*/

/*! The slice of the API manager the identity helper reads; FxGripAPIAccessing answers it. */
@protocol FxGripHostIdentity <NSObject>
@property (assign, readonly, nullable) NSString *pluginUUID;
@end

NS_INLINE NSString * _Nullable FxGripHostPluginUUID(id<FxGripEffectHost> _Nullable host)
{
	// The API manager is the identity's single source; every host carries one.
	id<FxGripHostIdentity> manager = (id<FxGripHostIdentity>)host.apiManager;
	return [manager respondsToSelector:@selector(pluginUUID)] ? manager.pluginUUID : nil;
}

NS_INLINE NSDictionary<NSString *, id> * _Nullable FxGripHostPluginProperties(id<FxGripEffectHost> _Nullable host)
{
	if ([host respondsToSelector:@selector(pluginProperties)]) {
		return host.pluginProperties;
	}
	id<FxGripEffectHost> base = (id<FxGripEffectHost>)host.effectBase;
	return [base respondsToSelector:@selector(pluginProperties)] ? base.pluginProperties : nil;
}

NS_INLINE NSDictionary * _Nullable FxGripHostConfigurationForParameter(id<FxGripEffectHost> _Nullable host,
																	   UInt32 parameterID)
{
	if ([host respondsToSelector:@selector(configurationForParameter:)]) {
		return [host configurationForParameter:parameterID];
	}
	id<FxGripEffectHost> base = (id<FxGripEffectHost>)host.effectBase;
	return [base respondsToSelector:@selector(configurationForParameter:)]
		? [base configurationForParameter:parameterID] : nil;
}

/*!
	The meta manager and parameter data are services, resolved in two steps: the host's own
	member when it answers, else a resolve notification on the host's notifier, which whichever
	observer owns the service answers. The API wrappers cache the resolution per vended instance.
*/
FOUNDATION_EXPORT FxGripMetaManager * _Nullable FxGripHostMeta(id<FxGripEffectHost> _Nullable host);
FOUNDATION_EXPORT BOOL FxGripHostHasMeta(id<FxGripEffectHost> _Nullable host);
FOUNDATION_EXPORT FxGripParameterData * _Nullable FxGripHostParameterData(id<FxGripEffectHost> _Nullable host);

NS_ASSUME_NONNULL_END

#endif /* FxGripEffectHost_h */
