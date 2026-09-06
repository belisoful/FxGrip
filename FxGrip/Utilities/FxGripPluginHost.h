/*!
	@file       FxGripPluginHost.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPluginHost
	@abstract   A ready-made FxGripEffectHost for a plug-in that keeps its own effect base.
	@discussion Introduced in FxGrip 0.1.0. The host wraps the plug-in's PROAPIAccessing in an
	            FxGripAPIAccessing and supplies a notification center. That satisfies the
	            parameter subsystem's contract, so the plug-in registers plist parameters, hosts
	            the custom controls, and uses the tags and presets API wrappers while keeping its
	            own FxTileableEffect. This is the smallest FxGrip adoption step.
*/

#ifndef FxGripPluginHost_h
#define FxGripPluginHost_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripEffectHost.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripPluginHost
	@abstract   A ready-made FxGripEffectHost for an FxPlug plug-in that does not use the effect base.
	@discussion Introduced in FxGrip 0.1.0. An existing plug-in owns one of these alongside its own
				implementation: the host wraps the plug-in's PROAPIAccessing in an
				FxGripAPIAccessing and supplies a private notification center. That satisfies the
				parameter subsystem's contract, so the plug-in registers parameters from plist
				dictionaries, hosts the custom controls, and uses the tags and presets API wrappers,
				while keeping its own FxTileableEffect implementation.

				This is the smallest adoption step. The next steps up are composing an
				FxGripTileableEffect inside the plug-in, and subclassing it. See the Adoption
				article.
*/
@interface FxGripPluginHost : NSObject <FxGripEffectHost>

/*!
	@method		initWithAPIManager:
	@abstract	Creates a host that wraps the plug-in's API manager.
	@param		apiManager	The PROAPIAccessing FxPlug passed to the plug-in's init.
	@return		A host ready to register parameters and vend the API wrappers. */
- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager;

@property (readonly, nonnull) id<FxGripAPIAccessing> apiManager;
@property (readonly, nonnull, assign) NSPriorityNotificationCenter *notifier;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripPluginHost_h */
