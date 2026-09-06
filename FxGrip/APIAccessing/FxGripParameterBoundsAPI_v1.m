/*!
	@file       FxGripParameterBoundsAPI_v1.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterBoundsAPI_v1
	@abstract   Implements the single-edge bounds setters over Apple's dynamic-parameter API.
	@discussion Introduced in FxGrip 0.1.0. Each setter reads the parameter's current minimum,
	            maximum, and slider range through the host FxDynamicParameterAPI_v3, changes the one
	            edge the caller named, and writes the full range back. A read error is returned and
	            the write is skipped.
*/

#import "FxGripParameterBoundsAPI_v1.h"

/*!
	@abstract	FxGrip's single-edge parameter-bounds setters.
	@discussion	Introduced in FxGrip 0.1.0. Reads the current range through the host API and writes
				it back with one edge changed.
*/
@implementation FxGripParameterBoundsAPI_v1

- (nullable instancetype)initWithAPI:(id<FxDynamicParameterAPI_v3> _Nullable)api
							  effect:(nonnull id<FxGripEffectHost>)effect
{
	self = [super initWithEffect:effect];
	if (self != nil) {
		_api = api;
	}
	return self;
}

#pragma mark - Float

- (NSError *)setParameter:(UInt32)parameterID floatMinimum:(double)min
{
	double oldMin = 0, max = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self.api parameter:parameterID
						   floatMinimum:&oldMin maximum:&max
						  sliderMinimum:&sliderMin sliderMaximum:&sliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						 floatMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID floatMaximum:(double)max
{
	double min = 0, oldMax = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self.api parameter:parameterID
						   floatMinimum:&min maximum:&oldMax
						  sliderMinimum:&sliderMin sliderMaximum:&sliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						 floatMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID floatMinimum:(double)min maximum:(double)max
{
	double oldMin = 0, oldMax = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self.api parameter:parameterID
						   floatMinimum:&oldMin maximum:&oldMax
						  sliderMinimum:&sliderMin sliderMaximum:&sliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						 floatMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID floatSliderMinimum:(double)sliderMin
{
	double min = 0, max = 0, oldSliderMin = 0, sliderMax = 0;
	NSError *error = [self.api parameter:parameterID
						   floatMinimum:&min maximum:&max
						  sliderMinimum:&oldSliderMin sliderMaximum:&sliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						 floatMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID floatSliderMaximum:(double)sliderMax
{
	double min = 0, max = 0, sliderMin = 0, oldSliderMax = 0;
	NSError *error = [self.api parameter:parameterID
						   floatMinimum:&min maximum:&max
						  sliderMinimum:&sliderMin sliderMaximum:&oldSliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						 floatMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID floatSliderMinimum:(double)sliderMin sliderMaximum:(double)sliderMax
{
	double min = 0, max = 0, oldSliderMin = 0, oldSliderMax = 0;
	NSError *error = [self.api parameter:parameterID
						   floatMinimum:&min maximum:&max
						  sliderMinimum:&oldSliderMin sliderMaximum:&oldSliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						 floatMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

#pragma mark - Int

- (NSError *)setParameter:(UInt32)parameterID intMinimum:(int)min
{
	int oldMin = 0, max = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self.api parameter:parameterID
							 intMinimum:&oldMin maximum:&max
						  sliderMinimum:&sliderMin sliderMaximum:&sliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						   intMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID intMaximum:(int)max
{
	int min = 0, oldMax = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self.api parameter:parameterID
							 intMinimum:&min maximum:&oldMax
						  sliderMinimum:&sliderMin sliderMaximum:&sliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						   intMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID intMinimum:(int)min maximum:(int)max
{
	int oldMin = 0, oldMax = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self.api parameter:parameterID
							 intMinimum:&oldMin maximum:&oldMax
						  sliderMinimum:&sliderMin sliderMaximum:&sliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						   intMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID intSliderMinimum:(int)sliderMin
{
	int min = 0, max = 0, oldSliderMin = 0, sliderMax = 0;
	NSError *error = [self.api parameter:parameterID
							 intMinimum:&min maximum:&max
						  sliderMinimum:&oldSliderMin sliderMaximum:&sliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						   intMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID intSliderMaximum:(int)sliderMax
{
	int min = 0, max = 0, sliderMin = 0, oldSliderMax = 0;
	NSError *error = [self.api parameter:parameterID
							 intMinimum:&min maximum:&max
						  sliderMinimum:&sliderMin sliderMaximum:&oldSliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						   intMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID intSliderMinimum:(int)sliderMin sliderMaximum:(int)sliderMax
{
	int min = 0, max = 0, oldSliderMin = 0, oldSliderMax = 0;
	NSError *error = [self.api parameter:parameterID
							 intMinimum:&min maximum:&max
						  sliderMinimum:&oldSliderMin sliderMaximum:&oldSliderMax];
	if (!error) {
		error = [self.api setParameter:parameterID
						   intMinimum:min maximum:max
						sliderMinimum:sliderMin sliderMaximum:sliderMax];
	}
	return error;
}

@end
