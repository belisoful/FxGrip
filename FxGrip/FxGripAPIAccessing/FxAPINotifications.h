//
//  FxAPINotifications.h
//  FxAPINotifications
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#ifndef FxAPINotifications_h
#define FxAPINotifications_h

#import <Foundation/Foundation.h>

//Notification post names
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterKey;
extern NSNotificationName const _Nonnull FxNotifyAPI_ResultKey;
extern NSNotificationName const _Nonnull FxNotifyAPI_ErrorKey;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterIDKey;

extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterAddPreName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterAddName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterStartGroupName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterEndGroupName;

extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterRemoveName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetNameName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetNamePreName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetNameName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetTypeName;

extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetFloatBoundsName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetIntBoundsName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetMenuName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetMenuPreName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetMenuName;

extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetFlagsPreName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetFlagsName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetStringValueName;

extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetBoolName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetCustomValueName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetFloatName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetHistogramName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetIntName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetFlagsPreName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetFlagsName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetPathIDName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetRGBAName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetRGBName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetStringValuePreName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetStringValueName;
extern NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetXYName;



@interface NSDictionary (FxAPINotificationUserInfo)
@property (readonly, nullable, nonatomic) NSDictionary* fxParameter;
@property (readonly, nullable, nonatomic) NSMutableDictionary* mutableFxParameter;
@property (readonly, nullable) NSError* fxError;
@property (readonly, nullable) id fxResult;
@end

@interface NSMutableDictionary (FxAPINotificationUserInfo)
@property (readwrite, nullable, nonatomic) NSDictionary* fxParameter;
@property (readwrite, nullable) id fxResult;
@property (readwrite, nullable) NSError* fxError;
@end

#endif
