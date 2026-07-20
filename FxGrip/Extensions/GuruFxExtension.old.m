/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  GuruFxExtension.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import "GuruFxExtension.h"
#import "GuruFxTileableEffect.h"
#import "GuruFxTileableEffect+Extensions.h"
#import "GuruFxInterpolatingDictionary.h"
#import "NSDictionary+FxTileableEffect.h"
#import "NSCoder+FxPlug.h"


#pragma mark -
#pragma mark GuruFxExtension Implementation

@implementation GuruFxExtension

@synthesize effect = _effect;
@synthesize extActive = _extActive;
@synthesize extDefaultPriority = _extDefaultPriority;

- (nullable id)init
{
	self = [super init];
	if (self) {
		_extActive = YES;
		_extDefaultPriority = NSPriorityNotificationDefaultPriority;
	}
	return self;
}

#include "GuruFxExtensionLibrary.m"

- (void)extUnload
{
	[_effect.notifier removeObserver:self];
}


@end



#pragma mark -
#pragma mark GuruFxExtensionParameter Implementation

@implementation GuruFxExtensionParameter


- (instancetype _Nullable)init
{
	self = [super init];
	if (self) {
		_addedToEffect = NO;
		
		_parameterName = nil;
		_parameterID = 0;
		_parameterParentID = 0;
		_parameterCurrentFlags = _parameterFlags = 0;
		
	}
	return self;
}

- (nullable id) parameterForDictionary:(nonnull NSDictionary *)data
{
	_addedToEffect = YES;
	
	_parameterName = data.parameterName;
	_parameterID = data.parameterID;
	_parameterParentID = data.parameterParentID;
	_parameterCurrentFlags = _parameterFlags = data.parameterFlags;
	
	return self;
}


- (BOOL)startChangedTime:(CMTime)time error:(NSError * _Nullable * _Nullable)error
{
	return YES;
}

- (BOOL)endChangedTime:(CMTime)time error:(NSError * _Nullable * _Nullable)error
{
	return YES;
}


#include "../GuruFxParameters/GuruFxParameterLibrary.m"

@end




#pragma mark -
#pragma mark GuruFxExtensionCustomParameter Implementation

@implementation GuruFxExtensionCustomParameter

-(instancetype _Nullable) init
{
	self = [super init];
	if(self) {
		_dataClasses = [NSOrderedSet orderedSetWithArray:@[
			[GuruFxDictionary class],
			[GuruFxInterpolatingDictionary class],
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

#include "../GuruFxParameters/Common/GuruFxCustomParameterLibrary.m"

@end






#pragma mark -
#pragma mark GuruFxExtensionIntParameter Implementation
// replicate GuruFxIntParameter in this class

@implementation GuruFxExtensionToggleParameter

#include "../GuruFxParameters/Common/GuruFxToggleParameterLibrary.m"

@end


 
/*

#pragma mark -
#pragma mark GuruFxExtensionIntParameter Implementation
// replicate GuruFxIntParameter in this class

@implementation GuruFxExtensionIntParameter

-(int) value:(CMTime)renderTime
{
	int intValue = 0;
	if(![self.effect.apiManager.paramGetAPIv6 getIntValue:&intValue fromParameter:self.paramID atTime:renderTime]) {
		_error = kGuruFxParameterErrorBool;
	}
	return intValue;
}


-(void) encodeInto:(NSMutableDictionary*_Nonnull)dictionary renderTime:(CMTime)renderTime
{
	int intValue = 0;
	if([self.effect.apiManager.paramGetAPIv6 getIntValue:&intValue fromParameter:self.paramID atTime:renderTime]) {
		[dictionary setObject:[NSNumber numberWithInt:intValue] forKey:self.stateKey];
	} else {
		_error = kGuruFxParameterErrorBool;
	}
}

@end
*/
