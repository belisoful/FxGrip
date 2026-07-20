/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  NSMutableDictionary-Extension.swift
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#import <objc/runtime.h>
#import "GuruFxTileableEffect+Parameters.h"
#import "GuruFxTileableEffect+Extensions.h"
#import "NSDictionary+FxTileableEffect.h"

#import "GuruFxAllParameters.h"

@implementation GuruFxTileableEffect (FxAnalyzer)


- (BOOL)desiredAnalysisTimeRange:(CMTimeRange *)desiredRange
		   forInputWithTimeRange:(CMTimeRange)inputTimeRange
						   error:(NSError **)error
{
	// Whatever the host app has, we want to analyze
	*desiredRange = inputTimeRange;
	return YES;
}


- (BOOL)setupAnalysisForTimeRange:(CMTimeRange)analysisRange
					frameDuration:(CMTime)frameDuration
							error:(NSError**)error
{
	BOOL result = YES;
	/*
	id<FxParameterRetrievalAPI_v7> getParamAPI = [_apiManager apiForProtocol:@protocol(FxParameterRetrievalAPI_v7)];
	if (getParamAPI == nil)
	{
		if (error != NULL)
		{
			*error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxError_APIUnavailable
									 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to retrieve the FxParameterRetrievalAPI_v7 in -setupAnalysisForTimeRange:::" }];
		}
	}
	BOOL backwardsAnalysis = NO;
	[getParamAPI getBoolValue:&backwardsAnalysis fromParameter:kParam_Backwards atTime:kCMTimeZero];
	
	[analysisLock lock];
	{
		startFrameTime = analysisRange.start;
		analysisFrameDuration = frameDuration;
		
		if (analyzedData != NULL)
		{
			free(analyzedData);
			analyzedData = NULL;
		}
		
		double numFrames = ceil(CMTimeGetSeconds(analysisRange.duration) / CMTimeGetSeconds(frameDuration));
		totalFramesToAnalyze = ceil(numFrames);
		analyzedData = malloc(sizeof(*analyzedData) * (size_t)numFrames);
		if (backwardsAnalysis)
		{
			nextAnalyzedFrameNum = numFrames - 1;
		}
		else
		{
			nextAnalyzedFrameNum = 0;
		}
	}
	[analysisLock unlock];
	*/
	return result;
}

- (BOOL)analyzeFrame:(FxImageTile *)frame
			  atTime:(CMTime)frameTime
			   error:(NSError **)error
{/*
	id<FxParameterRetrievalAPI_v7> getParamAPI = [_apiManager apiForProtocol:@protocol(FxParameterRetrievalAPI_v7)];
	if (getParamAPI == nil)
	{
		if (error != NULL)
		{
			*error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxError_APIUnavailable
									 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to retrieve the FxParameterRetrievalAPI_v7 in -setupAnalysisForTimeRange:::" }];
		}
		return NO;
	}
	
	int location = kParamLocation_CPU;
	[getParamAPI getIntValue:&location fromParameter:kParam_Location atTime:kCMTimeZero];
	
	if ((location == kParamLocation_CPU && frame.ioSurface.pixelFormat != kCVPixelFormatType_128RGBAFloat) ||
		(location == kParamLocation_GPU && frame.ioSurface.pixelFormat != kCVPixelFormatType_64RGBAHalf))
	{
		if (error != nil)
		{
			*error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxError_AnalysisError
									 userInfo:@{ NSLocalizedDescriptionKey : @"Invalid bit depth for analysis data" }];
		}
		return NO;
	}
	
	// Calculate the average brightness of the next frames
	double averageLuminance = 0;
	NSInteger   width   = frame.ioSurface.width;
	NSInteger   height  = frame.ioSurface.height;
	
	[frame.ioSurface lockWithOptions:kIOSurfaceLockReadOnly
								seed:nil];
	if (location == kParamLocation_CPU)
	{
		NSUInteger  rowBytes= frame.ioSurface.bytesPerRow;
		float*      pixels  = frame.ioSurface.baseAddress;
		for (NSInteger row = 0; row < height; row++)
		{
			float*  nextPixel = (float*)((UInt8*)pixels + (row * rowBytes));
			for (NSInteger col = 0; col < width; col++)
			{
				double  red = *nextPixel;
				nextPixel++;
				double  green = *nextPixel;
				nextPixel++;
				double  blue = *nextPixel;
				nextPixel++;
				nextPixel++; // skip alpha
				
				double luminance = luminanceRed * red + luminanceGreen * green + luminanceBlue * blue;
				averageLuminance += luminance;
			}
		}
		averageLuminance /= (double)width * (double)height;
	}
	else // GPU
	{
		CGRect bounds = { 0, 0, width, height };
		// Set up the CI renderer.
		CIContext* context = [CIContext contextWithOptions:@{kCIContextCacheIntermediates : @(NO)}];
		CIImage* sourceCIImage = [CIImage imageWithIOSurface:(IOSurfaceRef)(frame.ioSurface)];
		CIFilter* gammaAdjust = [CIFilter filterWithName:@"CIGammaAdjust"];
		[gammaAdjust setValue:sourceCIImage forKey:kCIInputImageKey];
		[gammaAdjust setValue:@1.1 forKey:@"inputPower"];

		// Process with CI average Filter
		CIFilter* areaAverage = [CIFilter filterWithName:@"CIAreaAverage"];
		[areaAverage setValue:gammaAdjust.outputImage forKey:kCIInputImageKey];
		[areaAverage setValue:[CIVector vectorWithCGRect:bounds] forKey:kCIInputExtentKey];
		  
		// Sample the average result (1 pixel in size)
		CGRect singlePixel = {0, 0, 1, 1};
		CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		CGImageRef averageCGImage = [context createCGImage:areaAverage.outputImage
												  fromRect:singlePixel
													format:kCIFormatRGBA8
												colorSpace:colorSpace];
		UInt8 * color = (UInt8 *) CFDataGetBytePtr(CGDataProviderCopyData(CGImageGetDataProvider(averageCGImage)));
		averageLuminance = (luminanceRed * (double)color[0] + luminanceGreen * (double)color[1] + luminanceBlue * (double)color[2]) / 255.0;
		}
	
	
	[frame.ioSurface unlockWithOptions:kIOSurfaceLockReadOnly
								  seed:nil];
	
	
	BOOL backwardsAnalysis = NO;
	[getParamAPI getBoolValue:&backwardsAnalysis fromParameter:kParam_Backwards atTime:kCMTimeZero];

	[analysisLock lock];

	// Add our analysis data to the array
	analyzedData [ nextAnalyzedFrameNum ].frameTime = frameTime;
	analyzedData [ nextAnalyzedFrameNum ].averageLuminance = averageLuminance;
	if (backwardsAnalysis)
	{
		nextAnalyzedFrameNum--;
	}
	else
	{
		nextAnalyzedFrameNum++;
	}
	
	// Attempt to save partial data. If it fails, don't worry because we'll save it all at the end
	// Also, don't save on every frame, as it slows down the analysis too much. Save every 10th
	// frame instead
	if ((nextAnalyzedFrameNum % 10) == 0)
	{
		if (![self saveAnalyzedData:nil])
		{
			NSLog (@"Unable to save partial analysis data");
		}
	}
	
	[analysisLock unlock];
	*/
	return YES;
}

- (BOOL)saveAnalyzedData:(NSError**)error
{
	BOOL result = NO;
	/*
	id<FxParameterSettingAPI_v5>    paramAPI    = [_apiManager apiForProtocol:@protocol(FxParameterSettingAPI_v5)];
	if (paramAPI != nil)
	{
		NSData* analysisData    = [NSData dataWithBytes:analyzedData
												 length:totalFramesToAnalyze * sizeof (*analyzedData)];
		NSDictionary*   paramData   = [NSDictionary dictionaryWithObjectsAndKeys:
									   [(NSDictionary*)CMTimeCopyAsDictionary(analysisFrameDuration, kCFAllocatorDefault) autorelease], kKey_FrameDuration,
									   analysisData, kKey_AnalysisData,
									   [NSNumber numberWithInteger:nextAnalyzedFrameNum], kKey_NumAnalyzedFrames,
									   nil];

		[paramAPI setCustomParameterValue:paramData
							  toParameter:kParam_AnalysisData
								   atTime:kCMTimeZero];

		result = YES;
	}
	else
	{
		if (error != NULL)
		{
			*error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxError_APIUnavailable
									 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to retrieve the FxParameterSettingAPI_v5 in -saveAnalyzedData:" }];
		}
	}
	*/
	return result;
}

- (BOOL)cleanupAnalysis:(NSError **)error
{
	// Update our parameters
	BOOL    result  = NO;
	/*
	[analysisLock lock];
	{
		[self saveAnalyzedData:error];
		free(analyzedData);
		analyzedData = NULL;
		result = YES;
	}
	[analysisLock unlock];
	 */
	
	return result;
}

/*
 triggering an analysis with a button calling this

FxAnalysisState currentState = [analysisAPI analysisStateForEffect];
if ((currentState != kFxAnalysisState_AnalysisStarted) && (currentState != kFxAnalysisState_AnalysisRequested))
{
	NSError* err = nil;
	if (backwardsAnalysis)
	{
		if (!useImageWell)
		{
			if (![analysisAPI startBackwardAnalysis:location
											  error:&err])
			{
				NSLog (@"Analysis failed to start due to error: %@", err);
			}
		}
		else
		{
			if (![analysisAPI startBackwardAnalysis:location
										ofParameter:kParam_ImageWell
											  error:&err])
			{
				NSLog (@"Analysis of image well failed to start due to error: %@", err);
			}
		}
	}
	else // Forward analysis
	{
		if (!useImageWell)
		{
			if (![analysisAPI startForwardAnalysis:location
											 error:&err])
			{
				NSLog (@"Analysis failed to start due to error: %@", err);
			}
		}
		else
		{
			if (![analysisAPI startForwardAnalysis:location
									   ofParameter:kParam_ImageWell
											 error:&err])
			{
				NSLog (@"Analysis of image well failed to start due to error: %@", err);
			}
		}
	}
}
 */


@end


