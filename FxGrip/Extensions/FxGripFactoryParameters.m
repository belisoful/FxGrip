//
//  FxGripDebugMenu.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//


/*
 @todo
 - required - parameter to view FXFactory version
 - optional - parameter to set the FxFactory product UUID
 - parameter for "click to view product" and "buy" w/ version display
 
 - target preset on licensing Toggle, from configuration, embed (NSDictionary) or TargetPreset Name.
 - If Debugging, add menu items for
 	• Hiding product UUID parameter.
 */

#import <FxFactory/FxFactory.h>
#import "FxGripFactory.h"
#import "FxTileableEffectBase.h"
#import "GuruFxTileableEffect+Extensions.h"
#import "GuruFxTileableEffect+Versioning.h"
#import "GuruFxTileableEffect+Extensions.h"
#import "FxGripRegression.h"
#import "NSPriorityNotificationCenter.h"
#import "NSDictionary+FxTileableEffect.h"
#import "CIImage+BExtension.h"

#import "FxGripMTLDeviceCache.h"
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <MetalKit/MetalKit.h>
//#import <MetalFX/MetalFX.h>
//#import <IOSurface/IOSurfaceObjC.h>
#import <CoreImage/CoreImage.h>
//#import <CoreImage/CIFilter.h>
//#import <CoreImage/CIFilterBuiltins.h>

#import "FxGrip_ARC.h"

/*!
 
 This automatically clears the plugin cache by changing the parameter to indicate licensing within Motion.
 
 @todo combine buy product and version (version has icon for up-to-date, )
 
 */
#pragma mark -
#pragma mark FxFactory Extension methods

@implementation FxGripFactory
{
	// stored to remove it on unload.
	id _licensingStatusChangeHandler;
	NSString *_licensingHandlerUUID;
}

@synthesize fxFactoryIsInstalled = _fxFactoryIsInstalled;
@synthesize fxFactoryPluginUUID = _fxFactoryPluginUUID;
@synthesize fxFactoryPluginVersion = _fxFactoryPluginVersion;

@synthesize fxFactoryHasActive = _fxFactoryHasActive;

@synthesize fxFactorySettingsObject = _fxFactorySettingsObject;

- (instancetype _Nullable)init
{
	self = [super init];
	if (self) {
		_licensingStatusChangeHandler = NULL;
		_licensingHandlerUUID = NULL;
		_fxFactoryIsInstalled = FxFactoryIsInstalled();
	}
	return self;
}


- (void)dealloc
{
	[self unregisterLicenseHandler];
	
	SUPER_DEALLOC();
}


- (void)registerLicenseHandler:(NSString *)productUUID
{
	[self unregisterLicenseHandler];
	if (FxFactoryRegisterLicensingStatusChangeHandler != NULL && productUUID != NULL && productUUID.length > 0) {
		_licensingHandlerUUID = productUUID;
		_licensingStatusChangeHandler = FxFactoryRegisterLicensingStatusChangeHandler(productUUID, self, ^(FxFactoryLicensingStatus status, id _Nullable context) {
			
			self->_pluginLicenseStatus = @(status);
			
			FxGripOOBParameterAccess *__attribute__((unused)) accessor = ((FxGripFactory*)context).effect.startContext;
			
			[(FxGripFactory*)context setBoolValue:status == kFxFactoryLicensingStatusProductLicensed];
			
			
			// Product may have gone from unlicensed to licensed, or vice versa
			[((FxGripFactory*)context).effect onFxFactoryRegisterLicensingStatusChange:status];
			
			[self.effect.notifier postNotificationName:kFxFactoryBroadcastProductLicenseChange object:(FxGripFactory*)context userInfo:@{kFxFactoryBroadcastProductLicenseStatus: @(status)}];
		});
	}
}

- (void)unregisterLicenseHandler
{
	if (_licensingStatusChangeHandler) {
		FxFactoryUnregisterLicensingStatusHandler(self.fxFactoryPluginUUID, _licensingStatusChangeHandler);
		_licensingStatusChangeHandler = nil;
		_licensingHandlerUUID = nil;
	}
}


- (void)showProductUpdates
{
	[self showProductUpdates:NO handler:nil];
}


- (void)showProductUpdates:(void (^)(NSDictionary * _Nonnull response))handler
{
	[self showProductUpdates:YES handler:handler];
}


- (void)showProductUpdates:(BOOL)forceCheck handler:(void (^)(NSDictionary * _Nonnull response))handler
{
	handler = Block_copy(handler);
	void (^ _Nullable _handler) (NSDictionary * _Nonnull response) =
	^(NSDictionary * productInfo) {
		if (productInfo != nil) {
			[self.effect onFxFactoryShowProductUpdates:productInfo];
			
			if (handler) {
				handler(productInfo);
				Block_release(handler);
			}
			
			[self.effect.notifier postNotificationName:kFxFactoryBroadcastProductUpdate object:self userInfo:productInfo];
		}
	};
	
	FxFactoryShowProductUpdates( self.fxFactoryPluginUUID, self.fxFactoryPluginVersion, forceCheck, _handler);
}


#pragma mark -
#pragma mark FxFactory Extension methods

- (void)extProcessParameters:(nonnull NSMutableArray<NSMutableDictionary *> *)parameters
{
	NSMutableArray *fxFactoryComponents = NSMutableArray.new;
	NSMutableDictionary *parameter = nil;
	
	// Find the fxfactory paramter
	for(NSMutableDictionary *pcheck in parameters) {
		if (pcheck.parameterType == FxParameterType_FxFactory) {
			parameter = pcheck;
			break;
		}
	}
	
	// If none, construct
	if (!parameter) {
		parameter = @{}.mutableCopy;
	}
	
	if (!parameter[kFxParameterProperty_Factory]) {
		parameter[kFxParameterProperty_Factory] = self;
	}
	
	if (parameter[kFxParameterProperty_Id]) {
		_parameterID = ((NSNumber*)parameter[kFxParameterProperty_Id]).intValue;
	} else {
		_parameterID = kFxParameterId_FxFactoryLicense;
		parameter[kFxParameterProperty_Id] = @(_parameterID);
	}
	
	parameter[kFxParameterProperty_Type] = kFxParameterType_Toggle;
	
	if (!parameter[kFxParameterProperty_Name]) {
		parameter[kFxParameterProperty_Name] = @"FxFactory Product Licensed";
	}
	if (!parameter[kFxParameterProperty_Description]) {
		parameter[kFxParameterProperty_Description] = @"FxFactory Integration";
	}
	
	parameter[kFxParameterProperty_Flags] = parameter.parameterFlagsArray.mutableCopy;
	NSArray *pFlags = @[kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA, kParameterFlagString_NO_DEBUG];
	[parameter[kFxParameterProperty_Flags] removeObjectsInArray:pFlags];
	
	[parameter[kFxParameterProperty_Flags] addObjectsFromArray:pFlags];
	
	[fxFactoryComponents addObject:parameter];
	
	NSDictionary *fxFactoryParameter = parameter;
	
	
	// Step 1: Get FxFactory Extension Active
	if ([self.fxFactorySettingsObject respondsToSelector:@selector(fxFactoryActive)]) {
		_fxFactoryActive = @([self.fxFactorySettingsObject fxFactoryActive]);
	} else {
		_fxFactoryActive = parameter[kPropertiesFxFactoryActive];
	}
	_fxFactoryHasActive = _fxFactoryActive != nil;
	
	// If hard deactivated, then stop
	if (!self.fxFactoryActive) {
		return;
	}
	
	
	
	if ([self.fxFactorySettingsObject respondsToSelector:@selector(fxFactoryProductUUID)]) {
		_fxFactoryPluginUUID = [self.fxFactorySettingsObject fxFactoryProductUUID];
	}
	
	if (!_fxFactoryPluginUUID) {
		_fxFactoryPluginUUID = parameter[kPropertiesFxFactoryPluginUUID];
		if (!_fxFactoryPluginUUID) {
			_fxFactoryPluginUUID = self.effect.properties[kPropertiesFxFactoryPluginUUID];
		}
		if (_fxFactoryPluginUUID && [_fxFactoryPluginUUID isKindOfClass:NSNumber.class]) {
			_fxFactoryPluginUUID = self.effect.uuid;
		}
	}
	
	if (_fxFactoryPluginUUID) {
		if ([self.fxFactorySettingsObject respondsToSelector:@selector(fxFactoryProductVersion)]) {
			_fxFactoryPluginVersion = [self.fxFactorySettingsObject fxFactoryProductVersion];
		}
		if (!_fxFactoryPluginVersion) {
			_fxFactoryPluginVersion = parameter[kPropertiesFxFactoryPluginVersion];
			if (!_fxFactoryPluginVersion) {
				_fxFactoryPluginVersion = self.effect.properties[kPropertiesFxFactoryPluginVersion];
			}
			if (_fxFactoryPluginVersion && [_fxFactoryPluginVersion isKindOfClass:NSNumber.class]) {
				_fxFactoryPluginVersion = self.effect.pluginShortVersion;
			}
		}
	}
	_fxFactoryHasPluginProduct = _fxFactoryPluginUUID != nil;
	
	
	
	if ([self.fxFactorySettingsObject respondsToSelector:@selector(fxFactoryWaterMarkUnlicensed)]) {
		_fxFactoryWaterMarkUnlicensed = @([self.fxFactorySettingsObject fxFactoryWaterMarkUnlicensed]);
	} else {
		_fxFactoryWaterMarkUnlicensed = parameter[kPropertiesFxFactoryWatermarkUnlicensed];
	}
	_fxFactoryHasWaterMarkUnlicensed = parameter[kPropertiesFxFactoryWatermarkUnlicensed] != nil;
	
	
	
	if ([self.fxFactorySettingsObject respondsToSelector:@selector(fxFactoryShowBuyButton)]) {
		_fxFactoryShowBuyButton = @([self.fxFactorySettingsObject fxFactoryShowBuyButton]);
	} else {
		_fxFactoryShowBuyButton = parameter[kPropertiesFxFactoryShowBuyButton];
	}
	_fxFactoryHasShowBuyButton = _fxFactoryShowBuyButton != nil;
	
	
	
	if ([self.fxFactorySettingsObject respondsToSelector:@selector(fxFactoryShowProductButton)]) {
		_fxFactoryShowProductButton = @([self.fxFactorySettingsObject fxFactoryShowProductButton]);
	} else {
		_fxFactoryShowProductButton = parameter[kPropertiesFxFactoryShowProductButton];
	}
	_fxFactoryHasShowProductButton = _fxFactoryShowProductButton != nil;
	
	
	
	if ([self.fxFactorySettingsObject respondsToSelector:@selector(fxFactoryAutoChecking)]) {
		_fxFactoryAutoChecking = @([self.fxFactorySettingsObject fxFactoryAutoChecking]);
	} else {
		_fxFactoryAutoChecking = parameter[kPropertiesFxFactoryAutoChecking];
	}
	_fxFactoryHasAutoChecking = _fxFactoryAutoChecking != nil;
	
		// if active is not defined
	if ((!self.fxFactoryHasActive && !self.fxFactoryHasPluginProduct) || (_fxFactoryActive && ![_fxFactoryActive isKindOfClass:NSNumber.class])) {
		parameter = @{
			@"type": kFxParameterType_Toggle,
			@"name": @"FxFactory Active",
			@"id": @(_parameterID + kParameterFxFactoryActiveOffset),
			kFxParameterProperty_ParentId: fxFactoryParameter[kFxParameterProperty_ParentId],
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[fxFactoryComponents addObject:parameter];
	}
	
	
	if (!self.fxFactoryHasPluginProduct) {
		parameter = @{
			@"type": kFxParameterType_String,
			@"name": @"FxFactory Product UUID",
			@"id": @(_parameterID + kParameterFxFactoryProductUUIDOffset),
			kFxParameterProperty_ParentId: fxFactoryParameter[kFxParameterProperty_ParentId],
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA, kParameterFlagString_NO_STATE]
		}.mutableCopy;
		[fxFactoryComponents addObject:parameter];
		
		parameter = @{
			@"id": @(_parameterID + kParameterFxFactoryProductVersionOffset),
			@"name": @"FxFactory Product Version",
			@"type": kFxParameterType_String,
			kFxParameterProperty_ParentId: fxFactoryParameter[kFxParameterProperty_ParentId],
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA, kParameterFlagString_NO_STATE]
		}.mutableCopy;
		[fxFactoryComponents addObject:parameter];
	}
	
	if (!self.fxFactoryHasWaterMarkUnlicensed) {
		parameter = @{
			@"id": @(_parameterID + kParameterFxFactoryWaterMarkUnlicensedOffset),
			@"name": @"FxFactory Unlicensed Watermark",
			@"type": kFxParameterType_Toggle,
			kFxParameterProperty_ParentId: fxFactoryParameter[kFxParameterProperty_ParentId],
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[fxFactoryComponents addObject:parameter];
	}
	//if (!self.fxFactoryHasShowProductVersion) {
	//	[fxFactoryComponents addObject:licensedParameter];
	//}
	if (!self.fxFactoryHasShowBuyButton) {
		NSString *name = @"Buy Plugin...";
		parameter = @{
			@"type": kFxParameterType_PushButton,
			@"name": name,
			@"id": @(_parameterID + kParameterFxFactoryBuyButtonOffset),
			kFxParameterProperty_ParentId: fxFactoryParameter[kFxParameterProperty_ParentId],
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[fxFactoryComponents addObject:parameter];
		
		parameter = @{
			@"type": kFxParameterType_String,
			@"name": @"Buy Button Label",
			@"id": @(_parameterID + kParameterFxFactoryBuyButtonLabelOffset),
			@"default": name,
			kFxParameterProperty_ParentId: fxFactoryParameter[kFxParameterProperty_ParentId],
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[fxFactoryComponents addObject:parameter];
	}
	if (!self.fxFactoryHasShowProductButton) {
		NSString *name = @"Show FxFactory Product...";
		parameter = @{
			@"type": kFxParameterType_PushButton,
			@"name": @"Show FxFactory Product...",
			@"id": @(_parameterID + kParameterFxFactoryProductButtonOffset),
			kFxParameterProperty_ParentId: fxFactoryParameter[kFxParameterProperty_ParentId],
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[fxFactoryComponents addObject:parameter];
		
		parameter = @{
			@"type": kFxParameterType_String,
			@"name": @"Product Button Label",
			@"id": @(_parameterID + kParameterFxFactoryProductButtonLabelOffset),
			@"default": name,
			kFxParameterProperty_ParentId: fxFactoryParameter[kFxParameterProperty_ParentId],
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[fxFactoryComponents addObject:parameter];
	}
	if (!self.fxFactoryHasAutoChecking) {
		parameter = @{
			@"type": kFxParameterType_Toggle,
			@"name": @"FxFactory Update Checking",
			@"id": @(_parameterID + kParameterFxFactoryAutoCheckingOffset),
			kFxParameterProperty_ParentId: fxFactoryParameter[kFxParameterProperty_ParentId],
			@"default": @YES,
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA, kParameterFlagString_NO_STATE]
		}.mutableCopy;
		[fxFactoryComponents addObject:parameter];
	}
	
	
	[parameters addObjectsFromArray:fxFactoryComponents];
}

- (FxParameterType)extParameterTypeForString:(nullable NSString *)typeString
{
	if ([typeString isEqualToString:kFxParameterType_FxFactory]) {
		return FxParameterType_FxFactory;
	} else
	return FxParameterType_None;
}


- (nullable Class)extParameterClassForType:(FxParameterType)type
{
	if (type == FxParameterType_FxFactory) {
		return FxGripFactory.class;
	}
	return NULL;
}


- (BOOL)extLoadWithEffect:(GuruFxTileableEffect * _Nonnull)effect
{
	[super extLoadWithEffect:effect];
	
	if (!_fxFactoryIsInstalled) {
		// If FxFactory is not installed, the extension works but isn't connected.
		return YES;
	}
	
	
	//Run regression if installed
	if ([effect hasExtensionClass:FxGripRegression.class]) {
		[self fxFactoryRegression];
	}
	
	return YES;
}


- (void)extAddedToDocument
{
	[super extAddedToDocument];
	
	if (!self.fxFactoryActive) {
		return;
	}
	// run auto update unless disabled
	if (FxFactoryShowProductUpdates != NULL) {
		[self showProductUpdates];
	}
	
	// install licensing status changed handler
	[self registerLicenseHandler: self.fxFactoryPluginUUID];
	
#if DEBUG
	id debugLicensed = self.effect.properties[kPropertiesFxFactoryDebugSetLicensed];
	if (!debugLicensed || ([debugLicensed isKindOfClass:NSNumber.class])) {
		BOOL licensed = ((NSNumber*)debugLicensed).boolValue;
		NSLog(@"⚠️ Debugging %@icensed version as default. This bypasses FxFactory Licensing in the xCode Debug Target and will work normally in the Release Target.", licensed ? @"L" : @"Unl");
		[self.effect setFxFactoryLicenseState:licensed];
	} else {
#endif
		BOOL priorLicenseStatus = self.boolValue;
		BOOL currentLicenseStatus = self.pluginIsLicensed;
		if (currentLicenseStatus != priorLicenseStatus) {
			self.boolValue = currentLicenseStatus;
			// change any parameters between their licensed and unlicensed state.
			[self.effect setFxFactoryLicenseState:currentLicenseStatus];
		}
#if DEBUG
	}
#endif
}

- (void)extParameterChanged:(FxParameterId)paramID
							atTime:(CMTime)time
							 error:(NSError * _Nullable * _Nullable)error
{
	if (!self.fxFactoryActive) {
		return;
	}
	
	if (paramID == self.parameterID) {
		// If the licensing BOOL changes, change it back.
		self.boolValue = self.pluginIsLicensed;
		
	} else if (paramID == self.parameterID + kParameterFxFactoryActiveOffset) {
		BOOL active = self.effect[paramID].boolValue;
		if (active) {
			[self registerLicenseHandler:self.fxFactoryPluginUUID];
		} else {
			[self unregisterLicenseHandler];
		}
		
	} else if (paramID == self.parameterID + kParameterFxFactoryProductUUIDOffset) {
		[self registerLicenseHandler:self.fxFactoryPluginUUID];
		
	} else if (paramID == self.parameterID + kParameterFxFactoryProductButtonLabelOffset || paramID == self.parameterID + kParameterFxFactoryBuyButtonLabelOffset) {
		//	 The value becomes the button name
		self.effect[paramID - 1].parameterName = self.effect[paramID].stringValue;
	
	} else if (paramID == self.parameterID + kParameterFxFactoryAutoCheckingOffset) {
		[self setPluginIsUpdateChecking:self.effect[paramID].boolValue];
	}
}

- (BOOL)extRenderDestinationImage:(FxImageTile *_Nonnull)destinationImage
					 sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
					  pluginState:(id _Nullable)pluginState   //NSData or NSKeyedUnarchiver
						   atTime:(CMTime)renderTime
							error:(NSError *_Nullable *_Nullable)outError
{
	if (!self.fxFactoryWaterMarkUnlicensed || self.pluginIsLicensed) {
		return YES;
	}
	FxGripMTLDeviceCache*  deviceCache     = [FxGripMTLDeviceCache deviceCache];
	FxGripMTLDeviceCacheItem* destDevice = [deviceCache deviceWithRegistryID:destinationImage.deviceRegistryID];
	
	CGColorSpaceRef colorSpace = (CGColorSpaceRef)nil;
	colorSpace = [NSColorSpace sRGBColorSpace].CGColorSpace;
	id<MTLTexture> outputTexture   = [destinationImage metalTextureForDevice:destDevice.gpuDevice];
	CIImage *inImage = [CIImage imageWithMTLTexture:outputTexture options:@{kCIImageColorSpace: (id)colorSpace}];
	
	
	CIImage *topImage = [CIImage createImageText:self.effect.displayName
										fontName:@"Helvetica"
										fontSize:99
										   angle:10.0
										   color:NSColor.whiteColor
											blur:0
										position:(CGPoint){0,0}];
	CIImage *bottomImage = [CIImage createImageText:self.effect.displayName
										   fontName:@"Helvetica"
										   fontSize:99
											  angle:10.0
											  color:NSColor.blueColor
											   blur:10
										   position:(CGPoint){0,0}];
	CIImage *watermark = [CIImage combineImage:topImage alpha:1.0 withImage:bottomImage ];
	
	
	inImage = [CIImage combineImage:watermark alpha:0.73 withImage:inImage ];
	
	
	CIContext *ciContext = [CIContext contextWithMTLDevice:destDevice.gpuDevice];
	CGImageRef cgImage = [ciContext createCGImage:inImage fromRect:CGRectFromFxRect(destinationImage.tilePixelBounds)];//CGRectMake(destTileRect.left, destTileRect.bottom, destTileRect.right -  destTileRect.left, destTileRect.top -  destTileRect.bottom)]; // fromRect:inImage.extent
	
	
	// Step 6: CGImage to MTLTexture
	MTKTextureLoader	*mtlLoader = [[MTKTextureLoader.alloc initWithDevice:destDevice.gpuDevice] autorelease];
	id<MTLTexture> 		inTexture = [[mtlLoader newTextureWithCGImage:cgImage
																  options:@{MTKTextureLoaderOptionSRGB: @(YES),
																		  MTKTextureLoaderOptionOrigin: MTKTextureLoaderOriginBottomLeft}
																	error:outError] autorelease];
	
	id<MTLCommandQueue> 	commandQueue = [destDevice getNextFreeCommandQueue];
	id<MTLCommandBuffer>    commandBuffer   = [commandQueue commandBuffer];
	
	MPSImageScale *scaleEncoder = [[MPSImageBilinearScale.alloc init] autorelease];
	[scaleEncoder encodeToCommandBuffer:commandBuffer sourceTexture:inTexture destinationTexture:outputTexture];
	CGImageRelease(cgImage);
	inTexture = nil;
	mtlLoader = nil;
	
	CGColorSpaceRelease(colorSpace);
	return YES;
}

#pragma mark -
#pragma mark FxFactory Properties

- (FxFactoryVersion)fxFactoryVersion
{
	if (FxFactoryGetVersion == NULL) {
		return (FxFactoryVersion){0, 0, 0};
	}
	return FxFactoryGetVersion();
}

- (NSString* _Nonnull)fxFactoryPluginUUID
{
	if (!_fxFactoryPluginUUID) {
		return self.effect[self.parameterID + kParameterFxFactoryProductUUIDOffset].stringValue;
	}
	return _fxFactoryPluginUUID;
	
}

- (void)setFxFactoryPluginUUID:(NSString* _Nonnull)pluginUUID
{
	if (!_fxFactoryPluginUUID) {
		_fxFactoryPluginUUID = pluginUUID;
	} else {
#if DEBUG
		NSLog(@"⚠️ Trying to set the FxFactory Plugin UUID to \"%@\" but is already set to \"%@\".", pluginUUID, _fxFactoryPluginUUID);
#endif
	}
}


// If it is already set, it cannot be changed unless it is cleared first.
- (void)clearFxFactoryPluginUUID
{
	_fxFactoryPluginUUID = NULL;
}


- (NSString* _Nonnull)fxFactoryPluginVersion
{
	if (!_fxFactoryPluginVersion) {
		return self.effect[self.parameterID + kParameterFxFactoryProductVersionOffset].stringValue;
	}
	return _fxFactoryPluginVersion;
}


- (void)setFxFactoryPluginVersion:(NSString* _Nonnull)pluginVersion
{
	if (!_fxFactoryPluginVersion) {
		_fxFactoryPluginVersion = pluginVersion;
	} else {
#if DEBUG
		NSLog(@"⚠️ Trying to set the FxFactory Plugin Version to \"%@\" but is already set to \"%@\".", pluginVersion, _fxFactoryPluginVersion);
#endif
	}
}


// If it is already set, it cannot be changed unless it is cleared first.
- (void)clearFxFactoryPluginVersion
{
	_fxFactoryPluginVersion = NULL;
}


- (BOOL)pluginIsLicensed
{
	return self.pluginLicenseStatus == kFxFactoryLicensingStatusProductLicensed;
}

- (FxFactoryLicensingStatus)pluginLicenseStatus
{
	if (FxFactoryGetLicensingStatus == NULL) {
		return 0;
	}
	if (!_pluginLicenseStatus) {
		_pluginLicenseStatus = @(FxFactoryGetLicensingStatus(self.fxFactoryPluginUUID));
	}
	return _pluginLicenseStatus.intValue;
}

- (BOOL)pluginIsUpdateChecking
{
	if (FxFactoryIsProductUpdateCheckingEnabled == NULL) {
		return 0;
	}
	return FxFactoryIsProductUpdateCheckingEnabled(self.fxFactoryPluginUUID);
}


- (void)setPluginIsUpdateChecking: (BOOL)enabled
{
	if (FxFactorySetProductUpdateCheckingEnabled == NULL) {
		return;
	}
	[self.effect.notifier postNotificationName:kFxFactoryBroadcastSetUpdateChecking object:self userInfo:@{@"enabled":@(enabled)}];
	
	FxFactorySetProductUpdateCheckingEnabled(self.fxFactoryPluginUUID, enabled);
}


- (BOOL)showFxFactoryProduct
{
	if (FxFactoryPerformLicensingAction == NULL) {
		return NO;
	}
	
	[self.effect.notifier postNotificationName:kFxFactoryBroadcastShowProduct object:self];
	
	return FxFactoryPerformLicensingAction(kFxFactoryLicensingActionShow, self.fxFactoryPluginUUID);
}
- (BOOL)showFxFactoryBuyPlugin
{
	if (FxFactoryPerformLicensingAction == NULL) {
		return NO;
	}
	
	[self.effect.notifier postNotificationName:kFxFactoryBroadcastShowBuy object:self];
	
	return FxFactoryPerformLicensingAction(kFxFactoryLicensingActionBuy, self.fxFactoryPluginUUID);
}



//recipient must be "@fxfactory.com", like for sending fxFactory errors back to them.
- (BOOL)showContactForm:(NSString * _Nullable)subject message:(NSString * _Nullable) message
{
	return [self showContactForm:nil subject:subject message:message];
}


- (BOOL)showContactForm:(NSString * _Nullable)recipient subject:(NSString * _Nullable)subject message:(NSString * _Nullable) message
{
	if (FxFactoryShowContactForm == NULL) {
		return NO;
	}
	if (recipient && [recipient hasSuffix:@"@fxfactory.com"]) {
		NSLog(@"Error: The FxFactory Show Contact Form recipient '%@' must have an '@fxfactory.com' address.  External addresses are not allowed.", recipient);
		return NO;
	}
	
	[self.effect.notifier postNotificationName:kFxFactoryBroadcastContactForm object:self
			   userInfo:@{kFxFactoryBroadcastContactFormRecipient: recipient,
						  kFxFactoryBroadcastContactFormSubject: subject,
						  kFxFactoryBroadcastContactFormMessage: message}];
	
	return FxFactoryShowContactForm(recipient, subject, message);
}


#pragma mark -
#pragma mark FxFactory Configuration Properties


- (id<FxGripFactorySettings> )fxFactorySettingsObject
{
	if (!_fxFactorySettingsObject) {
		if ([self.effect conformsToProtocol:@protocol(FxGripFactorySettings)]) {
			return (id<FxGripFactorySettings>) self.effect;
		}
		return NULL;
	}
	return _fxFactorySettingsObject;
}

- (void)setFxFactorySettingsObject:(nullable id<FxGripFactorySettings>)settingsObject
{
	_fxFactorySettingsObject = settingsObject;
}


- (BOOL)fxFactoryActive
{
	if (self.fxFactoryHasActive && [_fxFactoryActive isKindOfClass:NSNumber.class]) {
		return _fxFactoryActive.boolValue;
	} else if (!self.fxFactoryHasActive && self.fxFactoryHasPluginProduct) {
		return YES;
	} else if (_addedToEffect) {
		return self.effect[self.parameterID + kParameterFxFactoryActiveOffset].boolValue;
	}
	return false;
}

- (void)setFxFactoryActive:(BOOL)active
{
	if ((self.fxFactoryHasActive && [_fxFactoryActive isKindOfClass:NSNumber.class]) || (!self.fxFactoryHasActive && self.fxFactoryHasPluginProduct)) {
		NSLog(@"Error: Cannot setFxFactoryActive when preset");
	} else if (_addedToEffect) {
		self.effect[self.parameterID + kParameterFxFactoryActiveOffset].boolValue = active;
	} else {
		NSLog(@"Error: Cannot setFxFactoryActive before being added to effect");
	}
}

- (BOOL)fxFactoryWaterMarkUnlicensed
{
	BOOL result = NO;
	if (self.fxFactoryHasWaterMarkUnlicensed && [_fxFactoryWaterMarkUnlicensed isKindOfClass:NSNumber.class]) {
		result = _fxFactoryWaterMarkUnlicensed.boolValue;
	} else if (!self.fxFactoryHasWaterMarkUnlicensed && self.fxFactoryHasPluginProduct) {
		result = YES;
	} else if (_addedToEffect) {
		result = self.effect[self.parameterID + kParameterFxFactoryWaterMarkUnlicensedOffset].boolValue;
	}
	return result && self.fxFactoryActive;
}

- (void)setFxFactoryWaterMarkUnlicensed:(BOOL)active
{
	if (self.fxFactoryHasWaterMarkUnlicensed || self.fxFactoryHasPluginProduct) {
		NSLog(@"Error: Cannot setFxFactoryWaterMarkUnlicensed when preset");
	} else if (_addedToEffect) {
		self.effect[self.parameterID + kParameterFxFactoryWaterMarkUnlicensedOffset].boolValue = active;
	} else {
		NSLog(@"Error: Cannot setFxFactoryWaterMarkUnlicensed before being added to effect");
	}
}

- (BOOL)fxFactoryShowBuyButton
{
	if (self.fxFactoryHasShowBuyButton) {
		return _fxFactoryShowBuyButton.boolValue;
	} else if (self.fxFactoryHasPluginProduct) {
		return NO;
	}
	return NO;
}

- (void)setFxFactoryShowBuyButton:(BOOL)active
{
	if (self.fxFactoryHasShowBuyButton || self.fxFactoryHasPluginProduct) {
		NSLog(@"Error: Cannot setFxFactoryShowBuyButton when preset");
	} else if (_addedToEffect) {
		self.effect[self.parameterID + kParameterFxFactoryBuyButtonOffset].boolValue = active;
	} else {
		NSLog(@"Error: Cannot setFxFactoryShowBuyButton before being added to effect");
	}
}


- (BOOL)fxFactoryShowProductButton
{
	if (self.fxFactoryHasShowProductButton) {
		return _fxFactoryShowProductButton.boolValue;
	} else if (self.fxFactoryHasPluginProduct) {
		return NO;
	}
	return NO;
}

- (void)setFxFactoryShowProductButton:(BOOL)active
{
	if (self.fxFactoryHasShowProductButton || self.fxFactoryHasPluginProduct) {
		NSLog(@"Error: Cannot setFxFactoryShowBuyButton when preset");
	} else if (_addedToEffect) {
		self.effect[self.parameterID + kParameterFxFactoryProductButtonOffset].boolValue = active;
	} else {
		NSLog(@"Error: Cannot setFxFactoryShowBuyButton before being added to effect");
	}
}

- (BOOL)fxFactoryAutoChecking
{
	if (self.fxFactoryHasAutoChecking) {
		return _fxFactoryAutoChecking.boolValue;
	} else if (self.fxFactoryHasPluginProduct) {
		return NO;
	} else if (_addedToEffect) {
		return self.effect[self.parameterID + kParameterFxFactoryAutoCheckingOffset].boolValue;
	}
	return false;
}

- (void)setFxFactoryAutoChecking:(BOOL)active
{
	if (self.fxFactoryHasAutoChecking || self.fxFactoryHasPluginProduct) {
		NSLog(@"Error: Cannot setFxFactoryShowBuyButton when preset");
	} else if (_addedToEffect) {
		self.effect[self.parameterID + kParameterFxFactoryAutoCheckingOffset].boolValue = active;
	} else {
		NSLog(@"Error: Cannot setFxFactoryShowBuyButton before being added to effect");
	}
}

#pragma mark -
#pragma mark FxFactory Regression methods


- (BOOL)fxFactoryRegression
{
	BOOL success = YES;
	// from https://fxfactory.com/developer/fxfactory-framework/
	//check "com.apple.security.app-sandbox" is false and "com.apple.security.cs.disable-library-validation" is true
	//check "NSUpdateSecurityPolicy" has:
	//	@"AllowPackages": @[@"AZLNLGPTT3"]
	//	@"AllowProcesses": @{@"AZLNLGPTT3": @[@"com.fxfactory.FxFactory", @"com.fxfactory.FxFactory.helper"] }
	
	NSBundle *mainBundle = [NSBundle mainBundle];
	
	id prop = [mainBundle objectForInfoDictionaryKey:@"com.apple.security.app-sandbox"];
	if (!prop) {
		success = NO;
		NSLog(@"Error: Info.plist must have property 'com.apple.security.app-sandbox'");
	} else if (![prop isKindOfClass:NSNumber.class]) {
		success = NO;
		NSLog(@"Error: Info.plist property 'com.apple.security.app-sandbox' must be a Boolean");
	} else if (((NSNumber*)prop).boolValue) {
		success = NO;
		NSLog(@"Error: Info.plist property 'com.apple.security.app-sandbox' must be set to NO/false");
	}
	prop = [mainBundle objectForInfoDictionaryKey:@"com.apple.security.cs.disable-library-validation"];
	if (!prop) {
		success = NO;
		NSLog(@"Error: Info.plist must have property 'com.apple.security.cs.disable-library-validation'");
	} else if (![prop isKindOfClass:NSNumber.class]) {
		success = NO;
		NSLog(@"Error: Info.plist property 'com.apple.security.cs.disable-library-validation' must be a Boolean");
	} else if (!((NSNumber*)prop).boolValue) {
		success = NO;
		NSLog(@"Error: Info.plist property 'com.apple.security.cs.disable-library-validation' must be set to YES/true");
	}
	
	prop = [mainBundle objectForInfoDictionaryKey:@"NSUpdateSecurityPolicy"];
	
	if (!prop) {
		success = NO;
		NSLog(@"Error: Info.plist must have property 'NSUpdateSecurityPolicy'");
	} else if (![prop isKindOfClass:NSDictionary.class]) {
		success = NO;
		NSLog(@"Error: Info.plist property 'NSUpdateSecurityPolicy' must be a Dictionary");
	} else {
		NSDictionary *dict = (NSDictionary*)prop;
		if (!dict[@"AllowPackages"]) {
			success = NO;
			NSLog(@"Error: Info.plist property 'NSUpdateSecurityPolicy' does not have dictionary key 'AllowPackages' for software updating");
		} else if (![dict[@"AllowPackages"] isKindOfClass:NSArray.class]) {
			success = NO;
			NSLog(@"Error: Info.plist property 'NSUpdateSecurityPolicy' key 'AllowPackages' must be an array");
		} else {
			NSArray *allowedPackages = (NSArray*) dict[@"AllowPackages"];
			if (![allowedPackages containsObject:kFxFactoryPackageID]) {
				success = NO;
				NSLog(@"Error: Info.plist property 'NSUpdateSecurityPolicy' key 'AllowPackages' array does not contain value '%@'", kFxFactoryPackageID);
			}
		}
		
		if (!dict[@"AllowProcesses"]) {
			success = NO;
			NSLog(@"Error: Info.plist property 'NSUpdateSecurityPolicy' does not have dictionary key 'AllowProcesses' for software updating");
		} else if (![dict[@"AllowProcesses"] isKindOfClass:NSDictionary.class]) {
			success = NO;
			NSLog(@"Error: Info.plist property 'NSUpdateSecurityPolicy' key 'AllowProcesses' must be a dictionary for software updating");
		} else {
			dict = dict[@"AllowProcesses"];
			if (!dict[kFxFactoryPackageID]) {
				success = NO;
				NSLog(@"Error: Info.plist property 'NSUpdateSecurityPolicy'  key 'AllowProcesses' must have key '%@' for software updating", kFxFactoryPackageID);
			} else if (![dict[kFxFactoryPackageID] isKindOfClass:NSArray.class]) {
				success = NO;
				NSLog(@"Error: Info.plist property 'NSUpdateSecurityPolicy' key 'AllowProcesses' key '%@' is not an Array for software updating", kFxFactoryPackageID);
			} else {
				NSArray *processes = (NSArray*) dict[kFxFactoryPackageID];
				
				if (![processes containsObject:kFxFactoryBundleProcess]) {
					success = NO;
					NSLog(@"Error: Info.plist property 'NSUpdateSecurityPolicy' key 'AllowProcesses' key '%@' array does not contain value '%@'", kFxFactoryPackageID, kFxFactoryBundleProcess);
				}
				if (![processes containsObject:kFxFactoryBundleProcessHelper]) {
					success = NO;
					NSLog(@"Error: Info.plist property 'NSUpdateSecurityPolicy' key 'AllowProcesses' key '%@' array does not contain value '%@'", kFxFactoryPackageID, kFxFactoryBundleProcessHelper);
				}
			}
		}
	}
	return success;
}

@end



#pragma mark -

@implementation NSDictionary (FxFactoryProductUpdateResponse)

- (BOOL) fxFactoryUpdateCheckingEnabled
{
	NSNumber *value = self[kFxFactoryUpdateCheckingEnabled];
	if (!value || ![value isKindOfClass:NSNumber.class])
		return NO;
	return value.boolValue;
}

- (BOOL) fxFactoryUpdateCheckingPostponed
{
	NSNumber *value = self[kFxFactoryUpdateCheckingPostponed];
	if (!value || ![value isKindOfClass:NSNumber.class])
		return NO;
	return value.boolValue;
}

- (BOOL) fxFactoryUpdateCheckingNewVersionFound
{
	NSNumber *value = self[kFxFactoryUpdateCheckingNewVersionFound];
	if (!value || ![value isKindOfClass:NSNumber.class])
		return NO;
	return value.boolValue;
}

- (nullable NSError *) fxFactoryUpdateCheckingError
{
	NSError *value = self[kFxFactoryUpdateCheckingError];
	if (!value || ![value isKindOfClass:NSError.class])
		return NULL;
	return value;
}

- (nullable NSDictionary *) fxFactoryUpdateCheckingProductInfo
{
	NSDictionary *value = self[kFxFactoryUpdateCheckingProductInfo];
	if (!value || ![value isKindOfClass:NSDictionary.class])
		return NULL;
	return value;
}

@end


#pragma mark -

//  These can be used to access fxFactoryUpdateCheckingProductInfo as well

@implementation NSDictionary (FxFactoryProductInfoResponse)

- (nullable NSString *) fxFactoryProductName
{
	NSString *value = self[kFxFactoryLicensingProductName];
	if (!value || ![value isKindOfClass:NSString.class])
		return NULL;
	return value;
}

- (nullable NSString *) fxFactoryProductLatestVersion
{
	// @todo TEST THIS, what data is here? should it be parsed?
	NSString *value = self[kFxFactoryLicensingProductLatestVersion];
	if (!value || ![value isKindOfClass:NSString.class])
		return NULL;
	return value;
}

- (nullable NSString *) fxFactoryProductLatestVersionRequiredOSVersion
{
	// @todo TEST THIS, what data is here? should it be parsed?
	NSString *value = self[kFxFactoryLicensingProductLatestVersionRequiredOSVersion];
	if (!value || ![value isKindOfClass:NSString.class])
		return NULL;
	return value;
}

- (nullable NSString *) fxFactoryProductLatestVersionRequiredFxFactoryVersion
{
	// @todo TEST THIS, what data is here? should it be parsed?
	NSString *value = self[kFxFactoryLicensingProductLatestVersionRequiredFxFactoryVersion];
	if (!value || ![value isKindOfClass:NSString.class])
		return NULL;
	return value;
}

- (BOOL) fxFactoryProductIsDiscontinued
{
	// @todo TEST THIS, what data is here? should it be parsed?
	NSNumber *value = self[kFxFactoryLicensingProductIsDiscontinued];
	if (!value || ![value isKindOfClass:NSNumber.class])
		return NO;
	return value.boolValue;
}

//  return NAN if not found, use isnan() to check.
- (float) fxFactoryProductPriceInUSD
{
	// @todo TEST THIS, what data is here? should it be parsed?
	NSNumber *value = self[kFxFactoryLicensingProductPriceInUSD];
	if (!value || ![value isKindOfClass:NSNumber.class])
		return NAN;
	return value.floatValue;
}

@end


#pragma mark -

@implementation FxTileableEffectBase (FxFactory)

// Subclass this method to be informed when the user buys or refunds.

- (void)setFxFactoryLicenseState:(BOOL)licensed
{
	// @todo - set license targetpresets, names, flags, values, etc. here
	
	//Set or change any parameters or internal data structures to set the plugin license state.
	//  There should be no direct user interaction here, eg only changing UI elemnts, buttons, etc.
	// the parameter for showing "BUY" might have its hidden flag based on if its licensed.
}


// This automatically triggers setFxFactoryLicenseState
- (void)onFxFactoryRegisterLicensingStatusChange:(FxFactoryLicensingStatus)status
{
	[self setFxFactoryLicenseState:(status == kFxFactoryLicensingStatusProductLicensed)];
	
	/*
	 from https://fxfactory.com/developer/instant-product-activation/ is the text:
	"There are a few things a third-party application may choose to do in response to a change:
	 • Hide UI elements that mention trial mode / unavailable features, as well as any buttons that initiate the purchase process through FxFactory.
	 • Display a ”Thank you” message to the user, perhaps with information about the features that have been unlocked.
	 • Remind the user of any steps he or she must take in order to remove any watermarks. For example, visual or audio plug-ins whose output may have been cached by the host application, should be re-rendered in order for the watermark to be removed. FxFactory automatically displays these messages for native products implemented through its FxPack, FxTemplates or FxTextStyles product types."
	 
	 */
}

// called when FxFactoryShowProductUpdates action is taken.
- (void)onFxFactoryShowProductUpdates:(NSDictionary * _Nonnull) response
{
	// Time to do something interesting with
	// the values in productInfo:
	// - Is the latest version of my product newer
	//   than one already installed?
	// - Can the latest version of my product run
	//   on the current version of macOS?
	// - Is the user interested in being notified
	//   about updates
	// etc.
}

- (FxGripFactory * _Nullable)fxFactory
{
	return (FxGripFactory*)[self extensionForClass:FxGripFactory.class];
}

- (NSString * _Nullable)fxFactoryPluginUUID
{
	return self.fxFactory.fxFactoryPluginUUID;
}

- (NSString * _Nullable)fxFactoryPluginVersion
{
	return self.fxFactory.fxFactoryPluginVersion;
}

- (BOOL)fxFactoryPluginLicensed
{
	return self.fxFactory.pluginIsLicensed;
}


- (FxGripFactory * _Nullable)newFxFactoryExtension
{
	return [FxGripFactory.alloc init];
}

@end

