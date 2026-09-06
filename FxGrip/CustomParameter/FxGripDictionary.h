/*!
	@file       FxGripDictionary.h
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDictionary
	@abstract   A mutable dictionary custom parameter value that answers the host's typed parameter API.
	@discussion Introduced in FxGrip 0.1.0. The class stores a custom parameter's data as a keyed
	            dictionary and feeds that data to the standard typed accessors, such as
	            getIntValue:fromParameter: and setIntValue:toParameter:. Well-known keys map each
	            FxPlug type to its entry, so a plugin sets and reads bool, float, int, color, path,
	            string, and point values without translating through NSNumber. A lock flag restricts
	            the default typed setters to keys that already exist. The class conforms to
	            NSSecureCoding so the host persists the value.
*/

#ifndef FxGripDictionary_h
#define FxGripDictionary_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripCustomDataClasses.h"
#import "FxGripMutableParameter.h"

//These are keys that respond to the parameter Get__Value in the API for the parameter.
//	  FxGrip overrides the get/set to read these values when attempting to access the normal
//		parameter values.
//		eg. @"intValue" will give its value when the FxParameterRetrievalAPI_v6::getIntValue:fromParameter
//					is called on the custom parameter and will change its value in response to
//					FxParameterSettingAPI_v5::setIntValue:toParameter.
/*! The key for the boolean typed accessors. */
#define kCustomAPI_BoolKey @"boolValue"
/*! The key for the float typed accessors. */
#define kCustomAPI_FloatKey @"floatValue"
/*! The key for the histogram typed accessors. */
#define kCustomAPI_HistogramKey @"histogramValue"
/*! The key for the int typed accessors. */
#define kCustomAPI_IntKey @"intValue"
/*! The key for the RGBA color typed accessors. */
#define kCustomAPI_RGBAKey @"rgbaValue"
/*! The key for the RGB color typed accessors. */
#define kCustomAPI_RGBKey @"rgbValue"
/*! The key for the path-ID typed accessors. */
#define kCustomAPI_PathIDKey @"pathIdValue"
/*! The key for the string typed accessors. */
#define kCustomAPI_StringKey @"stringValue"
/*! The key for the x and y point typed accessors. */
#define kCustomAPI_PointKey @"xyValue"

/*! The key holding the name of the most recently changed entry. */
#define kCustomAPI_LastChangedKey @"__lastChangedKey"
/*! The key holding the lock flag; when locked, the default typed setters write only existing keys. */
#define kCustomAPI_IsLocked		 @"__locked"
/*! The key holding the array of keys exempt from interpolation. */
#define kCustomAPI_ExemptKeysKey @"exemptKeys"

/*!
	@class      FxGripDictionary
	@abstract	A mutable dictionary custom parameter value that answers the host's typed parameter API.
	@discussion This class is a NSMutableDictionary for Custom Values of a Custom Parameter. Introduced
				in FxGrip 0.1.0. It holds multiple values and data of different types. The various types
				of FxPlug data are set and read without translating through NSNumber. It feeds custom
				values to the standard FxParameterRetrievalAPI_v6. An array of keys is exempt from
				interpolation, which the interpolating subclass uses.
 */
@interface FxGripDictionary : NSMutableDictionary <FxGripMutableParameter, FxGripCustomDataClasses>

	/*! The backing store of keys and values. */
	@property (strong, readonly, nonnull)  NSMutableDictionary*  data;

	/*! The keys exempt from interpolation, stored under kCustomAPI_ExemptKeysKey. */
	// Keys that are exempt from interpolation
	// Found at key kCustomAPI_ExemptKeysKey @"exemptKeys"
	@property (assign, readonly, nonnull)  NSMutableArray*  exemptKeys;

	/*! YES restricts the default typed setters to keys that already exist. */
	// This specifies if new parameters can be set from the standard interface
	@property (assign, readonly)  BOOL isLocked;
	/*! The writable form of isLocked. */
	@property (assign, getter=isLocked)  BOOL locked;

- (instancetype _Null_unspecified)init;

/*! The secure-coding allow-list for values a parameter dictionary may carry. A subclass
	overrides to extend it; the instance method returns the class-level list. */
+ (NSOrderedSet<Class>*_Nonnull)classesForParameter;

//- (id)customInterpolateValue:(id)left rightValue:(id)right path:(NSString*)path withWeight:(float)weight;

// Each typed accessor has a forKey: variant that reads or writes an explicit key. The default
// typed accessors from FxGripMutableParameter call these with the type's well-known key.

/*! Reads the boolean at a key. */
- (BOOL)getBoolValue:(BOOL*_Null_unspecified)boolValue
			  forKey:(id<NSCopying>_Null_unspecified)aKey;
/*! Sets the boolean at a key. */
- (BOOL)setBoolValue:(BOOL)boolValue
			  forKey:(id<NSCopying>_Null_unspecified)aKey;

/*! Reads the double at a key. */
- (BOOL)getFloatValue:(double*_Null_unspecified)boolValue
			   forKey:(id<NSCopying>_Null_unspecified)aKey;
/*! Sets the double at a key. */
- (BOOL)setFloatValue:(double)floatValue
			   forKey:(id<NSCopying>_Null_unspecified)aKey;

/*! Reads a channel's histogram values at a key. */
//bIn, bOut, wIn, wOut, & gamma for each RGBA
- (BOOL)getHistogramBlackIn:(double*_Null_unspecified)blackIn
				   blackOut:(double*_Null_unspecified)blackOut
					whiteIn:(double*_Null_unspecified)whiteIn
				   whiteOut:(double*_Null_unspecified)whiteOut
					  gamma:(double*_Null_unspecified)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>_Null_unspecified)aKey;
/*! Sets a channel's histogram values at a key. */
- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>_Null_unspecified)aKey;

/*! Reads the int at a key. */
- (BOOL)getIntValue:(int*_Null_unspecified)intValue
			 forKey:(id<NSCopying>_Null_unspecified)aKey;
/*! Sets the int at a key. */
- (BOOL)setIntValue:(int)intValue
			 forKey:(id<NSCopying>_Null_unspecified)aKey;

/*! Reads the FxPathID at a key. */
- (BOOL)getPathID:(FxPathID _Null_unspecified *_Null_unspecified)pathID
			 forKey:(id<NSCopying>_Null_unspecified)aKey;
/*! Sets the FxPathID at a key. */
- (BOOL)setPathID:(FxPathID _Null_unspecified)pathID
			 forKey:(id<NSCopying>_Null_unspecified)aKey;

/*! Reads the RGBA color at a key. */
- (BOOL)getRedValue:(double*_Null_unspecified)red
		 greenValue:(double*_Null_unspecified)green
		  blueValue:(double*_Null_unspecified)blue
		 alphaValue:(double*_Null_unspecified)alpha
			 forKey:(id<NSCopying>_Null_unspecified)aKey;
/*! Sets the RGBA color at a key. */
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		 alphaValue:(double)alpha
			 forKey:(id<NSCopying>_Null_unspecified)aKey;

/*! Reads the RGB color at a key. */
- (BOOL)getRedValue:(double*_Null_unspecified)red
		 greenValue:(double*_Null_unspecified)green
		  blueValue:(double*_Null_unspecified)blue
			 forKey:(id<NSCopying>_Null_unspecified)aKey;
/*! Sets the RGB color at a key. */
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
			 forKey:(id<NSCopying>_Null_unspecified)aKey;

/*! Reads the string at a key. */
- (BOOL)getStringParameterValue:(NSString*_Null_unspecified *_Null_unspecified)string
						 forKey:(id<NSCopying>_Null_unspecified)aKey;
/*! Sets the string at a key. */
- (BOOL)setStringParameterValue:(NSString*_Null_unspecified)string
						 forKey:(id<NSCopying>_Null_unspecified)aKey;

/*! Reads the x and y point at a key. */
- (BOOL)getXValue:(double*_Null_unspecified)x
		   YValue:(double*_Null_unspecified)y
		   forKey:(id<NSCopying>_Null_unspecified)aKey;
/*! Sets the x and y point at a key. */
- (BOOL)setXValue:(double)x
		   YValue:(double)y
		   forKey:(id<NSCopying>_Null_unspecified)aKey;

// Fast enumeration derives from the dictionary primitives; no declaration is needed.

@end

#endif
