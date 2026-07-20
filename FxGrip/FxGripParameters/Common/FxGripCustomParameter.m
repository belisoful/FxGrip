//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripCustomParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxGripInterpolatingDictionary.h"
#import <BEFoundation/NSDictionary+BExtension.h>
#import "NSCoder+FxPlug.h"

@implementation FxGripCustomParameter

-(instancetype _Nullable) initWithDictionary:(NSDictionary*_Nonnull)dictionary effect:(nonnull id<FxTileableEffectBase>)effect
{
	self = [super initWithDictionary:dictionary effect:effect];
	if(self) {
		_dataClasses = [NSOrderedSet orderedSetWithArray:@[
			[FxGripDictionary class],
			[FxGripInterpolatingDictionary class],
			[NSMutableDictionary class],
			[NSDictionary class],
			[NSMutableArray class],
			[NSArray class],
			[NSMutableString class],
			[NSString class],
			[NSMutableSet class],
			[NSSet class],
			[NSMutableOrderedSet class],
			[NSOrderedSet class],
			[NSMutableIndexSet class],
			[NSIndexSet class],
			[NSNumber class],
			[NSDecimalNumber class],
			[NSColor class],
			[NSDate class],
			[NSMutableData class],
			[NSData class],
			[NSValue class],
			[NSMutableCharacterSet class],
			[NSCharacterSet class],
			[NSNull class],
			[NSURL class],
			[NSUUID class]
		 ]].set;
	}
	return self;
}

#include "FxGripCustomParameterLibrary.m"



- (void)initializeCustomData:(NSObject<NSSecureCoding, NSCopying>* _Nullable * _Nonnull)customDefaultValue parameterID:(FxParameterId)parameterID
{
	//Sub classes can initialize any custom data here.
	//	eg. if the CustomData class is FxGripInterpolatingDictionary, this is where to init its values
	
	//set *customDefaultValue
}

@end
