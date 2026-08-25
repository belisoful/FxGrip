//
//  FxHueSaturation.h
//  PlugIn
//
//  Created by Apple on 10/22/18.
//  Copyright © 2019-2023 Apple Inc. All rights reserved.
//

#ifndef FxGripSectionData_h
#define FxGripSectionData_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxCustomDataClasses.h"
#import "FxGripMutableParameter.h"


/*!
	@class      FxGripInterpolatingDictionary
	@discussion This class is a NSMutableDictionary for Custom Values of a Custom Parameter.
				This can hold multiple different values and data.  It will interpolate between values that it knows how to interpolate
 				and copy everything else.  There is an array for keys that are exempt from interpolation.
 				The various Types of FxPlug data can be set without needing to regard translation through NSNumber.
				This also feeds various custom values to the Standard FxParameterRetrievalAPI-v6.
 */
@interface FxGripSectionData : NSObject <NSSecureCoding, NSCopying, FxGripMutableParameter, FxCustomDataClasses>

	// transform (none upper lower cap), alignment, font, weight, width, size, margin over, margin below, rgba


	@property (strong, readonly)  NSMutableDictionary*  data;

	// Keys that are exempt from interpolation
	// Found at key kCustomAPI_ExemptKeysKey @"exemptKeys"
	@property (assign, readonly)  NSMutableArray*  exemptKeys;

	// This specifies if new parameters can be set from the standard interface
	@property (assign, readonly)  BOOL isLocked;
	@property (assign, getter=isLocked)  BOOL locked;

- (instancetype)init;
- (instancetype)initWithDictionary:(NSDictionary*)dictionary;

//- (id)customInterpolateValue:(id)left rightValue:(id)right path:(NSString*)path withWeight:(float)weight;

- (BOOL)getBoolValue:(BOOL*)boolValue
			  forKey:(id<NSCopying>)aKey;
- (BOOL)setBoolValue:(BOOL)boolValue
			  forKey:(id<NSCopying>)aKey;

- (BOOL)getFloatValue:(double*)boolValue
			   forKey:(id<NSCopying>)aKey;
- (BOOL)setFloatValue:(double)floatValue
			   forKey:(id<NSCopying>)aKey;

//bIn, bOut, wIn, wOut, & gamma for each RGBA
- (BOOL)getHistogramBlackIn:(double*)blackIn
				   blackOut:(double*)blackOut
					whiteIn:(double*)whiteIn
				   whiteOut:(double*)whiteOut
					  gamma:(double*)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>)aKey;
- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>)aKey;

- (BOOL)getIntValue:(int*)intValue
			 forKey:(id<NSCopying>)aKey;
- (BOOL)setIntValue:(int)intValue
			 forKey:(id<NSCopying>)aKey;

- (BOOL)getPathID:(FxPathID*)pathID
			 forKey:(id<NSCopying>)aKey;
- (BOOL)setPathID:(FxPathID)pathID
			 forKey:(id<NSCopying>)aKey;

- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue
		 alphaValue:(double*)alpha
			 forKey:(id<NSCopying>)aKey;
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		 alphaValue:(double)alpha
			 forKey:(id<NSCopying>)aKey;

- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue
			 forKey:(id<NSCopying>)aKey;
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
			 forKey:(id<NSCopying>)aKey;

- (BOOL)getStringParameterValue:(NSString**)string
						 forKey:(id<NSCopying>)aKey;
- (BOOL)setStringParameterValue:(NSString*)string
						 forKey:(id<NSCopying>)aKey;

- (BOOL)getXValue:(double*)x
		   YValue:(double*)y
		   forKey:(id<NSCopying>)aKey;
- (BOOL)setXValue:(double)x
		   YValue:(double)y
		   forKey:(id<NSCopying>)aKey;


@end

#endif
