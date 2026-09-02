//
//  FxGripParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripParameter_h
#define FxGripParameter_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameterFlags.h"
#import "FxGripTypes.h"
#import "NSCoder+FxPlug.h"



// ********
//			These are parameters used by FxGrip
// This will activate the debug menu if it's been deactivated.  A parameter link rig
// can be used to turn the debug menu on and off.

#define kFxParameterId_AppleRootGroup		(0)
#define kFxParameterId_FxFactoryLicense		(9980)

//#define kFxParameterId_DebugActivator		(9995)
//#define kFxParameterId_DebugMenu			(9996)
//#define kFxParameterId_InstanceMeta			(9997)
//#define kFxParameterId_ParameterData		(9998)
//#define kFxParameterId_ApplePluginData	(9999)



// Forward declaration
@protocol FxGripTileableEffect;







@protocol _FxGripParameterProtocol <NSObject, NSSecureCoding>

@property (readonly) BOOL addedToEffect;

@property (readonly) NSError *_Nullable error;
//@property (readonly) id<FxGripEffectHost> _Nonnull effect;
@property (readonly) FxParameterId parameterID;
@property (readonly) FxParameterType parameterType;
@property (readwrite) FxParameterFlags parameterFlags;
@property (readwrite, retain) NSString*_Nonnull parameterName;
@property (readonly) FxParameterId parameterParentID;
@property (readonly) BOOL hasState;

@property (readonly) FxParameterFlags parameterCurrentFlags;
@property (readwrite) BOOL	isCaching;


- (FxParameterType)parameterType;
- (void)setParameterFlags:(FxParameterFlags)flags;

//Tells the Parameter to add itself to the plugin
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;
- (void)parameterFlush;

// When the parameter is created
- (void)createdWithFlags:(FxParameterFlags)flags parentID:(FxParameterId)parentID;
- (void)setParameterParentID:(FxParameterId)parentID;

@optional

- (BOOL)startChangedTime:(CMTime)time
				   error:(NSError * _Nullable * _Nullable)error;
- (BOOL)endChangedTime:(CMTime)time
				   error:(NSError * _Nullable * _Nullable)error;

// @todo:  After "addParameter" main function runs, validate parameters
- (BOOL)validate;	// RGB validates it's alpha parameter is a float style

@property (readonly, nonnull) NSNumber* minimum;
@property (readonly, nonnull) NSNumber* maximum;
@property (readonly, nonnull) NSNumber* delta;
@property (readonly, nonnull) NSNumber* sliderMinimum;
@property (readonly, nonnull) NSNumber* sliderMaximum;

@property (readonly, nonnull) NSNumber* defaultX;
@property (readonly, nonnull) NSNumber* defaultY;

@property (readonly, nonnull) NSArray<NSString*>* menuItems;



@property (readwrite, nullable, retain, nonatomic) NSString* stringValue;
@property (readwrite, nonatomic) BOOL boolValue;

@optional
@property (readonly, nonatomic, nullable) SEL		selector;
@property (readonly, nonatomic, nullable) NSString*	selectorString;
//@property (readonly, nonatomic) NSObject* _Nullable parameterSelectorObject;

@end




@protocol FxGripSubParameters <_FxGripParameterProtocol, NSFastEnumeration>

- (BOOL)addChildParameter:(id<_FxGripParameterProtocol>_Nonnull)parameter;
- (BOOL)removeChildParameter:(id<_FxGripParameterProtocol> _Nonnull)parameter;

- (NSUInteger)count;
- (nonnull NSArray<id<_FxGripParameterProtocol>>*)children;

//recursively gets all children, children of children, ^3, ^4, etc
- (NSUInteger)allCount;
- (nonnull NSArray<id<_FxGripParameterProtocol>>*)allChildren;

- (id<_FxGripParameterProtocol> _Nullable)objectAtIndexedSubscript:(NSInteger)index;

- (NSUInteger) countByEnumeratingWithState: (nonnull NSFastEnumerationState *) enumerationState
								   objects: (id _Nonnull __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;
@end




// Some Parameters are not for the pluginState, like Group, Help, and PushButton
// The Parameter should be added automatically by the pluginState unless "NO_STATE"
//	flag is set.
/*
 @protocol FxStateParameter
@end
*/



#define kFxGripParameterErrorBool (-1)
#define kFxGripPluginStateParameterTypeString @"-_-type"

@interface FxGripParameter : NSObject <_FxGripParameterProtocol> //NSCopying
{
@protected
	NSError				*_error;
	NSMutableDictionary<NSString*, id> *_data;
	BOOL				_addedToEffect;
	FxParameterFlags	_parameterFlags;
	
}

@property (readonly) uint loadIndex;
//@property (readwrite, retain, nonnull) NSString *name;
@property (readwrite, retain, nullable) NSString *paramDescription;
@property (readonly, assign) BOOL flagNoState;
@property (readonly, retain, nonnull) NSMutableDictionary *tags;
@property (readonly, retain, nonnull) NSMutableDictionary *meta;
@property (readonly, retain, nullable) NSString* customClass;
@property (readonly, retain, nullable) NSSet<NSString*>* customDataClasses;
@property (readonly, retain, nullable) id defaultValue;
@property (readonly, retain, nullable) id resetValue;


-(instancetype _Nullable) initWithDictionary:(NSDictionary*_Nonnull)dictionary effect:(id<FxGripEffectHost>_Nonnull)effect;

- (FxParameterType)parameterType NS_UNAVAILABLE;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect NS_UNAVAILABLE;


/*!
	@method		timelineTime:fromImageTime:forParameterID:
	@abstract   Converts from image time of the given parameter to timeline time.
	@param		timelineTime	The converted time, in CMTime.
	@param		time			The parameter's time, in CMTime.
*/
- (void)timelineTime:(nonnull CMTime*)timelineTime
	   fromImageTime:(CMTime)time;

- (void)imageTime:(nonnull CMTime*)imageTime
 fromTimelineTime:(CMTime)time;

//description?
// targetPrefix - target
// target preset
// target preset names, flags, tags, values


// red, green, blue, alpha, colorspace
// selector
// selector Prefix
// manage Prefix
// x, y
// items - NSArray<NSString*> has array of names
//					if array (name => string, selector => , reset => bool)


//NSSecureCoding Implementation
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;
- (nullable instancetype)initWithCoder:(NSCoder *_Nonnull)coder;
+ (BOOL)supportsSecureCoding;

@end




#endif
