//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripMenuParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"

@implementation FxGripMenuParameter

-(instancetype _Nullable) initWithDictionary:(NSDictionary*)dictionary effect:(nonnull id<FxGripEffectHost>)effect
{
	self = [super initWithDictionary:dictionary effect:effect];
	if(self) {
		_parameterMenuItems = dictionary.parameterMenuItems;
	}
	return self;
}


+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Menu;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Menu;
}


+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	NSArray<NSString*> *items = parameter.parameterMenuItems;
	
	int defaultValue = 0;
	NSNumber *defaultValueNumber = [parameter valueForKey:kFxParameterProperty_Default];
	if (defaultValueNumber != nil) {
		defaultValue = [defaultValueNumber intValue];
	}
	return [effect.apiManager.paramCreateAPIv5 addPopupMenuWithName: parameter.parameterName
														parameterID: parameter.parameterID
													   defaultValue: defaultValue
														menuEntries: items
													 parameterFlags: parameter.parameterFlags];
}

@end
