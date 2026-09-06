/*!
	@file       FxGripInferenceResult.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInferenceResult
	@abstract   Implements the immutable result value: the model's named outputs.
	@discussion Introduced in FxGrip 0.1.0. The initializer copies the outputs, mapping nil to an
	            empty dictionary. The value is immutable, so copyWithZone: returns self. Equality and
	            hash compare the outputs dictionary.
*/

#import "FxGripInferenceResult.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The immutable output of one inference run: the model's named outputs.
	@discussion	Introduced in FxGrip 0.1.0. The value copies its dictionary at initialization and is
				equal to another result with equal outputs.
*/
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
