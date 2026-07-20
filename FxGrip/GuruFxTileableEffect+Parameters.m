/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  NSMutableDictionary-Extension.swift
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#import <objc/runtime.h>
#import "GuruFxTileableEffect+Parameters.h"
#import "GuruFxTileableEffect+Extensions.h"
#import "NSDictionary+FxTileableEffect.h"

#import "GuruFxAllParameters.h"

@implementation GuruFxTileableEffect (Parameters)


- (NSArray<NSDictionary*> * _Nonnull)initialParametersFromGroup:(FxParameterId)parameterID
{
	NSArray<NSDictionary*> *initialParameters = self.initialParameters.allValues;
	
	return [initialParameters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat: @"parameterParentID = %d", parameterID]];
}


// this is called by the Guru FxPlug 4 API Accessing, Creation API
- (BOOL)addParameter:(nonnull NSDictionary *)parameterDictionary
{
	
	NSDictionary* initialParam = [self initialParameter:parameterDictionary.parameterID];
	
	id<GuruFxParameterProtocol> parameter = initialParam.parameterFactory;
	
	if (!parameter) {
		parameter = [self parameterForDictionary:parameterDictionary];
	} else if ([parameter conformsToProtocol:@protocol(GuruFxExtensionParameterProtocol)]) {
		id<GuruFxExtensionParameterProtocol> extension = nil;//(id<GuruFxExtensionParameterProtocol>)parameter;
		parameter = [extension parameterForDictionary:parameterDictionary];
	}
	
	// Install other Parameter properties from initial
	//		reset Value
	//		tags
	//		etc
	
	_parameters[@(parameter.parameterID)] = parameter;
	
	// Add to the parent parameter structure.
	FxParameterId parentID = parameter.parameterParentID;
	if (parentID) {
		id<GuruFxSubParameters> parent = (id<GuruFxSubParameters>)self[parentID];
		if ([parent conformsToProtocol:@protocol(GuruFxSubParameters)]) {
			[((id<GuruFxSubParameters>)self[parentID]) addChildParameter:parameter];
		} else {
			NSLog(@"Error: %d Has parent %d that does not contain sub parameters", parameter.parameterID, parentID);
		}
	}
	
	return [self extensionsAddParameter:parameter];
}


- (BOOL)endParameterSubGroup
{
	return YES;
}



- (NSMutableArray<NSMutableDictionary*>*_Nonnull)flattenDictionaryParameters:(NSMutableArray<NSDictionary*>* _Nonnull)parameters
{
	NSMutableArray<NSMutableDictionary*> *flat = [parameters mutableCopy];
	
	//convert parameters to NSMutableDictionaries
	// flatten group parameters, recurse until all nested are flattened.
	for(int i = 0; i < flat.count; i++) {
		NSMutableDictionary *param = flat[i];
		
		if (param.parameterType == FxParameterType_Group) {
			// Groups unfold their inner parameters setting their parentId
			if (param[kFxParameterProperty_GroupParameters]) {
				id _group = param[kFxParameterProperty_GroupParameters];
				
				[param removeObjectForKey:kFxParameterProperty_GroupParameters];
				
				if ([_group isKindOfClass:NSDictionary.class]) {
					_group = ((NSDictionary*)_group).allValues;
				} else if (![_group isKindOfClass:NSArray.class]) {
					continue;
				}
				
				int j = 1;
				for(NSMutableDictionary *groupParam in (NSArray*)_group) {
					if (!groupParam[kFxParameterProperty_ParentId])
						groupParam[kFxParameterProperty_ParentId] = @(param.parameterID);
					
					// Added at the next i so they also get processed.
					[flat insertObject:groupParam atIndex:i + j];
					j++;
				}
			}
		}
	}
	return flat;
}

static NSArray<NSString*> *offLangs = @[@"off", @"af", @"عن", @"বন্ধ", @"离开", @"uit", @"désactivé", @"aus", @"hemo", @"बंद", @"オフ", @"ਬੰਦ", @"выключенный", @"apagado"];

// Main function to instance a parameter from a dictionary.
//  This returns the object at kFxParameterProperty_Factory if it is already
// allocated and initialized.
- (id<GuruFxParameterProtocol> _Nullable)parameterForDictionary:(NSDictionary*_Nonnull)data
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self IN %@", offLangs];
	NSArray *hasOff = [data.allKeys filteredArrayUsingPredicate:predicate];
	if (hasOff.count) {
		NSLog(@"keys %@ turned off parameter %d", hasOff, data.parameterID);
		return NULL;
	}
	
	FxParameterType type = [self parameterTypeForString:data[kFxParameterProperty_Type]];
	Class parameterClass = [self parameterClassForType:type];
	id<GuruFxParameterProtocol> instance = nil;
	
	// the type must have a root type class even if a customClass or instance.
	if (!parameterClass) {
		return NULL;
	}
	
	if (data[kFxParameterProperty_Factory]) {
		instance = data[kFxParameterProperty_Factory];
		if (![instance conformsToProtocol:@protocol(GuruFxParameterProtocol)] ) {
			NSLog(@"Error: parameter instance %@ does not conform to GuruFxParameterProtocol.", instance.class.className);
			return nil;
		}
		if (instance.parameterType != type) {
			NSLog(@"Error: parameter instance %@ is type %ld but is specified to be a %ld in configuration.", instance.class.className, (long)instance.parameterType, (long)type);
			return nil;
		}
		return instance;
	}
	
	if (data[kFxParameterProperty_ClassName]) {
		NSString *className = data[kFxParameterProperty_ClassName];
		Class cls = nil;
		if (![className isKindOfClass:NSString.class]) {
			NSLog(@"Error: instancing class name %@, it is not an NSString.", className);
			return nil;
		} else {
			cls = NSClassFromString(className);
		}
		if (!cls) {
			NSLog(@"Error: Class %@ does not exist.", className);
			return nil;
		}
		parameterClass = cls;
	}
	
	if (![parameterClass conformsToProtocol: @protocol(GuruFxParameterProtocol)]) {
		NSLog(@"Error: class %@ does not conform to GuruFxParameterProtocol.", parameterClass.className);
		return nil;
	}
	instance = [parameterClass.alloc initWithDictionary:data];
	
	return instance;
}


//Plugins should override this to provide their own type.
//  Typically, this does not need to be overloaded except by framework developers.
//
- (FxParameterType)parameterTypeForString:(nullable NSString *)type
{
	if (!type || ![type isKindOfClass:NSString.class] || !type.length) {
		return FxParameterType_None;
	}
	FxParameterType extType = [self extensionParameterTypeForString:type];
	
	if (extType) {
		return extType;
	}
	return [GuruFxParameterConverter parameterTypeFromString:type];
}


//Plugins should override this to provide their own type.
//  Typically, this does not need to be overloaded except by framework developers.
//
- (nullable Class)parameterClassForType:(FxParameterType)type
{
	if (type == FxParameterType_None) {
		return nil;
	}
	Class cls = [self extensionParameterClassForType:type];
	
	if (cls) {
		return cls;
	}
	
	const NSDictionary *typeClasses = @{
		@(FxParameterType_Angle):		GuruFxAngleParameter.class,
		@(FxParameterType_RGBA):		GuruFxColorParameter.class,
		@(FxParameterType_RGB):			GuruFxRGBParameter.class,
		@(FxParameterType_Custom):		GuruFxCustomParameter.class,
		@(FxParameterType_Float):		GuruFxFloatParameter.class,
		@(FxParameterType_FontMenu):	GuruFxFontMenuParameter.class,
		@(FxParameterType_Gradient):	GuruFxGradientParameter.class,
		@(FxParameterType_Help): 		GuruFxHelpParameter.class,
		@(FxParameterType_Histogram):	GuruFxHistogramParameter.class,
		@(FxParameterType_ImageRef): 	GuruFxImageRefParameter.class,
		@(FxParameterType_Int): 		GuruFxIntParameter.class,
		@(FxParameterType_PathID):		GuruFxPathParameter.class,
		@(FxParameterType_Percent): 	GuruFxPercentParameter.class,
		@(FxParameterType_Point):		GuruFxPointParameter.class,
		@(FxParameterType_Menu):		GuruFxMenuParameter.class,
		@(FxParameterType_PushButton):	GuruFxPushButtonParameter.class,
		@(FxParameterType_String):		GuruFxStringParameter.class,
		@(FxParameterType_Group):		GuruFxGroupParameter.class,
		@(FxParameterType_Toggle):		GuruFxToggleParameter.class,
		
		//
#if 0
		@(FxParameterType_Section): [GuruFxSectionParameter class],
		@(FxParameterType_Random): [GuruFxRandomParameter class],
		@(FxParameterType_Capsule): [GuruFxCapsuleParameter class],
		@(FxParameterType_Banner): [GuruFxBannerParameter class],
		@(FxParameterType_Presets): [GuruFxPresetsParameter class],
		@(FxParameterType_Status): [GuruFxStatusParameter class],
		@(FxParameterType_Progress): [GuruFxProgressParameter class],
		@(FxParameterType_Switch): [GuruFxSwitchParameter class],
		@(FxParameterType_Divider): [GuruFxDividerParameter class],
		@(FxParameterType_WebView): [GuruFxWebViewParameter class],
		@(FxParameterType_VideoView): [GuruFxVideoViewParameter class],
#endif
	};
	return typeClasses[@(type)];
}

@end


