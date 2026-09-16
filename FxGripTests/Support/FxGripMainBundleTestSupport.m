/*!
	@file       FxGripMainBundleTestSupport.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripMainBundleTestSupport
	@abstract   Implements the main-bundle Info.plist staging for the registration tests.
	@discussion Introduced in FxGrip 0.1.0. The two NSBundle lookups are replaced once with
	            implementations that consult the staged dictionaries for the main bundle and
	            forward every other call to the original implementation.
*/

#import "FxGripMainBundleTestSupport.h"
#import <objc/runtime.h>

static NSDictionary<NSString *, id> *gStagedInfo = nil;
static NSDictionary<NSString *, id> *gStagedLocalized = nil;
static BOOL gHasStagedLocalized = NO;
static IMP gOriginalObjectForInfoDictionaryKey = NULL;
static IMP gOriginalLocalizedInfoDictionary = NULL;

static id FxGripStagedObjectForInfoDictionaryKey(NSBundle *self, SEL _cmd, NSString *key)
{
	if (self == NSBundle.mainBundle && key != nil) {
		id staged = gStagedInfo[key];
		if (staged != nil) {
			return staged == NSNull.null ? nil : staged;
		}
	}
	return ((id (*)(id, SEL, NSString *))gOriginalObjectForInfoDictionaryKey)(self, _cmd, key);
}

static NSDictionary *FxGripStagedLocalizedInfoDictionary(NSBundle *self, SEL _cmd)
{
	if (self == NSBundle.mainBundle && gHasStagedLocalized) {
		return gStagedLocalized;
	}
	return ((NSDictionary *(*)(id, SEL))gOriginalLocalizedInfoDictionary)(self, _cmd);
}

@implementation FxGripMainBundleTestSupport

+ (void)installInterception
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		Method infoKey = class_getInstanceMethod(NSBundle.class, @selector(objectForInfoDictionaryKey:));
		gOriginalObjectForInfoDictionaryKey =
			method_setImplementation(infoKey, (IMP)FxGripStagedObjectForInfoDictionaryKey);
		Method localized = class_getInstanceMethod(NSBundle.class, @selector(localizedInfoDictionary));
		gOriginalLocalizedInfoDictionary =
			method_setImplementation(localized, (IMP)FxGripStagedLocalizedInfoDictionary);
	});
}

+ (void)stageInfoDictionary:(nullable NSDictionary<NSString *, id> *)values
{
	[self installInterception];
	gStagedInfo = [values copy];
}

+ (void)stageLocalizedInfoDictionary:(nullable NSDictionary<NSString *, id> *)localized
{
	[self installInterception];
	gStagedLocalized = [localized copy];
	gHasStagedLocalized = localized != nil;
}

+ (void)clearStagedValues
{
	gStagedInfo = nil;
	gStagedLocalized = nil;
	gHasStagedLocalized = NO;
}

@end
