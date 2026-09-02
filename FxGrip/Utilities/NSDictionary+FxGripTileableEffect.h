//
//  NSDictionary+FxGripTileableEffect.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#ifndef NSDictionary_FxGripTileableEffect_h
#define NSDictionary_FxGripTileableEffect_h

#import <Foundation/Foundation.h>
#import "FxGripTypes.h"
#import <BEFoundation/NSString+BExtension.h>

@protocol FxParameterFactory;

@interface NSNumber (FxGripTileableEffect)

- (FxParameterType)parameterType;

@end

@interface NSString (FxGripTileableEffect)

- (FxParameterType)parameterType;
- (NSArray<NSString*>*_Nonnull)splitByHumanDividers;

@end


@interface NSArray (FxGripTileableEffect)

- (NSArray*_Nonnull)localize;
- (id _Nullable)objectForIndex:(NSUInteger)index;

- (FxParameterFlags)fxParameterFlags;
- (FxParameterFlags)negativeFxParameterFlags;

@end



@interface NSDictionary (FxGripTileableEffect)

- (id _Nullable) objectForIndex:(NSUInteger)index;

- (NSString*_Nullable) pluginUUID;
- (NSString*_Nullable) pluginClassName;
- (NSString*_Nullable) pluginDisplayName;
- (NSString*_Nullable) pluginGroupUUID;
- (NSArray<NSString*>*_Nullable) pluginProtocolNames;
- (NSString*_Nullable) pluginInfoString;
- (NSString*_Nullable) pluginDefaultFontName;
- (NSString*_Nullable) pluginVersion;
- (NSDictionary<NSString*, NSDictionary*>*_Nullable) pluginPresets;
- (NSDictionary<NSString*, id>*_Nullable) pluginEffectProperties;

- (NSArray<NSString*>* _Nullable) pluginPriorUUIDs;
- (NSArray<NSDictionary*>* _Nullable) pluginParameters;
- (BOOL) pluginDebugMenu;
- (BOOL) pluginDebugActivator;
- (BOOL) pluginManageMeta;
- (BOOL) pluginManageParameterData;
- (BOOL) pluginTrackInstances;
- (BOOL) pluginRegression;
- (BOOL) pluginFxFactory;


- (nullable id<FxParameterFactory>)parameterFactory;
- (nullable NSString *)parameterExtensionKey;
- (nullable NSString *)parameterClassName;

@property (readonly, nonatomic) FxParameterType parameterType;
@property (readonly, nonatomic) FxParameterId parameterID;
@property (readonly, nonatomic) FxParameterId parameterParentID;

- (NSString*_Nullable) parameterName;
- (NSString*_Nullable) parameterDescription;
- (FxParameterFlags) parameterFlags;
- (NSArray<NSString*>*_Nullable) parameterFlagsArray;
- (NSArray<NSString*>*_Nullable) parameterTags;
- (NSDictionary*_Nullable) parameterMeta;
- (NSString*_Nullable) parameterCustomClass;
- (NSSet<NSString*>*_Nullable) parameterCustomClasses;
- (id _Nullable) parameterDefaultValue;
- (id _Nullable) parameterResetValue;
- (id _Nullable) parameterTargetPreset;

- (NSNumber*_Nullable)parameterMinimum_Raw;
- (int)parameterMinimumInt;
- (double)parameterMinimumDouble;
- (NSNumber*_Nullable) parameterMaximum;
- (int)parameterMaximumInt;
- (double)parameterMaximumDouble;
- (NSNumber*_Nullable) parameterSliderMinimum;
- (NSNumber*_Nullable) parameterSliderMaximum;
- (NSNumber*_Nullable) parameterDelta;
- (NSNumber*_Nullable) parameterRed;
- (NSNumber*_Nullable) parameterGreen;
- (NSNumber*_Nullable) parameterBlue;
- (NSNumber*_Nullable) parameterAlpha;
- (NSNumber*_Nullable) parameterColorSpace;
- (id _Nullable) parameterSelector;
- (NSObject*_Nullable)parameterSelectorObject;
- (NSNumber*_Nullable) parameterDefaultX;
- (NSNumber*_Nullable) parameterDefaultY;
- (NSArray<NSString*>*_Nullable) parameterMenuItems;

-(NSNumber*_Nullable) parameterGradientSamples;
-(FxGripDepthType) parameterGradientDepth;
-(FxGripDepthType) parameterGradientDepthType;

@end


@interface NSMutableDictionary (FxGripTileableEffect)

@property (readwrite, nonatomic) FxParameterType parameterType;
@property (readwrite, nonatomic) FxParameterId parameterID;
@property (readwrite, nonatomic) FxParameterId parameterParentID;
@property (readwrite, nonatomic) FxParameterFlags parameterFlags;

@end

#endif	//	NSDictionary_FxGripTileableEffect_h
