//
//  MasterFXAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripDynamicParameterAPI_v4.h"
#import "FxGripPreset.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
//#import "GuruFxTileableEffect+Extensions.h"
#import "FxAPINotifications.h"
#import "FxGripMeta.h"
#import "FxGripErrors.h"


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

- (FxParameterType)parameterType:(FxParameterId)parameterID
{
	NSMutableDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxNotifyAPI_ParameterKey:@{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Type: @0
			}.mutableCopy
		}.mutableCopy;
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterGetTypeName object:self.effect userInfo:userInfo];
	return ((NSNumber*)userInfo.fxParameter[kFxParameterProperty_Type]).intValue;
}


// Gets the menu entries
- (NSError*)parameter:(FxParameterId)parameterID entries:(NSArray<NSString*>**_Nonnull)entries
{
	NSMutableDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxNotifyAPI_ParameterKey:@{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_MenuItems: @[]
			}.mutableCopy
		}.mutableCopy;
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterGetMenuName object:self.effect userInfo:userInfo];
	*entries = userInfo.fxParameter[kFxParameterProperty_MenuItems];
	
	return userInfo.fxError;
}


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

#define hasMeta(returnValue) { if (!FxGripHostHasMeta(self.effect)) return (returnValue); }
#define noMetaError(parameterID) ([NSError errorWithDomain:FxGripPlugErrorDomain \
	code:kFxError_ThirdPartyDeveloperStart + (parameterID) \
	userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"No meta manager for parameter (%u).", (parameterID)] }])

- (SInt32)metaCountFromParameter:(FxParameterId)parameterID
{
	hasMeta(-1);
	return [FxGripHostMeta(self.effect) metaCountFromParameter:parameterID];
}

- (NSError *)getMeta:(NSDictionary **)meta fromParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [FxGripHostMeta(self.effect) getMeta:meta fromParameter:parameterID];
}

- (NSError *)setMeta:(NSDictionary *)meta toParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [FxGripHostMeta(self.effect) setMeta:meta toParameter:parameterID];
}

- (NSError *)getMetaKeys:(NSArray **)keys fromParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [FxGripHostMeta(self.effect) getMetaKeys:keys fromParameter:parameterID];
}

- (NSError *)removeAllMeta:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [FxGripHostMeta(self.effect) removeAllMeta:parameterID];
}

- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString *)key error:(NSError **)error
{
	if (!FxGripHostHasMeta(self.effect)) {
		if (error) {
			*error = noMetaError(parameterID);
		}
		return NO;
	}
	return [FxGripHostMeta(self.effect) parameter:parameterID hasMetaKey:key error:error];
}

- (BOOL)getMeta:(id<NSSecureCoding,NSCopying> *)value forKey:(NSString *)key fromParameter:(FxParameterId)parameterID
{
	hasMeta(NO);
	return [FxGripHostMeta(self.effect) getMeta:(NSObject<NSSecureCoding,NSCopying>**)value
													   forKey:key fromParameter:parameterID];
}

- (BOOL)setMeta:(id<NSSecureCoding,NSCopying>)value forKey:(NSString *)key toParameter:(FxParameterId)parameterID
{
	hasMeta(NO);
	return [FxGripHostMeta(self.effect) setMeta:(NSObject<NSSecureCoding,NSCopying>*)value
													   forKey:key toParameter:parameterID];
}

- (BOOL)removeMetaKey:(NSString *)key fromParameter:(FxParameterId)parameterID
{
	hasMeta(NO);
	return [FxGripHostMeta(self.effect) removeMetaKey:key fromParameter:parameterID];
}

@end
