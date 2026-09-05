//
//  FxGripImageRefParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripImageRefParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"

@implementation FxGripImageRefParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_ImageRef;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_ImageRef;
}


+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	return [effect.apiManager.paramCreateAPIv5 addImageReferenceWithName: parameter.parameterName
															 parameterID: parameter.parameterID
														  parameterFlags: parameter.parameterFlags];
}


- (BOOL)includeFilters
{	//	@todo get param from data
	return YES;
}


- (CMTime)startTime
{
	CMTime time = kCMTimeInvalid;
	
	[self.effect.apiManager.timingAPIv4 startTime:&time ofImageParameter:self.parameterID];
	
	return time;
}

- (CMTime)durationTime
{
	CMTime time = kCMTimeInvalid;
	
	[self.effect.apiManager.timingAPIv4 durationTime:&time ofImageParameter:self.parameterID];
	
	return time;
}

- (BOOL)isDropFrame
{
	return [self.effect.apiManager.timingAPIv5 isInputDropFrame:kFxImageTileRequestSourceParameter
													 parameterID:self.parameterID];
}

@end
