/*!
	@file       FxGripParameterExtension.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterExtension
	@abstract   The base extension that is itself an effect parameter.
	@discussion Introduced in FxGrip 0.1.0. The class is an FxGripExtension that also conforms to
	            FxGripParameter, so a single object both attaches to the effect and behaves as one of its
	            parameters. When it loads, it observes the parameter-add notification and tags the added
	            parameter with its extension key. The parameter ID is frozen from the first observed add.
	            Subclasses replicate a concrete parameter type through the included parameter libraries.
*/

#ifndef FxGripParameterExtension_h
#define FxGripParameterExtension_h

#import "FxGripExtension.h"
#import "FxGripParameter.h"


/*!
	@protocol	FxGripParameterExtension
	@abstract   The parameter-extension interface, combining the extension and parameter protocols.
	@discussion	Introduced in FxGrip 0.1.0. A conforming object carries a parameter ID and builds itself
				from a parameter dictionary.
*/
@protocol FxGripParameterExtension <FxGripExtension, FxGripParameter>

/*! @abstract The ID of the parameter this extension represents. */
@property (readwrite, nonatomic) FxParameterId parameterID;

/*! @abstract Configures the extension from a parameter dictionary and returns itself. */
- (nullable id) parameterForDictionary:(nonnull NSDictionary *)data;

@end


/*!
	@class		FxGripParameterExtension
	@abstract	The extension that participates in the effect as one of its parameters.
	@discussion	Introduced in FxGrip 0.1.0. The class attaches to the effect's notifier during load and
				tags its parameter with the extension key as the parameter registers. The parameter type
				and the plain addParameter path are unavailable; subclasses adopt a concrete type through
				the included parameter libraries.
*/
//This is an extension that is itself a parameter
@interface FxGripParameterExtension : FxGripExtension <FxGripParameter, FxGripParameterExtension>
{
	BOOL					_addedToEffect;

	@protected
	FxParameterId			_parameterID;
	FxParameterFlags		_parameterFlags;
	NSError*				_error;
	NSMutableDictionary*	_data;
}
- (instancetype _Nullable)init;


//FxGripParameterLirary

/*! @abstract YES when the parameter carries persistent state. */
- (BOOL)hasState;
/*! @abstract The parameter's display name. */
- (NSString*_Nonnull)parameterName;
/*! @abstract Sets the parameter's display name. */
- (void)setParameterName:(NSString*_Nonnull)name;

/*! @abstract Unavailable; the base extension declares no concrete parameter type. */
- (FxParameterType)parameterType NS_UNAVAILABLE;

/*! @abstract The parameter's flags. */
- (FxParameterFlags)parameterFlags;
/*! @abstract Sets the parameter's flags. */
- (void)setParameterFlags:(FxParameterFlags)flags;

/*! @abstract Unavailable; the extension registers its parameter through the notification seam. */
- (BOOL)addParameter NS_UNAVAILABLE;

/*! @abstract Clears the cached parameter data. */
- (void)parameterFlush;
/*! @abstract Records the flags and parent ID assigned when the parameter is created. */
- (void)createdWithFlags:(FxParameterFlags)flags parentID:(FxParameterId)parentID;
/*! @abstract Sets the parameter's parent group ID. */
- (void)setParameterParentID:(FxParameterId)parentID;

// Coder

/*! @abstract Encodes the parameter's state. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;
/*! @abstract Decodes the parameter's state. */
- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder;
/*! @abstract Returns YES; the class supports secure coding. */
+ (BOOL)supportsSecureCoding;
@end




#endif
