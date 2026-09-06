/*!
	@file       FxGripMeta.h
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMeta
	@abstract   The extension that owns the effect's per-instance parameter meta storage.
	@discussion Introduced in FxGrip 0.1.0. The extension registers a hidden custom parameter, loads an
	            FxGripMetaManager from the document, seeds a record for each parameter from its
	            configuration, applies target presets on parameter changes, and persists the manager
	            on flush. Activation is driven by the plist manageMeta boolean, which defaults to YES.
*/

#ifndef FxGripMeta_h
#define FxGripMeta_h

#import "FxGripCustomExtension.h"
#import "FxGripMetaManager.h"
#import "FxGripTileableEffect.h"

/*!
	@class      FxGripMeta
	@abstract   The extension that owns the effect's FxGripMetaManager.
	@discussion Introduced in FxGrip 0.1.0. Registers the hidden InstanceMeta custom
				parameter (`kFxParameterId_InstanceMeta`), loads the manager from the
				document when the effect is added, seeds a record for each parameter as
				it is created (transferring the configuration's tags, meta, reset value,
				and target-preset definitions into per-instance storage), and persists
				the manager on flush.

				Configuration transfer is additive: values already present in a record,
				including customizations restored from the document, are kept; the
				configuration supplies defaults for absent entries only. Target-preset
				definitions therefore live in the instance storage and are customizable
				per instance.

				Activation is driven by the plist `manageMeta` boolean, which defaults
				to YES, through the standard extension loading path. A plugin opts out
				with `manageMeta` = NO.
*/
@interface FxGripMeta : FxGripCustomExtension

/*! The effect's meta manager. nil until a parameter is seeded or the effect is added
	to the document. */
@property (readonly, nonatomic, nullable) FxGripMetaManager *manager;

@end


/*!
	@abstract	The effect-side accessors for the meta extension and its manager.
	@discussion	Introduced in FxGrip 0.1.0. meta resolves the loaded extension's manager.
*/
@interface FxGripTileableEffect (Meta)

/*! The meta manager of the loaded FxGripMeta extension; nil when meta is not managed. */
@property (readonly, nullable, nonatomic) FxGripMetaManager *meta;

/*! YES when the FxGripMeta extension is loaded. */
@property (readonly, nonatomic) BOOL hasMeta;

/*! Creates the meta extension instance for the loader to install. */
- (nonnull FxGripMeta *)newMetaExtension;

@end

#endif
