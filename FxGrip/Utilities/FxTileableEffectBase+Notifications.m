//
//  FxTileableEffectNotifications.m
//  FxTileableEffectNotifications
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#import "FxTileableEffectBase+Notifications.h"


NSNotificationName const _Nonnull FxTileableEffectLoadName = @"FxEffectLoad";

NSNotificationName const _Nonnull FxTileableEffectInitAPIManagerKey = @"FxEffectInit_APIManager";
NSNotificationName const _Nonnull FxTileableEffectInitName = @"FxEffectInit";

//NSNotificationName const _Nonnull FxTileableEffectErrorKey = @"Fx_Error";

NSNotificationName const _Nonnull FxTileableEffectPropertiesKey = @"FxEffectProperties_Properties";
NSNotificationName const _Nonnull FxTileableEffectPropertiesName = @"FxEffectProperties";

NSNotificationName const _Nonnull FxTileableEffectParametersKey = @"FxEffectParameters";
NSNotificationName const _Nonnull FxTileableEffectAddParametersName = @"FxEffectAddParameters";
NSNotificationName const _Nonnull FxTileableEffectFinishInitialSetupName = @"FxEffectFinishInitialSetup";
NSNotificationName const _Nonnull FxTileableEffectAddedToDocumentName = @"FxEffectAddedToDocument";

NSNotificationName const _Nonnull FxTileableEffectParameterChangedName = @"FxEffectParameterChanged";
NSNotificationName const _Nonnull FxTileableEffectParameterChangedIDKey = @"FxEffectParameterChanged_ID";
NSNotificationName const _Nonnull FxTileableEffectParameterChangedAtTimeKey = @"FxEffectParameterChanged_AtTime";
NSNotificationName const _Nonnull FxTileableEffectFlushName = @"FxEffectFlush";

NSNotificationName const _Nonnull FxTileableEffectPluginStateCoderKey = @"FxEffectPluginState_Coder";
NSNotificationName const _Nonnull FxTileableEffectPluginStateName = @"FxEffectPluginState";
NSNotificationName const _Nonnull FxTileableEffectDestinationImageRectName = @"FxEffectDestinationImageRect";
NSNotificationName const _Nonnull FxTileableEffectSourceTileRectName = @"FxEffectSourceTileRect";
NSNotificationName const _Nonnull FxTileableEffectScheduleInputsName = @"FxEffectScheduleInputs";
NSNotificationName const _Nonnull FxTileableEffectRenderDestinationImageName = @"FxEffectRenderDestinationImage";
NSNotificationName const _Nonnull FxTileableEffectRenderDestinationImageKey = @"FxEffectRenderDestinationImage_Destination";
NSNotificationName const _Nonnull FxTileableEffectRenderSourceImagesKey = @"FxEffectRenderDestinationImage_Sources";
NSNotificationName const _Nonnull FxTileableEffectRenderAtTimeKey = @"FxEffectRenderDestinationImage_AtTime";

NSNotificationName const _Nonnull FxTileableEffectRemovedFromDocumentName = @"FxEffectRemovedFromDocument";
NSNotificationName const _Nonnull FxTileableEffectUnloadName = @"FxEffectUnload";

#pragma mark -
#pragma mark NSDictionary FxPlug Notification UserInfo Access

@implementation NSDictionary (FxNotificationUserInfo)

- (nullable NSString *)fxApiManager {
	return self[FxTileableEffectInitAPIManagerKey];
}

- (nullable NSMutableDictionary *)fxEffectProperties {
	return self[FxTileableEffectPropertiesKey];
}

- (nullable NSMutableArray<NSMutableDictionary*> *)fxEffectParameters {
	return self[FxTileableEffectParametersKey];
}

- (nullable NSCoder *)fxCoder {
	return self[FxTileableEffectPluginStateCoderKey];
}


@end

