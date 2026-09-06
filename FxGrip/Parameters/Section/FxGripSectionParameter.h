/*!
	@file       FxGripSectionParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSectionParameter
	@abstract   The custom parameter that draws a styled section title header.
	@discussion Introduced in FxGrip 0.1.0. FxGripSectionView is the read-only header view, and
	            FxGripSectionParameter is the parameter that hosts it. The value is an
	            FxGripSectionData carrying the title, size, color, and the style and layout keys
	            declared in FxGripSection.h.
*/

#ifndef FxGripSectionParameter_h
#define FxGripSectionParameter_h

#import <AppKit/AppKit.h>
#import "FxGripCustomParameter.h"
#import "FxGripCustomViewDataDelegate.h"

/*!
	@class      FxGripSectionView
	@abstract   The styled title header backing a section parameter.
	@discussion Introduced in FxGrip 0.1.0. A read-only header row that spans the inspector
				width. updateFromCustomData: reads an FxGripSectionData (or a plain
				dictionary of the same shape) and applies the title, letter-case transform,
				alignment, font, weight, width, point size, color, opacity, and the
				margins above and below the text. Opacity is a dedicated 0…1 float multiplied
				into the color's alpha, so the title dims while the color stays at its
				inherited default.
*/
@interface FxGripSectionView : NSView <FxGripCustomViewDataDelegate>

@end

/*!
	@class      FxGripSectionParameter
	@abstract   A styled, full-width section title header in the inspector.
	@discussion Introduced in FxGrip 0.1.0. The value is an FxGripSectionData carrying the
				title (string key), point size (float key), color (RGBA key), and the
				transform, alignment, font name, weight, width, opacity, and margin keys
				declared in FxGripSection.h. When the configuration omits the title, the parameter name
				is used. Creation adds the custom-UI, not-animatable, full-view-width, and
				no-state flags.
*/
@interface FxGripSectionParameter : FxGripCustomParameter

@end

#endif
