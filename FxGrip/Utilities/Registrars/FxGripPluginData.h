//
//  FxGripClassRegistrar.h
//  XPC Service
//
//  Created on 3/11/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripPluginData_h
#define FxGripPluginData_h

#import <Foundation/Foundation.h>

#ifndef kProPlugPlugInList_Property
	#define kProPlugPlugInList_Property							@"ProPlugPlugInList"
#endif


@interface FxGripPluginData : NSObject

@property (retain, nonatomic, nonnull) NSDictionary<NSString*, id> *data;

@property (retain, nonatomic, nullable) NSString	*uuid;				// kProPlugPlugIn_UuidProperty
@property (retain, nonatomic, nullable) NSString	*pluginClassName;	// kProPlugPlugIn_ClassNameProperty
@property (retain, nonatomic, nullable) NSString	*displayName;		// kProPlugPlugIn_DisplayNameProperty
@property (retain, nonatomic, nullable) NSString	*groupUuid;			// kProPlugPlugIn_GroupUUIDProperty
@property (retain, nonatomic, nullable)	NSArray		*protocolNames;		// kProPlugPlugIn_ProtocolNamesProperty
@property (retain, nonatomic, nullable) NSString	*infoString;		// kProPlugPlugIn_InfoStringProperty
@property (retain, nonatomic, nullable) NSNumber	*version;			// kProPlugPlugIn_VersionProperty
@property (nonatomic)					NSUInteger	versionInteger;

//array of prior uuids this is tied to
@property (retain, nonatomic, nullable) NSArray		*supportedPlugins;	// kProPlugPlugIn_SupportedPluginsProperty

+ (nonnull instancetype)newPluginWithDictionary:(nullable NSDictionary*)data;

- (nonnull instancetype)init;
- (nonnull instancetype)initWithDictionary:(nullable NSDictionary*)data;

- (nullable id)objectForKeyedSubscript:(nullable NSString *)key;
- (void) setObject:(nullable id)obj forKeyedSubscript:(nonnull NSString *)key;

@end


#endif
