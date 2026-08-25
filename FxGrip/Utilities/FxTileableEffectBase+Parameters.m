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
		// The extension configures itself from the parameter dictionary — syncing its
		// id/name/flags and marking itself addedToEffect — and returns the FxParameter
		// it vends. Returning it unconfigured left FxGripCustomExtension values
		// permanently nil (addedToEffect stayed NO).
		if ([ext conformsToProtocol:@protocol(FxParameter)]
			&& [ext respondsToSelector:@selector(parameterForDictionary:)]) {
			return [(id)ext parameterForDictionary:data];
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
	return [parameterClass.alloc initWithDictionary:data effect:self];
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
	[self registerParameterType:FxGripPresetsParameter.class];
	[self registerParameterType:FxGripPushButtonParameter.class];
	[self registerParameterType:FxGripRGBParameter.class];
	[self registerParameterType:FxGripStringParameter.class];
	[self registerParameterType:FxGripToggleParameter.class];

	// Custom-UI classes
	[self registerParameterType:FxGripSwitchParameter.class];
	[self registerParameterType:FxGripDividerParameter.class];
	[self registerParameterType:FxGripSectionParameter.class];
	[self registerParameterType:FxGripRandomParameter.class];
	[self registerParameterType:FxGripBannerParameter.class];
	[self registerParameterType:FxGripCapsuleParameter.class];
	[self registerParameterType:FxGripStatusParameter.class];
	[self registerParameterType:FxGripProgressParameter.class];
	[self registerParameterType:FxGripWebViewParameter.class];
	[self registerParameterType:FxGripVideoViewParameter.class];
}


- (FxParameterType)parameterTypeWithString:(nullable NSString *)typeString
{
	if (!typeString) {
		return FxParameterType_None;
	}
	Class parameterClass = __typeToClassMap[typeString];
	if (parameterClass) {
		return [parameterClass parameterType];
	}
	// A loaded extension can back a custom type string the built-in map does not know.
	for (id<FxExtension> ext in [self extensionsForProtocol:@protocol(FxExtension)]) {
		if ([ext respondsToSelector:@selector(extParameterTypeForString:)]) {
			FxParameterType type = [ext extParameterTypeForString:typeString];
			if (type != FxParameterType_None) {
				return type;
			}
		}
	}
	return FxParameterType_None;
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
	Class parameterClass = __typeToClassMap[typeString];
	if (parameterClass) {
		return parameterClass;
	}
	// A loaded extension can back a custom type string: resolve the type it declares for the
	// string, then the class that backs that type.
	for (id<FxExtension> ext in [self extensionsForProtocol:@protocol(FxExtension)]) {
		if ([ext respondsToSelector:@selector(extParameterTypeForString:)]
			&& [ext respondsToSelector:@selector(extParameterClassForType:)]) {
			FxParameterType type = [ext extParameterTypeForString:typeString];
			if (type != FxParameterType_None) {
				Class extClass = [ext extParameterClassForType:type];
				if (extClass) {
					return extClass;
				}
			}
		}
	}
	return nil;
}


@end

