//
//  FxGripExtensionSystem.m
//  FxGrip
//

#import "FxGripExtensionSystem.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripAPINotifications.h"
#import "FxGripParameterUtility.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGrip_ARC.h"

@implementation FxGripExtensionSystem
{
	id<FxGripEffectHost> _host;
	NSMutableArray<id<FxGripExtension>> *_extensions;
}

- (instancetype)initWithHost:(id<FxGripEffectHost>)host
{
	self = [super init];
	if (self != nil) {
		_host = host;
		_extensions = NARC_RETAIN([NSMutableArray array]);
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_extensions);
	SUPER_DEALLOC();
}

- (id<FxGripEffectHost>)host
{
	return _host;
}

- (NSArray<id<FxGripExtension>> *)extensions
{
	return [_extensions copy];
}

- (BOOL)loadExtension:(id<FxGripExtension>)extension
{
	// The extensions bind to an effect; the host stands in for one, as it does for the
	// parameter classes.
	BOOL loaded = [extension extLoadWithEffect:(id)_host];
	if (loaded) {
		[_extensions addObject:extension];
	}
	return loaded;
}

- (nullable id<FxGripExtension>)extensionForClass:(Class)extensionClass
{
	for (id<FxGripExtension> extension in _extensions) {
		if ([extension isKindOfClass:extensionClass]) {
			return extension;
		}
	}
	return nil;
}

#pragma mark Lifecycle dispatch

/*! The payloads and names below mirror FxGripTileableEffect's posts, so an extension cannot
	tell the subsystem from the effect base. */

- (void)dispatchInit
{
	[_host.notifier postNotificationName:FxGripTileableEffectInitName
								  object:_host
								userInfo:@{FxGripTileableEffectInitAPIManagerKey: _host.apiManager}];
}

- (NSMutableDictionary *)dispatchProperties:(NSDictionary *)properties
{
	NSMutableDictionary *props = [NSMutableDictionary dictionaryWithDictionary:properties ?: @{}];
	NSMutableDictionary *userInfo = @{FxGripTileableEffectPropertiesKey: props}.mutableCopy;
	[_host.notifier postNotificationName:FxGripTileableEffectPropertiesName object:_host userInfo:userInfo];
	NSMutableDictionary *result = userInfo.fxEffectProperties;
	return [result isKindOfClass:NSMutableDictionary.class] ? result : props;
}

- (NSMutableArray *)dispatchAddParameters:(NSArray *)parameters
{
	NSMutableArray *mutable = [NSMutableArray arrayWithArray:parameters ?: @[]];
	NSMutableDictionary *userInfo = @{FxGripTileableEffectParametersKey: mutable}.mutableCopy;
	[_host.notifier postNotificationName:FxGripTileableEffectAddParametersName
								  object:_host
								userInfo:userInfo
							   postBlock:^(NSNotification * _Nonnull notification) {
		[FxGripParameterUtility flattenDictionaryParameters:notification.userInfo.fxEffectParameters];
	}];
	NSMutableArray *result = userInfo.fxEffectParameters;
	return [result isKindOfClass:NSMutableArray.class] ? result : mutable;
}

- (void)dispatchFinishInitialSetup
{
	[_host.notifier postNotificationName:FxGripTileableEffectFinishInitialSetupName
								  object:_host
								userInfo:@{}.mutableCopy];
}

- (void)dispatchAddedToDocument
{
	[_host.notifier postNotificationName:FxGripTileableEffectAddedToDocumentName object:_host];
}

- (void)dispatchParameterChanged:(UInt32)parameterID atTime:(CMTime)time
{
	NSMutableDictionary *userInfo = @{}.mutableCopy;
	userInfo[FxGripTileableEffectParameterChangedIDKey] = @(parameterID);
	NSDictionary *timeDict = (__bridge_transfer NSDictionary *)CMTimeCopyAsDictionary(time, kCFAllocatorDefault);
	if (timeDict) {
		userInfo[FxGripTileableEffectParameterChangedAtTimeKey] = timeDict;
	}
	[_host.notifier postNotificationName:FxGripTileableEffectParameterChangedName object:_host userInfo:userInfo];
}

- (void)dispatchParameterClicked:(UInt32)parameterID
{
	NSMutableDictionary *userInfo = @{FxGripTileableEffectParameterClickedIDKey: @(parameterID)}.mutableCopy;
	[_host.notifier postNotificationName:FxGripTileableEffectParameterClickedName object:_host userInfo:userInfo];
}

- (void)dispatchPluginStateWithCoder:(NSCoder *)coder
{
	NSMutableDictionary *userInfo = @{FxGripTileableEffectPluginStateCoderKey: coder}.mutableCopy;
	[_host.notifier postNotificationName:FxGripTileableEffectPluginStateName object:_host userInfo:userInfo];
}

- (nullable NSError *)flush
{
	NSMutableDictionary *userInfo = @{}.mutableCopy;
	[_host.notifier postNotificationName:FxGripTileableEffectFlushName object:_host userInfo:userInfo];
	NSError *error = userInfo.fxError;
	return [error isKindOfClass:NSError.class] ? error : nil;
}

@end
