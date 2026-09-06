/*!
	@file       FxGripCustomExtension.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCustomExtension
	@abstract   The parameter extension that models a custom-value parameter.
	@discussion Introduced in FxGrip 0.1.0. The class is an FxGripParameterExtension that conforms to
	            FxGripCustomParameter, so the extension both attaches to the effect and holds a
	            secure-codable custom value. The value is read and written directly or at a specific
	            render time. The dataClasses set names the value classes the parameter accepts.
*/

#ifndef FxGripCustomExtension_h
#define FxGripCustomExtension_h

#import "FxGripParameterExtension.h"
#import "FxGripCustomParameter.h"

/*!
	@class		FxGripCustomExtension
	@abstract	The extension that represents a custom-value effect parameter.
	@discussion	Introduced in FxGrip 0.1.0. The extension stores a secure-codable value and vends it
				directly or per render time. Its behavior is drawn from the custom parameter library.
*/
@interface FxGripCustomExtension : FxGripParameterExtension <FxGripCustomParameter>

/*! @abstract The ordered set of value classes the custom parameter accepts. */
@property (readonly, retain, nonnull) NSSet *dataClasses;

/*!
	@method		addParameter:toEffect:
	@abstract	Adds a custom parameter described by the dictionary to the effect.
	@param		parameter	The parameter description dictionary.
	@param		effect		The effect that receives the parameter.
	@return		YES when the parameter is added. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripTileableEffect>)effect;

/*! @abstract The current custom value. */
- (id<NSSecureCoding, NSCopying> _Nullable)value;
/*! @abstract The custom value at a given render time. */
- (id<NSSecureCoding, NSCopying> _Nullable)valueAtTime:(CMTime)renderTime;
/*! @abstract Sets the current custom value. */
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value;
/*! @abstract Sets the custom value at a given render time. */
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value atTime:(CMTime)renderTime;

/*! @abstract Encodes the custom value. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end


#endif
