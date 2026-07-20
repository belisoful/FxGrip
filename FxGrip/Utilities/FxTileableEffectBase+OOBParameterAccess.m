//
//  FxGripOOBParameterAccess.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxTileableEffectBase+OOBParameterAccess.h"
#import "FxGripOOBParameterAccess.h"


@implementation FxTileableEffectBase (ParameterAccess)

/*
```
FxGripOOBParameterAccess *__attribute__((unused)) accessor = [FxGripOOBParameterAccess access:effect.apiManager];
```
 */
- (FxGripOOBParameterAccess*_Nonnull)startContext
{
	return [FxGripOOBParameterAccess access:self];
}

/*!
 * @method		startContextFlush
 * @description	This calls extensionFlush upon deactivating.
 */
- (FxGripOOBParameterAccess*_Nonnull)startContextFlush
{
	return [FxGripOOBParameterAccess access:self flush:YES];
}

@end
