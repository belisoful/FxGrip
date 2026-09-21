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
#import <FxGrip/FxGripEffectHost.h>
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
@protocol FxGripParameterBase <NSObject, NSSecureCoding>

/*! The host hides the parameter. Mirrors `kFxParameterFlag_HIDDEN`. */
@property (readwrite, nonatomic) BOOL flagHidden;
/*! The host disables the parameter. Mirrors `kFxParameterFlag_DISABLED`. */
@property (readwrite, nonatomic) BOOL flagDisabled;
/*! The parameter is absent from the dashboard. Mirrors `kFxParameterFlag_DONT_DISPLAY_IN_DASHBOARD`. */
@property (readwrite, nonatomic) BOOL flagDontDisplayInDashboard;

/*! The flags could not be read from the host. Mirrors `kFxParameterFlag_INVALID`. */
@property (readwrite, nonatomic) BOOL flagInvalid;
/*! The value is kept out of the plugin state. Mirrors `kFxParameterFlag_NOSTATE`. */
@property (readwrite, nonatomic) BOOL flagNoState;
/*! The parameter stays hidden in debug mode. Mirrors `kFxParameterFlag_NO_DEBUG`. */
@property (readwrite, nonatomic) BOOL flagNoDebug;
/*! The parameter is shown in debug mode. Mirrors `kFxParameterFlag_IN_DEBUG_MODE`. */
@property (readwrite, nonatomic) BOOL flagInDebugMode;
/*! The parameter is hidden in proxy mode. Mirrors `kFxParameterFlag_HIDDEN_PROXY`. */
@property (readwrite, nonatomic) BOOL flagHiddenProxy;

/*! The parameter is caching its flags rather than writing each one to the host. Mirrors `kFxParameterFlag_CACHE`. */
@property (readwrite, nonatomic) BOOL flagCaching;
/*! The cached flags differ from the host's. Mirrors `kFxParameterFlag_CACHEDIRTY`. */
@property (readonly, nonatomic) BOOL flagCacheDirty;

/*! YES once the parameter has been added to its effect. */
@property (readonly) BOOL addedToEffect;

/*! The error from the most recent failed host call, or nil. */
@property (readonly, retain) NSError *_Nullable error;
/*! The effect that owns the parameter. */
@property (readonly, nonnull) id<FxGripEffectHost> effect;
/*! The parameter's host ID. */
@property (readonly) FxParameterId parameterID;
/*! The parameter's type, as an `FxParameterType`. */
@property (readonly) FxParameterType parameterType;
/*! The parameter type this class registers, as an `FxParameterType`. */
@property (readonly, class) FxParameterType parameterType;
/*! The configuration string that names this parameter type, or nil when the class registers none. */
@property (readonly, class, nullable) NSString* parameterTypeString;
/*! The extension key that claims this parameter, or an empty string when none does. */
@property (readonly, nonnull, retain) NSString* extKey;
/*! The parameter's flags. Reads and writes go through the effect's parameter APIs, or through the cache while `flagCaching` is set. */
@property (readwrite) FxParameterFlags parameterFlags;
/*! The parameter's display name. */
@property (readwrite, retain) NSString*_Nonnull parameterName;
/*! The host ID of the parameter's group, or 0 at the top level. */
@property (readonly) FxParameterId parameterParentID;
/*! YES when the parameter is a state parameter and neither it nor any ancestor sets the no-state flag. */
@property (readonly) BOOL hasState;

/*! The flags the parameter was created with. `parameterFlags` tracks every later write. */
@property (readonly) FxParameterFlags parameterCurrentFlags;

/*!
	@method		parameterTypeString
	@abstract	The configuration string that names this parameter type.
	@return		The type string, or nil when the class registers none.
*/
+ (nullable NSString*)parameterTypeString;

/*!
	@method		parameterType
	@abstract	The parameter type this class registers.
	@return		The class's `FxParameterType`.
*/
+ (FxParameterType)parameterType;

/*!
	@method		parameterType
	@abstract	The parameter's own type.
	@return		The instance's `FxParameterType`.
*/
- (FxParameterType)parameterType;

/*!
	@method		setParameterFlags:
	@abstract	Writes the parameter's whole flags value.
	@discussion	The write reaches the host through the effect's parameter APIs, or the flag
				cache while `flagCaching` is set.
	@param		flags	The flags value to apply.
*/
- (void)setParameterFlags:(FxParameterFlags)flags;

/*!
	@method		addParameter:toEffect:
	@abstract	Creates a parameter of this class from a configuration dictionary and adds it to an effect.
	@discussion	The concrete parameter class implements this. ``FxGripParameterBase-class`` marks it
				unavailable, because the base declares no type of its own.
	@param		parameter	The parameter's configuration dictionary.
	@param		effect		The effect to add the parameter to.
	@return		YES when the host accepted the parameter.
*/
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method		parameterFlush
	@abstract	Writes the cached flags to the host and clears the cache bit.
	@discussion	The effect flushes every parameter before the host reads a saved state, so a
				cached flag write reaches the host first.
*/
- (void)parameterFlush;

/*!
	@method		createdWithFlags:parentID:
	@abstract	Records that the host created the parameter, storing its flags and parent.
	@param		flags		The flags the host created the parameter with.
	@param		parentID	The host ID of the parameter's group, or 0 at the top level.
*/
- (void)createdWithFlags:(FxParameterFlags)flags parentID:(FxParameterId)parentID;

/*!
	@method		setParameterParentID:
	@abstract	Records the group the parameter belongs to.
	@param		parentID	The host ID of the parameter's group, or 0 at the top level.
*/
- (void)setParameterParentID:(FxParameterId)parentID;



@optional
/*!
	@method		startChangedTime:error:
	@abstract	Opens a change to the parameter's value at a time.
	@discussion	A parameter class overrides this to act before its value changes. The base
				answers YES and does nothing.
	@param		time	The time the change applies at.
	@param		error	On return, the reason the parameter refused the change.
	@return		YES when the change may proceed.
*/
- (BOOL)startChangedTime:(CMTime)time
				   error:(NSError * _Nullable * _Nullable)error;
/*!
	@method		endChangedTime:error:
	@abstract	Closes a change to the parameter's value at a time.
	@discussion	A parameter class overrides this to act after its value changes. The base
				answers YES and does nothing.
	@param		time	The time the change applied at.
	@param		error	On return, the reason the parameter reported a failure.
	@return		YES when the change completed.
*/
- (BOOL)endChangedTime:(CMTime)time
				   error:(NSError * _Nullable * _Nullable)error;

/*!
	@method		validate
	@abstract	Answers whether the parameter's configuration is coherent.
	@discussion	``FxGripTileableEffect-class`` calls this on every parameter that implements it,
				once the whole `addParameters` pass has run, so a parameter may check another
				parameter it refers to. One NO fails the pass.
	@return		YES when the parameter's configuration is usable.
*/
- (BOOL)validate;
@end

/*!
	@protocol	FxGripParameterMinMax
	@abstract	The min/max opt-out shared by numeric parameters.
	@discussion	Introduced in FxGrip 0.1.0. flagIgnoreMinMax lets a value pass outside the
				declared bounds.
*/
@protocol FxGripParameterMinMax
/*! A value may pass outside the declared bounds. Mirrors `kFxParameterFlag_IGNORE_MINMAX`. */
@property (readwrite, nonatomic) BOOL flagIgnoreMinMax;
@end

/*!
	@protocol	FxGripParameterMinMaxInt
	@abstract	The integer value bounds and slider range of a numeric parameter.
	@discussion	Introduced in FxGrip 0.1.0. minimum and maximum bound the value; sliderMinimum
				and sliderMaximum bound the slider track.
*/
@protocol FxGripParameterMinMaxInt <FxGripParameterMinMax>
/*! The lowest value the parameter accepts. */
@property (readwrite, nonatomic) int minimum;
/*! The highest value the parameter accepts. */
@property (readwrite, nonatomic) int maximum;
/*! The value at the left end of the slider track. */
@property (readwrite, nonatomic) int sliderMinimum;
/*! The value at the right end of the slider track. */
@property (readwrite, nonatomic) int sliderMaximum;
@end

/*!
	@protocol	FxGripParameterMinMaxDouble
	@abstract	The floating-point value bounds and slider range of a numeric parameter.
	@discussion	Introduced in FxGrip 0.1.0. minimum and maximum bound the value; sliderMinimum
				and sliderMaximum bound the slider track.
*/
@protocol FxGripParameterMinMaxDouble <FxGripParameterMinMax>
/*! The lowest value the parameter accepts. */
@property (readwrite, nonatomic) double minimum;
/*! The highest value the parameter accepts. */
@property (readwrite, nonatomic) double maximum;
/*! The value at the left end of the slider track. */
@property (readwrite, nonatomic) double sliderMinimum;
/*! The value at the right end of the slider track. */
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

/*! The parameter holds one value with no keyframes. Mirrors `kFxParameterFlag_NOT_ANIMATABLE`. */
@property (readwrite, nonatomic) BOOL flagNotAnimatable;
/*! The host does not save the value. Mirrors `kFxParameterFlag_DONT_SAVE`. */
@property (readwrite, nonatomic) BOOL flagDontSave;
/*! The parameter vends a custom view. Mirrors `kFxParameterFlag_CUSTOM_UI`. */
@property (readwrite, nonatomic) BOOL flagCustomUI;
/*! The parameter is absent from the curve editor. Mirrors `kFxParameterFlag_CURVE_EDITOR_HIDDEN`. */
@property (readwrite, nonatomic) BOOL flagCurveEditorHidden;
/*! The control spans the inspector width. Mirrors `kFxParameterFlag_USE_FULL_VIEW_WIDTH`. */
@property (readwrite, nonatomic) BOOL flagUseFullViewWidth;

/*! The parameter's custom inspector view, or nil when it has none. */
@property (readonly, nonatomic, nullable) NSView* customView;


@optional
/*!
	@method		startChangedTime:error:
	@abstract	Opens a change to the parameter's value at a time.
	@discussion	A parameter class overrides this to act before its value changes. The base
				answers YES and does nothing.
	@param		time	The time the change applies at.
	@param		error	On return, the reason the parameter refused the change.
	@return		YES when the change may proceed.
*/
- (BOOL)startChangedTime:(CMTime)time
				   error:(NSError * _Nullable * _Nullable)error;
/*!
	@method		endChangedTime:error:
	@abstract	Closes a change to the parameter's value at a time.
	@discussion	A parameter class overrides this to act after its value changes. The base
				answers YES and does nothing.
	@param		time	The time the change applied at.
	@param		error	On return, the reason the parameter reported a failure.
	@return		YES when the change completed.
*/
- (BOOL)endChangedTime:(CMTime)time
				   error:(NSError * _Nullable * _Nullable)error;

/*!
	@method		validate
	@abstract	Answers whether the parameter's configuration is coherent.
	@discussion	``FxGripTileableEffect-class`` calls this on every parameter that implements it,
				once the whole `addParameters` pass has run, so a parameter may check another
				parameter it refers to. One NO fails the pass.
	@return		YES when the parameter's configuration is usable.
*/
- (BOOL)validate;

/*! The lowest value the parameter accepts. */
@property (readonly, nonnull) NSNumber* minimum;
/*! The highest value the parameter accepts. */
@property (readonly, nonnull) NSNumber* maximum;
/*! The amount one step of the control changes the value. */
@property (readonly, nonnull) NSNumber* delta;
/*! The value at the left end of the slider track. */
@property (readonly, nonnull) NSNumber* sliderMinimum;
/*! The value at the right end of the slider track. */
@property (readonly, nonnull) NSNumber* sliderMaximum;

/*! The declared default of a point parameter's X component. */
@property (readonly, nonnull) NSNumber* defaultX;
/*! The declared default of a point parameter's Y component. */
@property (readonly, nonnull) NSNumber* defaultY;

/*! The titles of a menu parameter's entries, in menu order. */
@property (readonly, nonnull) NSArray<NSString*>* menuItems;



/*! The parameter's value as a string. */
@property (readwrite, nullable, retain, nonatomic) NSString* stringValue;
/*! The parameter's value as a boolean. A failed read answers `kFxGripParameterErrorBool`. */
@property (readwrite, nonatomic) BOOL boolValue;

@optional
/*! The selector a click on the parameter performs, or nil. */
@property (readonly, nonatomic, nullable) SEL		selector;
/*! The name of the selector a click on the parameter performs, or nil. */
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

/*!
	@method		addChildParameter:
	@abstract	Adds a parameter as a direct child.
	@param		parameter	The parameter to add.
	@return		YES when the parameter became a child.
*/
- (BOOL)addChildParameter:(id<FxGripParameter>_Nonnull)parameter;

/*!
	@method		removeChildParameter:
	@abstract	Removes a direct child.
	@param		parameter	The parameter to remove.
	@return		YES when the parameter was a child and was removed.
*/
- (BOOL)removeChildParameter:(id<FxGripParameter> _Nonnull)parameter;

/*!
	@method		count
	@abstract	The number of direct children.
	@return		The count of parameters one level down.
*/
- (NSUInteger)count;

/*!
	@method		children
	@abstract	The direct children, in order.
	@return		The parameters one level down.
*/
- (nonnull NSArray<id<FxGripParameter>>*)children;

/*!
	@method		allCount
	@abstract	The number of parameters in the whole descendant tree.
	@return		The count of children, their children, and so on to every depth.
*/
- (NSUInteger)allCount;

/*!
	@method		allChildren
	@abstract	Every parameter in the descendant tree, in order.
	@return		The children, their children, and so on to every depth.
*/
- (nonnull NSArray<id<FxGripParameter>>*)allChildren;

/*!
	@method		objectAtIndexedSubscript:
	@abstract	The direct child at an index, reachable as `parameter[i]`.
	@param		index	The position among the direct children.
	@return		The child, or nil when the index is out of range.
*/
- (id<FxGripParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;

/*!
	@method		countByEnumeratingWithState:objects:count:
	@abstract	Enumerates the direct children with `for (id p in parameter)`.
	@discussion	The `NSFastEnumeration` conformance walks one level, matching `children`.
	@param		enumerationState	The enumeration state the runtime carries between calls.
	@param		stackBuffer			The buffer the runtime offers for returned objects.
	@param		len					The capacity of stackBuffer.
	@return		The number of objects written, or 0 at the end of the enumeration.
*/
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
@interface FxGripParameterBase : NSObject <FxGripParameterBase, NSNotificationObjectPriorityItem> //NSCopying
{
@protected
	NSError				*_error;
	NSMutableDictionary<NSString*, id> *_data;
	BOOL				_addedToEffect;
	FxParameterFlags	_parameterFlags;
}
/*! The parameter's position in the effect's load order. */
@property (readonly) uint loadIndex;


/*!
	@method		initWithDictionary:effect:
	@abstract	Creates a parameter from its configuration dictionary.
	@discussion	The designated initializer. It stores the dictionary, resolves the parameter's
				flags, identity, and name through the effect's parameter APIs, and calls
				``installNotifications``.
	@param		dictionary	The parameter's configuration dictionary.
	@param		effect		The effect that owns the parameter.
	@return		The parameter, or nil when the dictionary describes none.
*/
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
/*!
	@method		removeObservers
	@abstract	Unregisters the parameter's observers from the effect's notifier.
	@discussion	`dealloc` calls this. The notifier holds selector observers weakly, so a
				parameter that outlives its effect still unregisters cleanly.
*/
- (void)removeObservers;

/*!
	@method		parameterType
	@abstract	Unavailable on the base, which declares no parameter type of its own.
	@discussion	A concrete parameter class overrides it with the type it registers.
*/
- (FxParameterType)parameterType NS_UNAVAILABLE;

/*!
	@method		addParameter:toEffect:
	@abstract	Unavailable on the base, which declares no parameter type of its own.
	@discussion	A concrete parameter class overrides it to build its parameter from a
				configuration dictionary.
	@param		parameter	The parameter's configuration dictionary.
	@param		effect		The effect to add the parameter to.
*/
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


/*!
	@method		encodeWithCoder:
	@abstract	Encodes the parameter type into the plugin state.
	@param		coder	The coder writing the plugin state.
*/
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

/*!
	@method		initWithCoder:
	@abstract	Decodes a parameter from the plugin state.
	@param		coder	The coder reading the plugin state.
	@return		The parameter, or nil when the state holds none.
*/
- (nullable instancetype)initWithCoder:(NSCoder *_Nonnull)coder;

/*!
	@method		supportsSecureCoding
	@abstract	Answers YES. The parameter model supports secure coding.
	@return		YES.
*/
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
