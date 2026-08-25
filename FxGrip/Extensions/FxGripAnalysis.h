//
//  FxGripAnalysis.h
//  FxGrip
//
//  Copyright © 2026 Belisoful All rights reserved.
//

#ifndef FxGripAnalysis_h
#define FxGripAnalysis_h

#import "FxGripCustomExtension.h"
#import "FxGripFrameData.h"
#import "FxTileableEffectBase.h"

/*!
	@class      FxGripAnalysis
	@abstract   The extension that owns the effect's per-frame analysis storage.
	@discussion Introduced in FxGrip 1.0. Registers the hidden AnalysisData custom parameter
				(`kFxParameterId_AnalysisData`) whose value is an FxGripFrameData, loads it
				from the document when the effect is added, and attaches the project media
				cache so large per-frame records spill to disk.

				The extension is loaded automatically when the effect conforms to the FxPlug
				`FxAnalyzer` protocol; the analysis pass in FxTileableEffectBase (Analyze)
				reads and writes the frame data through the effect's `analysisData`.
*/
@interface FxGripAnalysis : FxGripCustomExtension

/*! The per-frame analysis store; created on demand, never nil once accessed. */
@property (readonly, nonatomic, nonnull) FxGripFrameData *frameData;

@end


@interface FxTileableEffectBase (Analysis)

/*! The frame data of the loaded FxGripAnalysis extension; nil when analysis is not loaded. */
@property (readonly, nullable, nonatomic) FxGripFrameData *analysisData;

/*! YES when the FxGripAnalysis extension is loaded (the effect conforms to FxAnalyzer). */
@property (readonly, nonatomic) BOOL hasAnalysis;

- (nonnull FxGripAnalysis *)newAnalysisExtension;

@end

#endif
