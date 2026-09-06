/*!
	@file       FxGripObjectTrackerParameter.m
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerParameter
	@abstract   Implements the custom parameter that tracks an object across the clip.
	@discussion Introduced in FxGrip 0.1.0. The analysis pass arms a Vision tracker, seeds it
	            from the placed region on the first frame, and stores a sample per frame. When
	            the pass ends, the samples save into the parameter value and the linked center,
	            angle, and anchor points are baked as keyframes across the analyzed frames.
*/

#import "FxGripObjectTrackerParameter.h"
#import "FxGripObjectTrackerView.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripObjectTracker.h"

/*!
	@abstract	The custom parameter that tracks an object across the clip.
	@discussion	Introduced in FxGrip 0.1.0. The value is an FxGripObjectTrackerData. The class
				drives the analysis pass and reads a resolved transform back by frame.
*/
@implementation FxGripObjectTrackerParameter
{
	FxGripObjectTracker *_analysisTracker;
	FxGripObjectTrackerData *_analysisWorkingData;
	BOOL _analysisNeedsSeed;
	CMTime _analysisFrameDuration;
	NSDictionary<NSNumber *, NSValue *> *_analysisAnchorInitials;
}

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_ObjectTracker;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_ObjectTracker;
}

+ (nullable NSSet<Class> *)customValueClasses
{
	return [NSSet setWithObjects:FxGripObjectTrackerData.class, FxGripObjectTrackerSample.class, nil];
}

/*!
	@method		trackerDataFromDeclared:
	@abstract	Builds a tracker value from the parameter's declared configuration dictionary.
	@return		A tracker value seeded from the declared keys, or a default value when the input is not a dictionary.
	@discussion	Introduced in FxGrip 0.1.0. Each kFxGripObjectTrackerKey_* entry is applied only
				when it is present and of the expected class. */
+ (FxGripObjectTrackerData *)trackerDataFromDeclared:(nullable NSDictionary *)declared
{
	FxGripObjectTrackerData *data = [[FxGripObjectTrackerData alloc] init];
	if (![declared isKindOfClass:NSDictionary.class]) {
		return data;
	}

	NSNumber *shape = declared[kFxGripObjectTrackerKey_Shape];
	if ([shape isKindOfClass:NSNumber.class]) {
		data.shape = shape.integerValue;
	}
	NSNumber *behavior = declared[kFxGripObjectTrackerKey_Behavior];
	if ([behavior isKindOfClass:NSNumber.class]) {
		data.behavior = behavior.integerValue;
	}
	NSNumber *resolution = declared[kFxGripObjectTrackerKey_Resolution];
	if ([resolution isKindOfClass:NSNumber.class]) {
		data.resolution = resolution.integerValue;
	}
	NSNumber *smoothing = declared[kFxGripObjectTrackerKey_Smoothing];
	if ([smoothing isKindOfClass:NSNumber.class]) {
		data.smoothing = smoothing.integerValue;
	}
	NSNumber *leading = declared[kFxGripObjectTrackerKey_IncludeLeadingFilters];
	if ([leading isKindOfClass:NSNumber.class]) {
		data.includeLeadingFilters = leading.boolValue;
	}
	NSNumber *enabled = declared[kFxGripObjectTrackerKey_Enabled];
	if ([enabled isKindOfClass:NSNumber.class]) {
		data.enabled = enabled.boolValue;
	}
	NSString *label = declared[kFxGripObjectTrackerKey_Label];
	if ([label isKindOfClass:NSString.class]) {
		data.label = label;
	}
	NSArray *box = declared[kFxGripObjectTrackerKey_InitialBox];
	if ([box isKindOfClass:NSArray.class] && box.count == 4) {
		data.initialBox = CGRectMake([box[0] doubleValue], [box[1] doubleValue],
									 [box[2] doubleValue], [box[3] doubleValue]);
	}
	NSNumber *lowerLeft = declared[kFxGripObjectTrackerKey_LowerLeftParameterID];
	if ([lowerLeft isKindOfClass:NSNumber.class]) {
		data.lowerLeftParameterID = lowerLeft.integerValue;
	}
	NSNumber *upperRight = declared[kFxGripObjectTrackerKey_UpperRightParameterID];
	if ([upperRight isKindOfClass:NSNumber.class]) {
		data.upperRightParameterID = upperRight.integerValue;
	}
	NSNumber *center = declared[kFxGripObjectTrackerKey_CenterParameterID];
	if ([center isKindOfClass:NSNumber.class]) {
		data.centerParameterID = center.integerValue;
	}
	NSArray *anchors = declared[kFxGripObjectTrackerKey_AnchorParameterIDs];
	if ([anchors isKindOfClass:NSArray.class]) {
		data.anchorParameterIDs = anchors;
	}
	NSNumber *angle = declared[kFxGripObjectTrackerKey_AngleParameterID];
	if ([angle isKindOfClass:NSNumber.class]) {
		data.angleParameterID = angle.integerValue;
	}
	return data;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Adds the object tracker as a custom parameter to the effect.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default value is built from the declared
				configuration, and the custom-UI flag is set so the inspector shows the options view. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	FxGripObjectTrackerData *defaultValue =
		[self trackerDataFromDeclared:parameter.parameterDefaultValue];

	// The inspector shows the options view; the value persists so the track saves and presets.
	FxParameterFlags flags = parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI;

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: parameter.parameterName
					   parameterID: parameter.parameterID
					  defaultValue: defaultValue
					parameterFlags: flags];
}

- (NSView *)newParameterView
{
	FxGripObjectTrackerView *view = [[FxGripObjectTrackerView alloc] initWithFrame:NSMakeRect(0, 0, 240, 134)];
	view.parameterEffect = self.effect;
	view.parameterID = self.parameterID;
	// The host pushes the live value after attaching; seed from the declared configuration.
	[view updateFromCustomData:[self.class trackerDataFromDeclared:_data.parameterDefaultValue]];
	return view;
}

#pragma mark Analysis-pass driving

- (FxGripObjectTrackerData *)currentTrackerData
{
	id value = [self valueAtTime:kCMTimeZero];
	if ([value isKindOfClass:FxGripObjectTrackerData.class]) {
		return (FxGripObjectTrackerData *)value;
	}
	return [[FxGripObjectTrackerData alloc] init];
}

- (void)beginObjectTrackingAnalysis
{
	[self beginObjectTrackingAnalysisWithFrameDuration:kCMTimeInvalid];
}

/*!
	@method		beginObjectTrackingAnalysisWithFrameDuration:
	@abstract	Arms a fresh tracker for a pass and records the frame duration for keyframing.
	@discussion	Introduced in FxGrip 0.1.0. The working data copies the current value with its
				samples cleared, the seed box is read from the linked corners, and the tracker
				tracks rotation when the shape is a quadrilateral. */
- (void)beginObjectTrackingAnalysisWithFrameDuration:(CMTime)frameDuration
{
	_analysisFrameDuration = frameDuration;
	_analysisWorkingData = [[self currentTrackerData] copy];
	[_analysisWorkingData removeAllSamples];
	[self seedInitialBoxFromLinkedCorners];
	_analysisAnchorInitials = [self readAnchorInitialPositions];
	_analysisTracker = [[FxGripObjectTracker alloc] initWithLevel:FxGripObjectTrackerLevelAccurate];
	_analysisTracker.tracksRotation = _analysisWorkingData.shape == FxGripObjectTrackerShapeQuadrilateral;
	_analysisNeedsSeed = YES;
}

// Each anchor's position at the start of the pass, so it can ride with the tracked box.
- (NSDictionary<NSNumber *, NSValue *> *)readAnchorInitialPositions
{
	NSMutableDictionary<NSNumber *, NSValue *> *initials = [NSMutableDictionary dictionary];
	id<FxParameterRetrievalAPI_v6> getter = self.effect.apiManager.paramGetAPIv6;
	for (NSNumber *anchor in _analysisWorkingData.anchorParameterIDs) {
		double x = 0.0, y = 0.0;
		if ([getter getXValue:&x YValue:&y fromParameter:(UInt32)anchor.integerValue atTime:kCMTimeZero]) {
			initials[anchor] = [NSValue valueWithPoint:NSMakePoint(x, y)];
		}
	}
	return initials;
}

// When both corner points are linked, the placed region is the on-screen control's two point
// parameters; the seed box is read from them so a control edit updates the next analysis.
- (void)seedInitialBoxFromLinkedCorners
{
	NSInteger lowerLeft = _analysisWorkingData.lowerLeftParameterID;
	NSInteger upperRight = _analysisWorkingData.upperRightParameterID;
	if (lowerLeft == 0 || upperRight == 0) {
		return;
	}
	id<FxParameterRetrievalAPI_v6> getter = self.effect.apiManager.paramGetAPIv6;
	double llx = 0.0, lly = 0.0, urx = 0.0, ury = 0.0;
	if ([getter getXValue:&llx YValue:&lly fromParameter:(UInt32)lowerLeft atTime:kCMTimeZero]
		&& [getter getXValue:&urx YValue:&ury fromParameter:(UInt32)upperRight atTime:kCMTimeZero]) {
		_analysisWorkingData.initialBox = CGRectMake(MIN(llx, urx), MIN(lly, ury),
													 fabs(urx - llx), fabs(ury - lly));
	}
}

/*!
	@method		analyzeObjectTrackingImage:atFrame:
	@abstract	Seeds on the first frame of the pass, then tracks each later frame.
	@discussion	Introduced in FxGrip 0.1.0. The first frame starts the tracker from the seed box
				and stores it as the seed sample. Each later frame stores the tracked sample. A
				disabled tracker or a nil image is ignored. */
- (void)analyzeObjectTrackingImage:(CIImage *)image atFrame:(NSInteger)frameIndex
{
	if (_analysisWorkingData == nil || !_analysisWorkingData.enabled || image == nil) {
		return;
	}
	CIImage *analysisImage = [self imageForAnalysis:image];
	if (_analysisNeedsSeed) {
		CGRect box = _analysisWorkingData.initialBox;
		[_analysisTracker startTrackingImage:analysisImage boundingBox:box error:NULL];
		[_analysisWorkingData setSample:[[FxGripObjectTrackerSample alloc] initWithBoundingBox:box confidence:1.0f]
								atFrame:frameIndex];
		_analysisNeedsSeed = NO;
		return;
	}
	FxGripObjectTrackerSample *sample = [_analysisTracker trackImage:analysisImage error:NULL];
	if (sample != nil) {
		[_analysisWorkingData setSample:sample atFrame:frameIndex];
	}
}

// Half resolution scales the frame down before Vision, which speeds tracking of high-
// resolution clips. The tracker's coordinates are normalized, so downscaling leaves the
// stored samples in the same space.
- (CIImage *)imageForAnalysis:(CIImage *)image
{
	if (_analysisWorkingData.resolution == FxGripObjectTrackerResolutionHalf) {
		return [image imageByApplyingTransform:CGAffineTransformMakeScale(0.5, 0.5)];
	}
	return image;
}

/*!
	@method		endObjectTrackingAnalysis
	@abstract	Writes the accumulated samples back into the value and releases the tracker.
	@discussion	Introduced in FxGrip 0.1.0. The working data becomes the parameter value, and the
				linked points are baked as keyframes before the tracker state is cleared. */
- (void)endObjectTrackingAnalysis
{
	if (_analysisWorkingData != nil) {
		[self setValue:_analysisWorkingData];
		[self publishLinkedPoints];
	}
	_analysisTracker = nil;
	_analysisWorkingData = nil;
	_analysisAnchorInitials = nil;
	_analysisNeedsSeed = NO;
}

// Bakes the tracked center and anchor points as keyframes across the analyzed frames. The
// corner points are the manual region and are left untouched. Requires a valid frame duration
// to place the keyframes in time.
- (void)publishLinkedPoints
{
	if (!CMTIME_IS_VALID(_analysisFrameDuration)) {
		return;
	}
	NSInteger centerID = _analysisWorkingData.centerParameterID;
	NSInteger angleID = _analysisWorkingData.angleParameterID;
	NSArray<NSNumber *> *anchors = _analysisWorkingData.anchorParameterIDs;
	if (centerID == 0 && angleID == 0 && anchors.count == 0) {
		return;
	}
	NSInteger seedFrame = _analysisWorkingData.seedFrame;
	id<FxParameterSettingAPI_v5> setter = self.effect.apiManager.paramSetAPIv5;

	for (NSNumber *frameNumber in _analysisWorkingData.sampleFrameIndexes) {
		NSInteger frame = frameNumber.integerValue;
		CMTime time = CMTimeMultiply(_analysisFrameDuration, (int32_t)frame);

		if (angleID != 0) {
			FxGripObjectTrackerTransform transform = {0};
			if ([_analysisWorkingData transform:&transform atFrame:frame]) {
				[setter setFloatValue:transform.rotation * 180.0 / M_PI toParameter:(UInt32)angleID atTime:time];
			}
		}
		if (centerID != 0) {
			CGPoint center = CGPointZero;
			if ([_analysisWorkingData cornerBoxAtFrame:frame lowerLeft:NULL upperRight:NULL center:&center]) {
				[setter setXValue:center.x YValue:center.y toParameter:(UInt32)centerID atTime:time];
			}
		}
		for (NSNumber *anchor in anchors) {
			NSValue *initial = _analysisAnchorInitials[anchor];
			if (initial == nil) {
				continue;
			}
			NSPoint start = initial.pointValue;
			CGPoint out = CGPointZero;
			if ([_analysisWorkingData anchorPointAtFrame:frame
										  initialAnchor:CGPointMake(start.x, start.y)
											  seedFrame:seedFrame
											   outPoint:&out]) {
				[setter setXValue:out.x YValue:out.y toParameter:(UInt32)anchor.integerValue atTime:time];
			}
		}
	}
}

/*!
	@method		transform:atFrame:
	@abstract	Resolves the tracked transform at a frame from the stored value.
	@return		YES when the value is tracker data with a sample at or before the frame; NO otherwise.
	@discussion	Introduced in FxGrip 0.1.0. The resolution holds the last result forward across gaps. */
- (BOOL)transform:(FxGripObjectTrackerTransform *)outTransform atFrame:(NSInteger)frameIndex
{
	id value = [self valueAtTime:kCMTimeZero];
	if (![value isKindOfClass:FxGripObjectTrackerData.class]) {
		return NO;
	}
	return [(FxGripObjectTrackerData *)value transform:outTransform atFrame:frameIndex];
}

@end
