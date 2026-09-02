//
//  FxGripOOBParameterAccess.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripTileableEffect_OOBParameterAccess_h
#define FxGripTileableEffect_OOBParameterAccess_h

#import <Foundation/Foundation.h>
#import "FxGripTileableEffect.h"

@interface FxGripTileableEffect (OOBParameterAccess)

/*
```
FxGripOOBParameterAccess *__attribute__((unused)) accessor = [FxGripOOBParameterAccess access:effect.apiManager];
```
 */
- (nonnull FxGripOOBParameterAccess *)startContext;
- (nonnull FxGripOOBParameterAccess *)startContextFlush;
@end

#endif /* FxGripOOBParameterAccess */
