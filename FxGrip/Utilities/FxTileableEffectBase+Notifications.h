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
extern NSNotificationName	const _Nonnull FxTileableEffectFlushName;

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


@interface NSDictionary (FxNotificationUserInfo)
- (nullable NSString *)fxApiManager;
@property (readonly, nullable) NSMutableArray<NSMutableDictionary *> *fxEffectParameters;
@property (readonly, nullable) NSMutableDictionary<NSString *, id>* fxEffectProperties;
@property (readonly, nullable) NSCoder* fxCoder;

//- (id _Nullable)objectAtIndexedSubscript:(NSInteger)index;
@end


#endif
