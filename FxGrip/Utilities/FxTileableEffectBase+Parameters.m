//
//  FxTileableEffectNotifications.m
//  FxTileableEffectNotifications
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#import "FxTileableEffectBase+Extensions.h"
#import "FxTileableEffectBase+Parameters.h"
#import "FxGripAllParameters.h"
#import "NSDictionary+FxTileableEffect.h"

#pragma mark -
#pragma mark FxTileableEffectBase FxPlug Parameters

@implementation FxTileableEffectBase (FxParameters)

@protocol FxParameterExtension;

static NSArray<NSString*> *offLangs = @[@"off", @"af", @"عن", @"বন্ধ", @"离开", @"uit", @"désactivé", @"aus", @"hemo", @"बंद", @"オフ", @"ਬੰਦ", @"выключенный", @"apagado"];

- (nullable id)parameterForDictionary:(nullable NSDictionary *)data
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self IN %@", offLangs];
	NSArray *hasOff = [data.allKeys filteredArrayUsingPredicate:predicate];
	if (hasOff.count) {
		NSLog(@"keys %@ turned off parameter %d", hasOff, data.parameterID);
		return NULL;
	}
	
	id<FxExtension> ext = [self extensionForKey:data.parameterExtensionKey];
	if (ext) {
		if ([ext conformsToProtocol:@protocol(FxParameter)]) {
			return ext;
		}
		return nil;
	}
	Class parameterClass = [self parameterClassWithTypeString:data[kFxParameterProperty_Type]];
	
	// the type must have a root type class even if a customClass or instance.
	if (!parameterClass) {
		return NULL;
	}
	
	
	if (data[kFxParameterProperty_ClassName]) {
		NSString *className = data[kFxParameterProperty_ClassName];
		Class cls = nil;
		if (![className isKindOfClass:NSString.class]) {
			NSLog(@"Error: instancing class name %@, it is not an NSString.", className);
			return nil;
		} else {
			cls = NSClassFromString(className);
		}
		if (!cls) {
			NSLog(@"Error: Class %@ does not exist.", className);
			return nil;
		}
		parameterClass = cls;
	}
	
	if (![parameterClass conformsToProtocol: @protocol(FxParameter)]) {
		NSLog(@"Error: class %@ does not conform to FxGripParameterProtocol.", parameterClass.className);
		return nil;
	}
	return [parameterClass.alloc initWithDictionary:data];
}

- (void)registerParameterType:(nullable Class)paramClass
{
	if (![paramClass conformsToProtocol:@protocol(FxParameter)]) {
		return;
	}
	[__typeToClassMap setObject:paramClass forKey:@([paramClass parameterType])];
	[__typeToClassMap setObject:paramClass forKey:[paramClass parameterTypeString]];
}

- (void)loadTypeToClassMap
{
	[self registerParameterType:FxGripAngleParameter.class];
	[self registerParameterType:FxGripColorParameter.class];
	[self registerParameterType:FxGripCustomParameter.class];
	[self registerParameterType:FxGripFloatParameter.class];
	
	[self registerParameterType:FxGripFontMenuParameter.class];
	[self registerParameterType:FxGripGradientParameter.class];
	[self registerParameterType:FxGripGroupParameter.class];
	[self registerParameterType:FxGripHelpParameter.class];
	[self registerParameterType:FxGripHistogramParameter.class];
	[self registerParameterType:FxGripImageRefParameter.class];
	[self registerParameterType:FxGripIntParameter.class];
	[self registerParameterType:FxGripMenuParameter.class];
	[self registerParameterType:FxGripPathParameter.class];
	[self registerParameterType:FxGripPercentParameter.class];
	[self registerParameterType:FxGripPointParameter.class];
	[self registerParameterType:FxGripPushButtonParameter.class];
	[self registerParameterType:FxGripRGBParameter.class];
	[self registerParameterType:FxGripStringParameter.class];
	[self registerParameterType:FxGripToggleParameter.class];
	
	// Extra classes
}


- (FxParameterType)parameterTypeWithString:(nullable NSString *)typeString
{
	if (!typeString) {
		return FxParameterType_None;
	}
	return [__typeToClassMap[typeString] parameterType];
}


- (nullable NSString *)parameterStringWithType:(FxParameterType)type
{
	if (type == FxParameterType_None) {
		return nil;
	}
	return [__typeToClassMap[@(type)] parameterTypeString];
}


- (nullable Class)parameterClassWithType:(FxParameterType)type
{
	if (type == FxParameterType_None) {
		return nil;
	}
	return __typeToClassMap[@(type)];
}


- (nullable Class)parameterClassWithTypeString:(nullable NSString *)typeString
{
	if (!typeString) {
		return nil;
	}
	return __typeToClassMap[typeString];
}


@end

