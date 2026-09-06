/*!
	@file       FxGripTileableEffect+OOBParameterAccess.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+OOBParameterAccess
	@abstract   The category that opens an out-of-band parameter access context.
	@discussion Introduced in FxGrip 0.1.0. FxPlug limits parameter retrieval and setting to
	            certain host callbacks. The category opens an FxGripOOBParameterAccess context so
	            code outside those callbacks reads and writes parameters. The context deactivates
	            when the returned object is released.
*/

#ifndef FxGripTileableEffect_OOBParameterAccess_h
#define FxGripTileableEffect_OOBParameterAccess_h

#import <Foundation/Foundation.h>
#import "FxGripTileableEffect.h"

/*!
	@abstract	The category that starts an out-of-band parameter access context.
	@discussion	Introduced in FxGrip 0.1.0. The context is held for the scope in which parameters
				are accessed and deactivates on release.
*/
@interface FxGripTileableEffect (OOBParameterAccess)

/*!
	@method		startContext
	@abstract	Opens an out-of-band parameter access context.
	@return		The access context object; parameter access is valid until it is released. */
- (nonnull FxGripOOBParameterAccess *)startContext;

/*!
	@method		startContextFlush
	@abstract	Opens an out-of-band parameter access context that flushes the extensions on release.
	@return		The access context object; it calls the extension flush when it deactivates. */
- (nonnull FxGripOOBParameterAccess *)startContextFlush;
@end

#endif /* FxGripOOBParameterAccess */
