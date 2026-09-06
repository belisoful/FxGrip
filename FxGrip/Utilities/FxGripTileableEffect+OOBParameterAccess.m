/*!
	@file       FxGripTileableEffect+OOBParameterAccess.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+OOBParameterAccess
	@abstract   Implements the out-of-band parameter access context accessors.
	@discussion Introduced in FxGrip 0.1.0. Each accessor returns an FxGripOOBParameterAccess bound
	            to the effect. The flush variant runs the extension flush when the context
	            deactivates.
*/

#import "FxGripTileableEffect+OOBParameterAccess.h"
#import "FxGripOOBParameterAccess.h"


/*!
	@abstract	The category that starts an out-of-band parameter access context.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@implementation FxGripTileableEffect (OOBParameterAccess)

/*!
	@method		startContext
	@abstract	Opens an out-of-band parameter access context bound to the effect.
	@return		The access context object; parameter access is valid until it is released. */
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
