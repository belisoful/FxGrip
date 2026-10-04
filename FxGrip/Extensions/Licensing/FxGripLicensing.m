/*!
	@file       FxGripLicensing.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripLicensing
	@abstract   Implements the store-neutral licensing extension.
	@discussion Introduced in FxGrip 0.1.0. The provider's status callback and completion blocks run
	            on their own threads, so the cached status is synchronized and the toggle is written
	            through an out-of-band parameter access. The watermark decision is isolated behind
	            `watermarkConfigurationForStatus:` and the render behind `renderWatermark:ontoImage:error:`.
*/

#import "FxGripLicensing.h"
#import "FxGripOOBParameterAccess.h"
#import "FxGripTileableEffect+Extensions.h"
#import "FxGripTileableEffect+Versioning.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripParameter.h"
#import "FxGripRegression.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGrip_ARC.h"

NSString *const FxGripLicensingUpdateInfoNewVersionFound	= @"FxGripLicensingUpdateInfo_NewVersionFound";
NSString *const FxGripLicensingUpdateInfoPostponed			= @"FxGripLicensingUpdateInfo_Postponed";
NSString *const FxGripLicensingUpdateInfoError				= @"FxGripLicensingUpdateInfo_Error";
NSString *const FxGripLicensingUpdateInfoProductInfo		= @"FxGripLicensingUpdateInfo_ProductInfo";
NSString *const FxGripLicensingUpdateInfoProviderResponse	= @"FxGripLicensingUpdateInfo_ProviderResponse";

NSString *const FxGripLicensingProductInfoProductName			= @"FxGripLicensingProductInfo_ProductName";
NSString *const FxGripLicensingProductInfoLatestVersion			= @"FxGripLicensingProductInfo_LatestVersion";
NSString *const FxGripLicensingProductInfoRequiredOSVersion		= @"FxGripLicensingProductInfo_RequiredOSVersion";
NSString *const FxGripLicensingProductInfoRequiredStoreVersion	= @"FxGripLicensingProductInfo_RequiredStoreVersion";
NSString *const FxGripLicensingProductInfoDiscontinued			= @"FxGripLicensingProductInfo_Discontinued";
NSString *const FxGripLicensingProductInfoPriceUSD				= @"FxGripLicensingProductInfo_PriceUSD";
NSString *const FxGripLicensingProductInfoProviderResponse		= @"FxGripLicensingProductInfo_ProviderResponse";

NSNotificationName const FxGripLicensingStatusChangeName		= @"FxGripLicensing::StatusChange";
NSNotificationName const FxGripLicensingShowBuyName				= @"FxGripLicensing::ShowBuy";
NSNotificationName const FxGripLicensingShowProductName			= @"FxGripLicensing::ShowProduct";
NSNotificationName const FxGripLicensingShowLicenseEntryName	= @"FxGripLicensing::ShowLicenseEntry";
NSNotificationName const FxGripLicensingDeactivateName			= @"FxGripLicensing::Deactivate";
NSNotificationName const FxGripLicensingSetUpdateCheckingName	= @"FxGripLicensing::SetUpdateChecking";
NSNotificationName const FxGripLicensingProductUpdateName		= @"FxGripLicensing::ProductUpdate";
NSNotificationName const FxGripLicensingProductInfoName			= @"FxGripLicensing::ProductInfo";
NSNotificationName const FxGripLicensingSupportFormName			= @"FxGripLicensing::SupportForm";

NSString *const FxGripLicensingStatusKey		= @"FxGripLicensingValue::Status";
NSString *const FxGripLicensingProviderNameKey	= @"FxGripLicensingValue::ProviderName";
NSString *const FxGripLicensingEntitlementKey	= @"FxGripLicensingValue::Entitlement";
NSString *const FxGripLicensingEnabledKey		= @"FxGripLicensingValue::Enabled";
NSString *const FxGripLicensingSubjectKey		= @"FxGripLicensingValue::Subject";
NSString *const FxGripLicensingMessageKey		= @"FxGripLicensingValue::Message";
NSString *const FxGripLicensingErrorKey			= @"FxGripLicensingValue::Error";

/*! Parses "major.minor.patch"; missing components read as zero. */
static NSOperatingSystemVersion FxGripLicensingVersionFromString(NSString *string)
{
	NSOperatingSystemVersion version = {0, 0, 0};
	NSArray<NSString *> *components = [string componentsSeparatedByString:@"."];
	if (components.count > 0) {
		version.majorVersion = components[0].integerValue;
	}
	if (components.count > 1) {
		version.minorVersion = components[1].integerValue;
	}
	if (components.count > 2) {
		version.patchVersion = components[2].integerValue;
	}
	return version;
}

static NSMutableDictionary<NSString *, Class> *FxGripLicensingProviderRegistry(void)
{
	static NSMutableDictionary<NSString *, Class> *registry = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		registry = NSMutableDictionary.new;
	});
	return registry;
}

/*!
	@abstract	The extension that drives a plugin's licensing through a provider.
	@discussion	Introduced in FxGrip 0.1.0. Settings resolve from the settings object, the parameter
				dictionary, and the `licensing` plugin property in that order. A declared Boolean is
				stored as an NSNumber; a nil store means the setting is undeclared and its parameter
				is added.
*/
@implementation FxGripLicensing
{
	id<FxGripLicensingProvider>		_provider;
	id<FxGripLicensingSettings>		_settingsObject;

	NSString *_productID;
	NSString *_productVersion;
	NSString *_licensedVersion;
	NSNumber *_active;
	NSNumber *_watermarkUnlicensed;
	NSNumber *_watermarkTrial;
	NSNumber *_showBuyButton;
	NSNumber *_showProductButton;
	NSNumber *_autoChecking;
	FxGripWatermarkConfiguration *_unlicensedWatermarkConfiguration;
	FxGripWatermarkConfiguration *_trialWatermarkConfiguration;
	NSDictionary *_unlicensedWatermarkDictionary;
	NSDictionary *_trialWatermarkDictionary;

	BOOL _hasActive;
	BOOL _hasWatermarkUnlicensed;
	BOOL _hasWatermarkTrial;
	BOOL _hasShowBuyButton;
	BOOL _hasShowProductButton;
	BOOL _hasAutoChecking;
	BOOL _addedLicenseEntryButton;
	BOOL _addedDeactivateButton;

	NSNumber *_cachedStatus;
	NSString *_observedProductID;
}

@synthesize provider = _provider;
@synthesize licensedVersion = _licensedVersion;
@synthesize hasActive = _hasActive;
@synthesize hasWatermarkUnlicensed = _hasWatermarkUnlicensed;
@synthesize hasWatermarkTrial = _hasWatermarkTrial;
@synthesize hasShowBuyButton = _hasShowBuyButton;
@synthesize hasShowProductButton = _hasShowProductButton;
@synthesize hasAutoChecking = _hasAutoChecking;

#pragma mark -
#pragma mark Provider registry

+ (void)registerProviderClass:(Class)providerClass forName:(NSString *)name
{
	if (![providerClass conformsToProtocol:@protocol(FxGripLicensingProvider)]) {
		NSLog(@"Error: %@ does not adopt FxGripLicensingProvider and is not registered as the '%@' licensing provider.", providerClass, name);
		return;
	}
	NSMutableDictionary *registry = FxGripLicensingProviderRegistry();
	@synchronized (registry) {
		registry[name.lowercaseString] = providerClass;
	}
}

+ (Class)providerClassForName:(NSString *)name
{
	NSMutableDictionary *registry = FxGripLicensingProviderRegistry();
	@synchronized (registry) {
		return registry[name.lowercaseString];
	}
}

+ (NSArray<NSString *> *)registeredProviderNames
{
	NSMutableDictionary *registry = FxGripLicensingProviderRegistry();
	@synchronized (registry) {
		return [registry.allKeys sortedArrayUsingSelector:@selector(compare:)];
	}
}

+ (NSString *)providerNameForPluginProperties:(NSDictionary *)pluginProperties
{
	id licensing = pluginProperties[kProPlugPlugInX_LicensingProperty];
	if ([licensing isKindOfClass:NSString.class]) {
		return licensing;
	}
	if ([licensing isKindOfClass:NSDictionary.class]) {
		id provider = licensing[kFxGripLicensingProperty_Provider];
		if ([provider isKindOfClass:NSString.class]) {
			return provider;
		}
	}
	// Read the key directly: the plugin-property accessors answer only a full registration record.
	id fxFactory = pluginProperties[kProPlugPlugInX_FxFactoryProperty];
	if ([fxFactory isKindOfClass:NSNumber.class] && ((NSNumber *)fxFactory).boolValue) {
		return kFxParameterType_FxFactory;
	}
	return nil;
}

#pragma mark -
#pragma mark Creation

- (instancetype)initWithProvider:(id<FxGripLicensingProvider>)provider
{
	self = [super init];
	if (self) {
		_provider = provider;
	}
	return self;
}

- (instancetype)init
{
	return [self initWithProvider:nil];
}

- (void)dealloc
{
	[self stopObserving];

	SUPER_DEALLOC();
}

// The base types `effect` as id<FxGripTileableEffect>; the class-level accessors and the
// (Licensing) category live on FxGripTileableEffect, so route through a cast.
- (FxGripTileableEffect *)fxEffect
{
	return self.effect.effectBase;
}

/*! The `licensing` plugin property when it is a dictionary, else nil. */
- (NSDictionary *)licensingDictionary
{
	id licensing = self.fxEffect.pluginProperties[kProPlugPlugInX_LicensingProperty];
	return [licensing isKindOfClass:NSDictionary.class] ? licensing : nil;
}

- (BOOL)providerResponds:(SEL)selector
{
	return _provider != nil && [_provider respondsToSelector:selector];
}

#pragma mark -
#pragma mark Observation

- (void)startObservingProduct:(NSString *)productID
{
	[self stopObserving];

	if (_provider == nil || productID.length == 0) {
		return;
	}
	_observedProductID = productID;
	// The handler reaches the extension through a weak reference. Capturing self would retain
	// it for the life of the provider's registration, so dealloc could never run the stop.
	__weak typeof(self) weakSelf = self;
	[_provider startObservingProduct:productID handler:^(FxGripLicenseStatus status) {
		[weakSelf providerDidReportStatus:status];
	}];
}

- (void)stopObserving
{
	if (_observedProductID != nil) {
		// Stop with the ID the observation started under, not the current one: the product ID
		// can change between start and stop, and the provider keys the observation by product.
		[_provider stopObservingProduct:_observedProductID];
		_observedProductID = nil;
	}
}

/*!
	@method		providerDidReportStatus:
	@abstract	Applies a status the provider reports from its observation or a completion.
	@discussion	Introduced in FxGrip 0.1.0. Runs on the reporting thread. The status is cached, the
				toggle and button flags are written out of band, the effect hook runs, and the
				status change notification is posted. */
- (void)providerDidReportStatus:(FxGripLicenseStatus)status
{
	[self setCachedStatus:@(status)];

	FxGripOOBParameterAccess *__attribute__((unused)) accessor = [FxGripOOBParameterAccess access:self.effect];

	[self setBoolValue:FxGripLicenseStatusIsLicensed(status)];
	[self applyButtonVisibilityForStatus:status];

	[self.fxEffect licensingStatusDidChange:status];

	[self.effect.notifier postNotificationName:FxGripLicensingStatusChangeName object:self userInfo:[self statusUserInfo:status]];
}

- (NSDictionary *)statusUserInfo:(FxGripLicenseStatus)status
{
	NSMutableDictionary *userInfo = NSMutableDictionary.new;
	userInfo[FxGripLicensingStatusKey] = @(status);
	userInfo[FxGripLicensingProviderNameKey] = _provider.providerName;
	userInfo[FxGripLicensingEntitlementKey] = self.entitlement;
	return userInfo;
}

/*! Shows Enter License while unlicensed and Deactivate while licensed, for the buttons that were added. */
- (void)applyButtonVisibilityForStatus:(FxGripLicenseStatus)status
{
	BOOL licensed = FxGripLicenseStatusIsLicensed(status);
	if (_addedLicenseEntryButton) {
		self.effect[self.parameterID + kParameterLicensingLicenseEntryButtonOffset].flagHidden = licensed;
	}
	if (_addedDeactivateButton) {
		self.effect[self.parameterID + kParameterLicensingDeactivateButtonOffset].flagHidden = !licensed;
	}
}

#pragma mark -
#pragma mark Status

- (FxGripLicenseStatus)licenseStatus
{
	// The provider reports from its own thread; guard the lazy read-modify-write against it.
	// All writes go through setCachedStatus:.
	@synchronized (self) {
		if (_cachedStatus == nil) {
			if (_provider == nil) {
				return FxGripLicenseStatusUnknown;
			}
			if (_licensedVersion != nil && [_provider respondsToSelector:@selector(licenseStatusForProduct:version:)]) {
				_cachedStatus = @([_provider licenseStatusForProduct:self.productID version:FxGripLicensingVersionFromString(_licensedVersion)]);
			} else {
				_cachedStatus = @([_provider licenseStatusForProduct:self.productID]);
			}
		}
		return _cachedStatus.integerValue;
	}
}

- (void)setCachedStatus:(NSNumber *)status
{
	@synchronized (self) {
		_cachedStatus = status;
	}
}

- (BOOL)isLicensed
{
	return FxGripLicenseStatusIsLicensed(self.licenseStatus);
}

- (FxGripLicenseStatus)licenseStatusForVersion:(NSOperatingSystemVersion)version
{
	if ([self providerResponds:@selector(licenseStatusForProduct:version:)]) {
		return [_provider licenseStatusForProduct:self.productID version:version];
	}
	return FxGripLicenseStatusUnknown;
}

- (BOOL)upgradeAvailable
{
	if ([self providerResponds:@selector(upgradeAvailableForProduct:)]) {
		return [_provider upgradeAvailableForProduct:self.productID];
	}
	return NO;
}

- (FxGripLicenseEntitlement *)entitlement
{
	if ([self providerResponds:@selector(entitlementForProduct:)]) {
		return [_provider entitlementForProduct:self.productID];
	}
	return nil;
}

- (BOOL)updateChecking
{
	if ([self providerResponds:@selector(updateCheckingEnabledForProduct:)]) {
		return [_provider updateCheckingEnabledForProduct:self.productID];
	}
	return NO;
}

- (void)setUpdateChecking:(BOOL)enabled
{
	if (![self providerResponds:@selector(setUpdateCheckingEnabled:forProduct:)]) {
		return;
	}
	[self.effect.notifier postNotificationName:FxGripLicensingSetUpdateCheckingName object:self userInfo:@{FxGripLicensingEnabledKey: @(enabled)}];
	[_provider setUpdateCheckingEnabled:enabled forProduct:self.productID];
}

#pragma mark -
#pragma mark Product identity

- (NSString *)productID
{
	if (_productID == nil) {
		return self.effect[self.parameterID + kParameterLicensingProductIDOffset].stringValue ?: @"";
	}
	return _productID;
}

- (NSString *)productVersion
{
	if (_productVersion == nil) {
		if (self.hasProduct) {
			return self.fxEffect.pluginStringVersion ?: @"";
		}
		return self.effect[self.parameterID + kParameterLicensingProductVersionOffset].stringValue ?: @"";
	}
	return _productVersion;
}

- (BOOL)hasProduct
{
	return _productID != nil;
}

#pragma mark -
#pragma mark Actions

- (BOOL)buyProduct
{
	if (![self providerResponds:@selector(buyProduct:)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxGripLicensingShowBuyName object:self];
	return [_provider buyProduct:self.productID];
}

- (BOOL)showProduct
{
	if (![self providerResponds:@selector(showProduct:)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxGripLicensingShowProductName object:self];
	return [_provider showProduct:self.productID];
}

- (BOOL)showLicenseEntry
{
	if (![self providerResponds:@selector(showLicenseEntryForProduct:)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxGripLicensingShowLicenseEntryName object:self];
	return [_provider showLicenseEntryForProduct:self.productID];
}

- (void)deactivateLicense
{
	if (![self providerResponds:@selector(deactivateLicenseForProduct:completion:)]) {
		return;
	}
	[self.effect.notifier postNotificationName:FxGripLicensingDeactivateName object:self];
	__weak typeof(self) weakSelf = self;
	[_provider deactivateLicenseForProduct:self.productID completion:^(FxGripLicenseStatus status, NSError *error) {
		if (error != nil) {
			NSLog(@"Error: licensing deactivation failed: %@", error);
		}
		[weakSelf providerDidReportStatus:status];
	}];
}

- (BOOL)showSupportFormWithSubject:(NSString *)subject message:(NSString *)message
{
	if (![self providerResponds:@selector(showSupportFormWithSubject:message:)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxGripLicensingSupportFormName object:self
									  userInfo:@{FxGripLicensingSubjectKey: subject ?: @"",
												 FxGripLicensingMessageKey: message ?: @""}];
	return [_provider showSupportFormWithSubject:subject message:message];
}

- (void)checkForUpdates
{
	[self checkForUpdates:NO handler:nil];
}

- (void)checkForUpdates:(BOOL)force handler:(FxGripLicenseUpdateInfoHandler)handler
{
	if (![self providerResponds:@selector(checkForUpdatesForProduct:version:force:handler:)]) {
		return;
	}
	__weak typeof(self) weakSelf = self;
	[_provider checkForUpdatesForProduct:self.productID version:self.productVersion force:force handler:^(NSDictionary<NSString *, id> *info) {
		typeof(self) strongSelf = weakSelf;
		if (info == nil || strongSelf == nil) {
			return;
		}
		[strongSelf.fxEffect licensingDidReceiveUpdateInfo:info];
		if (handler) {
			handler(info);
		}
		[strongSelf.effect.notifier postNotificationName:FxGripLicensingProductUpdateName object:strongSelf userInfo:info];
	}];
}

- (void)fetchProductInfo:(FxGripLicenseProductInfoHandler)handler
{
	if (![self providerResponds:@selector(fetchProductInfoForProduct:handler:)]) {
		return;
	}
	__weak typeof(self) weakSelf = self;
	[_provider fetchProductInfoForProduct:self.productID handler:^(NSDictionary<NSString *, id> *info, NSError *error) {
		typeof(self) strongSelf = weakSelf;
		if (handler) {
			handler(info, error);
		}
		if (strongSelf == nil) {
			return;
		}
		NSDictionary *userInfo = info ?: (error != nil ? @{FxGripLicensingErrorKey: error} : @{});
		[strongSelf.effect.notifier postNotificationName:FxGripLicensingProductInfoName object:strongSelf userInfo:userInfo];
	}];
}

#pragma mark -
#pragma mark Host configuration

- (NSBundle *)hostConfigurationBundle
{
	return NSBundle.mainBundle;
}

- (NSArray<NSString *> *)hostConfigurationProblems
{
	if (![self providerResponds:@selector(hostConfigurationProblemsForBundle:)]) {
		return @[];
	}
	NSArray<NSString *> *problems = [_provider hostConfigurationProblemsForBundle:self.hostConfigurationBundle];
	for (NSString *problem in problems) {
		NSLog(@"Error: %@ licensing host configuration: %@", _provider.providerName, problem);
	}
	return problems;
}

#pragma mark -
#pragma mark Watermark

- (FxGripWatermarkConfiguration *)watermarkConfigurationForStatus:(FxGripLicenseStatus)status
{
	switch (status) {
		case FxGripLicenseStatusLicensed:
		case FxGripLicenseStatusOfflineGrace:
			return nil;
		case FxGripLicenseStatusTrial:
			return self.watermarkTrial ? self.trialWatermarkConfiguration : nil;
		case FxGripLicenseStatusUnknown:
		case FxGripLicenseStatusInvalidProduct:
		case FxGripLicenseStatusUnlicensed:
		case FxGripLicenseStatusExpired:
		case FxGripLicenseStatusRevoked:
			return self.watermarkUnlicensed ? self.unlicensedWatermarkConfiguration : nil;
	}
	return self.watermarkUnlicensed ? self.unlicensedWatermarkConfiguration : nil;
}

// The render is isolated behind this seam so the watermark DECISION is testable with a mock
// that records the call; the GPU work lives in FxGripWatermark and is verified in a live host.
- (BOOL)renderWatermark:(FxGripWatermarkConfiguration *)configuration ontoImage:(FxImageTile *)destinationImage error:(NSError *_Nullable *_Nullable)outError
{
	FxGripWatermark *watermark = [FxGripWatermark watermarkWithConfiguration:configuration];
	return [watermark renderOntoImageTile:destinationImage error:outError];
}

- (FxGripWatermarkConfiguration *)defaultUnlicensedWatermarkConfiguration
{
	FxGripWatermarkConfiguration *configuration = [FxGripWatermarkConfiguration configurationWithText:@""];
	configuration.style = FxGripWatermarkStyleSingle;
	configuration.fontSize = 99.0;
	configuration.angleDegrees = 10.0;
	configuration.color = NSColor.whiteColor;
	configuration.shadowColor = NSColor.blueColor;
	configuration.blur = 10.0;
	configuration.opacity = 0.73;
	return configuration;
}

- (FxGripWatermarkConfiguration *)defaultTrialWatermarkConfiguration
{
	FxGripWatermarkConfiguration *configuration = [FxGripWatermarkConfiguration configurationWithText:@""];
	configuration.style = FxGripWatermarkStyleCorner;
	configuration.corner = FxGripWatermarkCornerBottomRight;
	configuration.fontSize = 48.0;
	configuration.opacity = 0.5;
	return configuration;
}

/*! A copy of the configuration with empty text replaced by the resolved text. */
- (FxGripWatermarkConfiguration *)configuration:(FxGripWatermarkConfiguration *)configuration withDefaultText:(NSString *)text
{
	FxGripWatermarkConfiguration *copy = [configuration copy];
	if (copy.text.length == 0) {
		copy.text = text;
	}
	return copy;
}

- (FxGripWatermarkConfiguration *)unlicensedWatermarkConfiguration
{
	if (_unlicensedWatermarkConfiguration == nil) {
		FxGripWatermarkConfiguration *configuration = self.defaultUnlicensedWatermarkConfiguration;
		if (_unlicensedWatermarkDictionary != nil) {
			configuration = [configuration configurationByApplyingDictionary:_unlicensedWatermarkDictionary];
		}
		_unlicensedWatermarkConfiguration = configuration;
	}
	return [self configuration:_unlicensedWatermarkConfiguration withDefaultText:self.fxEffect.pluginDisplayName ?: @""];
}

- (void)setUnlicensedWatermarkConfiguration:(FxGripWatermarkConfiguration *)configuration
{
	_unlicensedWatermarkConfiguration = [configuration copy];
}

- (FxGripWatermarkConfiguration *)trialWatermarkConfiguration
{
	if (_trialWatermarkConfiguration == nil) {
		FxGripWatermarkConfiguration *configuration = self.defaultTrialWatermarkConfiguration;
		if (_trialWatermarkDictionary != nil) {
			configuration = [configuration configurationByApplyingDictionary:_trialWatermarkDictionary];
		}
		_trialWatermarkConfiguration = configuration;
	}
	NSString *name = self.fxEffect.pluginDisplayName;
	NSString *text = name.length > 0 ? [name stringByAppendingString:@" Trial"] : @"Trial";
	return [self configuration:_trialWatermarkConfiguration withDefaultText:text];
}

- (void)setTrialWatermarkConfiguration:(FxGripWatermarkConfiguration *)configuration
{
	_trialWatermarkConfiguration = [configuration copy];
}

#pragma mark -
#pragma mark Settings

- (id<FxGripLicensingSettings>)settingsObject
{
	if (_settingsObject == nil) {
		if ([self.effect conformsToProtocol:@protocol(FxGripLicensingSettings)]) {
			return (id<FxGripLicensingSettings>)self.effect;
		}
		return nil;
	}
	return _settingsObject;
}

- (void)setSettingsObject:(id<FxGripLicensingSettings>)settingsObject
{
	_settingsObject = settingsObject;
}

/*! The declared value for a key: the parameter dictionary first, then the `licensing` plugin property. */
- (id)declaredValueForKey:(NSString *)key inParameter:(NSDictionary *)parameter
{
	id value = parameter[key];
	if (value == nil) {
		value = self.licensingDictionary[key];
	}
	return value;
}

- (NSNumber *)declaredBoolForKey:(NSString *)key inParameter:(NSDictionary *)parameter
{
	id value = [self declaredValueForKey:key inParameter:parameter];
	return [value isKindOfClass:NSNumber.class] ? value : nil;
}

- (NSDictionary *)declaredDictionaryForKey:(NSString *)key inParameter:(NSDictionary *)parameter
{
	id value = [self declaredValueForKey:key inParameter:parameter];
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

/*! A declared product field: a string, or the plugin's own value when the declaration is `YES`. */
- (NSString *)declaredProductStringForKey:(NSString *)key inParameter:(NSDictionary *)parameter pluginValue:(NSString *)pluginValue
{
	id value = [self declaredValueForKey:key inParameter:parameter];
	if ([value isKindOfClass:NSString.class]) {
		return value;
	}
	if ([value isKindOfClass:NSNumber.class] && ((NSNumber *)value).boolValue) {
		return pluginValue ?: @"";
	}
	return nil;
}

- (BOOL)licensingActive
{
	if (_hasActive && _active != nil) {
		return _active.boolValue;
	} else if (!_hasActive && self.hasProduct) {
		return YES;
	} else if (_addedToEffect) {
		return self.effect[self.parameterID + kParameterLicensingActiveOffset].boolValue;
	}
	return NO;
}

- (void)setLicensingActive:(BOOL)active
{
	if ((_hasActive && _active != nil) || (!_hasActive && self.hasProduct)) {
		NSLog(@"Error: Cannot setLicensingActive when preset");
	} else if (_addedToEffect) {
		self.effect[self.parameterID + kParameterLicensingActiveOffset].boolValue = active;
	} else {
		NSLog(@"Error: Cannot setLicensingActive before being added to effect");
	}
}

- (BOOL)watermarkUnlicensed
{
	BOOL result = YES;
	if (_hasWatermarkUnlicensed && _watermarkUnlicensed != nil) {
		result = _watermarkUnlicensed.boolValue;
	} else if (!_hasWatermarkUnlicensed && _addedToEffect) {
		result = self.effect[self.parameterID + kParameterLicensingWatermarkUnlicensedOffset].boolValue;
	}
	return result && self.licensingActive;
}

- (void)setWatermarkUnlicensed:(BOOL)active
{
	if (_hasWatermarkUnlicensed) {
		NSLog(@"Error: Cannot setWatermarkUnlicensed when preset");
	} else if (_addedToEffect) {
		self.effect[self.parameterID + kParameterLicensingWatermarkUnlicensedOffset].boolValue = active;
	} else {
		NSLog(@"Error: Cannot setWatermarkUnlicensed before being added to effect");
	}
}

- (BOOL)watermarkTrial
{
	BOOL result = NO;
	if (_hasWatermarkTrial && _watermarkTrial != nil) {
		result = _watermarkTrial.boolValue;
	} else if (!_hasWatermarkTrial && _addedToEffect) {
		result = self.effect[self.parameterID + kParameterLicensingWatermarkTrialOffset].boolValue;
	}
	return result && self.licensingActive;
}

- (void)setWatermarkTrial:(BOOL)active
{
	if (_hasWatermarkTrial) {
		NSLog(@"Error: Cannot setWatermarkTrial when preset");
	} else if (_addedToEffect) {
		self.effect[self.parameterID + kParameterLicensingWatermarkTrialOffset].boolValue = active;
	} else {
		NSLog(@"Error: Cannot setWatermarkTrial before being added to effect");
	}
}

- (BOOL)showBuyButton
{
	if (_hasShowBuyButton && _showBuyButton != nil) {
		return _showBuyButton.boolValue;
	}
	return [self providerResponds:@selector(buyProduct:)];
}

- (BOOL)showProductButton
{
	if (_hasShowProductButton && _showProductButton != nil) {
		return _showProductButton.boolValue;
	}
	return [self providerResponds:@selector(showProduct:)];
}

- (BOOL)autoChecking
{
	if (_hasAutoChecking && _autoChecking != nil) {
		return _autoChecking.boolValue;
	} else if (!_hasAutoChecking && _addedToEffect && [self providerResponds:@selector(checkForUpdatesForProduct:version:force:handler:)]) {
		return self.effect[self.parameterID + kParameterLicensingAutoCheckingOffset].boolValue;
	}
	return NO;
}

- (void)setAutoChecking:(BOOL)active
{
	if (_hasAutoChecking) {
		NSLog(@"Error: Cannot setAutoChecking when preset");
	} else if (_addedToEffect) {
		self.effect[self.parameterID + kParameterLicensingAutoCheckingOffset].boolValue = active;
	} else {
		NSLog(@"Error: Cannot setAutoChecking before being added to effect");
	}
}

#pragma mark -
#pragma mark Extension hooks

/*!
	@method		extAddParameters:
	@abstract	Configures the licensing toggle and adds the support parameters the plugin omits.
	@discussion	Introduced in FxGrip 0.1.0. The method finds or creates the licensing parameter, sets
				it to a hidden non-animatable toggle, resolves each setting, and appends the
				product, watermark, buy, product-page, update-checking, license-entry, and
				deactivation parameters that are not hard-coded and that the provider can back. A
				declared licensing parameter is configured in place and stays at its position; a
				missing one is created and appended. The method returns early only when the
				configuration declares the integration inactive. Without a declared active state,
				a resolved product activates the integration, and with neither the hidden
				Licensing Active toggle is added so the plugin can switch it on at run time. */
- (void)extAddParameters:(nonnull NSNotification *)notification
{
	NSMutableArray<NSMutableDictionary *> *parameters = notification.userInfo.fxEffectParameters;
	NSMutableArray *components = NSMutableArray.new;
	NSMutableDictionary *parameter = nil;
	id<FxGripLicensingSettings> settings = self.settingsObject;

	// Find the licensing parameter. The type is matched as a string: the guarded
	// parameterType accessor maps only the standard types, so the custom type would read as
	// None and the entry would be missed.
	for (NSMutableDictionary *candidate in parameters) {
		id type = candidate[kFxParameterProperty_Type];
		if ([type isKindOfClass:NSString.class]
			&& ([type isEqualToString:kFxParameterType_Licensing] || [type isEqualToString:kFxParameterType_FxFactory])) {
			parameter = candidate;
			break;
		}
	}

	BOOL parameterWasDeclared = parameter != nil;
	if (!parameterWasDeclared) {
		parameter = @{}.mutableCopy;
	}

	if (!parameter[kFxParameterProperty_Factory]) {
		parameter[kFxParameterProperty_Factory] = self;
	}

	if (parameter[kFxParameterProperty_Id]) {
		_parameterID = ((NSNumber *)parameter[kFxParameterProperty_Id]).intValue;
	} else {
		_parameterID = kFxParameterId_Licensing;
		parameter[kFxParameterProperty_Id] = @(_parameterID);
	}

	parameter[kFxParameterProperty_Type] = kFxParameterType_Toggle;

	if (!parameter[kFxParameterProperty_Name]) {
		parameter[kFxParameterProperty_Name] = @"Product Licensed";
	}
	if (!parameter[kFxParameterProperty_Description]) {
		parameter[kFxParameterProperty_Description] = @"Licensing";
	}

	parameter[kFxParameterProperty_Flags] = parameter.parameterFlagsArray.mutableCopy;
	NSArray *enforcementFlags = @[kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA, kParameterFlagString_NO_DEBUG];
	[parameter[kFxParameterProperty_Flags] removeObjectsInArray:enforcementFlags];
	[parameter[kFxParameterProperty_Flags] addObjectsFromArray:enforcementFlags];

	// A declared entry is already in the array and is configured in place.
	if (!parameterWasDeclared) {
		[components addObject:parameter];
	}

	NSDictionary *licensingParameter = parameter;
	// The support parameters share the toggle's group; an undeclared parent reads as the top level.
	NSNumber *parentID = @(licensingParameter.parameterParentID);

	// Active.
	if ([settings respondsToSelector:@selector(licensingActive)]) {
		_active = @([settings licensingActive]);
	} else {
		_active = [self declaredBoolForKey:kFxGripLicensingProperty_Active inParameter:parameter];
	}
	_hasActive = _active != nil;

	// Read the declaration, not licensingActive: that reader depends on the product resolved
	// below and on the Active parameter, which is not registered until this pass returns.
	if (_active != nil && !_active.boolValue) {
		return;
	}

	// Product identity.
	if ([settings respondsToSelector:@selector(licensingProductID)]) {
		_productID = [settings licensingProductID];
	}
	if (_productID == nil) {
		_productID = [self declaredProductStringForKey:kFxGripLicensingProperty_ProductID inParameter:parameter pluginValue:self.fxEffect.pluginUUID];
	}
	if (_productID != nil) {
		if ([settings respondsToSelector:@selector(licensingProductVersion)]) {
			_productVersion = [settings licensingProductVersion];
		}
		if (_productVersion == nil) {
			_productVersion = [self declaredProductStringForKey:kFxGripLicensingProperty_ProductVersion inParameter:parameter pluginValue:self.fxEffect.pluginStringVersion];
		}
	}
	if ([settings respondsToSelector:@selector(licensingLicensedVersion)]) {
		_licensedVersion = [settings licensingLicensedVersion];
	}
	if (_licensedVersion == nil) {
		_licensedVersion = [self declaredProductStringForKey:kFxGripLicensingProperty_LicensedVersion inParameter:parameter pluginValue:self.fxEffect.pluginStringVersion];
	}

	// Watermarks.
	if ([settings respondsToSelector:@selector(licensingWatermarkUnlicensed)]) {
		_watermarkUnlicensed = @([settings licensingWatermarkUnlicensed]);
	} else {
		_watermarkUnlicensed = [self declaredBoolForKey:kFxGripLicensingProperty_WatermarkUnlicensed inParameter:parameter];
	}
	_hasWatermarkUnlicensed = _watermarkUnlicensed != nil;

	if ([settings respondsToSelector:@selector(licensingWatermarkTrial)]) {
		_watermarkTrial = @([settings licensingWatermarkTrial]);
	} else {
		_watermarkTrial = [self declaredBoolForKey:kFxGripLicensingProperty_WatermarkTrial inParameter:parameter];
	}
	_hasWatermarkTrial = _watermarkTrial != nil;

	if ([settings respondsToSelector:@selector(licensingUnlicensedWatermarkConfiguration)]) {
		_unlicensedWatermarkConfiguration = [[settings licensingUnlicensedWatermarkConfiguration] copy];
	} else {
		_unlicensedWatermarkDictionary = [self declaredDictionaryForKey:kFxGripLicensingProperty_UnlicensedWatermark inParameter:parameter];
	}
	if ([settings respondsToSelector:@selector(licensingTrialWatermarkConfiguration)]) {
		_trialWatermarkConfiguration = [[settings licensingTrialWatermarkConfiguration] copy];
	} else {
		_trialWatermarkDictionary = [self declaredDictionaryForKey:kFxGripLicensingProperty_TrialWatermark inParameter:parameter];
	}

	// Buttons and update checking.
	if ([settings respondsToSelector:@selector(licensingShowBuyButton)]) {
		_showBuyButton = @([settings licensingShowBuyButton]);
	} else {
		_showBuyButton = [self declaredBoolForKey:kFxGripLicensingProperty_ShowBuyButton inParameter:parameter];
	}
	_hasShowBuyButton = _showBuyButton != nil;

	if ([settings respondsToSelector:@selector(licensingShowProductButton)]) {
		_showProductButton = @([settings licensingShowProductButton]);
	} else {
		_showProductButton = [self declaredBoolForKey:kFxGripLicensingProperty_ShowProductButton inParameter:parameter];
	}
	_hasShowProductButton = _showProductButton != nil;

	if ([settings respondsToSelector:@selector(licensingAutoChecking)]) {
		_autoChecking = @([settings licensingAutoChecking]);
	} else {
		_autoChecking = [self declaredBoolForKey:kFxGripLicensingProperty_AutoChecking inParameter:parameter];
	}
	_hasAutoChecking = _autoChecking != nil;

	BOOL checksUpdates = [self providerResponds:@selector(checkForUpdatesForProduct:version:force:handler:)];

	if (!_hasActive && !self.hasProduct) {
		parameter = @{
			@"type": kFxParameterType_Toggle,
			@"name": @"Licensing Active",
			@"id": @(_parameterID + kParameterLicensingActiveOffset),
			kFxParameterProperty_ParentId: parentID,
			// HIDDEN: licensing enforcement state, not a user control. Without it the end
			// user could switch off licensing from the inspector.
			@"flags": @[kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[components addObject:parameter];
	}

	if (!self.hasProduct) {
		parameter = @{
			@"type": kFxParameterType_String,
			@"name": @"Product ID",
			@"id": @(_parameterID + kParameterLicensingProductIDOffset),
			kFxParameterProperty_ParentId: parentID,
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA, kParameterFlagString_NO_STATE]
		}.mutableCopy;
		[components addObject:parameter];

		if (checksUpdates) {
			parameter = @{
				@"id": @(_parameterID + kParameterLicensingProductVersionOffset),
				@"name": @"Product Version",
				@"type": kFxParameterType_String,
				kFxParameterProperty_ParentId: parentID,
				@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA, kParameterFlagString_NO_STATE]
			}.mutableCopy;
			[components addObject:parameter];
		}
	}

	if (!_hasWatermarkUnlicensed) {
		parameter = @{
			@"id": @(_parameterID + kParameterLicensingWatermarkUnlicensedOffset),
			@"name": @"Unlicensed Watermark",
			@"type": kFxParameterType_Toggle,
			@"default": @YES,
			kFxParameterProperty_ParentId: parentID,
			// HIDDEN: enforcement state, not a user control. Without it the end user could
			// switch off the unlicensed watermark from the inspector.
			@"flags": @[kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[components addObject:parameter];
	}

	if (!_hasWatermarkTrial) {
		parameter = @{
			@"id": @(_parameterID + kParameterLicensingWatermarkTrialOffset),
			@"name": @"Trial Watermark",
			@"type": kFxParameterType_Toggle,
			kFxParameterProperty_ParentId: parentID,
			@"flags": @[kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[components addObject:parameter];
	}

	if (self.showBuyButton && [self providerResponds:@selector(buyProduct:)]) {
		NSString *name = @"Buy…";
		parameter = @{
			@"type": kFxParameterType_PushButton,
			@"name": name,
			@"id": @(_parameterID + kParameterLicensingBuyButtonOffset),
			kFxParameterProperty_ParentId: parentID,
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[components addObject:parameter];

		parameter = @{
			@"type": kFxParameterType_String,
			@"name": @"Buy Button Label",
			@"id": @(_parameterID + kParameterLicensingBuyButtonLabelOffset),
			@"default": name,
			kFxParameterProperty_ParentId: parentID,
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[components addObject:parameter];
	}

	if (self.showProductButton && [self providerResponds:@selector(showProduct:)]) {
		NSString *name = @"Show Product…";
		parameter = @{
			@"type": kFxParameterType_PushButton,
			@"name": name,
			@"id": @(_parameterID + kParameterLicensingProductButtonOffset),
			kFxParameterProperty_ParentId: parentID,
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[components addObject:parameter];

		parameter = @{
			@"type": kFxParameterType_String,
			@"name": @"Product Button Label",
			@"id": @(_parameterID + kParameterLicensingProductButtonLabelOffset),
			@"default": name,
			kFxParameterProperty_ParentId: parentID,
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[components addObject:parameter];
	}

	if (!_hasAutoChecking && checksUpdates) {
		parameter = @{
			@"type": kFxParameterType_Toggle,
			@"name": @"Update Checking",
			@"id": @(_parameterID + kParameterLicensingAutoCheckingOffset),
			kFxParameterProperty_ParentId: parentID,
			@"default": @YES,
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA, kParameterFlagString_NO_STATE]
		}.mutableCopy;
		[components addObject:parameter];
	}

	_addedLicenseEntryButton = [self providerResponds:@selector(showLicenseEntryForProduct:)];
	if (_addedLicenseEntryButton) {
		parameter = @{
			@"type": kFxParameterType_PushButton,
			@"name": @"Enter License…",
			@"id": @(_parameterID + kParameterLicensingLicenseEntryButtonOffset),
			kFxParameterProperty_ParentId: parentID,
			@"flags": @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[components addObject:parameter];
	}

	_addedDeactivateButton = [self providerResponds:@selector(deactivateLicenseForProduct:completion:)];
	if (_addedDeactivateButton) {
		parameter = @{
			@"type": kFxParameterType_PushButton,
			@"name": @"Deactivate This Machine",
			@"id": @(_parameterID + kParameterLicensingDeactivateButtonOffset),
			kFxParameterProperty_ParentId: parentID,
			// Hidden until the product is licensed; the status sync shows it.
			@"flags": @[kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]
		}.mutableCopy;
		[components addObject:parameter];
	}

	[parameters addObjectsFromArray:components];
}

- (FxParameterType)extParameterTypeForString:(NSString *)typeString
{
	if ([typeString isEqualToString:kFxParameterType_Licensing] || [typeString isEqualToString:kFxParameterType_FxFactory]) {
		return FxParameterType_Licensing;
	}
	return FxParameterType_None;
}

- (Class)extParameterClassForType:(FxParameterType)type
{
	if (type == FxParameterType_Licensing) {
		return self.class;
	}
	return NULL;
}

/*!
	@method		extLoadWithEffect:
	@abstract	Binds the extension and runs the host configuration check when the provider is available.
	@return		YES.
	@discussion	Introduced in FxGrip 0.1.0. When the provider is absent or unavailable the extension
				loads but stays disconnected. The check runs only when the regression extension is
				loaded. */
- (BOOL)extLoadWithEffect:(id<FxGripTileableEffect>)effect
{
	[super extLoadWithEffect:effect];

	if (_provider == nil || !_provider.isAvailable) {
		return YES;
	}

	if ([(FxGripTileableEffect *)effect hasExtensionClass:FxGripRegression.class]) {
		[self hostConfigurationProblems];
	}

	return YES;
}

/*!
	@method		extAddedToDocument:
	@abstract	Runs the update check, starts observing, and syncs the toggle to the status.
	@discussion	Introduced in FxGrip 0.1.0. Returns early when the integration is inactive. In a DEBUG
				build an explicit debug property forces the status and seeds the cache; otherwise
				the toggle and UI sync to the provider's status. */
- (void)extAddedToDocument:(nonnull NSNotification *)notification
{
	// The extension base does not implement extAddedToDocument:; the notification handlers
	// override it without chaining to super, matching FxGripMeta and FxGripParameterData.
	if (!self.licensingActive) {
		return;
	}

	[self checkForUpdates];

	[self startObservingProduct:self.productID];

#if DEBUG
	NSNumber *debugStatus = [self debugStatusOverride];
	if (debugStatus != nil) {
		NSLog(@"⚠️ Debugging licensing status %@ as default. This bypasses the licensing provider in the Xcode Debug target and works normally in the Release target.", debugStatus);
		// The debug override drives the whole licensing decision: seed the cache so
		// licenseStatus (and the watermark, buttons, and toggle that read it) honors the
		// forced status, mirror it into the toggle, and apply the license UI state.
		FxGripLicenseStatus status = debugStatus.integerValue;
		[self setCachedStatus:debugStatus];
		self.boolValue = FxGripLicenseStatusIsLicensed(status);
		[self applyButtonVisibilityForStatus:status];
		[self.fxEffect licensingStatusDidChange:status];
		return;
	}
#endif

	FxGripLicenseStatus status = self.licenseStatus;
	BOOL priorLicensed = self.boolValue;
	BOOL licensed = FxGripLicenseStatusIsLicensed(status);
	if (licensed != priorLicensed) {
		self.boolValue = licensed;
		[self.fxEffect licensingStatusDidChange:status];
	}
	[self applyButtonVisibilityForStatus:status];
}

#if DEBUG
/*! The forced status from the debug plugin properties, or nil when neither is set. */
- (NSNumber *)debugStatusOverride
{
	NSDictionary *properties = self.fxEffect.pluginProperties;
	id status = properties[kPropertiesLicensingDebugSetStatus];
	if ([status isKindOfClass:NSNumber.class]) {
		return status;
	}
	id licensed = properties[kPropertiesLicensingDebugSetLicensed];
	if ([licensed isKindOfClass:NSNumber.class]) {
		return @(((NSNumber *)licensed).boolValue ? FxGripLicenseStatusLicensed : FxGripLicenseStatusUnlicensed);
	}
	return nil;
}
#endif

/*!
	@method		extParameterChanged:
	@abstract	Reacts to changes on the licensing parameters.
	@discussion	Introduced in FxGrip 0.1.0. A change to the licensing toggle is reverted to the true
				status. Toggling the active parameter starts or stops observing. Changing the
				product ID clears the cached status and restarts observing. A button label change
				renames its button. A button press runs its action. Toggling update checking
				applies the state. */
- (void)extParameterChanged:(nonnull NSNotification *)notification
{
	if (!self.licensingActive) {
		return;
	}

	NSNumber *pidNumber = notification.userInfo[FxGripTileableEffectParameterChangedIDKey];
	if (!pidNumber) {
		return;
	}
	FxParameterId paramID = pidNumber.unsignedIntValue;
	if (paramID < self.parameterID || paramID > self.parameterID + kParameterLicensingWatermarkTrialOffset) {
		return;
	}

	switch (paramID - self.parameterID) {
		case 0:
			// If the licensing toggle changes, change it back.
			self.boolValue = self.isLicensed;
			break;
		case kParameterLicensingActiveOffset:
			if (self.effect[paramID].boolValue) {
				[self startObservingProduct:self.productID];
			} else {
				[self stopObserving];
			}
			break;
		case kParameterLicensingProductIDOffset:
			// The cached verdict belongs to the previous product; drop it so licenseStatus
			// recomputes for the new ID instead of reporting the old product's status.
			[self setCachedStatus:nil];
			[self startObservingProduct:self.productID];
			break;
		case kParameterLicensingBuyButtonOffset:
			[self buyProduct];
			break;
		case kParameterLicensingProductButtonOffset:
			[self showProduct];
			break;
		case kParameterLicensingBuyButtonLabelOffset:
		case kParameterLicensingProductButtonLabelOffset:
			// The value becomes the button name.
			self.effect[paramID - 1].parameterName = self.effect[paramID].stringValue;
			break;
		case kParameterLicensingAutoCheckingOffset:
			[self setUpdateChecking:self.effect[paramID].boolValue];
			break;
		case kParameterLicensingLicenseEntryButtonOffset:
			[self showLicenseEntry];
			break;
		case kParameterLicensingDeactivateButtonOffset:
			[self deactivateLicense];
			break;
		default:
			break;
	}
}

/*!
	@method		extRenderDestinationImage:
	@abstract	Renders the watermark for the current status onto the destination image.
	@discussion	Introduced in FxGrip 0.1.0. Returns when the status renders clean. A failed render
				logs and leaves the frame unmarked. */
- (void)extRenderDestinationImage:(nonnull NSNotification *)notification
{
	FxGripWatermarkConfiguration *configuration = [self watermarkConfigurationForStatus:self.licenseStatus];
	if (configuration == nil) {
		return;
	}
	FxImageTile *destinationImage = notification.userInfo[FxGripTileableEffectRenderDestinationImageKey];
	if (destinationImage == nil) {
		return;
	}
	NSError *__autoreleasing renderError = nil;
	if (![self renderWatermark:configuration ontoImage:destinationImage error:&renderError]) {
		// A failed render leaves the frame unmarked; surface it rather than ship clean.
		NSLog(@"Error: licensing watermark render failed: %@", renderError);
	}
}

@end


#pragma mark -

/*!
	@abstract	The effect-side hooks and accessors for the licensing extension.
	@discussion	Introduced in FxGrip 0.1.0. The status and update hooks are empty defaults a subclass
				overrides.
*/
@implementation FxGripTileableEffect (Licensing)

- (void)setLicenseState:(BOOL)licensed
{
	// Set or change parameters or internal state for the license state here. No direct user
	// interaction belongs here, only UI state, such as hiding a Buy button once licensed.
}

- (void)licensingStatusDidChange:(FxGripLicenseStatus)status
{
	[self setLicenseState:FxGripLicenseStatusIsLicensed(status)];
}

- (void)licensingDidReceiveUpdateInfo:(NSDictionary<NSString *, id> *)info
{
}

- (FxGripLicensing *)licensing
{
	return (FxGripLicensing *)[self extensionForClass:FxGripLicensing.class];
}

- (NSString *)licensingProductID
{
	return self.licensing.productID;
}

- (BOOL)isProductLicensed
{
	return self.licensing.isLicensed;
}

- (FxGripLicensing *)newLicensingExtension
{
	NSString *name = [FxGripLicensing providerNameForPluginProperties:self.pluginProperties];
	if (name == nil) {
		return nil;
	}
	Class providerClass = [FxGripLicensing providerClassForName:name];
	if (providerClass == nil) {
		NSLog(@"Error: The licensing provider '%@' is not registered; %@ loads without licensing. Registered providers: %@.", name, self.pluginDisplayName, [FxGripLicensing registeredProviderNames]);
		return nil;
	}
	id<FxGripLicensingProvider> provider = [[providerClass alloc] init];
	return [[FxGripLicensing alloc] initWithProvider:provider];
}

@end
