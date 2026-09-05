//
//  FxGripAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripAPIAccessing.h"
#import "FxGripCustomCreationAPI_v1.h"
#import "FxGripTileableEffect.h"
#import "FxGripDynamicParameterAPI_v3.h"
#import "FxGripParameterInfoAPI_v1.h"
#import "FxGripParameterBoundsAPI_v1.h"
#import "FxGripMetaAPI_v1.h"
#import "FxGripParameterCreationAPI_v5.h"
#import "FxGripParameterCreationAPI_v6.h"
#import "FxGripParameterRetrievalAPI_v6.h"
#import "FxGripParameterRetrievalAPI_v7.h"
#import "FxGripParameterSettingAPI_v5.h"
#import "FxGripParameterSettingAPI_v6.h"
#import "FxGripTimingAPI_v4.h"
#import "FxGripParameterTagsAPI_v1.h"
#import "FxGripParameterTagsAPI_v1.h"
#import "FxGripPresetsAPI_v1.h"
#import <BEFoundation/NSNumber+BExtension.h>

#import "FxGrip_ARC.h"

/*
//	#pragma unused(variable)
@implementation FxGripAPITransaction

- (nullable instancetype)init
{
	self = [super init];
	
	if (self != nil)
	{
		if (!_uuid)
			_uuid = [NSUUID UUID];
		_active = NO;
	}
	return self;
}

- (nullable instancetype)initWithAPIManager:(FxGripAPIAccessing*_Nonnull)apiManager
{
	self = [self init];
	
	if (self != nil)
	{
		_apiManager = apiManager;
		_active = YES;
	}
	return self;
}

- (nullable instancetype)initWithTransaction:(FxGripAPITransaction*_Nonnull)transaction
{
	_uuid = transaction.uuid;
	self = [self initWithAPIManager:transaction.apiManager];
	
	if (self != nil)
	{
	}
	return self;
}
- (void)dealloc
{
	if (_active)
		[self commit];
	
	[super dealloc];
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone { 
	return [FxGripAPITransaction.alloc initWithTransaction:self];
}

- (void)commit
{
	[self commit:YES];
}

- (void)commit:(BOOL)saveMeta
{
	if(saveMeta && _apiManager.effect && _apiManager.effect.hasMeta) {
		//save any changes made to the meta
		[_apiManager.effect.meta saveMeta];
	}
	[_apiManager endTransaction:self];
	_active = NO;
}

@end

*/


#pragma mark -
#pragma mark FxGripAPIAccessing

	#import <objc/runtime.h>

@protocol __FxPROAPIAccessing <PROAPIAccessing>
@property (assign, readonly) NSString* _Nullable pluginUUID;
@property (assign, readonly) unsigned long long sessionID;

@optional
@property (assign, readonly) unsigned int pluginVersion;
@end

@implementation FxGripAPIAccessing
{
	//FxGripParameterRetrievalAPI_v6 *mParamGetAPI_v6;
	
	
//#define kFxGripMaxLockerCount 88
	//NSMutableDictionary<id, NSNumber*>*	lockCounter;
	//NSMutableDictionary<FxGripAPITransaction*, id>*	locker;
}
@dynamic pluginVersion;


//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
									 effect:(id<FxGripEffectHost>)effect
{
	id<__FxPROAPIAccessing> manager = (id<__FxPROAPIAccessing>)apiManager;
	self = [super init];
	
	if (self != nil)
	{
		unsigned int methodCount = 0;
		Method *methods = class_copyMethodList([apiManager class], &methodCount);
		for(int i = 0; i < methodCount; i++) {
			NSLog(@"%s\n", sel_getName(method_getName(methods[i])));
		}
		free(methods);
		if ([apiManager respondsToSelector:@selector(pluginUUID)]) {
			_pluginUUID = manager.pluginUUID;
		}
		if ([apiManager respondsToSelector:@selector(sessionID)]) {
			_sessionID = manager.sessionID;
		}
		
//		lockCounter = [NSMutableDictionary dictionary];
//		locker = [NSMutableDictionary dictionary];
//		
//		[lockCounter retain];
//		[locker retain];
		
		_apiAccessing = (id)apiManager;
		_effect = effect;
	}
	return self;
}

- (void)dealloc
{
	_pluginUUID = nil;
	_apiAccessing = nil;
	_effect = nil;
//	[lockCounter dealloc];
//	lockCounter = nil;
//	[locker dealloc];
//	locker = nil;
	
	SUPER_DEALLOC();
}


#pragma mark -
#pragma mark API Session Transaction

/*

- (FxGripAPITransaction*)transaction:(id)key
{
	@synchronized (lockCounter) {
		if (!lockCounter[key]) {
			lockCounter[key] = @1;
		} else {
			if ([lockCounter[key] isGreaterThanOrEqualTo:@kFxGripMaxLockerCount])
				return nil;
			lockCounter[key] = [lockCounter[key] plusOne];
		}
		FxGripAPITransaction *tx = [FxGripAPITransaction.alloc initWithAPIManager:self];
		locker[tx] = key;
		return tx;
	}
}

- (BOOL)hasTransaction
{
	@synchronized (lockCounter) {
		return locker.count > 0;
	}
}


- (BOOL)endTransaction:(FxGripAPITransaction*)transaction
{
	@synchronized (lockCounter) {
		if (locker[transaction]) {
			id key = locker[transaction];
			[locker removeObjectForKey:transaction];
			lockCounter[key] = [lockCounter[key] minusOne];
			if (lockCounter[key].isZero)
				[lockCounter removeObjectForKey:key];
			if (!locker.count)
				[self clearProtocols];
			return YES;
		}
	}
	return NO;
}

- (void)clearProtocols
{
	if (mParamGetAPI_v6) {
		[mParamGetAPI_v6 release];
		mParamGetAPI_v6 = nil;
	}
}
*/

#pragma mark -
#pragma mark FxGrip ProPlug API Layer

- (id)apiForProtocol:(Protocol *)apiProtocol
{
	return [self apiForProtocol:apiProtocol bypass:NO];
}

- (id)apiForProtocol:(Protocol *)apiProtocol bypass:(BOOL)bypassFxGripLayer
{
	id api = [_apiAccessing apiForProtocol:apiProtocol];
	
	if (bypassFxGripLayer) {
		return api;
	}
	
	if (api && [FxGripDynamicParameterAPI_v3 conformsToProtocol:apiProtocol]) {
		id dyParam_v3 = NARC_AUTORELEASE([FxGripDynamicParameterAPI_v3.alloc initWithAPI:api effect:self.effect]);
		if (dyParam_v3 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripDynamicParameterAPI_v3", _sessionID);
		}
		return dyParam_v3;
	}
	
	
	// FxGrip's own parameter-info queries; wraps Apple's dynamic v3 for the roster walk.
	if ([FxGripParameterInfoAPI_v1 conformsToProtocol:apiProtocol]) {
		id paramInfo_v1 = NARC_AUTORELEASE([FxGripParameterInfoAPI_v1.alloc initWithAPI:self.dynamicParamAPIv3_Raw effect:self.effect]);
		if (paramInfo_v1 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterInfoAPI_v1", _sessionID);
		}
		return paramInfo_v1;
	}

	// FxGrip's own parameter-bounds setters; wraps Apple's dynamic v3.
	if ([FxGripParameterBoundsAPI_v1 conformsToProtocol:apiProtocol]) {
		id paramBounds_v1 = NARC_AUTORELEASE([FxGripParameterBoundsAPI_v1.alloc initWithAPI:self.dynamicParamAPIv3_Raw effect:self.effect]);
		if (paramBounds_v1 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterBoundsAPI_v1", _sessionID);
		}
		return paramBounds_v1;
	}

	// FxGrip's own per-parameter metadata API; resolves through the host meta manager.
	if ([FxGripMetaAPI_v1 conformsToProtocol:apiProtocol]) {
		id meta_v1 = NARC_AUTORELEASE([FxGripMetaAPI_v1.alloc initWithEffect:self.effect]);
		if (meta_v1 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripMetaAPI_v1", _sessionID);
		}
		return meta_v1;
	}
	
	
	if (api && [FxGripParameterCreationAPI_v5 conformsToProtocol:apiProtocol]) {
		id paramCreateAPI_v5 = NARC_AUTORELEASE([FxGripParameterCreationAPI_v5.alloc initWithAPI:api effect:self.effect]);
		if (paramCreateAPI_v5 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterCreationAPI_v5", _sessionID);
		}
		return paramCreateAPI_v5;
	}

	// After the v5 branch: the v5 wrapper does not conform to v6, so a v5 request never reaches
	// here, and a v6 request skips the v5 branch to land on this one.
	if (api && [FxGripParameterCreationAPI_v6 conformsToProtocol:apiProtocol]) {
		id paramCreateAPI_v6 = NARC_AUTORELEASE([FxGripParameterCreationAPI_v6.alloc initWithAPI:api effect:self.effect]);
		if (paramCreateAPI_v6 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterCreationAPI_v6", _sessionID);
		}
		return paramCreateAPI_v6;
	}

	if (api && [FxGripParameterRetrievalAPI_v6 conformsToProtocol:apiProtocol]) {
		
		id paramGetAPI_v6 = nil;
		//if (self.hasTransaction)
		//	paramGetAPI_v6 = mParamGetAPI_v6;
		if (!paramGetAPI_v6) {
			id paramInfo_v1 = NARC_AUTORELEASE([FxGripParameterInfoAPI_v1.alloc initWithAPI:self.dynamicParamAPIv3_Raw effect:self.effect]);
			if (paramInfo_v1 == nil)
			{
				NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterInfoAPI_v1", _sessionID);
			}
			
			paramGetAPI_v6 = NARC_AUTORELEASE([FxGripParameterRetrievalAPI_v6.alloc initWithAPI:api parameterInfoAPIv1:paramInfo_v1 effect:self.effect]);
			if (paramGetAPI_v6 == nil)
			{
				NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterRetrievalAPI_v6", _sessionID);
			}
			//if (self.hasTransaction) {
			//	mParamGetAPI_v6 = paramGetAPI_v6;
			//	[mParamGetAPI_v6 retain];
			//}
		}
		return paramGetAPI_v6;
	}

	// After the v6 branch: the v6 wrapper does not conform to v7, so a v6 request never reaches
	// here, and a v7 request skips the v6 branch to land on this one.
	if (api && [FxGripParameterRetrievalAPI_v7 conformsToProtocol:apiProtocol]) {
		id paramInfo_v1 = NARC_AUTORELEASE([FxGripParameterInfoAPI_v1.alloc initWithAPI:self.dynamicParamAPIv3_Raw effect:self.effect]);
		id paramGetAPI_v7 = NARC_AUTORELEASE([FxGripParameterRetrievalAPI_v7.alloc initWithAPI:api parameterInfoAPIv1:paramInfo_v1 effect:self.effect]);
		if (paramGetAPI_v7 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterRetrievalAPI_v7", _sessionID);
		}
		return paramGetAPI_v7;
	}

	if (api && [FxGripParameterSettingAPI_v5 conformsToProtocol:apiProtocol]) {
		id<FxParameterRetrievalAPI_v6> paramGetAPIv6 = [_apiAccessing apiForProtocol:@protocol(FxParameterRetrievalAPI_v6)];
		if (paramGetAPIv6 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxParameterRetrievalAPI_v6", _sessionID);
		}
		id<FxGripParameterInfoAPI_v1> paramInfo_v1 = NARC_AUTORELEASE([FxGripParameterInfoAPI_v1.alloc initWithAPI:self.dynamicParamAPIv3_Raw effect:self.effect]);
		if (paramInfo_v1 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterInfoAPI_v1", _sessionID);
		}
		
		id paramSetAPI_v5 = NARC_AUTORELEASE([FxGripParameterSettingAPI_v5.alloc initWithAPI:api paramGetAPIv6:paramGetAPIv6 parameterInfoAPIv1:paramInfo_v1 effect:self.effect]);
		if (paramSetAPI_v5 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterSettingAPI_v5", _sessionID);
		}
		return paramSetAPI_v5;
	}
	
	if (api && [FxGripParameterSettingAPI_v6 conformsToProtocol:apiProtocol]) {
		
		id<FxParameterRetrievalAPI_v6> paramGetAPIv6 = [_apiAccessing apiForProtocol:@protocol(FxParameterRetrievalAPI_v6)];
		if (paramGetAPIv6 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxParameterRetrievalAPI_v6", _sessionID);
		}
		id<FxGripParameterInfoAPI_v1> paramInfo_v1 = NARC_AUTORELEASE([FxGripParameterInfoAPI_v1.alloc initWithAPI:self.dynamicParamAPIv3_Raw effect:self.effect]);
		if (paramInfo_v1 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterInfoAPI_v1", _sessionID);
		}
		
		id paramSetAPI_v6 = NARC_AUTORELEASE([FxGripParameterSettingAPI_v6.alloc initWithAPI:api paramGetAPIv6:paramGetAPIv6 parameterInfoAPIv1:paramInfo_v1 effect:self.effect]);
		if (paramSetAPI_v6 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterSettingAPI_v6", _sessionID);
		}
		return paramSetAPI_v6;
	}
	
	// FxGrip implements this protocol itself; no host vends it, so the wrapper is built
	// without a host API. Gating it on `api` would leave it permanently unreachable.
	if ([FxGripParameterTagsAPI_v1 conformsToProtocol:apiProtocol]) {
		id paramTags_v1 = NARC_AUTORELEASE([FxGripParameterTagsAPI_v1.alloc initWithAPI:api effect:self.effect]);
		if (paramTags_v1 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripParameterTagsAPI_v1", _sessionID);
		}
		return paramTags_v1;
	}
	// FxGrip-implemented, like the tags API above.
	if ([FxGripPresetsAPI_v1 conformsToProtocol:apiProtocol]) {
		id presets_v1 = NARC_AUTORELEASE([FxGripPresetsAPI_v1.alloc initWithAPI:api effect:self.effect]);
		if (presets_v1 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripPresetsAPI_v1", _sessionID);
		}
		return presets_v1;
	}
	if (api && [FxGripTimingAPI_v4 conformsToProtocol:apiProtocol]) {
		id timing_v4 = NARC_AUTORELEASE([FxGripTimingAPI_v4.alloc initWithAPI:api effect:self.effect]);
		if (timing_v4 == nil)
		{
			NSLog(@"FxGripAPIManager(%llu)::apiProtocol Unable to load FxGripTimingAPI_v4", _sessionID);
		}
		return timing_v4;
	}
	
	return api;
}



#pragma mark -
#pragma mark User Interface Parameter APIs


- (id<FxParameterCreationAPI_v5> _Nullable)paramCreateAPIv5_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxParameterCreationAPI_v5)];
}

- (id<FxParameterCreationAPI_v5> _Nullable)paramCreateAPIv5
{
	id<FxParameterCreationAPI_v5> paramAPI = [self apiForProtocol:@protocol(FxParameterCreationAPI_v5)];
	if (paramAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::paramCreateAPIv5 Unable to load FxParameterCreationAPI_v5", _sessionID);
	}
	return paramAPI;
}

- (id<FxParameterCreationAPI_v6> _Nullable)paramCreateAPIv6_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxParameterCreationAPI_v6)];
}

- (id<FxParameterCreationAPI_v6> _Nullable)paramCreateAPIv6
{
	id<FxParameterCreationAPI_v6> paramAPI = [self apiForProtocol:@protocol(FxParameterCreationAPI_v6)];
	if (paramAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::paramCreateAPIv6 Unable to load FxParameterCreationAPI_v6", _sessionID);
	}
	return paramAPI;
}


- (id<FxGripParameterTagsAPI_v1> _Nullable)paramTagsAPIv1
{
	// FxGrip-implemented: always available, independent of the host's API set.
	id<FxGripParameterTagsAPI_v1> tagsAPI = [self apiForProtocol:@protocol(FxGripParameterTagsAPI_v1)];
	if (tagsAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::paramTagsAPIv1 Unable to load FxGripParameterTagsAPI_v1", _sessionID);
	}
	return tagsAPI;
}

- (id<FxGripPresetsAPI_v1> _Nullable)presetsAPIv1
{
	// FxGrip-implemented: always available, independent of the host's API set.
	id<FxGripPresetsAPI_v1> presetsAPI = [self apiForProtocol:@protocol(FxGripPresetsAPI_v1)];
	if (presetsAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::presetsAPIv1 Unable to load FxGripPresetsAPI_v1", _sessionID);
	}
	return presetsAPI;
}

- (id<FxGripCustomCreationAPI_v1> _Nullable)customCreationAPIv1
{
	// FxGrip-implemented over the effect host; no host protocol backs it.
	FxGripCustomCreationAPI_v1 *api =
		[[FxGripCustomCreationAPI_v1 alloc] initWithEffect:(id<FxGripEffectHost>)self.effect];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::customCreationAPIv1 requires an effect host", _sessionID);
	}
	return NARC_AUTORELEASE(api);
}

- (id<FxParameterRetrievalAPI_v6> _Nullable)paramGetAPIv6_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxParameterRetrievalAPI_v6)];
}

- (id<FxParameterRetrievalAPI_v6> _Nullable)paramGetAPIv6
{
	id<FxParameterRetrievalAPI_v6> paramAPI = [self apiForProtocol:@protocol(FxParameterRetrievalAPI_v6)];
	if (paramAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::paramGetAPIv6 Unable to load FxParameterRetrievalAPI_v6", _sessionID);
	}
	return paramAPI;
}


- (id<FxParameterRetrievalAPI_v7> _Nullable)paramGetAPIv7_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxParameterRetrievalAPI_v7)];
}

- (id<FxParameterRetrievalAPI_v7> _Nullable)paramGetAPIv7
{
	id<FxParameterRetrievalAPI_v7> paramAPI = [self apiForProtocol:@protocol(FxParameterRetrievalAPI_v7)];
	if (paramAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::paramGetAPIv7 Unable to load FxParameterRetrievalAPI_v7", _sessionID);
	}
	return paramAPI;
}


- (id<FxParameterSettingAPI_v5> _Nullable)paramSetAPIv5_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxParameterSettingAPI_v5)];
}

- (id<FxParameterSettingAPI_v5> _Nullable)paramSetAPIv5
{
	id<FxParameterSettingAPI_v5> paramAPI = [self apiForProtocol:@protocol(FxParameterSettingAPI_v5)];
	if (paramAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::paramSetAPIv5 Unable to load FxParameterSettingAPI_v5", _sessionID);
	}
	return paramAPI;
}


- (id<FxParameterSettingAPI_v6> _Nullable)paramSetAPIv6_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxParameterSettingAPI_v6)];
}

- (id<FxParameterSettingAPI_v5> _Nullable)paramSetAPIv6
{
	id<FxParameterSettingAPI_v6> paramAPI = [self apiForProtocol:@protocol(FxParameterSettingAPI_v6)];
	if (paramAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::paramSetAPIv6 Unable to load FxParameterSettingAPI_v6", _sessionID);
	}
	return paramAPI;
}


- (id<FxDynamicParameterAPI_v3> _Nullable)dynamicParamAPIv3_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxDynamicParameterAPI_v3)];
}

- (id<FxDynamicParameterAPI_v3> _Nullable)dynamicParamAPIv3
{
	id<FxDynamicParameterAPI_v3> paramAPI = [self apiForProtocol:@protocol(FxDynamicParameterAPI_v3)];
	if (paramAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::dynamicParamAPIv3 Unable to load FxDynamicParameterAPI_v3", _sessionID);
	}
	return paramAPI;
}


- (id<FxGripParameterInfoAPI_v1> _Nullable)parameterInfoAPIv1
{
	// FxGrip-implemented: always available, independent of the host's API set.
	id<FxGripParameterInfoAPI_v1> infoAPI = [self apiForProtocol:@protocol(FxGripParameterInfoAPI_v1)];
	if (infoAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::parameterInfoAPIv1 Unable to load FxGripParameterInfoAPI_v1", _sessionID);
	}
	return infoAPI;
}

- (id<FxGripParameterBoundsAPI_v1> _Nullable)parameterBoundsAPIv1
{
	// FxGrip-implemented: always available, independent of the host's API set.
	id<FxGripParameterBoundsAPI_v1> boundsAPI = [self apiForProtocol:@protocol(FxGripParameterBoundsAPI_v1)];
	if (boundsAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::parameterBoundsAPIv1 Unable to load FxGripParameterBoundsAPI_v1", _sessionID);
	}
	return boundsAPI;
}

- (id<FxGripMetaAPI_v1> _Nullable)metaAPIv1
{
	// FxGrip-implemented: always available, independent of the host's API set.
	id<FxGripMetaAPI_v1> metaAPI = [self apiForProtocol:@protocol(FxGripMetaAPI_v1)];
	if (metaAPI == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::metaAPIv1 Unable to load FxGripMetaAPI_v1", _sessionID);
	}
	return metaAPI;
}


#pragma mark -
#pragma mark User Interface Custom Parameter API

- (id<FxCustomParameterActionAPI_v4> _Nullable)customParameterActionAPIv4_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxCustomParameterActionAPI_v4)];
}

- (id<FxCustomParameterActionAPI_v4> _Nullable)customParameterActionAPIv4
{
	id<FxCustomParameterActionAPI_v4> api = [self apiForProtocol:@protocol(FxCustomParameterActionAPI_v4)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::customParameterActionAPIv4 Unable to load FxCustomParameterActionAPI_v4", _sessionID);
	}
	return api;
}


#pragma mark -
#pragma mark User Interface On Screen Control APIs

- (id<FxOnScreenControlAPI> _Nullable)onScreenControlAPIv1_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxOnScreenControlAPI)];
}

- (id<FxOnScreenControlAPI> _Nullable)onScreenControlAPIv1
{
	id<FxOnScreenControlAPI> api = [self apiForProtocol:@protocol(FxOnScreenControlAPI)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::onScreenControlAPIv1 Unable to load FxOnScreenControlAPI", _sessionID);
	}
	return api;
}

- (id<FxOnScreenControlAPI_v2> _Nullable)onScreenControlAPIv2_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxOnScreenControlAPI_v2)];
}

- (id<FxOnScreenControlAPI_v2> _Nullable)onScreenControlAPIv2
{
	id<FxOnScreenControlAPI_v2> api = [self apiForProtocol:@protocol(FxOnScreenControlAPI_v2)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::onScreenControlAPIv2 Unable to load FxOnScreenControlAPI_v2", _sessionID);
	}
	return api;
}

- (id<FxOnScreenControlAPI_v3> _Nullable)onScreenControlAPIv3_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxOnScreenControlAPI_v3)];
}

- (id<FxOnScreenControlAPI_v3> _Nullable)onScreenControlAPIv3
{
	id<FxOnScreenControlAPI_v3> api = [self apiForProtocol:@protocol(FxOnScreenControlAPI_v3)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::onScreenControlAPIv3 Unable to load FxOnScreenControlAPI_v3", _sessionID);
	}
	return api;
}

- (id<FxOnScreenControlAPI_v4> _Nullable)onScreenControlAPIv4_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxOnScreenControlAPI_v4)];
}

- (id<FxOnScreenControlAPI_v4> _Nullable)onScreenControlAPIv4
{
	id<FxOnScreenControlAPI_v4> api = [self apiForProtocol:@protocol(FxOnScreenControlAPI_v4)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::onScreenControlAPIv4 Unable to load FxOnScreenControlAPI_v4", _sessionID);
	}
	return api;
}


#pragma mark -
#pragma mark User Interface APIs

- (id<FxPathAPI_v3> _Nullable)pathAPIv3_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxPathAPI_v3)];
}

- (id<FxPathAPI_v3> _Nullable)pathAPIv3
{
	id<FxPathAPI_v3> api = [self apiForProtocol:@protocol(FxPathAPI_v3)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::pathAPIv3 Unable to load FxPathAPI_v3", _sessionID);
	}
	return api;
}

- (id<FxUndoAPI> _Nullable)undoAPIv1_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxUndoAPI)];
}

- (id<FxUndoAPI> _Nullable)undoAPIv1
{
	id<FxUndoAPI> api = [self apiForProtocol:@protocol(FxUndoAPI)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::undoAPIv1 Unable to load FxUndoAPI", _sessionID);
	}
	return api;
}

- (id<FxCommandAPI> _Nullable)commandAPIv1_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxCommandAPI)];
}

- (id<FxCommandAPI> _Nullable)commandAPIv1
{
	id<FxCommandAPI> api = [self apiForProtocol:@protocol(FxCommandAPI)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::commandAPIv1 Unable to load FxCommandAPI", _sessionID);
	}
	return api;
}

- (id<FxCommandAPI_v2> _Nullable)commandAPIv2_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxCommandAPI_v2)];
}

- (id<FxCommandAPI_v2> _Nullable)commandAPIv2
{
	id<FxCommandAPI_v2> api = [self apiForProtocol:@protocol(FxCommandAPI_v2)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::commandAPIv2 Unable to load FxCommandAPI_v2", _sessionID);
	}
	return api;
}

- (id<FxRemoteWindowAPI> _Nullable)remoteWindowAPIv1_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxRemoteWindowAPI)];
}

- (id<FxRemoteWindowAPI> _Nullable)remoteWindowAPIv1
{
	id<FxRemoteWindowAPI> api = [self apiForProtocol:@protocol(FxRemoteWindowAPI)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::remoteWindowAPIv1 Unable to load FxRemoteWindowAPI", _sessionID);
	}
	return api;
}

- (id<FxRemoteWindowAPI_v2> _Nullable)remoteWindowAPIv2_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxRemoteWindowAPI_v2)];
}

- (id<FxRemoteWindowAPI_v2> _Nullable)remoteWindowAPIv2
{
	id<FxRemoteWindowAPI_v2> api = [self apiForProtocol:@protocol(FxRemoteWindowAPI_v2)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::remoteWindowAPIv2 Unable to load FxRemoteWindowAPI_v2", _sessionID);
	}
	return api;
}

- (id<FxRemoteWindowAPI_v3> _Nullable)remoteWindowAPIv3_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxRemoteWindowAPI_v3)];
}

- (id<FxRemoteWindowAPI_v3> _Nullable)remoteWindowAPIv3
{
	id<FxRemoteWindowAPI_v3> api = [self apiForProtocol:@protocol(FxRemoteWindowAPI_v3)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::remoteWindowAPIv3 Unable to load FxRemoteWindowAPI_v3", _sessionID);
	}
	return api;
}


#pragma mark -
#pragma mark 3D and Lighting APIs

- (id<Fx3DAPI_v5> _Nullable)spaceAPIv5_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(Fx3DAPI_v5)];
}

- (id<Fx3DAPI_v5> _Nullable)spaceAPIv5
{
	id<Fx3DAPI_v5> api = [self apiForProtocol:@protocol(Fx3DAPI_v5)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::cameraAPIv5 Unable to load Fx3DAPI_v5", _sessionID);
	}
	return api;
}

- (id<FxLightingAPI_v3> _Nullable)lightingAPIv3_Raws
{
	return [_apiAccessing apiForProtocol:@protocol(FxLightingAPI_v3)];
}

- (id<FxLightingAPI_v3> _Nullable)lightingAPIv3
{
	id<FxLightingAPI_v3> api = [self apiForProtocol:@protocol(FxLightingAPI_v3)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::lightingAPIv3 Unable to load FxLightingAPI_v3", _sessionID);
	}
	return api;
}


#pragma mark -
#pragma mark Color API

- (id<FxColorGamutAPI_v2> _Nullable)colorGamutAPIv2_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxColorGamutAPI_v2)];
}

- (id<FxColorGamutAPI_v2> _Nullable)colorGamutAPIv2
{
	id<FxColorGamutAPI_v2> api = [self apiForProtocol:@protocol(FxColorGamutAPI_v2)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::colorGamutAPIv2 Unable to load FxColorGamutAPI_v2", _sessionID);
	}
	return api;
}

#pragma mark -
#pragma mark Timing and Analysis APIs

- (id<FxTimingAPI_v4> _Nullable)timingAPIv4_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxTimingAPI_v4)];
}

- (id<FxTimingAPI_v4> _Nullable)timingAPIv4
{
	id<FxTimingAPI_v4> api = [self apiForProtocol:@protocol(FxTimingAPI_v4)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::timingAPIv4 Unable to load FxTimingAPI_v4", _sessionID);
	}
	return api;
}

- (id<FxTimingAPI_v5> _Nullable)timingAPIv5_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxTimingAPI_v5)];
}

- (id<FxTimingAPI_v5> _Nullable)timingAPIv5
{
	// No FxGrip wrapper: the host object is vended directly. Silent on nil, since hosts older
	// than FxPlug 4.3.5 vend no v5 and callers fall back to v4.
	return [self apiForProtocol:@protocol(FxTimingAPI_v5)];
}

- (id<FxKeyframeAPI_v3> _Nullable)keyframeAPIv3_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxKeyframeAPI_v3)];
}

- (id<FxKeyframeAPI_v3> _Nullable)keyframeAPIv3
{
	id<FxKeyframeAPI_v3> api = [self apiForProtocol:@protocol(FxKeyframeAPI_v3)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::keyframeAPIv3 Unable to load FxKeyframeAPI_v3", _sessionID);
	}
	return api;
}

- (id<FxAnalysisAPI> _Nullable)analysisAPIv1_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxAnalysisAPI)];
}

- (id<FxAnalysisAPI> _Nullable)analysisAPIv1
{
	id<FxAnalysisAPI> api = [self apiForProtocol:@protocol(FxAnalysisAPI)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::analysisAPIv1 Unable to load FxAnalysisAPI", _sessionID);
	}
	return api;
}

- (id<FxAnalysisAPI_v2> _Nullable)analysisAPIv2_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxAnalysisAPI_v2)];
}

- (id<FxAnalysisAPI_v2> _Nullable)analysisAPIv2
{
	id<FxAnalysisAPI_v2> api = [self apiForProtocol:@protocol(FxAnalysisAPI_v2)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::analysisAPIv2 Unable to load FxProjectAPI", _sessionID);
	}
	return api;
}

// plugin implements FxAnalyzer protocol

#pragma mark -
#pragma mark Project APIs

- (id<FxProjectAPI> _Nullable)projectAPIv1_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxProjectAPI)];
}

- (id<FxProjectAPI> _Nullable)projectAPIv1
{
	id<FxProjectAPI> api = [self apiForProtocol:@protocol(FxProjectAPI)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::projectAPIv1 Unable to load FxProjectAPI", _sessionID);
	}
	return api;
}

- (id<FxProjectAPI_v2> _Nullable)projectAPIv2_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxProjectAPI_v2)];
}

- (id<FxProjectAPI_v2> _Nullable)projectAPIv2
{
	id<FxProjectAPI_v2> api = [self apiForProtocol:@protocol(FxProjectAPI_v2)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::projectAPIv2 Unable to load FxProjectAPI_v2", _sessionID);
	}
	return api;
}


#pragma mark -
#pragma mark Versioning API

- (id<FxVersioningAPI> _Nullable)versioningAPIv1_Raw
{
	return [_apiAccessing apiForProtocol:@protocol(FxVersioningAPI)];
}

- (id<FxVersioningAPI> _Nullable)versioningAPIv1
{
	id<FxVersioningAPI> api = [self apiForProtocol:@protocol(FxVersioningAPI)];
	if (api == nil)
	{
		NSLog(@"FxGripAPIManager(%llu)::versioningAPIv1 Unable to load FxVersioningAPI", _sessionID);
	}
	return api;
}

@end
