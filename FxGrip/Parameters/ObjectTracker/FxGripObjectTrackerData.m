/*!
	@file       FxGripObjectTrackerData.m
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerData
	@abstract   Implements the Object Tracker parameter value type.
	@discussion Introduced in FxGrip 0.1.0. Samples are held in a frame-indexed dictionary and
	            are sparse. Resolution of a frame holds the last known sample forward and
	            averages the bounding box across the smoothing window. The type supports
	            secure coding and copying so it saves with the host document.
*/

#import "FxGripObjectTrackerData.h"

/*!
	@abstract	The persisted value of an Object Tracker parameter.
	@discussion	Introduced in FxGrip 0.1.0. The value stores the tracker configuration, the
				user-placed region, the linked parameter IDs, and the per-frame samples.
*/
@implementation FxGripObjectTrackerData
{
	NSMutableDictionary<NSNumber *, FxGripObjectTrackerSample *> *_samples;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_label = @"";
		_shape = FxGripObjectTrackerShapeRectangle;
		_behavior = FxGripObjectTrackerBehaviorPositionAndScale;
		_resolution = FxGripObjectTrackerResolutionFull;
		_smoothing = 0;
		_includeLeadingFilters = NO;
		_enabled = YES;
		_initialBox = CGRectMake(0.4, 0.4, 0.2, 0.2);
		_lowerLeftParameterID = 0;
		_upperRightParameterID = 0;
		_centerParameterID = 0;
		_anchorParameterIDs = @[];
		_angleParameterID = 0;
		_samples = [NSMutableDictionary dictionary];
	}
	return self;
}

#pragma mark Samples

- (NSUInteger)sampleCount
{
	return _samples.count;
}

- (NSArray<NSNumber *> *)sampleFrameIndexes
{
	return [_samples.allKeys sortedArrayUsingSelector:@selector(compare:)];
}

- (NSInteger)seedFrame
{
	NSArray<NSNumber *> *indexes = self.sampleFrameIndexes;
	return indexes.count > 0 ? indexes.firstObject.integerValue : NSNotFound;
}

- (nullable FxGripObjectTrackerSample *)sampleAtFrame:(NSInteger)frameIndex
{
	return _samples[@(frameIndex)];
}

- (void)setSample:(FxGripObjectTrackerSample *)sample atFrame:(NSInteger)frameIndex
{
	if (sample == nil) {
		[_samples removeObjectForKey:@(frameIndex)];
		return;
	}
	_samples[@(frameIndex)] = sample;
}

/*!
	@method		latestSampleAtOrBeforeFrame:
	@abstract	Returns the sample at the greatest stored frame at or before a frame.
	@return		The nearest earlier sample, or nil when no sample is at or before the frame.
	@discussion	Introduced in FxGrip 0.1.0. The lookup serves a seek to a frame the pass has not
				written by holding the last known result forward. */
- (nullable FxGripObjectTrackerSample *)latestSampleAtOrBeforeFrame:(NSInteger)frameIndex
{
	NSInteger best = NSIntegerMin;
	for (NSNumber *key in _samples) {
		NSInteger index = key.integerValue;
		if (index <= frameIndex && index > best) {
			best = index;
		}
	}
	return best == NSIntegerMin ? nil : _samples[@(best)];
}

- (void)removeAllSamples
{
	[_samples removeAllObjects];
}

/*!
	@method		transform:atFrame:
	@abstract	Resolves the tracked transform at a frame into the output structure.
	@return		YES when a sample exists at or before the frame; NO otherwise.
	@discussion	Introduced in FxGrip 0.1.0. The base sample is the latest at or before the frame.
				A smoothing window greater than zero averages the bounding-box origin, size, and
				rotation across the frames within the window. The location is the box center. */
- (BOOL)transform:(FxGripObjectTrackerTransform *)outTransform atFrame:(NSInteger)frameIndex
{
	if (outTransform == NULL) {
		return NO;
	}
	FxGripObjectTrackerSample *base = [self latestSampleAtOrBeforeFrame:frameIndex];
	if (base == nil) {
		return NO;
	}

	CGRect box = base.boundingBox;
	CGFloat rotation = base.rotation;
	if (_smoothing > 0) {
		CGFloat sumX = 0.0, sumY = 0.0, sumW = 0.0, sumH = 0.0, sumRotation = 0.0;
		NSInteger count = 0;
		for (NSInteger index = frameIndex - _smoothing; index <= frameIndex + _smoothing; index++) {
			FxGripObjectTrackerSample *sample = _samples[@(index)];
			if (sample == nil) {
				continue;
			}
			sumX += sample.boundingBox.origin.x;
			sumY += sample.boundingBox.origin.y;
			sumW += sample.boundingBox.size.width;
			sumH += sample.boundingBox.size.height;
			sumRotation += sample.rotation;
			count += 1;
		}
		if (count > 0) {
			box = CGRectMake(sumX / count, sumY / count, sumW / count, sumH / count);
			rotation = sumRotation / count;
		}
	} else {
		FxGripObjectTrackerSample *exact = _samples[@(frameIndex)];
		if (exact != nil) {
			box = exact.boundingBox;
			rotation = exact.rotation;
		}
	}

	outTransform->location = CGPointMake(CGRectGetMidX(box), CGRectGetMidY(box));
	outTransform->size = box.size;
	outTransform->rotation = rotation;
	return YES;
}

/*!
	@method		cornerBoxAtFrame:lowerLeft:upperRight:center:
	@abstract	Reports the tracked box corners and center at a frame.
	@return		YES when a sample exists at or before the frame; NO otherwise.
	@discussion	Introduced in FxGrip 0.1.0. The corners and center derive from the resolved,
				smoothed transform. Any output pointer may be NULL. */
- (BOOL)cornerBoxAtFrame:(NSInteger)frameIndex
			   lowerLeft:(CGPoint *)lowerLeft
			  upperRight:(CGPoint *)upperRight
				  center:(CGPoint *)center
{
	FxGripObjectTrackerTransform t = {0};
	if (![self transform:&t atFrame:frameIndex]) {
		return NO;
	}
	if (lowerLeft != NULL) {
		*lowerLeft = CGPointMake(t.location.x - t.size.width / 2.0, t.location.y - t.size.height / 2.0);
	}
	if (upperRight != NULL) {
		*upperRight = CGPointMake(t.location.x + t.size.width / 2.0, t.location.y + t.size.height / 2.0);
	}
	if (center != NULL) {
		*center = t.location;
	}
	return YES;
}

/*!
	@method		anchorPointAtFrame:initialAnchor:seedFrame:outPoint:
	@abstract	Resolves an anchor point's position at a frame.
	@return		YES when both the seed frame and the frame resolve and the seed box is non-degenerate.
	@discussion	Introduced in FxGrip 0.1.0. The anchor keeps its initial offset from the seed-frame
				center, scaled per axis by the box size change from the seed frame. */
- (BOOL)anchorPointAtFrame:(NSInteger)frameIndex
			 initialAnchor:(CGPoint)initialAnchor
				 seedFrame:(NSInteger)seedFrame
				  outPoint:(CGPoint *)outPoint
{
	FxGripObjectTrackerTransform seed = {0};
	FxGripObjectTrackerTransform frame = {0};
	if (![self transform:&seed atFrame:seedFrame] || ![self transform:&frame atFrame:frameIndex]) {
		return NO;
	}
	if (seed.size.width <= 0.0 || seed.size.height <= 0.0) {
		return NO;
	}
	CGFloat scaleX = frame.size.width / seed.size.width;
	CGFloat scaleY = frame.size.height / seed.size.height;
	outPoint->x = frame.location.x + (initialAnchor.x - seed.location.x) * scaleX;
	outPoint->y = frame.location.y + (initialAnchor.y - seed.location.y) * scaleY;
	return YES;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	FxGripObjectTrackerData *copy = [[FxGripObjectTrackerData allocWithZone:zone] init];
	copy->_label = [_label copyWithZone:zone];
	copy->_shape = _shape;
	copy->_behavior = _behavior;
	copy->_resolution = _resolution;
	copy->_smoothing = _smoothing;
	copy->_includeLeadingFilters = _includeLeadingFilters;
	copy->_enabled = _enabled;
	copy->_initialBox = _initialBox;
	copy->_lowerLeftParameterID = _lowerLeftParameterID;
	copy->_upperRightParameterID = _upperRightParameterID;
	copy->_centerParameterID = _centerParameterID;
	copy->_anchorParameterIDs = [_anchorParameterIDs copyWithZone:zone];
	copy->_angleParameterID = _angleParameterID;
	copy->_samples = [[NSMutableDictionary allocWithZone:zone] initWithDictionary:_samples copyItems:YES];
	return copy;
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
	self = [self init];
	if (self != nil) {
		NSString *label = [coder decodeObjectOfClass:NSString.class forKey:@"label"];
		if (label != nil) {
			_label = [label copy];
		}
		_shape = [coder decodeIntegerForKey:@"shape"];
		_behavior = [coder decodeIntegerForKey:@"behavior"];
		_resolution = [coder decodeIntegerForKey:@"resolution"];
		_smoothing = [coder decodeIntegerForKey:@"smoothing"];
		_includeLeadingFilters = [coder decodeBoolForKey:@"includeLeadingFilters"];
		_enabled = [coder decodeBoolForKey:@"enabled"];
		_initialBox = CGRectMake([coder decodeDoubleForKey:@"boxX"], [coder decodeDoubleForKey:@"boxY"],
								 [coder decodeDoubleForKey:@"boxW"], [coder decodeDoubleForKey:@"boxH"]);
		_lowerLeftParameterID = [coder decodeIntegerForKey:@"lowerLeftParameterID"];
		_upperRightParameterID = [coder decodeIntegerForKey:@"upperRightParameterID"];
		_centerParameterID = [coder decodeIntegerForKey:@"centerParameterID"];
		_angleParameterID = [coder decodeIntegerForKey:@"angleParameterID"];
		NSSet *anchorClasses = [NSSet setWithObjects:NSArray.class, NSNumber.class, nil];
		NSArray *anchors = [coder decodeObjectOfClasses:anchorClasses forKey:@"anchorParameterIDs"];
		if ([anchors isKindOfClass:NSArray.class]) {
			_anchorParameterIDs = [anchors copy];
		}
		NSSet *classes = [NSSet setWithObjects:NSMutableDictionary.class, NSNumber.class,
						  FxGripObjectTrackerSample.class, nil];
		NSDictionary *samples = [coder decodeObjectOfClasses:classes forKey:@"samples"];
		if ([samples isKindOfClass:NSDictionary.class]) {
			_samples = [samples mutableCopy];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_label forKey:@"label"];
	[coder encodeInteger:_shape forKey:@"shape"];
	[coder encodeInteger:_behavior forKey:@"behavior"];
	[coder encodeInteger:_resolution forKey:@"resolution"];
	[coder encodeInteger:_smoothing forKey:@"smoothing"];
	[coder encodeBool:_includeLeadingFilters forKey:@"includeLeadingFilters"];
	[coder encodeBool:_enabled forKey:@"enabled"];
	[coder encodeDouble:_initialBox.origin.x forKey:@"boxX"];
	[coder encodeDouble:_initialBox.origin.y forKey:@"boxY"];
	[coder encodeDouble:_initialBox.size.width forKey:@"boxW"];
	[coder encodeDouble:_initialBox.size.height forKey:@"boxH"];
	[coder encodeInteger:_lowerLeftParameterID forKey:@"lowerLeftParameterID"];
	[coder encodeInteger:_upperRightParameterID forKey:@"upperRightParameterID"];
	[coder encodeInteger:_centerParameterID forKey:@"centerParameterID"];
	[coder encodeInteger:_angleParameterID forKey:@"angleParameterID"];
	[coder encodeObject:_anchorParameterIDs forKey:@"anchorParameterIDs"];
	[coder encodeObject:_samples forKey:@"samples"];
}

@end
