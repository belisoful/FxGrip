//
//  FxGripParameterData.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripParameterData_h
#define FxGripParameterData_h

#import "FxGripCustomExtension.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import <FxTileableEffectBase.h>

#define kExtParameterData_Type @"type"
#define kExtParameterData_Flag @"flag"
#define kExtParameterData_SubGroup @"subgroup"
#define kExtParameterData_MenuItems @"menu"
#define kExtParameterData_Selector @"selector"

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




@interface FxTileableEffectBase (ParameterData)

@property (readonly, nullable, nonatomic) FxGripParameterData* parameterData;

- (nonnull FxGripParameterData*)newParameterDataExtension;

@end

#endif
