//
//  FxGripDictionary.h
//  PlugIn
//
//  Created by Apple on 10/22/18.
//  Copyright © 2019-2023 Apple Inc. All rights reserved.
//

#ifndef FxGripDictionary_h
#define FxGripDictionary_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxCustomDataClasses.h"
#import "FxGripMutableParameter.h"

//These are keys that respond to the parameter Get__Value in the API for the parameter.
//	  FxGrip overrides the get/set to read these values when attempting to access the normal
//		parameter values.
//		eg. @"intValue" will give its value when the FxParameterRetrievalAPI_v6::getIntValue:fromParameter
//					is called on the custom parameter and will change its value in response to
//					FxParameterSettingAPI_v5::setIntValue:toParameter.
#define kCustomAPI_BoolKey @"boolValue"
#define kCustomAPI_FloatKey @"floatValue"
#define kCustomAPI_HistogramKey @"histogramValue"
#define kCustomAPI_IntKey @"intValue"
#define kCustomAPI_RGBAKey @"rgbaValue"
#define kCustomAPI_RGBKey @"rgbValue"
#define kCustomAPI_PathIDKey @"pathIdValue"
#define kCustomAPI_StringKey @"stringValue"
#define kCustomAPI_PointKey @"xyValue"

#define kCustomAPI_LastChangedKey @"__lastChangedKey"
#define kCustomAPI_IsLocked		 @"__locked"
#define kCustomAPI_ExemptKeysKey @"exemptKeys"

/*!
	@class      FxGripInterpolatingDictionary
	@discussion This class is a NSMutableDictionary for Custom Values of a Custom Parameter.
				This can hold multiple different values and data.  It will interpolate between values that it knows how to interpolate
 				and copy everything else.  There is an array for keys that are exempt from interpolation.
 				The various Types of FxPlug data can be set without needing to regard translation through NSNumber.
				This also feeds various custom values to the Standard FxParameterRetrievalAPI-v6.
 */
@interface FxGripDictionary : NSMutableDictionary <FxGripMutableParameter, FxCustomDataClasses>

	@property (strong, readonly, nonnull)  NSMutableDictionary*  data;

	// Keys that are exempt from interpolation
	// Found at key kCustomAPI_ExemptKeysKey @"exemptKeys"
	@property (assign, readonly, nonnull)  NSMutableArray*  exemptKeys;

	// This specifies if new parameters can be set from the standard interface
	@property (assign, readonly)  BOOL isLocked;
	@property (assign, getter=isLocked)  BOOL locked;

- (instancetype _Null_unspecified)init;

//- (id)customInterpolateValue:(id)left rightValue:(id)right path:(NSString*)path withWeight:(float)weight;

- (BOOL)getBoolValue:(BOOL*_Null_unspecified)boolValue
			  forKey:(id<NSCopying>_Null_unspecified)aKey;
- (BOOL)setBoolValue:(BOOL)boolValue
			  forKey:(id<NSCopying>_Null_unspecified)aKey;

- (BOOL)getFloatValue:(double*_Null_unspecified)boolValue
			   forKey:(id<NSCopying>_Null_unspecified)aKey;
- (BOOL)setFloatValue:(double)floatValue
			   forKey:(id<NSCopying>_Null_unspecified)aKey;

//bIn, bOut, wIn, wOut, & gamma for each RGBA
- (BOOL)getHistogramBlackIn:(double*_Null_unspecified)blackIn
				   blackOut:(double*_Null_unspecified)blackOut
					whiteIn:(double*_Null_unspecified)whiteIn
				   whiteOut:(double*_Null_unspecified)whiteOut
					  gamma:(double*_Null_unspecified)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>_Null_unspecified)aKey;
- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>_Null_unspecified)aKey;

- (BOOL)getIntValue:(int*_Null_unspecified)intValue
			 forKey:(id<NSCopying>_Null_unspecified)aKey;
- (BOOL)setIntValue:(int)intValue
			 forKey:(id<NSCopying>_Null_unspecified)aKey;

- (BOOL)getPathID:(FxPathID _Null_unspecified *_Null_unspecified)pathID
			 forKey:(id<NSCopying>_Null_unspecified)aKey;
- (BOOL)setPathID:(FxPathID _Null_unspecified)pathID
			 forKey:(id<NSCopying>_Null_unspecified)aKey;

- (BOOL)getRedValue:(double*_Null_unspecified)red
		 greenValue:(double*_Null_unspecified)green
		  blueValue:(double*_Null_unspecified)blue
		 alphaValue:(double*_Null_unspecified)alpha
			 forKey:(id<NSCopying>_Null_unspecified)aKey;
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		 alphaValue:(double)alpha
			 forKey:(id<NSCopying>_Null_unspecified)aKey;

- (BOOL)getRedValue:(double*_Null_unspecified)red
		 greenValue:(double*_Null_unspecified)green
		  blueValue:(double*_Null_unspecified)blue
			 forKey:(id<NSCopying>_Null_unspecified)aKey;
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
			 forKey:(id<NSCopying>_Null_unspecified)aKey;

- (BOOL)getStringParameterValue:(NSString*_Null_unspecified *_Null_unspecified)string
						 forKey:(id<NSCopying>_Null_unspecified)aKey;
- (BOOL)setStringParameterValue:(NSString*_Null_unspecified)string
						 forKey:(id<NSCopying>_Null_unspecified)aKey;

- (BOOL)getXValue:(double*_Null_unspecified)x
		   YValue:(double*_Null_unspecified)y
		   forKey:(id<NSCopying>_Null_unspecified)aKey;
- (BOOL)setXValue:(double)x
		   YValue:(double)y
		   forKey:(id<NSCopying>_Null_unspecified)aKey;
- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *_Nonnull) enumerationState
								   objects: (id _Nonnull __unsafe_unretained [_Nullable]) stackBuffer
count: (NSUInteger) len;

@end

#endif
