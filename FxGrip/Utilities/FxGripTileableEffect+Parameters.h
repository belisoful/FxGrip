/*!
	@file       FxGripTileableEffect+Parameters.h
	@copyright  Copyright © 2020-2023 Apple, Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+Parameters
	@abstract   The category that maps parameter type strings to classes and builds parameter objects.
	@discussion Introduced in FxGrip 0.1.0. The category conforms the effect to FxParameterFactory.
	            It registers the built-in parameter classes in a type-to-class map keyed by both the
	            numeric type and the type string. It builds a parameter object from a configuration
	            dictionary, delegating to an extension when the record names one. A loaded extension
	            can back a custom type string the built-in map does not know.
*/

#ifndef FxGripTileableEffect_Parameters_h
#define FxGripTileableEffect_Parameters_h

#import "FxGripTileableEffect.h"


/*!
	@abstract	The category that constructs parameter objects and resolves parameter types.
	@discussion	Introduced in FxGrip 0.1.0. The type-to-class map is loaded once during setup and
				resolves both the numeric type and the type string.
*/
@interface FxGripTileableEffect (FxParameters) <FxParameterFactory>

/*!
	@method		parameterForDictionary:
	@abstract	Builds a parameter object from its configuration dictionary.
	@param		data	The parameter configuration record.
	@return		The parameter object, or NULL when the record turns the parameter off or names no valid class.
	@discussion	Introduced in FxGrip 0.1.0. An "off" key in any supported language disables the
				parameter. A record that names an extension key is built by that extension. A record
				that names a class name instantiates that class when it conforms to FxGripParameter. */
- (nullable id)parameterForDictionary:(nullable NSDictionary *)data;

/*! @abstract Registers a parameter class in the type-to-class map under its type and type string. */
- (void)registerParameterType:(nullable Class)paramClass;
/*! @abstract Registers every built-in parameter class in the type-to-class map. */
- (void)loadTypeToClassMap;
/*! @abstract The numeric parameter type for a type string, resolving extension types when needed. */
- (FxParameterType)parameterTypeWithString:(nullable NSString *)typeString;
/*! @abstract The type string for a numeric parameter type. */
- (nullable NSString *)parameterStringWithType:(FxParameterType)type;
/*! @abstract The parameter class for a numeric parameter type. */
- (nullable Class)parameterClassWithType:(FxParameterType)type;
/*! @abstract The parameter class for a type string, resolving extension types when needed. */
- (nullable Class)parameterClassWithTypeString:(nullable NSString *)typeString;


@end


#endif
