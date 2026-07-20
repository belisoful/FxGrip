//
//  FxGripClassRegistrar.h
//  XPC Service
//
//  Created on 3/11/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxPluginGroupData_h
#define FxPluginGroupData_h

#import <Foundation/Foundation.h>

#ifndef kProPlugPlugIn_GroupList_Property
	#define kProPlugPlugIn_GroupList_Property		@"ProPlugPlugInGroupList"
#endif

#ifndef kProPlugPlugInX_RegGroupUUIDProperty
	#define kProPlugPlugInX_RegGroupUUIDProperty	@"uuid"
#endif
#ifndef kProPlugPlugInX_RegGroupNameProperty
	#define kProPlugPlugInX_RegGroupNameProperty	@"groupName"
#endif

@interface FxPluginGroupData : NSObject

@property (retain, nonatomic, nonnull) NSDictionary<NSString*, NSString*> *data;

@property (retain, nonatomic, nullable) NSString *uuid;
@property (retain, nonatomic, nullable) NSString *name;


+ (nonnull instancetype)newPluginGroupUUID:(nullable NSString*)groupUUID groupName:(nullable NSString*)groupName;

- (nonnull instancetype)init;
- (nonnull instancetype)initWithGroupUUID:(nullable NSString*)groupUUID groupName:(nullable NSString*)groupName;

@end


#endif
