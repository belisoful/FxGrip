//
//  FxGripI18N.h
//  Automatic Internationalization
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripI18N_h
#define FxGripI18N_h

#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"


@interface FxGripI18N : FxGripExtension
{
	NSDictionary*	localizeDictionary;
	NSDictionary*	reverseLocalizeDictionary;
}

@property (readwrite, assign) BOOL isLocalizingNames;
@property (readwrite, assign) BOOL isLocalizingValues;
@property (readwrite, assign) BOOL isLocalizingMenus;

@property (readwrite, assign) BOOL isDelocalizingNames;
@property (readwrite, assign) BOOL isDelocalizingValues;
@property (readwrite, assign) BOOL isDelocalizingMenus;


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



@interface FxGripTileableEffect (I18N)

@property (readonly, nullable, nonatomic) FxGripI18N* i18n;

- (nonnull FxGripI18N*)newI18NExtension;
- (BOOL)isInternationalized;

@end

#endif
