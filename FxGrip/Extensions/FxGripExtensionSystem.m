/*!
	@file       FxGripExtensionSystem.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripExtensionSystem
	@abstract   Implements the standalone extension dispatcher over an effect host.
	@discussion Introduced in FxGrip 0.1.0. The dispatch methods post the lifecycle notifications an
	            FxGripTileableEffect posts, with the same names and payloads, so a loaded extension
	            cannot tell the system from the effect base.
*/

#import "FxGripExtensionSystem.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripAPINotifications.h"
#import "FxGripParameterUtility.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGrip_ARC.h"

/*!
	@abstract	Runs FxGrip extensions inside a plug-in that does not use the effect base.
	@discussion	Introduced in FxGrip 0.1.0. The system loads extensions against a host and forwards
				each FxPlug lifecycle call to the matching dispatch method.
*/
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

/*!
	@method		loadExtension:
	@abstract	Loads an extension against the host and records it when it loads.
	@return		The extension's own load result. */
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

/*!
	@method		dispatchProperties:
	@abstract	Runs the extensions over the plug-in's properties dictionary.
	@return		The properties the extensions leave, or the input copy when none replaces it. */
- (NSMutableDictionary *)dispatchProperties:(NSDictionary *)properties
{
	NSMutableDictionary *props = [NSMutableDictionary dictionaryWithDictionary:properties ?: @{}];
	NSMutableDictionary *userInfo = @{FxGripTileableEffectPropertiesKey: props}.mutableCopy;
	[_host.notifier postNotificationName:FxGripTileableEffectPropertiesName object:_host userInfo:userInfo];
	NSMutableDictionary *result = userInfo.fxEffectProperties;
	return [result isKindOfClass:NSMutableDictionary.class] ? result : props;
}

/*!
	@method		dispatchAddParameters:
	@abstract	Runs the extensions over the plug-in's parameter dictionaries.
	@return		The parameter array the extensions leave, flattened, or the input copy when none
				replaces it. */
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

/*!
	@method		flush
	@abstract	Posts the flush notification so extensions write their state to the host.
	@return		The error an extension leaves, or nil on success. */
- (nullable NSError *)flush
{
	NSMutableDictionary *userInfo = @{}.mutableCopy;
	[_host.notifier postNotificationName:FxGripTileableEffectFlushName object:_host userInfo:userInfo];
	NSError *error = userInfo.fxError;
	return [error isKindOfClass:NSError.class] ? error : nil;
}

@end
