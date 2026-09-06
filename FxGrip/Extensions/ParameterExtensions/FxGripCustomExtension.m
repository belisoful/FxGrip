/*!
	@file       FxGripCustomExtension.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCustomExtension
	@abstract   Implements the parameter extension that models a custom-value parameter.
	@discussion Introduced in FxGrip 0.1.0. The extension seeds the ordered set of accepted value classes
	            and draws its parameter behavior from the included custom parameter library.
*/

#import "FxGripCustomExtension.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Notifications.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripInterpolatingDictionary.h"
#import "NSCoder+FxPlug.h"



#pragma mark -
#pragma mark FxGripCustomExtension Implementation

/*!
	@abstract	The extension that represents a custom-value effect parameter.
	@discussion	Introduced in FxGrip 0.1.0. The extension stores a secure-codable value and accepts the
				value classes listed in dataClasses.
*/
@implementation FxGripCustomExtension

/*! @abstract Seeds the ordered set of value classes the custom parameter accepts. */
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

