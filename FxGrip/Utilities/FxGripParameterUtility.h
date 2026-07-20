//
//  FxGripDynamicRegistrar.h
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
 @interface     FxGripParameterConverter
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

@end


#endif
