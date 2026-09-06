/*!
	@file       FxGripPluginGroupData.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPluginGroupData
	@abstract   Implements the typed accessor over one plugin group's registration dictionary.
	@discussion Introduced in FxGrip 0.1.0. The uuid and name accessors read and write the group
	            dictionary's two entries. Any change invalidates the cached data snapshot.
*/

#import "FxGripPluginGroupData.h"


/*!
	@abstract	The mutable model of one plugin group's registration dictionary.
	@discussion	Introduced in FxGrip 0.1.0. The backing dictionary holds the group UUID and name, and
				data vends an immutable copy.
*/
@implementation FxGripPluginGroupData
{
	NSMutableDictionary<NSString*, NSString*> *__data;
}

@synthesize data = _data;


+ (instancetype)newPluginGroupUUID:(NSString*)groupUUID groupName:(NSString*)groupName
{
	return [self.class.alloc initWithGroupUUID:groupUUID groupName:groupName];
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_data = nil;
		__data = NSMutableDictionary.new;
	}
	return self;
}

- (instancetype)initWithGroupUUID:(NSString*)groupUUID groupName:(NSString*)groupName
{
	self = [self init];
	if (self) {
		self.uuid = groupUUID;
		self.name = groupName;
	}
	return self;
}

- (NSString*)uuid
{
	return __data[kProPlugPlugInX_RegGroupUUIDProperty];
}

- (void)setUuid:(NSString*)value
{
	if (value) {
		__data[kProPlugPlugInX_RegGroupUUIDProperty] = value;
	} else {
		[__data removeObjectForKey:kProPlugPlugInX_RegGroupUUIDProperty];
	}
	_data = nil;
}


- (NSString*)name
{
	return __data[kProPlugPlugInX_RegGroupNameProperty];
}

- (void)setName:(NSString*)value
{
	if (value) {
		__data[kProPlugPlugInX_RegGroupNameProperty] = value;
	} else {
		[__data removeObjectForKey:kProPlugPlugInX_RegGroupNameProperty];
	}
	_data = nil;
}


- (NSDictionary<NSString*, NSString*>*)data
{
	if (!_data) {
		_data = __data.copy;
	}
	return _data;
}

- (void)setData:(NSDictionary*)value
{
	NSString *element = [value objectForKey:kProPlugPlugInX_RegGroupUUIDProperty];
	if (element) {
		__data[kProPlugPlugInX_RegGroupUUIDProperty] = element;
	} else {
		[__data removeObjectForKey:kProPlugPlugInX_RegGroupUUIDProperty];
	}
	
	element = [value objectForKey:kProPlugPlugInX_RegGroupNameProperty];
	if (element) {
		__data[kProPlugPlugInX_RegGroupNameProperty] = element;
	} else {
		[__data removeObjectForKey:kProPlugPlugInX_RegGroupNameProperty];
	}
	_data = nil;
}

@end
