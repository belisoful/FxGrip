/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  GuruFxTileableEffect.m
//  GuruFxTileableEffect
//
//  Created by ~ ~ on 11/24/24.
//
/*
 
 This loads, stores, and provides access to extensions
 
 */

#import <objc/runtime.h>
//#import "GuruFxExtension.h"
#import "GuruFxTileableEffect+Extensions.h"
#import "FxTileableEffectBase.h"
#import "GuruFxTileableEffect+Parameters.h"
#import "NSPriorityNotificationCenter.h"
#import "FxParameter.h"

//Extensions
#import "GuruFxParameterData.h"
#import "GuruFxI18N.h"
#if DEBUG
	#import "GuruFxRegression.h"
#endif

static void *extensionKey = &extensionKey;


@implementation GuruFxTileableEffect (Extensions)

- (UInt32)extensionCount
{
	return (uint)self.extensions.count;
}


-(NSArray<id<GuruFxExtensionProtocol>>* _Nonnull) extensions
{
	NSArray* arr = (NSArray<id<GuruFxExtensionProtocol>>*)objc_getAssociatedObject(self, extensionKey);
	if(!arr) {
		arr = @[];
	}
	return arr;
}

-(void) setExtensions:(NSArray<id<GuruFxExtensionProtocol>>* _Nonnull) extensions
{
	objc_setAssociatedObject(self, extensionKey, extensions, OBJC_ASSOCIATION_RETAIN);
}



//---------------------------------------------------------
// loadExtensions
//
// This loads any extensions
//---------------------------------------------------------

// Subclasses should overload this method to load other extensions.
-(NSMutableArray<id<GuruFxExtensionProtocol>>* _Nonnull) loadExtensions
{
	NSMutableArray *extensions = [NSMutableArray new];
	
	id<GuruFxExtensionProtocol> ext;
	/*if (self.isTrackingInstances) {
		ext = self.newInstanceTrackerExtension;
		if (ext) {
			[extensions addObject:ext];
		}
	}*/
	
	//	Internationalization of parameter names, menu items, and string values
	if (self.isInternationalized) {
		ext = self.newI18NExtension;
		if (ext) {
			[extensions addObject:ext];
		}
	}
	
	//Parameter Data
	ext = self.newParameterDataExtension;
	if (ext) {
		[extensions addObject:ext];
	}
	
	//google analytics
	//fxfactory
	//debug menu
	//about menu
	
	
	// A GuruFxTileableEffect subclass having the protocol is an easy way
	// to plug into GuruFx without having to implement standard [Guru]FxTileableEffect
	// methods and calling the super (where needed).
	if ([self conformsToProtocol:@protocol(GuruFxExtensionProtocol)]) {
		[extensions addObject:self];
	}
	
#if DEBUG
	//ext = self.newRegressionExtension;
	//if (ext) {
		//[extensions addObject:ext];
	//}
#endif
	
	return extensions;
}
/*
-(id<GuruFxExtensionProtocol>) newAboutMenu
{
	return [GuruFxAboutMenu.alloc init];
}
 -(id<GuruFxExtensionProtocol>) newDebugMenu
 {
	 return [GuruFxDebugMenu.alloc init];
 }
 */

- (id<FxExtension>)newInstanceTrackerExtension
{
	return nil;//[GuruFxInstanceTracker.alloc init];
}




// Called in the FxTileableEffect::init
- (void)extensionsInit
{
	NSMutableArray<id<GuruFxExtensionProtocol>> *ext = [self loadExtensions];
	
	//Sort by priority.
	[ext sortUsingComparator:^NSComparisonResult(id<GuruFxExtensionProtocol> a, id<GuruFxExtensionProtocol> b) {
		return [a ncPriority:kExtensionsLoadName] - [b ncPriority:kExtensionsLoadName];
		}];
	
	[ext filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id<GuruFxExtensionProtocol> object, NSDictionary *bindings) {
		if (![object respondsToSelector:@selector(extLoadWithEffect:)]) {
			return YES;
		}
		return [object extLoadWithEffect:self];
 }]];
	
	//save the extensions in an immutable array
	[self setExtensions:[ext copy]];
	
	// post Init Notification
	[self.notifier postNotificationName:kExtensionsInitName object:self];
}




// Called in the FxTileableEffect::initialParametersList
//
-(void) extensionsProcessParameters:(NSMutableArray<NSMutableDictionary*>*_Nonnull)parameters
{
	NSMutableDictionary *userInfo = @{kExtensionsParameter0Name:parameters,
									  kExtensionsParametersValueName:parameters}.mutableCopy;
	[self.notifier postNotificationName:kExtensionsProcessParametersName object:self userInfo:userInfo
							  postBlock:^(NSNotification * _Nonnull notification) {
		
		NSMutableDictionary *userInfo = (NSMutableDictionary*)notification.userInfo;
		[GuruFxParameterConverter flattenDictionaryParameters:userInfo[kExtensionsParametersValueName]];
	}];
}

// called when adding a parameter to the plugin, within the API call, and after
//	the parameter is created.
- (BOOL)extensionsAddParameter:(nonnull id<GuruFxParameterProtocol>)parameter
{
	NSMutableDictionary *results = @{kExtensionsReturnValueName: @(YES),
									 kExtensionsParameter0Name:parameter,
									 kExtensionsParameterValueName: parameter}.mutableCopy;
	[self.notifier postNotificationName:kExtensionsAddParameterName object:self userInfo:results];
	return results[kExtensionsReturnValueName];
}



// Called in the FxTileableEffect::dealloc
// ordered by priority.
-(BOOL) extensionsFinishInitialSetup
{
	NSMutableDictionary *results = @{kExtensionsReturnValueName: @(YES)}.mutableCopy;
	[self.notifier postNotificationName:kExtensionsFinishInitialSetupName object:self userInfo:results];
	return ((NSNumber*)results[kExtensionsReturnValueName]).boolValue;
}


// Called in the FxTileableEffect::dealloc
// ordered by priority.
-(void) extensionsAddedToDocument
{
	[self.notifier postNotificationName:kExtensionsAddedToDocumentName object:self];
}




// Called in the FxTileableEffect::dealloc
// ordered by priority.
- (FxParameterType)extensionsGetParameterType:(FxParameterId)parameterID
{
	NSMutableDictionary *results = @{kExtensionsReturnValueName: @(FxParameterType_None),
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsGetParameterTypeName object:self userInfo:results];
	
	return ((NSNumber*)results[kExtensionsReturnValueName]).intValue;
}


// Called in the FxTileableEffect::dealloc
// ordered by priority.
- (BOOL)extensionsGetParameterFlags:(FxParameterFlags*_Nonnull)flags fromParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *results = @{kExtensionsReturnValueName: @(YES),
									 kExtensionsParameterFlagsName: @(*flags),
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsParameterGetFlagsName object:self userInfo:results];
	
	*flags = ((NSNumber*)results[kExtensionsReturnValueName]).unsignedIntValue;
	return ((NSNumber*)results[kExtensionsReturnValueName]).boolValue;
}

// Called in the FxTileableEffect::dealloc
// ordered by priority.
- (void)extensionsSetParameterFlagsPre:(FxParameterFlags*_Nonnull)flags toParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *results = @{kExtensionsParameterFlagsName: @(*flags),
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsParameterSetFlagsPreName object:self userInfo:results];
	
	*flags = ((NSNumber*)results[kExtensionsReturnValueName]).unsignedIntValue;
}

// Called in the FxTileableEffect::dealloc
// ordered by priority.
- (void)extensionsSetParameterFlags:(FxParameterFlags)flags toParameter:(FxParameterId)parameterID
{
	id<GuruFxParameterProtocol> parameter = self.effect[parameterID];
	if (!parameter) {
		NSLog(@"Error: setParameterFlags did not find the parameter to set the");
		return;
	}
	// The changes were Saved, so no need to flag it as changed.
	[parameter setParameterFlags:flags];
	
	NSMutableDictionary *results = @{kExtensionsParameterFlagsName: @(flags),
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsParameterSetFlagsName object:self userInfo:results];
}




// Called in the FxTileableEffect::dealloc
// ordered by priority.
- (NSError*_Nullable)extensionsGetParameterName:(NSString*_Nonnull*_Nonnull)name  fromParameter:(UInt32)parameterID
{
	NSMutableDictionary *results = @{kExtensionsParameter0Name: *name,
									 kExtensionsErrorName: [NSNull null],
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsGetParameterNameName object:self userInfo:results];
	
	*name = results[kExtensionsParameter0Name];
	if (*name == (NSString*)[NSNull null]) {
		*name = NULL;
	}
	
	if (results[kExtensionsErrorName] && results[kExtensionsErrorName] != [NSNull null]) {
		return results[kExtensionsErrorName];
	}
	return NULL;
}

// Called in the FxTileableEffect::dealloc
// ordered by priority.
- (void)extensionsSetParameterNamePre:(NSString*_Nonnull*_Nonnull)name  toParameter:(UInt32)parameterID
{
	NSMutableDictionary *results = @{kExtensionsParameter0Name: *name,
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsSetParameterNamePreName object:self userInfo:results];
	
	*name = results[kExtensionsParameter0Name];
}

// Called in the FxTileableEffect::dealloc
// ordered by priority.
- (void)extensionsSetParameterName:(NSString*_Nonnull)name  toParameter:(UInt32)parameterID
{
	NSMutableDictionary *results = @{kExtensionsParameter0Name: name,
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsSetParameterNameName object:self userInfo:results];
}


- (NSError*_Nullable)extensionsGetParameterStringValue:(NSString*_Nonnull*_Nonnull)value  fromParameter:(UInt32)parameterID
{
	NSMutableDictionary *results = @{kExtensionsParameter0Name: *value,
									 kExtensionsErrorName: [NSNull null],
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsGetParameterStringValueName object:self userInfo:results];
	
	*value = results[kExtensionsParameter0Name];
	if (*value == (NSString*)[NSNull null]) {
		*value = NULL;
	}
	
	if (results[kExtensionsErrorName] && results[kExtensionsErrorName] != [NSNull null]) {
		return results[kExtensionsErrorName];
	}
	return NULL;
}

// Called in the FxTileableEffect::dealloc
// ordered by priority.
- (void)extensionsSetParameterStringValuePre:(NSString*_Nonnull*_Nonnull)value  toParameter:(UInt32)parameterID
{
	NSMutableDictionary *results = @{kExtensionsParameter0Name: *value,
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsSetParameterStringValuePreName object:self userInfo:results];
	
	*value = results[kExtensionsParameter0Name];
}





- (NSError*_Nullable)extensionsGetParameterMenu:(NSArray<NSString*>*_Nullable*_Nonnull)entries fromParameter:(FxParameterId)parameterID
{
	if (!*entries) {
		*entries = (NSArray*)[NSNull null];
	}
	NSMutableDictionary *results = @{kExtensionsParameter0Name: *entries,
									 kExtensionsErrorName: [NSNull null],
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsSetParameterMenuName object:self userInfo:results];
	
	*entries = results[kExtensionsParameter0Name];
	if (*entries == (NSArray*)[NSNull null]) {
		*entries = NULL;
	}
	if (results[kExtensionsErrorName] && results[kExtensionsErrorName] != [NSNull null]) {
		return results[kExtensionsErrorName];
	}
	return NULL;
}


// Called in the FxTileableEffect::dealloc
// ordered by priority.
- (void)extensionsSetParameterMenuItemPre:(NSString*_Nonnull*_Nonnull)name  toParameter:(UInt32)parameterID
{
	NSMutableDictionary *results = @{kExtensionsParameter0Name: *name,
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsSetParameterMenuItemPreName object:self userInfo:results];
	
	*name = results[kExtensionsParameter0Name];
}

- (void)extensionsSetParameterMenu:(NSArray<NSString*>*_Nonnull)newEntries defaultValue:(UInt32)defaultIndex toParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *results = @{kExtensionsMenuEntriesName: newEntries,
									 kExtensionsDefaultName: @(defaultIndex),
									 kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsSetParameterMenuName object:self userInfo:results];
}


- (void)extensionsParameterChanged:(FxParameterId)paramID
							atTime:(CMTime)time
							 error:(NSError * _Nullable * _Nullable)error
{
	NSMutableDictionary *userInfo = @{
			kExtensionsParameterIDName: @(paramID),
			kExtensionsAtTimeName: (__bridge NSDictionary *)CMTimeCopyAsDictionary(time, NULL),
			kExtensionsErrorName: [NSNull null]
		}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsParameterChangedName object:self userInfo:userInfo];
	
	NSError *err = nil;
	if (userInfo[kExtensionsErrorName]) {
		NSError *err = userInfo[kExtensionsErrorName];
		if (err == (NSError*)[NSNull null]) {
			err = NULL;
		}
	}
	*error = err;
}

- (void)extensionsFlush
{
	for (id<GuruFxParameterProtocol> parameter in _parameters.allValues) {
		[parameter parameterFlush];
	}
	[self.notifier postNotificationName:kExtensionsFlushName object:self reverse:YES];
}


- (BOOL)extensionsRender:(FxImageTile *_Nonnull)destinationImage
			sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
			 pluginState:(id _Nullable)pluginState
				  atTime:(CMTime)renderTime
				   error:(NSError *_Nullable *_Nullable)outError
{
	NSMutableDictionary *userInfo = @{
			kExtensionsParameter0Name: destinationImage,
			kExtensionsParameter1Name: sourceImages,
			kExtensionsParameter2Name: pluginState,
			kExtensionsAtTimeName: (__bridge NSDictionary *)CMTimeCopyAsDictionary(renderTime, NULL),
			kExtensionsErrorName: [NSNull null],
			kExtensionsReturnValueName: @YES
		}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsRenderDestinationImageName object:self userInfo:userInfo];
	
	NSError *err = nil;
	if (userInfo[kExtensionsErrorName]) {
		NSError *err = userInfo[kExtensionsErrorName];
		if (err == (NSError*)[NSNull null]) {
			err = NULL;
		}
	}
	*outError = err;
	return ((NSNumber*)userInfo[kExtensionsReturnValueName]).boolValue;
}


- (void)extensionsRemoveParameter:(FxParameterId)parameterID
{
	NSMutableDictionary *results = @{kExtensionsParameterIDName: @(parameterID)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsRemoveParameterName object:self userInfo:results];
}



// Called in the FxTileableEffect::dealloc
// ordered by reverse priority.
-(void) extensionsRemovedFromDocument
{
	[self.notifier postNotificationName:kExtensionsRemovedFromDocumentName object:self reverse:YES];
}

// Called in the FxTileableEffect::dealloc
// ordered by reverse priority.
-(void) extensionsUnload
{
	[self.notifier postNotificationName:kExtensionsUnloadName object:self reverse:YES];
	objc_setAssociatedObject(self, extensionKey, nil, OBJC_ASSOCIATION_ASSIGN);
}



- (FxParameterType)extensionParameterTypeForString:(nullable NSString *)typeString
{
	NSMutableDictionary *results = @{kExtensionsParameter0Name: typeString}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsParameterTypeForStringName object:self userInfo:results];
	
	NSNumber *result = results[kExtensionsParameter0Name];
	if (!result || result == (NSNumber*)[NSNull null] || ![result isKindOfClass:NSNumber.class]) {
		return FxParameterType_None;
	}
	return result.intValue;
}


- (nullable Class)extensionParameterClassForType:(FxParameterType)type
{
	NSMutableDictionary *results = @{kExtensionsParameter0Name: @(type)}.mutableCopy;
	
	[self.notifier postNotificationName:kExtensionsParameterClassForTypeName object:self userInfo:results];
	
	Class result = results[kExtensionsReturnValueName];
	if (!result || result == (Class)[NSNull null]) {
		return NULL;
	}
	return result;
}





#pragma mark -
#pragma mark Plugin Extensions Getters

- (BOOL)hasExtensionProtocol:(nullable Protocol *)extensionProtocol
{
	for (id element in self.extensions) {
		if ([element conformsToProtocol:extensionProtocol]) {
			return YES;
		}
	}
	return NO;
}

- (BOOL)hasExtensionClass:(Class _Nullable)extensionClass
{
	for (id element in self.extensions) {
		if ([element isKindOfClass:extensionClass]) {
			return YES;
		}
	}
	return NO;
}

- (BOOL)hasExtensionKey:(NSString*_Nullable)extensionKey
{
	for (id<GuruFxExtensionProtocol> element in self.extensions) {
		if ([element.extKey isEqualToString:extensionKey]) {
			return YES;
		}
	}
	return NO;
}



-(id<GuruFxExtensionProtocol>_Nullable) extensionForProtocol:(nullable Protocol *)extensionProtocol
{
	if (!extensionProtocol)
		return nil;
	
	for (id element in self.extensions) {
		if ([element conformsToProtocol:extensionProtocol]) {
			return element;
		}
	}
	return nil;
}

-(id<GuruFxExtensionProtocol>_Nullable) extensionForClass:(Class _Nullable)extensionClass
{
	if (!extensionClass)
		return nil;
	
	for (id element in self.extensions) {
		if ([element isKindOfClass:extensionClass]) {
			return element;
		}
	}
	return nil;
}

-(id<GuruFxExtensionProtocol>_Nullable) extensionForKey:(NSString*_Nullable)extensionKey
{
	if (!extensionKey)
		return nil;
	
	for (id<GuruFxExtensionProtocol> element in self.extensions) {
		if ([element.extKey compare:extensionKey] == NSOrderedSame) {
			return element;
		}
	}
	return nil;
}



// In the case of multiple extensions with the same name, maybe with different settings on each one.
-(NSArray<id<GuruFxExtensionProtocol>>* _Nonnull) extensionsForProtocol:(nullable Protocol *)extensionProtocol
{
	if (!extensionProtocol)
		return @[];
	
	NSMutableArray *results = [NSMutableArray.alloc init];
	for (id element in self.extensions) {
		if ([element conformsToProtocol:extensionProtocol]) {
			[results addObject:element];
		}
	}
	return [results copy];
}

-(NSArray<id<GuruFxExtensionProtocol>>* _Nonnull) extensionsForClass:(Class _Nullable)extensionClass
{
	if (!extensionClass)
		return @[];
	
	NSMutableArray *results = [NSMutableArray.alloc init];
	for (id element in self.extensions) {
		if ([element isKindOfClass:extensionClass]) {
			[results addObject:element];
		}
	}
	return [results copy];
}

-(NSArray<id<GuruFxExtensionProtocol>>* _Nonnull) extensionsForKey:(NSString*_Nullable)extensionKey
{
	if (!extensionKey)
		return nil;
	
	NSMutableArray *results = [NSMutableArray.alloc init];
	for (id<GuruFxExtensionProtocol> element in self.extensions) {
		if ([element.extKey compare:extensionKey] == NSOrderedSame) {
			[results addObject:element];
		}
	}
	return [results copy];
}

@end


#pragma mark -
#pragma mark GuruFxTileableEffect <GuruFxExtension>

// this is when the GuruFxTileableEffect is itself an extension, so subclasses can do this
@implementation GuruFxTileableEffect (GuruFxExtension)


- (GuruFxTileableEffect*_Nonnull)effect
{
	return self;
}

#define kExtensionSkipEffect YES
#include "GuruFxExtensionLibrary.m"

@end
