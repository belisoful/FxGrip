//
//  FxGripMutableParameter.h
//  PlugIn
//
//  Created by Apple on 10/22/18.
//  Copyright © 2019-2023 Apple Inc. All rights reserved.
//

#ifndef FxGripMutableParameter_h
#define FxGripMutableParameter_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>

// This is the protocol for Custom Data to hijack the standard api get/set bool, int, float, string, etc.
@protocol FxGripMutableParameter

@optional

- (BOOL)getBoolValue:(BOOL*)boolValue;
- (BOOL)setBoolValue:(BOOL)boolValue;

- (BOOL)getFloatValue:(double*)floatValue;
- (BOOL)setFloatValue:(double)floatValue;


- (BOOL)getFontName:(NSString**)fontName;

- (BOOL)getGradientSamples:(void *)samples
				numSamples:(NSUInteger)numSamples
					 depth:(FxDepth)sampleDepth;

//bIn, bOut, wIn, wOut, & gamma for each RGBA
- (BOOL)getHistogramBlackIn:(double*)blackIn
				   blackOut:(double*)blackOut
					whiteIn:(double*)whiteIn
				   whiteOut:(double*)whiteOut
					  gamma:(double*)gamma
				 forChannel:(FxHistogramChannel)channel;
- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel;

- (BOOL)getIntValue:(int*)intValue;
- (BOOL)setIntValue:(int)intValue;

- (BOOL)getPathID:(FxPathID*)pathID;
- (BOOL)setPathID:(FxPathID)pathID;

- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue
		 alphaValue:(double*)alpha;
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		 alphaValue:(double)alpha;

- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue;
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue;

- (BOOL)getStringParameterValue:(NSString**)string;
- (BOOL)setStringParameterValue:(NSString*)string;

- (BOOL)getXValue:(double*)x YValue:(double*)y;
- (BOOL)setXValue:(double)x YValue:(double)y;

@end

#endif
