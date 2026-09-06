/*!
	@file       FxGripTileableEffect+Analyze.h
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+Analyze
	@abstract   The category that adds the FxPlug frame-analysis pass and its per-frame storage.
	@discussion Introduced in FxGrip 0.1.0. The category implements the FxAnalyzer protocol on the
	            effect base. An effect opts into pre-render analysis by declaring FxAnalyzer on its
	            own interface. The base answers the analysis callbacks, stores each frame's result
	            in the effect's analysisData, and reads it back at render. Object-tracker
	            parameters are analyzed automatically during the same pass.
*/

#ifndef FxGripTileableEffect_Analyze_h
#define FxGripTileableEffect_Analyze_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripTileableEffect.h"
#import "FxGripFrameData.h"
#import "FxGripObjectTrackerData.h"

/*!
	@abstract   The frame-analysis pass and its per-frame storage.
	@discussion Introduced in FxGrip 0.1.0. This category implements the FxPlug `FxAnalyzer`
				protocol on the effect base. An effect opts into pre-render analysis by
				declaring `<FxAnalyzer>` on its own interface; the base then answers the
				analysis callbacks, stores each frame's result in the effect's analysisData
				(an FxGripFrameData held by the auto-loaded FxGripAnalysis extension), and
				reads it back at render.

				A subclass overrides `analyzeImageTile:atTime:frameIndex:error:` to compute
				the per-frame record and, at render, calls `analysisRecordAtTime:` to read
				the analyzed value for the current time. The pass is started from a
				parameter action through `startForwardAnalysisAtLocation:error:` or its
				backward variant.
*/
@interface FxGripTileableEffect (Analyze)

/*!
	@method     analyzeImageTile:atTime:frameIndex:error:
	@abstract   Computes the per-frame record for one analyzed frame. Override to analyze.
	@discussion The default returns nil, storing nothing. Return any secure-codable, copyable
				value: a boxed scalar, a dictionary, or an FxGripImageBuffer. A non-nil result
				is stored at frameIndex in analysisData.
*/
- (nullable id<NSSecureCoding, NSCopying>)analyzeImageTile:(nonnull FxImageTile *)frame
												  atTime:(CMTime)frameTime
											  frameIndex:(NSInteger)frameIndex
												   error:(NSError *_Nullable *_Nullable)error;

/*! The absolute frame index for a time, derived from the analysis frame duration. */
- (NSInteger)analysisFrameIndexForTime:(CMTime)time;

/*! The stored record for a time: the latest at or before its frame index, or nil when none.
	Valid to call where the parameter API is available (e.g. pluginState:atTime:). */
- (nullable id<NSSecureCoding, NSCopying>)analysisRecordAtTime:(CMTime)time;

/*! The tracked transform of an object-tracker parameter at a time, resolved from the samples
	the pass stored. Returns NO when the parameter is not an object tracker, or has no sample
	at or before the time. The pass runs each object-tracker parameter automatically; an
	effect reads the result here at render. */
- (BOOL)objectTrackerTransform:(nonnull FxGripObjectTrackerTransform *)outTransform
				  forParameter:(FxParameterId)parameterID
						atTime:(CMTime)time;

/*! Persists the frame data into its hidden parameter. Called from cleanupAnalysis:. */
- (void)saveAnalysisData;

#pragma mark Driving the analysis pass

/*! The host's analysis state, or kFxAnalysisState_NotAnalyzing when the API is unavailable. */
- (FxAnalysisState)analysisState;

/*! Requests a forward analysis of the source clip. Call from a parameter action. */
- (BOOL)startForwardAnalysisAtLocation:(FxAnalysisLocation)location error:(NSError *_Nullable *_Nullable)error;

/*! Requests a backward analysis of the source clip. */
- (BOOL)startBackwardAnalysisAtLocation:(FxAnalysisLocation)location error:(NSError *_Nullable *_Nullable)error;

#pragma mark Utilities

/*!
	@method     averageColorOfImageTile:red:green:blue:alpha:
	@abstract   The area-average RGBA of a frame tile, for a subclass compute hook to use.
	@discussion Averages the tile through Core Image; any output channel pointer may be nil.
				Returns NO when the tile has no readable surface.
*/
+ (BOOL)averageColorOfImageTile:(nonnull FxImageTile *)tile
						   red:(nullable double *)red
						 green:(nullable double *)green
						  blue:(nullable double *)blue
						 alpha:(nullable double *)alpha;

/*! The Rec. 709 luminance of the tile's average color. */
+ (double)averageLuminanceOfImageTile:(nonnull FxImageTile *)tile;

@end

#endif
