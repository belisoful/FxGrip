/*!
	@file       FxGripObjectTrackerParameter.h
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerParameter
	@abstract   The custom parameter that tracks an object across the clip.
	@discussion Introduced in FxGrip 0.1.0. The parameter's value is an FxGripObjectTrackerData
	            holding the configuration, the region, and the per-frame result. The
	            kFxGripObjectTrackerKey_* constants name the design-time configuration keys
	            read from the parameter dictionary's default value. The analysis-pass methods
	            arm the tracker, analyze each frame, and write the samples back into the value.
*/

#ifndef FxGripObjectTrackerParameter_h
#define FxGripObjectTrackerParameter_h

#import "FxGripCustomParameter.h"
#import "FxGripObjectTrackerData.h"
#import <CoreImage/CoreImage.h>

// Design-time configuration keys read from the parameter dictionary's default value.
#define kFxGripObjectTrackerKey_Shape					@"shape"
#define kFxGripObjectTrackerKey_Behavior				@"behavior"
#define kFxGripObjectTrackerKey_Resolution				@"resolution"
#define kFxGripObjectTrackerKey_Smoothing				@"smoothing"
#define kFxGripObjectTrackerKey_IncludeLeadingFilters	@"includeLeadingFilters"
#define kFxGripObjectTrackerKey_Enabled					@"enabled"
#define kFxGripObjectTrackerKey_Label					@"label"
// A four-number array [x, y, width, height], normalized to the frame, lower-left origin.
#define kFxGripObjectTrackerKey_InitialBox				@"initialBox"
// Point parameter IDs the region's corners drive; when both are set the seed box is read
// from them instead of the initial box.
#define kFxGripObjectTrackerKey_LowerLeftParameterID	@"lowerLeftParameterID"
#define kFxGripObjectTrackerKey_UpperRightParameterID	@"upperRightParameterID"
// The center point parameter the track drives, and an array of anchor point parameter IDs.
#define kFxGripObjectTrackerKey_CenterParameterID		@"centerParameterID"
#define kFxGripObjectTrackerKey_AnchorParameterIDs		@"anchorParameterIDs"
// The angle parameter the quadrilateral tracker's rotation drives, in degrees.
#define kFxGripObjectTrackerKey_AngleParameterID		@"angleParameterID"

/*!
	@class      FxGripObjectTrackerParameter
	@abstract   The state object of a canvas object tracker.
	@discussion Introduced in FxGrip 0.1.0. The parameter's value is an FxGripObjectTrackerData
				that carries the tracker configuration, the user-placed region, and the
				per-frame tracking result, so the whole tracker saves with the host document
				and travels in a preset.

				The inspector shows an FxGripObjectTrackerView editing the shape, behavior,
				resolution, and smoothing. The on-canvas surface is the tracker on-screen
				control, the trigger is an [[FxGripAnalyzerParameter]] button, and a companion
				[[FxGripStatusParameter]] / [[FxGripProgressParameter]] pair reports progress.
				The analysis pass writes samples into the value; the render pass reads a
				resolved transform back by time.

				Coordinate space: the tracker works entirely in Vision's normalized space, a
				unit square with a lower-left origin. `initialBox`, the linked corner, center,
				and anchor point values, and every stored sample use it. FxPlug point
				parameters in Final Cut Pro and Motion are normalized to the frame, so a linked
				point maps directly; a point parameter declared in another range must be
				converted to the unit square before analysis and back afterward. The on-screen
				control places the corners through the host's OSC coordinate API, which is the
				one mapping that needs verification in a running host.
*/
@interface FxGripObjectTrackerParameter : FxGripCustomParameter

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (nullable NSSet<Class> *)customValueClasses;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

#pragma mark Analysis-pass driving

/*! Loads the current value, clears its samples, and arms a fresh tracker for a pass. The
	analysis pass calls this once at setup; a subclass does not. */
- (void)beginObjectTrackingAnalysis;

/*! As `beginObjectTrackingAnalysis`, plus the frame duration the pass reports. The duration
	places the keyframes written to the linked center and anchor points when the pass ends; an
	invalid duration skips that keyframing. */
- (void)beginObjectTrackingAnalysisWithFrameDuration:(CMTime)frameDuration;

/*! Seeds from `initialBox` on the first frame of the pass, then tracks each later frame,
	storing the sample. A disabled tracker ignores the frame. */
- (void)analyzeObjectTrackingImage:(nonnull CIImage *)image atFrame:(NSInteger)frameIndex;

/*! Writes the accumulated samples back into the parameter value and releases the tracker. */
- (void)endObjectTrackingAnalysis;

/*! The resolved transform at a frame from the stored samples, holding the last result
	forward across gaps. Returns NO when no sample exists at or before the frame. */
- (BOOL)transform:(nonnull FxGripObjectTrackerTransform *)outTransform atFrame:(NSInteger)frameIndex;

@end

#endif /* FxGripObjectTrackerParameter_h */
