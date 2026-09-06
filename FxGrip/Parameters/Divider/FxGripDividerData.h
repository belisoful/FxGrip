/*!
	@file       FxGripDividerData.h
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDividerData
	@abstract   The custom parameter value model for a divider: line width and margins.
	@discussion Introduced in FxGrip 0.1.0. The data class stores the divider's width fraction and its
	            top and bottom margins. It conforms to secure coding and copying so the host can
	            persist and duplicate the value. It bridges to the standard parameter retrieval API:
	            the float accessor maps to the width fraction and the int accessor maps to the total
	            parameter height.
*/

#ifndef FxGripDividerData_h
#define FxGripDividerData_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripCustomDataClasses.h"
#import "FxGripMutableParameter.h"
#import "FxGripCustomViewData.h"
#import "FxGripDividerParameter.h"

/*!
	@class      FxGripDividerData
	@abstract	The value model for a divider parameter: line width fraction and margins.
	@discussion	Introduced in FxGrip 0.1.0. The class stores the width fraction and the top and bottom
				margins, and derives the total parameter height from them. It conforms to secure
				coding and copying, and feeds its values to the standard FxParameterRetrievalAPI-v6
				through the float and int accessors.
 */
@interface FxGripDividerData : NSObject <NSSecureCoding, NSCopying, FxGripMutableParameter, FxGripCustomViewData>


	/*! The line width as a fraction of the container width, 0 to 1. */
	@property (nonatomic, assign)  FxGripDividerSize percentWidth;
	/*! The space above the line, in view points. */
	@property (nonatomic, assign)  uint16 marginTop;
	/*! The space below the line, in view points. */
	@property (nonatomic, assign)  uint16 marginBottom;
	/*! The total height: the top margin, the line, and the bottom margin. */
	@property (nonatomic, assign)  uint16 parameterHeight;


/*! Creates a divider data seeded from a width/margintop/marginbottom configuration dictionary. */
+(instancetype)dataWithDictionary:(NSDictionary*)values;
- (instancetype)init;


// Set the width 0..1
- (BOOL)getFloatValue:(double*)floatValue;
- (BOOL)setFloatValue:(double)floatValue;

// sets the total high split between top and bottom
- (BOOL)getIntValue:(int*)intValue;
- (BOOL)setIntValue:(int)intValue;

@end

#endif
