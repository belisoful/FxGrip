/*!
	@file       FxGripDynamicParameterAPI_v4.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDynamicParameterAPI_v4
	@abstract   FxGrip additions to the dynamic-parameter API for existence, type, single-edge
	            bounds, and per-parameter metadata.
	@discussion Introduced in FxGrip 0.1.0. The API extends FxDynamicParameterAPI_v3 with checks for
	            a parameter's existence and type, single-edge value and slider bounds setters, and
	            metadata storage. The single-edge setters and the metadata methods now have their
	            own APIs, FxGripParameterBoundsAPI_v1 and FxGripMetaAPI_v1, so FxGrip does not extend
	            Apple's dynamic-parameter protocol.
*/

#ifndef FxGripDynamicParameterAPI_v4_h
#define FxGripDynamicParameterAPI_v4_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripDynamicParameterAPI_v3.h>

//types todo
//'button' exposes more of the NSButton like a separate title from the parameter name
// and an an icon or image, state based (normal, toggle?)
#define kParameterType_Button		@"button"

// similar options for many options on one button
#define kParameterType_Capsule		@"capsule"

// a one line string input
#define kParameterType_StringLine	@"stringline"

// a banner image, size, url, help url, about url,
#define kParameterType_Banner		@"banner"

//preset menu, presets in plugin plist or media folder. save/load.
#define kParameterType_Presets		@"presets"

// shows stylized text
#define kParameterType_Section		@"section"

// menu or bar of links
#define kParameterType_Links		@"links"

// an integer input with refresh icon
#define kParameterType_Random		@"random"

//
#define kParameterType_Indicator	@"indicator"

// progress, style bar or circles
#define kParameterType_Progress		@"progress"

// menu with sub-menu, global selector, item selector
// long term
#define kParameterType_MenuAdvanced			@"xmenu"

#define kFxParameterId_Minimum		1
#define kFxParameterId_Maximum		9998

#pragma mark -

/*!
	@protocol	FxGripDynamicParameterAPI_v4
	@abstract	Adds existence, type, single-edge bounds, and metadata queries to the dynamic API.
	@discussion	Introduced in FxGrip 0.1.0. The plug-in checks whether a parameter exists by ID,
				reads a parameter's type, sets one edge of a Float or Int parameter's value or
				slider range, and reads or writes a parameter's metadata.
*/
@protocol FxGripDynamicParameterAPI_v4 <FxDynamicParameterAPI_v3>

// ***** Float Parameter settings
/*!
	@method     setParameter:floatMinimum
	@abstract   Set a Float parameter's Minimum
*/
- (NSError *)setParameter:(UInt32)parameterID
			 floatMinimum:(double)min;

/*!
	@method     setParameter:floatMaximum
	@abstract   Set a Float parameter's Maximum
*/
- (NSError *)setParameter:(UInt32)parameterID
			 floatMaximum:(double)max;

/*!
	@method     setParameter:floatMaximum:maximum
	@abstract   Set a Float parameter's Minimum and Maximum
*/
- (NSError *)setParameter:(UInt32)parameterID
			 floatMinimum:(double)min
				  maximum:(double)max;

/*!
@method     setParameter:floatSliderMinimum
@abstract   Set a Float parameter's slider minimum
*/
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMinimum:(double)sliderMin;

/*!
@method     setParameter:floatSliderMaximum
@abstract   Set a Float parameter's slider minimum
*/
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMaximum:(double)sliderMax;

/*!
@method     setParameter:floatSliderMinimum:sliderMaximum
@abstract   Set a Float parameter's slider minimum
*/
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMinimum:(double)sliderMin
			sliderMaximum:(double)sliderMax;




// *****  Int Parameter settings
/*!
	@method     setParameter:intMinimum
	@abstract   Set a Int parameter's Minimum
*/
- (NSError *)setParameter:(UInt32)parameterID
			   intMinimum:(int)min;

/*!
	@method     setParameter:intMaximum
	@abstract   Set a Int parameter's Maximum
*/
- (NSError *)setParameter:(UInt32)parameterID
			   intMaximum:(int)max;

/*!
	@method     setParameter:intMinimum:maximum
	@abstract   Set a Int parameter's Minimum and Maximum
*/
- (NSError *)setParameter:(UInt32)parameterID
			   intMinimum:(int)min
				  maximum:(int)max;

/*!
	@method     setParameter:intSliderMinimum
	@abstract   Set a Int parameter's slider Minimum
*/
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMinimum:(int)sliderMin;

/*!
	@method     setParameter:intSliderMaximum
	@abstract   Set a Int parameter's slider Minimum
*/
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMaximum:(int)sliderMax;

/*!
	@method     setParameter:intSliderMinimum:sliderMaximum
	@abstract   Set a Int parameter's slider Minimum
*/
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMinimum:(int)sliderMin
			sliderMaximum:(int)sliderMax;


// if a parameterId Exists
- (BOOL)parameterExists:(FxParameterId)parameterID;

// fills in the parameterId Type
- (FxParameterType)parameterType:(FxParameterId)parameterID;


- (NSArray<NSNumber*>*)allParameterIDs;

@end


#pragma mark -

/*!
	@class		FxGripDynamicParameterAPI_v4
	@abstract	FxGrip's implementation of FxGripDynamicParameterAPI_v4 over the v3 wrapper.
	@discussion	Introduced in FxGrip 0.1.0. Subclasses FxGripDynamicParameterAPI_v3 and adds the
				existence, type, menu-entry, single-edge bounds, and metadata methods. The bounds
				setters read the current range and write it back with one edge changed. The metadata
				methods forward to the host's meta manager.
*/

@interface FxGripDynamicParameterAPI_v4 : FxGripDynamicParameterAPI_v3 <FxGripDynamicParameterAPI_v4> {
}
// parameter

// if a parameterId Exists
- (BOOL)parameterExists:(FxParameterId)parameterID;

// fills in the parameterId Type
- (FxParameterType)parameterType:(FxParameterId)parameterID;

- (NSArray<NSNumber*>*)allParameterIDs;

// fills in the parameterId menu entries; entries come from the notification observers
- (NSError*)parameter:(FxParameterId)parameterID entries:(NSArray<NSString*>**)entries;

// Parameter Meta

- (SInt32)metaCountFromParameter:(FxParameterId)parameterID;
- (NSError*)getMeta:(NSDictionary**)meta fromParameter:(FxParameterId)parameterID;
- (NSError*)setMeta:(NSDictionary*) meta   toParameter:(FxParameterId)parameterID;
- (NSError*)getMetaKeys:(NSArray **)keys fromParameter:(FxParameterId)parameterID;
- (NSError*)removeAllMeta:(FxParameterId)parameterID;

- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString*)key error:(NSError**)error;
- (BOOL)getMeta:(id<NSSecureCoding, NSCopying> *)value forKey:(NSString*)key fromParameter:(FxParameterId)parameterID;
- (BOOL)setMeta:(id<NSSecureCoding, NSCopying>) value forKey:(NSString*)key toParameter:(FxParameterId)parameterID;
- (BOOL)removeMetaKey:(NSString*)key fromParameter:(FxParameterId)parameterID;


// Extension to Setting Parameter int/float values

- (NSError *)setParameter:(UInt32)parameterID
			 floatMinimum:(double)min;
- (NSError *)setParameter:(UInt32)parameterID
			 floatMaximum:(double)max;
- (NSError *)setParameter:(UInt32)parameterID
			 floatMinimum:(double)min
				  maximum:(double)max;
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMinimum:(double)sliderMin;
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMaximum:(double)sliderMax;
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMinimum:(double)sliderMin
			sliderMaximum:(double)sliderMax;

- (NSError *)setParameter:(UInt32)parameterID
			   intMinimum:(int)min;
- (NSError *)setParameter:(UInt32)parameterID
			   intMaximum:(int)max;
- (NSError *)setParameter:(UInt32)parameterID
			   intMinimum:(int)min
				  maximum:(int)max;
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMinimum:(int)sliderMin;
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMaximum:(int)sliderMax;
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMinimum:(int)sliderMin
			sliderMaximum:(int)sliderMax;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

