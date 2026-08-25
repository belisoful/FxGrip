//
//  FxGripSection.h
//  FxGrip
//

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

// Layout defaults, in view points, matching the FCP section-header look.
#define kFxGripSectionDefaultSize		(12.0)
#define kFxGripSectionDefaultMarginTop	(3)
#define kFxGripSectionDefaultMarginBot	(0)

#endif
