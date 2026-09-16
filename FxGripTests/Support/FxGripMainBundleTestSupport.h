/*!
	@file       FxGripMainBundleTestSupport.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripMainBundleTestSupport
	@abstract   Stages Info.plist values on the main bundle for the registration tests.
	@discussion Introduced in FxGrip 0.1.0. The registrars and FxGripPluginInfo read the plugin
	            lists through -[NSBundle objectForInfoDictionaryKey:] and the localized strings
	            through -[NSBundle localizedInfoDictionary] on the main bundle. The test process is
	            not a plugin bundle, so those lookups answer nil. This helper installs a staged
	            dictionary that answers only for the main bundle and only for the staged keys;
	            every other lookup reaches the original implementation.
*/

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class		FxGripMainBundleTestSupport
	@abstract	Stages main-bundle Info.plist and localized-info values for a test.
	@discussion	Introduced in FxGrip 0.1.0. A test stages values in setUp and clears them in
				tearDown. Staging installs the interception once for the process.
*/
@interface FxGripMainBundleTestSupport : NSObject

/*! @abstract Answers the staged value for each key on the main bundle; NSNull stages nil. */
+ (void)stageInfoDictionary:(nullable NSDictionary<NSString *, id> *)values;

/*! @abstract Answers the staged dictionary from -[NSBundle localizedInfoDictionary] on the main bundle. */
+ (void)stageLocalizedInfoDictionary:(nullable NSDictionary<NSString *, id> *)localized;

/*! @abstract Removes every staged value so the original lookups answer again. */
+ (void)clearStagedValues;

@end

NS_ASSUME_NONNULL_END
