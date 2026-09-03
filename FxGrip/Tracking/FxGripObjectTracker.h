//
//  FxGripObjectTracker.h
//  FxGrip
//
//  Copyright © 2026 Belisoful All rights reserved.
//

#ifndef FxGripObjectTracker_h
#define FxGripObjectTracker_h

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/*! The tracker's search effort, mapped to the Vision request tracking level. */
typedef NS_ENUM(NSInteger, FxGripObjectTrackerLevel) {
	FxGripObjectTrackerLevelFast		= 0,
	FxGripObjectTrackerLevelAccurate	= 1,
};

/*!
	@class      FxGripObjectTrackerSample
	@abstract   One frame's tracking result.
	@discussion Introduced in FxGrip 1.0. The bounding box is normalized to the image with a
				lower-left origin, matching Vision's convention; `center` is the box center in
				the same space. The initial version reports position and scale only; rotation
				arrives with the quadrilateral tracker.
*/
@interface FxGripObjectTrackerSample : NSObject <NSSecureCoding, NSCopying>

@property (readonly, nonatomic) CGRect boundingBox;
@property (readonly, nonatomic) CGPoint center;
@property (readonly, nonatomic) float confidence;

/*! The tracked region's rotation in radians, counterclockwise. Zero for the bounding-box
	tracker; the rectangle tracker fills it from the tracked quad's top edge. */
@property (readonly, nonatomic) CGFloat rotation;

- (instancetype)initWithBoundingBox:(CGRect)boundingBox confidence:(float)confidence;
- (instancetype)initWithBoundingBox:(CGRect)boundingBox rotation:(CGFloat)rotation confidence:(float)confidence;

@end

/*!
	@class      FxGripObjectTracker
	@abstract   Tracks one object's bounding box across a frame sequence.
	@discussion Introduced in FxGrip 1.0. Wraps a Vision sequence request handler and a
				bounding-box tracking request. `startTrackingImage:boundingBox:error:` seeds
				the tracker with the initial region on the first frame; each later
				`trackImage:error:` advances the track by one frame and returns the updated
				sample. The tracker feeds each result forward as the next frame's input
				observation, so frames are supplied in temporal order.

				This is the engine seam the Object Tracker parameter drives from the FxGrip
				analysis pass. It consumes the same CIImage the pass already builds from an
				FxImageTile's IOSurface, so no extra image plumbing is required.
*/
@interface FxGripObjectTracker : NSObject

@property (nonatomic) FxGripObjectTrackerLevel level;

/*! YES tracks a rectangle and reports rotation through VNTrackRectangleRequest, seeded by a
	one-shot rectangle detection inside the initial box. When detection finds no rectangle the
	tracker falls back to the bounding-box path and reports zero rotation. Set before
	`startTrackingImage:boundingBox:error:`. */
@property (nonatomic) BOOL tracksRotation;

/*! The most recent sample, or nil before tracking starts or after a reset. */
@property (readonly, nullable, nonatomic) FxGripObjectTrackerSample *lastSample;

- (instancetype)initWithLevel:(FxGripObjectTrackerLevel)level;

/*! Seeds the tracker with the first frame and the initial normalized bounding box. */
- (BOOL)startTrackingImage:(CIImage *)image
			   boundingBox:(CGRect)normalizedBox
					 error:(NSError * _Nullable * _Nullable)error;

/*! Advances the track by one frame; nil when the object is lost or on error. */
- (nullable FxGripObjectTrackerSample *)trackImage:(CIImage *)image
											 error:(NSError * _Nullable * _Nullable)error;

/*! Clears the sequence handler and the seeded observation. */
- (void)reset;

@end

NS_ASSUME_NONNULL_END

#endif
