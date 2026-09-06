/*!
	@file       FxGripCommonAPI.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCommonAPI
	@abstract   Implements the base API wrapper that caches the host meta manager and parameter data.
	@discussion Introduced in FxGrip 0.1.0. hostMeta and hostParameterData resolve their host object
	            on first access and cache the result, including a nil result, so a later access does
	            not re-run the resolve.
*/

#import "FxGripCommonAPI.h"
#import "FxGripEffectHost.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The base object for FxGrip's API capture layer.
	@discussion	Introduced in FxGrip 0.1.0. Retains the effect and caches the resolved host meta
				manager and parameter data.
*/
@implementation FxGripCommonAPI
{
	FxGripMetaManager *_hostMeta;
	FxGripParameterData *_hostParameterData;
	BOOL _resolvedMeta;
	BOOL _resolvedParameterData;
}

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
{
	self = [super init];
	
	if (self != nil)
	{
		_effect = effect;
	}
	return self;
}



- (void)dealloc
{
	NARC_RELEASE(_hostMeta);
	NARC_RELEASE(_hostParameterData);
	SUPER_DEALLOC();
}

/*! @abstract Resolves and caches the host's meta manager on first access. */
- (nullable FxGripMetaManager *)hostMeta
{
	if (!_resolvedMeta) {
		_resolvedMeta = YES;
		_hostMeta = NARC_RETAIN(FxGripHostMeta(self.effect));
	}
	return _hostMeta;
}

- (BOOL)hostHasMeta
{
	return self.hostMeta != nil;
}

/*! @abstract Resolves and caches the host's parameter data on first access. */
- (nullable FxGripParameterData *)hostParameterData
{
	if (!_resolvedParameterData) {
		_resolvedParameterData = YES;
		_hostParameterData = NARC_RETAIN(FxGripHostParameterData(self.effect));
	}
	return _hostParameterData;
}

@end
