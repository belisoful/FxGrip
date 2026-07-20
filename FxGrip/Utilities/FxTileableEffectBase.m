//
//  FxTileableEffectBase.m
//  FxTileableEffectBase
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#import "FxTileableEffectBase.h"
#import "NSCoder+FxPlug.h"
#import "FxGripAPIAccessing.h"
#import "FxTileableEffectBase+Notifications.h"
#import "FxTileableEffectBase+Extensions.h"
#import "FxTileableEffectBase+Parameters.h"
#import "FxTileableEffectBase+PluginProperties.h"
#import "FxTileableEffectBase+Versioning.h"
#import "FxAPINotifications.h"
#import <BEFoundation/NSString+BExtension.h>
#import "FxGripAPIAccessing.h"
#import "NSDictionary+FxTileableEffect.h"
#import <BEFoundation/BEMutable.h>
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import "FxGripParameterData.h"

#import "FxGripPluginInfo.h"
#import "FxGripInstanceTracker.h"
#import "FxGrip_ARC.h"


@implementation FxTileableEffectBase
{
	NSMutableDictionary<NSNumber*, id<FxParameter>> *__parameters;
	NSDictionary<NSNumber*, NSDictionary*> *__configParameters;
	id _notifierObservers[5];
}

//effect properties
@synthesize addedParameters = _addedParameters;
@synthesize finishedProperties = _finishedProperties;
@synthesize needsFullBuffer = _needsFullBuffer;
@synthesize variesWhenParamsAreStatic = _variesWhenParamsAreStatic;
@synthesize changesOutputSize = _changesOutputSize;
@synthesize mayRemapTime = _mayRemapTime;
@synthesize usesNonmatchingTextureLayout = _usesNonmatchingTextureLayout;
@synthesize drawsInScreenSpace = _drawsInScreenSpace;
@synthesize desiredProcessingColorInfo = _desiredProcessingColorInfo;
@synthesize pixelTransformSupport = _pixelTransformSupport;

@synthesize extensions = _extensions;
@synthesize parameters = _parameters;
//
@synthesize defaultFontName = _defaultFontName;

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//	@required
//---------------------------------------------------------

- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager;
{
    self = [super init];
    if (self != nil)
    {
		__typeToClassMap = NSMutableDictionary.new;
		
		_apiManager = [[FxGripAPIAccessing alloc] initWithAPIManager:apiManager effect:self];
		_pluginUUID = _apiManager.pluginUUID;
		_sessionID = _apiManager.sessionID;
		
		_pluginProperties = [FxGripPluginInfo pluginPropertiesByUUID:_pluginUUID];
		_pluginDisplayName = _pluginProperties[kProPlugPlugIn_DisplayNameProperty];
		_pluginGroupUUID = _pluginProperties[kProPlugPlugIn_GroupUUIDProperty];
		_pluginInfoString = _pluginProperties[kProPlugPlugIn_InfoStringProperty];
		
		_defaultFontName = self.pluginProperties.pluginDefaultFontName;
		if (!_defaultFontName) {
			_defaultFontName = kFxParameterType_FontNameDefault;
		}
		_extKey = FxTileableEffectExtKey;
		_finishedProperties = NO;
		
		// Default Property Values
		_needsFullBuffer = NO;
		_variesWhenParamsAreStatic = NO;
		_changesOutputSize = YES;
		_mayRemapTime = YES;
		_usesNonmatchingTextureLayout = NO;
		_drawsInScreenSpace = NO;
		_desiredProcessingColorInfo = kFxImageColorInfo_RGB_LINEAR;
		_pixelTransformSupport = kFxPixelTransform_ScaleTranslate;
		
		_addedParameters = NO;
		_finishedSetup = NO;
		_addedToDocument = NO;
		
		__configParameters = NSMutableDictionary.new;
		__parameters = NSMutableDictionary.new;
		_parameters = nil;
		
		// Parameter Capture
		// We don't use normal object selector for observer because subclasses
		//	 should have full management over that.
		// Thus we use a block to notify the method indirectly.
		
		
		
		_notifierObservers[0] = [self.notifier addObserverForName:FxNotifyAPI_ParameterAddPreName object:self priority:-18 queue:nil usingBlock:^(NSNotification *note) {
			// Add initial parameter configuration information
			// like gradient sample size and type
			[self notifyParameterAddPre:note];
		}];
		_notifierObservers[1] = [self.notifier addObserverForName:FxNotifyAPI_ParameterAddName object:self priority:-18 queue:nil usingBlock:^(NSNotification *note) {
			[self notifyParameterAdd:note];
		}];
		
		_notifierObservers[2] = [self.notifier addObserverForName:FxTileableEffectAddedToDocumentName object:self priority:-17 queue:nil usingBlock:^(NSNotification *note) {
			[self notifyParameterLoad:note];
		}];
		_notifierObservers[3] = [self.notifier addObserverForName:FxTileableEffectFlushName object:self priority:-14 queue:nil usingBlock:^(NSNotification *note) {
			[self notifyParametersFlush:note];
		}];
		_notifierObservers[4] = [self.notifier addObserverForName:FxNotifyAPI_ParameterRemoveName object:self priority:-18 queue:nil usingBlock:^(NSNotification *note) {
			[self notifyParameterRemove:note];
		}];
		
		//Initialize extensions
		[self loadTypeToClassMap];
		_extensions = [self initializeExtensions];
		[self.notifier postNotificationName:FxTileableEffectInitName object:self userInfo:@{FxTileableEffectInitAPIManagerKey:_apiManager}];
    }
    return self;
}

- (void)dealloc
{
	if (_addedToDocument) {
		[self.notifier postNotificationName:FxTileableEffectRemovedFromDocumentName object:self reverse:YES];
		_addedToDocument = NO;
	}
	[self.notifier postNotificationName:FxTileableEffectUnloadName object:self reverse:YES];
	
	for(id<FxExtension> extension in _extensions) {
		[self.notifier removeObserver:extension];
	}
	
	//remove all notifications to the subclass
	for(int i = 0; i < sizeof(_notifierObservers) / sizeof(id); i++) {
		[self.notifier removeObserver:_notifierObservers[i]];
	}
	NARC_RELEASE(__parameters);
	NARC_RELEASE(_parameters);
	NARC_RELEASE(_extensions);
	NARC_RELEASE(__configParameters);
	NARC_RELEASE(__typeToClassMap);
	
	SUPER_DEALLOC();
}

- (NSPriorityNotificationCenter *)notifier
{
	return [NSPriorityNotificationCenter defaultCenter];
}




#pragma mark Sub-class implementation Methods

- (nullable NSMutableArray<id<FxExtension>>*)loadExtensions
{
	NSMutableArray<id<FxExtension>> *extensions = [NSMutableArray.alloc initWithCapacity:13];
	
	// FxTileableEffectBase does implements FxExtensionBase but not FxExtension.
	// If a subclass implements it, then activate.
	if ([self conformsToProtocol:@protocol(FxExtension)]) {
		[extensions addObject:(id<FxExtension>)self];
	}
	
	if (self.isTrackingInstances) {
		id<FxExtension> tracker = self.newFxInstanceTracker;
		[extensions addObject:tracker];
	}
	/*
	if (self.hasDebugMenu) {
		id<FxExtension> tracker = self.newFxDebugMenu;
		[extensions addObject:tracker];
	}
	 if (self.isInternationalized) {
		 id<FxExtension> tracker = self.newFxI18N;
		 [extensions addObject:tracker];
	 }
	 #ifdef DEBUG
	 if (self.isRegression) {
		 id<FxExtension> tracker = self.newFxRegression;
		 [extensions addObject:tracker];
	 }
	 #endif
	 */
	return extensions;
}

- (NSMutableArray<NSDictionary *> *)parametersConfiguration
{
	NSMutableArray<NSDictionary *> *parameters = NSMutableArray.new;
	
	//
	
	return parameters;
}



- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError*_Nonnull*_Nullable)error
{
	BOOL success = YES;
	
	if (!__configParameters) {
		return NO;
	}
	
	for (NSDictionary* parameter in __configParameters) {
		FxParameterId pid = parameter.parameterID;
		FxParameterType ptype = parameter.parameterType;
		if (parameter.parameterParentID != groupID || __parameters[@(pid)]) {
			continue;
		}
		Class cls = [self parameterClassWithType:ptype];
		success = [cls addParameter:parameter toEffect:self] && success;
	}
	
	return success;
}


#pragma mark Effect Properties

- (void)setNeedsFullBuffer:(BOOL)needsFullBuffer
{
	if (!_finishedProperties) {
		_needsFullBuffer = needsFullBuffer;
	}
}

- (void)setVariesWhenParamsAreStatic:(BOOL)variesWhenParamsAreStatic
{
	if (!_finishedProperties) {
		_variesWhenParamsAreStatic = variesWhenParamsAreStatic;
	}
}


- (void)setChangesOutputSize:(BOOL)changesOutputSize
{
	if (!_finishedProperties) {
		_changesOutputSize = changesOutputSize;
	}
}

- (void)setDesiredProcessingColorInfo:(FxImageColorInfo)desiredProcessingColorInfo
{
	if (!_finishedProperties) {
		_desiredProcessingColorInfo = desiredProcessingColorInfo;
	}
}

-(void)setMayRemapTime:(BOOL)mayRemapTime
{
	if (!_finishedProperties) {
		_mayRemapTime = mayRemapTime;
	}
}

-(void)setUsesNonmatchingTextureLayout:(BOOL)usesNonmatchingTextureLayout
{
	if (!_finishedProperties) {
		_usesNonmatchingTextureLayout = usesNonmatchingTextureLayout;
	}
}

-(void)setDrawsInScreenSpace:(BOOL)drawsInScreenSpace
{
	if (!_finishedProperties) {
		_drawsInScreenSpace = drawsInScreenSpace;
	}
}

-(void)setPixelTransformSupport:(FxPixelTransformSupport)pixelTransformSupport
{
	if (!_finishedProperties) {
		_pixelTransformSupport = pixelTransformSupport;
	}
}

#pragma mark FxTileableEffect Implementation

//---------------------------------------------------------
// properties
//
// This method should return an NSDictionary defining the
// properties of the effect.
//	@required
//---------------------------------------------------------

- (BOOL)properties:(NSDictionary * _Nonnull *)properties
             error:(NSError * _Nullable *)error
{
	if (properties == nil) {
		//No reference for properties
		if (error != nil) {
			*error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxError_InvalidParameter
									 userInfo:@{ NSLocalizedFailureReasonErrorKey :
													 @"properties pointer is nil" }];
		}
		return NO;
	}
	
	NSUInteger initCount = 10;
	NSDictionary *effectProperties = nil;
	
	if (*properties) {
		NSUInteger count = [*properties count];
		if (initCount < count) {
			initCount = count;
		}
	}
	if (self.isEffectPropertiesInInfo) {
		effectProperties = self.pluginProperties.pluginEffectProperties;
		if (effectProperties) {
			NSUInteger count = [effectProperties count];
			if (initCount < count) {
				initCount = count;
			}
		}
	}
	
	NSMutableDictionary *props = NARC_AUTORELEASE([NSMutableDictionary.alloc initWithCapacity:initCount]);
	
	if (effectProperties) {
		// If the effect properties are in the Info.plist
		[props addEntriesFromDictionary:effectProperties];
		effectProperties = nil;
	}
	
	if (*properties) {
		// If there are existing properties
		[props addEntriesFromDictionary:*properties];
	}
	
	// Stop any changes from being made to the properties
	_finishedProperties = YES;
	
	NSNumber *value = [props objectForKey:kFxPropertyKey_NeedsFullBuffer];
	if (value != nil) {
		_needsFullBuffer = [value boolValue];
	} else if (_needsFullBuffer) {// set when not: default @NO  --  aka. when YES
		[props setObject:[NSNumber numberWithBool:_needsFullBuffer] forKey:kFxPropertyKey_NeedsFullBuffer];
	}
	
	value = [props objectForKey:kFxPropertyKey_VariesWhenParamsAreStatic];
	if (value != nil) {
		_variesWhenParamsAreStatic = [value boolValue];
	} else if (_variesWhenParamsAreStatic) { // set when not: default @NO  --  aka. when YES
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
		_desiredProcessingColorInfo = [value unsignedIntValue];
	} else if (_desiredProcessingColorInfo != kFxImageColorInfo_RGB_LINEAR) {
		[props setObject:[NSNumber numberWithUnsignedLong:_desiredProcessingColorInfo] forKey:kFxPropertyKey_DesiredProcessingColorInfo];
	}
	
	value = [props objectForKey:kFxPropertyKey_PixelTransformSupport];
	if (value != nil) {
		_pixelTransformSupport = [value unsignedLongValue];
	} else if (_pixelTransformSupport != kFxPixelTransform_ScaleTranslate) {
		[props setObject:[NSNumber numberWithUnsignedLong:_pixelTransformSupport] forKey:kFxPropertyKey_PixelTransformSupport];
	}
	
	// Process properties by extensions
	NSMutableDictionary *userInfo = @{FxTileableEffectPropertiesKey: props}.mutableCopy;
	[self.notifier postNotificationName:FxTileableEffectPropertiesName object:self userInfo:userInfo];
	props = userInfo.fxEffectProperties;
	
	if (![props isKindOfClass:NSMutableDictionary.class]) {
		NSLog (@"%s Error: Expecting NSMutableDictionary for Effect Properties but got %@.", __func__, props.className);
	}
	if ((*error = userInfo.fxError) && ![*error isKindOfClass:NSError.class]) {
		NSLog (@"%s Error: Error returned from notification is not NSError class but got %@.", __func__, (*error).className);
	}
	
	//Make an immutable copy
	*properties = [props copy];
	
	return YES;
}

//---------------------------------------------------------
// addParametersWithError
//
// This method is where a plug-in defines its list of parameters.
//	@required
//---------------------------------------------------------

- (BOOL)addParametersWithError:(NSError**)error
{
	_addingParameters = YES;
	NSMutableArray<NSMutableDictionary*> *parameters = [self parametersConfiguration].mutableCopyRecursive;
	
	NSMutableDictionary *userInfo = @{FxTileableEffectParametersKey: parameters}.mutableCopy;
	[self.notifier postNotificationName:FxTileableEffectAddParametersName object:self userInfo:userInfo postBlock:^(NSNotification * _Nonnull notification) {
		[FxGripParameterUtility flattenDictionaryParameters:notification.userInfo.fxEffectParameters];
	}];
	
	if ((*error = userInfo.fxError) && ![*error isKindOfClass:NSError.class]) {
		NSLog (@"%s Error: Error returned from notification is not NSError class but %@.", __func__, (*error).className);
	}
	
	parameters = userInfo.fxEffectParameters;
	__configParameters = parameters.copy;
	
	[self addParametersWithGroupID:kFxParameterId_TopLevelGroup error:error];
	
	BOOL success = *error == NULL;
	for(NSNumber *pid in __parameters) {
		id<FxParameter> p = __parameters[pid];
		if ([p respondsToSelector:@selector(validate)]) {
			success = [p validate] && success;
		}
	}
	[self extensionsFlush];
	
	_addingParameters = NO;
	_addedParameters = YES;
	_parameters = nil;
	
	return success;
}


//---------------------------------------------------------
// finishInitialSetup
//
// Wraps up any initialization within Motion.
// No document yet.  Called only once to finalize the initial setup
// @optional
//---------------------------------------------------------

- (BOOL)finishInitialSetup:(NSError * _Nullable *)error
{
	_finishedSetup = YES;
	
	NSMutableDictionary *userInfo = @{}.mutableCopy;
	[self.notifier postNotificationName:FxTileableEffectFinishInitialSetupName object:self userInfo:userInfo];
	
	if ((*error = userInfo.fxError) && ![*error isKindOfClass:NSError.class]) {
		NSLog (@"%s Error: Error returned from notification is not NSError class but %@.", __func__, (*error).className);
	}
	
	return *error == NULL;
}


/*!
	@method     -pluginInstanceAddedToDocument
	@abstract   Notifies your plug-in when it becomes part of user's document.
	@discussion Called when a new plug-in instance is created or a document is loaded and an
				existing instance is deserialized. When the host calls this method, the plug-in is
				a part of the document and the various API objects work as expected.
 	@optional
 */
- (void) pluginInstanceAddedToDocument
{
	_finishedSetup = YES;
	_addedToDocument = YES;
	NSError *error = nil;
	[self checkVersion:&error];
	
	[self.notifier postNotificationName:FxTileableEffectAddedToDocumentName object:self];
	
	[self extensionsFlush];
}

// @optional
- (Class)classForCustomParameterID:(UInt32)parameterID
{
	return nil;
}

// @optional
- (Class)classesForCustomParameterID:(UInt32)parameterID
{
	return nil;
}



// optional
- (BOOL)parameterChanged:(UInt32)paramID
				 atTime:(CMTime)time
				  error:(NSError**)error
{
	NSMutableDictionary *userInfo = @{}.mutableCopy;
	[self.notifier postNotificationName:FxTileableEffectParameterChangedName object:self userInfo:userInfo];
	
	if ((*error = userInfo.fxError) && ![*error isKindOfClass:NSError.class]) {
		NSLog (@"%s Error: Error returned from notification is not NSError class but %@.", __func__, (*error).className);
		return NO;
	} else if (*error) {
		NSLog (@"%s Error: Error returned from Parameter Changed Notification %@", __func__, *error);
		return NO;
	}
	
	*error = [self extensionsFlush];
	
	return *error == NULL;
}

//---------------------------------------------------------
// pluginState:atTime:quality:error
//
// Your plug-in should get its parameter values, do any calculations it needs to
// from those values, and package up the result to be used later with rendering.
// The host application will call this method before rendering. The
// FxParameterRetrievalAPI* is valid during this call. Use it to get the values of
// your plug-in's parameters, then put those values or the results of any calculations
// you need to do with those parameters to render into an NSData that you return
// to the host application. The host will pass it back to you during subsequent calls.
// Do not re-use the NSData; always create a new one as this method may be called
// on multiple threads at the same time.
//	@required
//---------------------------------------------------------

- (BOOL)pluginState:(NSData**)pluginState
             atTime:(CMTime)renderTime
            quality:(FxQuality)qualityLevel
              error:(NSError**)error
{
	NSKeyedArchiver *state = [NSKeyedArchiver.alloc initRequiringSecureCoding:true];
	state.outputFormat = NSPropertyListBinaryFormat_v1_0;
	
	state.renderTime = renderTime;
	state.qualityLevel = qualityLevel;
	
	// If the child has a pluginStateWithCoder
	if ([self conformsToProtocol:@protocol(FxTileableEffectCoderState)]) {
		if (![self pluginCoder:state atTime:renderTime quality:qualityLevel error:error] || (error && *error)) {
			return NO;
		}
	}
	
	NSMutableDictionary *userInfo = @{FxTileableEffectPluginStateCoderKey: state}.mutableCopy;
	[self.notifier postNotificationName:FxTileableEffectPluginStateName object:self userInfo:userInfo];
	
	if ((*error = userInfo.fxError) && ![*error isKindOfClass:NSError.class]) {
		NSLog (@"%s Error: Error returned from notification is not NSError class but %@.", __func__, (*error).className);
		return NO;
	} else if (*error) {
		NSLog (@"%s Error: Error returned from Parameter Changed Notification %@", __func__, *error);
		return NO;
	}
	
	[state finishEncoding];
	*pluginState = state.encodedData;
	
	return pluginState != nil && !(error && *error);
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
// @optional
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
	
	if ([self conformsToProtocol:@protocol(FxTileableEffectCoderState)]) {
		
		NSKeyedUnarchiver *state = NARC_AUTORELEASE([NSKeyedUnarchiver.alloc initForReadingFromData:pluginState
																			 error:error]);
		if (*error || !state) {
			return NO;
		}
		state.renderTime = renderTime;
		
		NSMutableArray *mutableInputImageRequests = NARC_AUTORELEASE([NSMutableArray.alloc initWithCapacity:5]);
		if (![self scheduleInputs:&mutableInputImageRequests
						withCoder:state
						   atTime:renderTime
							error:error]) {
			return NO;
		}
		
		NSMutableDictionary *userInfo = @{FxTileableEffectPluginStateCoderKey: state}.mutableCopy;
		[self.notifier postNotificationName:FxTileableEffectScheduleInputsName object:self userInfo:userInfo];
		
		if ((*error = userInfo.fxError) && ![*error isKindOfClass:NSError.class]) {
			NSLog (@"%s Error: Error returned from notification is not NSError class but %@.", __func__, (*error).className);
			return NO;
		} else if (*error) {
			NSLog (@"%s Error: Error returned from Parameter Changed Notification %@", __func__, *error);
			return NO;
		}
		
		if (mutableInputImageRequests) {
			*inputImageRequests = [mutableInputImageRequests copy];
		}
	}
	return YES;
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
//	@required
//---------------------------------------------------------

- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
                sourceImages:(NSArray<FxImageTile *> *)sourceImages
            destinationImage:(nonnull FxImageTile *)destinationImage
                 pluginState:(NSData *)pluginState
                      atTime:(CMTime)renderTime
                       error:(NSError * _Nullable *)error
{
	/*
	 if (isGenerator) {  // This is a generator so always use the output image's pixel bounds
  		*destinationImageRect = destinationImage.imagePixelBounds;
	 }
	 */
	
	NSKeyedUnarchiver *state = NARC_AUTORELEASE([NSKeyedUnarchiver.alloc initForReadingFromData:pluginState
																		 error:error]);
	if (*error || !state) {
		return NO;
	}
	
	if ([self conformsToProtocol:@protocol(FxTileableEffectCoderState)]) {
		state.renderTime = renderTime;
	}
	
	NSMutableDictionary *userInfo = @{FxTileableEffectPluginStateCoderKey: state}.mutableCopy;
	[self.notifier postNotificationName:FxTileableEffectDestinationImageRectName object:self userInfo:userInfo];
	
	if ((*error = userInfo.fxError) && ![*error isKindOfClass:NSError.class]) {
		NSLog (@"%s Error: Error returned from notification is not NSError class but %@.", __func__, (*error).className);
		return NO;
	} else if (*error) {
		NSLog (@"%s Error: Error returned from Parameter Changed Notification %@", __func__, *error);
		return NO;
	}
    
    return YES;
    
}

//---------------------------------------------------------
// sourceTileRect:sourceImageIndex:sourceImages:destinationTileRect:destinationImage:pluginState:atTime:error
//
// Calculate tile of the source image we need
// to render the given output tile.
//	@required
//---------------------------------------------------------

- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
      sourceImageIndex:(NSUInteger)sourceImageIndex
          sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
      destinationImage:(FxImageTile *)destinationImage
           pluginState:(NSData *)pluginState
                atTime:(CMTime)renderTime
                 error:(NSError * _Nullable *)error
{
	/*
	 if (isGenerator) {  // This is a generator so always use the output image's pixel bounds
		*sourceTileRect = kFxRect_Empty;
	 }
	 */
	if (!self.changesOutputSize) {
		*sourceTileRect = destinationTileRect;
		return YES;
	}
	
	if ([self conformsToProtocol:@protocol(FxTileableEffectCoderState)]) {
		// coder.imageRefs = sourceImages;
	}
	
	// @todo, is this different for screen space drawing?
	
	int srcIndex = -1;
	
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
	
	NSKeyedUnarchiver *state = NARC_AUTORELEASE([NSKeyedUnarchiver.alloc initForReadingFromData:pluginState
																		 error:error]);
	if (*error || !state) {
		return NO;
	}
	
	if ([self conformsToProtocol:@protocol(FxTileableEffectCoderState)]) {
		state.renderTime = renderTime;
	}
	
	NSMutableDictionary *userInfo = @{FxTileableEffectPluginStateCoderKey: state}.mutableCopy;
	[self.notifier postNotificationName:FxTileableEffectSourceTileRectName object:self userInfo:userInfo];
	
	if ((*error = userInfo.fxError) && ![*error isKindOfClass:NSError.class]) {
		NSLog (@"%s Error: Error returned from notification is not NSError class but %@.", __func__, (*error).className);
		return NO;
	} else if (*error) {
		NSLog (@"%s Error: Error returned from Parameter Changed Notification %@", __func__, *error);
		return NO;
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
//	@required
//---------------------------------------------------------

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
                  sourceImages:(NSArray<FxImageTile *> *)sourceImages
                   pluginState:(NSData *)pluginState
                        atTime:(CMTime)renderTime
                         error:(NSError * _Nullable *)error
{
	if (pluginState == nil) {
		NSLog(@"%s Error No pluginState", __func__);
		NSDictionary*   userInfo    = @{ NSLocalizedDescriptionKey : @"Invalid plugin state received from host" };
		if (error) {
			*error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxError_InvalidParameter
									 userInfo:userInfo];
		}
		return NO;
	}
	
	if (destinationImage.ioSurface == nil)
	{
		NSLog(@"%s Error: No destinationImage ioSurface", __func__);
		NSDictionary*   userInfo = @{ NSLocalizedDescriptionKey : @"Invalid No Destination ioSurface" };
		if (error) {
			*error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxError_InvalidParameter
									 userInfo:userInfo];
		}
		return NO;
	}
    
	
	if ([self conformsToProtocol:@protocol(FxTileableEffectCoderState)]) {
		
		NSKeyedUnarchiver *state = NARC_AUTORELEASE([NSKeyedUnarchiver.alloc initForReadingFromData:pluginState
																			  error:error]);
		if (*error || !state) {
			return NO;
		}
		
		state.renderTime = renderTime;
		
		BOOL success =  [self renderDestinationImage:destinationImage
							   sourceImages:sourceImages
								pluginCoder:state
									 atTime:renderTime
									  error:error];
		if (success) {
			NSMutableDictionary *userInfo = @{FxTileableEffectPluginStateCoderKey: state}.mutableCopy;
			[self.notifier postNotificationName:FxTileableEffectRenderDestinationImageName object:self userInfo:userInfo];
			
			if ((*error = userInfo.fxError) && ![*error isKindOfClass:NSError.class]) {
				NSLog (@"%s Error: Error returned from notification is not NSError class but %@.", __func__, (*error).className);
				success = NO;
			} else if (*error) {
				NSLog (@"%s Error: Error returned from Parameter Changed Notification %@", __func__, *error);
				success = NO;
			}
		}
		return success;
	}
	return YES;
}


#pragma mark Parameters


- (NSDictionary<NSNumber*, id<FxParameter>> *)parameters
{
	if (!_parameters) {
		_parameters = [__parameters copy];
	}
	return _parameters;
}

- (UInt32)parameterCount
{
	return [[self.apiManager apiForProtocol:@protocol(FxDynamicParameterAPI_v3)] parameterCount];
}


// This gives GuruFxTileableEffect the ability to [] its parameters by parameter ID.
//	Negative values are an index into the arrey of parameters, starting with 0 and going to (-n + 1).
// Thus to access by index, [0] is the first parameter, [-1] is the second, [-2] is the third.  Until nil is returned.
// 0 is an invalid parameter ID.  so by iterating 0 backwards
- (id<FxParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index
{
	if (index <= 0) {
		index = -index;
		id<FxDynamicParameterAPI_v3> dyParam = [self.apiManager apiForProtocol:@protocol(FxDynamicParameterAPI_v3)];
		
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
		return [_extensions objectForKey:key];
	}
	return nil;
}


- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *) enumerationState
								   objects: (id __unsafe_unretained []) stackBuffer
									 count: (NSUInteger) len
{
	return [_parameters countByEnumeratingWithState:enumerationState objects:stackBuffer count:len];
}

#pragma mark API Parameters


- (void)notifyParameterAddPre:(NSNotification*)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	int pid = parameter.parameterID;
	if (!pid) {
		return;
	}
	
	NSDictionary *initialParam = __configParameters[@(pid)];
	if (!initialParam) {
		return;
	}
	
	//Pass through:
	//	- Extension Parameter
	if (initialParam.parameterExtensionKey) {
		parameter[kFxParameterProperty_ExtensionKey] = initialParam.parameterExtensionKey;
	}
	FxParameterType ptype = parameter.parameterType;
	
	//	- type dependent variables Parameter
	switch (ptype) {
		case FxParameterType_Gradient:
			if (initialParam.parameterGradientSamples) {
				notification.mutableUserInfo[kFxParameterProperty_GradientSamples] = initialParam.parameterGradientSamples;
				notification.mutableUserInfo[kFxParameterProperty_GradientDepth] = @(initialParam.parameterGradientDepth);
			}
			break;
		default:
			break;
	}
}

- (void)notifyParameterAdd:(NSNotification*)notification
{
	[self constructParameter:notification.userInfo];
}

- (void)notifyParameterLoad:(NSNotification*)notification
{
	if (self.addedParameters) {
		return;
	}
	
	_addingParameters = YES;
	// If Parameters aren't added, they're loaded
	if (!__configParameters) {
		__configParameters = self.parameterData.data;
	}
	[self reconstructParametersWithGroupID:kFxParameterId_TopLevelGroup];
	
	_addingParameters = NO;
	_addedParameters = YES;
}

- (BOOL)reconstructParametersWithGroupID:(FxParameterId)groupID
{
	for(NSNumber* pid in __configParameters ) {
		NSDictionary *parameter = __configParameters[pid];
		
		if (parameter.parameterParentID != groupID || __parameters[pid]) {
			continue;
		}
		[self constructParameter:parameter];
		
		if (parameter.parameterType == FxParameterType_Group) {
			[self reconstructParametersWithGroupID:pid.intValue];
		}
	}
	return YES;
}

- (void)constructParameter:(NSDictionary*)parameter
{
	id<FxParameter> paramObj = [self parameterForDictionary:parameter];
	
	__parameters[@(parameter.parameterID)] = paramObj;
	NARC_RELEASE(_parameters);
	
	FxParameterId parentID = paramObj.parameterParentID;
	if (parentID) {
		id<FxSubParameters> parent = (id<FxSubParameters>)self[parentID];
		if ([parent conformsToProtocol:@protocol(FxSubParameters)]) {
			[((id<FxSubParameters>)self[parentID]) addChildParameter:paramObj];
		} else {
			NSLog(@"Error: %d Has parent %d that does not contain sub parameters", paramObj.parameterID, parentID);
		}
	}
}


- (void)notifyParameterRemove:(NSNotification*)notification
{
	NSDictionary *parameter = notification.userInfo.fxParameter;
	FxParameterId pid = parameter.parameterID;
	[__parameters removeObjectForKey:@(pid)];
	_parameters = nil;
}

- (void)notifyParametersFlush:(NSNotification*)notification
{
	for(NSNumber *key in __parameters) {
		[__parameters[key] parameterFlush];
	}
}

@end
