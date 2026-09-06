/*!
	@file       FxGripTileableEffect+Notifications.h
	@copyright  Copyright © 2020-2023 Apple, Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+Notifications
	@abstract   The notification names and userInfo keys the effect posts through its lifecycle and render path.
	@discussion Introduced in FxGrip 0.1.0. Each FxPlug lifecycle stage and render callback posts a
	            named notification on the effect's priority notification center, so extensions
	            participate without subclassing. The file declares the notification names, the
	            userInfo keys that carry each notification's payload, and an NSDictionary category
	            that reads the payloads from a notification's userInfo.
*/

#ifndef FxGripTileableEffect_Notifications_h
#define FxGripTileableEffect_Notifications_h

#import <Foundation/Foundation.h>

//	FxGripTileableEffectLoadName is used in ncPriority to get extension priority for load
/*! The name under which an extension's load priority is read while ordering the extensions. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectLoadName;

//Notification post names
/*! The userInfo key carrying the FxGripAPIAccessing instance on the init notification. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectInitAPIManagerKey;
/*! Posted when the effect is initialized. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectInitName;

/*! The userInfo key carrying the mutable effect-properties dictionary. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectPropertiesKey;
/*! Posted while the effect builds its FxPlug properties, for extension revision. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectPropertiesName;

/*! The userInfo key carrying the mutable parameter-configuration array. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectParametersKey;
/*! Posted while the effect adds parameters, for extensions to contribute configuration records. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectAddParametersName;
/*! Posted when the effect finishes its initial setup. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectFinishInitialSetupName;
/*! Posted when the effect is added to a document. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectAddedToDocumentName;

/*! Posted when a parameter value changes. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectParameterChangedName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectParameterChangedIDKey;		// NSNumber(FxParameterId) of the changed parameter
extern NSNotificationName	const _Nonnull FxGripTileableEffectParameterChangedAtTimeKey;	// CMTime-as-NSDictionary of the change time
/*! Posted when a button or help-button parameter is clicked. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectParameterClickedName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectParameterClickedIDKey;		// NSNumber(FxParameterId) of the clicked button
/*! Posted so extensions commit pending parameter and state work. */
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
/*! Posted to resolve the meta manager from an owning extension. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectResolveMetaName;
/*! Posted to resolve the parameter-data store from an owning extension. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectResolveParameterDataName;
/*! The userInfo key under which a resolve observer sets the resolved service object. */
extern NSString				* const _Nonnull FxGripTileableEffectResolvedObjectKey;

/*! The userInfo key carrying the NSCoder that encodes or decodes the render state. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectPluginStateCoderKey;
/*! Posted while the effect encodes its render-time plugin state. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectPluginStateName;
/*! Posted while the effect computes its destination image rect. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectDestinationImageRectName;
/*! Posted while the effect computes a source tile rect. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectSourceTileRectName;
/*! Posted while the effect schedules its render inputs. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectScheduleInputsName;
/*! Posted after the effect renders a destination image tile. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectRenderDestinationImageName;
extern NSNotificationName	const _Nonnull FxGripTileableEffectRenderDestinationImageKey;	// FxImageTile* destination
extern NSNotificationName	const _Nonnull FxGripTileableEffectRenderSourceImagesKey;		// NSArray<FxImageTile*>* sources
extern NSNotificationName	const _Nonnull FxGripTileableEffectRenderAtTimeKey;			// CMTime-as-NSDictionary of the render time

/*! Posted when the effect is removed from a document. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectRemovedFromDocumentName;
/*! Posted when the effect is unloaded. */
extern NSNotificationName	const _Nonnull FxGripTileableEffectUnloadName;


@protocol FxGripAPIAccessing;

/*!
	@abstract	The category that reads FxGrip notification payloads from a userInfo dictionary.
	@discussion	Introduced in FxGrip 0.1.0. Each accessor returns the value stored under the
				matching notification key, or nil when it is absent.
*/
@interface NSDictionary (FxNotificationUserInfo)
/*! @abstract The FxGripAPIAccessing instance carried by FxGripTileableEffectInitName. */
- (nullable id<FxGripAPIAccessing>)fxApiManager;
/*! @abstract The mutable parameter-configuration array carried by the add-parameters notification. */
@property (readonly, nullable) NSMutableArray<NSMutableDictionary *> *fxEffectParameters;
/*! @abstract The mutable effect-properties dictionary carried by the properties notification. */
@property (readonly, nullable) NSMutableDictionary<NSString *, id>* fxEffectProperties;
/*! @abstract The NSCoder carried by the render-path notifications. */
@property (readonly, nullable) NSCoder* fxCoder;

//- (id _Nullable)objectAtIndexedSubscript:(NSInteger)index;
@end


#endif
