/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  GuruFxTileableEffect+Parameters.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//
#ifndef GuruFxTileableEffect_Parameters_h
#define GuruFxTileableEffect_Parameters_h

#import <Foundation/Foundation.h>

#import "FxTileableEffectBase.h"
#import "GuruFxParameter.h"

// @todo  move the GuruFxTileableEffect Initial parameter stuff here.

@interface FxTileableEffectBase (Parameters)

- (BOOL)addParameter:(nonnull NSDictionary *)parameter;
//- (BOOL)addParameter:(FxParameterId)parameterID customClass:(Class _Nonnull)customClass flags:(FxParameterFlags)flags;
//- (BOOL)addParameter:(FxParameterId)parameterID type:(FxParameterType)type flags:(FxParameterFlags)flags;
- (BOOL)endParameterSubGroup;


//- (NSArray<id<GuruFxParameterProtocol>>*_Nonnull)initialParametersFromGroup:(FxParameterId)parameterID;

//- (NSMutableArray<NSMutableDictionary*>*_Nonnull)flattenDictionaryParameters:(NSMutableArray<NSDictionary*>* _Nonnull)parameters;


// Primary Instancing method
- (id<FxTileableEffectBase>_Nullable)parameterForDictionary:(NSDictionary*_Nonnull)data;


//	override this to add custom parameter types
//		extensions are also queried via extensionParameterClassForType
- (nullable Class)parameterClassForType:(FxParameterType)type;


@end

#endif	//	GuruFxTileableEffect_Parameters_h
