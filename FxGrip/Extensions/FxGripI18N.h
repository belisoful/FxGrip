//
//  FxGripI18N.h
//  Automatic Internationalization
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripI18N_h
#define FxGripI18N_h

#import "FxExtension.h"
#import "FxTileableEffectBase.h"


@interface FxGripI18N : FxExtension
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

- (nullable NSString*)delocalize:(nullable NSString*)string;

@end



@interface FxTileableEffectBase (I18N)

@property (readonly, nullable, nonatomic) FxGripI18N* i18n;

- (nonnull FxGripI18N*)newI18NExtension;
- (BOOL)isInternationalized;

@end

#endif
