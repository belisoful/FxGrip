/*!
	@file       FxGripAnalysis.h
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripAnalysis
	@abstract   The extension that owns the effect's per-frame analysis storage.
	@discussion Introduced in FxGrip 0.1.0. The extension registers a hidden custom parameter whose
	            value is an FxGripFrameData, loads it from the document, and attaches the project
	            media cache. It loads automatically when the effect conforms to the FxPlug
	            FxAnalyzer protocol.
*/

#ifndef FxGripAnalysis_h
#define FxGripAnalysis_h

#import "FxGripCustomExtension.h"
#import "FxGripFrameData.h"
#import "FxGripTileableEffect.h"

/*!
	@class      FxGripAnalysis
	@abstract   The extension that owns the effect's per-frame analysis storage.
	@discussion Introduced in FxGrip 0.1.0. Registers the hidden AnalysisData custom parameter
				(`kFxParameterId_AnalysisData`) whose value is an FxGripFrameData, loads it
				from the document when the effect is added, and attaches the project media
				cache so large per-frame records spill to disk.

				The extension is loaded automatically when the effect conforms to the FxPlug
				`FxAnalyzer` protocol; the analysis pass in FxGripTileableEffect (Analyze)
				reads and writes the frame data through the effect's `analysisData`.
*/
@interface FxGripAnalysis : FxGripCustomExtension

/*! The per-frame analysis store; created on demand, never nil once accessed. */
@property (readonly, nonatomic, nonnull) FxGripFrameData *frameData;

@end


/*!
	@abstract	The effect-side accessors for the analysis extension and its frame data.
	@discussion	Introduced in FxGrip 0.1.0. The analysis pass reads and writes per-frame records
				through analysisData.
*/
@interface FxGripTileableEffect (Analysis)

/*! The frame data of the loaded FxGripAnalysis extension; nil when analysis is not loaded. */
@property (readonly, nullable, nonatomic) FxGripFrameData *analysisData;

/*! YES when the FxGripAnalysis extension is loaded (the effect conforms to FxAnalyzer). */
@property (readonly, nonatomic) BOOL hasAnalysis;

/*! Creates the analysis extension instance for the loader to install. */
- (nonnull FxGripAnalysis *)newAnalysisExtension;

@end

#endif
