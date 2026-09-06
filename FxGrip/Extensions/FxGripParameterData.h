/*!
	@file       FxGripParameterData.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterData
	@abstract   The extension that stores per-parameter static properties in the document.
	@discussion Introduced in FxGrip 0.1.0. FxPlug does not vend a parameter's type, flags, parent, menu
	            items, or selector back to the plugin after creation. This extension captures those
	            entries from the add notification into a hidden custom parameter, persists them on
	            flush, and answers reads for them. On a flags read it restores the stored app-mask
	            bits; on a flags or menu write it recaptures the change.
*/

#ifndef FxGripParameterData_h
#define FxGripParameterData_h

#import "FxGripCustomExtension.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGripTileableEffect.h"

// Record keys. These alias the parameter property keys the notification payloads carry,
// so the stored records and the accessors name the same entries.
/*! The record key for a parameter's type. */
#define kExtParameterData_Type kFxParameterProperty_Type
/*! The record key for a parameter's flags. */
#define kExtParameterData_Flag kFxParameterProperty_Flags
/*! The record key for a parameter's parent group ID. */
#define kExtParameterData_SubGroup kFxParameterProperty_ParentId
/*! The record key for a parameter's menu items. */
#define kExtParameterData_MenuItems kFxParameterProperty_MenuItems
/*! The record key for a parameter's action selector. */
#define kExtParameterData_Selector kFxParameterProperty_Selector

// store tags	-	 Custom API
// store target presets	-	Custom API

/*!
	@class		FxGripParameterData
	@abstract	The extension that captures and persists per-parameter static properties.
	@discussion	Introduced in FxGrip 0.1.0. The store is a dictionary keyed by parameter ID; each value
				is the parameter's record. The store loads from the document, tracks a dirty flag,
				and flushes to a hidden custom parameter.
*/
@interface FxGripParameterData : FxGripCustomExtension <NSNotificationObjectPriorityItem>
{
	NSMutableDictionary<NSNumber*, NSMutableDictionary<NSString*, id>*>*_Nonnull	_pData;
}
/*! The stored records, keyed by parameter ID. */
@property (readonly, nonatomic, nonnull) NSDictionary<NSNumber*, NSMutableDictionary<NSString*, id>*>* data;

/*! YES once the store exists. */
@property (readonly, nonatomic) BOOL isLoaded;
/*! YES when the store has unsaved changes. */
@property (readonly, nonatomic) BOOL isCacheDirty;

/*! The stored type of a parameter, or 0 when unknown. */
- (FxParameterType)storedType:(FxParameterId)parameterID;
/*! The stored flags of a parameter, or 0 when unknown. */
- (FxParameterFlags)storedFlags:(FxParameterId)parameterID;
/*! The stored parent group ID of a parameter, or -1 when unknown. */
- (FxParameterId)storedParentId:(FxParameterId)parameterID;
/*! The stored menu items of a parameter, or nil when unknown. */
- (nullable NSArray<NSString*> *)storedMenus:(FxParameterId)parameterID;
/*! The stored action selector of a parameter, or nil when unknown. */
- (nullable NSString *)storedSelector:(FxParameterId)parameterID;


/*! Writes a value into a parameter's record when it differs, marking the store dirty. */
- (void)setObject:(nonnull id)object forKey:(nonnull NSString *)key toParameter:(FxParameterId)parameterID;
/*! Reads a value from a parameter's record. */
- (nullable id)objectForKey:(nonnull NSString *)key fromParameter:(FxParameterId)parameterID;

/*! The notification priority for a name; seeds before construction and flushes after the base. */
- (NSInteger)ncPriority:(nullable NSNotificationName)aName;

@end




/*!
	@abstract	The effect-side accessors for the parameter data extension.
	@discussion	Introduced in FxGrip 0.1.0. parameterData resolves the loaded extension.
*/
@interface FxGripTileableEffect (ParameterData)

/*! The installed parameter data extension, or nil when none is installed. */
@property (readonly, nullable, nonatomic) FxGripParameterData* parameterData;

/*! Creates the parameter data extension instance for the loader to install. */
- (nonnull FxGripParameterData*)newParameterDataExtension;

@end

#endif
