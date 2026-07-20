/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  GuruFxTileableEffect+Versioning.h
//		
//
//  Created by ~ ~ on 2/27/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef GuruFxTileableEffect_Versioning_h
#define GuruFxTileableEffect_Versioning_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "GuruFxTileableEffect.h"



@interface GuruFxTileableEffect (Versioning)

@property (readonly) UInt32 version;
@property (readonly) NSString*_Nullable pluginShortVersion;

-(unsigned int) checkVersion:(NSError * _Nullable * _Nullable)error;

-(bool) upgradeFromVersion:(unsigned int)fromVersion currentVersion:(unsigned int)currentVersion error:(NSError * _Nullable * _Nullable)error;

@end

#endif
