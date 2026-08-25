//
//  FxGripOOBParameterAccess.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxTileableEffectBase_ProjectProperties_h
#define FxTileableEffectBase_ProjectProperties_h

#import <Foundation/Foundation.h>
#import "FxTileableEffectBase.h"

@interface FxTileableEffectBase (ProjectProperties)

@property (readonly)			NSUInteger	projectDocumentID;
@property (readonly)			BOOL		isProjectMotion;
@property (readonly)			BOOL		isProjectFinalCutPro;
@property (readonly)			float		projectAspectRatio;
@property (readonly, nullable)	NSURL*		projectMediaFolder;

- (NSUInteger)projectDocumentIDWithError:(NSError *_Nullable *_Nullable)error;
- (nullable NSURL *)projectMediaFolderWithError:(NSError *_Nullable *_Nullable)error;
- (float) projectAspectRatioWithError:(NSError *_Nullable *_Nullable)error;

@end

#endif /* ProjectProperties */
