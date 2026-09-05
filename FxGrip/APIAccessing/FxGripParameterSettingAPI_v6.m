//
//  FxGripParameterCreationAPI_v5.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripParameterSettingAPI_v6.h"
#import "FxGripParameterFlags.h"
#import "FxGripTileableEffect.h"

@implementation FxGripParameterSettingAPI_v6

- (BOOL)addFlags:(FxParameterFlags)flags toParameter:(UInt32)parameterID
{
	FxParameterFlags pflags = kFxParameterFlag_DEFAULT;
	if(![self.effect.apiManager.paramGetAPIv6 getParameterFlags:&pflags fromParameter:parameterID])
		return NO;
	pflags |= flags;
	
	return [self setParameterFlags:pflags toParameter:parameterID];
}

- (BOOL)removeFlags:(FxParameterFlags)flags fromParameter:(UInt32)parameterID
{
	FxParameterFlags pflags = kFxParameterFlag_DEFAULT;
	if(![self.effect.apiManager.paramGetAPIv6 getParameterFlags:&pflags fromParameter:parameterID])
		return NO;
	
	pflags &= ~flags;
	
	return [self setParameterFlags:pflags toParameter:parameterID];
}

@end
