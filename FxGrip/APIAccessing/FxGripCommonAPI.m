//
//  MasterFXAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//


#import "FxGripCommonAPI.h"
#import "FxGripEffectHost.h"
#import "FxGrip_ARC.h"

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

- (nullable FxGripParameterData *)hostParameterData
{
	if (!_resolvedParameterData) {
		_resolvedParameterData = YES;
		_hostParameterData = NARC_RETAIN(FxGripHostParameterData(self.effect));
	}
	return _hostParameterData;
}

@end
