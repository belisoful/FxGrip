/*!
	@file       FxGripObjectTracker.m
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTracker
	@abstract   Implements the Vision-backed object tracker and its per-frame sample.
	@discussion Introduced in FxGrip 0.1.0. The tracker wraps a VNSequenceRequestHandler. It seeds a
	            detected-object observation, or a rectangle observation in rotation mode, and advances
	            it one frame per call. Each updated observation becomes the next frame's input.
*/

#import "FxGripObjectTracker.h"
#import <Vision/Vision.h>

/*!
	@abstract	One frame's tracking result.
	@discussion	Introduced in FxGrip 0.1.0. The sample holds the normalized bounding box, its center,
				the rotation, and the confidence. It is secure-codable and copyable.
*/
@implementation FxGripObjectTrackerSample

- (instancetype)initWithBoundingBox:(CGRect)boundingBox confidence:(float)confidence
{
	return [self initWithBoundingBox:boundingBox rotation:0.0 confidence:confidence];
}

- (instancetype)initWithBoundingBox:(CGRect)boundingBox rotation:(CGFloat)rotation confidence:(float)confidence
{
	self = [super init];
	if (self != nil) {
		_boundingBox = boundingBox;
		_rotation = rotation;
		_confidence = confidence;
	}
	return self;
}

- (CGPoint)center
{
	return CGPointMake(CGRectGetMidX(_boundingBox), CGRectGetMidY(_boundingBox));
}

- (id)copyWithZone:(NSZone *)zone
{
	return [[FxGripObjectTrackerSample allocWithZone:zone] initWithBoundingBox:_boundingBox
																	  rotation:_rotation
																	confidence:_confidence];
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super init];
	if (self != nil) {
		_boundingBox = CGRectMake([coder decodeDoubleForKey:@"x"], [coder decodeDoubleForKey:@"y"],
								  [coder decodeDoubleForKey:@"w"], [coder decodeDoubleForKey:@"h"]);
		_rotation = [coder decodeDoubleForKey:@"rotation"];
		_confidence = [coder decodeFloatForKey:@"confidence"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeDouble:_boundingBox.origin.x forKey:@"x"];
	[coder encodeDouble:_boundingBox.origin.y forKey:@"y"];
	[coder encodeDouble:_boundingBox.size.width forKey:@"w"];
	[coder encodeDouble:_boundingBox.size.height forKey:@"h"];
	[coder encodeDouble:_rotation forKey:@"rotation"];
	[coder encodeFloat:_confidence forKey:@"confidence"];
}

- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if (![object isKindOfClass:FxGripObjectTrackerSample.class]) {
		return NO;
	}
	FxGripObjectTrackerSample *other = object;
	return CGRectEqualToRect(_boundingBox, other->_boundingBox)
		&& _rotation == other->_rotation
		&& _confidence == other->_confidence;
}

- (NSUInteger)hash
{
	return (NSUInteger)(_boundingBox.origin.x * 73856093) ^ (NSUInteger)(_boundingBox.origin.y * 19349663);
}

@end


@interface FxGripObjectTracker ()
@property (nonatomic, strong) VNSequenceRequestHandler *sequenceHandler;
@property (nonatomic, strong, nullable) VNDetectedObjectObservation *lastObservation;
@property (nonatomic, strong, nullable) VNRectangleObservation *lastRectangleObservation;
@property (nonatomic) BOOL rotationActive;
@property (readwrite, nullable, nonatomic) FxGripObjectTrackerSample *lastSample;
@end

/*!
	@abstract	Tracks one object's bounding box across a frame sequence.
	@discussion	Introduced in FxGrip 0.1.0. The tracker holds a Vision sequence handler and the last
				observation. It seeds on the first frame and advances one frame per call.
*/
@implementation FxGripObjectTracker

- (instancetype)initWithLevel:(FxGripObjectTrackerLevel)level
{
	self = [super init];
	if (self != nil) {
		_level = level;
		_sequenceHandler = [[VNSequenceRequestHandler alloc] init];
	}
	return self;
}

- (VNRequestTrackingLevel)visionTrackingLevel
{
	return self.level == FxGripObjectTrackerLevelFast ? VNRequestTrackingLevelFast
													  : VNRequestTrackingLevelAccurate;
}

/*!
	@method		startTrackingImage:boundingBox:error:
	@abstract	Seeds the tracker with the first frame and the initial normalized bounding box.
	@param		image			The first frame as a CIImage.
	@param		normalizedBox	The initial region, normalized with a lower-left origin.
	@param		error			Set on failure.
	@return		YES when the tracker is seeded.
	@discussion	Introduced in FxGrip 0.1.0. A fresh sequence handler begins a new temporal sequence. In
				rotation mode the method detects a rectangle inside the seed box and tracks it; when no
				rectangle is found it falls back to the bounding-box path with zero rotation. */
- (BOOL)startTrackingImage:(CIImage *)image
			   boundingBox:(CGRect)normalizedBox
					 error:(NSError * _Nullable * _Nullable)error
{
	if (image == nil) {
		return NO;
	}
	// A fresh handler defines a new temporal sequence; the seeded box is the first result.
	self.sequenceHandler = [[VNSequenceRequestHandler alloc] init];
	self.lastObservation = nil;
	self.lastRectangleObservation = nil;
	self.rotationActive = NO;

	if (self.tracksRotation) {
		VNRectangleObservation *rectangle = [self detectRectangleInImage:image nearBox:normalizedBox];
		if (rectangle != nil) {
			self.lastRectangleObservation = rectangle;
			self.rotationActive = YES;
			self.lastSample = [self sampleFromRectangle:rectangle];
			return YES;
		}
		// No rectangle to seed; the bounding-box tracker takes over with zero rotation.
	}

	self.lastObservation = [VNDetectedObjectObservation observationWithBoundingBox:normalizedBox];
	self.lastSample = [[FxGripObjectTrackerSample alloc] initWithBoundingBox:normalizedBox
																 confidence:1.0f];
	return YES;
}

/*!
	@method		detectRectangleInImage:nearBox:
	@abstract	Returns the detected rectangle whose center is nearest the seed box center.
	@discussion	Introduced in FxGrip 0.1.0. The method runs a one-shot rectangle detection and picks the
				candidate closest to the box center, or nil when none is found. */
// The rectangle whose center is nearest the seed box center, or nil when none is found.
- (nullable VNRectangleObservation *)detectRectangleInImage:(CIImage *)image nearBox:(CGRect)box
{
	VNDetectRectanglesRequest *request = [[VNDetectRectanglesRequest alloc] init];
	request.maximumObservations = 16;
	request.minimumConfidence = 0.0f;
	VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCIImage:image options:@{}];
	if (![handler performRequests:@[request] error:NULL]) {
		return nil;
	}
	CGPoint target = CGPointMake(CGRectGetMidX(box), CGRectGetMidY(box));
	VNRectangleObservation *best = nil;
	CGFloat bestDistance = CGFLOAT_MAX;
	for (VNRectangleObservation *candidate in request.results) {
		CGPoint center = CGPointMake(CGRectGetMidX(candidate.boundingBox), CGRectGetMidY(candidate.boundingBox));
		CGFloat dx = center.x - target.x, dy = center.y - target.y;
		CGFloat distance = dx * dx + dy * dy;
		if (distance < bestDistance) {
			bestDistance = distance;
			best = candidate;
		}
	}
	return best;
}

/*!
	@method		sampleFromRectangle:
	@abstract	Builds a sample from a rectangle observation.
	@discussion	Introduced in FxGrip 0.1.0. The rotation is the angle of the tracked quad's top edge. */
// The axis-aligned bounds plus the rotation of the tracked quad's top edge.
- (FxGripObjectTrackerSample *)sampleFromRectangle:(VNRectangleObservation *)rectangle
{
	CGFloat rotation = atan2(rectangle.topRight.y - rectangle.topLeft.y,
							 rectangle.topRight.x - rectangle.topLeft.x);
	return [[FxGripObjectTrackerSample alloc] initWithBoundingBox:rectangle.boundingBox
														rotation:rotation
													  confidence:rectangle.confidence];
}

/*!
	@method		trackImage:error:
	@abstract	Advances the track by one frame and returns the updated sample.
	@param		image	The next frame as a CIImage.
	@param		error	Set on failure.
	@return		The updated sample, or nil when the object is lost or on error.
	@discussion	Introduced in FxGrip 0.1.0. In rotation mode the method runs a rectangle-tracking
				request; otherwise it runs an object-tracking request. The updated observation is stored
				as the next frame's input. */
- (nullable FxGripObjectTrackerSample *)trackImage:(CIImage *)image
											 error:(NSError * _Nullable * _Nullable)error
{
	if (image == nil) {
		return nil;
	}

	if (self.rotationActive && self.lastRectangleObservation != nil) {
		VNTrackRectangleRequest *request =
			[[VNTrackRectangleRequest alloc] initWithRectangleObservation:self.lastRectangleObservation];
		request.trackingLevel = [self visionTrackingLevel];
		if (![self.sequenceHandler performRequests:@[request] onCIImage:image error:error]) {
			return nil;
		}
		VNRectangleObservation *updated = (VNRectangleObservation *)request.results.firstObject;
		if (![updated isKindOfClass:VNRectangleObservation.class]) {
			return nil;
		}
		self.lastRectangleObservation = updated;
		self.lastSample = [self sampleFromRectangle:updated];
		return self.lastSample;
	}

	if (self.lastObservation == nil) {
		return nil;
	}
	VNTrackObjectRequest *request =
		[[VNTrackObjectRequest alloc] initWithDetectedObjectObservation:self.lastObservation];
	request.trackingLevel = [self visionTrackingLevel];

	if (![self.sequenceHandler performRequests:@[request] onCIImage:image error:error]) {
		return nil;
	}

	VNDetectedObjectObservation *updated = (VNDetectedObjectObservation *)request.results.firstObject;
	if (![updated isKindOfClass:VNDetectedObjectObservation.class]) {
		return nil;
	}

	self.lastObservation = updated;
	self.lastSample = [[FxGripObjectTrackerSample alloc] initWithBoundingBox:updated.boundingBox
																 confidence:updated.confidence];
	return self.lastSample;
}

/*!
	@method		reset
	@abstract	Clears the sequence handler and the seeded observation.
	@discussion	Introduced in FxGrip 0.1.0. A later startTrackingImage:boundingBox:error: begins a new
				sequence. */
- (void)reset
{
	self.sequenceHandler = [[VNSequenceRequestHandler alloc] init];
	self.lastObservation = nil;
	self.lastRectangleObservation = nil;
	self.rotationActive = NO;
	self.lastSample = nil;
}

@end
