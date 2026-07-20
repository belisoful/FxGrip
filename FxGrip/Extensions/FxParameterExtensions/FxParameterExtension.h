/**
 *	FxGripToggle.h
 */

#ifndef FxParameterExtension_h
#define FxParameterExtension_h

#import "FxExtension.h"
#import "FxParameter.h"


@protocol FxParameterExtension <FxExtension, FxParameter>

@property (readwrite, nonatomic) FxParameterId parameterID;

- (nullable id) parameterForDictionary:(nonnull NSDictionary *)data;

@end


//This is an extension that is itself a parameter
@interface FxParameterExtension : FxExtension <FxParameter, FxParameterExtension>
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

- (BOOL)hasState;
- (NSString*_Nonnull)parameterName;
- (void)setParameterName:(NSString*_Nonnull)name;

- (FxParameterType)parameterType NS_UNAVAILABLE;

- (FxParameterFlags)parameterFlags;
- (void)setParameterFlags:(FxParameterFlags)flags;

- (BOOL)addParameter NS_UNAVAILABLE;

- (void)parameterFlush;
- (void)createdWithFlags:(FxParameterFlags)flags parentID:(FxParameterId)parentID;
- (void)setParameterParentID:(FxParameterId)parentID;

// Coder

- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;
- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder;
+ (BOOL)supportsSecureCoding;
@end



/*
@interface FxGripExtensionCustomParameter : FxGripExtensionParameter <FxGripCustomParameterProtocol>

- (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull GuruFxTileableEffect *)effect;

- (id<NSSecureCoding, NSCopying> _Nullable)value;
- (id<NSSecureCoding, NSCopying> _Nullable)valueAtTime:(CMTime)renderTime;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value atTime:(CMTime)renderTime;

- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end




@interface FxGripExtensionToggleParameter : FxGripExtensionParameter <FxGripToggleParameterProtocol>


@end

*/

#endif
