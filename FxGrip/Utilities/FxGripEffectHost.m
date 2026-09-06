/*!
	@file       FxGripEffectHost.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripEffectHost
	@abstract   Implements the exported host-service resolvers for FxGripEffectHost.
	@discussion Introduced in FxGrip 0.1.0. The meta manager and parameter data resolve in two
	            steps: the host's own member when it answers, else a resolve notification whose
	            owning observer supplies the service. The resolvers use runtime dispatch so a
	            host that lacks the member incurs no link-time dependency.
*/

#import "FxGripEffectHost.h"
#import "FxGripTileableEffect+Notifications.h"
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
	return userInfo[FxGripTileableEffectResolvedObjectKey];
}

FxGripMetaManager * _Nullable FxGripHostMeta(id<FxGripEffectHost> _Nullable host)
{
	return FxGripHostResolveService(host, @selector(meta), FxGripTileableEffectResolveMetaName);
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
									FxGripTileableEffectResolveParameterDataName);
}
