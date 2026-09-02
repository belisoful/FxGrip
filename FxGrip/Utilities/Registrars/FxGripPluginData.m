
#import "FxGripPluginData.h"
#import <FxGrip/FxGripTypes.h>

/*!
 Within the mainBundle, the property `FxGripRegisteredPlugins` contains the list of plugin effect classes via `NSString*` (human separated), NSArray, or NSDictionary values.
 */

@implementation FxGripPluginData
{
	NSMutableDictionary<NSString*, id> *__data;
}

@synthesize data = _data;


+ (instancetype)newPluginWithDictionary:(nullable NSDictionary*)data
{
	return [self.class.alloc initWithDictionary:data];
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

- (instancetype)initWithDictionary:(nullable NSDictionary*)data
{
	self = [self init];
	if (self) {
		if (data) {
			[self setData:data];
		}
	}
	return self;
}

- (NSString*)uuid
{
	return __data[kProPlugPlugIn_UuidProperty];
}

- (void)setUuid:(NSString*)value
{
	if (value) {
		__data[kProPlugPlugIn_UuidProperty] = value;
	} else {
		[__data removeObjectForKey:kProPlugPlugIn_UuidProperty];
	}
	_data = nil;
}


- (NSString*)pluginClassName
{
	return __data[kProPlugPlugIn_ClassNameProperty];
}

- (void)setPluginClassName:(NSString *)value
{
	if (value) {
		__data[kProPlugPlugIn_ClassNameProperty] = value;
	} else {
		[__data removeObjectForKey:kProPlugPlugIn_ClassNameProperty];
	}
	_data = nil;
}


- (NSString*)displayName
{
	return __data[kProPlugPlugIn_DisplayNameProperty];
}

- (void)setDisplayName:(NSString *)value
{
	if (value) {
		__data[kProPlugPlugIn_DisplayNameProperty] = value;
	} else {
		[__data removeObjectForKey:kProPlugPlugIn_DisplayNameProperty];
	}
	_data = nil;
}


- (NSString*)groupUuid
{
	return __data[kProPlugPlugIn_GroupUUIDProperty];
}

- (void)setGroupUuid:(NSString *)value
{
	if (value) {
		__data[kProPlugPlugIn_GroupUUIDProperty] = value;
	} else {
		[__data removeObjectForKey:kProPlugPlugIn_GroupUUIDProperty];
	}
	_data = nil;
}


- (NSArray *)protocolNames
{
	return __data[kProPlugPlugIn_ProtocolNamesProperty];
}

- (void)setProtocolNames:(id)value
{
	if (value) {
		if (![value isKindOfClass:NSArray.class]) {
			value = @[value];
		}
		__data[kProPlugPlugIn_ProtocolNamesProperty] = value;
	} else {
		[__data removeObjectForKey:kProPlugPlugIn_ProtocolNamesProperty];
	}
	_data = nil;
}


- (NSString *)infoString
{
	return __data[kProPlugPlugIn_InfoStringProperty];
}

- (void)setInfoString:(NSString *)value
{
	if (value) {
		__data[kProPlugPlugIn_InfoStringProperty] = value;
	} else {
		[__data removeObjectForKey:kProPlugPlugIn_InfoStringProperty];
	}
	_data = nil;
}


- (NSNumber *)version
{
	return __data[kProPlugPlugIn_VersionProperty];
}

- (void)setVersion:(id)value
{
	if (value) {
		if ([value isKindOfClass:NSString.class]) {
			value = [NSNumber numberWithUnsignedInteger: [(NSString *)value integerValue]];
		}
		__data[kProPlugPlugIn_VersionProperty] = value;
	} else {
		[__data removeObjectForKey:kProPlugPlugIn_VersionProperty];
	}
	_data = nil;
}



- (NSUInteger)versionInteger
{
	return [(NSNumber*)__data[kProPlugPlugIn_VersionProperty] unsignedIntegerValue];
}

- (void)setVersionInteger:(NSUInteger)value
{
	if (value) {
		__data[kProPlugPlugIn_VersionProperty] = [NSNumber numberWithUnsignedInteger:value];
	} else {
		[__data removeObjectForKey:kProPlugPlugIn_VersionProperty];
	}
	_data = nil;
}


- (NSNumber *)supportedPlugins
{
	return __data[kProPlugPlugIn_SupportedPluginsProperty];
}

- (void)setSupportedPlugins:(id)value
{
	if (value) {
		if (![value isKindOfClass:NSArray.class]) {
			value = @[value];
		}
		__data[kProPlugPlugIn_SupportedPluginsProperty] = value;
	} else {
		[__data removeObjectForKey:kProPlugPlugIn_SupportedPluginsProperty];
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
	[__data removeAllObjects];
	if (value && [value isKindOfClass:NSDictionary.class]) {
		[__data addEntriesFromDictionary:value];
		[self validate];
	}
	_data = nil;
}

- (void)validate
{
	NSArray *protocolNames = __data[kProPlugPlugIn_ProtocolNamesProperty];
	
	if (protocolNames && ![protocolNames isKindOfClass:NSArray.class]) {
		__data[kProPlugPlugIn_ProtocolNamesProperty] = @[protocolNames];
		_data = nil;
	}
	
	NSString *version = __data[kProPlugPlugIn_VersionProperty];
	
	if (version && [version isKindOfClass:NSString.class]) {
		__data[kProPlugPlugIn_VersionProperty] = [NSNumber numberWithUnsignedInteger: [version integerValue]];
		_data = nil;
	}
	
	NSArray *supportedPlugins = __data[kProPlugPlugIn_SupportedPluginsProperty];
	
	if (supportedPlugins && ![supportedPlugins isKindOfClass:NSArray.class]) {
		__data[kProPlugPlugIn_SupportedPluginsProperty] = @[supportedPlugins];
		_data = nil;
	}
}


- (nullable id)objectForKeyedSubscript:(nullable NSString *)key
{
	return __data[key];
}

- (void) setObject:(nullable id)obj forKeyedSubscript:(nonnull NSString *)key;
{
	if (obj) {
		if (key) {
			if ([key isEqualToString:kProPlugPlugIn_ProtocolNamesProperty] && ![obj isKindOfClass:NSArray.class]) {
				obj = @[obj];
			} else if ([key isEqualToString:kProPlugPlugIn_VersionProperty] && [obj isKindOfClass:NSString.class]) {
				obj = [NSNumber numberWithUnsignedInteger: [(NSString *)obj integerValue]];
			} else if ([key isEqualToString:kProPlugPlugIn_SupportedPluginsProperty] && ![obj isKindOfClass:NSArray.class]) {
				obj = @[obj];
			}
		}
		__data[key] = obj;
	} else {
		[__data removeObjectForKey:key];
	}
	_data = nil;
}

@end
