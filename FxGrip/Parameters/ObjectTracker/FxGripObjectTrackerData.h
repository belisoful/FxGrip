/*!
	@file       FxGripObjectTrackerData.h
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerData
	@abstract   The value type of an Object Tracker parameter and its configuration enums.
	@discussion Introduced in FxGrip 0.1.0. FxGripObjectTrackerData holds the tracker
	            configuration, the user-placed region, the linked parameter IDs, and the
	            per-frame samples. The enums name the region shape, the driven behavior, and
	            the analysis resolution. FxGripObjectTrackerTransform is the resolved
	            location, rotation, and size at a frame. Coordinates are normalized to the
	            frame with a lower-left origin, matching Vision.
*/

#ifndef FxGripObjectTrackerData_h
#define FxGripObjectTrackerData_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "FxGripObjectTracker.h"

NS_ASSUME_NONNULL_BEGIN

/*! The trackable region's shape. Phase 1 tracks the rectangle; the quadrilateral adds
	rotation through the Vision rectangle tracker. */
typedef NS_ENUM(NSInteger, FxGripObjectTrackerShape) {
	FxGripObjectTrackerShapeRectangle		= 0,
	FxGripObjectTrackerShapeQuadrilateral	= 1,
};

/*! What the tracker drives from the region. */
typedef NS_ENUM(NSInteger, FxGripObjectTrackerBehavior) {
	FxGripObjectTrackerBehaviorPositionOnly		= 0,
	FxGripObjectTrackerBehaviorPositionAndScale	= 1,
};

/*! The analysis resolution. Half resolution speeds tracking of high-resolution clips. */
typedef NS_ENUM(NSInteger, FxGripObjectTrackerResolution) {
	FxGripObjectTrackerResolutionFull	= 0,
	FxGripObjectTrackerResolutionHalf	= 1,
};

/*! A resolved tracked transform. Coordinates are normalized to the frame with a lower-left
	origin, matching Vision. `rotation` is zero for the phase-1 bounding-box tracker. */
typedef struct {
	CGPoint location;
	CGFloat rotation;
	CGSize  size;
} FxGripObjectTrackerTransform;

/*!
	@class      FxGripObjectTrackerData
	@abstract   The persisted value of an Object Tracker parameter: its configuration, the
				user-placed region, and the per-frame tracking result.
	@discussion Introduced in FxGrip 0.1.0. The value carries the whole tracker state so it
				saves with the host document and travels in a preset. The configuration
				(shape, behavior, resolution, smoothing, leading-filter inclusion, enabled
				state, label) is set at design time and edited in the inspector; `initialBox`
				is the region the on-screen control places; the frame-indexed samples are the
				analysis output the pass writes.

				Samples are sparse. `latestSampleAtOrBeforeFrame:` serves a seek to a frame
				the pass has not written by holding the last known result forward.
				`transform:atFrame:` resolves a sample to a location, rotation, and size,
				averaging the bounding box across a `smoothing`-frame window when smoothing is
				set. This is the direct-access half of the tracker's data API; the effect
				exposes the same result by time.
*/
@interface FxGripObjectTrackerData : NSObject <NSSecureCoding, NSCopying>

@property (copy, nonatomic) NSString *label;
@property (nonatomic) FxGripObjectTrackerShape shape;
@property (nonatomic) FxGripObjectTrackerBehavior behavior;
@property (nonatomic) FxGripObjectTrackerResolution resolution;

/*! The half-window, in frames, of the box-averaging smoother. 0 disables smoothing. */
@property (nonatomic) NSInteger smoothing;

/*! YES analyzes the layers beneath this effect together with it. */
@property (nonatomic) BOOL includeLeadingFilters;

/*! YES when the tracker participates in the analysis pass. */
@property (nonatomic) BOOL enabled;

/*! The user-placed region, normalized to the frame with a lower-left origin. Used to seed the
	tracker when the corner point parameters are not linked. */
@property (nonatomic) CGRect initialBox;

/*! The point parameter driven by the region's lower-left corner, or 0 when not linked. When
	both corners are linked, the analysis pass forms the seed box from them instead of
	`initialBox`. These are the FxFactory-style top-left / bottom-right links. */
@property (nonatomic) NSInteger lowerLeftParameterID;

/*! The point parameter driven by the region's upper-right corner, or 0 when not linked. */
@property (nonatomic) NSInteger upperRightParameterID;

/*! The point parameter driven to the tracked box center each frame, or 0 when not linked. */
@property (nonatomic) NSInteger centerParameterID;

/*! Point parameters that ride with the tracked object, each keeping its initial offset from
	the box center scaled by the box size change. NSNumber-wrapped parameter IDs; empty when
	none. These are the FxFactory-style anchor points. */
@property (copy, nonatomic) NSArray<NSNumber *> *anchorParameterIDs;

/*! The angle parameter driven, in degrees, by the quadrilateral tracker's rotation each
	frame, or 0 when not linked. */
@property (nonatomic) NSInteger angleParameterID;

@property (readonly, nonatomic) NSUInteger sampleCount;

/*! The first stored sample's frame index, or NSNotFound when there are no samples. This is
	the tracker's seed frame. */
@property (readonly, nonatomic) NSInteger seedFrame;

/*! The stored frame indexes, ascending. */
@property (readonly, nonatomic) NSArray<NSNumber *> *sampleFrameIndexes;

- (nullable FxGripObjectTrackerSample *)sampleAtFrame:(NSInteger)frameIndex;
- (void)setSample:(FxGripObjectTrackerSample *)sample atFrame:(NSInteger)frameIndex;

/*! The sample at the greatest stored index at or before `frameIndex`, or nil when none. */
- (nullable FxGripObjectTrackerSample *)latestSampleAtOrBeforeFrame:(NSInteger)frameIndex;

- (void)removeAllSamples;

/*! Resolves the tracked transform at a frame, holding the last result forward across gaps
	and applying the smoothing window. Returns NO when no sample exists at or before the
	frame. */
- (BOOL)transform:(nonnull FxGripObjectTrackerTransform *)outTransform atFrame:(NSInteger)frameIndex;

/*! The tracked box corners and center at a frame, from the resolved (smoothed) transform.
	Any output pointer may be NULL. Returns NO when no sample exists at or before the frame. */
- (BOOL)cornerBoxAtFrame:(NSInteger)frameIndex
			   lowerLeft:(nullable CGPoint *)lowerLeft
			  upperRight:(nullable CGPoint *)upperRight
				  center:(nullable CGPoint *)center;

/*! An anchor's position at a frame: it keeps `initialAnchor`'s offset from the seed-frame
	center, scaled per axis by the box size change from the seed frame. Returns NO when either
	the seed frame or the frame has no resolved transform, or the seed box is degenerate. */
- (BOOL)anchorPointAtFrame:(NSInteger)frameIndex
			 initialAnchor:(CGPoint)initialAnchor
				 seedFrame:(NSInteger)seedFrame
				  outPoint:(nonnull CGPoint *)outPoint;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripObjectTrackerData_h */
