//
//  FxGripAPINotifications.h
//  FxGripAPINotifications
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#ifndef FxGripAPINotifications_h
#define FxGripAPINotifications_h

#import <Foundation/Foundation.h>

//Notification post names
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterKey;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ResultKey;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ErrorKey;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterIDKey;

extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterAddPreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterAddName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterStartGroupName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterEndGroupName;

extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterRemoveName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetNameName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetNamePreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetNameName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetTypeName;

extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFloatBoundsName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetIntBoundsName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetMenuName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetMenuPreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetMenuName;

extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetFlagsPreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetFlagsName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetStringValueName;

extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetBoolName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetCustomValueName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFloatName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetHistogramName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetIntName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFlagsPreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFlagsName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetPathIDName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetRGBAName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetRGBName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetStringValuePreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetStringValueName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetXYName;



@interface NSDictionary (FxGripAPINotificationUserInfo)
@property (readonly, nullable, nonatomic) NSDictionary* fxParameter;
@property (readonly, nullable, nonatomic) NSMutableDictionary* mutableFxParameter;
@property (readonly, nullable) NSError* fxError;
@property (readonly, nullable) id fxResult;
@end

@interface NSMutableDictionary (FxGripAPINotificationUserInfo)
@property (readwrite, nullable, nonatomic) NSDictionary* fxParameter;
@property (readwrite, nullable) id fxResult;
@property (readwrite, nullable) NSError* fxError;
@end

#endif
