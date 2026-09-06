/*!
	@file       NSDictionary+FxGripTileableEffect.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     NSDictionary+FxGripTileableEffect
	@abstract   Typed accessors that read plug-in and parameter configuration from Foundation collections.
	@discussion Introduced in FxGrip 0.1.0. Plug-in registration and parameter definitions arrive
	            as plist dictionaries, arrays, strings, and numbers. These categories read a
	            parameter's type, ID, flags, range, and per-type values from a dictionary, and read
	            the plug-in's identity, presets, and feature switches. Companion categories on
	            NSString, NSNumber, and NSArray resolve a type name, split human-divided lists, and
	            fold flag-name arrays into an FxParameterFlags mask. The NSMutableDictionary
	            category writes the common parameter keys back.
*/

#ifndef NSDictionary_FxGripTileableEffect_h
#define NSDictionary_FxGripTileableEffect_h

#import <Foundation/Foundation.h>
#import "FxGripTypes.h"
#import <BEFoundation/NSString+BExtension.h>

@protocol FxParameterFactory;

/*!
	@abstract	Reads a numeric parameter-type value.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@interface NSNumber (FxGripTileableEffect)

/*! The receiver's integer value as an FxParameterType. */
- (FxParameterType)parameterType;

@end

/*!
	@abstract	Resolves a parameter-type name and splits human-divided lists.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@interface NSString (FxGripTileableEffect)

/*! The FxParameterType named by the string. */
- (FxParameterType)parameterType;
/*! The string split into components on human dividers (whitespace and punctuation). */
- (NSArray<NSString*>*_Nonnull)splitByHumanDividers;

@end


/*!
	@abstract	Localizes entries, indexes safely, and folds flag-name arrays into a mask.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@interface NSArray (FxGripTileableEffect)

/*! A copy with each string entry localized against the plug-in bundle. */
- (NSArray*_Nonnull)localize;
/*! The object at an index, or nil when the index is out of range. */
- (id _Nullable)objectForIndex:(NSUInteger)index;

/*! The OR of the flag bits named by the array's entries. */
- (FxParameterFlags)fxParameterFlags;
/*! The OR of the flag bits named by the array's "-"-prefixed entries. */
- (FxParameterFlags)negativeFxParameterFlags;

@end



/*!
	@abstract	Typed reads of plug-in registration and parameter configuration.
	@discussion	Introduced in FxGrip 0.1.0. The plug-in accessors return nil or NO unless the
				dictionary carries the required plug-in keys. The parameter accessors return a
				neutral value unless it carries the required parameter keys.
*/
@interface NSDictionary (FxGripTileableEffect)

/*! The object under an integer index, matched as a number key or its decimal-string key. */
- (id _Nullable) objectForIndex:(NSUInteger)index;

/*! The plug-in UUID. */
- (NSString*_Nullable) pluginUUID;
/*! The plug-in principal class name. */
- (NSString*_Nullable) pluginClassName;
/*! The plug-in display name. */
- (NSString*_Nullable) pluginDisplayName;
/*! The plug-in group UUID. */
- (NSString*_Nullable) pluginGroupUUID;
/*! The FxPlug protocol names the plug-in declares. */
- (NSArray<NSString*>*_Nullable) pluginProtocolNames;
/*! The plug-in info string. */
- (NSString*_Nullable) pluginInfoString;
/*! The default font name for the plug-in's font menus. */
- (NSString*_Nullable) pluginDefaultFontName;
/*! The plug-in version string. */
- (NSString*_Nullable) pluginVersion;
/*! The plug-in preset table, keyed by preset name. */
- (NSDictionary<NSString*, NSDictionary*>*_Nullable) pluginPresets;
/*! The plug-in effect properties dictionary. */
- (NSDictionary<NSString*, id>*_Nullable) pluginEffectProperties;

/*! The plug-in's prior UUIDs; a string value splits on human dividers. */
- (NSArray<NSString*>* _Nullable) pluginPriorUUIDs;
/*! The plug-in's parameter definitions. */
- (NSArray<NSDictionary*>* _Nullable) pluginParameters;
/*! YES when the plug-in enables the debug menu. Default NO. */
- (BOOL) pluginDebugMenu;
/*! YES when the plug-in enables the debug activator. Default NO. */
- (BOOL) pluginDebugActivator;
/*! The plug-in's about-menu configuration. */
- (NSDictionary*_Nullable) pluginAboutMenu;
/*! YES when the plug-in manages meta. Default YES. */
- (BOOL) pluginManageMeta;
/*! YES when the plug-in manages parameter data. Default NO. */
- (BOOL) pluginManageParameterData;
/*! YES when the plug-in tracks instances. Default NO. */
- (BOOL) pluginTrackInstances;
/*! YES when the plug-in enables the regression pass. Default NO. */
- (BOOL) pluginRegression;
/*! YES when the plug-in is distributed through FxFactory. Default NO. */
- (BOOL) pluginFxFactory;


/*! The parameter's factory object. */
- (nullable id<FxParameterFactory>)parameterFactory;
/*! The parameter's extension key. */
- (nullable NSString *)parameterExtensionKey;
/*! The parameter's custom class name. */
- (nullable NSString *)parameterClassName;

/*! The parameter type, read from a number or a type name. */
@property (readonly, nonatomic) FxParameterType parameterType;
/*! The parameter ID; kFxParameterId_None when absent. */
@property (readonly, nonatomic) FxParameterId parameterID;
/*! The parameter parent ID; kFxParameterId_TopLevelGroup when absent. */
@property (readonly, nonatomic) FxParameterId parameterParentID;

/*! The parameter name. */
- (NSString*_Nullable) parameterName;
/*! The parameter description. */
- (NSString*_Nullable) parameterDescription;
/*! The parameter flag mask, read from a string, array, dictionary, or number. */
- (FxParameterFlags) parameterFlags;
/*! The parameter flags as an array of flag names. */
- (NSArray<NSString*>*_Nullable) parameterFlagsArray;
/*! The parameter tags; a string value splits on human dividers. */
- (NSArray<NSString*>*_Nullable) parameterTags;
/*! The parameter meta dictionary. */
- (NSDictionary*_Nullable) parameterMeta;
/*! The parameter's single custom-view class name. */
- (NSString*_Nullable) parameterCustomClass;
/*! The parameter's custom-view class names as a set. */
- (NSSet<NSString*>*_Nullable) parameterCustomClasses;
/*! The parameter's default value. */
- (id _Nullable) parameterDefaultValue;
/*! The parameter's reset value. */
- (id _Nullable) parameterResetValue;
/*! The parameter's target-preset definition: a tag, array, or index-keyed dictionary. */
- (id _Nullable) parameterTargetPreset;

/*! The raw minimum value as a number. */
- (NSNumber*_Nullable)parameterMinimum_Raw;
/*! The minimum value as an int. */
- (int)parameterMinimumInt;
/*! The minimum value as a double. */
- (double)parameterMinimumDouble;
/*! The raw maximum value as a number. */
- (NSNumber*_Nullable) parameterMaximum;
/*! The maximum value as an int. */
- (int)parameterMaximumInt;
/*! The maximum value as a double. */
- (double)parameterMaximumDouble;
/*! The slider's minimum value. */
- (NSNumber*_Nullable) parameterSliderMinimum;
/*! The slider's maximum value. */
- (NSNumber*_Nullable) parameterSliderMaximum;
/*! The parameter's drag delta. */
- (NSNumber*_Nullable) parameterDelta;
/*! The red channel default. */
- (NSNumber*_Nullable) parameterRed;
/*! The green channel default. */
- (NSNumber*_Nullable) parameterGreen;
/*! The blue channel default. */
- (NSNumber*_Nullable) parameterBlue;
/*! The alpha channel default. */
- (NSNumber*_Nullable) parameterAlpha;
/*! The parameter's color space. */
- (NSNumber*_Nullable) parameterColorSpace;
/*! The parameter's click selector. */
- (id _Nullable) parameterSelector;
/*! The parameter's selector target object. */
- (NSObject*_Nullable)parameterSelectorObject;
/*! The point default's X, read from an X key or the default's first component; 0 when absent. */
- (NSNumber*_Nullable) parameterDefaultX;
/*! The point default's Y, read from a Y key or the default's second component; 0 when absent. */
- (NSNumber*_Nullable) parameterDefaultY;
/*! The menu items; an empty array for a Menu or Capsule with none. */
- (NSArray<NSString*>*_Nullable) parameterMenuItems;

/*! The gradient sample count. */
-(NSNumber*_Nullable) parameterGradientSamples;
/*! The gradient depth as an FxDepth; kFxDepth_FLOAT16 by default, converting from a byte count when needed. */
-(FxGripDepthType) parameterGradientDepth;
/*! The gradient depth type: FxDepth or byte-count interpretation of the depth value. */
-(FxGripDepthType) parameterGradientDepthType;

@end


/*!
	@abstract	Writes the common parameter keys back into a configuration.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@interface NSMutableDictionary (FxGripTileableEffect)

/*! The parameter type, stored as a number. */
@property (readwrite, nonatomic) FxParameterType parameterType;
/*! The parameter ID, stored as a number. */
@property (readwrite, nonatomic) FxParameterId parameterID;
/*! The parameter parent ID, stored as a number. */
@property (readwrite, nonatomic) FxParameterId parameterParentID;
/*! The parameter flag mask, stored as a number. */
@property (readwrite, nonatomic) FxParameterFlags parameterFlags;

@end

#endif	//	NSDictionary_FxGripTileableEffect_h
