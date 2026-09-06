/*!
	@file       FxGripSectionData.h
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSectionData
	@abstract   The dictionary-backed custom value of a section parameter.
	@discussion Introduced in FxGrip 0.1.0. The value stores the section's configuration in a
	            mutable dictionary and exposes it through the FxParameterRetrievalAPI-v6 typed
	            accessors. A locked value accepts a standard-key write only for a key that is
	            already set. An exempt-keys list names the keys held out of interpolation.
*/

#ifndef FxGripSectionData_h
#define FxGripSectionData_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripCustomDataClasses.h"
#import "FxGripMutableParameter.h"


/*!
	@class		FxGripSectionData
	@abstract	The mutable-dictionary custom value of a section parameter.
	@discussion	Introduced in FxGrip 0.1.0. The value holds many typed FxPlug values in one
				dictionary and serves them through the standard custom-value accessors. Values
				that support interpolation interpolate; the rest are copied. Keys named in the
				exempt-keys list are held out of interpolation. A locked value accepts a
				standard-key write only when that key is already set.
*/
@interface FxGripSectionData : NSObject <NSSecureCoding, NSCopying, FxGripMutableParameter, FxGripCustomDataClasses>

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
