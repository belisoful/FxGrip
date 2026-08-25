//
//  FxGripInferenceRequest.m
//  FxGrip
//

#import "FxGripInferenceRequest.h"
#import "FxGrip_ARC.h"

@implementation FxGripInferenceRequest

+ (instancetype)requestWithInputs:(NSDictionary<NSString *, id> *)inputs
					   parameters:(nullable NSDictionary<NSString *, id> *)parameters
{
	return NARC_AUTORELEASE([[self alloc] initWithInputs:inputs parameters:parameters]);
}

+ (instancetype)requestWithInputs:(NSDictionary<NSString *, id> *)inputs
{
	return [self requestWithInputs:inputs parameters:nil];
}

- (instancetype)initWithInputs:(NSDictionary<NSString *, id> *)inputs
					parameters:(nullable NSDictionary<NSString *, id> *)parameters
{
	self = [super init];
	if (self != nil) {
		_inputs = [(inputs ?: @{}) copy];
		_parameters = [(parameters ?: @{}) copy];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_inputs);
	NARC_RELEASE(_parameters);
	SUPER_DEALLOC();
}

- (nullable id)inputForKey:(NSString *)key
{
	return key != nil ? _inputs[key] : nil;
}

- (nullable id)parameterForKey:(NSString *)key
{
	return key != nil ? _parameters[key] : nil;
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
	if (![object isKindOfClass:FxGripInferenceRequest.class]) {
		return NO;
	}
	FxGripInferenceRequest *other = object;
	return [other->_inputs isEqualToDictionary:_inputs]
		&& [other->_parameters isEqualToDictionary:_parameters];
}

- (NSUInteger)hash
{
	return _inputs.hash ^ _parameters.hash;
}

@end
