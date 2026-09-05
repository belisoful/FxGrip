/**
 *	FxGripToggle.h
 */

#ifndef FxGripParameterExtension_h
#define FxGripParameterExtension_h

#import "FxGripExtension.h"
#import "FxGripParameter.h"


@protocol FxGripParameterExtension <FxGripExtension, FxGripParameter>

@property (readwrite, nonatomic) FxParameterId parameterID;

- (nullable id) parameterForDictionary:(nonnull NSDictionary *)data;

@end


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




#endif
