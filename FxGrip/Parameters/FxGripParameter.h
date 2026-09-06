/*!
	@file       FxGripParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameter
	@abstract   The parameter model: the base protocols and classes every FxGrip parameter adopts.
	@discussion Introduced in FxGrip 0.1.0. FxGripParameterBase defines the flags, identity, and
	            host wiring shared by group and regular parameters. FxGripParameter adds the
	            value, min/max, and custom-view surface of a leaf parameter. FxGripSubParameters
	            models a parameter that holds children. FxGripStateParameter marks a parameter
	            whose value belongs in the plugin state. FxGripParameterBase (the class) is the
	            concrete root that stores the parameter dictionary, registers flag observers on
	            the effect's notifier, and encodes the parameter type into the plugin state.
*/

#ifndef FxGripParameter_h
#define FxGripParameter_h

#import <FxPlug/FxPlugSDK.h>
//#import "FxGripParameterFlags.h"
#import <FxGrip/FxGripTypes.h>
#import "FxGripEffectHost.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
//#import "NSCoder+FxPlug.h"

// Forward declaration
@protocol FxGripTileableEffect;

// Reserved FxGrip parameter ID for the FxFactory license parameter.
#define kFxParameterId_FxFactoryLicense		(9980)



/*!
	@protocol	FxGripParameterBase
	@abstract	The flags, identity, and host wiring shared by group and regular parameters.
	@discussion	Introduced in FxGrip 0.1.0. Each flagXxx property mirrors one bit of the
				parameter's FxParameterFlags, reading and writing it through the effect's
				parameter APIs. The protocol also exposes the parameter's ID, type, name, parent
				ID, and error, and the class methods that register a parameter type and add a
				parameter to an effect.
*/
// Flags that Group and Regular Parameters share
@protocol FxGripParameterBase <NSObject, NSSecureCoding>

@property (readwrite, nonatomic) BOOL flagHidden;
@property (readwrite, nonatomic) BOOL flagDisabled;
@property (readwrite, nonatomic) BOOL flagDontDisplayInDashboard;

@property (readwrite, nonatomic) BOOL flagInvalid;
@property (readwrite, nonatomic) BOOL flagNoState;
@property (readwrite, nonatomic) BOOL flagNoDebug;
@property (readwrite, nonatomic) BOOL flagInDebugMode;
@property (readwrite, nonatomic) BOOL flagHiddenProxy;

@property (readwrite, nonatomic) BOOL flagCaching;
@property (readonly, nonatomic) BOOL flagCacheDirty;

@property (readonly) BOOL addedToEffect;

@property (readonly, retain) NSError *_Nullable error;
@property (readonly, nonnull) id<FxGripEffectHost> effect;
@property (readonly) FxParameterId parameterID;
@property (readonly) FxParameterType parameterType;
@property (readonly, class) FxParameterType parameterType;
@property (readonly, class, nullable) NSString* parameterTypeString;
@property (readonly, nonnull, retain) NSString* extKey;
@property (readwrite) FxParameterFlags parameterFlags;
@property (readwrite, retain) NSString*_Nonnull parameterName;
@property (readonly) FxParameterId parameterParentID;
@property (readonly) BOOL hasState;

@property (readonly) FxParameterFlags parameterCurrentFlags;

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
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
- (BOOL)validate;
@end

/*!
	@protocol	FxGripParameterMinMax
	@abstract	The min/max opt-out shared by numeric parameters.
	@discussion	Introduced in FxGrip 0.1.0. flagIgnoreMinMax lets a value pass outside the
				declared bounds.
*/
@protocol FxGripParameterMinMax
@property (readwrite, nonatomic) BOOL flagIgnoreMinMax;
@end

/*!
	@protocol	FxGripParameterMinMaxInt
	@abstract	The integer value bounds and slider range of a numeric parameter.
	@discussion	Introduced in FxGrip 0.1.0. minimum and maximum bound the value; sliderMinimum
				and sliderMaximum bound the slider track.
*/
@protocol FxGripParameterMinMaxInt <FxGripParameterMinMax>
@property (readwrite, nonatomic) int minimum;
@property (readwrite, nonatomic) int maximum;
@property (readwrite, nonatomic) int sliderMinimum;
@property (readwrite, nonatomic) int sliderMaximum;
@end

/*!
	@protocol	FxGripParameterMinMaxDouble
	@abstract	The floating-point value bounds and slider range of a numeric parameter.
	@discussion	Introduced in FxGrip 0.1.0. minimum and maximum bound the value; sliderMinimum
				and sliderMaximum bound the slider track.
*/
@protocol FxGripParameterMinMaxDouble <FxGripParameterMinMax>
@property (readwrite, nonatomic) double minimum;
@property (readwrite, nonatomic) double maximum;
@property (readwrite, nonatomic) double sliderMinimum;
@property (readwrite, nonatomic) double sliderMaximum;
@end



/*!
	@protocol	FxGripParameter
	@abstract	A leaf parameter: a value, its bounds, and its optional custom view.
	@discussion	Introduced in FxGrip 0.1.0. The protocol adds the value flags a leaf parameter
				carries (not-animatable, don't-save, custom-UI, curve-editor-hidden,
				full-view-width), the read-only value bounds and defaults, the string and bool
				value accessors, and the custom view. defaultParameterAction supplies a
				parameter's built-in click behavior.
*/
@protocol FxGripParameter <FxGripParameterBase>

@property (readwrite, nonatomic) BOOL flagNotAnimatable;
@property (readwrite, nonatomic) BOOL flagDontSave;
@property (readwrite, nonatomic) BOOL flagCustomUI;
@property (readwrite, nonatomic) BOOL flagCurveEditorHidden;
@property (readwrite, nonatomic) BOOL flagUseFullViewWidth;

@property (readonly, nonatomic, nullable) NSView* customView;


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

/*!
	@method     defaultParameterAction
	@abstract   The parameter's built-in click behavior.
	@discussion Introduced in FxGrip 0.1.0. `FxGripTileableEffect parameterClicked:` performs
				this when the effect subclass implements no configuration-declared click
				selector for the parameter.
*/
- (void)defaultParameterAction;

@end



/*!
	@protocol	FxGripSubParameters
	@abstract	A parameter that holds child parameters, such as a group.
	@discussion	Introduced in FxGrip 0.1.0. The protocol adds and removes children, counts and
				enumerates the direct children, and counts and enumerates the whole descendant
				tree (allCount, allChildren). A child is reachable by index through
				objectAtIndexedSubscript:, and the parameter conforms to NSFastEnumeration.
*/
@protocol FxGripSubParameters <FxGripParameter, NSFastEnumeration>

- (BOOL)addChildParameter:(id<FxGripParameter>_Nonnull)parameter;
- (BOOL)removeChildParameter:(id<FxGripParameter> _Nonnull)parameter;

- (NSUInteger)count;
- (nonnull NSArray<id<FxGripParameter>>*)children;

//recursively gets all children, children of children, ^3, ^4, etc
- (NSUInteger)allCount;
- (nonnull NSArray<id<FxGripParameter>>*)allChildren;

- (id<FxGripParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;

- (NSUInteger) countByEnumeratingWithState: (nonnull NSFastEnumerationState *) enumerationState
								   objects: (id _Nonnull __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;
@end




/*!
	@protocol	FxGripStateParameter
	@abstract	Marks a parameter whose value belongs in the plugin state.
	@discussion	Introduced in FxGrip 0.1.0. A conforming parameter is added to the plugin state
				automatically unless its NO_STATE flag is set. Group, Help, and PushButton
				parameters do not conform, so they carry no state.
*/
// Some Parameters are not for the pluginState, like Group, Help, and PushButton
// The Parameter should be added automatically by the pluginState unless "NO_STATE"
//	flag is set.
@protocol FxGripStateParameter
@end




/*! The bool value returned when a bool parameter read fails. */
#define kFxGripParameterErrorBool (-1)
/*! The suffix of the plugin-state key that stores a parameter's type, keyed by parameter ID. */
#define kFxGripPluginStateParameterTypeString @"-_-type"

/*!
	@class		FxGripParameterBase
	@abstract	The concrete root of the parameter model.
	@discussion	Introduced in FxGrip 0.1.0. The class stores the parameter dictionary, resolves
				the flags, identity, and name through the effect's parameter APIs, and registers
				flag observers on the effect's notifier. It encodes the parameter type into the
				plugin state and supports secure coding. parameterType, and the class factory
				addParameter:toEffect:, are unavailable on the base and are overridden by a
				concrete parameter class.
*/
//This is to differentiate the Group Parameter
@interface FxGripParameterBase : NSObject <FxGripParameterBase, NSNotificationObjectPriorityItem> //NSCopying
{
@protected
	NSError				*_error;
	NSMutableDictionary<NSString*, id> *_data;
	BOOL				_addedToEffect;
	FxParameterFlags	_parameterFlags;
}
@property (readonly) uint loadIndex;


-(instancetype _Nullable) initWithDictionary:(NSDictionary*_Nonnull)dictionary effect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method     installNotifications
	@abstract   Registers the parameter's observers on the effect's notifier.
	@discussion Introduced in FxGrip 0.1.0. The designated initializer calls this; a
				subclass overrides it to register additional observers and calls super.
				The notifier holds selector observers weakly; removeObservers (called
				from dealloc) unregisters them.
*/
- (void)installNotifications;
- (void)removeObservers;

- (FxParameterType)parameterType NS_UNAVAILABLE;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect NS_UNAVAILABLE;

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


/*!
	@class		FxGripParameter
	@abstract	The concrete root of a leaf parameter that carries a value and an optional view.
	@discussion	Introduced in FxGrip 0.1.0. The class adds the custom inspector view surface
				(newParameterView, attachCustomView:), the secure-coding allow-list for a
				custom value (customValueClasses), and the parameter's description, tags, meta,
				custom classes, and default and reset values.
*/
@interface FxGripParameter : FxGripParameterBase <FxGripParameter> //NSCopying
/*!
	@method     newParameterView
	@abstract   Creates the parameter's custom inspector view.
	@discussion Introduced in FxGrip 0.1.0. The view host
				(createViewForParameterID:) calls this for a parameter whose class
				provides a view and hands the result to the host application. The base
				returns nil; a parameter class with custom UI overrides. The returned
				view is retained per the FxCustomParameterViewHost_v2 contract.
*/
- (NSView *_Nullable)newParameterView;

/*!
	@method     attachCustomView:
	@abstract   Records the view backing this parameter.
	@discussion Introduced in FxGrip 0.1.0. The view host attaches the created view (or
				its retained root, when the returned view wraps it) so the parameter can
				reach its view for data pushes; nil detaches.
*/
- (void)attachCustomView:(NSView *_Nullable)view;

/*!
	@method     customValueClasses
	@abstract   The secure-coding allow-list for this parameter class's custom value.
	@discussion Introduced in FxGrip 0.1.0. classesForCustomParameterID: consults the
				parameter class registered for the configured type; a class whose custom
				value is its own model type overrides. The base returns nil.
*/
+ (NSSet<Class> *_Nullable)customValueClasses;

//@property (readwrite, retain, nonnull) NSString *name;
/*! The parameter's descriptive text. */
@property (readwrite, retain, nullable) NSString *paramDescription;
/*! The parameter's tags. */
@property (readonly, retain, nonnull) NSMutableDictionary *tags;
/*! The parameter's meta dictionary. */
@property (readonly, retain, nonnull) NSMutableDictionary *meta;
/*! The declared custom class name for a custom parameter, or nil. */
@property (readonly, retain, nullable) NSString* customClass;
/*! The declared custom data class names for a custom parameter, or nil. */
@property (readonly, retain, nullable) NSSet<NSString*>* customDataClasses;
/*! The parameter's declared default value, or nil. */
@property (readonly, retain, nullable) id defaultValue;
/*! The value the parameter resets to, or nil. */
@property (readonly, retain, nullable) id resetValue;


@end




#endif
