//
//  FxGripParameterCreationAPI_v5.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripParameterFlags.h"
#import "FxGripParameterRetrievalAPI_v6.h"
#import "FxGripInterpolatingDictionary.h"
#import "FxGripParameterInfoAPI_v1.h"
#import "FxGripTileableEffect.h"
#import "FxGripCustomViewData.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripAPINotifications.h"

#import <FxGrip_ARC.h>

@implementation FxGripParameterRetrievalAPI_v6

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPI:(id<FxParameterRetrievalAPI_v6>)api
				   parameterInfoAPIv1:(id<FxGripParameterInfoAPI_v1>)parameterInfoAPIv1
							  effect:(id<FxGripEffectHost>)effect

{
	self = [super initWithEffect:effect];
	
	if (self != nil)
	{
		_api = api;
		_parameterInfoAPIv1 = parameterInfoAPIv1;
	}
	return self;
}

- (void)dealloc
{
	SUPER_DEALLOC();
}


- (BOOL)getBoolValue:(nonnull BOOL *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_api getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(getBoolValue:)]) {
			return [(id<FxGripMutableParameter>)customValue getBoolValue:value];
		}
	}
	return [_api getBoolValue:value fromParameter:parameterID atTime:time];
}

- (BOOL)getCustomParameterValue:(NSObject<NSSecureCoding,NSCopying> * _Nullable * _Nonnull)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	BOOL success = [_api getCustomParameterValue:value fromParameter:parameterID atTime:time];
	if (success && value != nil && *value != nil) {
		if ([*value conformsToProtocol:@protocol(FxGripCustomViewData)]) {
			NSObject<NSSecureCoding, NSCopying, FxGripCustomViewData> *customValue = (id)*value;
			//customValue.parameterView = [self.effect viewForParameterID:parameterID];
			customValue.parameterEffect = self.effect;
		}
	}
	return success;
}

- (BOOL)getFloatValue:(nonnull double *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_api getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(getFloatValue:)]) {
			return [(id<FxGripMutableParameter>)customValue getFloatValue:value];
		}
	}
	return [_api getFloatValue:value fromParameter:parameterID atTime:time];
}

- (BOOL)getFontName:(NSString * _Nullable * _Nonnull)fontName fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_api getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(getFontName:)]) {
			return [(id<FxGripMutableParameter>)customValue getFontName:fontName];
		}
	}
	return [_api getFontName:fontName fromParameter:parameterID atTime:time];
}

- (BOOL)getGradientSamples:(nonnull void *)samples numSamples:(NSUInteger)numSamples depth:(FxDepth)sampleDepth fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_api getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(getGradientSamples:numSamples:depth:)]) {
			return [(id<FxGripMutableParameter>)customValue getGradientSamples:samples numSamples:numSamples depth:sampleDepth];
		}
	}
	return [_api getGradientSamples:samples numSamples:numSamples depth:sampleDepth fromParameter:parameterID atTime:time];
}

- (BOOL)getHistogramBlackIn:(nonnull double *)blackIn BlackOut:(nonnull double *)blackOut WhiteIn:(nonnull double *)whiteIn WhiteOut:(nonnull double *)whiteOut Gamma:(nonnull double *)gamma forChannel:(FxHistogramChannel)channel fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_api getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(getHistogramBlackIn:blackOut:whiteIn:whiteOut:gamma:forChannel:)]) {
			return [(id<FxGripMutableParameter>)customValue getHistogramBlackIn:blackIn
																	   blackOut:blackOut
																		whiteIn:whiteIn
																	   whiteOut:whiteOut
																		  gamma:gamma
																	 forChannel:channel];
		}
	}
	return [_api getHistogramBlackIn:blackIn
							BlackOut:blackOut
							 WhiteIn:whiteIn
							WhiteOut:whiteOut
							   Gamma:gamma
						  forChannel:channel
					   fromParameter:parameterID
							  atTime:time];
}

- (BOOL)getIntValue:(nonnull int *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_api getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(getIntValue:)]) {
			return [(id<FxGripMutableParameter>)customValue getIntValue:value];
		}
	}
	return [_api getIntValue:value fromParameter:parameterID atTime:time];
}

- (BOOL)getParameterFlags:(nonnull FxParameterFlags *)flags fromParameter:(UInt32)parameterID
{
	NSMutableDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Flags: @(0)
			}.mutableCopy
		}.mutableCopy;
	
	[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterGetFlagsPreName object:self.effect userInfo:userInfo];
	
	userInfo.parameterID = parameterID;
	userInfo.mutableFxParameter.parameterID = parameterID;
	if (userInfo.fxResult) {
		*flags = ((NSNumber*)userInfo.fxParameter[kFxParameterProperty_Flags]).unsignedIntValue;
		return [userInfo.fxResult boolValue];
	}
	
	if (![_api getParameterFlags:flags fromParameter:parameterID]) {
		return NO;
	}

	// The following shouldn't be necessary as Apple does not save undefined flags, but in case they change the behavior or stray bits.
	//*flags = FxParameterFlagsFxMask(*flags);

	// The host value seeds the payload so observers see it and the readback returns it.
	userInfo.mutableFxParameter[kFxParameterProperty_Flags] = @(*flags);
	[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterGetFlagsName object:self.effect userInfo:userInfo];
	*flags = ((NSNumber*)userInfo.fxParameter[kFxParameterProperty_Flags]).unsignedIntValue;
	return userInfo.fxError == NULL;
}

- (BOOL)getPathID:(FxPathID  _Nullable * _Nonnull)pathID fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_api getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(getPathID:)]) {
			return [(id<FxGripMutableParameter>)customValue getPathID:pathID];
		}
	}
	return [_api getPathID:pathID fromParameter:parameterID atTime:time];
}

- (BOOL)getRedValue:(nonnull double *)red greenValue:(nonnull double *)green blueValue:(nonnull double *)blue alphaValue:(nonnull double *)alpha fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_api getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(getRedValue:greenValue:blueValue:alphaValue:)]) {
			return [(id<FxGripMutableParameter>)customValue getRedValue:red greenValue:green blueValue:blue alphaValue:alpha];
		}
	}
	return [_api getRedValue:red greenValue:green blueValue:blue alphaValue:alpha fromParameter:parameterID atTime:time];
}

- (BOOL)getRedValue:(nonnull double *)red greenValue:(nonnull double *)green blueValue:(nonnull double *)blue fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_api getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(getRedValue:greenValue:blueValue:)]) {
			return [(id<FxGripMutableParameter>)customValue getRedValue:red greenValue:green blueValue:blue];
		}
	}
	return [_api getRedValue:red greenValue:green blueValue:blue fromParameter:parameterID atTime:time];
}

- (BOOL)getStringParameterValue:(NSString * _Nonnull * _Nullable)string fromParameter:(UInt32)parameterID
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_api getCustomParameterValue:&customValue fromParameter:parameterID atTime:kCMTimeZero] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(getStringParameterValue:)]) {
			return [(id<FxGripMutableParameter>)customValue getStringParameterValue:string];
		}
	}
	BOOL success = [_api getStringParameterValue:string fromParameter:parameterID];
	
	if (success) {
		NSMutableDictionary *userInfo = @{
				kFxParameterProperty_Id: @(parameterID),
				FxGripNotifyAPI_ParameterKey: @{
					kFxParameterProperty_Id: @(parameterID),
					kFxParameterProperty_Default: *string
				}.mutableCopy
			}.mutableCopy;
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterGetStringValueName object:self.effect userInfo:userInfo];
		*string = userInfo.fxParameter[kFxParameterProperty_Default];
	}
	return success;
}

- (BOOL)getXValue:(nonnull double *)x YValue:(nonnull double *)y fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_api getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(getXValue:YValue:)]) {
			return [(id<FxGripMutableParameter>)customValue getXValue:x YValue:y];
		}
	}
	return [_api getXValue:x YValue:y fromParameter:parameterID atTime:time];
}

@end
