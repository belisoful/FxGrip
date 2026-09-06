/*!
	@file       FxGripEventModifiers.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripEventModifiers
	@abstract   The house modifier-key convention for FxGrip's draggable parameter controls.
	@discussion Introduced in FxGrip 0.1.0. FxGrip maps Option to fine adjustment, Shift to
	            axis constraint, Command to delete, and Control to the contextual menu, matching
	            Final Cut Pro and macOS. Each draggable control reads its modifiers through this
	            class, so the convention is defined once. The class tests both an AppKit NSEvent
	            and a host on-screen-control event's FxModifierKeys bitmask.
*/

#ifndef FxGripEventModifiers_h
#define FxGripEventModifiers_h

#import <AppKit/AppKit.h>
#import <FxPlug/FxOnScreenControl.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripEventModifiers
	@abstract   The house modifier-key convention for FxGrip's draggable parameter controls.
	@discussion Introduced in FxGrip 0.1.0. It follows Final Cut Pro and macOS so a control feels
				native:

				- Option drag → fine (slow) adjustment.
				- Shift drag → constrain to horizontal or vertical.
				- Command click → delete the point or handle under the cursor.
				- Control click → contextual menu (AppKit routes this through menuForEvent:).

				Every control that drags a point or handle reads its modifiers through this class, so
				the convention is defined once and stays consistent across the parameters.
*/
@interface FxGripEventModifiers : NSObject

/*! YES when the event carries the fine-adjustment modifier (Option). */
+ (BOOL)isFineDrag:(nonnull NSEvent *)event;

/*! YES when the event carries the constrain-to-axis modifier (Shift). */
+ (BOOL)isConstrain:(nonnull NSEvent *)event;

/*! YES when the event carries the delete modifier (Command). */
+ (BOOL)isDeleteClick:(nonnull NSEvent *)event;

/*! YES when the event carries the contextual-menu modifier (Control). */
+ (BOOL)isContextMenu:(nonnull NSEvent *)event;

/*!
	@group      FxOnScreenControl events
	@abstract   The same tests for a host on-screen-control event's FxModifierKeys bitmask.
	@discussion FxPlug delivers OSC mouse and key events with an FxModifierKeys mask rather than an
				NSEvent, so an OSC part reads its modifiers through these.
*/
+ (BOOL)isFineDragForFxModifiers:(FxModifierKeys)modifiers;
+ (BOOL)isConstrainForFxModifiers:(FxModifierKeys)modifiers;
+ (BOOL)isDeleteClickForFxModifiers:(FxModifierKeys)modifiers;
+ (BOOL)isContextMenuForFxModifiers:(FxModifierKeys)modifiers;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripEventModifiers_h */
