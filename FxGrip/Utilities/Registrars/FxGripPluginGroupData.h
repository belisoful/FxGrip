/*!
	@file       FxGripPluginGroupData.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPluginGroupData
	@abstract   A typed accessor over one plugin group's registration dictionary.
	@discussion Introduced in FxGrip 0.1.0. The class wraps the two-entry dictionary that describes a
	            plugin group. The uuid and name properties read and write the group's UUID and display
	            name in the backing store. The data property returns an immutable snapshot rebuilt on
	            demand.
*/

#ifndef FxGripPluginGroupData_h
#define FxGripPluginGroupData_h

#import <Foundation/Foundation.h>

/*! The Info.plist key that holds the host's plugin group list. */
#ifndef kProPlugPlugIn_GroupList_Property
	#define kProPlugPlugIn_GroupList_Property		@"ProPlugPlugInGroupList"
#endif

/*! The group dictionary key for the group UUID. */
#ifndef kProPlugPlugInX_RegGroupUUIDProperty
	#define kProPlugPlugInX_RegGroupUUIDProperty	@"uuid"
#endif
/*! The group dictionary key for the group display name. */
#ifndef kProPlugPlugInX_RegGroupNameProperty
	#define kProPlugPlugInX_RegGroupNameProperty	@"groupName"
#endif

/*!
	@class		FxGripPluginGroupData
	@abstract	The mutable model of one plugin group's registration dictionary.
	@discussion	Introduced in FxGrip 0.1.0. The uuid and name properties map to the group dictionary's
				two keys, and data vends an immutable copy.
*/
@interface FxGripPluginGroupData : NSObject

/*! @abstract An immutable snapshot of the backing dictionary, rebuilt after any change. */
@property (retain, nonatomic, nonnull) NSDictionary<NSString*, NSString*> *data;

/*! @abstract The group UUID. */
@property (retain, nonatomic, nullable) NSString *uuid;
/*! @abstract The group display name. */
@property (retain, nonatomic, nullable) NSString *name;


/*!
	@method		newPluginGroupUUID:groupName:
	@abstract	Creates a group data instance from a UUID and name.
	@param		groupUUID	The group UUID.
	@param		groupName	The group display name.
	@return		A new FxGripPluginGroupData. */
+ (nonnull instancetype)newPluginGroupUUID:(nullable NSString*)groupUUID groupName:(nullable NSString*)groupName;

- (nonnull instancetype)init;

/*!
	@method		initWithGroupUUID:groupName:
	@abstract	Initializes the instance from a UUID and name.
	@param		groupUUID	The group UUID.
	@param		groupName	The group display name. */
- (nonnull instancetype)initWithGroupUUID:(nullable NSString*)groupUUID groupName:(nullable NSString*)groupName;

@end


#endif
