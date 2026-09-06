/*!
	@file       FxGripCustomParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCustomParameter
	@abstract   The parameter model for a host custom parameter that stores an arbitrary coded object.
	@discussion Introduced in FxGrip 0.1.0. The class registers a custom parameter whose value is an object conforming to NSSecureCoding and NSCopying. It reads and writes the value at a render time. It conforms to FxGripStateParameter and encodes the value into the FxPlug plugin-state coder. A subclass overrides initializeCustomData:parameterID: to seed the default value.
*/

#ifndef FxGripCustomParameter_h
#define FxGripCustomParameter_h

#import "FxGripParameter.h"

/*!
	@protocol	FxGripCustomParameter
	@abstract	The interface a custom parameter exposes for its coded value.
	@discussion	Introduced in FxGrip 0.1.0. The protocol declares the set of permitted data classes and value access at a render time and at time zero.
*/
@protocol FxGripCustomParameter <FxGripParameter>
/*! @abstract The classes the custom value is permitted to be an instance of. */
@property (readonly) NSSet<Class> * _Nonnull dataClasses;

/*! @abstract Reads the custom value at time zero. */
- (id<NSSecureCoding, NSCopying> _Nullable)value;
/*! @abstract Reads the custom value at a render time. */
- (id<NSSecureCoding, NSCopying> _Nullable)valueAtTime:(CMTime)renderTime;
/*! @abstract Writes the custom value at time zero. */
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value;
/*! @abstract Writes the custom value at a render time. */
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value atTime:(CMTime)renderTime;

@end



/*!
	@class		FxGripCustomParameter
	@abstract	The parameter model for a host custom parameter.
	@discussion	Introduced in FxGrip 0.1.0. The class maps the declared configuration to a host custom parameter and exposes its coded value at a render time.
*/
@interface FxGripCustomParameter :
FxGripParameter <FxGripCustomParameter, FxGripStateParameter>

/*!
	@method		initWithDictionary:effect:
	@abstract	Initializes the parameter and populates the permitted data classes.
	@param		dictionary	The parameter configuration dictionary.
	@param		effect		The host that owns the parameter. */
-(instancetype _Nullable) initWithDictionary:(NSDictionary*_Nonnull)dictionary effect:(id<FxGripEffectHost>_Nonnull)effect;

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the custom parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default value is an empty mutable dictionary. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*! @abstract Reads the custom value at time zero. */
- (id<NSSecureCoding, NSCopying> _Nullable)value;
/*! @abstract Reads the custom value at a render time. */
- (id<NSSecureCoding, NSCopying> _Nullable)valueAtTime:(CMTime)renderTime;
/*! @abstract Writes the custom value at time zero. */
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value;
/*! @abstract Writes the custom value at a render time. */
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value atTime:(CMTime)renderTime;

/*! @abstract Encodes the value into the plugin-state coder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
