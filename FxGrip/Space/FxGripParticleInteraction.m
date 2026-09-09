/*!
	@file       FxGripParticleInteraction.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripParticleInteraction
	@abstract   Implements the inter-particle force configuration value object.
	@discussion Introduced in FxGrip 0.1.0. The accuracy tier maps to the multipole order and
	            acceptance ratio the Fast Multipole Method uses. The object archives and copies its
	            whole state so a system that carries it stays configured across an archive or a copy.
*/

#import "FxGripParticleInteraction.h"

static NSString * const kEnabled = @"enabled";
static NSString * const kKind = @"kind";
static NSString * const kGravity = @"gravityStrength";
static NSString * const kElectric = @"electricStrength";
static NSString * const kMagnetic = @"magneticStrength";
static NSString * const kSoftening = @"softening";
static NSString * const kAccuracy = @"accuracy";

@implementation FxGripParticleInteraction

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_enabled = NO;
		_kind = FxGripParticleInteractionKindNone;
		_gravityStrength = 1.0;
		_electricStrength = 1.0;
		_magneticStrength = 1.0;
		_softening = 0.01;
		_accuracy = FxGripParticleInteractionAccuracyStandard;
	}
	return self;
}

+ (instancetype)gravityWithStrength:(CGFloat)strength
{
	FxGripParticleInteraction *interaction = [[self alloc] init];
	interaction.enabled = YES;
	interaction.kind = FxGripParticleInteractionKindGravity;
	interaction.gravityStrength = strength;
	return interaction;
}

- (uint32_t)expansionOrder
{
	switch (self.accuracy) {
		case FxGripParticleInteractionAccuracyDraft: return 2u;
		case FxGripParticleInteractionAccuracyFine:  return 6u;
		case FxGripParticleInteractionAccuracyStandard:
		default: return 4u;
	}
}

- (float)theta
{
	switch (self.accuracy) {
		case FxGripParticleInteractionAccuracyDraft: return 0.7f;
		case FxGripParticleInteractionAccuracyFine:  return 0.4f;
		case FxGripParticleInteractionAccuracyStandard:
		default: return 0.5f;
	}
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	FxGripParticleInteraction *copy = [[FxGripParticleInteraction allocWithZone:zone] init];
	copy->_enabled = _enabled;
	copy->_kind = _kind;
	copy->_gravityStrength = _gravityStrength;
	copy->_electricStrength = _electricStrength;
	copy->_magneticStrength = _magneticStrength;
	copy->_softening = _softening;
	copy->_accuracy = _accuracy;
	return copy;
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [self init];
	if (self != nil) {
		_enabled = [coder decodeBoolForKey:kEnabled];
		_kind = (FxGripParticleInteractionKind)[coder decodeIntegerForKey:kKind];
		_gravityStrength = [coder decodeDoubleForKey:kGravity];
		_electricStrength = [coder decodeDoubleForKey:kElectric];
		_magneticStrength = [coder decodeDoubleForKey:kMagnetic];
		_softening = [coder decodeDoubleForKey:kSoftening];
		_accuracy = (FxGripParticleInteractionAccuracy)[coder decodeIntegerForKey:kAccuracy];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeBool:_enabled forKey:kEnabled];
	[coder encodeInteger:(NSInteger)_kind forKey:kKind];
	[coder encodeDouble:_gravityStrength forKey:kGravity];
	[coder encodeDouble:_electricStrength forKey:kElectric];
	[coder encodeDouble:_magneticStrength forKey:kMagnetic];
	[coder encodeDouble:_softening forKey:kSoftening];
	[coder encodeInteger:(NSInteger)_accuracy forKey:kAccuracy];
}

@end
