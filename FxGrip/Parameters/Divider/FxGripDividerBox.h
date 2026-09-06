/*!
	@file       FxGripDividerBox.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDividerBox
	@abstract   The NSBox separator view that draws a divider parameter's line.
	@discussion Introduced in FxGrip 0.1.0. The box is an NSBoxSeparator centered within a sizing
	            container. Its width fraction and top and bottom margins come from the parameter
	            value through updateFromCustomData:. The container view, topView, gives the divider
	            its full-width slot in the inspector.
*/

#ifndef FxGripDividerBox_h
#define FxGripDividerBox_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FxGripCustomViewDataDelegate.h"
#import "FxGripDividerParameter.h"

/*!
	@class		FxGripDividerBox
	@abstract	The separator box backing a divider parameter, centered in a sizing container.
	@discussion	Introduced in FxGrip 0.1.0. The box draws a horizontal line whose width is a fraction
				of the inspector width. The top and bottom margins set the parameter height. It reads
				its geometry from an FxGripDividerData value through updateFromCustomData:.
*/
@interface FxGripDividerBox : NSBox <FxGripCustomViewDataDelegate>

/*! The full-width container that holds the centered separator box. */
@property (nonatomic, strong) NSView *topView;

/*! The line width as a fraction of the container width, 0 to 1. */
@property (nonatomic, assign) FxGripDividerSize percentWidth;

/*! The space above the line, in view points. */
@property (nonatomic, assign) uint16 marginTop;

/*! The space below the line, in view points. */
@property (nonatomic, assign) uint16 marginBottom;

/*! The total parameter height: the top margin, the line, and the bottom margin. */
@property (nonatomic, assign) uint16 parameterHeight;

@end

#endif
