//
//  FxGripExtensionSystem.m
//  FxGrip
//

#import "FxGripExtensionSystem.h"
#import "FxTileableEffectBase+Notifications.h"
#import "FxAPINotifications.h"
#import "FxGripParameterUtility.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGrip_ARC.h"

@implementation FxGripExtensionSystem
{
	id<FxGripEffectHost> _host;
	NSMutableArray<id<FxExtension>> *_extensions;
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

- (NSArray<id<FxExtension>> *)extensions
{
	return [_extensions copy];
}

- (BOOL)loadExtension:(id<FxExtension>)extension
{
	// The extensions bind to an effect; the host stands in for one, as it does for the
	// parameter classes.
	BOOL loaded = [extension extLoadWithEffect:(id)_host];
	if (loaded) {
		[_extensions addObject:extension];
	}
	return loaded;
}

- (nullable id<FxExtension>)extensionForClass:(Class)extensionClass
{
	for (id<FxExtension> extension in _extensions) {
		if ([extension isKindOfClass:extensionClass]) {
			return extension;
		}
	}
	return nil;
}

#pragma mark Lifecycle dispatch

/*! The payloads and names below mirror FxTileableEffectBase's posts, so an extension cannot
	tell the subsystem from the effect base. */

- (void)dispatchInit
{
	[_host.notifier postNotificationName:FxTileableEffectInitName
								  object:_host
								userInfo:@{FxTileableEffectInitAPIManagerKey: _host.apiManager}];
}

- (NSMutableDictionary *)dispatchProperties:(NSDictionary *)properties
{
	NSMutableDictionary *props = [NSMutableDictionary dictionaryWithDictionary:properties ?: @{}];
	NSMutableDictionary *userInfo = @{FxTileableEffectPropertiesKey: props}.mutableCopy;
	[_host.notifier postNotificationName:FxTileableEffectPropertiesName object:_host userInfo:userInfo];
	NSMutableDictionary *result = userInfo.fxEffectProperties;
	return [result isKindOfClass:NSMutableDictionary.class] ? result : props;
}

- (NSMutableArray *)dispatchAddParameters:(NSArray *)parameters
{
	NSMutableArray *mutable = [NSMutableArray arrayWithArray:parameters ?: @[]];
	NSMutableDictionary *userInfo = @{FxTileableEffectParametersKey: mutable}.mutableCopy;
	[_host.notifier postNotificationName:FxTileableEffectAddParametersName
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
	[_host.notifier postNotificationName:FxTileableEffectFinishInitialSetupName
								  object:_host
								userInfo:@{}.mutableCopy];
}

- (void)dispatchAddedToDocument
{
	[_host.notifier postNotificationName:FxTileableEffectAddedToDocumentName object:_host];
}

- (void)dispatchParameterChanged:(UInt32)parameterID atTime:(CMTime)time
{
	NSMutableDictionary *userInfo = @{}.mutableCopy;
	userInfo[FxTileableEffectParameterChangedIDKey] = @(parameterID);
	NSDictionary *timeDict = (__bridge_transfer NSDictionary *)CMTimeCopyAsDictionary(time, kCFAllocatorDefault);
	if (timeDict) {
		userInfo[FxTileableEffectParameterChangedAtTimeKey] = timeDict;
	}
	[_host.notifier postNotificationName:FxTileableEffectParameterChangedName object:_host userInfo:userInfo];
}

- (void)dispatchParameterClicked:(UInt32)parameterID
{
	NSMutableDictionary *userInfo = @{FxTileableEffectParameterClickedIDKey: @(parameterID)}.mutableCopy;
	[_host.notifier postNotificationName:FxTileableEffectParameterClickedName object:_host userInfo:userInfo];
}

- (void)dispatchPluginStateWithCoder:(NSCoder *)coder
{
	NSMutableDictionary *userInfo = @{FxTileableEffectPluginStateCoderKey: coder}.mutableCopy;
	[_host.notifier postNotificationName:FxTileableEffectPluginStateName object:_host userInfo:userInfo];
}

- (nullable NSError *)flush
{
	NSMutableDictionary *userInfo = @{}.mutableCopy;
	[_host.notifier postNotificationName:FxTileableEffectFlushName object:_host userInfo:userInfo];
	NSError *error = userInfo.fxError;
	return [error isKindOfClass:NSError.class] ? error : nil;
}

@end
