//
//  FxGripTileableEffect+Notifications.h
//  FxGripTileableEffect+Notifications
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#ifndef FxGripTileableEffect_Notifications_h
#define FxGripTileableEffect_Notifications_h

#import <Foundation/Foundation.h>

//	FxGripTileableEffectLoadName is used in ncPriority to get extension priority for load
extern NSNotificationName	const _Nonnull FxGripTileableEffectLoadName;

//Notification post names
extern NSNotificationName	const _Nonnull FxGripTileableEffectInitAPIManagerKey;
extern NSNotificationName	const _Nonnull FxGripTileableEffectInitName;

extern NSNotificationName	const _Nonnull FxGripTileableEffectPropertiesKey;
extern NSNotificationName	const _Nonnull FxGripTileableEffectPropertiesName;

extern NSNotificationName	const _Nonnull FxGripTileableEffectParametersKey;
extern NSNotificationName	const _Nonnull FxGripTileableEffectAddParametersName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectFinishInitialSetupName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectAddedToDocumentName;

extern NSNotificationName	const _Nonnull FxGripTileableEffectParameterChangedName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectParameterChangedIDKey;		// NSNumber(FxParameterId) of the changed parameter
extern NSNotificationName	const _Nonnull FxGripTileableEffectParameterChangedAtTimeKey;	// CMTime-as-NSDictionary of the change time
extern NSNotificationName	const _Nonnull FxGripTileableEffectParameterClickedName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectParameterClickedIDKey;		// NSNumber(FxParameterId) of the clicked button
extern NSNotificationName	const _Nonnull FxGripTileableEffectFlushName;

/*! Posted by a parameter class before registration so observers apply host policy to the
	declared configuration (the default font of a font menu, a color's gamut conversion). The
	userInfo's parameter dictionary is mutable; the effect base observes and applies its policy. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectParameterPolicyName;

/*! Posted by a group parameter after opening its subgroup so the configuration's owner adds the
	group's children. The userInfo carries the group ID; an error returns through fxError. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectAddGroupParametersName;
extern NSString				* const _Nonnull FxGripTileableEffectGroupIDKey;

/*! Posted to resolve a host service: an observer that owns the meta manager or the parameter
	data answers by setting it under FxGripTileableEffectResolvedObjectKey in the mutable userInfo.
	The effect base answers through its members directly; the resolve path serves a plain host
	whose extensions supply the service. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectResolveMetaName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectResolveParameterDataName;
extern NSString				* const _Nonnull FxGripTileableEffectResolvedObjectKey;

extern NSNotificationName	const _Nonnull FxGripTileableEffectPluginStateCoderKey;
extern NSNotificationName	const _Nonnull FxGripTileableEffectPluginStateName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectDestinationImageRectName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectSourceTileRectName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectScheduleInputsName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectRenderDestinationImageName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectRenderDestinationImageKey;	// FxImageTile* destination
extern NSNotificationName	const _Nonnull FxGripTileableEffectRenderSourceImagesKey;		// NSArray<FxImageTile*>* sources
extern NSNotificationName	const _Nonnull FxGripTileableEffectRenderAtTimeKey;			// CMTime-as-NSDictionary of the render time

extern NSNotificationName	const _Nonnull FxGripTileableEffectRemovedFromDocumentName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectUnloadName;


@protocol FxGripAPIAccessing;

@interface NSDictionary (FxNotificationUserInfo)
// The FxGripAPIAccessing instance carried by FxGripTileableEffectInitName.
- (nullable id<FxGripAPIAccessing>)fxApiManager;
@property (readonly, nullable) NSMutableArray<NSMutableDictionary *> *fxEffectParameters;
@property (readonly, nullable) NSMutableDictionary<NSString *, id>* fxEffectProperties;
@property (readonly, nullable) NSCoder* fxCoder;

//- (id _Nullable)objectAtIndexedSubscript:(NSInteger)index;
@end


#endif
