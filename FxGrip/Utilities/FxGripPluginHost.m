//
//  FxGripPluginHost.m
//  FxGrip
//

#import "FxGripPluginHost.h"
#import "FxGripAPIAccessing.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGrip_ARC.h"

@implementation FxGripPluginHost
{
	FxGripAPIAccessing *_apiManager;
}

- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	self = [super init];
	if (self != nil) {
		// The host stands in for an effect the wrapper never has; the OSC base binds the same way.
		_apiManager = [[FxGripAPIAccessing alloc] initWithAPIManager:apiManager effect:(id _Nonnull)self];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_apiManager);
	SUPER_DEALLOC();
}

- (id<FxGripAPIAccessing>)apiManager
{
	return _apiManager;
}

- (NSPriorityNotificationCenter *)notifier
{
	return [NSPriorityNotificationCenter defaultCenter];
}

- (nullable FxTileableEffectBase *)effectBase
{
	return nil;
}

@end
