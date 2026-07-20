//
//  FxTileableEffectBase+Versioning.h
//		
//
//  Created by ~ ~ on 2/27/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxTileableEffectBase_Versioning_h
#define FxTileableEffectBase_Versioning_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxTileableEffectBase.h>



@interface FxTileableEffectBase (Versioning)

@property (readonly)			UInt32		pluginVersion;
@property (readonly, nullable)	NSString*	pluginStringVersion;
@property (readonly)			UInt32		installedVersion;

- (BOOL)checkVersion:(NSError * _Nullable * _Nullable)error;

- (BOOL)upgradeFromVersion:(unsigned int)fromVersion currentVersion:(unsigned int)currentVersion error:(NSError * _Nullable * _Nullable)error;

@end

#endif
