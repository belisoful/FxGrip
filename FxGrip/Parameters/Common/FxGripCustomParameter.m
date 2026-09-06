/*!
	@file       FxGripCustomParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCustomParameter
	@abstract   Implements the parameter model for a host custom parameter that stores a coded object.
	@discussion Introduced in FxGrip 0.1.0. The class registers a custom parameter through the parameter-creation API and reads and writes its coded value at a render time. The shared method bodies come from FxGripCustomParameterLibrary.m through a textual include.
*/

#import "FxGripCustomParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripInterpolatingDictionary.h"
#import <BEFoundation/NSDictionary+BExtension.h>
#import "NSCoder+FxPlug.h"

/*!
	@abstract	The parameter model for a host custom parameter.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a custom parameter, populates its permitted data classes, and reads, writes, and encodes its coded value.
*/
@implementation FxGripCustomParameter

/*!
	@method		initWithDictionary:effect:
	@abstract	Initializes the parameter and populates the ordered set of permitted data classes.
	@param		dictionary	The parameter configuration dictionary.
	@param		effect		The host that owns the parameter. */
-(instancetype _Nullable) initWithDictionary:(NSDictionary*_Nonnull)dictionary effect:(nonnull id<FxGripEffectHost>)effect
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



/*!
	@method		initializeCustomData:parameterID:
	@abstract	Seeds the default custom value for a parameter.
	@param		customDefaultValue	An out pointer the subclass sets to the seed value.
	@param		parameterID			The parameter being initialized.
	@discussion	Introduced in FxGrip 0.1.0. The base implementation performs no work. A subclass overrides it to initialize a custom data object, such as an FxGripInterpolatingDictionary. */
- (void)initializeCustomData:(NSObject<NSSecureCoding, NSCopying>* _Nullable * _Nonnull)customDefaultValue parameterID:(FxParameterId)parameterID
{
	//Sub classes can initialize any custom data here.
	//	eg. if the CustomData class is FxGripInterpolatingDictionary, this is where to init its values
	
	//set *customDefaultValue
}

@end
