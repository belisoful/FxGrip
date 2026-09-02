//
//  FxGripParameterData.h
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripParameterData_h
#define FxGripParameterData_h

#import "FxGripCustomExtension.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGripTileableEffect.h"

// Record keys. These alias the parameter property keys the notification payloads carry,
// so the stored records and the accessors name the same entries.
#define kExtParameterData_Type kFxParameterProperty_Type
#define kExtParameterData_Flag kFxParameterProperty_Flags
#define kExtParameterData_SubGroup kFxParameterProperty_ParentId
#define kExtParameterData_MenuItems kFxParameterProperty_MenuItems
#define kExtParameterData_Selector kFxParameterProperty_Selector

// store tags	-	 Custom API
// store target presets	-	Custom API

@interface FxGripParameterData : FxGripCustomExtension <NSNotificationObjectPriorityItem>
{
	NSMutableDictionary<NSNumber*, NSMutableDictionary<NSString*, id>*>*_Nonnull	_pData;
}
@property (readonly, nonatomic, nonnull) NSDictionary<NSNumber*, NSMutableDictionary<NSString*, id>*>* data;

@property (readonly, nonatomic) BOOL isLoaded;
@property (readonly, nonatomic) BOOL isCacheDirty;

- (FxParameterType)storedType:(FxParameterId)parameterID;
- (FxParameterFlags)storedFlags:(FxParameterId)parameterID;
- (FxParameterId)storedParentId:(FxParameterId)parameterID;
- (nullable NSArray<NSString*> *)storedMenus:(FxParameterId)parameterID;
- (nullable NSString *)storedSelector:(FxParameterId)parameterID;


- (void)setObject:(nonnull id)object forKey:(nonnull NSString *)key toParameter:(FxParameterId)parameterID;
- (nullable id)objectForKey:(nonnull NSString *)key fromParameter:(FxParameterId)parameterID;

- (NSInteger)ncPriority:(nullable NSNotificationName)aName;

@end




@interface FxGripTileableEffect (ParameterData)

@property (readonly, nullable, nonatomic) FxGripParameterData* parameterData;

- (nonnull FxGripParameterData*)newParameterDataExtension;

@end

#endif
