//
//  FxGripParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxParameter_h
#define FxParameter_h

#import <FxPlug/FxPlugSDK.h>
//#import "FxGripParameterFlags.h"
#import <FxGrip/FxGripTypes.h>
#import "FxGripEffectHost.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
//#import "NSCoder+FxPlug.h"

// Forward declaration
@protocol FxTileableEffectBase;



// Flags that Group and Regular Parameters share
@protocol FxParameterBase <NSObject, NSSecureCoding>

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

@protocol FxParameterMinMax
@property (readwrite, nonatomic) BOOL flagIgnoreMinMax;
@end

@protocol FxParameterMinMaxInt <FxParameterMinMax>
@property (readwrite, nonatomic) int minimum;
@property (readwrite, nonatomic) int maximum;
@property (readwrite, nonatomic) int sliderMinimum;
@property (readwrite, nonatomic) int sliderMaximum;
@end

@protocol FxParameterMinMaxDouble <FxParameterMinMax>
@property (readwrite, nonatomic) double minimum;
@property (readwrite, nonatomic) double maximum;
@property (readwrite, nonatomic) double sliderMinimum;
@property (readwrite, nonatomic) double sliderMaximum;
@end



@protocol FxParameter <FxParameterBase>

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
	@discussion Introduced in FxGrip 1.0. `FxTileableEffectBase parameterClicked:` performs
				this when the effect subclass implements no configuration-declared click
				selector for the parameter.
*/
- (void)defaultParameterAction;

@end



@protocol FxSubParameters <FxParameter, NSFastEnumeration>

- (BOOL)addChildParameter:(id<FxParameter>_Nonnull)parameter;
- (BOOL)removeChildParameter:(id<FxParameter> _Nonnull)parameter;

- (NSUInteger)count;
- (nonnull NSArray<id<FxParameter>>*)children;

//recursively gets all children, children of children, ^3, ^4, etc
- (NSUInteger)allCount;
- (nonnull NSArray<id<FxParameter>>*)allChildren;

- (id<FxParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;

- (NSUInteger) countByEnumeratingWithState: (nonnull NSFastEnumerationState *) enumerationState
								   objects: (id _Nonnull __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;
@end




// Some Parameters are not for the pluginState, like Group, Help, and PushButton
// The Parameter should be added automatically by the pluginState unless "NO_STATE"
//	flag is set.
@protocol FxStateParameter
@end




#define kFxGripParameterErrorBool (-1)
#define kFxGripPluginStateParameterTypeString @"-_-type"

//This is to differentiate the Group Parameter
@interface FxParameterBase : NSObject <FxParameterBase, NSNotificationObjectPriorityItem> //NSCopying
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
	@discussion Introduced in FxGrip 1.0. The designated initializer calls this; a
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


@interface FxParameter : FxParameterBase <FxParameter> //NSCopying
/*!
	@method     newParameterView
	@abstract   Creates the parameter's custom inspector view.
	@discussion Introduced in FxGrip 1.0. The view host
				(createViewForParameterID:) calls this for a parameter whose class
				provides a view and hands the result to the host application. The base
				returns nil; a parameter class with custom UI overrides. The returned
				view is retained per the FxCustomParameterViewHost_v2 contract.
*/
- (NSView *_Nullable)newParameterView;

/*!
	@method     attachCustomView:
	@abstract   Records the view backing this parameter.
	@discussion Introduced in FxGrip 1.0. The view host attaches the created view (or
				its retained root, when the returned view wraps it) so the parameter can
				reach its view for data pushes; nil detaches.
*/
- (void)attachCustomView:(NSView *_Nullable)view;

/*!
	@method     customValueClasses
	@abstract   The secure-coding allow-list for this parameter class's custom value.
	@discussion Introduced in FxGrip 1.0. classesForCustomParameterID: consults the
				parameter class registered for the configured type; a class whose custom
				value is its own model type overrides. The base returns nil.
*/
+ (NSSet<Class> *_Nullable)customValueClasses;

//@property (readwrite, retain, nonnull) NSString *name;
@property (readwrite, retain, nullable) NSString *paramDescription;
@property (readonly, retain, nonnull) NSMutableDictionary *tags;
@property (readonly, retain, nonnull) NSMutableDictionary *meta;
@property (readonly, retain, nullable) NSString* customClass;
@property (readonly, retain, nullable) NSSet<NSString*>* customDataClasses;
@property (readonly, retain, nullable) id defaultValue;
@property (readonly, retain, nullable) id resetValue;


@end




#endif
