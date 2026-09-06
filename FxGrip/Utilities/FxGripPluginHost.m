/*!
	@file       FxGripPluginHost.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPluginHost
	@abstract   Implements the standalone FxGripEffectHost for a plain FxPlug plug-in.
	@discussion Introduced in FxGrip 0.1.0. The host owns a wrapped API manager and reports no
	            effect base. The notifier is the default priority notification center.
*/

#import "FxGripPluginHost.h"
#import "FxGripAPIAccessing.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGrip_ARC.h"

/*!
	@abstract	A ready-made FxGripEffectHost for a plug-in that keeps its own effect base.
	@discussion	Introduced in FxGrip 0.1.0. The host wraps the plug-in's PROAPIAccessing and
				reports no effect base.
*/
@implementation FxGripPluginHost
{
	FxGripAPIAccessing *_apiManager;
}

/*! @abstract Wraps the plug-in's PROAPIAccessing, binding the wrapper to this host. */
- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	self = [super init];
	if (self != nil) {
		// The host stands in for an effect the wrapper never has; the OSC base binds the same way.
		_apiManager = [[FxGripAPIAccessing alloc] initWithAPIManager:apiManager effect:(id _Nonnull)self];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_apiManager);
	SUPER_DEALLOC();
}

- (id<FxGripAPIAccessing>)apiManager
{
	return _apiManager;
}

/*! @abstract The default priority notification center. */
- (NSPriorityNotificationCenter *)notifier
{
	return [NSPriorityNotificationCenter defaultCenter];
}

/*! @abstract Always nil; this host has no effect base. */
- (nullable FxGripTileableEffect *)effectBase
{
	return nil;
}

@end
