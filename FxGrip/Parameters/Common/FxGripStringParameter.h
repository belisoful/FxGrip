/*!
	@file       FxGripStringParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripStringParameter
	@abstract   The parameter model for a host string parameter.
	@discussion Introduced in FxGrip 0.1.0. The base class FxGripStringParameterBase reads and writes the string value and encodes it into the FxPlug plugin-state coder. FxGripStringParameter adds host registration for a plain string field. FxGripFontMenuParameter derives from the base class.
*/

#ifndef FxGripStringParameter_h
#define FxGripStringParameter_h

#import "FxGripParameter.h"


/*!
	@class		FxGripStringParameterBase
	@abstract	The base string parameter model that reads, writes, and encodes a string value.
	@discussion	Introduced in FxGrip 0.1.0. The class exposes the string value without declaring its own host registration. A subclass registers the concrete host control.
*/
@interface FxGripStringParameterBase : FxGripParameter <FxGripStateParameter>

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;

/*!
	@method		valueAtTime:
	@abstract	Reads the string value at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The string value. The string parameter reads the current value regardless of time. */
- (nullable NSString*)valueAtTime:(CMTime)renderTime;
/*! @abstract Writes the string value at a time. */
- (void)setValue:(NSString*_Nullable)value atTime:(CMTime)time;

/*!
	@property	stringValue
	@abstract	The current string value.
	@discussion	Introduced in FxGrip 0.1.0. Reads and writes return nil and perform no work until the parameter is added to an effect. A nil write stores an empty string. */
@property (readwrite, nullable, nonatomic) NSString* stringValue;

/*! @abstract Encodes the string value into the plugin-state coder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

//
/*!
	@class		FxGripStringParameter
	@abstract	The parameter model for a host string field.
	@discussion	Introduced in FxGrip 0.1.0. The class adds host registration for a plain string field to FxGripStringParameterBase.
*/
@interface FxGripStringParameter : FxGripStringParameterBase //NSSecureCoding NSCopying

/*!
	@method		addParameter:toEffect:
	@abstract	Registers the string field with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default value is localized before registration. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif
