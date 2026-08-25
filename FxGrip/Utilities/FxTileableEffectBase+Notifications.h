//
//  FxTileableEffectBase+Notifications.h
//  FxTileableEffectBase+Notifications
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#ifndef FxTileableEffectBase_Notifications_h
#define FxTileableEffectBase_Notifications_h

#import <Foundation/Foundation.h>

//	FxTileableEffectLoadName is used in ncPriority to get extension priority for load
extern NSNotificationName	const _Nonnull FxTileableEffectLoadName;

//Notification post names
extern NSNotificationName	const _Nonnull FxTileableEffectInitAPIManagerKey;
extern NSNotificationName	const _Nonnull FxTileableEffectInitName;

extern NSNotificationName	const _Nonnull FxTileableEffectPropertiesKey;
extern NSNotificationName	const _Nonnull FxTileableEffectPropertiesName;

extern NSNotificationName	const _Nonnull FxTileableEffectParametersKey;
extern NSNotificationName	const _Nonnull FxTileableEffectAddParametersName;
extern NSNotificationName	const _Nonnull FxTileableEffectFinishInitialSetupName;
extern NSNotificationName	const _Nonnull FxTileableEffectAddedToDocumentName;

extern NSNotificationName	const _Nonnull FxTileableEffectParameterChangedName;
extern NSNotificationName	const _Nonnull FxTileableEffectParameterChangedIDKey;		// NSNumber(FxParameterId) of the changed parameter
extern NSNotificationName	const _Nonnull FxTileableEffectParameterChangedAtTimeKey;	// CMTime-as-NSDictionary of the change time
extern NSNotificationName	const _Nonnull FxTileableEffectParameterClickedName;
extern NSNotificationName	const _Nonnull FxTileableEffectParameterClickedIDKey;		// NSNumber(FxParameterId) of the clicked button
extern NSNotificationName	const _Nonnull FxTileableEffectFlushName;

/*! Posted by a parameter class before registration so observers apply host policy to the
	declared configuration (the default font of a font menu, a color's gamut conversion). The
	userInfo's parameter dictionary is mutable; the effect base observes and applies its policy. */
extern NSNotificationName	const _Nonnull FxTileableEffectParameterPolicyName;

/*! Posted by a group parameter after opening its subgroup so the configuration's owner adds the
	group's children. The userInfo carries the group ID; an error returns through fxError. */
extern NSNotificationName	const _Nonnull FxTileableEffectAddGroupParametersName;
extern NSString				* const _Nonnull FxTileableEffectGroupIDKey;

/*! Posted to resolve a host service: an observer that owns the meta manager or the parameter
	data answers by setting it under FxTileableEffectResolvedObjectKey in the mutable userInfo.
	The effect base answers through its members directly; the resolve path serves a plain host
	whose extensions supply the service. */
extern NSNotificationName	const _Nonnull FxTileableEffectResolveMetaName;
extern NSNotificationName	const _Nonnull FxTileableEffectResolveParameterDataName;
extern NSString				* const _Nonnull FxTileableEffectResolvedObjectKey;

extern NSNotificationName	const _Nonnull FxTileableEffectPluginStateCoderKey;
extern NSNotificationName	const _Nonnull FxTileableEffectPluginStateName;
extern NSNotificationName	const _Nonnull FxTileableEffectDestinationImageRectName;
extern NSNotificationName	const _Nonnull FxTileableEffectSourceTileRectName;
extern NSNotificationName	const _Nonnull FxTileableEffectScheduleInputsName;
extern NSNotificationName	const _Nonnull FxTileableEffectRenderDestinationImageName;
extern NSNotificationName	const _Nonnull FxTileableEffectRenderDestinationImageKey;	// FxImageTile* destination
extern NSNotificationName	const _Nonnull FxTileableEffectRenderSourceImagesKey;		// NSArray<FxImageTile*>* sources
extern NSNotificationName	const _Nonnull FxTileableEffectRenderAtTimeKey;			// CMTime-as-NSDictionary of the render time

extern NSNotificationName	const _Nonnull FxTileableEffectRemovedFromDocumentName;
extern NSNotificationName	const _Nonnull FxTileableEffectUnloadName;


@protocol FxGripAPIAccessing;

@interface NSDictionary (FxNotificationUserInfo)
// The FxGripAPIAccessing instance carried by FxTileableEffectInitName.
- (nullable id<FxGripAPIAccessing>)fxApiManager;
@property (readonly, nullable) NSMutableArray<NSMutableDictionary *> *fxEffectParameters;
@property (readonly, nullable) NSMutableDictionary<NSString *, id>* fxEffectProperties;
@property (readonly, nullable) NSCoder* fxCoder;

//- (id _Nullable)objectAtIndexedSubscript:(NSInteger)index;
@end


#endif
