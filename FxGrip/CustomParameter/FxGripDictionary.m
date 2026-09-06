/*!
	@file       FxGripDictionary.m
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDictionary
	@abstract   Implements the mutable dictionary custom parameter value and its typed accessors.
	@discussion Introduced in FxGrip 0.1.0. The class subclasses NSMutableDictionary as a class
	            cluster wrapper over an inner NSMutableDictionary. It maps the standard typed FxPlug
	            accessors to well-known keys and archives its store through NSSecureCoding.
*/

#import "FxGripDictionary.h"
#import <BEFoundation/FxTime.h>
#import <BEFoundation/BEMutable.h>
#import "FxGrip_ARC.h"

// Locked makes the default keys for types (bool, int, float, etc) only settable if they are already set.
//  So the keys for the automatic var->custum->var must be set in the configuration to be usable,
//		or it must be unlocked.

/*!
	@abstract	A mutable dictionary custom parameter value that answers the host's typed parameter API.
	@discussion	Introduced in FxGrip 0.1.0. An inner NSMutableDictionary holds the store. The typed
				accessors read and write well-known keys, and the lock flag confines the default typed
				setters to keys that already exist.
*/
@implementation FxGripDictionary

- (instancetype)init
{
    self = [super init];
    
    if (self != nil)
    {
		_data = NARC_RETAIN([NSMutableDictionary dictionary]);
    }
    
    return self;
}


- (instancetype)initWithDictionary:(NSDictionary*)dictionary
{
	self = [super init];
	
	if (self != nil)
	{
		_data = [dictionary mutableCopy];
	}
	
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_data);
	
	SUPER_DEALLOC();
}

/*!
	@method		classesForParameter
	@abstract	The secure-coding allow-list of classes a parameter dictionary may carry.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides this to extend the list.
	@result		The ordered set of decodable classes.
*/
+ (NSOrderedSet<Class>*)classesForParameter
{
	return [NSOrderedSet orderedSetWithArray:@[
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
		   [NSMutableData class],
		   [NSData class],
		   [NSValue class],
		   [NSURL class],
		   [NSUUID class],
		   [FxTime class]
		]];
}

#pragma mark -
#pragma mark NSSecureCoding & NSCopying

+ (BOOL)supportsSecureCoding
{
	return YES;
}

// NSDictionary substitutes a plain dictionary class during keyed archiving; encoding the
// receiver's own class keeps initWithCoder: in the round trip.
- (Class)classForCoder
{
	return self.class;
}

/*!
	@method		initWithCoder:
	@abstract	Decodes the store from an archive, restricting values to classesForParameter.
	@discussion	Introduced in FxGrip 0.1.0. A decoded value that is not a dictionary yields an empty store.
*/
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];

	if (self != nil)
	{
		NSDictionary *decoded = nil;
		if (aDecoder.allowsKeyedCoding) {
			NSSet<Class> *classes = [NSSet setWithArray:self.class.classesForParameter.array];
			decoded = [aDecoder decodeObjectOfClasses:classes forKey:@"data"];
		} else {
			decoded = [aDecoder decodePropertyList];
		}
		if ([decoded isKindOfClass:NSDictionary.class]) {
			_data = [decoded mutableCopyRecursive];
		} else {
			_data = NARC_RETAIN([NSMutableDictionary dictionary]);
		}
	}

	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	if (aCoder.allowsKeyedCoding) {
		[aCoder encodeObject:_data forKey:@"data"];
	} else {
		[aCoder encodePropertyList:_data];
	}
}

- (instancetype)copyWithZone:(NSZone *)zone
{
	FxGripDictionary*    newInstance = [[self.class alloc] initWithDictionary:_data];

	return newInstance;
}


- (BOOL)isEqual:(NSObject<NSSecureCoding, NSCopying>*)object
{
	if (self == (id)object) {
		return YES;
	}
	if (![object isKindOfClass:FxGripDictionary.class]) {
		return NO;
	}
	FxGripDictionary*    rhs = (FxGripDictionary*)object;

	return [_data isEqual:rhs.data];
}

- (NSUInteger)hash
{
	return _data.hash;
}


#pragma mark -
#pragma mark NSDictionary & NSMutableDictionary

- (instancetype)initWithObjects:(const id _Nonnull [_Nullable])objects forKeys:(const id <NSCopying> _Nonnull [_Nullable])keys count:(NSUInteger)cnt
{
	self = [super init];

	if (self != nil)
	{
		_data = [NSMutableDictionary dictionaryWithObjects:objects forKeys:keys count:cnt];
	}
	return self;
}

- (instancetype)initWithCapacity:(NSUInteger)numItems
{
	self = [super init];

	if (self != nil)
	{
		_data = NARC_RETAIN([NSMutableDictionary dictionaryWithCapacity:numItems]);
	}
	return self;
}

- (NSUInteger)count
{
	return [_data count];
}

- (nullable NSObject*)objectForKey:(id)aKey;
{
	return [_data objectForKey:aKey];
}

- (NSEnumerator<NSObject*> *)keyEnumerator
{
	return (NSEnumerator*)[_data keyEnumerator];
}

- (void)setObject:(id)anObject
		   forKey:(id<NSCopying>)aKey
{
	[_data setObject:anObject forKey:aKey];
}

- (void)removeObjectForKey:(id)aKey
{
	[_data removeObjectForKey:aKey];
}


#pragma mark -
#pragma mark Locking

/*!
	@method		isLocked
	@abstract	Reports whether the default typed setters are confined to existing keys.
	@discussion	Introduced in FxGrip 0.1.0. The flag lives under kCustomAPI_IsLocked and defaults to YES.
*/
// This is to lock the default API values to only those that are already set.
//  Any API call to set a variable in FxGripMutableParameter will return
//	NO if its not already set.
- (BOOL)isLocked
{
	BOOL locked = YES;
	
	[self getBoolValue:&locked forKey:kCustomAPI_IsLocked];
	
	return locked;
}


- (void)setLocked:(BOOL)locked
{
	BOOL existingLocked = YES;
	if ([self getBoolValue:&existingLocked forKey:kCustomAPI_IsLocked]) {
		if (locked) {
			[self removeObjectForKey:kCustomAPI_IsLocked];
		}
	}
	if (!locked) {
		[self setObject:[NSNumber numberWithBool:locked] forKey:kCustomAPI_IsLocked];
	}
}
/*
 
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (self != nil)
    {
        _hue = [aDecoder decodeDoubleForKey:kKey_Hue];
        _saturation = [aDecoder decodeDoubleForKey:kKey_Saturation];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeDouble:_hue
                  forKey:kKey_Hue];
    [aCoder encodeDouble:_saturation
                  forKey:kKey_Saturation];
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    FxHueSaturation*    newInstance = [[FxHueSaturation alloc] initWithHue:self.hue
                                                                saturation:self.saturation];
    
    return newInstance;
}*/



#pragma mark -
#pragma mark API Parameter Access

// Booleans
- (BOOL)getBoolValue:(BOOL*)boolValue forKey:(id<NSCopying>)aKey
{
	id value = [self objectForKey:aKey];
	if (value && [value isKindOfClass:[NSNumber class]]) {
		*boolValue = [value boolValue];
		return YES;
	}
	return NO;
}

- (BOOL)setBoolValue:(BOOL)boolValue forKey:(id<NSCopying>)aKey
{
	[self setObject:[NSNumber numberWithBool:boolValue] forKey:aKey];
	return YES;
}

- (BOOL)getBoolValue:(BOOL*)boolValue
{
	return [self getBoolValue:boolValue forKey:kCustomAPI_BoolKey];
}

- (BOOL)setBoolValue:(BOOL)boolValue
{
	if (!self.isLocked || [self objectForKey:kCustomAPI_BoolKey]) {
		return [self setBoolValue:boolValue forKey:kCustomAPI_BoolKey];
	}
	return NO;
}


// Floats
- (BOOL)getFloatValue:(double*)floatValue
		 forKey:(id<NSCopying>)aKey
{
	id value = [self objectForKey:aKey];
	if (value && [value isKindOfClass:[NSNumber class]]) {
		*floatValue = [value doubleValue];
		return YES;
	}
	return NO;
}
- (BOOL)setFloatValue:(double)floatValue
		  forKey:(id<NSCopying>)aKey
{
	[self setObject:[NSNumber numberWithDouble:floatValue] forKey:aKey];
	return YES;
}

- (BOOL)getFloatValue:(double*)floatValue
{
	return [self getFloatValue:floatValue forKey:kCustomAPI_FloatKey];
}

- (BOOL)setFloatValue:(double)floatValue
{
	if (!self.isLocked || [self objectForKey:kCustomAPI_FloatKey]) {
		return [self setFloatValue:floatValue forKey:kCustomAPI_FloatKey];
	}
	return NO;
}


// Histograms
/*!
	@method		getHistogramBlackIn:blackOut:whiteIn:whiteOut:gamma:forChannel:forKey:
	@abstract	Reads one histogram channel's levels from the array stored at a key.
	@discussion	Introduced in FxGrip 0.1.0. The stored array holds one entry per channel. The RGB
				channel averages the red, green, and blue entries. A missing entry yields the identity
				levels: black-in 0, black-out 0, white-in 1, white-out 1, gamma 1.
*/
//bIn, bOut, wIn, wOut, & gamma for each RGBA
- (BOOL)getHistogramBlackIn:(double*)blackIn
				   blackOut:(double*)blackOut
					whiteIn:(double*)whiteIn
				   whiteOut:(double*)whiteOut
					  gamma:(double*)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>)aKey
{
	id histogram = [self objectForKey:aKey];

	if (histogram && [histogram isKindOfClass:[NSArray class]]) {
		unsigned long count = [histogram count];
		
		if (((count == 1 || count == 2) && channel != kFxHistogramChannel_Alpha) || (count >= 3 && channel == kFxHistogramChannel_Red)) {
			*blackIn = [histogram[0][0] doubleValue];
			*blackOut = [histogram[0][1] doubleValue];
			*whiteIn = [histogram[0][2] doubleValue];
			*whiteOut = [histogram[0][3] doubleValue];
			*gamma = [histogram[0][4] doubleValue];
		} else if((count == 2 && channel == kFxHistogramChannel_Alpha) || (count >= 3 && channel == kFxHistogramChannel_Green)) {
			*blackIn = [histogram[1][0] doubleValue];
			*blackOut = [histogram[1][1] doubleValue];
			*whiteIn = [histogram[1][2] doubleValue];
			*whiteOut = [histogram[1][3] doubleValue];
			*gamma = [histogram[1][4] doubleValue];
		} else if(count >= 3 && channel == kFxHistogramChannel_Blue) {
			*blackIn = [histogram[2][0] doubleValue];
			*blackOut = [histogram[2][1] doubleValue];
			*whiteIn = [histogram[2][2] doubleValue];
			*whiteOut = [histogram[2][3] doubleValue];
			*gamma = [histogram[2][4] doubleValue];
		} else if(count >= 3 && channel == kFxHistogramChannel_RGB) {
			*blackIn = ([histogram[0][0] doubleValue] + [histogram[1][0] doubleValue] + [histogram[2][0] doubleValue]) / 3.0;
			*blackOut = ([histogram[0][1] doubleValue] + [histogram[1][1] doubleValue] + [histogram[2][1] doubleValue]) / 3.0;
			*whiteIn = ([histogram[0][2] doubleValue] + [histogram[1][2] doubleValue] + [histogram[2][2] doubleValue]) / 3.0;
			*whiteOut = ([histogram[0][3] doubleValue] + [histogram[1][3] doubleValue] + [histogram[2][3] doubleValue]) / 3.0;
			*gamma = ([histogram[0][4] doubleValue] + [histogram[1][4] doubleValue] + [histogram[2][4] doubleValue]) / 3.0;
		} else if(count >= 4 && channel == kFxHistogramChannel_Alpha) {
			*blackIn = [histogram[3][0] doubleValue];
			*blackOut = [histogram[3][1] doubleValue];
			*whiteIn = [histogram[3][2] doubleValue];
			*whiteOut = [histogram[3][3] doubleValue];
			*gamma = [histogram[3][4] doubleValue];
		} else {
			*blackIn = 0.0;
			*blackOut = 0.0;
			*whiteIn = 1.0;
			*whiteOut = 1.0;
			*gamma = 1.0;
		}
		return YES;
	}
	return NO;
}

/*!
	@method		setHistogramBlackIn:blackOut:whiteIn:whiteOut:gamma:forChannel:forKey:
	@abstract	Writes one histogram channel's levels into the array stored at a key.
	@discussion	Introduced in FxGrip 0.1.0. The array grows to four channel entries on first write.
				The RGB channel writes the red, green, and blue entries; a specific channel writes
				only its own entry.
*/
- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>)aKey
{
	id histogram = [self objectForKey:aKey];

	if (!histogram || ![histogram isKindOfClass:[NSMutableArray class]]) {
		histogram = [NSMutableArray arrayWithCapacity:4];
	}
	if ([histogram count] < 4) {
		NSNumber *zero = [NSNumber numberWithDouble:0];
		NSNumber *one = [NSNumber numberWithDouble:1];
		NSMutableArray *channel = [NSMutableArray arrayWithObjects:zero, zero, one, one, one, nil];
		[histogram addObject:channel];
		if ([histogram count] < 4)
			[histogram addObject:[NSMutableArray arrayWithArray:channel]];
		if ([histogram count] < 4)
			[histogram addObject:[NSMutableArray arrayWithArray:channel]];
		if ([histogram count] < 4)
			[histogram addObject:[NSMutableArray arrayWithArray:channel]];
	}
	// Channel RGB (0) writes the three color channels; a specific channel writes only
	// its own entry at index channel - 1.
	for(unsigned long i = (channel == kFxHistogramChannel_RGB) ? 1 : channel;
		i < ((channel == kFxHistogramChannel_RGB) ? 4 : channel + 1); i++) {
		id channelData = histogram[i - 1];
		if (![channelData isKindOfClass:[NSMutableArray class]]) {
			channelData = [NSMutableArray arrayWithCapacity:5];
			histogram[i - 1] = channelData;
		}
		channelData[0] = [NSNumber numberWithDouble:blackIn];
		channelData[1] = [NSNumber numberWithDouble:blackOut];
		channelData[2] = [NSNumber numberWithDouble:whiteIn];
		channelData[3] = [NSNumber numberWithDouble:whiteOut];
		channelData[4] = [NSNumber numberWithDouble:gamma];
	}

	[self setObject:histogram forKey:aKey];
	return YES;
}

- (BOOL)getHistogramBlackIn:(double*)blackIn
				   blackOut:(double*)blackOut
					whiteIn:(double*)whiteIn
				   whiteOut:(double*)whiteOut
					  gamma:(double*)gamma
				 forChannel:(FxHistogramChannel)channel
{
	return [self getHistogramBlackIn:blackIn
							blackOut:blackOut
							 whiteIn:whiteIn
							whiteOut:whiteOut
							   gamma:gamma
						  forChannel:channel
							  forKey:kCustomAPI_HistogramKey];
}

- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel
{
	if (!self.isLocked || [self objectForKey:kCustomAPI_HistogramKey]) {
		return [self setHistogramBlackIn:blackIn
								blackOut:blackOut
								 whiteIn:whiteIn
								whiteOut:whiteOut
								   gamma:gamma
							  forChannel:channel
								  forKey:kCustomAPI_HistogramKey];
	}
	return NO;
}


// Integers
- (BOOL)getIntValue:(int*)intValue
		 forKey:(id<NSCopying>)aKey
{
	id value = [self objectForKey:aKey];
	if (value && [value isKindOfClass:[NSNumber class]]) {
		*intValue = [value intValue];
		return YES;
	}
	return NO;
}
- (BOOL)setIntValue:(int)intValue
		  forKey:(id<NSCopying>)aKey
{
	[self setObject:[NSNumber numberWithInt:intValue] forKey:aKey];
	return YES;
}
- (BOOL)getIntValue:(int*)intValue
{
	return [self getIntValue:intValue forKey:kCustomAPI_IntKey];
}

- (BOOL)setIntValue:(int)intValue
{
	if (!self.isLocked || [self objectForKey:kCustomAPI_IntKey]) {
		return [self setIntValue:intValue forKey:kCustomAPI_IntKey];
	}
	return NO;
}


// PathId
- (BOOL)getPathID:(FxPathID*)pathID
		 forKey:(id<NSCopying>)aKey
{
	id value = [self objectForKey:aKey];
	if (value && [value isKindOfClass:[NSNumber class]]) {
		*pathID = (FxPathID)[value unsignedLongLongValue];
		return YES;
	}
	return NO;
}
- (BOOL)setPathID:(FxPathID)pathID
		  forKey:(id<NSCopying>)aKey
{
	[self setObject:[NSNumber numberWithUnsignedLongLong:(unsigned long long)pathID] forKey:aKey];
	return YES;
}
- (BOOL)getPathID:(FxPathID*)pathID
{
	return [self getPathID:pathID forKey:kCustomAPI_PathIDKey];
}

- (BOOL)setPathID:(FxPathID)pathID
{
	if (!self.isLocked || [self objectForKey:kCustomAPI_PathIDKey]) {
		return [self setPathID:pathID forKey:kCustomAPI_PathIDKey];
	}
	return NO;
}


// RGBA

- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue
		 alphaValue:(double*)alpha
			 forKey:(id<NSCopying>)aKey
{
	id value = [self objectForKey:aKey];
	if (value && [value isKindOfClass:[NSArray class]] && [value count]) {
		if ([value count] <= 2) {
			*red = *green = *blue = [value[0] doubleValue];
			*alpha = ([value count] == 1) ? 1.0 : [value[1] doubleValue];
		} else {
			*red = [value[0] doubleValue];
			*green = [value[1] doubleValue];
			*blue = [value[2] doubleValue];
			*alpha = ([value count] == 3) ? 1.0 : [value[3] doubleValue];
		}
		return YES;
	}
	return NO;
}

- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		 alphaValue:(double)alpha
			 forKey:(id<NSCopying>)aKey
{
	id rgba = [self objectForKey:aKey];
	
	if (!rgba || ![rgba isKindOfClass:[NSMutableArray class]]) {
		rgba = [NSMutableArray arrayWithCapacity:4];
	}
	rgba[0] = [NSNumber numberWithDouble:red];
	rgba[1] = [NSNumber numberWithDouble:green];
	rgba[2] = [NSNumber numberWithDouble:blue];
	rgba[3] = [NSNumber numberWithDouble:alpha];
	
	[self setObject:rgba forKey:aKey];
	return YES;
}

- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue
		 alphaValue:(double*)alpha
{
	return [self getRedValue:red
				  greenValue:green
				   blueValue:blue
				  alphaValue:alpha
					  forKey:kCustomAPI_RGBAKey];
}

- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		 alphaValue:(double)alpha
{
	if (!self.isLocked || [self objectForKey:kCustomAPI_RGBAKey]) {
		return [self setRedValue:red
					  greenValue:green
					   blueValue:blue
					  alphaValue:alpha
						  forKey:kCustomAPI_RGBAKey];
	}
	return NO;
}


// RGB

- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue
			 forKey:(id<NSCopying>)aKey
{
	id value = [self objectForKey:aKey];
	if (value && [value isKindOfClass:[NSArray class]] && [value count]) {
		if ([value count] <= 2) {
			*red = *green = *blue = [value[0] doubleValue];
		} else {
			*red = [value[0] doubleValue];
			*green = [value[1] doubleValue];
			*blue = [value[2] doubleValue];
		}
		return YES;
	}
	return NO;
}

- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
			 forKey:(id<NSCopying>)aKey
{
	id rgb = [self objectForKey:aKey];
	
	if (!rgb || ![rgb isKindOfClass:[NSMutableArray class]]) {
		rgb = [NSMutableArray arrayWithCapacity:4];
	}
	rgb[0] = [NSNumber numberWithDouble:red];
	rgb[1] = [NSNumber numberWithDouble:green];
	rgb[2] = [NSNumber numberWithDouble:blue];
	
	[self setObject:rgb forKey:aKey];
	return YES;
}

- (BOOL)getRedValue:(double*)red
		 greenValue:(double*)green
		  blueValue:(double*)blue
{
	return [self getRedValue:red
				  greenValue:green
				   blueValue:blue
					  forKey:kCustomAPI_RGBKey];
}
- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
{
	if (!self.isLocked || [self objectForKey:kCustomAPI_RGBKey]) {
		return [self setRedValue:red
					  greenValue:green
					   blueValue:blue
						  forKey:kCustomAPI_RGBKey];
	}
	return NO;
}

- (BOOL)getStringParameterValue:(NSString**)string
				forKey:(id<NSCopying>)aKey
{
	id value = [self objectForKey:aKey];
	if (value && [value isKindOfClass:[NSString class]]) {
		*string = value;
		return YES;
	}
	if (value && [value isKindOfClass:[NSNumber class]]) {
		*string = [value stringValue];
		return YES;
	}
	return NO;
}

- (BOOL)setStringParameterValue:(NSString*)string
				forKey:(id<NSCopying>)aKey
{
	[self setObject:string forKey:aKey];
	return YES;
}

- (BOOL)getStringParameterValue:(NSString**)string
{
	return [self getStringParameterValue:string forKey:kCustomAPI_StringKey];
}

- (BOOL)setStringParameterValue:(NSString*)string
{
	if (!self.isLocked || [self objectForKey:kCustomAPI_StringKey]) {
		return [self setStringParameterValue:string forKey:kCustomAPI_StringKey];
	}
	return NO;
}



- (BOOL)getXValue:(double*)x
		   YValue:(double*)y
		   forKey:(id<NSCopying>)aKey
{
	id point = [self objectForKey:aKey];
	if (point && [point isKindOfClass:[NSArray class]] && [point count] == 2) {
		*x = [point[0] doubleValue];
		*y = [point[1] doubleValue];
		return YES;
	}
	return NO;
}

- (BOOL)setXValue:(double)x
		   YValue:(double)y
		   forKey:(id<NSCopying>)aKey
{
	id point = [self objectForKey:aKey];
	
	if (!point || ![point isKindOfClass:[NSMutableArray class]]) {
		point = [NSMutableArray arrayWithCapacity:2];
	}
	point[0] = [NSNumber numberWithDouble:x];
	point[1] = [NSNumber numberWithDouble:y];
	
	[self setObject:point forKey:aKey];
	return YES;
}

- (BOOL)getXValue:(double*)x
		   YValue:(double*)y
{
	return [self getXValue:x YValue:y forKey:kCustomAPI_PointKey];
}

- (BOOL)setXValue:(double)x
		   YValue:(double)y
{
	if (!self.isLocked || [self objectForKey:kCustomAPI_PointKey]) {
		return [self setXValue:x YValue:y forKey:kCustomAPI_PointKey];
	}
	return NO;
}




- (NSOrderedSet<Class> *)classesForParameter {
	return self.class.classesForParameter;
}

// Fast enumeration, mutable copying, description, and the key/value collections all
// derive from the five dictionary primitives implemented above; overriding them here
// with stubs is what broke the class-cluster contract.

/*!
	@method		exemptKeys
	@abstract	The mutable array of keys exempt from interpolation.
	@discussion	Introduced in FxGrip 0.1.0. The array is created on first access and always contains
				the exempt-keys key and the last-changed key.
*/
- (NSMutableArray*)exemptKeys
{
	NSMutableArray *exemptKeys = [self objectForKey:kCustomAPI_ExemptKeysKey];

	if (!exemptKeys) {
		exemptKeys = [NSMutableArray arrayWithCapacity:1];
	}
	if (exemptKeys && ![exemptKeys isKindOfClass:[NSMutableArray class]]) {
		if ([exemptKeys isKindOfClass:[NSArray class]]) {
			exemptKeys = [NSMutableArray arrayWithArray:exemptKeys];
		} else {
			id priorValue = exemptKeys;
			exemptKeys = [NSMutableArray arrayWithCapacity:2];
			[exemptKeys addObject:priorValue];
		}
	}
	if (![exemptKeys containsObject:kCustomAPI_ExemptKeysKey]) {
		[exemptKeys addObject:kCustomAPI_ExemptKeysKey];
	}
	if (![exemptKeys containsObject:kCustomAPI_LastChangedKey]) {
		[exemptKeys addObject:kCustomAPI_LastChangedKey];
	}
	[self setObject:exemptKeys forKey:kCustomAPI_ExemptKeysKey];
	return exemptKeys;
}

@end
