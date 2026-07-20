//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripPathParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
#import "NSCoder+FxPlug.h"

@implementation FxGripPathParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_PathID;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_PathID;
}

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect
{
	return [effect.apiManager.paramCreateAPIv5 addPathPickerWithName: parameter.parameterName
														 parameterID: parameter.parameterID
													  parameterFlags: parameter.parameterFlags];
}

-(FxPathID _Nullable) valueAtTime:(CMTime)renderTime
{
	FxPathID pathValue = nil;
	if(![self.effect.apiManager.paramGetAPIv6 getPathID:&pathValue fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return pathValue;
}


- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];
	
	if (coder.isFxPluginStateEncoder) {
		FxPathID pathId = [self valueAtTime:coder.renderTime];
		[coder encodeBytes:(void*)&pathId length:sizeof(pathId) atIndex:self.parameterID];
	} else {
		// encode meta
	}
}

@end
