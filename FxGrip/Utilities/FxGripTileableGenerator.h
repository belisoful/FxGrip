/*!
	@file       FxGripTileableGenerator.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableGenerator
	@abstract   The base class for FxPlug tileable generators built on FxGrip.
	@discussion Introduced in FxGrip 0.1.0. FxGripTileableGenerator subclasses
	            FxGripTileableEffect and adapts it for generators that produce output
	            without a source image. The class supplies the destination-bounds and
	            source-tile behavior a generator needs, so a generator plugin inherits the
	            full FxGrip parameter, extension, and notification stack.
*/

#ifndef FxGripTileableGenerator_h
#define FxGripTileableGenerator_h

#import <FxGrip/FxGripTileableEffect.h>

/*!
	@class		FxGripTileableGenerator
	@abstract	The FxGrip base class for tileable generator plugins.
	@discussion	Introduced in FxGrip 0.1.0. The class overrides the destination-image-rect
				and source-tile-rect callbacks so the output covers the destination image's
				pixel bounds and no source tile is requested. Subclasses implement the render
				callback to draw the generated image.
*/
@interface FxGripTileableGenerator : FxGripTileableEffect

@end

#endif
