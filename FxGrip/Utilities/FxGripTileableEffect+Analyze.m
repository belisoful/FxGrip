/*!
	@file       FxGripTileableEffect+Analyze.m
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+Analyze
	@abstract   Implements the FxAnalyzer callbacks, per-frame storage, and object-tracker analysis.
	@discussion Introduced in FxGrip 0.1.0. The analysis pass computes a record for each frame
	            through the subclass hook, stores it at the frame's index in analysisData, and runs
	            every object-tracker parameter on the same frame. The frame duration is stored so a
	            time maps to the same frame index at analysis and at render. The utilities average a
	            tile's color and luminance through Core Image.
*/

#import "FxGripTileableEffect+Analyze.h"
#import "FxGripTileableEffect+Extensions.h"
#import "FxGripAnalysis.h"
#import "FxGripAPIAccessing.h"
#import "FxGripMTLDeviceCache.h"
#import "FxGripObjectTrackerParameter.h"
#import <CoreImage/CoreImage.h>

/*!
	@abstract	The category that implements the frame-analysis pass and its storage.
	@discussion	Introduced in FxGrip 0.1.0. The category answers the FxAnalyzer callbacks, stores
				each frame's record in analysisData, and drives object-tracker analysis.
*/
@implementation FxGripTileableEffect (Analyze)

#pragma mark FxAnalyzer

/*!
	@method		desiredAnalysisTimeRange:forInputWithTimeRange:error:
	@abstract	Reports the time range the analysis pass covers.
	@return		YES, requesting the whole input time range by default.
	@discussion	Introduced in FxGrip 0.1.0. A subclass narrows the range. */
- (BOOL)desiredAnalysisTimeRange:(CMTimeRange *)desiredRange
		   forInputWithTimeRange:(CMTimeRange)inputTimeRange
						   error:(NSError * _Nullable * _Nullable)error
{
	// Analyze the whole input by default; a subclass narrows the range.
	if (desiredRange != NULL) {
		*desiredRange = inputTimeRange;
	}
	return YES;
}

/*!
	@method		setupAnalysisForTimeRange:frameDuration:error:
	@abstract	Prepares the analysis pass and stores the frame duration with the frame data.
	@return		YES.
	@discussion	Introduced in FxGrip 0.1.0. The frame duration converts a time to an absolute frame
				index at analysis and at render, so it is stored in analysisData. The method also
				begins the object-tracker parameters' analysis. */
- (BOOL)setupAnalysisForTimeRange:(CMTimeRange)analysisRange
					frameDuration:(CMTime)frameDuration
							error:(NSError * _Nullable * _Nullable)error
{
	// The frame duration converts a time to an absolute frame index at analysis and at
	// render, so it is stored with the frame data.
	[self beginObjectTrackerAnalysisWithFrameDuration:frameDuration];

	FxGripFrameData *data = self.analysisData;
	if (data == nil) {
		return YES;
	}
	NSDictionary *durationDictionary =
		(NSDictionary *)CFBridgingRelease(CMTimeCopyAsDictionary(frameDuration, kCFAllocatorDefault));
	if (durationDictionary != nil) {
		[data setObject:durationDictionary forKey:kFxGripFrameDataKey_FrameDuration];
	}
	return YES;
}

/*!
	@method		analyzeFrame:atTime:error:
	@abstract	Analyzes one frame and stores the resulting record.
	@return		YES.
	@discussion	Introduced in FxGrip 0.1.0. The method calls the subclass hook for the frame's
				record, stores a non-nil record at the frame's index, and runs the object trackers
				on the same frame. */
- (BOOL)analyzeFrame:(FxImageTile *)frame
			  atTime:(CMTime)frameTime
			   error:(NSError * _Nullable * _Nullable)error
{
	NSInteger frameIndex = [self analysisFrameIndexForTime:frameTime];
	id<NSSecureCoding, NSCopying> record = [self analyzeImageTile:frame
														 atTime:frameTime
													 frameIndex:frameIndex
														  error:error];
	if (record != nil) {
		[self.analysisData setRecord:record atIndex:frameIndex];
	}
	[self analyzeObjectTrackersWithTile:frame atFrame:frameIndex];
	return YES;
}

/*!
	@method		cleanupAnalysis:
	@abstract	Ends the analysis pass and persists the analyzed data.
	@return		YES.
	@discussion	Introduced in FxGrip 0.1.0. The method ends object-tracker analysis and saves the
				frame data into its hidden parameter. */
- (BOOL)cleanupAnalysis:(NSError * _Nullable * _Nullable)error
{
	[self endObjectTrackerAnalysis];
	[self saveAnalysisData];
	return YES;
}

#pragma mark Hooks and readback

- (nullable id<NSSecureCoding, NSCopying>)analyzeImageTile:(FxImageTile *)frame
												  atTime:(CMTime)frameTime
											  frameIndex:(NSInteger)frameIndex
												   error:(NSError * _Nullable * _Nullable)error
{
	return nil;
}

- (NSInteger)analysisFrameIndexForTime:(CMTime)time
{
	NSDictionary *durationDictionary = (NSDictionary *)[self.analysisData objectForKey:kFxGripFrameDataKey_FrameDuration];
	if (![durationDictionary isKindOfClass:NSDictionary.class]) {
		return 0;
	}
	CMTime frameDuration = CMTimeMakeFromDictionary((__bridge CFDictionaryRef)durationDictionary);
	double durationSeconds = CMTIME_IS_VALID(frameDuration) ? CMTimeGetSeconds(frameDuration) : 0.0;
	if (durationSeconds <= 0.0) {
		return 0;
	}
	return (NSInteger)llround(CMTimeGetSeconds(time) / durationSeconds);
}

- (nullable id<NSSecureCoding, NSCopying>)analysisRecordAtTime:(CMTime)time
{
	return [self.analysisData latestRecordAtOrBefore:[self analysisFrameIndexForTime:time]];
}

/*! Persists the frame data into its hidden custom parameter through the parameter-set API. */
- (void)saveAnalysisData
{
	FxGripAnalysis *analysis = (FxGripAnalysis *)[self extensionForClass:FxGripAnalysis.class];
	if (analysis == nil) {
		return;
	}
	[self.apiManager.paramSetAPIv5 setCustomParameterValue:analysis.frameData
											   toParameter:analysis.parameterID
													atTime:kCMTimeZero];
}

#pragma mark Driving the analysis pass

- (FxAnalysisState)analysisState
{
	id<FxAnalysisAPI_v2> api = self.apiManager.analysisAPIv2;
	return api != nil ? [api analysisStateForEffect] : kFxAnalysisState_NotAnalyzing;
}

- (BOOL)startForwardAnalysisAtLocation:(FxAnalysisLocation)location error:(NSError * _Nullable * _Nullable)error
{
	id<FxAnalysisAPI_v2> api = self.apiManager.analysisAPIv2;
	return api != nil ? [api startForwardAnalysis:location error:error] : NO;
}

- (BOOL)startBackwardAnalysisAtLocation:(FxAnalysisLocation)location error:(NSError * _Nullable * _Nullable)error
{
	id<FxAnalysisAPI_v2> api = self.apiManager.analysisAPIv2;
	return api != nil ? [api startBackwardAnalysis:location error:error] : NO;
}

#pragma mark Utilities

/*!
	@method		averageColorOfImageTile:red:green:blue:alpha:
	@abstract	Computes the area-average RGBA of a frame tile.
	@return		YES when the tile has a readable surface; NO otherwise.
	@discussion	Introduced in FxGrip 0.1.0. The average is computed with Core Image's CIAreaAverage
				on the tile's IOSurface. Any output channel pointer may be nil. */
+ (BOOL)averageColorOfImageTile:(FxImageTile *)tile
						   red:(double *)red
						 green:(double *)green
						  blue:(double *)blue
						 alpha:(double *)alpha
{
	if (tile == nil) {
		return NO;
	}
	IOSurfaceRef surface = (__bridge IOSurfaceRef)tile.ioSurface;
	if (surface == NULL) {
		return NO;
	}
	CIImage *image = [CIImage imageWithIOSurface:surface];
	if (image == nil) {
		return NO;
	}
	CIFilter *average = [CIFilter filterWithName:@"CIAreaAverage"];
	[average setValue:image forKey:kCIInputImageKey];
	[average setValue:[CIVector vectorWithCGRect:image.extent] forKey:kCIInputExtentKey];
	CIImage *output = average.outputImage;
	if (output == nil) {
		return NO;
	}

	FxGripMTLDeviceCacheItem *device = [[FxGripMTLDeviceCache deviceCache] deviceWithRegistryID:tile.deviceRegistryID];
	CIContext *context = device.gpuDevice != nil ? [CIContext contextWithMTLDevice:device.gpuDevice] : [CIContext context];

	float pixel[4] = {0.0f, 0.0f, 0.0f, 0.0f};
	[context render:output
		   toBitmap:pixel
		   rowBytes:sizeof(pixel)
			 bounds:CGRectMake(0, 0, 1, 1)
			 format:kCIFormatRGBAf
		 colorSpace:nil];
	if (red != NULL) {
		*red = pixel[0];
	}
	if (green != NULL) {
		*green = pixel[1];
	}
	if (blue != NULL) {
		*blue = pixel[2];
	}
	if (alpha != NULL) {
		*alpha = pixel[3];
	}
	return YES;
}

+ (double)averageLuminanceOfImageTile:(FxImageTile *)tile
{
	double red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
	if (![self averageColorOfImageTile:tile red:&red green:&green blue:&blue alpha:&alpha]) {
		return 0.0;
	}
	return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
}

#pragma mark Object trackers

/*! The effect's object-tracker parameters. */
- (NSArray<FxGripObjectTrackerParameter *> *)objectTrackerParameters
{
	NSMutableArray<FxGripObjectTrackerParameter *> *trackers = [NSMutableArray array];
	for (id<FxGripParameter> parameter in self.parameters.allValues) {
		if ([parameter isKindOfClass:FxGripObjectTrackerParameter.class]) {
			[trackers addObject:(FxGripObjectTrackerParameter *)parameter];
		}
	}
	return trackers;
}

- (void)beginObjectTrackerAnalysisWithFrameDuration:(CMTime)frameDuration
{
	for (FxGripObjectTrackerParameter *tracker in [self objectTrackerParameters]) {
		[tracker beginObjectTrackingAnalysisWithFrameDuration:frameDuration];
	}
}

/*! Runs each object-tracker parameter on the frame's Core Image at the frame index. */
- (void)analyzeObjectTrackersWithTile:(FxImageTile *)tile atFrame:(NSInteger)frameIndex
{
	NSArray<FxGripObjectTrackerParameter *> *trackers = [self objectTrackerParameters];
	if (trackers.count == 0) {
		return;
	}
	IOSurfaceRef surface = (__bridge IOSurfaceRef)tile.ioSurface;
	if (surface == NULL) {
		return;
	}
	CIImage *image = [CIImage imageWithIOSurface:surface];
	if (image == nil) {
		return;
	}
	for (FxGripObjectTrackerParameter *tracker in trackers) {
		[tracker analyzeObjectTrackingImage:image atFrame:frameIndex];
	}
}

- (void)endObjectTrackerAnalysis
{
	for (FxGripObjectTrackerParameter *tracker in [self objectTrackerParameters]) {
		[tracker endObjectTrackingAnalysis];
	}
}

- (BOOL)objectTrackerTransform:(FxGripObjectTrackerTransform *)outTransform
				  forParameter:(FxParameterId)parameterID
						atTime:(CMTime)time
{
	id<FxGripParameter> parameter = self.parameters[@(parameterID)];
	if (![parameter isKindOfClass:FxGripObjectTrackerParameter.class]) {
		return NO;
	}
	NSInteger frameIndex = [self analysisFrameIndexForTime:time];
	return [(FxGripObjectTrackerParameter *)parameter transform:outTransform atFrame:frameIndex];
}

@end
