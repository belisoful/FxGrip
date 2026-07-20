/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  GuruFxTileableEffect.m
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/27/24.
//  Copyright © 2024 Belisoful All rights reserved.
//
/*
 Todo:
 - parameter 9998: Plugin Data - holds the plugin metadata for each instance.
 	-has instance guid (initial to plugin guid, gets changed if the same)
 	-has last updated time flag
 - effect metadata - saved when has media directory
 	-has effect guid

 - capture FxParameterCreationAPI_v5 to save parameter types into instance meta data
 - FxParameterRetrievalAPI_v6 has getParameterFlags passthrough to FlagsCache
 - FxParameterSettingAPI_v5 has setParameters flag passthrough to FlagsCache
 - FxParameterSettingAPI_v6 as Flags Cache, add remove passthrough to flagscache
 - FxDynamicParameterAPI_v3 removeParameter capture
 
 
 Call Stack
 • FxPrincipalDelegate::didEstablishConnectionWithHost:(NSString *)hostBundleIdentifier
								version:(NSString *)hostVersion
 •
 
 
 */
#include <objc/message.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <IOSurface/IOSurfaceObjC.h>

#import "NSString+BExtension.h"
#import "NSDictionary+BExtension.h"
#import "NSArray+BExtension.h"
#import "NSSet+BExtension.h"
#import "NSDictionary+FxTileableEffect.h"
#import "NSCoder+AtIndex.h"
#import "NSCoder+FxPlug.h"

#import "GuruFxAPIAccessing.h"
#import "GuruFxTileableEffect.h"
#import "GuruFxTileableEffect+Extensions.h"
#import "GuruFxTileableEffect+Parameters.h"
#import "GuruFxPluginInfo.h"
#import "GuruFxMTLDeviceCache.h"
#import "GuruFxDynamicParameterAPI_v4.h"
#import "GuruFxPresetsAPI_v1.h"
#import "GuruFxInterpolatingDictionary.h"

#import "GuruFxParameters/Common/GuruFxImageRefParameter.h"
#import "GuruFxParameters/Common/GuruFxCustomParameter.h"

#import "FXBox.h"
#import "GuruFxDividerData.h"
#import "NSCoder+AtIndex.h"
#import <BFoundationExtension/BEMutable.h>
#import "GuruFx_ARC.h"

FxQuality x;

@implementation GuruFxTileableEffect
{
	//NSMutableDictionary<NSNumber*, NSMutableDictionary*> *_params;
	NSNumber			*__isGenerator, *__isFilter;

	//NSLock				*mPluginDataLock;
	//NSMutableDictionary *mParametersFlags;
}

@synthesize addedToDocument = _addedToDocument;
@synthesize meta = _meta;

@synthesize needsFullBuffer = _needsFullBuffer;
@synthesize variesWhenParamsAreStatic = _variesWhenParamsAreStatic;
@synthesize changesOutputSize = _changesOutputSize;

@synthesize mayRemapTime = _mayRemapTime;
@synthesize usesNonmatchingTextureLayout = _usesNonmatchingTextureLayout;
@synthesize drawsInScreenSpace = _drawsInScreenSpace;

@synthesize desiredProcessingColorInfo = _desiredProcessingColorInfo;
@synthesize pixelTransformSupport = _pixelTransformSupport;

// Are RGB and RGBA parameters doing color in sRGB or Linear?
// Set in -properties to the host, cannot change
@synthesize isGammaColorParameters;	// color info is sRGB
@synthesize isLinearColorParameters;	// color info is Linear

@synthesize colorPrimaries;
@synthesize isHDRProject;
@synthesize issRGBProject;

@synthesize isGenerator;
@synthesize isFilter;

@synthesize properties = _properties;
@synthesize initialParametersList = _initialParametersList;
@synthesize parametersFile = _parametersFile;
@synthesize initialParameters = _initialParameters;


@synthesize uuid = _uuid;
@synthesize priorUuids = _priorUuids;
@synthesize displayName = _displayName;
@synthesize groupUuid = _groupUuid;
@synthesize infoString = _infoString;
@synthesize defaultFontName = _defaultFontName;
@synthesize protocolNames = _protocolNames;
@synthesize hasDebugMenu = _hasDebugMenu;
@synthesize hasDebugActivator = _hasDebugActivator;
@synthesize hasMeta = _hasMeta;

//As its own GuruFxExtension
@synthesize extActive = _extActive;
@synthesize extDefaultPriority = _extDefaultPriority;


#pragma mark -
#pragma mark FxTileableEffect Implementation


//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	self = [super init];
	
	if (self != nil)
	{
		_addedToDocument = NO;
		
		//_apiManager = [GuruFxAPIAccessing.alloc initWithAPIManager:apiManager effect:self];
		_extActive = YES;
		
		//mPluginDataLock = [[NSLock alloc] init];
		//mPluginDataLock.name = @"Plugin Data Lock";
		
		//Preset Properties to default values.
		_needsFullBuffer = NO;
		_variesWhenParamsAreStatic = NO;
		_changesOutputSize = YES;
		_mayRemapTime = YES;
		_usesNonmatchingTextureLayout = NO;
		_drawsInScreenSpace = NO;
		_desiredProcessingColorInfo = kFxImageColorInfo_RGB_LINEAR;
		_pixelTransformSupport = kFxPixelTransform_Scale;
		
		parameterViews = [NSMutableDictionary dictionaryWithCapacity:13];
		_parameters = [NSMutableDictionary dictionary];
		_notifier = [NSPriorityNotificationCenter.alloc init];
		
		[self extensionsInit];
		
		DebugLog(_apiManager.sessionID, @">>");
	}
	return self;
}


- (void)dealloc
{
	if (_addedToDocument) {
		[self extensionsRemovedFromDocument];
		_addedToDocument = NO;
	}
	[self extensionsUnload];
	
	if (_displayName) {
		_displayName = nil;
	}
	if (_groupUuid) {
		_groupUuid = nil;
	}
	if (_infoString) {
		_infoString = nil;
	}
	_subgroupStack = nil;
	_parameters = nil;
	
	
	if (_apiManager) {
		NARC_RELEASE(_apiManager);
	}
	_notifier = nil;
	
	SUPER_DEALLOC();
}



//---------------------------------------------------------
// addParametersWithError
//
// This method is where a plug-in defines its list of parameters.
// Only called in Motion when adding the FxPlug to a document
//---------------------------------------------------------

- (BOOL)addParametersWithError:(NSError**)error
{
	DebugLog(_apiManager.sessionID, @">>");

	// @todo apply the customized data before.
	BOOL success =  [self generateParameters:self.initialParametersList error:error];
	
	for(id<FxParameter> p in _parameters) {
		if ([p respondsToSelector:@selector(validate)]) {
			success = [p validate] && success;
		}
	}
	
	[self extensionsFlush];
	
	DebugLog2(_apiManager.sessionID, @"<<", success ? @"success" : @"failed");
	return success;
}


// Called when getting custom data from a parameter 
- (NSSet<Class> *)classesForCustomParameterID:(FxParameterId)parameterID
{
	DebugLog(_apiManager.sessionID, @">>");
#if DEBUG
	NSLog(@" --- Parameter ID %d", parameterID);
#endif
	/*id<FxCustomParameter> parameter = (id<GuruFxCustomParameterProtocol>)self[parameterID];
	
	if (!parameter || ![parameter conformsToProtocol:@protocol(GuruFxCustomParameterProtocol)]) {
		return NSSet.new;
	}*/
	return nil;
	//return parameter.dataClasses;
	
	/*
	// We can't get Meta Custom Classes from the meta because it's in the meta, recursive
	if (parameterID == kFxParameterId_InstanceMeta) {
		NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithObject:[GuruFxMetaManager class]];
		[set unionOrderedSet:[GuruFxMetaManager classesForParameter]];
		return set.set;
	}
	
	// Return classes from metadata
	if (0 && self.hasMeta) {
		// Processed
		NSDictionary *paramData = [self.meta parameterData:parameterID];
		if (paramData) {
			// This is a NSSet<NSString*> of className
			return paramData.parameterCustomClasses.toClassesFromStrings;
		}
		NSLog(@"ERROR - No Meta Parameter Data for %d", parameterID);
		return nil;
	}
	
	// If not in metadata or no metadata
	//	get the custom classes from the initialParameters
	NSMutableArray<NSString*> *plistCustomClasses = [self initialValueForKey:kFxParameterProperty_CustomClasses fromParameter:parameterID];
	if (!plistCustomClasses) {
		plistCustomClasses = [NSMutableArray array];
	} else if ([plistCustomClasses isKindOfClass:[NSString class]]) {
		plistCustomClasses = [NSMutableArray arrayWithArray:[(NSString*)plistCustomClasses splitByHumanDividers]];
	} else if ([plistCustomClasses isKindOfClass:[NSSet class]]) {
		plistCustomClasses = [NSMutableArray arrayWithArray:((NSSet*)plistCustomClasses).allObjects];
	} else if ([plistCustomClasses isKindOfClass:[NSArray class]]) {
		plistCustomClasses = [plistCustomClasses mutableCopy];
	}
	
	for (NSString *part in plistCustomClasses) {
		Class partClass = NSClassFromString(part);
		if (!partClass) {
			NSLog(@"ERROR - Could not find custom classes \"%@\" from the InitialParameters Id %d" , part, parameterID);
			[plistCustomClasses removeObject:part];
		}
	}
	
	
	NSMutableOrderedSet<Class> *customClasses = [NSMutableOrderedSet orderedSetWithCapacity:plistCustomClasses.count + 1 + 13];
	NSString *customClassStr = [self initialValueForKey:kFxParameterProperty_CustomClass fromParameter:parameterID];
	if (!customClassStr) {
		id defaultValue = [self initialValueForKey:kFxParameterProperty_Default fromParameter:parameterID];
		if (defaultValue) {
			if ([defaultValue isMemberOfClass:[NSDictionary class]]) {
				customClassStr = [GuruFxInterpolatingDictionary className];
			} else {
				customClassStr = [defaultValue className];
			}
		} else {
			customClassStr = @"";
		}
	}
	Class customClass = NSClassFromString(customClassStr);
	if (customClass) {
		[customClasses addObject:customClass];
		if ([customClass conformsToProtocol:@protocol(FxCustomDataClasses)]) {
			[customClasses addObjectsFromArray:[customClass classesForParameter].array];
		}
	} else {
		NSLog(@"ERROR - Could not find custom class \"%@\" from the InitialParameters Id %d" , customClassStr, parameterID);
	}
	[customClasses addObjectsFromArray:plistCustomClasses.toClassesFromStrings];
	return customClasses.set;*/
}


- (NSView *)createViewForParameterID:(UInt32)parameterID
{
	DebugLog(_apiManager.sessionID, @">>");
#if DEBUG
	NSLog(@" --- Parameter ID %d", parameterID);
#endif
	
	// NSView *view =  self[parameterID].view;
	// view.parameterId = parameterID;
	// return view;
	
	return nil;
	/*
	NSDictionary *paramData;
	if (0 && self.hasMeta) {
		paramData = [self.meta parameterData:parameterID];
	} else {
		paramData = [self initialParameter:parameterID];
	}
	FxParameterType type = paramData.parameterType;
	NSView *paramView = nil, *returnView = nil;
	if (type == FxParameterType_Switch) {
		NSSwitch *switchView = [NSSwitch.alloc initWithFrame:NSMakeRect(0, 0, 80, 24)];
		switchView.controlSize = NSControlSizeMini;
		switchView.tag = parameterID;
		// Todo right align.
		switchView.layerContentsPlacement = NSViewLayerContentsPlacementRight;
		
		returnView = paramView = switchView;
	} else if (type == FxParameterType_Divider) {
		FXBox *dividerView = [FXBox.alloc initWithFrame:NSMakeRect(0, 22, 100, 1)];
		paramView = dividerView;
		returnView = dividerView.topView;
	}
	
	if (paramView != nil)
		parameterViews[@(parameterID)] = paramView;
	
	return returnView;*/
}


//---------------------------------------------------------
// properties
//
// This method should return an NSDictionary defining the
//  properties of the effect.
// This reads the kProPlugPlugIn_EffectPropertiesProperty
//  from the plugin effect from Info.plist (@"effectProperties").
// If a subclass overrides this method, call [super properties:properties error:error]
//  to grab the Info.plist plugin "effectProperties".
// Subclasses can pass its own Properties, eg [super properties:@{@"ChangesOutputSize":@NO} error:error]
//  And it will set the effect variables in the class, eg _changesOutputSize.
// Subclasses can also set the various property properties, like _changesOutputSize, and
//  this method will generate the required NSDictionary output.
//
// First, the effect properties are set from the Info.plist.
// If *properties, then those override Info.plist effect properties.
// Any missing properties are set from the values of the plugin, 
//---------------------------------------------------------

- (BOOL)properties:(NSDictionary * _Nonnull *)properties
             error:(NSError * _Nullable *)error
{
	DebugLog(_apiManager.sessionID, @">>");
	
	NSUInteger initCount = (*properties) ? [*properties count] : 10;
	
	NSMutableDictionary *props = NARC_AUTORELEASE([NSMutableDictionary.alloc initWithCapacity:initCount]);
	
	NSDictionary *effectProperties = self.properties.pluginEffectProperties;
	
	if (effectProperties) {
		[props addEntriesFromDictionary:effectProperties];
		effectProperties = nil;
	}
	
	if (*properties) {
		[props addEntriesFromDictionary:*properties];
	}
	
	// If there property isn't there, add it.
	NSNumber *value = [props objectForKey:kFxPropertyKey_NeedsFullBuffer];
	if (value != nil) {
		_needsFullBuffer = [value boolValue];
	} else if (_needsFullBuffer) {
		[props setObject:[NSNumber numberWithBool:_needsFullBuffer] forKey:kFxPropertyKey_NeedsFullBuffer];
	}
	
	value = [props objectForKey:kFxPropertyKey_VariesWhenParamsAreStatic];
	if (value != nil) {
		_variesWhenParamsAreStatic = [value boolValue];
	} else if (_variesWhenParamsAreStatic) {
		[props setObject:[NSNumber numberWithBool:_variesWhenParamsAreStatic] forKey:kFxPropertyKey_VariesWhenParamsAreStatic];
	}
	
	value = [props objectForKey:kFxPropertyKey_ChangesOutputSize];
	if (value != nil) {
		_changesOutputSize = [value boolValue];
	} else if (!_changesOutputSize) {
		[props setObject:[NSNumber numberWithBool:_changesOutputSize] forKey:kFxPropertyKey_ChangesOutputSize];
	}
	
	
	value = [props objectForKey:kFxPropertyKey_MayRemapTime];
	if (value != nil) {
		_mayRemapTime = [value boolValue];
	} else if (!_mayRemapTime) {
		[props setObject:[NSNumber numberWithBool:_mayRemapTime] forKey:kFxPropertyKey_MayRemapTime];
	}
	
	value = [props objectForKey:kFxPropertyKey_UsesNonmatchingTextureLayout];
	if (value != nil) {
		_usesNonmatchingTextureLayout = [value boolValue];
	} else if (_usesNonmatchingTextureLayout) {
		[props setObject:[NSNumber numberWithBool:_usesNonmatchingTextureLayout] forKey:kFxPropertyKey_UsesNonmatchingTextureLayout];
	}
	
	value = [props objectForKey:kFxPropertyKey_DrawsInScreenSpace];
	if (value != nil) {
		_drawsInScreenSpace = [value boolValue];
	} else if (_drawsInScreenSpace) {
		[props setObject:[NSNumber numberWithBool:_drawsInScreenSpace] forKey:kFxPropertyKey_DrawsInScreenSpace];
	}
	
	value = [props objectForKey:kFxPropertyKey_DesiredProcessingColorInfo];
	if (value != nil) {
		_desiredProcessingColorInfo = [value unsignedLongValue];
	} else if (_desiredProcessingColorInfo != kFxImageColorInfo_RGB_GAMMA_VIDEO) {
		[props setObject:[NSNumber numberWithUnsignedLong:_desiredProcessingColorInfo] forKey:kFxPropertyKey_DesiredProcessingColorInfo];
	}
	
	
	value = [props objectForKey:kFxPropertyKey_PixelTransformSupport];
	if (value != nil) {
		_pixelTransformSupport = [value unsignedLongValue];
	} else {
		[props setObject:[NSNumber numberWithUnsignedLong:_pixelTransformSupport] forKey:kFxPropertyKey_PixelTransformSupport];
	}
	
	*properties = [props copy];
	DebugLog(_apiManager.sessionID, @"<<");
    return YES;
}

//---------------------------------------------------------
// finishInitialSetup
//
// Wraps up any initialization within Motion.
// No document yet.  Called only once to finalize the initial setup
//---------------------------------------------------------

- (BOOL) finishInitialSetup:(NSError * _Nullable *)error
{
	DebugLog(_apiManager.sessionID, @">>");
	
	return [self extensionsFinishInitialSetup];
}

/*!
	@method     -pluginInstanceAddedToDocument
	@abstract   Notifies your plug-in when it becomes part of user's document.
	@discussion Called when a new plug-in instance is created or a document is loaded and an
				existing instance is deserialized. When the host calls this method, the plug-in is
				a part of the document and the various API objects work as expected.
 */
- (void) pluginInstanceAddedToDocument
{
	DebugLog(_apiManager.sessionID, @">>");
	
	_addedToDocument = YES;
	
	// @todo Reconstruct parameters here
	
	[self extensionsAddedToDocument];
	
	//if (self.hasMeta) {
		// load Meta on instance load
	//	[self.meta metaInstalled];
	//}
}

/*!
	@method     -parameterChanged:atTime:error:
	@abstract   Executes when the host detects that a parameter has changed.
	@param      paramID     The ID of the parameter that changed.
	@param      time        The rational time at which the parameter changed.
	@param      error       Return any errors that occurred in this parameter.
	@discussion Use this method to change, enable, disable, hide, or show other parameters.
				This method is called each time the user changes a parameter. You can use this
				method to update other parameters (such as hiding or showing them). You have full
				access to @c FxParameterCreationAPI_v5 or later, @c FxParameterRetrievalAPI_v6 or
				later, and @c FxParameterSettingAPI_v5 or later, within this method.
	@result     Return YES if you successfully handled the parameter change. Return NO otherwise.
				If you return NO, also fill out the error parameter by creating an NSError with
				the FxPlugErrorDomain.
 */
- (BOOL)parameterChanged:(UInt32)paramID
				  atTime:(CMTime)time
				   error:(NSError * _Nullable *)error
{
	DebugLog(_apiManager.sessionID, @">>");
	
	BOOL success = [self handleParameterChanged:paramID atTime:time error:error];
	
#if DEBUG
	if (!success && *error) {
		NSLog(@"%s- ERROR: %@", __func__, *error);
	}
#endif
	
	// Call internal subclass parameterChanged
	if ([self respondsToSelector:@selector(guruParameterChanged:atTime:error:)]) {
		success = [self guruParameterChanged:paramID atTime:time error:error] && success;
#if DEBUG
		if (!success && *error) {
			NSLog(@"%s- ERROR: %@", __func__, *error);
		}
#endif
	}
	
	//
	success = [self completeParameterChanged:paramID atTime:time error:error] && success;
	
	[self extensionsFlush];
	
#if DEBUG
	if (!success && *error) {
		NSLog(@"%s- ERROR: %@", __func__, *error);
	}
#endif
	
	return success;
}


- (BOOL)pluginState:(NSData * _Nonnull * _Nullable)pluginState atTime:(CMTime)renderTime quality:(FxQuality)qualityLevel error:(NSError * _Nonnull * _Nullable)error
{
	DebugLog(_apiManager.sessionID, @">>");
	
	NSKeyedArchiver *encoder = [NSKeyedArchiver.alloc initRequiringSecureCoding:true];
	encoder.outputFormat = NSPropertyListBinaryFormat_v1_0;
	encoder.renderTime = renderTime;
	encoder.qualityLevel = qualityLevel;
	
	// For counting all the ImageRef parameters.
	//int imageRefCount = 0;
	
	// Encode all the parameters that have state
	for(id<FxParameter> param in _parameters) {
		if (!param.hasState) {
			continue;
		}
		//imageRefCount += [param isKindOfClass:GuruFxImageRefParameter.class];
		[param encodeWithCoder:encoder];
	}
	
	// Insert the imageRef offsets for each parameter, from the end.
	// To retreive the sourceImages ImageRef Index, get the int for the parameter ID
	//	then use the FxImageTile at arary index (sourceImages.count - ImageRef Index)
	/* int i = 0;
	for(id<GuruFxParameterProtocol> param in _parameters) {
		if (!param.hasState || ![param isKindOfClass:GuruFxImageRefParameter.class]) {
			continue;
		}
		[encoder encodeInt:-imageRefCount + i atIndex:param.parameterID];
		i++;
	}*/
	
	// If the child has a pluginStateWithCoder
	if ([self respondsToSelector:@selector(pluginStateWithCoder:atTime:quality:error:)]) {
		if (![self pluginStateWithCoder:encoder atTime:renderTime quality:qualityLevel error: error] || (error && *error)) {
			return NO;
		}
	}
	
	[encoder finishEncoding];
	*pluginState = encoder.encodedData;
	
	return pluginState != nil && !(error && *error);
}

//---------------------------------------------------------
// destinationImageRect:sourceImages:destinationImage:pluginState:atTime:error
//
// This method will calculate the rectangular bounds of the output
// image given the various inputs and plug-in state
// at the given render time.
// It will pass in an array of images, the plug-in state
// returned from your plug-in's -pluginStateAtTime:error: method,
// and the render time.
// This is called except when properties has kFxPropertyKey_ChangesOutputSize
// that is NO
//---------------------------------------------------------

- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *)sourceImages
			destinationImage:(nonnull FxImageTile *)destinationImage
				 pluginState:(NSData *)pluginState
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)outError
{
	DebugLog(_apiManager.sessionID, @">>");
	
	if (self.isGenerator || self) {
		// This is a generator so always use the output image's pixel bounds
		*destinationImageRect = destinationImage.imagePixelBounds;
  
		return YES;
	}
	
	if (sourceImages.count < 1)
	{
		NSLog(@"GuruFxTileableEffect(%llu)::destinationImageRect Error: No inputImages list", _apiManager.sessionID);
		
		if (outError != NULL)
		{
			*outError = [NSError errorWithDomain:FxPlugErrorDomain
											code:kFxError_ThirdPartyDeveloperStart + 5
										userInfo:@{
												   NSLocalizedDescriptionKey : @"Invalid input image list - it's empty!"
												   }];
		}
		return NO;
	}
	
	int srcIndex = 0;
	
	FxPoint2D   ll  = { sourceImages [ srcIndex ].imagePixelBounds.left, sourceImages [ srcIndex ].imagePixelBounds.bottom };
	FxPoint2D   ur  = { sourceImages [ srcIndex ].imagePixelBounds.right, sourceImages [ srcIndex ].imagePixelBounds.top };
	
	
	// Convert from input pixel space to image space
	ll = [sourceImages [ srcIndex ].inversePixelTransform transform2DPoint:ll];
	ur = [sourceImages [ srcIndex ].inversePixelTransform transform2DPoint:ur];
	
	// Convert image space to output pixel space
	ll = [destinationImage.pixelTransform transform2DPoint:ll];
	ur = [destinationImage.pixelTransform transform2DPoint:ur];
	
	destinationImageRect->left = ll.x;
	destinationImageRect->right = ur.x;
	destinationImageRect->bottom = ll.y;
	destinationImageRect->top = ur.y;
	
	return YES;
}

//---------------------------------------------------------
// sourceTileRect:sourceImageIndex:sourceImages:destinationTileRect:destinationImage:pluginState:atTime:error
//
// Calculate tile of the source image we need
// to render the given output tile.
//---------------------------------------------------------

- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
	  sourceImageIndex:(NSUInteger)sourceImageIndex
		  sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
	  destinationImage:(FxImageTile *)destinationImage
		   pluginState:(NSData *)pluginState
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable *)outError
{
	//DebugLog(_apiManager.sessionID, @">>");
	
	if (self.isGenerator) {
		// Since this is a generator, there is no source tile
  		*sourceTileRect = kFxRect_Empty;
		return YES;
	} else if (!self.changesOutputSize) {
		*sourceTileRect = destinationTileRect;
		return YES;
	}
	
	int srcIndex = 0;
	
	// Get output pixel space coordinates
	FxPoint2D   ll = { destinationTileRect.left, destinationTileRect.bottom };
	FxPoint2D   ur = { destinationTileRect.right, destinationTileRect.top };
	
	// Convert to image space
	ll = [destinationImage.inversePixelTransform transform2DPoint:ll];
	ur = [destinationImage.inversePixelTransform transform2DPoint:ur];
	
	// Convert to input pixel space
	ll = [sourceImages [ srcIndex ].pixelTransform transform2DPoint:ll];
	ur = [sourceImages [ srcIndex ].pixelTransform transform2DPoint:ur];
	
	sourceTileRect->left = ll.x;
	sourceTileRect->right = ur.x;
	sourceTileRect->bottom = ll.y;
	sourceTileRect->top = ur.y;
	
	return YES;
}


//---------------------------------------------------------
// renderDestinationImage:sourceImages:pluginState:atTime:error:
//
// The host will call this method when it wants your plug-in to render an image
// tile of the output image. It will pass in each of the input tiles needed as well
// as the plug-in state needed for the calculations. Your plug-in should do all its
// rendering in this method. It should not attempt to use the FxParameterRetrievalAPI*
// object as it is invalid at this time. Note that this method will be called on
// multiple threads at the same time.
//---------------------------------------------------------
- (BOOL)scheduleInputs:(NSArray<FxImageTileRequest*>* _Nullable * _Nullable)inputImageRequests
	   withPluginState:(NSData* _Nullable)pluginState
				atTime:(CMTime)renderTime
				 error:(NSError**)error
{
	if (pluginState == nil)
	{
		if (error != nil)
		{
			*error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxError_ThirdPartyDeveloperStart + 1
									 userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Invalid pluginState in %s", __func__] }];
		}
		return NO;
	}
	
	// @todo if a generator, skip out?
	
	if ([self respondsToSelector:@selector(pluginStateWithCoder:atTime:quality:error:)]) {
		
		NSKeyedUnarchiver *state = NARC_AUTORELEASE([NSKeyedUnarchiver.alloc initForReadingFromData:pluginState
																			 error:error]);
		if (*error || !state) {
			return NO;
		}
		
		int imageRefCount = 0;
		for(FxParameter *param in _parameters) {
			if ([param isKindOfClass: GuruFxImageRefParameter.class]) {
				imageRefCount++;
			}
		}
		FxImageTileRequest* mainInput   = NARC_AUTORELEASE([FxImageTileRequest.alloc initWithSource:kFxImageTileRequestSourceEffectClip
																			   time:renderTime
																	 includeFilters:YES
																		parameterID:0]);
		
		NSMutableArray *mutableInputImageRequests = NARC_AUTORELEASE([NSMutableArray.alloc initWithCapacity:imageRefCount + 1]);
		[mutableInputImageRequests addObject:mainInput];
		if ([self respondsToSelector:@selector(scheduleInputs:withCoder:atTime:error:)]) {
			if (![self scheduleInputs:&mutableInputImageRequests
							withCoder:state
							   atTime:renderTime
								error:error]) {
				return NO;
			}
		}
		if (imageRefCount) {
			for(FxParameter *param in _parameters) {
				if ([param isKindOfClass: GuruFxImageRefParameter.class]) {
					GuruFxImageRefParameter *imgRefParam = (GuruFxImageRefParameter*)param;
					FxImageTileRequest* paramInput = nil;
					paramInput = NARC_AUTORELEASE([FxImageTileRequest.alloc initWithSource: kFxImageTileRequestSourceParameter
																	 time:renderTime
														   includeFilters:imgRefParam.includeFilters
															  parameterID:imgRefParam.parameterID]);
					[mutableInputImageRequests addObject:paramInput];
				}
			}
		}
		if (mutableInputImageRequests) {
			*inputImageRequests = [mutableInputImageRequests copy];
		}
	}
	return YES;
}



//---------------------------------------------------------
// renderDestinationImage:sourceImages:pluginState:atTime:error:
//
// The host will call this method when it wants your plug-in to render an image
// tile of the output image. It will pass in each of the input tiles needed as well
// as the plug-in state needed for the calculations. Your plug-in should do all its
// rendering in this method. It should not attempt to use the FxParameterRetrievalAPI*
// object as it is invalid at this time. Note that this method will be called on
// multiple threads at the same time.
//---------------------------------------------------------

- (BOOL)renderDestinationImage:(FxImageTile *_Nonnull)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *)sourceImages
				   pluginState:(NSData *)pluginState
						atTime:(CMTime)renderTime
						 error:(NSError *_Nullable *_Nullable)outError
{
	//DebugLog(_apiManager.index, @">>");
	
	int srcIndex = 0;
	
	if (pluginState == nil) {
		NSLog(@"GuruFxTileableEffect(%llu)::renderDestinationImage Error No pluginState", _apiManager.sessionID);
		NSDictionary*   userInfo    = @{ NSLocalizedDescriptionKey : @"Invalid plugin state received from host" };
		if (outError != NULL)
			*outError = [NSError errorWithDomain:FxPlugErrorDomain
											code:kFxError_InvalidParameter
										userInfo:userInfo];
		return NO;
	}
	
	if (destinationImage.ioSurface == nil)
	{
		NSLog(@"GuruFxTileableEffect(%llu)::renderDestinationImage Error: No destinationImage ioSurface", _apiManager.sessionID);
		NSDictionary*   userInfo = @{ NSLocalizedDescriptionKey : @"Invalid No Destination ioSurface" };
		if (outError != NULL)
			*outError = [NSError errorWithDomain:FxPlugErrorDomain
											code:kFxError_InvalidParameter
										userInfo:userInfo];
		return NO;
	}
	
	BOOL success = YES;
	id pState = pluginState;
	if ([self respondsToSelector:@selector(pluginStateWithCoder:atTime:quality:error:)]) {
		
		NSKeyedUnarchiver *state = NARC_AUTORELEASE([NSKeyedUnarchiver.alloc initForReadingFromData:pluginState
																			 error:outError]);
		if (*outError || !state) {
			return NO;
		}
		//state.imageRefCount = sourceImages.count;
		pState = state;
		if (![self respondsToSelector:@selector(renderDestinationImage:sourceImages:pluginStateCoder:atTime:error:)]) {
			static dispatch_once_t renderCoderToken;
			dispatch_once(&renderCoderToken, ^{
				NSLog(@"Error: subclass %@ does not respond to renderDestinationImage:sourceImages:pluginStateCoder:atTime:error:", self.className);
			});
			return NO;
		}
		success = [self renderDestinationImage:destinationImage
							   sourceImages:sourceImages
						   pluginStateCoder:state
									 atTime:renderTime
									  error:outError];
	} else if(!isGenerator) {
		
		// FxFilter - copy source to destination.
		
		if (![sourceImages count] || sourceImages [ srcIndex ].ioSurface == nil || srcIndex >= [sourceImages count])
		{
			NSDictionary*   userInfo = nil;
			if (![sourceImages count]) {
				NSLog(@"GuruFxTileableEffect(%llu)::renderDestinationImage Error: No inputImages list", _apiManager.sessionID);
				userInfo = @{ NSLocalizedDescriptionKey : @"Invalid No Source Image" };
			} else if(sourceImages [ srcIndex ].ioSurface == nil) {
				NSLog(@"GuruFxTileableEffect(%llu)::renderDestinationImage Error: No inputImages[%d] ioSurface", _apiManager.sessionID, srcIndex);
				userInfo = @{ NSLocalizedDescriptionKey : @"Invalid No Source Image ioSurface" };
			} else {
				NSLog(@"GuruFxTileableEffect(%llu)::renderDestinationImage Error: srcIndex %d is equal or above the number of sourceImages %lu", _apiManager.sessionID, srcIndex, (unsigned long)[sourceImages count]);
				userInfo = @{ NSLocalizedDescriptionKey : @"Invalid No Source Image ioSurface" };
			}
			if (outError != NULL)
				*outError = [NSError errorWithDomain:FxPlugErrorDomain
												code:kFxError_InvalidParameter
											userInfo:userInfo];
			return NO;
		}
		
		// This is where you would access parameter values and other info about the source tile
		// from the pluginState.
		//double  brightness = 0.0;
		
		// Set up the renderer, in this case we are using Metal.
		
		GuruFxMTLDeviceCache*  deviceCache		= [GuruFxMTLDeviceCache deviceCache];
		//MTLPixelFormat     pixelFormat		= [GuruFxMTLDeviceCache MTLPixelFormatForImageTile:destinationImage];
		GuruFxMTLDeviceCacheItem* srcDevice		= [deviceCache deviceWithRegistryID:sourceImages [ srcIndex ].deviceRegistryID];
		id<MTLDevice> destDevice	= [GuruFxMTLDeviceCache metalDeviceFromID:destinationImage.deviceRegistryID];
		
		id<MTLCommandQueue> commandQueue = [srcDevice getNextFreeCommandQueue];
		if (commandQueue == nil)
		{
			NSLog(@"GuruFxTileableEffect(%llu)::destinationImageRect Error: No command queue", _apiManager.sessionID);
			return NO;
		}
		MPSImageScale *scaleEncoder = [MPSImageBilinearScale.alloc init];
		
		float   inputWidth     = (float)(sourceImages[srcIndex].tilePixelBounds.right - sourceImages[srcIndex].tilePixelBounds.left);
		float   inputHeight    = (float)(sourceImages[srcIndex].tilePixelBounds.top - sourceImages[srcIndex].tilePixelBounds.bottom);
		
		float   outputWidth     = (float)(destinationImage.tilePixelBounds.right - destinationImage.tilePixelBounds.left);
		float   outputHeight    = (float)(destinationImage.tilePixelBounds.top - destinationImage.tilePixelBounds.bottom);
		/*
		 MPSScaleTransform transform;
		 initWithDevice:srcDevice.gpuDevice] autorelease];
		 transform.scaleX = outputWidth / inputWidth;
		 transform.scaleY = outputHeight / inputHeight;
		 transform.translateX = 0.0;
		 transform.translateY = 0.0;
		 scaleEncoder.scaleTransform = &transform;
		 */
		
		id<MTLCommandBuffer>    commandBuffer   = [commandQueue commandBuffer];
		commandBuffer.label = [NSString stringWithFormat:@"GuruFxTileableEffect Basic Scale Command Buffer (%.1f, %.1f)", outputWidth / inputWidth, outputHeight / inputHeight];
		[commandBuffer enqueue];
		
		id<MTLTexture>  inputTexture    = [sourceImages[srcIndex] metalTextureForDevice:srcDevice.gpuDevice];
		
		id<MTLTexture>  outputTexture   = [destinationImage metalTextureForDevice:destDevice];
		
		[scaleEncoder encodeToCommandBuffer:commandBuffer sourceTexture:inputTexture destinationTexture:outputTexture];
		
		[commandBuffer commit];
		[commandBuffer waitUntilCompleted];
		[deviceCache returnCommandQueueToCache:commandQueue];
		
		if (commandBuffer.status == MTLCommandBufferStatusError || commandBuffer.error) {
			NSLog(@"GuruFxTileableEffect(%llu)::renderDestinationImage Metal Blit Error %@", _apiManager.sessionID, commandBuffer.error);
			success = NO;
		}
		NARC_RELEASE(scaleEncoder);
	}
	if (success) {
		success = [self extensionsRender:destinationImage sourceImages:sourceImages
				   pluginState:pState atTime:renderTime error:outError];
	}
	
	return success;
	
}


#pragma mark -
#pragma mark Project Properties


/*!
	@method     -documentID
	@discussion This returns 0 when there is no Project.  This also returns 0 when in a project within Motion.
				When used in Final Cut Pro, each instance of the plugin has its own documentId
	@result     NSUInteger	The serial number of the Plugin Instance within the document.
 */
- (NSUInteger)documentID
{
	NSError *error = nil;
	NSUInteger docId = 0;
	docId = [self documentIDWithError:&error];
	if (error) {
		NSLog(@"Error: getting documentIDWithError: %@", error);
	}
	return docId;
}

- (BOOL)isMotion
{
	return self.documentID == 0;
}

- (BOOL)isFinalCutPro
{
	return self.documentID != 0;
}

- (NSUInteger)documentIDWithError:(NSError**)error
{
	NSUInteger documentId = 0;
#if DEBUG
	if((
#endif
	   [self.apiManager.projectAPIv1 documentID:&documentId error:error]
#if !DEBUG
		;
#else
			)) {
		NSLog(@"%s(%llu) - Document ID is %d", __func__, _apiManager.sessionID, (int)documentId);
	} else {
		NSLog(@"Error: %s(%llu) - Document ID error %@", __func__, _apiManager.sessionID, *error);
	}
#endif
	return documentId;
}


// @todo,  document what this is
- (NSURL* _Nullable)mediaFolder
{
   NSError *error = nil;
   return [self mediaFolderWithError:&error];
}


-(NSURL* _Nullable) mediaFolderWithError:(NSError * _Nullable *)error
{
	NSURL *mediaFolder = nil;
	
	if ([self.apiManager.projectAPIv1 mediaFolderURL:&mediaFolder error:error]) {
		NSLog(@"%s(%llu) - Document Media Folder is %@", __func__, _apiManager.sessionID, [mediaFolder standardizedURL]);
	} else {
		NSLog(@"%s(%llu) - no media folder", __func__, _apiManager.sessionID);
	}
	return mediaFolder;
}

- (float) projectAspectRatio
{
	NSError *error = nil;
	return [self projectAspectRatioWithError:&error];
}

- (float) projectAspectRatioWithError:(NSError * _Nullable *)error
{
	float aspectF = 0.0;
	
	if ([_apiManager.projectAPIv2 projectAspectRatio:&aspectF error:error]) {
		return aspectF;
	}
	return kAspectRatio16x9;
}



#pragma mark -
#pragma mark Subclass Utilities


// These are properties of the plugin parameters that are trasferred to the
// parameter's runtime meta.
- (NSArray<NSString*>* _Nonnull)transferParameterProperties
{
	// so we can see which meta are which by name in debugging
	return @[
#if DEBUG
		kFxParameterProperty_Name,
#endif
		kFxParameterProperty_Selector,
		kFxParameterProperty_ResetValue
	];
}




#pragma mark -
#pragma mark Getters and Setters

- (GuruFxMetaManager *)meta
{
	@synchronized(self) {
		if (!_meta) {
			id<FxParameterRetrievalAPI_v6> paramGetAPIv6 = _apiManager.paramGetAPIv6_Raw;
			if (paramGetAPIv6) {
				GuruFxMetaManager *newMeta = nil;
				CMTime time = kCMTimeZero;
				//NSArray<NSNumber*>* params = _apiManager.dynamicParamAPIv4.allParameterIDs;
				NSLog(@"reading meta from: %d", kFxParameterId_InstanceMeta);
				if ([paramGetAPIv6 getCustomParameterValue:&newMeta fromParameter:kFxParameterId_InstanceMeta atTime:time]) {
					_meta = newMeta;
					//[_meta retain];
					[_meta setEffect:self];
				}
			}
			if (!_meta) {
				_meta = [GuruFxMetaManager.alloc initWithEffect:self];
			}
		}
	}
	return _meta;
}

// This gets the configuration properties of the plugin.
// these are Not the "effect properties" (like "remap" and "change output size")
- (NSDictionary* _Nonnull)properties
{
	@synchronized(self) {
		if (!_properties) {
			
#if GURUFX_APPLE_TERMS_COMPLIANT
	#if GURUFX_MULTI_PLUGIN_CLASSES
			// By default, we allow multiple plugins to be run by the same class and
			//	 then change itself based on configuration.
			_properties = [GuruFxPluginInfo.sharedInstance pluginPropertiesByUUID:_apiManager.apiAccessing.pluginUUID];
	#else
			// Full Compliance requires unique classes per Plugin Configuration
			_properties = [GuruFxPluginInfo.sharedInfo pluginProperties:[self className]];
	#endif
#else
			//_properties = [GuruFxPluginInfo.sharedInstance pluginPropertiesByUUID:_apiManager.apiAccessing.pluginUUID];
#endif
			
			if (_properties == nil) {
				_properties = @{};
			}
		}
	}
	return _properties;
}

// gets the list of Plugin Parameters from the Plugin Properties under it's UUID, or gets the plist file.  the file based plist is localized similarly to the plugin plist.
// This adds the Debug activator and the debug menu parameter.
- (NSArray<NSDictionary*>* _Nonnull)initialParametersList
{
	@synchronized(self) {
		if (!_initialParametersList) {
			// Grap the actual parameters list.
			NSArray *ogParameterList;
			ogParameterList = (NSArray*)[self.properties objectForKey:kProPlugPlugInX_ParametersProperty];
			if (!ogParameterList || ![ogParameterList isKindOfClass:NSArray.class]) {
				ogParameterList = @[];
			} else if ([ogParameterList isKindOfClass:[NSString class]]) {
				_parametersFile = (NSString*)ogParameterList;
				//If the parameters for the plugin are a file, get the plist file.
				ogParameterList = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:_parametersFile ofType:@"plist"]];
			}
			
			NSMutableArray *paramList = [ogParameterList mutableCopyRecursive];
			
			//flatten
			[GuruFxParameterUtility flattenDictionaryParameters:paramList];
			
			// Allow extensions to CRUD parameters
			//	Sub classes can override this method to process the list,
			//	just be sure to call the super method.
			[self extensionsProcessParameters:paramList];
			
			// Localize
			paramList = [GuruFxPluginInfo localizeObject:paramList];
			
			// solidify each element
			for(int i = 0; i < paramList.count; i++) {
				paramList[i] = [paramList[i] copy];
			}
			_initialParametersList = [paramList copy];
		}
	}
	return _initialParametersList;
}


// A dictionary with the keys as the parameter ID numbers of the parameters to index into them
- (NSDictionary<NSNumber*, NSDictionary*>* _Nonnull)initialParameters
{
	if (!_initialParameters) {
		NSArray *parameters = self.initialParametersList;
		NSMutableDictionary *initParams = [NSMutableDictionary.alloc initWithCapacity:[parameters count]];
		
		NSDictionary *param = nil;
		for (param in parameters) {
			NSNumber *paramID = [param objectForKey:kFxParameterProperty_Id];
			if (paramID != nil) {
				[initParams setObject:param forKey:paramID];
			} else {
				NSLog(@"GuruFxTileableEFfect::initialParameters Error: No Parameter id in parameter %@", param);
			}
		}
		_initialParameters = [initParams copy];
	}
	return _initialParameters;
}

// A dictionary with the keys as the parameter ID numbers of the parameters to index into them
- (NSDictionary*_Nullable)initialParameter:(FxParameterId)parameterID
{
	return self.initialParameters[@(parameterID)];
}

// A dictionary with the keys as the parameter ID numbers of the parameters to index into them
/*- (id)initialValueForKey:(NSString*)key fromParameter:(FxParameterId)parameterID
{
	NSDictionary *initParamData = [self initialParameter:parameterID];
	
	if (initParamData) {
		return initParamData[key];
	}
	
	return nil;
}*/

//Produces an immutable copy of the added parameters
- (NSDictionary<NSNumber*, FxParameter*>*_Nonnull)parameters
{
	return [_parameters copy];
}


// Gets the coloring for the Project: is it sRGB or HDR?
- (FxColorPrimaries)colorPrimaries
{
	id<FxColorGamutAPI_v2> colorGamut = [_apiManager colorGamutAPIv2];
	if (!colorGamut)
		return kFxColorPrimaries_Rec709;
	return [colorGamut colorPrimaries];
}
- (BOOL)isHDRProject
{
	return self.colorPrimaries == kFxColorPrimaries_Rec2020;
}
- (BOOL)issRGBProject
{
	return self.colorPrimaries == kFxColorPrimaries_Rec709;
}
- (BOOL)isGammaColorParameters
{
	return self.desiredProcessingColorInfo == kFxImageColorInfo_RGB_GAMMA_VIDEO;
}
- (BOOL)isLinearColorParameters
{
	return self.desiredProcessingColorInfo == kFxImageColorInfo_RGB_LINEAR;
}

- (NSString*)uuid
{
	if (!_uuid) {
		if ([self conformsToProtocol:@protocol(FxRegisteredPlugin)] && [self.class respondsToSelector:@selector(uuid)]) {
			_uuid = [self.class uuid];
		} else {
			_uuid = self.properties.pluginUUID;
		}
		if (!_uuid) {
			_uuid = @"";
		}
	}
	return _uuid;
}

// This is for prior versions
- (NSArray*)priorUuids
{
	if (!_priorUuids) {
		_priorUuids = self.properties.pluginPriorUUIDs;
		
		if (!_priorUuids) {
			_priorUuids = @[];
		} else if ([_priorUuids isKindOfClass:[NSArray class]]) {
			// nothing to do, skip
		} else if ([_priorUuids isKindOfClass:[NSString class]]) {
			_priorUuids = @[_priorUuids];
		} else if ([_priorUuids isKindOfClass:[NSDictionary class]]) {
			_priorUuids = [(NSDictionary*)_priorUuids allValues];
		} else {
			_priorUuids = @[[(id)_priorUuids stringValue]];
		}
	}
	return _priorUuids;
}

- (NSString*)displayName
{
	if (!_displayName) {
		_displayName = self.properties.pluignDisplayName;
		if (!_displayName) {
			_displayName = @"";
		}
	}
	return _displayName;
}

//
// group
// returns the guid of the group of the plugin
- (NSString*)groupUuid
{
	if (!_groupUuid) {
		_groupUuid = self.properties.pluginGroupUUID;
		if (!_groupUuid) {
			_groupUuid = @"";
		}
	}
	return _groupUuid;
}

- (NSString*)infoString
{
	if (!_infoString) {
		_infoString = self.properties.pluginInfoString;
		if (!_infoString) {
			_infoString = @"";
		}
	}
	return _infoString;
}

- (NSString*)defaultFontName
{
	if (!_defaultFontName) {
		_defaultFontName = self.properties.pluginDefaultFontName;
		if (!_defaultFontName) {
			_defaultFontName = kFxParameterType_FontNameDefault;
		}
	}
	return _defaultFontName;
}

- (NSArray*)protocolNames
{
	if (!_protocolNames) {
		_protocolNames = self.properties.pluginProtocolNames;
		if (!_protocolNames) {
			_protocolNames = @[@""];
		}
	}
	return _protocolNames;
}

- (BOOL)hasProtocolName:(NSString* _Nullable)protocol
{
	NSArray *protocols = self.protocolNames;
	if (protocols && protocol) {
		for(NSString *p in protocols) {
			if ([protocol.lowercaseString isEqualToString:p.lowercaseString]) {
				return YES;
			}
		}
	}
	return NO;
}

- (BOOL)isGenerator
{
	if (__isGenerator == nil) {
		__isGenerator = [NSNumber numberWithBool:[self hasProtocolName:kProPlugPlugIn_ProtocolFxGenerator]];
	}
	return [__isGenerator boolValue];
}

- (BOOL)isFilter
{
	if (__isFilter == nil) {
		__isFilter = [NSNumber numberWithBool:[self hasProtocolName:kProPlugPlugIn_ProtocolFxFilter]];
	}
	return [__isFilter boolValue];
}

/*
- (NSString*)infoStringLocalized
{
	NSString *str = self.infoString;
	return NSLocalizedString(str, str);
}*/


// Default YES, Looks at the plugin class Info.plist for @"manageMeta" BOOL equals @NO,
- (BOOL)hasMeta
{
	return self.properties.pluginManageMeta;
}

- (BOOL)hasLoadedMeta
{
	return _addedToDocument && self.hasMeta;
}

- (UInt32)parameterCount
{
	return [self.apiManager.dynamicParamAPIv4 parameterCount];
}


// This gives GuruFxTileableEffect the ability to [] its parameters by parameter ID.
//	Negative values are an index into the arrey of parameters, starting with 0 and going to (-n + 1).
// Thus to access by index, [0] is the first parameter, [-1] is the second, [-2] is the third.  Until nil is returned.
// 0 is an invalid parameter ID.  so by iterating 0 backwards
- (id<GuruFxParameterProtocol> _Nullable)objectAtIndexedSubscript:(NSInteger)index
{
	if (index <= 0) {
		index = -index;
		id<FxDynamicParameterAPI_v4> dyParam = self.apiManager.dynamicParamAPIv4;
		
		UInt32 count = [dyParam parameterCount];
		if (index >= count)
			return nil;
		index = [dyParam parameterIDAtIndex:(UInt32)index];
	}
	return [_parameters objectForKey:@(index)];
}


- (id _Nullable)objectForKeyedSubscript:(id _Nullable)key
{
	if (!key) {
		return nil;
	}
	if ([key isKindOfClass:NSNumber.class] || ([key isKindOfClass:NSString.class] && [(NSString*)key isDigits])) {
		return [self objectAtIndexedSubscript:[key intValue]];
	}
	if ([key isKindOfClass:NSString.class]) {
		return [self extensionForKey:key];
	}
	return nil;
}


- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *) enumerationState
								   objects: (id __unsafe_unretained []) stackBuffer
									 count: (NSUInteger) len
{
	return [_parameters countByEnumeratingWithState:enumerationState objects:stackBuffer count:len];
}


#pragma mark -
#pragma mark Implementation

// This applies any presets from toggles and menu items to ensure initial conditions of the parameters
-(void) filterParameters:(NSMutableArray* _Nonnull)tParamList
{
	//NSMutableArray<NSMutableDictionary*> *tParamList = [paramList mutableCopy];
	NSMutableDictionary<NSNumber*, NSMutableDictionary*> *paramDispatch = [NSMutableDictionary dictionaryWithCapacity:tParamList.count];
	
	//convert parameters to NSMutableDictionaries
	// flatten group parameters, recurse until all nested are flattened.
	for(int i = 0; i < tParamList.count; i++) {
		NSMutableDictionary *param = nil;
		
		// Make sure the parameter dictionary is mutable
		if ([tParamList[i] isKindOfClass:[NSMutableDictionary class]]) {
			param = (NSMutableDictionary*)tParamList[i];
		} else {
			param = [tParamList[i] mutableCopy];
		}
		
		//
		FxParameterType type = param.parameterType;
		if (type == FxParameterType_Group) {
			// Groups unfold their inner parameters setting their parentId
			if (param[kFxParameterProperty_GroupParameters]) {
				int j = 1;
				for(NSDictionary *groupParam in param[kFxParameterProperty_GroupParameters]) {
					NSMutableDictionary *mutableGroupParam = [groupParam mutableCopy];
					if (!mutableGroupParam[kFxParameterProperty_ParentId])
						mutableGroupParam[kFxParameterProperty_ParentId] = @(param.parameterID);
					// Added at the next i so they also get processed.
					[tParamList insertObject:mutableGroupParam atIndex:i + j];
					j++;
				}
				[param removeObjectForKey:kFxParameterProperty_GroupParameters];
			}
		}
		tParamList[i] = param;
		paramDispatch[@(param.parameterID)] = param;
	}
	 
	
	int i = -1;

	for(NSMutableDictionary *param in tParamList) {
		i++;
		FxParameterType type = param.parameterType;
		
		// Set up the CustomClasses from initial List of Custom Class, Custom Classes, and FxCustomDataClasses.classesForParameter
		if (type == FxParameterType_Custom) {/*
			// *****  All this is processed in addCustomParameter.
											  
											  
			//Ensure Custom Class
			///	NSDictionary for Custom Class makes it a GuruFxInterpolatingDictionary
			///	Grab and set the clas from the default value, which may be filled in with an actual default class and values.
			NSString *customClassString = param.parameterCustomClass;
			if (!customClassString) {
				NSObject *defaultValue = param.parameterDefaultValue;
				if (defaultValue && [defaultValue isMemberOfClass:[NSDictionary class]]) {
					customClassString = [GuruFxInterpolatingDictionary className];
					param[kFxParameterProperty_CustomClass] = customClassString;
				} else if (defaultValue) {
					customClassString = [defaultValue className];
					param[kFxParameterProperty_CustomClass] = customClassString;
				} else {
					NSLog(@"ERROR - No Custom Class nor default for parameter %d", param.parameterID);
				}
			}
			
			NSSet<NSString*> *plistCustomClasses = param.parameterCustomClasses;
			
			NSMutableOrderedSet *customClasses = [NSMutableOrderedSet orderedSetWithCapacity:plistCustomClasses.count + 1 + 13];
			Class customClass = NSClassFromString(customClassString);
			if (customClass) {
				if (![customClass conformsToProtocol:@protocol(NSSecureCoding)]) {
					NSLog(@"ERROR - Custom Class \"%@\" for parameter %u does not conform to NSSecureCoding", customClass, (unsigned int)param.parameterID);
				} else if (![customClass conformsToProtocol:@protocol(NSCopying)]) {
					NSLog(@"ERROR - Custom Class \"%@\" for parameter %u does not conform to NSCopying", customClass, (unsigned int)param.parameterID);
				} else {
					[customClasses addObject:[customClass className]];
					if ([customClass conformsToProtocol:@protocol(FxCustomDataClasses)]) {
						for(NSString *innerClass in [customClass classesForParameter]) {
							[customClasses addObject:[innerClass className]];
						}
					}
				}
			} else {
				NSLog(@"ERROR - Custom Class \"%@\" for parameter %u is not a class", customClass, (unsigned int)param.parameterID);
			}
			
			NSMutableOrderedSet *filteredPListCustomClasses = [NSMutableOrderedSet orderedSetWithCapacity:plistCustomClasses.count];
			for(NSString *innerClass in plistCustomClasses) {
				if (NSClassFromString(innerClass)) {
					[filteredPListCustomClasses addObject:innerClass];
				} else {
					NSLog(@"ERROR - parameter %u custom Classes \"%@\" was not found - skipping", (unsigned int)param.parameterID, innerClass);
				}
			}
			[customClasses unionOrderedSet:filteredPListCustomClasses];
			
			param[kFxParameterProperty_CustomClasses] = [customClasses copy];
			 */
		}
		
	}
	
	//Process each Parameter
	for(NSMutableDictionary *param in tParamList) {
		FxParameterType type = param.parameterType;
		
		NSArray *targetPreset = param.parameterTargetPreset;
		if ([targetPreset isKindOfClass:[NSString class]]) {
			// Then this is a tag preset referencing the plugin presets
			NSDictionary *pluginPresets = self.properties.pluginPresets;
			NSString *tag = (NSString*)targetPreset;
			if (pluginPresets) {
				targetPreset = pluginPresets[tag];
			} else {
				targetPreset = nil;
			}
			if (!targetPreset) {
				NSLog(@"ERROR - preset target tag \"%@\" was not found in parameter %u", tag, (unsigned int)param.parameterID);
			}
		}
		if (targetPreset && targetPreset.count > 0 && (type == FxParameterType_Menu || type == FxParameterType_Toggle)) {
			long defaultValue = 0;
			NSNumber *defaultNumber = param.parameterDefaultValue;
			if (defaultNumber != nil) {
				defaultValue = defaultNumber.intValue;
			}
			
			NSDictionary *preset =  [targetPreset objectForIndex:defaultValue];
			
			if (!preset) {
				continue;
			}
			
			// Set Name Presets
			NSDictionary *presetNames = preset[kFxParameterProperty_TargetPresetNames];
			if (presetNames != nil) {
				
				for (NSString *pidStr in presetNames) {
					NSNumber *pid = @(pidStr.intValue);
					if (paramDispatch[pid]) {
						paramDispatch[pid][kFxParameterProperty_Name] = presetNames[pidStr];
					} else {
						NSLog(@"ERROR: Preset %ld of %u cannot set the Name of non-existent parameter %@ - skipping", defaultValue, (unsigned int)param.parameterID, pid);
						continue;
					}
				}
			}
			
			
			// Set Flag Presets
			NSDictionary *presetFlags = preset[kFxParameterProperty_TargetPresetFlags];
			if (presetFlags != nil) { // (options & PresetFlags) &&
				
				// For each Parameter in the flags
				for (NSString *pidStr in presetFlags) {
					NSNumber *pid = @(pidStr.intValue);
					
					if (!paramDispatch[pid]) {
						NSLog(@"ERROR: Preset %ld of %u cannot set the flags of non-existent parameter %@ - skipping", defaultValue, (unsigned int)param.parameterID, pid);
						continue;
					}
					
					NSArray* presetParamFlags = presetFlags[pidStr];
					
					//If a string, split by separator
					if ([presetParamFlags isKindOfClass:[NSString class]]) {
						presetParamFlags = [(NSString*)presetParamFlags splitByHumanDividers];
					}
					
					NSMutableArray<NSString*> *pflags = (NSMutableArray*)paramDispatch[pid].parameterFlagsArray;
					
					for (__strong NSString *presetFlag in presetParamFlags) {
						BOOL add = YES, rm1Char = NO;
						if ([presetFlag hasPrefix:@"-"]) {
							add = NO;
							rm1Char = YES;
						} else if ([presetFlag hasPrefix:@"+"]) {
							rm1Char = YES;
						}
						if (rm1Char) {
							presetFlag = [presetFlag substringFromIndex:1];
						}
						if (add && ![pflags containsObject:presetFlag]) {
							[pflags addObject:presetFlag];
						} else if (!add && [pflags containsObject:presetFlag]) {
							[pflags removeObject:presetFlag];
						}
					}
				}
			}
			
			
			// Set Tag Presets
			NSDictionary *presetTags = preset[kFxParameterProperty_TargetPresetTags];
			if (presetTags != nil) {
				NSString *pidStr = nil;
				for (pidStr in presetTags) {
					NSNumber *pid = @(pidStr.intValue);
					
					if (!paramDispatch[pid]) {
						NSLog(@"ERROR: Preset %ld of %u cannot set the tags of non-existent parameter %@ - skipping", defaultValue, (unsigned int)param.parameterID, pid);
						continue;
					}
					
					NSArray* presetParamTags = presetTags[pidStr];
					if ([presetParamTags isKindOfClass:[NSString class]]) {
						presetParamTags = [(NSString*)presetParamTags splitByHumanDividers];
					}
					
					NSMutableArray *ptags = paramDispatch[pid][kFxParameterProperty_Tags];
					if (ptags == nil) {
						ptags = [NSMutableArray arrayWithCapacity:presetTags.count];
						paramDispatch[pid][kFxParameterProperty_Tags] = ptags;
					}
					
					
					for (__strong NSString *presetTag in presetParamTags) {
						BOOL add = YES, rm1Char = NO;
						if ([presetTag hasPrefix:@"-"]) {
							add = NO;
							rm1Char = YES;
						} else if ([presetTag hasPrefix:@"+"]) {
							rm1Char = YES;
						}
						if (rm1Char) {
							presetTag = [presetTag substringFromIndex:1];
						}
						if (add && ![ptags containsObject:presetTag]) {
							[ptags addObject:presetTag];
						} else if (!add && [ptags containsObject:presetTag]) {
							[ptags removeObject:presetTag];
						}
					}
				}
			}
			
			
			//Set Value Presets
			NSDictionary<NSNumber*, id> *presetValues = preset[kFxParameterProperty_TargetPresetValues];
			if (presetValues != nil) {
				NSString *pidStr = nil;
				for (pidStr in presetValues) {
					NSNumber *pid = @(pidStr.intValue);
					
					FxParameterType ptype = paramDispatch[pid].parameterType;
					
					switch (ptype) {
						case FxParameterType_RGBA:
							if ([presetValues[pid] isKindOfClass:[NSDictionary class]]) {
								NSNumber *v = nil;
								v = ((NSDictionary*)presetValues[pid]).parameterAlpha;
								if (v != nil)
									paramDispatch[pid][kFxParameterProperty_Alpha] = v;
							}
						case FxParameterType_RGB:
							if ([presetValues[pid] isKindOfClass:[NSDictionary class]]) {
								NSNumber *v = nil;
								v = ((NSDictionary*)presetValues[pid]).parameterRed;
								if (v != nil)
									paramDispatch[pid][kFxParameterProperty_Red] = v;
								v = ((NSDictionary*)presetValues[pid]).parameterGreen;
								if (v != nil)
									paramDispatch[pid][kFxParameterProperty_Green] = v;
								v = ((NSDictionary*)presetValues[pid]).parameterBlue;
								if (v != nil)
									paramDispatch[pid][kFxParameterProperty_Blue] = v;
							}
							break;
						case FxParameterType_Point:
							if ([presetValues[pid] isKindOfClass:[NSDictionary class]]) {
								NSNumber *v = nil;
								v = ((NSDictionary*)presetValues[pid]).parameterDefaultX;
								if (v != nil)
									paramDispatch[pid][kFxParameterProperty_X] = v;
								v = ((NSDictionary*)presetValues[pid]).parameterDefaultY;
								if (v != nil)
									paramDispatch[pid][kFxParameterProperty_Y] = v;
							}
							break;
						case FxParameterType_Custom:
							if ([presetValues[pid] isKindOfClass:[NSDictionary class]]) {
								NSMutableDictionary *defaultValue = paramDispatch[pid].parameterDefaultValue;
								if (defaultValue == nil) {
									defaultValue = [NSMutableDictionary dictionary];
								}
								if ([defaultValue isKindOfClass:[NSMutableDictionary class]]) {
									[defaultValue mergeEntriesFromDictionary:presetValues[pid]];
								}
								paramDispatch[pid][kFxParameterProperty_Default] = defaultValue;
							}
							break;
						default:
							paramDispatch[pid][kFxParameterProperty_Default] = presetValues[pid];
							break;
					}
					
					
				}
			}
		}// end if (targetPreset and Menu or Toggle)
	}
}



- (BOOL)generateParameters:(NSArray<NSDictionary*>*_Nullable)parameters error:(NSError * _Nullable * _Nullable)error
{
	return [self generateParameters:parameters parameterID:kFxParameterId_AppleTopLevel error:error];
}

- (BOOL)generateParameters:(NSArray<NSDictionary*>*_Nullable)parameters parameterID:(FxParameterId)parentParameterId error:(NSError * _Nullable * _Nullable)error
{
	DebugLog(_apiManager.sessionID, @">>");
#if DEBUG
	NSLog(@"generateParameters: %@", parameters);
#endif
	
	//id<FxParameterCreationAPI_v5>   paramCreateAPI	= _apiManager.paramCreateAPIv5;
	//id<FxParameterTagsAPI_v1>   	paramTagsAPI	= nil;
	
	if (!parameters)
		return YES;
	
	// if (!_params) {
	//	_params = [NSMutableDictionary dictionaryWithCapacity:[parameters count]];
	//}
	BOOL success = YES;
	for (NSDictionary* parameter in parameters) {
		FxParameterId pid = parameter.parameterID;
		FxParameterType ptype = parameter.parameterType;
		if (!_parameters[@(pid)] && parameter.parameterParentID != parentParameterId) {
			continue;
		}
		Class cls = [self parameterClassForType:ptype];
		success = [cls addParameter:parameter toEffect:self] && success;
		//NSMutableDictionary *paramData = [NSMutableDictionary dictionaryWithDictionary:param];
		
		// FxParameterType type = paramData.parameterType;
		// NSString *errorReason = @"";
		
		//NSString *name = NSLocalizedString([paramData valueForKey:kFxParameterProperty_Name], [paramData valueForKey:kFxParameterProperty_Description]);
		
		/*id createdParameterData = _params[parameterNumber];
		if (createdParameterData) {
			NSLog(@"GuruFxTileableEffect(%llu)::generateParameters Error - #%@ Duplicate Parameter Id %d - \"%@\" attempted to instance but \"%@\" is already using the Id.", _apiManager.sessionID, [createdParameterData objectForKey:kFxParameterProperty_Index], parameterID, name, [createdParameterData objectForKey:kFxParameterProperty_Name]);
			continue;
		}*/
#if DEBUG
		NSLog(@"GuruFxTileableEffect(%llu)::generateParameters Creating (%u) %@", _apiManager.sessionID, (unsigned int)parameter.parameterID, parameter.parameterName);
#endif
		
/*		// when type is not found.
		if (0) {
			NSLog(@"GuruFxTileableEffect(%llu)::generateParameters Error - Parameter Type \"%@\" Not Found in parameter \"%@\" (#%d)", _apiManager.sessionID, paramData[kFxParameterProperty_Type], name, parameterID);
		} */
		
		
		/*
		NSArray<NSString*> *transferProperties = [self transferParameterProperties];
		NSMutableDictionary *metaParamData = [self.meta parameterData:parameterID];
		for(NSString *prop in paramData) {
			if ([transferProperties containsObject:prop] || [prop hasPrefix:kFxParameterProperty_TargetPrefix]) {
				metaParamData[prop.lowercaseString] = paramData[prop];
			}
		}
		
		
		//transfer elements of initial parameter meta to metaParameter Meta
		if (paramData.parameterMeta) {
			[metaParamData[kFxMetaProperty_ParamMeta] addEntriesFromDictionary:paramData.parameterMeta];
		}*/
		
		/*
		if (0) {
			if (error)
				*error = [NSError errorWithDomain:FxPlugErrorDomain
											 code:kFxError_ThirdPartyDeveloperStart + parameterID
										 userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%@%@%@", @"Unable to create ", name, @" parameter in [-GuruFxTileableEffect generateParameters:].", errorReason] }];
			return NO;
		} */
		//[paramData setObject:[NSNumber numberWithInt:parameterIndex] forKey:kFxParameterProperty_Index];
		//[_params setObject:paramData forKey:parameterNumber];
	}
	DebugLog(_apiManager.sessionID, @"<<");
	return success;
}


- (id _Nullable)parameterTargetPreset:(UInt32)paramID parameterData:(NSDictionary * _Nullable * _Nullable)paramData
{
	NSDictionary *_paramData = nil;
	id targetPreset = nil;
	
	if (self.hasMeta) {
		_paramData = [self.meta parameterData:paramID];
	} else {
		//_paramData = [self initialParameter:paramID];
	}
	if (_paramData == nil)
		return nil;
	if (paramData)
		*paramData = _paramData;
	
	targetPreset = _paramData.parameterTargetPreset;
	
	if ([targetPreset isKindOfClass:[NSString class]]) {
		// Then this is a tag preset referencing the plugin presets
		NSDictionary *pluginPresets = self.properties.pluginPresets;
		NSString *tag = (NSString*)targetPreset;
		if (pluginPresets) {
			targetPreset = pluginPresets[tag];
		} else {
			targetPreset = nil;
		}
		if (!targetPreset) {
			NSLog(@"ERROR - preset target tag \"%@\" was not found in parameter %u", tag, (unsigned int)_paramData.parameterID);
		}
	}
	return targetPreset;
}


- (BOOL)setParameterTargetPreset:(FxParameterId)paramID
						  atTime:(CMTime)time
						 options:(GuruFxPresetOptions)options
{
	NSDictionary *paramData = nil;
	NSArray *targetPreset = [self parameterTargetPreset:paramID parameterData:&paramData];
	if (!paramData)
		return NO;
	FxParameterType type = paramData.parameterType;
	
	//Menus and toggles can have presets, like a rig.
	if ((type == FxParameterType_Menu || type == FxParameterType_Toggle)) {
		
		id<FxParameterRetrievalAPI_v6> paramGetAPIv6 = [self.apiManager paramGetAPIv6];
		if (!paramGetAPIv6) {
			return NO;
		}
		id<FxParameterSettingAPI_v6> paramSetAPIv6 = [self.apiManager paramSetAPIv6];
		if (!paramSetAPIv6) {
			return NO;
		}
		id<FxDynamicParameterAPI_v4> dynamicParamAPIv4 = [self.apiManager dynamicParamAPIv4];
		if (!dynamicParamAPIv4) {
			return NO;
		}
		
		
		int		intValue = 0;
		//Menu or Toggle value
		if (type == FxParameterType_Menu) {
			if (![paramGetAPIv6 getIntValue:&intValue fromParameter:paramID atTime:time]) {
				return NO;
			}
		} else {
			BOOL	boolValue = NO;
			if (![paramGetAPIv6 getBoolValue:&boolValue fromParameter:paramID atTime:time]) {
				return NO;
			}
			intValue = (int)boolValue;
		}
		
		
		if (targetPreset && targetPreset.count > 0) {
			//NSArray + NSDictionary custom method for integer index
			NSDictionary *preset =  [targetPreset objectForIndex:intValue];
			
			// If no preset, default
			if (!preset) {
				if ([targetPreset isKindOfClass:[NSDictionary class]]) {
					preset = [((NSDictionary*)targetPreset) objectForKey:@"default"];
				}
			}
			
			if (preset) {
				//Set Name Presets
				
				 // Postpone setting the parameter names automatically because getting a string parameter will bug out
				
				NSDictionary *presetNames = preset[kFxParameterProperty_TargetPresetNames];
				if ((options & PresetName) && presetNames != nil) {
					for (NSString *pidStr in presetNames) {
						FxParameterId paramToName = pidStr.intValue;
						NSString *newName = presetNames[pidStr];
						if ([dynamicParamAPIv4 setParameter:paramToName name:newName]) { //return error?
							NSLog(@"ERROR: Preset %d of parameter %d cannot set the Name of parameter %@ - skipping", intValue, paramID, pidStr);
							continue;
						}
					}
				}
				 
				
				//Set Flag Presets
				NSDictionary *presetFlags = preset[kFxParameterProperty_TargetPresetFlags];
				if ((options & PresetFlags) && presetFlags != nil) {
					
					// Loop through Pids in the Flags Presets
					for (NSString *pidStr in presetFlags) {
						NSNumber *pid = @(pidStr.intValue);
						
						NSArray* presetParamFlags = presetFlags[pidStr];
						
						//If a string, split by separator
						if ([presetParamFlags isKindOfClass:[NSString class]]) {
							presetParamFlags = [(NSString*)presetParamFlags splitByHumanDividers];
						}
						
						BOOL changed = false;
						FxParameterFlags paramFlags = FxParameterType_None;
						
						//Get param flags
						if (![paramGetAPIv6 getParameterFlags:&paramFlags fromParameter:pid.intValue]) {
							NSLog(@"ERROR - Preset %d of %u - Could not get flags for %@", intValue, (unsigned int)paramID, pid);
							continue;
						}
						
						//change the flags
						for (__strong NSString *presetFlag in presetParamFlags) {
							BOOL add = YES, rm1Char = NO;
							if ([presetFlag hasPrefix:@"-"]) {
								add = NO;
								rm1Char = YES;
							} else if ([presetFlag hasPrefix:@"+"]) {
								rm1Char = YES;
							}
							if (rm1Char) {
								presetFlag = [presetFlag substringFromIndex:1];
							}
							FxParameterFlags bit = [GuruFxParameterUtility convertFlag:presetFlag];
							if (add && ((~paramFlags) & bit)) {
								changed = true;
								paramFlags |= bit;
							} else if (!add && (paramFlags & bit)) {
								changed = true;
								paramFlags &= ~bit;
							}
						}
						
						//Set param flags if changed
						if (changed) {
							if (![paramSetAPIv6 setParameterFlags:paramFlags toParameter:pid.intValue]) {
								NSLog(@"ERROR - Preset %d of %u - Could not set flags for %@", intValue, (unsigned int)paramID, pid);
								continue;
							}
						}
					}
				}
				
				//Set Tag Presets
				
				
				//Set Value Presets
				
				
				// Set min/max/slidermin/slidermax Presets
				
				
				
			} // end has preset within Target Preset
		}// end has targetPreset
		
		// Menu / Toggle selectors
		
		
	}
	return YES;
}

- (NSView *_Nullable)viewForParameterID:(UInt32)parameterID
{
	id<GuruFxParameterProtocol> parameter = self[parameterID];
	if (parameter) {
		if (![parameter isKindOfClass:GuruFxCustomParameter.class])
			return nil;
		return ((GuruFxCustomParameter*)parameter).view;
	}
	return nil;
}

- (BOOL)setParameter:(FxParameterId)paramID value:(id)value atTime:(CMTime)time
{ /*
	FxParameterType type = [self.apiManager.dynamicParamAPIv4 parameterType:paramID];
	
	
	if (type == FxParameterType_Menu || type == FxParameterType_Int) {
		if (value) {
			[self.apiManager.paramSetAPIv5 setIntValue:[value intValue] toParameter:paramID atTime:time];
		}
	} else if (type == FxParameterType_Toggle) {
		 if (value) {
			 [self.apiManager.paramSetAPIv5 setBoolValue:[value boolValue] toParameter:paramID atTime:time];
		 }
	} else if (type == FxParameterType_Angle || type == FxParameterType_Float ||
			   type == FxParameterType_Percent) {
		 if (value) {
			 [self.apiManager.paramSetAPIv5 setFloatValue:[value doubleValue] toParameter:paramID atTime:time];
		 }
	} else  if (type == FxParameterType_FontMenu || type == FxParameterType_String) {
		  if (value) {
			  [self.apiManager.paramSetAPIv5 setStringParameterValue:[value stringValue] toParameter:paramID];
		  }
	 } else if (type == FxParameterType_Point) {
		  if (value) {
			  NSDictionary *point = value;
			  double x = 0.0, y = 0.0;
			  
			  [self.apiManager.paramGetAPIv6 getXValue:&x YValue:&y fromParameter:paramID atTime:time];
			  
			  if (point.parameterDefaultX != nil)
				  x = point.parameterDefaultX.doubleValue;
			  if (point.parameterDefaultY != nil)
				  y = point.parameterDefaultY.doubleValue;
			  
			  [self.apiManager.paramSetAPIv5 setXValue:x YValue:y toParameter:paramID atTime:time ];
		  }
	} else if (type == FxParameterType_RGB || type == FxParameterType_RGBA) {
		 if (value) {
			 double red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0;
			 
			 if (type == FxParameterType_RGB)
				 [self.apiManager.paramGetAPIv6 getRedValue:&red greenValue:&green blueValue:&blue fromParameter:paramID atTime:time];
			 else
				 [self.apiManager.paramGetAPIv6 getRedValue:&red greenValue:&green blueValue:&blue alphaValue:&alpha fromParameter:paramID atTime:time];
			 
			 NSDictionary *color = value;
			 if (color.parameterRed != nil)
				 red = color.parameterRed.doubleValue;
			 if (color.parameterGreen != nil)
				 green = color.parameterGreen.doubleValue;
			 if (color.parameterBlue != nil)
				 blue = color.parameterBlue.doubleValue;
			 
			 if (type == FxParameterType_RGB) {
				 [self.apiManager.paramSetAPIv5 setRedValue:red greenValue:green blueValue:blue toParameter:paramID atTime:time];
			 } else {
				 if (type == FxParameterType_RGBA && color.parameterAlpha != nil)
				  alpha = color.parameterAlpha.doubleValue;
				 
				 [self.apiManager.paramSetAPIv5 setRedValue:red greenValue:green blueValue:blue alphaValue:alpha toParameter:paramID atTime:time];
			 }
		 }
	 }*/
	return YES;
}

/*!
	@method     -handleParameterChanged:atTime:error:
	@abstract   Executes when the host detects that a parameter has changed.
	@param      paramID     The ID of the parameter that changed.
	@param      time        The rational time at which the parameter changed.
	@param      error       Return any errors that occurred in this parameter.
	@discussion Use this method to change, enable, disable, hide, or show other parameters.
				This method is called each time the user changes a parameter. You can use this
				method to update other parameters (such as hiding or showing them). You have full
				access to @c FxParameterCreationAPI_v5 or later, @c FxParameterRetrievalAPI_v6 or
				later, and @c FxParameterSettingAPI_v5 or later, within this method.
	@result     Return YES if you successfully handled the parameter change. Return NO otherwise.
				If you return NO, also fill out the error parameter by creating an NSError with
				the FxPlugErrorDomain.
 */
- (BOOL)handleParameterChanged:(FxParameterId)paramID
						atTime:(CMTime)time
						 error:(NSError * _Nullable * _Nullable)error
{
	DebugLog(_apiManager.sessionID, @">>");
	BOOL success = YES;
	
	
	// []
	//Not names, String Parameters will not return value if name is set first
	//[self setParameterTargetPreset:paramID atTime:time options:PresetAll ^ PresetName];
	
	// If parameter has a target
	//	 set target name, value, metaKey, etc.
	// if menu item has links, open link, menu item fallback links
	//		link fallback in parameter meta
	//	if parameter has selector
	
	id<GuruFxParameterProtocol> parameter = self[paramID];
	if (!parameter) {
		return success;
	}
	if ([parameter respondsToSelector:@selector(startChangedTime:error:)]) {
		success = [parameter startChangedTime:time error:error];
	}
	return success;
	//Message the parameter Selector
	/*if ([parameter respondsToSelector:@selector(parameterSelector)]) {
		SEL selector = parameter.parameterSelector;
		if (selector) {
			GuruFxManagedSelector func = (GuruFxManagedSelector) objc_msgSend;
			NSObject* object = parameter.parameterSelectorObject;
			if (!object) {
				object = self;
			}
			if ([object respondsToSelector:selector]) {
				success = func(self, selector, paramID, time, error);
			} else {
				NSLog(@"Error: The selector %@ was not found on object %@", NSStringFromSelector(selector), object.className);
				success = NO;
			}
		}
	}*/
	
	return success;
}

/*!
	@method     -completeParameterChanged:atTime:error:
	@abstract   Executes when the host detects that a parameter has changed.
	@param      paramID     The ID of the parameter that changed.
	@param      time        The rational time at which the parameter changed.
	@param      error       Return any errors that occurred in this parameter.
	@discussion Use this method to change, enable, disable, hide, or show other parameters.
				This method is called each time the user changes a parameter. You can use this
				method to update other parameters (such as hiding or showing them). You have full
				access to @c FxParameterCreationAPI_v5 or later, @c FxParameterRetrievalAPI_v6 or
				later, and @c FxParameterSettingAPI_v5 or later, within this method.
	@result     Return YES if you successfully handled the parameter change. Return NO otherwise.
				If you return NO, also fill out the error parameter by creating an NSError with
				the FxPlugErrorDomain.
 */
- (BOOL)completeParameterChanged:(FxParameterId)paramID
						  atTime:(CMTime)time
						   error:(NSError * _Nullable * _Nullable)error
{
	DebugLog(_apiManager.sessionID, @">>");
	
	NSDictionary *paramData = nil;
	if (self.hasMeta) {
		paramData = [self.meta parameterData:paramID];
		if (!paramData) // for when the parameter is removed, success
			return YES;//todo: other solution for bypassing removed changed param?
		///			but others would return NO
	} else {
		//paramData = [self initialParameter:paramID];
	}
	if (!paramData)
		return NO;
	
	id<FxParameter> parameter = nil;//self[paramID];
	if (!parameter) {
		return NO;
	}
	
	BOOL success = YES;
	if ([parameter respondsToSelector:@selector(endChangedTime:error:)]) {
		//success = [parameter endChangedTime:time error:error];
	}
	//self[paramID].onChangeComplete
		// This is where the parameter would move the reset parameter value and set target preset
	//
	
	{
		//Preset name before resetValue
		[self setParameterTargetPreset:paramID atTime:time options:PresetName];
		
		
		// Parameter gets reset to its resetValue when selected.
		id resetValue = paramData.parameterResetValue;
		
		if (resetValue)
			[self setParameter:paramID value:resetValue atTime:time];
	}
	
	//extensionsParameterChanged

	// !!!   Bug work around for setting parameter name then getting a string parameter value glitching out.
	// Notes: Set the targetpresets names after everything so strings parameters aren't affected by their set name bug.
	//		Setting string parameter names should be the last thing we do.
	
	//if (self.hasMeta) {
	//	[self.meta saveMeta];
	//}
	
	return success;
}


- (NSUInteger)gradientSamples:(UInt32)parameterID
{
	// @todo
	//NSNumber *pid = [NSNumber numberWithUnsignedLong:parameterID];
	NSNumber *data = @100;//self[pid].parameterGradientSamples;
	
	if(data != nil) {
		return [data intValue];
	}
	return 0;
}


- (FxDepth)gradientDepth:(UInt32)parameterID;
{
	// @todo
	//NSNumber *pid = [NSNumber numberWithUnsignedLong:parameterID];
	return kFxDepth_FLOAT16;//_params[pid].parameterGradientDepth;
}




 /*
typedef NS_ENUM(NSUInteger, GuruFxDebugMenuItem) {
	DebugItem_Main = 0,
	DebugItem_ToggleUnhide = 2,
	DebugItem_ToggleShow = 3,
	DebugItem_ToggleMenu = 5,
	DebugItem_RemoveDebug = 7,
	DebugItem_AddParam = 8,
	DebugItem_RemoveParam = 9,
};

- (BOOL)debugUnhide:(BOOL)active
{
	id<FxDynamicParameterAPI_v3> dynamicAPIv3 = self.apiManager.dynamicParamAPIv3;
	id<FxParameterRetrievalAPI_v6> paramGetAPIv6 = self.apiManager.paramGetAPIv6;
	id<FxParameterSettingAPI_v5> paramSetAPIv5 = self.apiManager.paramSetAPIv5;
	
	
	int numParams = dynamicAPIv3.parameterCount;
	
	for(int i = 0; i < numParams; i++) {
		FxParameterId pid = [dynamicAPIv3 parameterIDAtIndex:i];
		FxParameterFlags pflags = 0;
		
		if (![paramGetAPIv6 getParameterFlags:&pflags fromParameter:pid])
			return NO;
		
		if (pflags & kFxParameterFlag_NO_DEBUG)
			continue;
		
		BOOL changed = NO;
		if (active && !(pflags & kFxParameterFlag_IN_DEBUG_MODE)) {
			pflags |= kFxParameterFlag_IN_DEBUG_MODE;
			changed = YES;
		} else if (!active && (pflags & kFxParameterFlag_IN_DEBUG_MODE)) {
			pflags &= ~kFxParameterFlag_IN_DEBUG_MODE;
			changed = YES;
		}
		
		if (changed && ![paramSetAPIv5 setParameterFlags:pflags toParameter:pid])
			return NO;
	}
		
	[self.apiManager.dynamicParamAPIv3 setPopupMenuParameter:kFxParameterId_DebugMenu entries: [GuruFxPluginInfo localizeObject:[self debugMenuItems:active].localize] defaultValue:0];
	
	return YES;
}

- (BOOL)isDebugUnhiding
{
	FxParameterFlags unhideFlags = 0;
	
	if (![self.apiManager.paramGetAPIv6 getParameterFlags:&unhideFlags fromParameter:kFxParameterId_DebugMenu])
		return NO;
	return (unhideFlags & kFxParameterFlag_DEBUG_UNHIDE) != 0;
}


- (BOOL)manageDebuggerController:(FxParameterId)paramID
						  atTime:(CMTime)time
						   error:(NSError * _Nullable * _Nullable)error
{
	int selection = -1;
	
	if (![self.apiManager.paramGetAPIv6 getIntValue:&selection fromParameter:paramID atTime:time])
		return NO;
	
	if (!self.hasDebugActivator && selection >= DebugItem_ToggleShow) {
		selection += 1;
	}
	
	switch(selection) {
		case DebugItem_Main: // Main Item
			break;
		case DebugItem_ToggleUnhide:
			if (![self debugUnhide:!self.isDebugUnhiding]) {
				return NO;
			}
			break;
		case DebugItem_ToggleShow:
			{
				FxParameterFlags activatorFlags = 0;
				
				[self.apiManager.paramGetAPIv6 getParameterFlags:&activatorFlags fromParameter:kFxParameterId_DebugActivator];
				activatorFlags ^= kFxParameterFlag_HIDDEN;
				[self.apiManager.paramSetAPIv6 setParameterFlags:activatorFlags toParameter:kFxParameterId_DebugActivator];
			}
			break;
		case DebugItem_ToggleMenu:
			{
				BOOL activator = NO;
				if (![self.apiManager.paramGetAPIv6 getBoolValue:&activator fromParameter:kFxParameterId_DebugActivator atTime:time])
					return NO;
				activator = !activator;
				if (![self.apiManager.paramSetAPIv5 setBoolValue:activator toParameter:kFxParameterId_DebugActivator atTime:time])
					return NO;
				[self setParameterTargetPreset:kFxParameterId_DebugActivator
							   atTime:time
							  options:PresetFlags];
			}
			break;
		case DebugItem_RemoveDebug:
			if (self.hasDebugMenu) {
				if (self.isDebugUnhiding && ![self debugUnhide:NO]) {
					return NO;
				}
				if (self.hasDebugActivator) {
					[self.apiManager.dynamicParamAPIv3 removeParameter:kFxParameterId_DebugActivator];
				}
				NSError *err = [self.apiManager.dynamicParamAPIv3 removeParameter:kFxParameterId_DebugMenu];
				if (err) {
					NSLog(@"ERROR - error removing debug meno %@", err);
					return NO;
				}
			}
			break;
		
		case DebugItem_AddParam:
			{
#define kTempParamId 888
				BOOL success = [self.apiManager.paramCreateAPIv5 addStringParameterWithName:@"Temp Param" parameterID:kTempParamId defaultValue:@"xyz" parameterFlags:kFxParameterFlag_DEFAULT];
				if (!success) {
					NSLog(@"ERROR - could not add temp param");
					return NO;
				}
				FxParameterFlags flags = 0;
				[self.apiManager.paramGetAPIv6 getParameterFlags:&flags fromParameter:kTempParamId];
				flags |= 0;
				[self.apiManager.paramSetAPIv5 setParameterFlags:flags toParameter:kTempParamId];
			}
			break;
		case DebugItem_RemoveParam:
			{
				NSError *err = [self.apiManager.dynamicParamAPIv3 removeParameter:kTempParamId];
				if (err) {
					NSLog(@"ERROR - could not remove param %@", err);
					return NO;
				}
			}
			break;
	}
	
	return YES;
}


- (NSArray<NSString*>*)debugMenuItems:(BOOL)unhide
{
	NSMutableArray *menuItems = [NSMutableArray arrayWithCapacity:20];
	
	[menuItems addObject:@"GuruFx::DebugMenu::MainItem"];
	[menuItems addObject:@"-"];
	[menuItems addObject:unhide ? @"GuruFx::DebugMenu::ToggleUnhideOn": @"GuruFx::DebugMenu::ToggleUnhideOff"]; // map to debug menu unused flag?  like collapsed or ...
	
	if (self.hasDebugActivator) {
		[menuItems addObject:@"GuruFx::DebugMenu::ToggleDebugToggle"];
	}
	[menuItems addObject:@"-"];
	[menuItems addObject:@"GuruFx::DebugMenu::ToggleDebugMenu"];
	[menuItems addObject:@"-"];
	[menuItems addObject:@"GuruFx::DebugMenu::RemoveDebugMenu"];
	[menuItems addObject:@"Add Param"];
	[menuItems addObject:@"Remove Param"];
	
	return [menuItems copy];
}
*/


@end
