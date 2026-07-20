//
//  FxGripDebugMenu.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripMeta.h"

@implementation FxGripMeta

- (FxParameterId)parameterID {
	return kFxParameterId_InstanceMeta;
}

-(void) processParameters:(NSMutableArray<id<FxGripParameterProtocol>>*)parameters
{
	NSDictionary *metaData = @{
		kFxParameterProperty_Factory: self,
		@"id": @(kFxParameterId_InstanceMeta),
		@"name": @"Plugin Data",
		@"type": kFxParameterType_Custom,
		@"flags": @[kParameterFlagString_DONT_DISPLAY, kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA, kParameterFlagString_NO_DEBUG, kParameterFlagString_NO_STATE]
	};
	[parameters addObject:[metaData mutableCopy]];
}

@end

