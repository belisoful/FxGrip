//
//  FxGripTileableEffect+Analyze.m
//  FxGrip
//
//  Copyright © 2026 Belisoful All rights reserved.
//

#import "FxGripTileableEffect+Analyze.h"
#import "FxGripTileableEffect+Extensions.h"
#import "FxGripAnalysis.h"
#import "FxGripAPIAccessing.h"
#import "FxGripMTLDeviceCache.h"
#import <CoreImage/CoreImage.h>

@implementation FxGripTileableEffect (Analyze)

#pragma mark FxAnalyzer

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

- (BOOL)setupAnalysisForTimeRange:(CMTimeRange)analysisRange
					frameDuration:(CMTime)frameDuration
							error:(NSError * _Nullable * _Nullable)error
{
	// The frame duration converts a time to an absolute frame index at analysis and at
	// render, so it is stored with the frame data.
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
	return YES;
}

- (BOOL)cleanupAnalysis:(NSError * _Nullable * _Nullable)error
{
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

@end
