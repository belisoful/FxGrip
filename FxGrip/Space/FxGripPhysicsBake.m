//
//  FxGripPhysicsBake.m
//  FxGrip
//

#import "FxGripPhysicsBake.h"
#import "FxGripSpaceEffect.h"
#import "FxGripSceneKitPhysicsBackend.h"
#import "FxGripPhysicsSimulationStore.h"
#import "FxGripTileableEffect+Extensions.h"
#import "FxGripTileableEffect+Notifications.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTypes.h"
#import "FxGripParameterFlags.h"
#import "FxGripAPIAccessing.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import "FxGrip_ARC.h"

@implementation FxGripPhysicsBake
{
	FxGripFrameData *_frameData;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_parameterID = kFxParameterId_PhysicsBake;
	}
	return self;
}

- (NSSet *)dataClasses
{
	NSMutableSet *classes = [super.dataClasses mutableCopy];
	[classes addObject:FxGripFrameData.class];
	[classes addObject:NSDictionary.class];
	[classes addObject:NSData.class];
	[classes addObject:NSString.class];
	[classes unionSet:FxGripFrameData.classesForParameter.set];
	return classes;
}

- (FxGripFrameData *)frameData
{
	if (_frameData == nil) {
		_frameData = [FxGripFrameData.alloc init];
		[_frameData attachProjectMediaCacheForEffect:self.effect];
	}
	return _frameData;
}

// The hidden parameter carries no presented state and stays out of presets.
- (void)extAddParameters:(nonnull NSNotification *)notification
{
	NSDictionary *parameter = @{
		kFxParameterProperty_Factory: self,
		kFxParameterProperty_Id: @(kFxParameterId_PhysicsBake),
		kFxParameterProperty_Name: @"Physics Bake",
		kFxParameterProperty_Type: kFxParameterType_Custom,
		kFxParameterProperty_Flags: @[kParameterFlagString_DONT_DISPLAY, kParameterFlagString_HIDDEN,
									  kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOVALUE,
									  kParameterFlagString_NO_DEBUG, kParameterFlagString_NO_STATE]
	};
	[notification.userInfo.fxEffectParameters addObject:[parameter mutableCopy]];
}

- (void)extAddedToDocument:(nonnull NSNotification *)notification
{
	NSObject<NSCopying, NSSecureCoding> *object = nil;
	[self.effect.apiManager.paramGetAPIv6 getCustomParameterValue:&object
													fromParameter:self.parameterID
														   atTime:kCMTimeZero];
	if ([object isKindOfClass:FxGripFrameData.class]) {
		_frameData = (FxGripFrameData *)object;
	} else if (_frameData == nil) {
		_frameData = [FxGripFrameData.alloc init];
	}
	[_frameData attachProjectMediaCacheForEffect:self.effect];

	[self installStoreOnPhysicsBackend];
}

- (void)installStoreOnPhysicsBackend
{
	if (![self.effect isKindOfClass:FxGripSpaceEffect.class]) {
		return;
	}
	FxGripSpaceEffect *effect = (FxGripSpaceEffect *)self.effect;
	if (![effect.spaceBackend isKindOfClass:FxGripSceneKitPhysicsBackend.class]) {
		return;
	}
	FxGripSceneKitPhysicsBackend *backend = (FxGripSceneKitPhysicsBackend *)effect.spaceBackend;
	backend.simulationStore = [[FxGripPhysicsFrameDataStore alloc] initWithFrameData:self.frameData];
	backend.simulationMode = FxGripPhysicsSimulationModeSessionCache;
}

@end


@implementation FxGripTileableEffect (PhysicsBake)

- (nullable FxGripFrameData *)physicsBakeData
{
	FxGripPhysicsBake *bake = (FxGripPhysicsBake *)[self extensionForClass:FxGripPhysicsBake.class];
	return bake.frameData;
}

- (BOOL)hasPhysicsBake
{
	return [self extensionForClass:FxGripPhysicsBake.class] != nil;
}

- (nonnull FxGripPhysicsBake *)newPhysicsBakeExtension
{
	return [FxGripPhysicsBake.alloc init];
}

@end
