//
//  FxGripEffectHost.m
//  FxGrip
//

#import "FxGripEffectHost.h"
#import "FxTileableEffectBase+Notifications.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGrip_ARC.h"

/*! The two-step service resolution: the host's own member, else a resolve notification. */
static id _Nullable FxGripHostResolveService(id<FxGripEffectHost> _Nullable host,
											 SEL member,
											 NSNotificationName name)
{
	if (host == nil) {
		return nil;
	}
	if ([host respondsToSelector:member]) {
		IMP imp = [(NSObject *)host methodForSelector:member];
		id (*getter)(id, SEL) = (id (*)(id, SEL))imp;
		return getter(host, member);
	}
	NSMutableDictionary *userInfo = @{}.mutableCopy;
	[host.notifier postNotificationName:name object:host userInfo:userInfo];
	return userInfo[FxTileableEffectResolvedObjectKey];
}

FxGripMetaManager * _Nullable FxGripHostMeta(id<FxGripEffectHost> _Nullable host)
{
	return FxGripHostResolveService(host, @selector(meta), FxTileableEffectResolveMetaName);
}

BOOL FxGripHostHasMeta(id<FxGripEffectHost> _Nullable host)
{
	if ([host respondsToSelector:@selector(hasMeta)]) {
		BOOL (*getter)(id, SEL) = (BOOL (*)(id, SEL))[(NSObject *)host methodForSelector:@selector(hasMeta)];
		return getter(host, @selector(hasMeta));
	}
	return FxGripHostMeta(host) != nil;
}

FxGripParameterData * _Nullable FxGripHostParameterData(id<FxGripEffectHost> _Nullable host)
{
	return FxGripHostResolveService(host, @selector(parameterData),
									FxTileableEffectResolveParameterDataName);
}
