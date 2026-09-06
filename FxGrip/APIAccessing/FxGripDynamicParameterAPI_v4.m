/*!
	@file       FxGripDynamicParameterAPI_v4.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDynamicParameterAPI_v4
	@abstract   Implements the FxGrip dynamic-parameter additions over the v3 wrapper.
	@discussion Introduced in FxGrip 0.1.0. The single-edge bounds setters read the current range
	            and write it back with one edge changed. parameterType and parameter:entries:
	            resolve their answer from the notification observers. parameterExists and
	            allParameterIDs walk the parameter roster by index. The metadata methods forward to
	            the host's meta manager and answer a not-found result when the host has none.
*/

#import "FxGripDynamicParameterAPI_v4.h"
#import "FxGripPreset.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripAPINotifications.h"
#import "FxGripMeta.h"
#import "FxGripErrors.h"


/*!
	@abstract	FxGrip's dynamic-parameter additions over the v3 wrapper.
	@discussion	Introduced in FxGrip 0.1.0. Adds single-edge bounds setters, parameter existence
				and type queries, menu-entry retrieval, and metadata forwarding.
*/
@implementation FxGripDynamicParameterAPI_v4


#pragma mark -
#pragma mark FxDynamicParameterAPI_v3 Extension
#pragma mark Setting Parameter individual Min/Max & Slider

- (NSError *)setParameter:(UInt32)parameterID floatMinimum:(double)min
{
	double oldMin = 0, max = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self parameter:parameterID
						floatMinimum:&oldMin
							 maximum:&max
					   sliderMinimum:&sliderMin
					   sliderMaximum:&sliderMax];
	if (!error) {
		error = [self setParameter:parameterID
					  floatMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID floatMaximum:(double)max
{
	double min = 0, oldMax = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self parameter:parameterID
						floatMinimum:&min
							 maximum:&oldMax
					   sliderMinimum:&sliderMin
					   sliderMaximum:&sliderMax];
	if (!error) {
		error = [self setParameter:parameterID
					  floatMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID
			 floatMinimum:(double)min
				  maximum:(double)max
{
	
	double oldMin = 0, oldMax = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self parameter:parameterID
						floatMinimum:&oldMin
							 maximum:&oldMax
					   sliderMinimum:&sliderMin
					   sliderMaximum:&sliderMax];
	if (!error) {
		error = [self setParameter:parameterID
					  floatMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID floatSliderMinimum:(double)sliderMin
{
	double min = 0, max = 0, oldSliderMin = 0, sliderMax = 0;
	NSError *error = [self parameter:parameterID
						floatMinimum:&min
							 maximum:&max
					   sliderMinimum:&oldSliderMin
					   sliderMaximum:&sliderMax];
	if (!error) {
		error = [self setParameter:parameterID
					  floatMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID floatSliderMaximum:(double)sliderMax
{
	double min = 0, max = 0, sliderMin = 0, oldSliderMax = 0;
	NSError *error = [self parameter:parameterID
						floatMinimum:&min
							 maximum:&max
					   sliderMinimum:&sliderMin
					   sliderMaximum:&oldSliderMax];
	if (!error) {
		error = [self setParameter:parameterID
					  floatMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID
	   floatSliderMinimum:(double)sliderMin
			sliderMaximum:(double)sliderMax
{
	double min = 0, max = 0, oldSliderMin = 0, oldSliderMax = 0;
	NSError *error = [self parameter:parameterID
						floatMinimum:&min
							 maximum:&max
					   sliderMinimum:&oldSliderMin
					   sliderMaximum:&oldSliderMax];
	if (!error) {
		error = [self setParameter:parameterID
					  floatMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID intMinimum:(int)min
{
	int oldMin = 0, max = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self parameter:parameterID
						  intMinimum:&oldMin
							 maximum:&max
					   sliderMinimum:&sliderMin
					   sliderMaximum:&sliderMax];
	if (!error) {
		error = [self setParameter:parameterID
						intMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID intMaximum:(int)max
{
	int min = 0, oldMax = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self parameter:parameterID
						  intMinimum:&min
							 maximum:&oldMax
					   sliderMinimum:&sliderMin
					   sliderMaximum:&sliderMax];
	if (!error) {
		error = [self setParameter:parameterID
						intMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}
- (NSError *)setParameter:(UInt32)parameterID intMinimum:(int)min maximum:(int)max
{
	int oldMin = 0, oldMax = 0, sliderMin = 0, sliderMax = 0;
	NSError *error = [self parameter:parameterID
						  intMinimum:&oldMin
							 maximum:&oldMax
					   sliderMinimum:&sliderMin
					   sliderMaximum:&sliderMax];
	if (!error) {
		error = [self setParameter:parameterID
						intMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID intSliderMinimum:(int)sliderMin
{
	int min = 0, max = 0, oldSliderMin = 0, sliderMax = 0;
	NSError *error = [self parameter:parameterID
						  intMinimum:&min
							 maximum:&max
					   sliderMinimum:&oldSliderMin
					   sliderMaximum:&sliderMax];
	if (!error) {
		error = [self setParameter:parameterID
						intMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID intSliderMaximum:(int)sliderMax
{
	int min = 0, max = 0, sliderMin = 0, oldSliderMax = 0;
	NSError *error = [self parameter:parameterID
						  intMinimum:&min
							 maximum:&max
					   sliderMinimum:&sliderMin
					   sliderMaximum:&oldSliderMax];
	if (!error) {
		error = [self setParameter:parameterID
						intMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID intSliderMinimum:(int)sliderMin sliderMaximum:(int)sliderMax
{
	int min = 0, max = 0, oldSliderMin = 0, oldSliderMax = 0;
	NSError *error = [self parameter:parameterID
						  intMinimum:&min
							 maximum:&max
					   sliderMinimum:&oldSliderMin
					   sliderMaximum:&oldSliderMax];
	if (!error) {
		error = [self setParameter:parameterID
						intMinimum:min
						   maximum:max
					 sliderMinimum:sliderMin
					 sliderMaximum:sliderMax];
	}
	return error;
}

#pragma mark -
#pragma mark Parameter Type

/*! @abstract Returns YES when a parameter with the given ID is in the roster. */
- (BOOL)parameterExists:(FxParameterId)parameterID
{
	UInt32 count = [self parameterCount];
	
	for (int i = 0; i < count; i++) {
		FxParameterId pid = [self parameterIDAtIndex:i];
		
		if (pid == parameterID)
			return YES;
	}
	
	return NO;
}

/*! @abstract Returns a parameter's type, resolved from the notification observers. */
- (FxParameterType)parameterType:(FxParameterId)parameterID
{
	NSMutableDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey:@{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Type: @0
			}.mutableCopy
		}.mutableCopy;
	[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterGetTypeName object:self.effect userInfo:userInfo];
	return ((NSNumber*)userInfo.fxParameter[kFxParameterProperty_Type]).intValue;
}


/*! @abstract Fills entries with a menu parameter's items, gathered from the notification observers. */
// Gets the menu entries
- (NSError*)parameter:(FxParameterId)parameterID entries:(NSArray<NSString*>**_Nonnull)entries
{
	NSMutableDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey:@{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_MenuItems: @[]
			}.mutableCopy
		}.mutableCopy;
	[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterGetMenuName object:self.effect userInfo:userInfo];
	*entries = userInfo.fxParameter[kFxParameterProperty_MenuItems];
	
	return userInfo.fxError;
}


/*! @abstract Returns every parameter ID in the roster, in index order. */
- (NSArray<NSNumber*>*)allParameterIDs
{
	UInt32			count = [self parameterCount];
	NSMutableArray	*ids = [NSMutableArray arrayWithCapacity:count];
	
	for (int i = 0; i < count; i++) {
		[ids addObject:@([self parameterIDAtIndex:i])];
	}
	
	return [ids copy];
}


#pragma mark -
#pragma mark Meta API

#define hasMeta(returnValue) { if (!self.hostHasMeta) return (returnValue); }
#define noMetaError(parameterID) ([NSError errorWithDomain:FxGripPlugErrorDomain \
	code:kFxError_ThirdPartyDeveloperStart + (parameterID) \
	userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"No meta manager for parameter (%u).", (parameterID)] }])

- (SInt32)metaCountFromParameter:(FxParameterId)parameterID
{
	hasMeta(-1);
	return [self.hostMeta metaCountFromParameter:parameterID];
}

- (NSError *)getMeta:(NSDictionary **)meta fromParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta getMeta:meta fromParameter:parameterID];
}

- (NSError *)setMeta:(NSDictionary *)meta toParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta setMeta:meta toParameter:parameterID];
}

- (NSError *)getMetaKeys:(NSArray **)keys fromParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta getMetaKeys:keys fromParameter:parameterID];
}

- (NSError *)removeAllMeta:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta removeAllMeta:parameterID];
}

- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString *)key error:(NSError **)error
{
	if (!self.hostHasMeta) {
		if (error) {
			*error = noMetaError(parameterID);
		}
		return NO;
	}
	return [self.hostMeta parameter:parameterID hasMetaKey:key error:error];
}

- (BOOL)getMeta:(id<NSSecureCoding,NSCopying> *)value forKey:(NSString *)key fromParameter:(FxParameterId)parameterID
{
	hasMeta(NO);
	return [self.hostMeta getMeta:(NSObject<NSSecureCoding,NSCopying>**)value
													   forKey:key fromParameter:parameterID];
}

- (BOOL)setMeta:(id<NSSecureCoding,NSCopying>)value forKey:(NSString *)key toParameter:(FxParameterId)parameterID
{
	hasMeta(NO);
	return [self.hostMeta setMeta:(NSObject<NSSecureCoding,NSCopying>*)value
													   forKey:key toParameter:parameterID];
}

- (BOOL)removeMetaKey:(NSString *)key fromParameter:(FxParameterId)parameterID
{
	hasMeta(NO);
	return [self.hostMeta removeMetaKey:key fromParameter:parameterID];
}

@end
