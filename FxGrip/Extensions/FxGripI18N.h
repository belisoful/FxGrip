/*!
	@file       FxGripI18N.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripI18N
	@abstract   The extension that localizes parameter text on the way in and delocalizes it on the way out.
	@discussion Introduced in FxGrip 0.1.0. The extension maps a parameter's name, string value, and
	            menu items through the plugin bundle's Localizable.strings as they pass through the
	            parameter API. A write localizes; a read delocalizes back to the original key, so a
	            round-trip closes. The forward table is the plugin's own bundle, not the host's main
	            bundle. Each direction has an independent switch for names, values, and menus.
*/

#ifndef FxGripI18N_h
#define FxGripI18N_h

#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"

/*!
	@class		FxGripI18N
	@abstract	The internationalization extension for effect parameter text.
	@discussion	Introduced in FxGrip 0.1.0. The extension caches the forward and reverse tables and
				applies them in the parameter API notification handlers.
*/
@interface FxGripI18N : FxGripExtension
{
	NSDictionary*	localizeDictionary;
	NSDictionary*	reverseLocalizeDictionary;
}

/*! Whether parameter names are localized on writes. */
@property (readwrite, assign) BOOL isLocalizingNames;
/*! Whether string parameter values are localized on writes. */
@property (readwrite, assign) BOOL isLocalizingValues;
/*! Whether menu items are localized on writes. */
@property (readwrite, assign) BOOL isLocalizingMenus;

/*! Whether parameter names are delocalized on reads. */
@property (readwrite, assign) BOOL isDelocalizingNames;
/*! Whether string parameter values are delocalized on reads. */
@property (readwrite, assign) BOOL isDelocalizingValues;
/*! Whether menu items are delocalized on reads. */
@property (readwrite, assign) BOOL isDelocalizingMenus;


/*! Reads a parameter's name through the dynamic API and delocalizes it when enabled. */
//This gets the name of a parameter but delocalizes it.
- (void)parameter:(FxParameterId)parameterID name:(NSString*_Nonnull*_Nonnull)parameterName;

/*! Maps a key to its localized string via localizationTable, returning the key unchanged
	when the table has no entry. */
- (nonnull NSString*)localize:(nonnull NSString*)key;

/*! Maps a localized string back to its key by inverting localizationTable. */
- (nullable NSString*)delocalize:(nullable NSString*)string;

/*! The bundle whose Localizable.strings drives localization. Defaults to the plugin's own
	bundle (the bundle of the effect's class), not the host application's main bundle, which
	is what NSLocalizedString would read inside an out-of-process FxPlug plugin. Overridable
	for testing. */
- (nonnull NSBundle*)localizationBundle;

/*! The forward key→localized table, loaded from localizationBundle's Localizable.strings.
	Overridable so a test can supply a fixture table and exercise the round-trip. */
- (nonnull NSDictionary<NSString*, NSString*>*)localizationTable;

@end



/*!
	@abstract	The effect-side accessors for the internationalization extension.
	@discussion	Introduced in FxGrip 0.1.0. isInternationalized reads the plugin property that gates
				the extension.
*/
@interface FxGripTileableEffect (I18N)

/*! The installed internationalization extension, or nil when none is installed. */
@property (readonly, nullable, nonatomic) FxGripI18N* i18n;

/*! Creates the internationalization extension instance for the loader to install. */
- (nonnull FxGripI18N*)newI18NExtension;
/*! YES when the plugin opts into internationalization via its plugin property. */
- (BOOL)isInternationalized;

@end

#endif
