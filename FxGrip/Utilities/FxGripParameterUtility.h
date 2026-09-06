/*!
	@file       FxGripParameterUtility.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterUtility
	@abstract   Converts FxPlug parameter types and flags between integer and string forms.
	@discussion Introduced in FxGrip 0.1.0. The plist parameter definitions name types and flags
	            as strings. This helper maps a type string to its FxParameterType and back, and a
	            flag string or array of flag strings to an FxParameterFlags bitmask and back. It
	            also flattens nested parameter definitions, applies target-preset defaults, and
	            encodes and decodes the synthesized click selector a button parameter registers.
*/

#ifndef FxParameterFactory_h
#define FxParameterFactory_h

#import <Foundation/Foundation.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripTypes.h>

@protocol FxGripParameter;

/*!
	@protocol	FxParameterFactory
	@abstract	Creates a parameter model object from a plist configuration dictionary.
	@discussion	Introduced in FxGrip 0.1.0. An adopter builds an id<FxGripParameter> from a
				parameter definition.
*/
@protocol FxParameterFactory <NSObject>

/*! A parameter built from its configuration dictionary, or nil when the data is unusable. */
- (nullable id<FxGripParameter>)parameterForDictionary:(nonnull NSDictionary *)data;

@end


/*!
 @interface     FxGripParameterUtility
 @abstract      converts FxPlug parameter types and flags between their int and string representations.
 @discussion    This is the Helper class for doing type convertions.  Given a NSString, it will
				provide it's FxParameterType.  Also this will convert NSStrings and NSArray of NSString
				to their associated bit flag.
 
 */
@interface FxGripParameterUtility : NSObject

// The maps of the parameter type <=> string, eg. integer, rgba, point, string, toggle.
/*! The map from type string to FxParameterType number. */
+ (NSDictionary<NSString*, NSNumber*>*_Nonnull)parameterTypes;
/*! The inverse map from FxParameterType number to type string. */
+ (NSDictionary<NSNumber*, NSString*>*_Nonnull)typeParameters;

// The maps of the parameter flags <=> string, eg. hidden, disabled, dontsave, ignore_minmax
/*! The map from flag string to FxParameterFlags number. */
+ (NSDictionary<NSString*, NSNumber*>*_Nonnull)flagValues;
/*! The inverse map from single-flag number to flag string. */
+ (NSDictionary<NSNumber*, NSString*>*_Nonnull)valueFlags;

// Convert types to strings and strings to types
/*! The FxParameterType for a type string; the unknown type when the string is nil or unmatched. */
+ (FxParameterType)parameterTypeFromString:(NSString*_Nullable)type;
/*! The type string for an FxParameterType, or nil when the type has no name. */
+ (NSString* _Nullable)parameterTypeString:(FxParameterType)type;

// convert a flag to its string, and a set of flags to an array of strings
//	and visa versa.
/*! The flag string for a single flag value, or nil when it names none. */
+ (NSString* _Nullable) convertToFlag:(FxParameterFlags)flag;
/*! The flag strings for every bit set in a flag mask. */
+ (NSArray<NSString*>*_Nonnull) convertToFlags:(FxParameterFlags)flag;
/*! The flag bit for a single flag string; zero when the string names none. */
+ (FxParameterFlags)convertFlag:(nullable NSString*)flag;
/*! The combined flag mask for a flag string or an array of flag strings. */
+ (FxParameterFlags)convertFlags:(nullable id)flags;


/*!
	@method		flattenDictionaryParameters:
	@abstract	Expands nested parameter groups into a flat configuration list, in place.
	@param		parameters	The parameter configurations, mutated in place. */
+ (void)flattenDictionaryParameters:(nullable NSMutableArray<NSMutableDictionary*> *)parameters;

/*!
	@method     applyTargetPresetDefaults:pluginPresets:
	@abstract   Applies each Menu and Toggle parameter's default target preset to the
				parameter configurations.
	@discussion Introduced in FxGrip 0.1.0. Runs on the flattened configuration list before
				any parameter is created, so the initial interface state matches the
				default menu or toggle selection. The parameter's `default` entry indexes
				its target-preset definition; a string definition resolves through
				`pluginPresets`.

				The preset's sections rewrite the configurations in place: `names` sets
				`name`, `flags` and `tags` apply `+`/`-` entries to the string arrays, and
				`values` writes each target's `default` according to its type. An index
				that names no entry applies nothing; this path has no `default` fallback.
	@param      parameters      The flattened configurations, mutated in place.
	@param      pluginPresets   The plugin's preset table, resolving string definitions.
*/
+ (void)applyTargetPresetDefaults:(nullable NSMutableArray<NSMutableDictionary*> *)parameters
					pluginPresets:(nullable NSDictionary *)pluginPresets;

#pragma mark Click Selectors

/*!
	@method     clickSelectorNameForParameter:
	@abstract   Returns the selector name registered with the host for a button parameter.
	@discussion Introduced in FxGrip 0.1.0. The name is `kFxGripClickSelectorPrefix` followed
				by the decimal parameter ID and takes no arguments. The selector is not
				implemented; `FxGripTileableEffect` resolves it at runtime and dispatches
				the click to `-parameterClicked:` with the decoded parameter ID.
*/
+ (nonnull NSString *)clickSelectorNameForParameter:(FxParameterId)parameterID;

/*!
	@method     getParameterID:fromClickSelector:
	@abstract   Decodes the parameter ID from a synthesized click selector.
	@result     YES when the selector matches the synthesized form exactly; the decoded ID
				is assigned to `parameterID`.
*/
+ (BOOL)getParameterID:(nonnull FxParameterId *)parameterID fromClickSelector:(nullable SEL)selector;

@end


#endif
