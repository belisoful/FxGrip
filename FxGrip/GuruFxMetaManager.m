/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  MasterFXAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxCustomDataClasses.h"
#import "GuruFxMetaManager.h"
#import "FXParameterFlags.h"
#import "FxTileableEffectBase.h"
#import "GuruFxOOBParameterAccess.h"
#import "GuruFxPreset.h"
#import "FxTime.h"
#import "NSArray+BExtension.h"
#import "NSSet+BExtension.h"
#import "NSOrderedSet+BExtension.h"
#import "NSDictionary+FxTileableEffect.h"
#import "NSDictionary+BExtension.h"

@implementation GuruFxMetaManager
{
	NSRecursiveLock		*mMetaLock;
}

@synthesize count;
@synthesize effect = _effect;
@synthesize tags = _tags;

- (nonnull instancetype)init
{
	return [self initWithEffect:nil];
}

- (nonnull instancetype)initWithEffect:(GuruFxTileableEffect* _Nullable)effect
{
	self = [super init];
	
	if (self != nil)
	{
		// Space for 
		_data = [NSMutableDictionary dictionaryWithCapacity:5];
		_effect = effect;
		
		_data[kFxMetaProperty_Tags] = __tags = [NSMutableDictionary dictionary];
		_data[kFxMetaProperty_Parameters] = __parameters = [NSMutableDictionary dictionary];
		mMetaLock = [NSRecursiveLock.alloc init];
	}
	return self;
}

- (instancetype)initWithMeta:(GuruFxMetaManager *)metaManager
{
	self = [super init];
	
	if (self != nil)
	{
		_data = [metaManager.data mutableCopyRecursive];
		__tags = (id)_data[kFxMetaProperty_Tags];
		__parameters = (id)_data[kFxMetaProperty_Parameters];
		mMetaLock = [NSRecursiveLock.alloc init];
		_effect = metaManager.effect;
	}
	
	return self;
}

- (void)dealloc
{
	_tags = nil;
	__tags = nil;
	__parameters = nil;
	mMetaLock = nil;
	_data = nil;
	_effect = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark NSSecureCoding & NSCopying

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];
	
	if (self != nil)
	{
		_data = [aDecoder decodeObject];
		[_data retain];
		__tags = (id)_data[kFxMetaProperty_Tags];
		__parameters = (id)_data[kFxMetaProperty_Parameters];
		mMetaLock = [NSRecursiveLock.alloc init];
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:_data];
}


- (BOOL)isEqual:(NSObject<NSSecureCoding, NSCopying>*)object
{
	GuruFxMetaManager*    rhs = (GuruFxMetaManager*)object;
	
	return [_data isEqual:rhs.data];
}

- (instancetype)copyWithZone:(NSZone *)zone
{
	GuruFxMetaManager*    newInstance = [[self.class alloc] initWithMeta:self];
	return newInstance;
}

- (void)setEffect:(GuruFxTileableEffect* _Nonnull)effect
{
	_effect = effect;
}

+ (NSOrderedSet<Class>*)classesForParameter;
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
			[NSFxTime class]
			]
		];
}


#pragma mark -
#pragma mark NSDictionary & NSMutableDictionary


- (instancetype)initWithObjects:(id  _Nonnull const *)objects
						forKeys:(id<NSCopying>  _Nonnull const *)keys
						  count:(NSUInteger)cnt
{
	self = [super init];
	
	if (self != nil)
	{
		_data = [NSMutableDictionary dictionaryWithObjects:objects forKeys:keys count:cnt];
		// Effect still need to be set.  Not a proper meta manager without its associated effect.
		
		//Uptake the tags and parameters
		__tags = (NSMutableDictionary*)_data[kFxMetaProperty_Tags];
		__parameters = (NSMutableDictionary*)_data[kFxMetaProperty_Parameters];
		mMetaLock = [NSRecursiveLock.alloc init];
	}
	return self;
}

- (NSUInteger)count
{
	[self lock];
	NSUInteger size = [_data count];
	[self unlock];
	return size;
}

- (nullable NSObject*)objectForKey:(id)aKey;
{
	[self lock];
	id value = [_data objectForKey:aKey];
	[self unlock];
	return value;
}

- (NSEnumerator<NSObject*> *)keyEnumerator
{
	[self lock];
	NSEnumerator* enumerator = (NSEnumerator*)[_data keyEnumerator];
	[self unlock];
	return enumerator;
}

- (void)setObject:(id)anObject
		   forKey:(id<NSCopying>)aKey
{
	[self lock];
	[_data setObject:anObject forKey:aKey];
	[self unlock];
}

- (void)removeObjectForKey:(id)aKey
{
	[self lock];
	[_data removeObjectForKey:aKey];
	[self unlock];
}

#pragma mark -
#pragma mark Instance Management

/*
 {
 	[[NSNotificationCenter defaultCenter] addObserver:self
										selector:@selector(timeChangeNotificationInvalidateCache:)
											name:NSSystemClockDidChangeNotification
										  object:nil];
 [[NSNotificationCenter defaultCenter] removeObserver:self name:NSSystemClockDidChangeNotification object:nil];
 }
 
// only added as notifier if we have meta
- (void)timeChangeNotificationInvalidateCache:(NSNotification *)notification
{
	GuruFxOOBParameterAccess *accessor = [GuruFxOOBParameterAccess access:self.effect.apiManager];
	
	CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
	if (now < _lastModified)
		[self.effect.apiManager.paramSetAPIv5 setFloatValue:now toParameter:kFxParameterId_InstanceMetaModified atTime:kCMTimeZero];
	[self clearCache];
	
	[accessor retainCount];
}*/

- (BOOL)metaInstalled
{
	return [self parameterExists:kFxParameterId_InstanceMeta];
}



#pragma mark -
#pragma mark Parameter CRUD & Flags APIs

- (BOOL)addParameter:(FxParameterId)parameterID type:(FxParameterType)type flags:(FxParameterFlags)flags
{
	BOOL success = YES;
	[self lock];
	
	// Check for existing parameter ID
	NSNumber *pid = @(parameterID);
	
	// can be preset if no Param ID is set
	if (__parameters[pid] && __parameters[pid][kFxMetaProperty_ParamId]) {
		NSLog(@"GuruFxMetaManager::addParameter Error: Parameter already exists");
		success = NO;
	} else {
		unsaved = YES;
		if (!__parameters[pid] || ![__parameters[pid] isKindOfClass:[NSDictionary class]])
			__parameters[pid] = [NSMutableDictionary dictionary];
		else if (![__parameters[pid] isKindOfClass:[NSMutableDictionary class]]) {
			__parameters[pid] = [__parameters[pid] mutableCopy];
		}
		
		//add the basic parameter properties: ID, Type,
		__parameters[pid][kFxMetaProperty_ParamId] = pid;
		__parameters[pid][kFxMetaProperty_ParamType] = @(type);
		__parameters[pid][kFxMetaProperty_ParamFlags] = @(flags);
		__parameters[pid][kFxMetaProperty_ParamTags] = [NSMutableDictionary dictionary];
		__parameters[pid][kFxMetaProperty_ParamMeta] = [NSMutableDictionary dictionary];
	}
	
	[self unlock];
	return success;
}


- (BOOL)addParameter:(FxParameterId)parameterID customClass:(Class)dataClass flags:(FxParameterFlags)flags
{
	BOOL success = YES;
	[self lock];
	success = [self addParameter:parameterID type:FxParameterType_Custom flags:flags];
	if (success) {
		__parameters[@(parameterID)][kFxMetaProperty_ParamCustomClass] = dataClass.className;
		NSMutableOrderedSet<NSString*> *customClasses = [NSMutableOrderedSet orderedSetWithObject:dataClass.className];
		
		if ([dataClass conformsToProtocol:@protocol(FxCustomDataClasses)]) {
			[customClasses unionOrderedSet:dataClass.classesForParameter.toStringsFromClasses];
		}
		NSSet<NSString*> *priorCustomClasses = __parameters[@(parameterID)].parameterCustomClasses;
		if (priorCustomClasses) {
			[customClasses unionSet:priorCustomClasses];
		}
		
		__parameters[@(parameterID)][kFxMetaProperty_ParamCustomClasses] = [customClasses copy];
	}
	
	[self unlock];
	return success;
}

- (BOOL)removeParameter:(FxParameterId)parameterID
{
	[self lock];
	
	BOOL success = YES;
	// Check for existing parameter ID
	NSNumber *pid = @(parameterID);
	NSMutableDictionary *paramData = __parameters[pid];
	if (paramData) {
		[__parameters removeObjectForKey:pid];
		unsaved = YES;
	} else {
		NSLog(@"GuruFxMetaManager::removeParameter Error: Parameter already does not exist");
		success = NO;
		
	}
	
	[self unlock];
	return success;
}



// The kFxParameterFlag_CACHE is also saved here
- (BOOL)getParameterFlags:(nonnull FxParameterFlags *)flags fromParameter:(UInt32)parameterID
{
	BOOL success = YES;
	[self lock];
	NSNumber *pid = @(parameterID);
	NSMutableDictionary *paramData = __parameters[pid];
	if (paramData) {
		NSNumber *pflags = paramData[kFxMetaProperty_ParamFlags];
		if (pflags != nil) {
			*flags = (FxParameterFlags)pflags.longLongValue;
		} else {
			NSLog(@"GuruFxMetaManager::removeParameter Error: Parameter has no flags");
			success = NO;
		}
	} else {
		NSLog(@"GuruFxMetaManager::removeParameter Error: Parameter does not exist");
		success = NO;
		
	}
	[self unlock];
	return success;
}

// This can be used instead of the API to accumulate flags.  This sets the
// kFxParameterFlag_CACHE flag unless it is specifically flagged with
//	kFxParameterFlag_SAVING to prevent the change flag from being set.
// kFxParameterFlag_SAVING is used by the API when the flags are saved.
// The changed bypass flag is only a one time use, and this method will remove
//  the changed bypass once it skips setting the changed flag.
- (BOOL)setParameterFlags:(FxParameterFlags)flags toParameter:(UInt32)parameterID
{
	BOOL success = YES;
	[self lock];
	NSMutableDictionary *paramData = __parameters[@(parameterID)];
	if (paramData) {
		if (!(flags & kFxParameterFlag_SAVING)) {
			
			flags |= kFxParameterFlag_CACHE;
		} else {
			// remove the changed bypass flag b/c it's one use.
			flags &= ~kFxParameterFlag_SAVING;
		}
		unsaved = YES;
		paramData[kFxMetaProperty_ParamFlags] = @(flags);
	} else {
		NSLog(@"GuruFxMetaManager::removeParameter Error: Parameter does not exist");
		success = NO;
		
	}
	[self unlock];
	return success;
}

- (BOOL)addFlags:(FxParameterFlags)flags toParameter:(UInt32)parameterID
{
	FxParameterFlags appFlags = 0;
	BOOL success = NO;
	
	[self lock];
	if([self getParameterFlags:&appFlags fromParameter:parameterID]) {
		// If any flags are off, by inverting bits then "bit and" with flags. not 0 if any bits need switching
		if(((~appFlags) & flags)) {
			appFlags |= flags;
			success = [self setParameterFlags:appFlags toParameter:parameterID];
		}
	} else {
		NSLog(@"GuruFxParameterSettingAPI_v6::addFlags - Error did not get parameters for id %d", parameterID);
	}
	[self unlock];
	return success;
}
- (BOOL)removeFlags:(FxParameterFlags)flags fromParameter:(UInt32)parameterID
{
	FxParameterFlags appFlags = 0;
	BOOL success = NO;
	
	[self lock];
	if([self getParameterFlags:&appFlags fromParameter:parameterID]) {
		// If any flags are on,  "bit and" with flags.  not 0 if any bits are on to turn off
		if((appFlags & flags)) {
			unsaved = YES;
			appFlags &= ~flags;
			success = [self setParameterFlags:appFlags toParameter:parameterID];
		}
	} else {
		NSLog(@"GuruFxParameterSettingAPI_v6::addFlags - Error did not get parameters for id %d", parameterID);
	}
	[self unlock];
	return success;
}

- (NSMutableDictionary* _Nullable)parameterData:(FxParameterId)parameterID
{
	NSMutableDictionary *paramData = nil;
	[self lock];
	paramData = __parameters[@(parameterID)];
	[self unlock];
	return paramData;
}

- (id _Nullable)parameterData:(FxParameterId)parameterID forKey:(id)key
{
	NSDictionary *paramData = [self parameterData:parameterID];
	if (paramData)
		return paramData[key];
	return nil;
}

- (FxParameterType)parameterType:(FxParameterId)parameterID
{
	FxParameterType type = FxParameterType_None;
	[self lock];
	
	NSMutableDictionary *paramData = [self parameterData:parameterID];
	if (paramData) {
		NSNumber *ptype = paramData[kFxMetaProperty_ParamType];
		if (ptype != nil) {
			type = (FxParameterType)ptype.intValue;
		} else {
			NSLog(@"GuruFxMetaManager::removeParameter Error: Existing Parameter does not have a type.");
		}
	}
	[self unlock];
	
	return type;
}

- (BOOL)parameterExists:(FxParameterId)parameterID
{
	BOOL exists = NO;
	[self lock];
	
	exists =  [self parameterData:parameterID] != nil;
	[self unlock];
	
	return exists;
}

#pragma mark -
#pragma mark Cache Management


- (BOOL)saveMeta
{
	BOOL success = YES;
	[self lock];
	if (unsaved) {
		unsaved = NO;
		
		id<FxParameterSettingAPI_v5> paramSetAPIv5 = self.effect.apiManager.paramSetAPIv5;
		for (NSNumber *pid in __parameters) {
			NSMutableDictionary *paramData = __parameters[pid];
			FxParameterFlags flags = paramData.parameterFlags;
			int pidInt = [pid intValue];
			
			//Update the values
			if (flags & kFxParameterFlag_CACHEDIRTY) {
				flags &= kFxParameterFlag_CACHEDIRTY;
				id newValue = [paramData objectForKey:kFxMetaProperty_ParamValue];
				NSFxTime *newValueTime = [paramData objectForKey:kFxMetaProperty_ParamValueTime];
				if (newValue) {
					[paramData removeObjectForKey:kFxMetaProperty_ParamValue];
					if (newValueTime)
						[GuruFxPreset setParameterValue:newValue toParameter:pidInt atTime:newValueTime.time withAPI:paramSetAPIv5];
				}
				if (newValueTime) {
					[paramData removeObjectForKey:kFxMetaProperty_ParamValueTime];
				}
			}
			if (flags & kFxParameterFlag_CACHE) {
				flags &= kFxParameterFlag_CACHE;
				[paramSetAPIv5 setParameterFlags:flags toParameter:[pid intValue]];
			}
		}
		
		[self.effect.apiManager.paramSetAPIv5 setCustomParameterValue:self toParameter:kFxParameterId_InstanceMeta atTime:kCMTimeZero];
	}
	[self unlock];
	return success;
}

- (void)setUnsaved:(BOOL)unsavedValue
{
	unsaved = unsavedValue;
}


#pragma mark -
#pragma mark Parameter Tags

- (NSArray*)tags
{
	if (!_tags) {
		_tags = [__tags allKeys];
	}
	return _tags;
}

- (SInt32)tagCount
{
	return (SInt32)[__tags count];
}

- (SInt32)tagCount:(FxParameterId)parameterID
{
	NSMutableArray *pTags = [self parameterData:parameterID forKey:kFxMetaProperty_ParamTags];
	
	if (!pTags) {
		return -1;
	}
	return (SInt32)[pTags count];
}

- (NSArray* _Nullable)parameterTags:(FxParameterId)parameterID;
{
	NSMutableArray *pTags = [self parameterData:parameterID forKey:kFxMetaProperty_ParamTags];
	if (pTags) {
		return [pTags copy];
	}
	return nil;
}

- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString* _Nullable)tag error:(NSError* _Nullable *)error
{
	NSMutableArray *pTags = [self parameterData:parameterID forKey:kFxMetaProperty_ParamTags];
	
	if (pTags) {
		return [pTags containsObject:tag];
	} else if(error) {
		*error = [NSError errorWithDomain:FxPlugErrorDomain
								   code:kFxError_ThirdPartyDeveloperStart + parameterID
							   userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }];
	}
	return NO;
}

- (NSError* _Nullable)setTags:(NSArray*_Nonnull)tags toParameter:(FxParameterId)parameterID
{
	[self removeAllTags:parameterID];
	return nil;
}

- (NSError* _Nullable)addTag:(NSString*_Nullable)tag toParameter:(FxParameterId)parameterID;
{
	NSMutableArray *pTags = [self parameterData:parameterID forKey:kFxMetaProperty_ParamTags];
	
	if (pTags) {
		if (![pTags containsObject:tag]) {
			unsaved = YES;
			[pTags addObject:tag];
			
			if (!__tags[tag]) {
				__tags[tag] = [NSMutableArray array];
			}
			
			[__tags[tag] addObject:[NSNumber numberWithInt:parameterID]];
		}
	} else {
		return [NSError errorWithDomain:FxPlugErrorDomain
								   code:kFxError_ThirdPartyDeveloperStart + parameterID
							   userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }];
	}
	return nil;
}

- (NSError* _Nullable)removeTag:(NSString*_Nullable)tag fromParameter:(FxParameterId)parameterID
{
	NSMutableArray *pTags = [self parameterData:parameterID forKey:kFxMetaProperty_ParamTags];
	
	if (pTags) {
		if ([pTags containsObject:tag]) {
			unsaved = YES;
			[pTags removeObject:tag];
			
			[__tags[tag] removeObject:[NSNumber numberWithInt:parameterID]];
			if (![__tags[tag] count]) {
				[__tags removeObjectForKey:tag];
			}
		}
	} else {
		return [NSError errorWithDomain:FxPlugErrorDomain
								   code:kFxError_ThirdPartyDeveloperStart + parameterID
							   userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }];
	}
	return nil;
}

- (NSError* _Nullable)removeAllTags:(FxParameterId)parameterID
{
	NSMutableArray *pTags = [self parameterData:parameterID forKey:kFxMetaProperty_ParamTags];
	
	if (pTags) {
		NSNumber *pid = [NSNumber numberWithInt:parameterID];
		NSString *tag = nil;
		for (tag in pTags) {
			unsaved = YES;
			[__tags[tag] removeObject:pid];
			if (![__tags[tag] count]) {
				[__tags removeObjectForKey:tag];
			}
		}
		[pTags removeAllObjects];
	} else {
		return [NSError errorWithDomain:FxPlugErrorDomain
								   code:kFxError_ThirdPartyDeveloperStart + parameterID
							   userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }];
	}
	return nil;
}

- (NSArray* _Nullable)parametersWithTag:(NSString*_Nullable)tag
{
	NSMutableArray *paramsWithTag = __tags[tag];
	if (paramsWithTag != nil) {
		return [paramsWithTag copy];
	}
	return nil;
}


#pragma mark -
#pragma mark Parameter Meta Data

- (SInt32)metaCountFromParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *paramData = __parameters[@(parameterID)];
	if (!paramData) {
		return -1;
	}
	return (SInt32)((NSDictionary*)paramData[kFxMetaProperty_ParamMeta]).count;
}

- (NSError*_Nullable)getMeta:(NSDictionary*_Nullable*_Nullable)meta fromParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *paramData = __parameters[@(parameterID)];
	if (!paramData) {
		return [NSError errorWithDomain:FxPlugErrorDomain
								   code:kFxError_ThirdPartyDeveloperStart + parameterID
							   userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }];
	}
	return [paramData[kFxMetaProperty_ParamMeta] copy];
}

- (NSError*_Nullable)setMeta:(NSDictionary*_Nonnull) meta   toParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *paramData = __parameters[@(parameterID)];
	if (!paramData) {
		return [NSError errorWithDomain:FxPlugErrorDomain
								   code:kFxError_ThirdPartyDeveloperStart + parameterID
							   userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }];
	}
	if (!meta) {
		meta = @{};
	}
	[paramData setObject:[meta mutableCopy] forKey:kFxMetaProperty_ParamMeta];
	return nil;
}

- (NSError*_Nullable)getMetaKeys:(NSArray *_Nullable*_Nullable)keys fromParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *paramData = __parameters[@(parameterID)];
	if (!paramData) {
		return [NSError errorWithDomain:FxPlugErrorDomain
								   code:kFxError_ThirdPartyDeveloperStart + parameterID
							   userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }];
	}
	if (!keys) {
		return [NSError errorWithDomain:FxPlugErrorDomain
								   code:kFxError_ThirdPartyDeveloperStart + parameterID
							   userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"keys is nil and can't be set for parameter (", parameterID, @") tags."] }];
	}
	*keys = [paramData[kFxMetaProperty_ParamMeta] allKeys];
	return nil;
}

- (NSError*_Nullable)removeAllMeta:(FxParameterId)parameterID
{
	NSMutableDictionary *paramData = __parameters[@(parameterID)];
	if (!paramData) {
		return [NSError errorWithDomain:FxPlugErrorDomain
								   code:kFxError_ThirdPartyDeveloperStart + parameterID
							   userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }];
	}
	[paramData[kFxMetaProperty_ParamMeta] removeAllObjects];
	return nil;
}


- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString*_Nonnull)key error:(NSError*_Nullable*_Nullable)error
{
	NSMutableDictionary *paramData = __parameters[@(parameterID)];
	if (!paramData) {
		if (error) {
			*error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxError_ThirdPartyDeveloperStart + parameterID
									 userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }];
		}
		return NO;
	}
	
	id pMeta = paramData[kFxMetaProperty_ParamMeta][key];
	
	return pMeta != nil;
}


- (BOOL)getMeta:(NSObject<NSSecureCoding,NSCopying> * _Nullable * _Nonnull)value forKey:(NSString* _Nullable)key fromParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *paramData = __parameters[@(parameterID)];
	if (!paramData) {
		return NO;
	}
	
	id pMeta = paramData[kFxMetaProperty_ParamMeta][key];
	if (!pMeta)
		return NO;
	
	if (value)
		*value = pMeta;
	
	return YES;
}


- (BOOL)setMeta:(NSObject<NSSecureCoding,NSCopying>*_Nonnull)value forKey:(NSString*_Nullable)key toParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *paramData = __parameters[@(parameterID)];
	if (!paramData) {
		return NO;
	}
	
	paramData[kFxMetaProperty_ParamMeta][key] = value;
	
	return YES;
}


- (BOOL)removeMetaKey:(NSString*_Nullable)key fromParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *paramData = __parameters[@(parameterID)];
	if (!paramData) {
		return NO;
	}
	BOOL exists = paramData[kFxMetaProperty_ParamMeta][key] != nil;
	
	if (exists)
		[paramData[kFxMetaProperty_ParamMeta] removeObjectForKey:key];
	
	return exists;
}

#pragma mark -
#pragma mark Locking

- (BOOL)lock
{
	[mMetaLock lock];
	return YES;
}

- (BOOL)lockWithinTime:(double)tryTime
{
	if (tryTime <= 0) {
		return [mMetaLock tryLock];
	} else {
		NSDate *failTime = [NSDate dateWithTimeIntervalSinceNow:tryTime];
		return [mMetaLock lockBeforeDate:failTime];
	}
}

- (void)unlock
{
	[mMetaLock unlock];
}


- (NSOrderedSet<Class> *)classesForParameter {
	return nil;
}

@end
