//
//  FxGripFactory.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripFactory_h
#define FxGripFactory_h

#import <FxFactory/FxFactory.h>
#import "FxExtension.h"
#import "FxTileableEffectBase.h"

#define kPropertiesFxFactoryDebugSetLicensed @"FxFactoryDebugSetLicensed"

#define kPropertiesFxFactoryPluginUUID @"FxFactoryPluginUUID"
#define kPropertiesFxFactoryPluginVersion @"FxFactoryPluginVersion"
#define kPropertiesFxFactoryActive @"FxFactoryActive"
#define kPropertiesFxFactoryWatermarkUnlicensed @"FxFactoryWatermark"
#define kPropertiesFxFactoryShowBuyButton @"FxFactoryShowBuyButton"
#define kPropertiesFxFactoryShowProductButton @"FxFactoryShowProductButton"
#define kPropertiesFxFactoryAutoChecking @"FxFactoryAutoChecking"

#define kFxFactoryPackageID @"AZLNLGPTT3"
#define kFxFactoryBundleProcess @"com.fxfactory.FxFactory"
#define kFxFactoryBundleProcessHelper @"com.fxfactory.FxFactory.helper"


#define kFxParameterType_FxFactory @"fxfactory"

#define FxParameterType_FxFactory 'FxFy'

// Post Notification Messages.
#define kFxFactoryBroadcastSetUpdateChecking @"FxFactory::IsUpdateChecking"
#define kFxFactoryBroadcastShowProduct @"FxFactory::ShowProduct"
#define kFxFactoryBroadcastShowBuy @"FxFactory::ShowBuy"
#define kFxFactoryBroadcastContactForm @"FxFactory::ContactForm"
#define kFxFactoryBroadcastContactFormRecipient @"FxFactoryValue::Recipient"
#define kFxFactoryBroadcastContactFormSubject @"FxFactoryValue::Subject"
#define kFxFactoryBroadcastContactFormMessage @"FxFactoryValue::Message"
#define kFxFactoryBroadcastProductUpdate @"FxFactory::ProductUpdate"
#define kFxFactoryBroadcastProductLicenseChange @"FxFactory::LicenseChange"
#define kFxFactoryBroadcastProductLicenseStatus @"FxFactoryValue::Status"



#define kParameterFxFactoryActiveOffset					1
#define kParameterFxFactoryProductUUIDOffset			2
#define kParameterFxFactoryProductVersionOffset			3
#define kParameterFxFactoryWaterMarkUnlicensedOffset	4
#define kParameterFxFactoryBuyButtonOffset				5
#define kParameterFxFactoryBuyButtonLabelOffset			6
#define kParameterFxFactoryProductButtonOffset			7
#define kParameterFxFactoryProductButtonLabelOffset		8
#define kParameterFxFactoryAutoCheckingOffset			9


// These can be set by the plugin to hard code
@protocol FxGripFactorySettings <NSObject>

@optional

- (BOOL)fxFactoryActive;
- (nonnull NSString*)fxFactoryProductUUID;
- (nonnull NSString*)fxFactoryProductVersion;
- (BOOL)fxFactoryWaterMarkUnlicensed;
- (BOOL)fxFactoryShowBuyButton;
- (BOOL)fxFactoryShowProductButton;
- (BOOL)fxFactoryAutoChecking;

@end



@interface FxGripFactoryParameters : FxGripFactory
{
	NSNumber *_fxFactoryActive;
	NSNumber *_fxFactoryWaterMarkUnlicensed;
	NSNumber *_fxFactoryShowBuyButton;
	NSNumber *_fxFactoryShowProductButton;
	NSNumber *_fxFactoryAutoChecking;
	
	NSNumber *_pluginLicenseStatus;
	
}

// This indicates if the user has FxFactory installed on their machine
@property (readonly) BOOL				fxFactoryIsInstalled;
@property (readonly) FxFactoryVersion	fxFactoryVersion;

@property (readonly, nonatomic) NSString* _Nonnull fxFactoryPluginUUID;
@property (readonly, nonatomic) NSString* _Nonnull fxFactoryPluginVersion;

// This indicates if the plugin is licensed in FxFactory
@property (readonly) BOOL pluginIsLicensed;

// This returns the status of the plugin license in FxFactory
@property (readonly) FxFactoryLicensingStatus pluginLicenseStatus;

//
@property (readwrite) BOOL pluginIsUpdateChecking;

@property (readonly, nonnull) id<FxGripFactorySettings> fxFactorySettingsObject;

@property (readonly) BOOL fxFactoryHasActive;
@property (readonly) BOOL fxFactoryHasPluginProduct; // UUID and Version
@property (readonly) BOOL fxFactoryHasWaterMarkUnlicensed;
@property (readonly) BOOL fxFactoryHasShowBuyButton;
@property (readonly) BOOL fxFactoryHasShowProductButton;
@property (readonly) BOOL fxFactoryHasAutoChecking;

@property (readwrite, nonatomic) BOOL fxFactoryActive;
@property (readwrite, nonatomic) BOOL fxFactoryWaterMarkUnlicensed;
@property (readwrite, nonatomic) BOOL fxFactoryShowBuyButton;
@property (readwrite, nonatomic) BOOL fxFactoryShowProductButton;
@property (readwrite, nonatomic) BOOL fxFactoryAutoChecking;

- (void)setFxFactorySettingsObject:(nullable id<FxGripFactorySettings>)settingsObject;

- (BOOL)showFxFactoryProduct;
- (BOOL)showFxFactoryBuyPlugin;

//recipient must be "@fxfactory.com", like for sending fxFactory errors back to them.
- (BOOL)showContactForm:(NSString * _Nullable)subject message:(NSString * _Nullable) message;
- (BOOL)showContactForm:(NSString * _Nullable)recipient subject:(NSString * _Nullable)subject message:(NSString * _Nullable) message;


- (BOOL)extLoadWithEffect:(GuruFxTileableEffect*_Nonnull)effect;
- (void)extProcessParameters:(nonnull NSMutableArray<NSMutableDictionary*> *)parameters;
- (FxParameterType)extParameterTypeForString:(nullable NSString *)typeString;
- (nullable Class)extParameterClassForType:(FxParameterType)type;
- (void)extAddedToDocument;

@end




@interface NSDictionary (FxFactoryProductUpdateResponse)

- (BOOL) fxFactoryUpdateCheckingEnabled;
- (BOOL) fxFactoryUpdateCheckingPostponed;
- (BOOL) fxFactoryUpdateCheckingNewVersionFound;
- (nullable NSError *) fxFactoryUpdateCheckingError;
- (nullable NSDictionary *) fxFactoryUpdateCheckingProductInfo;

@end

@interface NSDictionary (FxFactoryProductInfoResponse)

- (nullable NSString *) fxFactoryProductName;
- (nullable NSString *) fxFactoryProductLatestVersion;
- (nullable NSString *) fxFactoryProductLatestVersionRequiredOSVersion;
- (nullable NSString *) fxFactoryProductLatestVersionRequiredFxFactoryVersion;
- (BOOL) fxFactoryProductIsDiscontinued;
- (float) fxFactoryProductPriceInUSD;

@end




@interface FxTileableEffectBase (FxFactory)

// change plugin parameter UI
- (void)setFxFactoryLicenseState:(BOOL)licensed;

- (void)onFxFactoryRegisterLicensingStatusChange:(FxFactoryLicensingStatus) status;
- (void)onFxFactoryShowProductUpdates:(NSDictionary * _Nonnull) response;


- (FxGripFactory*_Nullable)fxFactory;
- (NSString * _Nullable)fxFactoryPluginUUID;
- (NSString * _Nullable)fxFactoryPluginVersion;
- (FxGripFactory * _Nullable)newFxFactoryExtension;

@end


#endif
