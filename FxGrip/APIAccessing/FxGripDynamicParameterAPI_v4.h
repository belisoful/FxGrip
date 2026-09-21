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
	@method		setParameter:floatMinimum:
	@abstract	Sets a Float parameter's minimum, leaving its maximum unchanged.
	@param		parameterID		The parameter to change.
	@param		min				The lowest value the parameter accepts.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
			 floatMinimum:(double)min;

/*!
	@method		setParameter:floatMaximum:
	@abstract	Sets a Float parameter's maximum, leaving its minimum unchanged.
	@param		parameterID		The parameter to change.
	@param		max				The highest value the parameter accepts.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
			 floatMaximum:(double)max;

/*!
	@method		setParameter:floatMinimum:maximum:
	@abstract	Sets both edges of a Float parameter's value range.
	@param		parameterID		The parameter to change.
	@param		min				The lowest value the parameter accepts.
	@param		max				The highest value the parameter accepts.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
			 floatMinimum:(double)min
				  maximum:(double)max;

/*!
	@method		setParameter:floatSliderMinimum:
	@abstract	Sets the value at the left end of a Float parameter's slider track.
	@param		parameterID		The parameter to change.
	@param		sliderMin		The value at the left end of the track.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMinimum:(double)sliderMin;

/*!
	@method		setParameter:floatSliderMaximum:
	@abstract	Sets the value at the right end of a Float parameter's slider track.
	@param		parameterID		The parameter to change.
	@param		sliderMax		The value at the right end of the track.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMaximum:(double)sliderMax;

/*!
	@method		setParameter:floatSliderMinimum:sliderMaximum:
	@abstract	Sets both ends of a Float parameter's slider track.
	@param		parameterID		The parameter to change.
	@param		sliderMin		The value at the left end of the track.
	@param		sliderMax		The value at the right end of the track.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMinimum:(double)sliderMin
			sliderMaximum:(double)sliderMax;




// *****  Int Parameter settings
/*!
	@method		setParameter:intMinimum:
	@abstract	Sets an Int parameter's minimum, leaving its maximum unchanged.
	@param		parameterID		The parameter to change.
	@param		min				The lowest value the parameter accepts.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
			   intMinimum:(int)min;

/*!
	@method		setParameter:intMaximum:
	@abstract	Sets an Int parameter's maximum, leaving its minimum unchanged.
	@param		parameterID		The parameter to change.
	@param		max				The highest value the parameter accepts.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
			   intMaximum:(int)max;

/*!
	@method		setParameter:intMinimum:maximum:
	@abstract	Sets both edges of an Int parameter's value range.
	@param		parameterID		The parameter to change.
	@param		min				The lowest value the parameter accepts.
	@param		max				The highest value the parameter accepts.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
			   intMinimum:(int)min
				  maximum:(int)max;

/*!
	@method		setParameter:intSliderMinimum:
	@abstract	Sets the value at the left end of an Int parameter's slider track.
	@param		parameterID		The parameter to change.
	@param		sliderMin		The value at the left end of the track.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMinimum:(int)sliderMin;

/*!
	@method		setParameter:intSliderMaximum:
	@abstract	Sets the value at the right end of an Int parameter's slider track.
	@param		parameterID		The parameter to change.
	@param		sliderMax		The value at the right end of the track.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMaximum:(int)sliderMax;

/*!
	@method		setParameter:intSliderMinimum:sliderMaximum:
	@abstract	Sets both ends of an Int parameter's slider track.
	@param		parameterID		The parameter to change.
	@param		sliderMin		The value at the left end of the track.
	@param		sliderMax		The value at the right end of the track.
	@return		The error the host reported, or nil.
*/
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMinimum:(int)sliderMin
			sliderMaximum:(int)sliderMax;


/*!
	@method		parameterExists:
	@abstract	Answers whether the effect holds a parameter with an ID.
	@discussion	The search walks the host's parameter list by index, so the cost grows with the
				parameter count.
	@param		parameterID		The ID to look for.
	@return		YES when a parameter carries that ID.
*/
- (BOOL)parameterExists:(FxParameterId)parameterID;

/*!
	@method		parameterType:
	@abstract	The type of a parameter.
	@discussion	The type comes from FxGrip's notification observers rather than from the host,
				which vends no type query.
	@param		parameterID		The parameter to read.
	@return		The parameter's `FxParameterType`.
*/
- (FxParameterType)parameterType:(FxParameterId)parameterID;

/*!
	@method		allParameterIDs
	@abstract	The IDs of every parameter the effect holds, in host order.
	@return		The parameter IDs, boxed as `NSNumber`.
*/
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

#pragma mark Parameter queries

/*! Answers whether the effect holds a parameter with an ID, by walking the host's parameter list. */
- (BOOL)parameterExists:(FxParameterId)parameterID;

/*! The parameter's type, resolved through FxGrip's notification observers. */
- (FxParameterType)parameterType:(FxParameterId)parameterID;

/*! The IDs of every parameter the effect holds, in host order, boxed as `NSNumber`. */
- (NSArray<NSNumber*>*)allParameterIDs;

/*!
	@method		parameter:entries:
	@abstract	Reads a menu parameter's entry titles.
	@discussion	The host vends no menu query, so the entries come from FxGrip's notification
				observers. An observer fills them in response to the get-menu notification.
	@param		parameterID		The menu parameter to read.
	@param		entries			On return, the entry titles in menu order.
	@return		The error the host reported, or nil.
*/
- (NSError*)parameter:(FxParameterId)parameterID entries:(NSArray<NSString*>**)entries;

#pragma mark Parameter meta

/*!
	@method		metaCountFromParameter:
	@abstract	The number of meta entries a parameter carries.
	@param		parameterID		The parameter to read.
	@return		The entry count, or -1 when the effect carries no meta manager.
*/
- (SInt32)metaCountFromParameter:(FxParameterId)parameterID;

/*!
	@method		getMeta:fromParameter:
	@abstract	Reads a parameter's whole meta dictionary.
	@param		meta			On return, the parameter's meta.
	@param		parameterID		The parameter to read.
	@return		The error the host reported, a no-meta-manager error, or nil.
*/
- (NSError*)getMeta:(NSDictionary**)meta fromParameter:(FxParameterId)parameterID;

/*!
	@method		setMeta:toParameter:
	@abstract	Replaces a parameter's whole meta dictionary.
	@param		meta			The meta to store.
	@param		parameterID		The parameter to write.
	@return		The error the host reported, a no-meta-manager error, or nil.
*/
- (NSError*)setMeta:(NSDictionary*) meta   toParameter:(FxParameterId)parameterID;

/*!
	@method		getMetaKeys:fromParameter:
	@abstract	Reads the keys a parameter's meta carries.
	@param		keys			On return, the meta keys.
	@param		parameterID		The parameter to read.
	@return		The error the host reported, a no-meta-manager error, or nil.
*/
- (NSError*)getMetaKeys:(NSArray **)keys fromParameter:(FxParameterId)parameterID;

/*!
	@method		removeAllMeta:
	@abstract	Removes every meta entry from a parameter.
	@param		parameterID		The parameter to clear.
	@return		The error the host reported, a no-meta-manager error, or nil.
*/
- (NSError*)removeAllMeta:(FxParameterId)parameterID;

/*!
	@method		parameter:hasMetaKey:error:
	@abstract	Answers whether a parameter's meta carries a key.
	@param		parameterID		The parameter to read.
	@param		key				The meta key to look for.
	@param		error			On return, the reason the read failed.
	@return		YES when the key is present.
*/
- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString*)key error:(NSError**)error;

/*!
	@method		getMeta:forKey:fromParameter:
	@abstract	Reads one meta value from a parameter.
	@param		value			On return, the stored value.
	@param		key				The meta key to read.
	@param		parameterID		The parameter to read.
	@return		YES when the key was present and the value was read.
*/
- (BOOL)getMeta:(id<NSSecureCoding, NSCopying> *)value forKey:(NSString*)key fromParameter:(FxParameterId)parameterID;

/*!
	@method		setMeta:forKey:toParameter:
	@abstract	Writes one meta value to a parameter.
	@param		value			The value to store, which must support secure coding and copying.
	@param		key				The meta key to write.
	@param		parameterID		The parameter to write.
	@return		YES when the value was stored.
*/
- (BOOL)setMeta:(id<NSSecureCoding, NSCopying>) value forKey:(NSString*)key toParameter:(FxParameterId)parameterID;

/*!
	@method		removeMetaKey:fromParameter:
	@abstract	Removes one meta entry from a parameter.
	@param		key				The meta key to remove.
	@param		parameterID		The parameter to change.
	@return		YES when the key was present and was removed.
*/
- (BOOL)removeMetaKey:(NSString*)key fromParameter:(FxParameterId)parameterID;

#pragma mark Single-edge bounds

/*! Sets a Float parameter's minimum, leaving its maximum unchanged. */
- (NSError *)setParameter:(UInt32)parameterID
			 floatMinimum:(double)min;
/*! Sets a Float parameter's maximum, leaving its minimum unchanged. */
- (NSError *)setParameter:(UInt32)parameterID
			 floatMaximum:(double)max;
/*! Sets both edges of a Float parameter's value range. */
- (NSError *)setParameter:(UInt32)parameterID
			 floatMinimum:(double)min
				  maximum:(double)max;
/*! Sets the value at the left end of a Float parameter's slider track. */
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMinimum:(double)sliderMin;
/*! Sets the value at the right end of a Float parameter's slider track. */
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMaximum:(double)sliderMax;
/*! Sets both ends of a Float parameter's slider track. */
- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMinimum:(double)sliderMin
			sliderMaximum:(double)sliderMax;

/*! Sets an Int parameter's minimum, leaving its maximum unchanged. */
- (NSError *)setParameter:(UInt32)parameterID
			   intMinimum:(int)min;
/*! Sets an Int parameter's maximum, leaving its minimum unchanged. */
- (NSError *)setParameter:(UInt32)parameterID
			   intMaximum:(int)max;
/*! Sets both edges of an Int parameter's value range. */
- (NSError *)setParameter:(UInt32)parameterID
			   intMinimum:(int)min
				  maximum:(int)max;
/*! Sets the value at the left end of an Int parameter's slider track. */
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMinimum:(int)sliderMin;
/*! Sets the value at the right end of an Int parameter's slider track. */
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMaximum:(int)sliderMax;
/*! Sets both ends of an Int parameter's slider track. */
- (NSError *)setParameter:(UInt32)parameterID
		 intSliderMinimum:(int)sliderMin
			sliderMaximum:(int)sliderMax;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

