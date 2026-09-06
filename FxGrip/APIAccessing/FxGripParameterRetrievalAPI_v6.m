/*!
	@file       FxGripParameterRetrievalAPI_v6.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterRetrievalAPI_v6
	@abstract   Implements the parameter retrieval wrapper over the host FxParameterRetrievalAPI_v6.
	@discussion Introduced in FxGrip 0.1.0. Typed reads check for a Custom parameter first and
	            route to the value's FxGripMutableParameter accessor when it responds, otherwise
	            they forward to the host API. String and flag reads post FxGrip notifications so
	            observers can supply or amend the returned value.
*/

#import "FxGripParameterFlags.h"
#import "FxGripParameterRetrievalAPI_v6.h"
#import "FxGripInterpolatingDictionary.h"
#import "FxGripParameterInfoAPI_v1.h"
#import "FxGripTileableEffect.h"
#import "FxGripCustomViewData.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripAPINotifications.h"

#import <FxGrip_ARC.h>

/*!
	@abstract	FxGrip's wrapper around the host FxParameterRetrievalAPI_v6.
	@discussion	Introduced in FxGrip 0.1.0. Custom parameters route through FxGripMutableParameter;
				every other read forwards to the host API, with string and flag reads posting
				FxGrip notifications.
*/
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


/*! @abstract Reads a Boolean value, routing to the custom value's accessor for a Custom parameter. */
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

/*!
	@method		getCustomParameterValue:fromParameter:atTime:
	@abstract	Reads a custom parameter value and attaches the effect to it.
	@discussion	Introduced in FxGrip 0.1.0. When the returned value conforms to FxGripCustomViewData,
				the wrapper sets its parameterEffect so the value can reach the effect.
	@return		YES when the host returns a value.
*/
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

/*! @abstract Reads a floating-point value, routing to the custom value's accessor for a Custom parameter. */
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

/*! @abstract Reads a font name, routing to the custom value's accessor for a Custom parameter. */
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

/*! @abstract Reads gradient samples, routing to the custom value's accessor for a Custom parameter. */
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

/*! @abstract Reads histogram controls, routing to the custom value's accessor for a Custom parameter. */
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

/*! @abstract Reads an integer value, routing to the custom value's accessor for a Custom parameter. */
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

/*!
	@method		getParameterFlags:fromParameter:
	@abstract	Reads a parameter's flags, letting observers override or amend the host value.
	@discussion	Introduced in FxGrip 0.1.0. A pre-notification lets an observer return the flags
				directly. Otherwise the host value seeds the payload, a second notification lets
				observers amend it, and the amended flags are returned.
	@return		YES when the flags resolve.
*/
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

/*! @abstract Reads a path ID, routing to the custom value's accessor for a Custom parameter. */
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

/*! @abstract Reads an RGBA color, routing to the custom value's accessor for a Custom parameter. */
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

/*! @abstract Reads an RGB color, routing to the custom value's accessor for a Custom parameter. */
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

/*!
	@method		getStringParameterValue:fromParameter:
	@abstract	Reads a string value, letting observers amend it through a notification.
	@discussion	Introduced in FxGrip 0.1.0. A Custom parameter routes to the custom value's
				accessor. Otherwise the host value is read, then the get-string notification lets
				observers replace it before it returns.
	@return		YES when the host returns a string.
*/
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

/*! @abstract Reads a 2D point, routing to the custom value's accessor for a Custom parameter. */
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
