/*!
	@file       FxGripMLCache.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMLCache
	@abstract   The extension that owns an ML effect's per-frame inference cache.
	@discussion Introduced in FxGrip 0.1.0. The extension registers a hidden custom parameter whose
	            value is an FxGripFrameData, loads it from the document, and attaches the project
	            media cache so cached inference outputs spill to disk and survive a reopen.
*/

#ifndef FxGripMLCache_h
#define FxGripMLCache_h

#import "FxGripCustomExtension.h"
#import "FxGripFrameData.h"
#import "FxGripTileableEffect.h"

/*!
	@class      FxGripMLCache
	@abstract   The extension that owns an ML effect's per-frame inference cache.
	@discussion Introduced in FxGrip 0.1.0. Registers the hidden MLCache custom parameter
				(`kFxParameterId_MLCache`) whose value is an FxGripFrameData, loads it from the
				document when the effect is added, and attaches the project media cache so cached
				frames spill to disk. The records are FxGripImageBuffer copies of inference
				outputs, keyed by frame, so a multi-second model runs once per frame and survives
				a reopen.

				FxGripMLImageEffect loads this extension and reads and writes the cache through
				the effect's mlCacheData.
*/
@interface FxGripMLCache : FxGripCustomExtension

/*! The per-frame inference cache; created on demand, never nil once accessed. */
@property (readonly, nonatomic, nonnull) FxGripFrameData *frameData;

@end


/*!
	@abstract	The effect-side accessors for the ML cache extension and its frame data.
	@discussion	Introduced in FxGrip 0.1.0. FxGripMLImageEffect reads and writes the cache through
				mlCacheData.
*/
@interface FxGripTileableEffect (MLCache)

/*! The frame data of the loaded FxGripMLCache extension; nil when the cache is not loaded. */
@property (readonly, nullable, nonatomic) FxGripFrameData *mlCacheData;

/*! YES when the FxGripMLCache extension is loaded. */
@property (readonly, nonatomic) BOOL hasMLCache;

/*! Creates the ML cache extension instance for the loader to install. */
- (nonnull FxGripMLCache *)newMLCacheExtension;

@end

#endif /* FxGripMLCache_h */
