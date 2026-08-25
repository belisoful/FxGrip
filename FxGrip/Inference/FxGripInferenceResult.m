//
//  FxGripInferenceResult.m
//  FxGrip
//

#import "FxGripInferenceResult.h"
#import "FxGrip_ARC.h"

@implementation FxGripInferenceResult

+ (instancetype)resultWithOutputs:(NSDictionary<NSString *, id> *)outputs
{
	return NARC_AUTORELEASE([[self alloc] initWithOutputs:outputs]);
}

- (instancetype)initWithOutputs:(NSDictionary<NSString *, id> *)outputs
{
	self = [super init];
	if (self != nil) {
		_outputs = [(outputs ?: @{}) copy];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_outputs);
	SUPER_DEALLOC();
}

- (nullable id)outputForKey:(NSString *)key
{
	return key != nil ? _outputs[key] : nil;
}

- (id)copyWithZone:(NSZone *)zone
{
	// Immutable.
	return NARC_RETAIN(self);
}

- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if (![object isKindOfClass:FxGripInferenceResult.class]) {
		return NO;
	}
	FxGripInferenceResult *other = object;
	return [other->_outputs isEqualToDictionary:_outputs];
}

- (NSUInteger)hash
{
	return _outputs.hash;
}

@end
