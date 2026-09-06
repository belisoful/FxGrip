/*!
	@file       FxGripImageRefParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripImageRefParameter
	@abstract   Implements the parameter model for a host image reference well.
	@discussion Introduced in FxGrip 0.1.0. The class registers an image reference parameter through the parameter-creation API and reports the referenced clip's start time, duration, and drop-frame setting through the host timing APIs.
*/

#import "FxGripImageRefParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"

/*!
	@abstract	The parameter model for a host image reference well.
	@discussion	Introduced in FxGrip 0.1.0. The class registers an image reference parameter and reports the referenced clip's timing.
*/
@implementation FxGripImageRefParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_ImageRef;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_ImageRef;
}


/*!
	@method		addParameter:toEffect:
	@abstract	Registers the image reference parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	return [effect.apiManager.paramCreateAPIv5 addImageReferenceWithName: parameter.parameterName
															 parameterID: parameter.parameterID
														  parameterFlags: parameter.parameterFlags];
}


/*! @abstract YES when the referenced image includes upstream filters. */
- (BOOL)includeFilters
{	//	@todo get param from data
	return YES;
}


/*!
	@method		startTime
	@abstract	Reads the start time of the referenced clip through FxTimingAPI_v4.
	@return		The start time, or kCMTimeInvalid when the timing API does not answer. */
- (CMTime)startTime
{
	CMTime time = kCMTimeInvalid;
	
	[self.effect.apiManager.timingAPIv4 startTime:&time ofImageParameter:self.parameterID];
	
	return time;
}

/*!
	@method		durationTime
	@abstract	Reads the duration of the referenced clip through FxTimingAPI_v4.
	@return		The duration, or kCMTimeInvalid when the timing API does not answer. */
- (CMTime)durationTime
{
	CMTime time = kCMTimeInvalid;

	[self.effect.apiManager.timingAPIv4 durationTime:&time ofImageParameter:self.parameterID];

	return time;
}

/*!
	@method		isDropFrame
	@abstract	Reports whether the referenced clip requires drop-frame timecode through FxTimingAPI_v5.
	@return		YES when the clip requires drop-frame timecode; NO on hosts without FxTimingAPI_v5. */
- (BOOL)isDropFrame
{
	return [self.effect.apiManager.timingAPIv5 isInputDropFrame:kFxImageTileRequestSourceParameter
													 parameterID:self.parameterID];
}

@end
