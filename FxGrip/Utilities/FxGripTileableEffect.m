//
//  FxGripTileableEffect.m
//  FxGripTileableEffect
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#import "FxGripTileableEffect.h"
#import "NSCoder+FxPlug.h"
#import "FxGripAPIAccessing.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripTileableEffect+Extensions.h"
#import "FxGripTileableEffect+Parameters.h"
#import "FxGripTileableEffect+PluginProperties.h"
#import "FxGripTileableEffect+Versioning.h"
#import "FxGripAPINotifications.h"
#import <BEFoundation/NSString+BExtension.h>
#import "FxGripAPIAccessing.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import <BEFoundation/BEMutable.h>
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import "FxGripParameterData.h"

#import "FxGripPluginInfo.h"
#import "FxGripInstanceTracker.h"
#import "FxGripParameterUtility.h"
#import "FxGripMetaManager.h"
#import "FxGripMeta.h"
#import "FxGripDebugMenu.h"
#import "FxGripI18N.h"
#import "FxGripRegression.h"
#import "FxGripGoogleAnalytics.h"
#import "FxGripFxFactory.h"
#import "FxGripAnalysis.h"
#import "FxGripTileableGenerator.h"
#import "FxGripImageRefParameter.h"
#import "FxGripMTLDeviceCache.h"
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import "FxGrip_ARC.h"
#import <FxPlug/FxOnScreenControl.h>
#import <objc/runtime.h>
#import <objc/message.h>


@implementation FxGripTileableEffect
{
	NSMutableDictionary<NSNumber*, id<FxParameter>> *__parameters;
	NSDictionary<NSNumber*, NSDictionary*> *__configParameters;
	NSArray<NSNumber*> *__configParameterOrder;	// creation order; drives host add order
	id _notifierObservers[7];
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
		_extKey = FxGripTileableEffectExtKey;
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
		//
		// The blocks capture self weakly: the center retains the block, so a strong
		// capture would keep the effect alive for the process lifetime and dealloc
		// (which removes these observers) could never run. A nil weakSelf after
		// teardown makes each block a no-op.
		__weak typeof(self) weakSelf = self;

		_notifierObservers[0] = [self.notifier addObserverForName:FxGripNotifyAPI_ParameterAddPreName object:self priority:-18 queue:nil usingBlock:^(NSNotification *note) {
			// Add initial parameter configuration information
			// like gradient sample size and type
			[weakSelf notifyParameterAddPre:note];
		}];
		_notifierObservers[1] = [self.notifier addObserverForName:FxGripNotifyAPI_ParameterAddName object:self priority:-18 queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf notifyParameterAdd:note];
		}];

		_notifierObservers[2] = [self.notifier addObserverForName:FxGripTileableEffectAddedToDocumentName object:self priority:-17 queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf notifyParameterLoad:note];
		}];
		_notifierObservers[3] = [self.notifier addObserverForName:FxGripTileableEffectFlushName object:self priority:-14 queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf notifyParametersFlush:note];
		}];
		_notifierObservers[5] = [self.notifier addObserverForName:FxGripTileableEffectParameterPolicyName object:self priority:-18 queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf notifyParameterPolicy:note];
		}];
		_notifierObservers[6] = [self.notifier addObserverForName:FxGripTileableEffectAddGroupParametersName object:self priority:-18 queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf notifyAddGroupParameters:note];
		}];
		_notifierObservers[4] = [self.notifier addObserverForName:FxGripNotifyAPI_ParameterRemoveName object:self priority:-18 queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf notifyParameterRemove:note];
		}];
		
		//Initialize extensions
		[self loadTypeToClassMap];
		_extensions = [self initializeExtensions];
		[self.notifier postNotificationName:FxGripTileableEffectInitName object:self userInfo:@{FxGripTileableEffectInitAPIManagerKey:_apiManager}];
    }
    return self;
}

- (void)dealloc
{
	// Teardown does NOT post RemovedFromDocument/Unload here: the notification retains
	// its object, and an autoreleased notification carrying a mid-dealloc self is a
	// resurrection over-release when the pool drains. The posts also matched no
	// observer — the center's object filter is weak and reads nil during dealloc.
	// Extensions that hold effect-keyed state deregister in their own dealloc instead
	// (see FxGripInstanceTracker), which is bounded by this effect's lifetime.
	_addedToDocument = NO;

	for(id<FxGripExtension> extension in _extensions.allValues) {
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
	NARC_RELEASE(__configParameterOrder);
	NARC_RELEASE(__typeToClassMap);
	
	SUPER_DEALLOC();
}

- (NSPriorityNotificationCenter *)notifier
{
	return [NSPriorityNotificationCenter defaultCenter];
}

- (nullable FxGripTileableEffect *)effectBase
{
	return self;
}




#pragma mark Sub-class implementation Methods

- (nullable NSMutableArray<id<FxGripExtension>>*)loadExtensions
{
	NSMutableArray<id<FxGripExtension>> *extensions = [NSMutableArray.alloc initWithCapacity:13];
	
	// FxGripTileableEffect does implements FxGripExtensionBase but not FxGripExtension.
	// If a subclass implements it, then activate.
	if ([self conformsToProtocol:@protocol(FxGripExtension)]) {
		[extensions addObject:(id<FxGripExtension>)self];
	}
	
	if (self.isTrackingInstances) {
		id<FxGripExtension> tracker = self.newFxInstanceTracker;
		[extensions addObject:tracker];
	}

	if (self.pluginProperties.pluginManageParameterData) {
		[extensions addObject:self.newParameterDataExtension];
	}

	if (self.pluginProperties.pluginManageMeta) {
		[extensions addObject:self.newMetaExtension];
	}

	// An effect that declares FxAnalyzer conformance gets per-frame analysis storage.
	if ([self conformsToProtocol:@protocol(FxAnalyzer)]) {
		[extensions addObject:self.newAnalysisExtension];
	}

	// The following extensions are opt-in through plugin properties (default off), matching
	// the gates above. They stay inert for a plugin that does not request them.
	if (self.hasDebugMenu) {
		[extensions addObject:self.newDebugMenuExtension];
	}
	if (self.isInternationalized) {
		[extensions addObject:self.newI18NExtension];
	}
	if (self.isGoogleAnalyticsInstalled) {
		[extensions addObject:self.newGoogleAnalyticsExtension];
	}
	if (self.pluginProperties.pluginFxFactory) {
		[extensions addObject:self.newFxFactoryExtension];
	}
#ifdef DEBUG
	if (self.isRegression) {
		[extensions addObject:self.newRegressionExtension];
	}
#endif
	return extensions;
}

- (NSMutableArray<NSDictionary *> *)parametersConfiguration
{
	NSArray<NSDictionary *> *declared = self.pluginProperties.pluginParameters;
	if (declared != nil) {
		return [declared mutableCopy];
	}
	return NSMutableArray.new;
}



- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError*_Nonnull*_Nullable)error
{
	BOOL success = YES;
	
	if (!__configParameters) {
		return NO;
	}
	
	NSArray<NSNumber*> *orderedPids = __configParameterOrder ?: __configParameters.allKeys;
	for (NSNumber *pidKey in orderedPids) {
		NSDictionary *parameter = __configParameters[pidKey];
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
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
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
	NSMutableDictionary *userInfo = @{FxGripTileableEffectPropertiesKey: props}.mutableCopy;
	[self.notifier postNotificationName:FxGripTileableEffectPropertiesName object:self userInfo:userInfo];
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
	
	NSMutableDictionary *userInfo = @{FxGripTileableEffectParametersKey: parameters}.mutableCopy;
	[self.notifier postNotificationName:FxGripTileableEffectAddParametersName object:self userInfo:userInfo postBlock:^(NSNotification * _Nonnull notification) {
		[FxGripParameterUtility flattenDictionaryParameters:notification.userInfo.fxEffectParameters];
		// Runs on the flattened list so extension-added parameters participate.
		[FxGripParameterUtility applyTargetPresetDefaults:notification.userInfo.fxEffectParameters
											pluginPresets:self.pluginProperties.pluginPresets];
	}];
	
	if ((*error = userInfo.fxError) && ![*error isKindOfClass:NSError.class]) {
		NSLog (@"%s Error: Error returned from notification is not NSError class but %@.", __func__, (*error).className);
	}
	
	parameters = userInfo.fxEffectParameters;

	NSMutableDictionary<NSNumber*, NSDictionary*> *configParameters = NSMutableDictionary.new;
	NSMutableArray<NSNumber*> *configOrder = NSMutableArray.new;
	for (NSDictionary *parameter in parameters) {
		NSNumber *pid = @(parameter.parameterID);
		if (!configParameters[pid]) {
			[configOrder addObject:pid];
		}
		configParameters[pid] = parameter;
	}
	__configParameters = configParameters.copy;
	__configParameterOrder = configOrder.copy;
	
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
	[self.notifier postNotificationName:FxGripTileableEffectFinishInitialSetupName object:self userInfo:userInfo];
	
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
	
	[self.notifier postNotificationName:FxGripTileableEffectAddedToDocumentName object:self];
	
	[self extensionsFlush];
}

// @optional
- (Class)classForCustomParameterID:(UInt32)parameterID
{
	if (parameterID == kFxParameterId_InstanceMeta) {
		return FxGripMetaManager.class;
	}
	return nil;
}

// @optional
- (NSSet<Class>*)classesForCustomParameterID:(UInt32)parameterID
{
	if (parameterID == kFxParameterId_InstanceMeta) {
		NSMutableSet<Class> *classes = [NSMutableSet setWithObject:FxGripMetaManager.class];
		[classes unionSet:FxGripMetaManager.classesForParameter.set];
		return classes.copy;
	}
	// The parameter class registered for the configured type declares its value classes.
	NSDictionary *configuration = [self configurationForParameter:parameterID];
	Class parameterClass = [self parameterClassWithTypeString:configuration[kFxParameterProperty_Type]];
	if ([parameterClass respondsToSelector:@selector(customValueClasses)]) {
		return [parameterClass customValueClasses];
	}
	return nil;
}



// optional
- (BOOL)parameterChanged:(UInt32)paramID
				 atTime:(CMTime)time
				  error:(NSError**)error
{
	NSMutableDictionary *userInfo = @{}.mutableCopy;
	userInfo[FxGripTileableEffectParameterChangedIDKey] = @(paramID);
	NSDictionary *timeDict = (__bridge_transfer NSDictionary *)CMTimeCopyAsDictionary(time, kCFAllocatorDefault);
	if (timeDict) {
		userInfo[FxGripTileableEffectParameterChangedAtTimeKey] = timeDict;
	}
	[self.notifier postNotificationName:FxGripTileableEffectParameterChangedName object:self userInfo:userInfo];
	
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


#pragma mark Parameter Clicks

// Trampoline for the synthesized button selectors. The host performs the zero-argument
// selector registered at parameter creation; the parameter ID is decoded from _cmd.
static void FxGripParameterClickTrampoline(id self, SEL _cmd)
{
	FxParameterId parameterID = 0;
	if ([FxGripParameterUtility getParameterID:&parameterID fromClickSelector:_cmd]) {
		[(FxGripTileableEffect*)self parameterClicked:parameterID];
	}
}

+ (BOOL)resolveInstanceMethod:(SEL)sel
{
	FxParameterId parameterID = 0;
	if ([FxGripParameterUtility getParameterID:&parameterID fromClickSelector:sel]) {
		class_addMethod(self, sel, (IMP)FxGripParameterClickTrampoline, "v@:");
		return YES;
	}
	return [super resolveInstanceMethod:sel];
}

- (NSDictionary *_Nullable)configurationForParameter:(FxParameterId)parameterID
{
	return __configParameters[@(parameterID)];
}

/*! Applies the effect's parameter policy to a declared configuration: a font menu without a
	declared font takes the effect's default, and a color declaring a color space converts to the
	effect's working gamut. Observed on FxGripTileableEffectParameterPolicyName. */
- (void)notifyParameterPolicy:(NSNotification *)notification
{
	NSMutableDictionary *config = notification.userInfo.mutableFxParameter;
	if (config == nil) {
		return;
	}
	FxParameterType type = config.parameterType;

	if (type == FxParameterType_FontMenu) {
		NSString *font = config.parameterDefaultValue;
		if (![font isKindOfClass:NSString.class] || font.length == 0
			|| [font isEqualToString:kFxParameterType_FontNameDefault]) {
			config[kFxParameterProperty_Default] = self.defaultFontName;
		}
		return;
	}

	if (type == FxParameterType_RGBA || type == FxParameterType_RGB) {
		NSMutableDictionary *colors = config[kFxParameterProperty_Default];
		if (![colors isKindOfClass:NSMutableDictionary.class]) {
			return;
		}
		NSNumber *space = colors.parameterColorSpace;
		if (space == nil) {
			return;
		}
		int convertGamma = 0;
		if (space.intValue == 1 && self.isLinearColorParameters) {
			convertGamma = -1;
		} else if (space.intValue == 0 && self.isGammaColorParameters) {
			convertGamma = 1;
		}
		if (convertGamma == 0) {
			return;
		}
		const double gamma = 2.2;
		double exponent = convertGamma > 0 ? gamma : 1.0 / gamma;
		for (NSString *key in @[kFxParameterProperty_Red, kFxParameterProperty_Green, kFxParameterProperty_Blue]) {
			NSNumber *component = colors[key];
			if ([component isKindOfClass:NSNumber.class]) {
				colors[key] = @(pow(component.doubleValue, exponent));
			}
		}
	}
}

/*! Adds a group's configured children when a group parameter announces its subgroup. Observed on
	FxGripTileableEffectAddGroupParametersName. */
- (void)notifyAddGroupParameters:(NSNotification *)notification
{
	NSNumber *groupID = notification.userInfo[FxGripTileableEffectGroupIDKey];
	if (![groupID isKindOfClass:NSNumber.class]) {
		return;
	}
	NSError *error = nil;
	if (![self addParametersWithGroupID:groupID.unsignedIntValue error:&error] && error != nil) {
		((NSMutableDictionary *)notification.userInfo).fxError = error;
	}
}

- (BOOL)parameterClicked:(FxParameterId)parameterID
{
	// OSC plug-ins must not bracket with startAction/endAction; the host already expects
	// parameter changes.
	id<FxCustomParameterActionAPI_v4> actionAPI = nil;
	if (![self conformsToProtocol:@protocol(FxOnScreenControl_v4)]) {
		actionAPI = self.apiManager.customParameterActionAPIv4;
		[actionAPI startAction:self];
	}

	NSMutableDictionary *userInfo = @{FxGripTileableEffectParameterClickedIDKey: @(parameterID)}.mutableCopy;
	[self.notifier postNotificationName:FxGripTileableEffectParameterClickedName object:self userInfo:userInfo];

	NSError *error = userInfo.fxError;
	if (error && ![error isKindOfClass:NSError.class]) {
		NSLog(@"%s Error: Error returned from notification is not NSError class but %@.", __func__, error.className);
	} else if (error) {
		NSLog(@"%s Error: Error returned from Parameter Clicked Notification %@", __func__, error);
	}

	// The configuration's "selector" names the subclass hook; the method is optional. A
	// strict-form synthesized name never dispatches here (it would re-enter the trampoline).
	NSString *declaredName = [self configurationForParameter:parameterID].parameterSelector;
	SEL declared = declaredName ? NSSelectorFromString(declaredName) : NULL;
	FxParameterId declaredPid = 0;
	if (declared && [FxGripParameterUtility getParameterID:&declaredPid fromClickSelector:declared]) {
		declared = NULL;
	}

	if (declared && [self respondsToSelector:declared]) {
		((void (*)(id, SEL))objc_msgSend)(self, declared);
	} else {
		id<FxParameter> parameter = __parameters[@(parameterID)];
		if ([parameter respondsToSelector:@selector(defaultParameterAction)]) {
			[(id)parameter defaultParameterAction];
		}
	}

	[actionAPI endAction:self];
	return error == nil;
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

	// The render thread cannot use the retrieval API, so parameters with state
	// encode their values here for the render-side coder to read back.
	for (id<FxParameter> parameter in self.parameters.allValues) {
		if (parameter.hasState) {
			[parameter encodeWithCoder:state];
		}
	}

	// If the child has a pluginStateWithCoder
	if ([self conformsToProtocol:@protocol(FxGripTileableEffectCoderState)]) {
		if (![self pluginCoder:state atTime:renderTime quality:qualityLevel error:error] || (error && *error)) {
			return NO;
		}
	}
	
	NSMutableDictionary *userInfo = @{FxGripTileableEffectPluginStateCoderKey: state}.mutableCopy;
	[self.notifier postNotificationName:FxGripTileableEffectPluginStateName object:self userInfo:userInfo];
	
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
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxError_ThirdPartyDeveloperStart + 1
									 userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Invalid pluginState in %s", __func__] }];
		}
		return NO;
	}
	
	NSKeyedUnarchiver *state = NARC_AUTORELEASE([NSKeyedUnarchiver.alloc initForReadingFromData:pluginState
																		 error:error]);
	if (*error || !state) {
		return NO;
	}
	if ([self conformsToProtocol:@protocol(FxGripTileableEffectCoderState)]) {
		state.renderTime = renderTime;
	}

	// The requests reach the host only when the subclass schedules; leaving the out
	// parameter untouched keeps the host's default input delivery.
	BOOL scheduled = NO;
	NSMutableArray *mutableInputImageRequests = NARC_AUTORELEASE([NSMutableArray.alloc initWithCapacity:5]);
	if ([self respondsToSelector:@selector(scheduleInputs:pluginCoder:atTime:error:)]) {
		if (![self scheduleInputs:&mutableInputImageRequests
					  pluginCoder:state
						   atTime:renderTime
							error:error]) {
			return NO;
		}
		scheduled = YES;
	}

	NSMutableDictionary *userInfo = @{FxGripTileableEffectPluginStateCoderKey: state}.mutableCopy;
	[self.notifier postNotificationName:FxGripTileableEffectScheduleInputsName object:self userInfo:userInfo];

	if ((*error = userInfo.fxError) && ![*error isKindOfClass:NSError.class]) {
		NSLog (@"%s Error: Error returned from notification is not NSError class but %@.", __func__, (*error).className);
		return NO;
	} else if (*error) {
		NSLog (@"%s Error: Error returned from Parameter Changed Notification %@", __func__, *error);
		return NO;
	}

	// An image-ref parameter delivers a tile only when it is requested. The requests
	// follow the scheduled inputs in ascending parameter-ID order, so the render side
	// finds the main clip first and each image reference after it.
	NSDictionary<NSNumber *, id<FxParameter>> *parameters = self.parameters;
	NSMutableArray<FxGripImageRefParameter *> *imageRefParameters = [NSMutableArray array];
	for (NSNumber *parameterID in [parameters.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
		id<FxParameter> parameter = parameters[parameterID];
		if ([parameter isKindOfClass:FxGripImageRefParameter.class]) {
			[imageRefParameters addObject:(FxGripImageRefParameter *)parameter];
		}
	}
	if (imageRefParameters.count) {
		// Once the plug-in schedules, the host abandons default input delivery; a
		// filter that has not scheduled its own inputs gains the effect clip first.
		if (!scheduled && ![self isKindOfClass:FxGripTileableGenerator.class]) {
			FxImageTileRequest *mainInput = [FxImageTileRequest.alloc initWithSource:kFxImageTileRequestSourceEffectClip
																				time:renderTime
																	  includeFilters:YES
																		 parameterID:0];
			[mutableInputImageRequests insertObject:NARC_AUTORELEASE(mainInput) atIndex:0];
		}
		for (FxGripImageRefParameter *imageRefParameter in imageRefParameters) {
			FxImageTileRequest *request = [FxImageTileRequest.alloc initWithSource:kFxImageTileRequestSourceParameter
																			  time:renderTime
																	includeFilters:imageRefParameter.includeFilters
																	   parameterID:imageRefParameter.parameterID];
			[mutableInputImageRequests addObject:NARC_AUTORELEASE(request)];
		}
		scheduled = YES;
	}

	if (scheduled && mutableInputImageRequests) {
		*inputImageRequests = [mutableInputImageRequests copy];
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

/*! The tile's bounds converted from pixel space to image space. */
- (FxRect)fxImageSpaceBoundsOfTile:(FxImageTile *)tile
{
	FxRect pixelBounds = tile.imagePixelBounds;
	FxPoint2D ll = { pixelBounds.left, pixelBounds.bottom };
	FxPoint2D ur = { pixelBounds.right, pixelBounds.top };
	ll = [tile.inversePixelTransform transform2DPoint:ll];
	ur = [tile.inversePixelTransform transform2DPoint:ur];
	FxRect bounds;
	bounds.left = ll.x;
	bounds.bottom = ll.y;
	bounds.right = ur.x;
	bounds.top = ur.y;
	return bounds;
}

/*! The image-space union of the sources' bounds; the destination's bounds when there
	are no sources (the generator base overrides with the output bounds directly). */
- (FxRect)fxImageSpaceUnionOfImages:(NSArray<FxImageTile *> *)sourceImages
						   fallback:(FxImageTile *)destinationImage
{
	if (sourceImages.count == 0) {
		return [self fxImageSpaceBoundsOfTile:destinationImage];
	}
	FxRect unionRect = [self fxImageSpaceBoundsOfTile:sourceImages[0]];
	for (NSUInteger index = 1; index < sourceImages.count; index++) {
		FxRect bounds = [self fxImageSpaceBoundsOfTile:sourceImages[index]];
		unionRect.left = MIN(unionRect.left, bounds.left);
		unionRect.bottom = MIN(unionRect.bottom, bounds.bottom);
		unionRect.right = MAX(unionRect.right, bounds.right);
		unionRect.top = MAX(unionRect.top, bounds.top);
	}
	return unionRect;
}

- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
                sourceImages:(NSArray<FxImageTile *> *)sourceImages
            destinationImage:(nonnull FxImageTile *)destinationImage
                 pluginState:(NSData *)pluginState
                      atTime:(CMTime)renderTime
                       error:(NSError * _Nullable *)error
{
	// Assigned before dispatch so the rect is defined even when neither the subclass
	// nor an observer writes it.
	*destinationImageRect = [self fxImageSpaceUnionOfImages:sourceImages
												   fallback:destinationImage];

	NSKeyedUnarchiver *state = NARC_AUTORELEASE([NSKeyedUnarchiver.alloc initForReadingFromData:pluginState
																		 error:error]);
	if (*error || !state) {
		return NO;
	}

	if ([self conformsToProtocol:@protocol(FxGripTileableEffectCoderState)]) {
		state.renderTime = renderTime;
	}

	if ([self respondsToSelector:@selector(destinationImageRect:sourceImages:destinationImage:pluginCoder:atTime:error:)]) {
		if (![self destinationImageRect:destinationImageRect
						   sourceImages:sourceImages
					   destinationImage:destinationImage
							pluginCoder:state
								 atTime:renderTime
								  error:error]) {
			return NO;
		}
	}

	NSMutableDictionary *userInfo = @{FxGripTileableEffectPluginStateCoderKey: state}.mutableCopy;
	[self.notifier postNotificationName:FxGripTileableEffectDestinationImageRectName object:self userInfo:userInfo];

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
	if (!self.changesOutputSize) {
		// Same-size default: the source tile mirrors the destination tile. The
		// subclass coder method below still runs so a filter can pad its tiles
		// (a blur reading beyond the destination) without changing output size.
		*sourceTileRect = destinationTileRect;
	} else {
		if (sourceImageIndex >= sourceImages.count) {
			if (error) {
				*error = [NSError errorWithDomain:FxGripPlugErrorDomain
											 code:kFxError_InvalidParameter
										 userInfo:@{ NSLocalizedDescriptionKey :
											 [NSString stringWithFormat:@"Source image index %lu out of range in %s",
											  (unsigned long)sourceImageIndex, __func__] }];
			}
			return NO;
		}

		// Round-trip the destination tile through image space into the indexed
		// source's pixel space.
		FxPoint2D   ll = { destinationTileRect.left, destinationTileRect.bottom };
		FxPoint2D   ur = { destinationTileRect.right, destinationTileRect.top };

		ll = [destinationImage.inversePixelTransform transform2DPoint:ll];
		ur = [destinationImage.inversePixelTransform transform2DPoint:ur];

		ll = [sourceImages [ sourceImageIndex ].pixelTransform transform2DPoint:ll];
		ur = [sourceImages [ sourceImageIndex ].pixelTransform transform2DPoint:ur];

		sourceTileRect->left = ll.x;
		sourceTileRect->right = ur.x;
		sourceTileRect->bottom = ll.y;
		sourceTileRect->top = ur.y;
	}

	NSKeyedUnarchiver *state = NARC_AUTORELEASE([NSKeyedUnarchiver.alloc initForReadingFromData:pluginState
																		 error:error]);
	if (*error || !state) {
		return NO;
	}

	if ([self conformsToProtocol:@protocol(FxGripTileableEffectCoderState)]) {
		state.renderTime = renderTime;
	}

	if ([self respondsToSelector:@selector(sourceTileRect:sourceImageIndex:sourceImages:destinationTileRect:destinationImage:pluginCoder:atTime:error:)]) {
		if (![self sourceTileRect:sourceTileRect
				 sourceImageIndex:sourceImageIndex
					 sourceImages:sourceImages
			  destinationTileRect:destinationTileRect
				 destinationImage:destinationImage
					  pluginCoder:state
						   atTime:renderTime
							error:error]) {
			return NO;
		}
	}

	NSMutableDictionary *userInfo = @{FxGripTileableEffectPluginStateCoderKey: state}.mutableCopy;
	[self.notifier postNotificationName:FxGripTileableEffectSourceTileRectName object:self userInfo:userInfo];
	
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
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
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
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxError_InvalidParameter
									 userInfo:userInfo];
		}
		return NO;
	}
    
	
	BOOL success = YES;
	NSKeyedUnarchiver *state = nil;
	if ([self conformsToProtocol:@protocol(FxGripTileableEffectCoderState)]) {
		state = NARC_AUTORELEASE([NSKeyedUnarchiver.alloc initForReadingFromData:pluginState
																			  error:error]);
		if (*error || !state) {
			return NO;
		}

		state.renderTime = renderTime;

		success = [self renderDestinationImage:destinationImage
								  sourceImages:sourceImages
								   pluginCoder:state
										atTime:renderTime
										 error:error];
	} else if (![self isKindOfClass:FxGripTileableGenerator.class]) {
		success = [self renderPassthroughDestinationImage:destinationImage
											 sourceImages:sourceImages
													error:error];
	}
	if (success) {
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		userInfo[FxGripTileableEffectPluginStateCoderKey] = state;
		userInfo[FxGripTileableEffectRenderDestinationImageKey] = destinationImage;
		if (sourceImages) {
			userInfo[FxGripTileableEffectRenderSourceImagesKey] = sourceImages;
		}
		NSDictionary *renderTimeDict = (__bridge_transfer NSDictionary *)CMTimeCopyAsDictionary(renderTime, kCFAllocatorDefault);
		if (renderTimeDict) {
			userInfo[FxGripTileableEffectRenderAtTimeKey] = renderTimeDict;
		}
		[self.notifier postNotificationName:FxGripTileableEffectRenderDestinationImageName object:self userInfo:userInfo];

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

/*!
	The default filter render: a bilinear blit of the first source tile into the
	destination, so a filter without a coder-state render passes its input through.
*/
- (BOOL)renderPassthroughDestinationImage:(FxImageTile *)destinationImage
							 sourceImages:(NSArray<FxImageTile *> *)sourceImages
									error:(NSError * _Nullable *)error
{
	int srcIndex = 0;
	if (sourceImages.count == 0 || sourceImages[srcIndex].ioSurface == nil) {
		NSLog(@"%s Error: No source image to pass through", __func__);
		if (error) {
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxError_InvalidParameter
									 userInfo:@{ NSLocalizedDescriptionKey : @"Invalid No Source Image ioSurface" }];
		}
		return NO;
	}

	FxGripMTLDeviceCache *deviceCache = [FxGripMTLDeviceCache deviceCache];
	FxGripMTLDeviceCacheItem *srcDevice = [deviceCache deviceWithRegistryID:sourceImages[srcIndex].deviceRegistryID];
	id<MTLDevice> destDevice = [FxGripMTLDeviceCache metalDeviceFromID:destinationImage.deviceRegistryID];

	id<MTLCommandQueue> commandQueue = [srcDevice getNextFreeCommandQueue];
	if (commandQueue == nil) {
		NSLog(@"%s Error: No command queue", __func__);
		if (error) {
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxError_InvalidParameter
									 userInfo:@{ NSLocalizedDescriptionKey : @"No Metal command queue" }];
		}
		return NO;
	}

	MPSImageBilinearScale *scaleEncoder = NARC_AUTORELEASE([MPSImageBilinearScale.alloc initWithDevice:srcDevice.gpuDevice]);
	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
	commandBuffer.label = @"FxGripTileableEffect Passthrough Blit";
	[commandBuffer enqueue];

	id<MTLTexture> inputTexture = [sourceImages[srcIndex] metalTextureForDevice:srcDevice.gpuDevice];
	id<MTLTexture> outputTexture = [destinationImage metalTextureForDevice:destDevice];
	[scaleEncoder encodeToCommandBuffer:commandBuffer sourceTexture:inputTexture destinationTexture:outputTexture];

	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];
	[deviceCache returnCommandQueueToCache:commandQueue];

	if (commandBuffer.status == MTLCommandBufferStatusError || commandBuffer.error) {
		NSLog(@"%s Metal Blit Error %@", __func__, commandBuffer.error);
		if (error) {
			*error = commandBuffer.error;
		}
		return NO;
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


// This gives FxGripTileableEffect the ability to [] its parameters by parameter ID.
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
	// The getter rebuilds the cache constructParameter: invalidates; the ivar is nil
	// after every registration.
	return [self.parameters objectForKey:@(index)];
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
	// The remove payload carries only the id, so the guarded parameterID accessor
	// (which needs id+type+name together) returns kFxParameterId_None and would remove
	// nothing — leaving the dead parameter object registered and observing. Read the
	// raw id key with the top-level fallback, matching the extension handlers.
	NSNumber *pid = parameter[kFxParameterProperty_Id] ?: notification.userInfo[kFxParameterProperty_Id];
	if (pid == nil) {
		return;
	}
	[__parameters removeObjectForKey:pid];
	_parameters = nil;
}

- (void)notifyParametersFlush:(NSNotification*)notification
{
	for(NSNumber *key in __parameters) {
		[__parameters[key] parameterFlush];
	}
}

@end
