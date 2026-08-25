//
//  FxGripExtensionSystem.h
//  FxGrip
//

#ifndef FxGripExtensionSystem_h
#define FxGripExtensionSystem_h

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "FxExtension.h"
#import "FxGripEffectHost.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripExtensionSystem
	@abstract   Runs FxGrip extensions inside an FxPlug plug-in that does not use the effect base.
	@discussion Introduced in FxGrip 1.0. FxTileableEffectBase drives its extensions by posting
				lifecycle notifications; this class posts the same notifications, with the same
				payloads, over an effect host, so the extension machinery runs as a self-contained
				subsystem. The plug-in loads the extensions it wants and forwards each FxPlug
				lifecycle call to the matching dispatch method:

				- -properties: → dispatchProperties:
				- -addParameters → dispatchAddParameters: (with the plug-in's parameter dictionaries)
				- the end of setup → dispatchFinishInitialSetup, then dispatchAddedToDocument
				- -parameterChanged:atTime:error: → dispatchParameterChanged:atTime:
				- a custom-parameter click → dispatchParameterClicked:
				- -pluginState:atTime:error: → dispatchPluginStateWithCoder:
				- after out-of-band writes → flush

				An extension observes the host it was loaded with, so several systems coexist.
				An extension that reaches beyond the host contract (the analysis pass reads the
				render pipeline, for example) needs the fuller member it asks for; the
				parameter-facing extensions (meta, parameter data, toggles) run on the host alone.
*/
@interface FxGripExtensionSystem : NSObject

- (instancetype)initWithHost:(id<FxGripEffectHost>)host;

@property (readonly, nonnull, assign) id<FxGripEffectHost> host;

/*! The loaded extensions, in load order. */
@property (readonly, nonnull) NSArray<id<FxExtension>> *extensions;

/*! Loads an extension against the host; returns the extension's own load result. */
- (BOOL)loadExtension:(id<FxExtension>)extension;

/*! The first loaded extension of a class, or nil. */
- (nullable id<FxExtension>)extensionForClass:(Class)extensionClass;

/*! Announces the host to the loaded extensions; call once after loading them. */
- (void)dispatchInit;

/*! Runs the extensions over the plug-in's properties dictionary and returns the result. */
- (NSMutableDictionary *)dispatchProperties:(NSDictionary *)properties;

/*! Runs the extensions over the plug-in's parameter dictionaries and returns the result. The
	extensions may add, remove, and reorder entries; register what comes back. */
- (NSMutableArray *)dispatchAddParameters:(NSArray *)parameters;

/*! Announces the end of initial setup. */
- (void)dispatchFinishInitialSetup;

/*! Announces that the plug-in is live in the document; extensions load their stored state. */
- (void)dispatchAddedToDocument;

/*! Forwards a parameter change. */
- (void)dispatchParameterChanged:(UInt32)parameterID atTime:(CMTime)time;

/*! Forwards a custom-parameter click. */
- (void)dispatchParameterClicked:(UInt32)parameterID;

/*! Runs the extensions over the plug-in state coder. */
- (void)dispatchPluginStateWithCoder:(NSCoder *)coder;

/*! Flushes extension state to the host; nil on success. */
- (nullable NSError *)flush;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripExtensionSystem_h */
