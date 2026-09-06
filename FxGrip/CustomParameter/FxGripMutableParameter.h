/*!
	@file       FxGripMutableParameter.h
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMutableParameter
	@abstract   Protocol a custom parameter value adopts to answer the standard typed get and set API.
	@discussion Introduced in FxGrip 0.1.0. FxGrip routes the host's typed parameter accessors, such as
	            getIntValue: and setIntValue:, to the custom value when the value conforms to this
	            protocol. Every method is optional, so a value implements only the types it represents.
	            A getter returns YES when it supplies a value and NO when it does not. A setter returns
	            YES when it accepts the value.
*/

#ifndef FxGripMutableParameter_h
#define FxGripMutableParameter_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>

/*!
	@protocol	FxGripMutableParameter
	@abstract	Answers the host's typed parameter get and set API from a custom value.
	@discussion	Introduced in FxGrip 0.1.0. Each method is optional; a value implements the types it
				represents. Getters return YES on success; setters return YES when the value is accepted.
*/
// This is the protocol for Custom Data to hijack the standard api get/set bool, int, float, string, etc.
@protocol FxGripMutableParameter

@optional

/*! Reads the value as a boolean. */
- (BOOL)getBoolValue:(BOOL*)boolValue;
/*! Sets the value from a boolean. */
- (BOOL)setBoolValue:(BOOL)boolValue;

/*! Reads the value as a double. */
- (BOOL)getFloatValue:(double*)floatValue;
/*! Sets the value from a double. */
- (BOOL)setFloatValue:(double)floatValue;


/*! Reads the value as a font name. */
- (BOOL)getFontName:(NSString**)fontName;

/*! Fills a gradient sample buffer at the given depth. */
- (BOOL)getGradientSamples:(void *)samples
				numSamples:(NSUInteger)numSamples
					 depth:(FxDepth)sampleDepth;

/*! Reads a channel's black-in, black-out, white-in, white-out, and gamma. */
//bIn, bOut, wIn, wOut, & gamma for each RGBA
- (BOOL)getHistogramBlackIn:(double*)blackIn
				   blackOut:(double*)blackOut
					whiteIn:(double*)whiteIn
				   whiteOut:(double*)whiteOut
					  gamma:(double*)gamma
				 forChannel:(FxHistogramChannel)channel;
/*! Sets a channel's black-in, black-out, white-in, white-out, and gamma. */
- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel;

/*! Reads the value as an int. */
- (BOOL)getIntValue:(int*)intValue;
/*! Sets the value from an int. */
- (BOOL)setIntValue:(int)intValue;

/*! Reads the value as an FxPathID. */
- (BOOL)getPathID:(FxPathID*)pathID;
/*! Sets the value from an FxPathID. */
- (BOOL)setPathID:(FxPathID)pathID;

/*! Reads the value as red, green, blue, and alpha components. */
- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue
		 alphaValue:(double*)alpha;
/*! Sets the value from red, green, blue, and alpha components. */
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		 alphaValue:(double)alpha;

/*! Reads the value as red, green, and blue components. */
- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue;
/*! Sets the value from red, green, and blue components. */
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue;

/*! Reads the value as a string. */
- (BOOL)getStringParameterValue:(NSString**)string;
/*! Sets the value from a string. */
- (BOOL)setStringParameterValue:(NSString*)string;

/*! Reads the value as an x and y pair. */
- (BOOL)getXValue:(double*)x YValue:(double*)y;
/*! Sets the value from an x and y pair. */
- (BOOL)setXValue:(double)x YValue:(double)y;

@end

#endif
