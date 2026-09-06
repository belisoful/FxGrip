/*!
	@file       FxGripPluginData.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPluginData
	@abstract   A typed accessor over one plugin's registration dictionary.
	@discussion Introduced in FxGrip 0.1.0. The class wraps the property dictionary that describes a
	            single registered plugin. Each named property reads and writes its entry in the backing
	            store under the matching kProPlugPlugIn_* key. Keyed subscripting reaches entries that
	            have no named property. Setting a value coerces protocol names and supported plugins to
	            arrays and a string version to a number.
*/

#ifndef FxGripPluginData_h
#define FxGripPluginData_h

#import <Foundation/Foundation.h>

/*! The Info.plist key that holds the host's plugin list. */
#ifndef kProPlugPlugInList_Property
	#define kProPlugPlugInList_Property							@"ProPlugPlugInList"
#endif


/*!
	@class		FxGripPluginData
	@abstract	The mutable model of one plugin's registration dictionary.
	@discussion	Introduced in FxGrip 0.1.0. Named properties map to kProPlugPlugIn_* keys in the backing
				dictionary. The data property returns an immutable snapshot rebuilt on demand.
*/
@interface FxGripPluginData : NSObject

/*! @abstract An immutable snapshot of the backing dictionary, rebuilt after any change. */
@property (retain, nonatomic, nonnull) NSDictionary<NSString*, id> *data;

/*! @abstract The plugin UUID. */
@property (retain, nonatomic, nullable) NSString	*uuid;				// kProPlugPlugIn_UuidProperty
/*! @abstract The plugin's class name. */
@property (retain, nonatomic, nullable) NSString	*pluginClassName;	// kProPlugPlugIn_ClassNameProperty
/*! @abstract The plugin's display name. */
@property (retain, nonatomic, nullable) NSString	*displayName;		// kProPlugPlugIn_DisplayNameProperty
/*! @abstract The UUID of the group that contains the plugin. */
@property (retain, nonatomic, nullable) NSString	*groupUuid;			// kProPlugPlugIn_GroupUUIDProperty
/*! @abstract The FxPlug protocol names the plugin conforms to; a scalar is wrapped in an array. */
@property (retain, nonatomic, nullable)	NSArray		*protocolNames;		// kProPlugPlugIn_ProtocolNamesProperty
/*! @abstract The plugin's description string. */
@property (retain, nonatomic, nullable) NSString	*infoString;		// kProPlugPlugIn_InfoStringProperty
/*! @abstract The plugin version as a number; 1000 encodes v1.0.0.0. A string is converted to a number. */
@property (retain, nonatomic, nullable) NSNumber	*version;			// kProPlugPlugIn_VersionProperty
/*! @abstract The plugin version as an unsigned integer, reading and writing the version entry. */
@property (nonatomic)					NSUInteger	versionInteger;

/*! @abstract The prior plugin UUIDs this plugin supports; a scalar is wrapped in an array. */
//array of prior uuids this is tied to
@property (retain, nonatomic, nullable) NSArray		*supportedPlugins;	// kProPlugPlugIn_SupportedPluginsProperty

/*!
	@method		newPluginWithDictionary:
	@abstract	Creates a plugin data instance seeded from a registration dictionary.
	@param		data	The registration dictionary, or nil for an empty instance.
	@return		A new FxGripPluginData. */
+ (nonnull instancetype)newPluginWithDictionary:(nullable NSDictionary*)data;

- (nonnull instancetype)init;

/*!
	@method		initWithDictionary:
	@abstract	Initializes the instance from a registration dictionary.
	@param		data	The registration dictionary, or nil for an empty instance. */
- (nonnull instancetype)initWithDictionary:(nullable NSDictionary*)data;

/*! @abstract Returns the backing entry for a key, supporting keyed subscripting. */
- (nullable id)objectForKeyedSubscript:(nullable NSString *)key;
/*! @abstract Sets the backing entry for a key, coercing protocol names, version, and supported plugins. */
- (void) setObject:(nullable id)obj forKeyedSubscript:(nonnull NSString *)key;

@end


#endif
