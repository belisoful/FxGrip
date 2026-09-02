//
//  FxGripParameterUtility.h
//  XPC Service
//
//  Created on 3/11/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxParameterFactory_h
#define FxParameterFactory_h

#import <Foundation/Foundation.h>
#import <FxGrip/FxParameterFlags.h>
#import <FxGrip/FxGripTypes.h>

@protocol FxParameter;

@protocol FxParameterFactory <NSObject>

- (nullable id<FxParameter>)parameterForDictionary:(nonnull NSDictionary *)data;

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
+ (NSDictionary<NSString*, NSNumber*>*_Nonnull)parameterTypes;
+ (NSDictionary<NSNumber*, NSString*>*_Nonnull)typeParameters;

// The maps of the parameter flags <=> string, eg. hidden, disabled, dontsave, ignore_minmax
+ (NSDictionary<NSString*, NSNumber*>*_Nonnull)flagValues;
+ (NSDictionary<NSNumber*, NSString*>*_Nonnull)valueFlags;

// Convert types to strings and strings to types
+ (FxParameterType)parameterTypeFromString:(NSString*_Nullable)type;
+ (NSString* _Nullable)parameterTypeString:(FxParameterType)type;

// convert a flag to its string, and a set of flags to an array of strings
//	and visa versa.
+ (NSString* _Nullable) convertToFlag:(FxParameterFlags)flag;
+ (NSArray<NSString*>*_Nonnull) convertToFlags:(FxParameterFlags)flag;
+ (FxParameterFlags)convertFlag:(nullable NSString*)flag;
+ (FxParameterFlags)convertFlags:(nullable id)flags;


+ (void)flattenDictionaryParameters:(nullable NSMutableArray<NSMutableDictionary*> *)parameters;

/*!
	@method     applyTargetPresetDefaults:pluginPresets:
	@abstract   Applies each Menu and Toggle parameter's default target preset to the
				parameter configurations.
	@discussion Introduced in FxGrip 1.0. Runs on the flattened configuration list before
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
	@discussion Introduced in FxGrip 1.0. The name is `kFxGripClickSelectorPrefix` followed
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
