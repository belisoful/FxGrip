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
#import <FxGrip/FxGripCustomDataClasses.h>
#import <FxGrip/FxGripMutableParameter.h>


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

	/*! The backing dictionary, which holds every typed value the section carries. */
	@property (strong, readonly)  NSMutableDictionary*  data;

	/*!
		@property	exemptKeys
		@abstract	The keys held out of interpolation.
		@discussion	Stored in `data` under `kCustomAPI_ExemptKeysKey`. A value at an exempt key is
					copied from the left side of an interpolation rather than blended.
	*/
	@property (assign, readonly)  NSMutableArray*  exemptKeys;

	/*!
		@property	isLocked
		@abstract	YES when the standard accessors refuse to introduce a new key.
		@discussion	A locked value still accepts a write to a key that is already set, so a
					declaration fixes the section's shape while leaving its values editable.
	*/
	@property (assign, readonly)  BOOL isLocked;

	/*! Locks and unlocks the value. See ``isLocked``. */
	@property (assign, getter=isLocked)  BOOL locked;

/*!
	@method		init
	@abstract	Creates an empty, unlocked section value.
	@return		The section value.
*/
- (instancetype)init;

/*!
	@method		initWithDictionary:
	@abstract	Creates a section value from a dictionary of typed values.
	@param		dictionary	The values to store, including any exempt-keys list.
	@return		The section value.
*/
- (instancetype)initWithDictionary:(NSDictionary*)dictionary;

/*!
	@method		getBoolValue:forKey:
	@abstract	Reads a boolean from the section.
	@param		boolValue	On return, the stored value.
	@param		aKey		The key to read.
	@return		YES when the key holds a boolean.
*/
- (BOOL)getBoolValue:(BOOL*)boolValue
			  forKey:(id<NSCopying>)aKey;

/*!
	@method		setBoolValue:forKey:
	@abstract	Writes a boolean into the section.
	@param		boolValue	The value to store.
	@param		aKey		The key to write.
	@return		YES when the write was accepted. A locked value refuses a key it does not hold.
*/
- (BOOL)setBoolValue:(BOOL)boolValue
			  forKey:(id<NSCopying>)aKey;

/*!
	@method		getFloatValue:forKey:
	@abstract	Reads a floating-point value from the section.
	@param		boolValue	On return, the stored value.
	@param		aKey		The key to read.
	@return		YES when the key holds a floating-point value.
*/
- (BOOL)getFloatValue:(double*)boolValue
			   forKey:(id<NSCopying>)aKey;

/*!
	@method		setFloatValue:forKey:
	@abstract	Writes a floating-point value into the section.
	@param		floatValue	The value to store.
	@param		aKey		The key to write.
	@return		YES when the write was accepted. A locked value refuses a key it does not hold.
*/
- (BOOL)setFloatValue:(double)floatValue
			   forKey:(id<NSCopying>)aKey;

/*!
	@method		getHistogramBlackIn:blackOut:whiteIn:whiteOut:gamma:forChannel:forKey:
	@abstract	Reads one channel of a histogram from the section.
	@param		blackIn		On return, the channel's black input level.
	@param		blackOut	On return, the channel's black output level.
	@param		whiteIn		On return, the channel's white input level.
	@param		whiteOut	On return, the channel's white output level.
	@param		gamma		On return, the channel's gamma.
	@param		channel		The channel to read.
	@param		aKey		The key to read.
	@return		YES when the key holds a histogram.
*/
- (BOOL)getHistogramBlackIn:(double*)blackIn
				   blackOut:(double*)blackOut
					whiteIn:(double*)whiteIn
				   whiteOut:(double*)whiteOut
					  gamma:(double*)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>)aKey;

/*!
	@method		setHistogramBlackIn:blackOut:whiteIn:whiteOut:gamma:forChannel:forKey:
	@abstract	Writes one channel of a histogram into the section.
	@param		blackIn		The channel's black input level.
	@param		blackOut	The channel's black output level.
	@param		whiteIn		The channel's white input level.
	@param		whiteOut	The channel's white output level.
	@param		gamma		The channel's gamma.
	@param		channel		The channel to write.
	@param		aKey		The key to write.
	@return		YES when the write was accepted. A locked value refuses a key it does not hold.
*/
- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>)aKey;

/*!
	@method		getIntValue:forKey:
	@abstract	Reads an integer from the section.
	@param		intValue	On return, the stored value.
	@param		aKey		The key to read.
	@return		YES when the key holds an integer.
*/
- (BOOL)getIntValue:(int*)intValue
			 forKey:(id<NSCopying>)aKey;

/*!
	@method		setIntValue:forKey:
	@abstract	Writes an integer into the section.
	@param		intValue	The value to store.
	@param		aKey		The key to write.
	@return		YES when the write was accepted. A locked value refuses a key it does not hold.
*/
- (BOOL)setIntValue:(int)intValue
			 forKey:(id<NSCopying>)aKey;

/*!
	@method		getPathID:forKey:
	@abstract	Reads a path ID from the section.
	@param		pathID		On return, the stored path ID.
	@param		aKey		The key to read.
	@return		YES when the key holds a path ID.
*/
- (BOOL)getPathID:(FxPathID*)pathID
			 forKey:(id<NSCopying>)aKey;

/*!
	@method		setPathID:forKey:
	@abstract	Writes a path ID into the section.
	@param		pathID		The path ID to store.
	@param		aKey		The key to write.
	@return		YES when the write was accepted. A locked value refuses a key it does not hold.
*/
- (BOOL)setPathID:(FxPathID)pathID
			 forKey:(id<NSCopying>)aKey;

/*!
	@method		getRedValue:greenValue:blueValue:alphaValue:forKey:
	@abstract	Reads an RGBA color from the section.
	@param		red			On return, the red component.
	@param		green		On return, the green component.
	@param		blue		On return, the blue component.
	@param		alpha		On return, the alpha component.
	@param		aKey		The key to read.
	@return		YES when the key holds an RGBA color.
*/
- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue
		 alphaValue:(double*)alpha
			 forKey:(id<NSCopying>)aKey;

/*!
	@method		setRedValue:greenValue:blueValue:alphaValue:forKey:
	@abstract	Writes an RGBA color into the section.
	@param		red			The red component.
	@param		green		The green component.
	@param		blue		The blue component.
	@param		alpha		The alpha component.
	@param		aKey		The key to write.
	@return		YES when the write was accepted. A locked value refuses a key it does not hold.
*/
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		 alphaValue:(double)alpha
			 forKey:(id<NSCopying>)aKey;

/*!
	@method		getRedValue:greenValue:blueValue:forKey:
	@abstract	Reads an RGB color from the section.
	@param		red			On return, the red component.
	@param		green		On return, the green component.
	@param		blue		On return, the blue component.
	@param		aKey		The key to read.
	@return		YES when the key holds an RGB color.
*/
- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue
			 forKey:(id<NSCopying>)aKey;

/*!
	@method		setRedValue:greenValue:blueValue:forKey:
	@abstract	Writes an RGB color into the section.
	@param		red			The red component.
	@param		green		The green component.
	@param		blue		The blue component.
	@param		aKey		The key to write.
	@return		YES when the write was accepted. A locked value refuses a key it does not hold.
*/
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
			 forKey:(id<NSCopying>)aKey;

/*!
	@method		getStringParameterValue:forKey:
	@abstract	Reads a string from the section.
	@param		string		On return, the stored string.
	@param		aKey		The key to read.
	@return		YES when the key holds a string.
*/
- (BOOL)getStringParameterValue:(NSString**)string
						 forKey:(id<NSCopying>)aKey;

/*!
	@method		setStringParameterValue:forKey:
	@abstract	Writes a string into the section.
	@param		string		The string to store.
	@param		aKey		The key to write.
	@return		YES when the write was accepted. A locked value refuses a key it does not hold.
*/
- (BOOL)setStringParameterValue:(NSString*)string
						 forKey:(id<NSCopying>)aKey;

/*!
	@method		getXValue:YValue:forKey:
	@abstract	Reads a point from the section.
	@param		x			On return, the X component.
	@param		y			On return, the Y component.
	@param		aKey		The key to read.
	@return		YES when the key holds a point.
*/
- (BOOL)getXValue:(double*)x
		   YValue:(double*)y
		   forKey:(id<NSCopying>)aKey;

/*!
	@method		setXValue:YValue:forKey:
	@abstract	Writes a point into the section.
	@param		x			The X component.
	@param		y			The Y component.
	@param		aKey		The key to write.
	@return		YES when the write was accepted. A locked value refuses a key it does not hold.
*/
- (BOOL)setXValue:(double)x
		   YValue:(double)y
		   forKey:(id<NSCopying>)aKey;


@end

#endif
