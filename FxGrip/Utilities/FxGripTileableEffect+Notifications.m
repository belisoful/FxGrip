/*!
	@file       FxGripTileableEffect+Notifications.m
	@copyright  Copyright © 2020-2023 Apple, Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+Notifications
	@abstract   Defines the effect's notification names and userInfo payload accessors.
	@discussion Introduced in FxGrip 0.1.0. The file assigns the string value of each notification
	            name and userInfo key. It implements the NSDictionary category that reads the API
	            manager, effect properties, parameter configuration, and coder from a userInfo
	            dictionary.
*/

#import "FxGripTileableEffect+Notifications.h"


NSNotificationName const _Nonnull FxGripTileableEffectLoadName = @"FxGripEffectLoad";

NSNotificationName const _Nonnull FxGripTileableEffectInitAPIManagerKey = @"FxGripEffectInit_APIManager";
NSNotificationName const _Nonnull FxGripTileableEffectInitName = @"FxGripEffectInit";

//NSNotificationName const _Nonnull FxGripTileableEffectErrorKey = @"Fx_Error";

NSNotificationName const _Nonnull FxGripTileableEffectPropertiesKey = @"FxGripEffectProperties_Properties";
NSNotificationName const _Nonnull FxGripTileableEffectPropertiesName = @"FxGripEffectProperties";

NSNotificationName const _Nonnull FxGripTileableEffectParametersKey = @"FxGripEffectParameters";
NSNotificationName const _Nonnull FxGripTileableEffectAddParametersName = @"FxGripEffectAddParameters";
NSNotificationName const _Nonnull FxGripTileableEffectFinishInitialSetupName = @"FxGripEffectFinishInitialSetup";
NSNotificationName const _Nonnull FxGripTileableEffectAddedToDocumentName = @"FxGripEffectAddedToDocument";

NSNotificationName const _Nonnull FxGripTileableEffectParameterChangedName = @"FxGripEffectParameterChanged";
NSNotificationName const _Nonnull FxGripTileableEffectParameterChangedIDKey = @"FxGripEffectParameterChanged_ID";
NSNotificationName const _Nonnull FxGripTileableEffectParameterChangedAtTimeKey = @"FxGripEffectParameterChanged_AtTime";
NSNotificationName const _Nonnull FxGripTileableEffectParameterClickedName = @"FxGripEffectParameterClicked";
NSNotificationName const _Nonnull FxGripTileableEffectParameterClickedIDKey = @"FxGripEffectParameterClicked_ID";
NSNotificationName const _Nonnull FxGripTileableEffectFlushName = @"FxGripEffectFlush";
NSNotificationName const _Nonnull FxGripTileableEffectParameterPolicyName = @"FxGripEffectParameterPolicy";
NSNotificationName const _Nonnull FxGripTileableEffectAddGroupParametersName = @"FxGripEffectAddGroupParameters";
NSString * const _Nonnull FxGripTileableEffectGroupIDKey = @"groupID";
NSNotificationName const _Nonnull FxGripTileableEffectResolveMetaName = @"FxGripEffectResolveMeta";
NSNotificationName const _Nonnull FxGripTileableEffectResolveParameterDataName = @"FxGripEffectResolveParameterData";
NSString * const _Nonnull FxGripTileableEffectResolvedObjectKey = @"resolvedObject";

NSNotificationName const _Nonnull FxGripTileableEffectPluginStateCoderKey = @"FxGripEffectPluginState_Coder";
NSNotificationName const _Nonnull FxGripTileableEffectPluginStateName = @"FxGripEffectPluginState";
NSNotificationName const _Nonnull FxGripTileableEffectDestinationImageRectName = @"FxGripEffectDestinationImageRect";
NSNotificationName const _Nonnull FxGripTileableEffectSourceTileRectName = @"FxGripEffectSourceTileRect";
NSNotificationName const _Nonnull FxGripTileableEffectScheduleInputsName = @"FxGripEffectScheduleInputs";
NSNotificationName const _Nonnull FxGripTileableEffectRenderDestinationImageName = @"FxGripEffectRenderDestinationImage";
NSNotificationName const _Nonnull FxGripTileableEffectRenderDestinationImageKey = @"FxGripEffectRenderDestinationImage_Destination";
NSNotificationName const _Nonnull FxGripTileableEffectRenderSourceImagesKey = @"FxGripEffectRenderDestinationImage_Sources";
NSNotificationName const _Nonnull FxGripTileableEffectRenderAtTimeKey = @"FxGripEffectRenderDestinationImage_AtTime";

NSNotificationName const _Nonnull FxGripTileableEffectRemovedFromDocumentName = @"FxGripEffectRemovedFromDocument";
NSNotificationName const _Nonnull FxGripTileableEffectUnloadName = @"FxGripEffectUnload";

#pragma mark -
#pragma mark NSDictionary FxPlug Notification UserInfo Access

/*!
	@abstract	The category that reads FxGrip notification payloads from a userInfo dictionary.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@implementation NSDictionary (FxNotificationUserInfo)

- (nullable id<FxGripAPIAccessing>)fxApiManager {
	return self[FxGripTileableEffectInitAPIManagerKey];
}

- (nullable NSMutableDictionary *)fxEffectProperties {
	return self[FxGripTileableEffectPropertiesKey];
}

- (nullable NSMutableArray<NSMutableDictionary*> *)fxEffectParameters {
	return self[FxGripTileableEffectParametersKey];
}

- (nullable NSCoder *)fxCoder {
	return self[FxGripTileableEffectPluginStateCoderKey];
}


@end

