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
 * FxGripRegression Implementation
 *
 * This class validates the plugin plist properties.  It checks:
 *  - That the UUID exists and has a length
 */
@implementation FxGripRegression


- (BOOL)extLoadWithEffect:(id<FxGripTileableEffect>)effect
{
	if(![super extLoadWithEffect:effect]) {
		return NO;
	}
	
	NSString *uuidStr = effect.pluginProperties[kProPlugPlugIn_UuidProperty];
	NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidStr];
	
	if(!uuid) {
		NSLog(@"🚨 Plugin %@ of class %@ does not have a valid UUID '%@'. A qualified UUID can be generated on the command line with `uuidgen`. Or you can use this new valid uuid: %@", effect.pluginProperties[kProPlugPlugIn_DisplayNameProperty], effect.pluginProperties[kProPlugPlugIn_ClassNameProperty], uuidStr ? uuidStr : @"(null)", [NSUUID UUID].UUIDString);
	}
	
	// Check that the version is an integer and not a typical software version with major, minor, and point releases.
	id version = effect.pluginProperties[kProPlugPlugIn_VersionProperty];
	if ([version isKindOfClass:NSString.class]) {
		NSLog(@"⚠️ Plugin UUID %@ is using a String (value: %@) for the version instead of the preferred integer Number.", effect.pluginUUID, version);
	}
	if(![version isKindOfClass:[NSNumber class]] && (![version isKindOfClass:[NSString class]] || ![version isDigits])) {
		NSLog(@"🚨 Plugin UUID %@ is using version '%@' but versioning can only handle an integer for the version.", effect.pluginUUID, [version stringValue]);
	}
	
	return YES;
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
