/*!
	@file       FxGripPhysicsBake.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPhysicsBake
	@abstract   Implements the physics-bake extension and its effect-side accessors.
	@discussion Introduced in FxGrip 0.1.0. The extension registers the hidden Physics Bake custom
	            parameter, loads its FxGripFrameData when the effect is added to a document, and
	            installs an FxGripFrameData-backed store on the effect's physics backend in session-cache
	            mode. Firebase is not involved; the bake stays inline in the parameter.
*/

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

/*!
	@abstract	The extension that persists per-frame body transforms with the document.
	@discussion	Introduced in FxGrip 0.1.0. The extension owns an FxGripFrameData, adds the hidden bake
				parameter, and wires the frame data into the physics backend's simulation store.
*/
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

/*! @abstract The secure-coding classes the custom parameter decodes, adding FxGripFrameData and its record types. */
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

/*! @abstract The bake store, created on first access and attached to the effect's project media cache. */
- (FxGripFrameData *)frameData
{
	if (_frameData == nil) {
		_frameData = [FxGripFrameData.alloc init];
		[_frameData attachProjectMediaCacheForEffect:self.effect];
	}
	return _frameData;
}

/*!
	@method		extAddParameters:
	@abstract	Registers the hidden Physics Bake custom parameter.
	@discussion	Introduced in FxGrip 0.1.0. */
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

/*!
	@method		extAddedToDocument:
	@abstract	Loads the bake from the document and installs the store on the physics backend.
	@discussion	Introduced in FxGrip 0.1.0. Reads the custom parameter value at time zero, adopts it as the
				frame data when it is an FxGripFrameData, and attaches the project media cache before
				wiring the store into the backend. */
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

/*!
	@method		installStoreOnPhysicsBackend
	@abstract	Backs the effect's physics backend with an FxGripFrameData store in session-cache mode.
	@discussion	Introduced in FxGrip 0.1.0. The install is a no-op unless the effect is an FxGripSpaceEffect
				whose space backend is an FxGripSceneKitPhysicsBackend. */
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


/*!
	@abstract	The effect-side accessors that read and create the physics-bake extension.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@implementation FxGripTileableEffect (PhysicsBake)

/*! @abstract The frame data of the loaded FxGripPhysicsBake extension, or nil when it is not loaded. */
- (nullable FxGripFrameData *)physicsBakeData
{
	FxGripPhysicsBake *bake = (FxGripPhysicsBake *)[self extensionForClass:FxGripPhysicsBake.class];
	return bake.frameData;
}

/*! @abstract YES when the FxGripPhysicsBake extension is loaded. */
- (BOOL)hasPhysicsBake
{
	return [self extensionForClass:FxGripPhysicsBake.class] != nil;
}

/*! @abstract Creates the physics-bake extension instance for the loader to install. */
- (nonnull FxGripPhysicsBake *)newPhysicsBakeExtension
{
	return [FxGripPhysicsBake.alloc init];
}

@end
