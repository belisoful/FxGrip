/*!
	@file       FxGripToggleParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripToggleParameter
	@abstract   The parameter model for a host toggle button.
	@discussion Introduced in FxGrip 0.1.0. The class registers a toggle button with the effect's host and reads and writes its boolean value at a render time. The boolValue property reads and writes the value at time zero. The class conforms to FxGripStateParameter and encodes its value into the FxPlug plugin-state coder.
*/

#ifndef FxGripToggleParameter_h
#define FxGripToggleParameter_h

#import "FxGripParameter.h"

/*!
	@protocol	FxGripToggleParameter
	@abstract	The interface a boolean toggle parameter exposes.
	@discussion	Introduced in FxGrip 0.1.0. The protocol declares boolean value access at a render time and at time zero, host registration, and plugin-state encoding.
*/
@protocol FxGripToggleParameter <FxGripParameter>

/*! @abstract Registers the toggle button with the effect's host. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*! @abstract Reads the boolean value at a render time. */
- (BOOL)valueAtTime:(CMTime)renderTime;
/*! @abstract Writes the boolean value at a time. */
- (void)setValue:(BOOL)value atTime:(CMTime)time;

/*! @property boolValue @abstract The value read and written at time zero. */
@property (readwrite, nonatomic) BOOL boolValue;

/*! @abstract Encodes the value into the plugin-state coder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end


/*!
	@class		FxGripToggleParameter
	@abstract	The parameter model for a host toggle button.
	@discussion	Introduced in FxGrip 0.1.0. The class maps the declared configuration to a host toggle button and exposes its boolean value at a render time.
*/
@interface FxGripToggleParameter : FxGripParameter <FxGripToggleParameter, FxGripStateParameter>

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the toggle button with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default value is NO. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*! @abstract Reads the boolean value at a render time. */
- (BOOL)valueAtTime:(CMTime)renderTime;
/*! @abstract Writes the boolean value at a time. */
- (void)setValue:(BOOL)value atTime:(CMTime)time;

/*! @abstract Reads the value at time zero. */
- (BOOL)boolValue;
/*! @abstract Writes the value at time zero. */
- (void)setBoolValue:(BOOL)value;

/*! @abstract Encodes the value into the plugin-state coder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
