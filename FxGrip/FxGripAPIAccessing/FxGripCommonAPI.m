//
//  MasterFXAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//


#import "FxGripCommonAPI.h"

@implementation FxGripCommonAPI

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithEffect:(nonnull id<FxTileableEffectBase>)effect
{
	self = [super init];
	
	if (self != nil)
	{
		_effect = effect;
	}
	return self;
}



@end
