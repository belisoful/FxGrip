//
//  FxGripCustomExtension.m
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripCustomExtension.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Notifications.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripInterpolatingDictionary.h"
#import "NSCoder+FxPlug.h"



#pragma mark -
#pragma mark FxGripCustomExtension Implementation

@implementation FxGripCustomExtension

-(instancetype _Nullable) init
{
	self = [super init];
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
			[NSNumber class],
			[NSDecimalNumber class],
			[NSColor class],
			[NSDate class],
			[NSMutableData class],
			[NSData class],
			[NSValue class],
			[NSNull class],
			[NSURL class],
			[NSUUID class]
		 ]].set;
	}
	return self;
}

#include "../../Parameters/Common/FxGripCustomParameterLibrary.m"

@end

