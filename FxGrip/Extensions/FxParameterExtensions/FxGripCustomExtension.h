/**
 *	FxGripToggle.h
 */

#ifndef FxGripCustomExtension_h
#define FxGripCustomExtension_h

#import "FxParameterExtension.h"
#import "FxGripCustomParameter.h"

@interface FxGripCustomExtension : FxParameterExtension <FxGripCustomParameter>

@property (readonly, retain, nonnull) NSSet *dataClasses;

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect;

- (id<NSSecureCoding, NSCopying> _Nullable)value;
- (id<NSSecureCoding, NSCopying> _Nullable)valueAtTime:(CMTime)renderTime;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value atTime:(CMTime)renderTime;

- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end


#endif
