/*!
	@file       FxGripSection.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSection
	@abstract   The configuration keys, defaults, and title-case transform of a section parameter.
	@discussion Introduced in FxGrip 0.1.0. FxGripSectionTransform names the letter-case transform
	            applied to a section title. The kFxGripSectionKey_* constants name the entries a
	            section reads from its value: the title, size, and color reuse the standard
	            custom-value keys, and the transform, alignment, font, weight, width, margins,
	            and opacity carry dedicated keys. The kFxGripSectionDefault* constants are the
	            layout defaults in view points.
*/

#ifndef FxGripSection_h
#define FxGripSection_h

#import <Foundation/Foundation.h>
#import "FxGripDictionary.h"

/*!
	@enum       FxGripSectionTransform
	@abstract   The letter-case transform applied to a section title before it is drawn.
	@constant   FxGripSectionTransformNone       The title text is drawn as declared.
	@constant   FxGripSectionTransformUppercase  The title text is uppercased.
	@constant   FxGripSectionTransformLowercase  The title text is lowercased.
	@constant   FxGripSectionTransformCapitalize The title text is title-cased.
*/
typedef NS_ENUM(NSInteger, FxGripSectionTransform) {
	FxGripSectionTransformNone			= 0,
	FxGripSectionTransformUppercase		= 1,
	FxGripSectionTransformLowercase		= 2,
	FxGripSectionTransformCapitalize	= 3,
};

// The section title reuses the string value; its point size reuses the float value; its
// color reuses the RGBA value. The remaining options carry dedicated keys.
#define kFxGripSectionKey_Title			kCustomAPI_StringKey
#define kFxGripSectionKey_Size			kCustomAPI_FloatKey
#define kFxGripSectionKey_Color			kCustomAPI_RGBAKey
#define kFxGripSectionKey_Transform		@"transform"
#define kFxGripSectionKey_Alignment		@"alignment"
#define kFxGripSectionKey_FontName		@"fontName"
#define kFxGripSectionKey_Weight		@"weight"
#define kFxGripSectionKey_Width			@"width"
#define kFxGripSectionKey_MarginTop		@"marginTop"
#define kFxGripSectionKey_MarginBottom	@"marginBottom"

// Opacity is a dedicated 0…1 float multiplied into the resolved color's alpha, so the
// title can be dimmed while the color stays at its inherited default (Color set to none).
#define kFxGripSectionKey_Opacity		@"opacity"

// Layout defaults, in view points, matching the FCP section-header look.
#define kFxGripSectionDefaultSize		(12.0)
#define kFxGripSectionDefaultMarginTop	(3)
#define kFxGripSectionDefaultMarginBot	(0)
#define kFxGripSectionDefaultOpacity	(1.0)

#endif
