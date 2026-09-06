/*!
	@file       NSDictionary+FxGripTileableEffect.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     NSDictionary+FxGripTileableEffect
	@abstract   Implements the typed plug-in and parameter accessors over Foundation collections.
	@discussion Introduced in FxGrip 0.1.0. Each plug-in accessor guards on the required plug-in
	            keys and each parameter accessor guards on the required parameter keys, so a
	            dictionary of the wrong shape returns a neutral value. Flag and tag accessors
	            accept a string, array, dictionary, or number and normalize to one form.
*/

#import <BEFoundation/NSArray+BExtension.h>
#import <BEFoundation/NSDictionary+BExtension.h>
#import "FxGripTypes.h"
#import "FxGripParameterUtility.h"
#import "FxGripPluginInfo.h"
#import "FxGripPrimeNumbers.h"
#import "FxGripParameter.h"
#import <BEFoundation/NSNumber+Primes16b.h>

//#import "FxGrip.h"


/*! @abstract Reads a numeric parameter type. @discussion Introduced in FxGrip 0.1.0. */
@implementation NSNumber (FxGripTileableEffect)

- (FxParameterType)parameterType
{
	return self.intValue;
}

@end



/*! @abstract Resolves a type name and splits divided lists. @discussion Introduced in FxGrip 0.1.0. */
@implementation NSString (FxGripTileableEffect)

- (FxParameterType)parameterType
{
	return [FxGripParameterUtility parameterTypeFromString:self];
}

- (NSArray<NSString*>*_Nonnull)splitByHumanDividers
{
	return [self componentsSeparatedByCharactersInSet:FxGripPluginInfo.separatorSet];
}

@end



/*!
	@abstract	Localizes entries and folds flag-name arrays into a mask.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@implementation NSArray (FxGripTileableEffect)

- (NSArray*_Nonnull)localize
{
	return [self mapUsingBlock:^BOOL(id  _Nullable __autoreleasing * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		if ([*obj isKindOfClass:[NSString class]]) {
			*obj = NSLocalizedString(*obj, *obj);
		}
		return YES;
	}];
}


- (id _Nullable)objectForIndex:(NSUInteger)index
{
	return self[index];
}


/*!
	@method		fxParameterFlags
	@abstract	The flag mask named by the array's entries.
	@discussion	Introduced in FxGrip 0.1.0. A bare or "+"-prefixed entry sets its flag; a
				"-"-prefixed entry clears it. Non-string entries are skipped. */
- (FxParameterFlags)fxParameterFlags
{
	FxParameterFlags result = kFxParameterFlag_DEFAULT;
	
	for (NSString *_flag in self) {
		NSString *flag = _flag;
		BOOL add = YES, rm1Char = NO;
		if (![flag isKindOfClass:[NSString class]]) {
			continue;
		}
		if ([flag hasPrefix:@"-"]) {
			add = NO;
			rm1Char = YES;
		} else if ([flag hasPrefix:@"+"]) {
			rm1Char = YES;
		}
		if (rm1Char) {
			flag = [flag substringFromIndex:1];
		}
		if (add) {
			result |= [FxGripParameterUtility convertFlag:flag];
		} else {
			result &= ~[FxGripParameterUtility convertFlag:flag];
		}
	}
	
	return result;
}

/*! @abstract The mask of flags named by the array's "-"-prefixed entries. */
- (FxParameterFlags)negativeFxParameterFlags
{
	FxParameterFlags result = kFxParameterFlag_DEFAULT;

	for (NSString *_flag in self) {
		NSString *flag = _flag;
		if (![flag isKindOfClass:[NSString class]]) {
			continue;
		}
		if ([flag hasPrefix:@"-"]) {
			flag = [flag substringFromIndex:1];
			result |= [FxGripParameterUtility convertFlag:flag];
		}
	}
	return result;
}
@end



/*!
	@abstract	Typed reads of plug-in registration and parameter configuration.
	@discussion	Introduced in FxGrip 0.1.0. The guard macros return a neutral value unless the
				dictionary carries the required plug-in or parameter keys.
*/
@implementation NSDictionary (FxGripTileableEffect)

#define isPluginDictionary(returnValue) if (!self[kProPlugPlugIn_UuidProperty] || !self[kProPlugPlugIn_ClassNameProperty] || !self[kProPlugPlugIn_GroupUUIDProperty]) {return returnValue;}

#define isParameterDictionary(returnValue) if (!self[kFxParameterProperty_Id] || !self[kFxParameterProperty_Type] || !self[kFxParameterProperty_Name]) {return returnValue;}


/*! @abstract The object under an integer index, matched as a number key then a decimal-string key. */
- (id)objectForIndex:(NSUInteger)index
{
	id obj = self[@(index)];
	if (!obj) {
		obj = self[[NSString stringWithFormat:@"%lu", index]];
	}
	return obj;
}


#pragma mark -
#pragma mark Plugin Property Access


- (NSString*_Nullable)pluginUUID
{
	isPluginDictionary(nil);
	return self[kProPlugPlugIn_UuidProperty];
}

- (NSString*_Nullable)pluginClassName
{
	isPluginDictionary(nil);
	return self[kProPlugPlugIn_ClassNameProperty];
}

- (NSString*_Nullable)pluginDisplayName
{
	isPluginDictionary(nil);
	return self[kProPlugPlugIn_DisplayNameProperty];
}

- (NSString*_Nullable)pluginGroupUUID
{
	isPluginDictionary(nil);
	return self[kProPlugPlugIn_GroupUUIDProperty];
}

- (NSArray<NSString*>*_Nullable)pluginProtocolNames
{
	isPluginDictionary(nil);
	return self[kProPlugPlugIn_ProtocolNamesProperty];
}

- (NSString*_Nullable)pluginInfoString
{
	isPluginDictionary(nil);
	return self[kProPlugPlugIn_InfoStringProperty];
}

- (NSString*_Nullable)pluginDefaultFontName
{
	isPluginDictionary(nil);
	return self[kProPlugPlugInX_DefaultFontNameProperty];
}

- (NSString*_Nullable)pluginVersion
{
	isPluginDictionary(nil);
	return self[kProPlugPlugIn_VersionProperty];
}

- (NSDictionary<NSString*, NSDictionary*>*_Nullable)pluginPresets
{
	isPluginDictionary(nil);
	return self[kProPlugPlugInX_PresetsProperty];
}

- (NSDictionary<NSString*, id>*_Nullable)pluginEffectProperties
{
	isPluginDictionary(nil);
	return self[kProPlugPlugInX_EffectPropertiesProperty];
}

- (NSArray<NSString*>*_Nullable)pluginPriorUUIDs
{
	isPluginDictionary(nil);
	id prior = self[kProPlugPlugInX_PriorUuidsProperty];
	
	if (prior && [prior isKindOfClass:[NSString class]]) {
		NSString *value = prior;
		prior = [value splitByHumanDividers];
	}
	
	return prior;
}

- (NSArray<NSDictionary*>*_Nullable)pluginParameters
{
	isPluginDictionary(nil);
	return self[kProPlugPlugInX_ParametersProperty];
}

- (BOOL)pluginDebugMenu
{
	isPluginDictionary(NO);
	NSNumber *value = self[kProPlugPlugInX_DebugMenuProperty];
	if (value != nil) {
		return value.boolValue;
	}
	return NO;
}

- (BOOL)pluginDebugActivator
{
	isPluginDictionary(NO);
	NSNumber *value = self[kProPlugPlugInX_DebugActivatorProperty];
	if (value != nil) {
		return value.boolValue;
	}
	return NO;
}

- (NSDictionary*_Nullable)pluginAboutMenu
{
	isPluginDictionary(nil);
	NSDictionary *value = self[kProPlugPlugInX_AboutMenuProperty];
	if ([value isKindOfClass:NSDictionary.class]) {
		return value;
	}
	return nil;
}

- (BOOL)pluginManageMeta
{
	isPluginDictionary(NO);
	NSNumber *value = self[kProPlugPlugInX_ManagedMetaProperty];
	if (value != nil) {
		return value.boolValue;
	}
	// Meta management is on by default; a plugin opts out with manageMeta = NO.
	return YES;
}

- (BOOL)pluginManageParameterData
{
	isPluginDictionary(NO);

	NSNumber *value = self[kProPlugPlugInX_ManagedParameterDataProperty];
	if (value != nil) {
		return value.boolValue;
	}
	return NO;
}

- (BOOL)pluginRegression
{
	isPluginDictionary(NO);

	NSNumber *value = self[kProPlugPlugInX_RegressionProperty];
	if (value != nil) {
		return value.boolValue;
	}
	// Opt-in, matching the other extension gates: the regression pass validates plugin
	// identity properties and is only wanted during development.
	return NO;
}

- (BOOL)pluginFxFactory
{
	isPluginDictionary(NO);

	NSNumber *value = self[kProPlugPlugInX_FxFactoryProperty];
	if (value != nil) {
		return value.boolValue;
	}
	// Opt-in: only plugins distributed through FxFactory license/watermark through it.
	return NO;
}

- (BOOL)pluginTrackInstances
{
	isPluginDictionary(NO);

	NSNumber *value = self[kProPlugPlugInX_TrackInstancesProperty];
	if (value != nil) {
		return value.boolValue;
	}
	// Opt-in, matching pluginManageMeta / pluginManageParameterData: the process-wide
	// instance registry only serves neighbour queries, so effects that do not ask for
	// it pay no registry cost.
	return NO;
}



#pragma mark -
#pragma mark Parameter Property Access

- (id<FxParameterFactory>_Nullable)parameterFactory
{
	isParameterDictionary(nil);
	
	return self[kFxParameterProperty_Factory];
}
- (NSString*_Nullable)parameterExtensionKey
{
	isParameterDictionary(nil);
	
	return self[kFxParameterProperty_ExtensionKey];
}


- (NSString*_Nullable)parameterClassName
{
	isParameterDictionary(nil);
	
	id value = self[kFxParameterProperty_ClassName];
	if (value != nil && [value isKindOfClass:NSString.class]) {
		return value;
	}
	return nil;
}

- (FxParameterType)parameterType
{
	isParameterDictionary(FxParameterType_None);
	
	id value = self[kFxParameterProperty_Type];
	if (value) {
		if ([value isKindOfClass:[NSNumber class]])
			return ((NSNumber*)value).intValue;
		if ([value isKindOfClass:[NSString class]])
			return [FxGripParameterUtility parameterTypeFromString:(NSString*)value];
		
	}
	return FxParameterType_None;
}

- (FxParameterId)parameterID
{
	isParameterDictionary(kFxParameterId_None);
	
	NSNumber *value = self[kFxParameterProperty_Id];
	if (value != nil) {
		return value.intValue;
	}
	return kFxParameterId_None;
}

- (FxParameterId)parameterParentID
{
	isParameterDictionary(kFxParameterId_None);
	
	NSNumber *parentId = self[kFxParameterProperty_ParentId];
	if (parentId != nil)
		return parentId.intValue;
	return kFxParameterId_TopLevelGroup;
}

- (NSString*_Nullable)parameterName
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_Name];
}

- (NSString*_Nullable)parameterDescription
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_Description];
}

/*!
	@method		parameterFlags
	@abstract	The parameter flag mask.
	@discussion	Introduced in FxGrip 0.1.0. A string splits on human dividers, a dictionary
				contributes its values, and a number returns directly. The default flag applies
				when no flags key is present. */
- (FxParameterFlags)parameterFlags
{
	isParameterDictionary(kFxParameterFlag_INVALID);
	
	id flags = self[kFxParameterProperty_Flags];
	if (!flags)
		return kFxParameterFlag_DEFAULT;
	if ([flags isKindOfClass:[NSString class]]) {
		flags = [((NSString*)flags) splitByHumanDividers];
	} else if ([flags isKindOfClass:[NSDictionary class]]) {
		flags = [flags allValues];
	} else if ([flags isKindOfClass:[NSNumber class]]) {
		return [flags intValue];
	}
	
	return [((NSArray*)flags) fxParameterFlags];
}

- (NSArray<NSString*>*_Nullable)parameterFlagsArray
{
	isParameterDictionary(nil);
	
	id flags = self[kFxParameterProperty_Flags];
	if (!flags)
		return @[];
	if ([flags isKindOfClass:[NSString class]]) {
		return [((NSString*)flags) splitByHumanDividers];
	} else if ([flags isKindOfClass:[NSDictionary class]]) {
		flags = [flags allValues];
	} else if ([flags isKindOfClass:[NSNumber class]]) {
		FxParameterFlags n = [flags unsignedIntValue];
		flags = [FxGripParameterUtility convertToFlags:n];
	}
	
	//Presume NSArray
	return flags;
}

- (NSArray<NSString*>*_Nullable)parameterTags
{
	isParameterDictionary(nil);
	
	id tags = self[kFxParameterProperty_Tags];
	if ([tags isKindOfClass:[NSString class]])
		return [((NSString*)tags) splitByHumanDividers];
	return tags;
}

- (NSDictionary*_Nullable)parameterMeta
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_Meta];
}


- (NSString*_Nullable)parameterCustomClass
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_CustomClass];
}

- (NSSet<NSString*>*_Nullable)parameterCustomClasses
{
	isParameterDictionary(nil);
	id customClasses = self[kFxParameterProperty_CustomClasses];
	if (!customClasses)
		return [NSSet set];
	if ([customClasses isKindOfClass:[NSString class]])
		return [NSSet setWithArray:[customClasses splitByHumanDividers]];
	if ([customClasses isKindOfClass:[NSArray class]])
		return [NSSet setWithArray:customClasses];
	return customClasses;
}

- (id _Nullable)parameterDefaultValue
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_Default];
}
- (id _Nullable)parameterResetValue
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_ResetValue];
}

//NSString *tag, or NSArray/NSDictionary (keys are number indices)
- (id _Nullable)parameterTargetPreset
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_TargetPreset];
}

- (NSNumber*_Nullable)parameterMinimum_Raw
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_Minimum];
}

- (int)parameterMinimumInt
{
	isParameterDictionary(0);
	return [self[kFxParameterProperty_Minimum] intValue];
}

- (double)parameterMinimumDouble
{
	isParameterDictionary(0.0);
	return [self[kFxParameterProperty_Minimum] doubleValue];
}

- (NSNumber*_Nullable)parameterMaximum
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_Maximum];
}

- (int)parameterMaximumInt
{
	isParameterDictionary(0);
	return [self[kFxParameterProperty_Maximum] intValue];
}

- (double)parameterMaximumDouble
{
	isParameterDictionary(0.0);
	return [self[kFxParameterProperty_Maximum] doubleValue];
}


- (NSNumber*_Nullable)parameterSliderMinimum
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_SliderMinimum];
}

- (NSNumber*_Nullable)parameterSliderMaximum
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_SliderMaximum];
}


- (NSNumber*_Nullable)parameterDelta
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_Delta];
}

- (NSNumber*_Nullable)parameterRed
{
	return self[kFxParameterProperty_Red];
}

- (NSNumber*_Nullable)parameterGreen
{
	return self[kFxParameterProperty_Green];
}

- (NSNumber*_Nullable)parameterBlue
{
	return self[kFxParameterProperty_Blue];
}

- (NSNumber*_Nullable)parameterAlpha
{
	return self[kFxParameterProperty_Alpha];
}

- (NSNumber*_Nullable)parameterColorSpace
{
	return self[kFxParameterProperty_ColorSpace];
}

- (id _Nullable)parameterSelector
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_Selector];
}

- (NSObject*_Nullable)parameterSelectorObject
{
	isParameterDictionary(nil);
	return self[kFxParameterProperty_SelectorObject];
}

/*!
	@method		parameterDefaultX
	@abstract	The point default's X coordinate.
	@discussion	Introduced in FxGrip 0.1.0. The value comes from an X key, or the default's X
				entry, first array element, or first whitespace-split token. A string coerces to
				a double, and a missing value returns zero. */
- (NSNumber*_Nullable)parameterDefaultX
{
	id value = self[kFxParameterProperty_X];
	if (!value && self[kFxParameterProperty_Default]) {
		NSArray<id> *defaultValues = nil;
		if ([self[kFxParameterProperty_Default] isKindOfClass:NSDictionary.class]) {
			value = self[kFxParameterProperty_Default][kFxParameterProperty_X];
		} else if ([self[kFxParameterProperty_Default] isKindOfClass:NSArray.class]) {
			defaultValues = self[kFxParameterProperty_Default];
		} else if ([self[kFxParameterProperty_Default] isKindOfClass:NSString.class]) {
			NSString *str = self[kFxParameterProperty_Default];
			defaultValues = [str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		}
		if (defaultValues && defaultValues.count >= 1) {
			value = defaultValues[0];
		}
	}
	if (!value) {
		value = @0.0;
	} else if ([value isKindOfClass:NSString.class]) {
		value= @(((NSString*)value).doubleValue);
	}
	return value;
}

/*! @abstract The point default's Y coordinate, from a Y key or the default's second component; zero when absent. */
- (NSNumber*_Nullable)parameterDefaultY
{
	id value = self[kFxParameterProperty_Y];
	if (!value && self[kFxParameterProperty_Default]) {
		NSArray<id> *defaultValues = nil;
		if ([self[kFxParameterProperty_Default] isKindOfClass:NSDictionary.class]) {
			value = self[kFxParameterProperty_Default][kFxParameterProperty_Y];
		} else if ([self[kFxParameterProperty_Default] isKindOfClass:NSArray.class]) {
			defaultValues = self[kFxParameterProperty_Default];
		} else if ([self[kFxParameterProperty_Default] isKindOfClass:NSString.class]) {
			NSString *str = self[kFxParameterProperty_Default];
			defaultValues = [str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		}
		if (defaultValues && defaultValues.count >= 2) {
			value = defaultValues[1];
		}
	}
	if (!value) {
		value = @0.0;
	} else if ([value isKindOfClass:NSString.class]) {
		value= @(((NSString*)value).doubleValue);
	}
	return value;
}

- (NSArray<NSString*>*_Nullable)parameterMenuItems
{
	isParameterDictionary(nil);
	NSArray* items =  self[kFxParameterProperty_MenuItems];
	
	FxParameterType  type = self.parameterType;
	if (!items && (type == FxParameterType_Menu || type == FxParameterType_Capsule))
		return @[];
		
	return items;
}

-(NSNumber*_Nullable)parameterGradientSamples
{
	return self[kFxParameterProperty_GradientSamples];
}

/*!
	@method		parameterGradientDepth
	@abstract	The gradient sample depth as an FxDepth.
	@discussion	Introduced in FxGrip 0.1.0. A number is read as an FxDepth or a byte count per the
				depth type. A string maps "uchar", "float", and otherwise "half". The default is
				kFxDepth_FLOAT16 when no depth is present.
	@default	kFxDepth_FLOAT16
 */
-(FxDepth)parameterGradientDepth
{
	id		gradientDepthField = self[kFxParameterProperty_GradientDepth];
	int		depthValue = kFxDepth_FLOAT16;
	
	// If none, default to FLOAT16
	if (!gradientDepthField) {
		return depthValue;
	}
	
	//If there is a type, get the type as int, or "bytes"[int: 2] or "fxdepth"[int: 1] (default)
	FxGripDepthType		depthType = self.parameterGradientDepthType;
	
	if([gradientDepthField isKindOfClass:[NSNumber class]]) {
		// fxdepth: 0 = 8bit char, 2 = float16, 3 = float32
		// or
		// byte depth: 1 for 1 byte uchar, 2 for 2 byte float, and 4 for 4 byte float
		depthValue = [gradientDepthField intValue];
			
	} else if([gradientDepthField isKindOfClass:[NSString class]]) {
		NSString *strValue = (NSString*)gradientDepthField;
		// if "uchar"
		if(NSOrderedSame == [strValue compare:kFxParameterProperty_GradientDepth_UInt8]) {
			depthValue = kFxDepth_UINT8;
		} else if(NSOrderedSame == [strValue compare:kFxParameterProperty_GradientDepth_float32]) {
			// or "float" for 32 bit float
			depthValue = kFxDepth_FLOAT32;
		} else {
			// else "half" for 16 bit float
			depthValue = kFxDepth_FLOAT16;
		}
		depthType = FxGripDepthTypeFxDepth;
	}
	
	// If conversion from bytes to fxdepth is needed, do it here
	if (depthType == FxGripDepthTypeBytes) {
		switch (depthValue) {
			case 1://  1 byte
				depthValue = kFxDepth_UINT8;
				break;
			case 2:	// 2 bytes
				depthValue = kFxDepth_FLOAT16;
				break;
			case 4:	// 4 bytes
				depthValue = kFxDepth_FLOAT32;
				break;
		}
		depthType = FxGripDepthTypeFxDepth;
	}
	
	return depthValue;
}

/*! @abstract The gradient depth interpretation: FxDepth or a byte count; None when absent. */
- (FxGripDepthType)parameterGradientDepthType
{
	id depthType = self[kFxParameterProperty_GradientDepthType];
	
	FxGripDepthType type = FxGripDepthTypeNone;
	
	if (!depthType) {
		return type;
	}
	
	if([depthType isKindOfClass:[NSNumber class]]) {
		// Signed intermediate: the enum is unsigned, so comparing it below None is dead.
		int rawType = [depthType intValue];
		if (rawType < FxGripDepthTypeNone) {
			type = FxGripDepthTypeNone;
		} else if (rawType > FxGripDepthTypeBytes) {
			type = FxGripDepthTypeFxDepth;
		} else {
			type = rawType;
		}
	} else if([depthType isKindOfClass:[NSString class]]) {
		// if "bytes"
		if(NSOrderedSame == [depthType compare:kFxParameterProperty_GradientDepthType_Bytes]) {
			return FxGripDepthTypeBytes;
		} else if(NSOrderedSame == [depthType compare:kFxParameterProperty_GradientDepthType_FxDepth]) {
			return FxGripDepthTypeFxDepth;
		} else {
			return FxGripDepthTypeFxDepth;
		}
	}
	return type;
}

@end




/*!
	@abstract	Writes the common parameter keys back into a configuration.
	@discussion	Introduced in FxGrip 0.1.0. Each setter stores its value as a number.
*/
@implementation NSMutableDictionary (FxGripTileableEffect)


- (void)setParameterType:(FxParameterType)type
{
	self[kFxParameterProperty_Type] = @(type);
}

- (void)setParameterID:(FxParameterId)parameterID
{
	self[kFxParameterProperty_Id] = @(parameterID);
}

- (void)setParameterParentID:(FxParameterId)parentID
{
	self[kFxParameterProperty_ParentId] = @(parentID);
}

- (void)setParameterFlags:(FxParameterFlags)parameterFlags
{
	self[kFxParameterProperty_Flags] = @(parameterFlags);
}

@end

