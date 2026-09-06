//
//  FxGripRegression.m
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripRegression.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Extensions.h"
#import "NSDictionary+FxGripTileableEffect.h"

#import <BEFoundation/NSString+BExtension.h>

/*!
	@class      FxGripRegression
	@abstract   Validates a plugin's plist properties at load time.
	@discussion Introduced in FxGrip 1.0. A DEBUG-only pass that reports problems; it never
				blocks the plugin from loading. It checks:
				- the plist UUID string parses as a UUID and the effect's resolved pluginUUID
				  is present;
				- the version is an integer Number, warning when it is a digit String and
				  reporting an error for any other value.
*/
@implementation FxGripRegression


- (BOOL)extLoadWithEffect:(id<FxGripTileableEffect>)effect
{
	if(![super extLoadWithEffect:effect]) {
		return NO;
	}

	// Both checks report and continue: the pass never blocks the plugin from loading.
	[self validatePluginUUID:effect];
	[self validatePluginVersion:effect];

	return YES;
}

/*! Reports when either the plist UUID string does not parse or the resolved pluginUUID is
	absent. Returns YES when both are valid. */
- (BOOL)validatePluginUUID:(nonnull id<FxGripTileableEffect>)effect
{
	NSString *uuidString = effect.pluginProperties[kProPlugPlugIn_UuidProperty];
	NSUUID *parsedUUID = [uuidString isKindOfClass:NSString.class] ? [NSUUID.alloc initWithUUIDString:uuidString] : nil;

	NSString *resolvedUUID = effect.pluginUUID;
	BOOL hasResolvedUUID = [resolvedUUID isKindOfClass:NSString.class] && resolvedUUID.length > 0;

	if (parsedUUID && hasResolvedUUID) {
		return YES;
	}

	NSLog(@"🚨 Plugin %@ of class %@ does not have a valid UUID '%@'. A qualified UUID can be generated on the command line with `uuidgen`. Or you can use this new valid UUID: %@",
		  effect.pluginProperties[kProPlugPlugIn_DisplayNameProperty],
		  effect.pluginProperties[kProPlugPlugIn_ClassNameProperty],
		  [uuidString isKindOfClass:NSString.class] ? uuidString : @"(null)",
		  NSUUID.UUID.UUIDString);
	return NO;
}

/*! Reports when the version is not an integer Number. A digit String is accepted with a
	warning; any other value is an error. Returns YES when the version is a usable integer. */
- (BOOL)validatePluginVersion:(nonnull id<FxGripTileableEffect>)effect
{
	id version = effect.pluginProperties[kProPlugPlugIn_VersionProperty];
	if ([version isKindOfClass:NSNumber.class]) {
		return YES;
	}

	if ([version isKindOfClass:NSString.class] && [(NSString *)version isDigits]) {
		NSLog(@"⚠️ Plugin UUID %@ is using a String (value: %@) for the version instead of the preferred integer Number.", effect.pluginUUID, version);
		return YES;
	}

	// A non-digit String or any other type cannot be handled. -description answers on every
	// object, so an array or dictionary version reports instead of crashing.
	NSLog(@"🚨 Plugin UUID %@ is using version '%@' but versioning can only handle an integer for the version.", effect.pluginUUID, [version description]);
	return NO;
}

@end




@implementation FxGripTileableEffect (Regression)

- (FxGripRegression*)regression
{
	return [self extensionForClass:FxGripRegression.class];
}

- (BOOL)isRegression
{
	return self.pluginProperties.pluginRegression;
}


- (nonnull FxGripRegression*)newRegressionExtension
{
	return [FxGripRegression.alloc init];
}

@end
