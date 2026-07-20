//
//  FxGripOOBParameterAccess.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxTileableEffectBase_OOBParameterAccess_h
#define FxTileableEffectBase_OOBParameterAccess_h

#import <Foundation/Foundation.h>
#import "FxTileableEffectBase.h"

@interface FxTileableEffectBase (OOBParameterAccess)

/*
```
FxGripOOBParameterAccess *__attribute__((unused)) accessor = [FxGripOOBParameterAccess access:effect.apiManager];
```
 */
- (nonnull FxGripOOBParameterAccess *)startContext;
- (nonnull FxGripOOBParameterAccess *)startContextFlush;
@end

#endif /* FxGripOOBParameterAccess */
