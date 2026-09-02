//
//  FxGripPluginHost.h
//  FxGrip
//

#ifndef FxGripPluginHost_h
#define FxGripPluginHost_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripEffectHost.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripPluginHost
	@abstract   A ready-made FxGripEffectHost for an FxPlug plug-in that does not use the effect base.
	@discussion Introduced in FxGrip 1.0. An existing plug-in owns one of these alongside its own
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

/*! Wraps the plug-in's API manager, the one FxPlug passed to init. */
- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager;

@property (readonly, nonnull) id<FxGripAPIAccessing> apiManager;
@property (readonly, nonnull, assign) NSPriorityNotificationCenter *notifier;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripPluginHost_h */
