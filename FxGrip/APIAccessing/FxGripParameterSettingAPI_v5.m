//
//  FxGripParameterCreationAPI_v5.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripParameterSettingAPI_v5.h"
#import "FxParameterFlags.h"
#import "FxGripParameterInfoAPI_v1.h"
#import "FxGripInterpolatingDictionary.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripAPINotifications.h"
#import <BEFoundation/FxTime.h>
#import "FxGrip_ARC.h"

@implementation FxGripParameterSettingAPI_v5

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPI:(id<FxParameterSettingAPI_v6>)api
					   paramGetAPIv6:(id<FxParameterRetrievalAPI_v6>)paramGetAPIv6
				   parameterInfoAPIv1:(id<FxParameterInfoAPI_v1>)parameterInfoAPIv1
							  effect:(id<FxGripEffectHost>)effect
{
	self = [super initWithEffect:effect];
	
	if (self != nil)
	{
		_api = api;
		_parameterInfoAPIv1 = parameterInfoAPIv1;
		_paramGetAPIv6 = paramGetAPIv6;
	}
	return self;
}

- (void)dealloc
{
	SUPER_DEALLOC();
}

- (BOOL)setBoolValue:(BOOL)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_paramGetAPIv6 getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(setBoolValue:)]) {
			if ([(id<FxGripMutableParameter>)customValue setBoolValue:value]) {
				[self setCustomParameterValue:customValue toParameter:parameterID atTime:time];
				return YES;
			}
		}
		return NO;
	}
	BOOL success = [_api setBoolValue:value toParameter:parameterID atTime:time];
	
	if (success) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Default: @(value),
				kFxParameterProperty_Time: [FxTime time:time]
			}
		};
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetBoolName object:self.effect userInfo:userInfo];
	}
	
	return success;
}

- (BOOL)setCustomParameterValue:(nonnull NSObject<NSSecureCoding,NSCopying> *)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	BOOL success = [_api setCustomParameterValue:value toParameter:parameterID atTime:time];
	
	if (success) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Default: value,
				kFxParameterProperty_Time: [FxTime time:time]
			}
		};
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetCustomValueName object:self.effect userInfo:userInfo];
	}
	
	return success;
}

- (BOOL)setFloatValue:(double)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_paramGetAPIv6 getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(setFloatValue:)]) {
			if ([(id<FxGripMutableParameter>)customValue setFloatValue:value]) {
				[self setCustomParameterValue:customValue toParameter:parameterID atTime:time];
				return YES;
			}
		}
		return NO;
	}
	BOOL success = [_api setFloatValue:value toParameter:parameterID atTime:time];
	
	if (success) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Default: @(value),
				kFxParameterProperty_Time: [FxTime time:time]
			}
		};
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetFloatName object:self.effect userInfo:userInfo];
	}
	
	return success;
}

- (BOOL)setHistogramBlackIn:(double)blackIn blackOut:(double)blackOut whiteIn:(double)whiteIn whiteOut:(double)whiteOut gamma:(double)gamma forChannel:(FxHistogramChannel)channel fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_paramGetAPIv6 getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(setHistogramBlackIn:blackOut:whiteIn:whiteOut:gamma:forChannel:)]) {
			if ([(id<FxGripMutableParameter>)customValue setHistogramBlackIn:blackIn blackOut:blackOut whiteIn:whiteIn whiteOut:whiteOut gamma:gamma forChannel:channel]) {
				[self setCustomParameterValue:customValue toParameter:parameterID atTime:time];
				return YES;
			}
		}
		return NO;
	}
	BOOL success = [_api setHistogramBlackIn:blackIn blackOut:blackOut whiteIn:whiteIn whiteOut:whiteOut gamma:gamma forChannel:channel fromParameter:parameterID atTime:time];
	
	if (success) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_BlackIn: @(blackIn),
				kFxParameterProperty_BlackOut: @(blackOut),
				kFxParameterProperty_WhiteIn: @(whiteIn),
				kFxParameterProperty_WhiteOut: @(whiteOut),
				kFxParameterProperty_Gamma: @(gamma),
				kFxParameterProperty_Channel: @(channel),
				kFxParameterProperty_Time: [FxTime time:time]
			}
		};
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetHistogramName object:self.effect userInfo:userInfo];
	}
	
	return success;
}

- (BOOL)setIntValue:(int)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_paramGetAPIv6 getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(setIntValue:)]) {
			if ([(id<FxGripMutableParameter>)customValue setIntValue:value]) {
				[self setCustomParameterValue:customValue toParameter:parameterID atTime:time];
				return YES;
			}
		}
		return NO;
	}
	BOOL success = [_api setIntValue:value toParameter:parameterID atTime:time];
	
	if (success) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Default: @(value),
				kFxParameterProperty_Time: [FxTime time:time]
			}
		};
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetIntName object:self.effect userInfo:userInfo];
	}
	
	return success;
}

- (BOOL)setParameterFlags:(FxParameterFlags)flags toParameter:(UInt32)parameterID
{
	NSMutableDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Flags: @(flags)
			}.mutableCopy
		}.mutableCopy;
	
	[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetFlagsPreName object:self.effect userInfo:userInfo];
	if (userInfo.fxResult) {
		return [userInfo.fxResult boolValue];
	}
	flags = ((NSNumber*)userInfo.fxParameter[kFxParameterProperty_Flags]).unsignedIntValue;
	userInfo.parameterID = parameterID;
	userInfo.mutableFxParameter.parameterID = parameterID;
	
	BOOL success = [_api setParameterFlags:FxParameterFlagsFxMask(flags) toParameter:parameterID];
	
	if (success) {
		flags = SavingFlags(flags);
		flags &= ~kFxParameterFlag_CACHE;
		
		userInfo.mutableFxParameter.parameterFlags = flags;
		userInfo.fxParameter = userInfo.fxParameter.copy;
		
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetFlagsName object:self.effect userInfo:userInfo.copy];
	}
	
	return success;
	
}

- (BOOL)setPathID:(nonnull FxPathID)pathID toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_paramGetAPIv6 getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(setPathID:)]) {
			if ([(id<FxGripMutableParameter>)customValue setPathID:pathID]) {
				[self setCustomParameterValue:customValue toParameter:parameterID atTime:time];
				return YES;
			}
		}
		return NO;
	}
	BOOL success = [_api setPathID:pathID toParameter:parameterID atTime:time];
	
	if (success) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterPropertyX_PathID: [NSValue valueWithPointer:pathID],
				kFxParameterProperty_Time: [FxTime time:time]
			}
		};
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetPathIDName object:self.effect userInfo:userInfo];
	}
	
	return success;
}

- (BOOL)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_paramGetAPIv6 getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(setRedValue:greenValue:blueValue:alphaValue:)]) {
			if ([(id<FxGripMutableParameter>)customValue setRedValue:red greenValue:green blueValue:blue alphaValue:alpha]) {
				[self setCustomParameterValue:customValue toParameter:parameterID atTime:time];
				return YES;
			}
		}
		return NO;
	}
	BOOL success = [_api setRedValue:red greenValue:green blueValue:blue alphaValue:alpha toParameter:parameterID atTime:time];
	
	if (success) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Red: @(red),
				kFxParameterProperty_Green: @(green),
				kFxParameterProperty_Blue: @(blue),
				kFxParameterProperty_Alpha: @(alpha),
				kFxParameterProperty_Time: [FxTime time:time]
			}
		};
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetRGBAName object:self.effect userInfo:userInfo];
	}
	
	return success;
}

- (BOOL)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_paramGetAPIv6 getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(setRedValue:greenValue:blueValue:)]) {
			if ([(id<FxGripMutableParameter>)customValue setRedValue:red greenValue:green blueValue:blue]) {
				[self setCustomParameterValue:customValue toParameter:parameterID atTime:time];
				return YES;
			}
		}
		return NO;
	}
	BOOL success = [_api setRedValue:red greenValue:green blueValue:blue toParameter:parameterID atTime:time];
	
	if (success) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Red: @(red),
				kFxParameterProperty_Green: @(green),
				kFxParameterProperty_Blue: @(blue),
				kFxParameterProperty_Time: [FxTime time:time]
			}
		};
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetRGBName object:self.effect userInfo:userInfo];
	}
	
	return success;
}

- (BOOL)setStringParameterValue:(nonnull NSString *)string toParameter:(UInt32)parameterID
{
	NSMutableDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Default: string
			}.mutableCopy
		}.mutableCopy;
	[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetStringValuePreName object:self.effect userInfo:userInfo];
	userInfo.parameterID = parameterID;
	userInfo.mutableFxParameter.parameterID = parameterID;
	
	string = userInfo.fxParameter[kFxParameterProperty_Default];
	userInfo.fxParameter = userInfo.fxParameter.copy;
	
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_paramGetAPIv6 getCustomParameterValue:&customValue fromParameter:parameterID atTime:kCMTimeZero] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(setStringParameterValue:)]) {
			if ([(id<FxGripMutableParameter>)customValue setStringParameterValue:string]) {
				[self setCustomParameterValue:customValue toParameter:parameterID atTime:kCMTimeZero];
				return YES;
			}
		}
		return NO;
	}
	BOOL success = [_api setStringParameterValue:string toParameter:parameterID];
	
	if (success) {
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetStringValueName object:self.effect userInfo:userInfo.copy];
	}
	
	return success;
}

- (BOOL)setXValue:(double)x YValue:(double)y toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	if (_parameterInfoAPIv1 && [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Custom) {
		NSObject<NSSecureCoding, NSCopying> *customValue;
		if ([_paramGetAPIv6 getCustomParameterValue:&customValue fromParameter:parameterID atTime:time] && [customValue conformsToProtocol:@protocol(FxGripMutableParameter)] && [customValue respondsToSelector:@selector(setXValue:YValue:)]) {
			if ([(id<FxGripMutableParameter>)customValue setXValue:x YValue:y]) {
				[self setCustomParameterValue:customValue toParameter:parameterID atTime:time];
				return YES;
			}
		}
		return NO;
	}
	BOOL success = [_api setXValue:x YValue:y toParameter:parameterID atTime:time];
	
	if (success) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_X: @(x),
				kFxParameterProperty_Y: @(y),
				kFxParameterProperty_Time: [FxTime time:time]
			}
		};
		[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterSetXYName object:self.effect userInfo:userInfo];
	}
	
	return success;
}

@end
