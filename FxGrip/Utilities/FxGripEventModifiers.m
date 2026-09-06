/*!
	@file       FxGripEventModifiers.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripEventModifiers
	@abstract   Implements the modifier-key tests over NSEvent and FxModifierKeys masks.
	@discussion Introduced in FxGrip 0.1.0. Each test reads a single modifier bit. The NSEvent
	            variants read modifierFlags, and the FxModifierKeys variants read the host mask.
*/

#import "FxGripEventModifiers.h"

/*!
	@abstract	The modifier-key convention for draggable parameter controls.
	@discussion	Introduced in FxGrip 0.1.0. Option is fine drag, Shift constrains, Command
				deletes, and Control opens the contextual menu.
*/
@implementation FxGripEventModifiers

+ (BOOL)isFineDrag:(nonnull NSEvent *)event
{
	return (event.modifierFlags & NSEventModifierFlagOption) != 0;
}

+ (BOOL)isConstrain:(nonnull NSEvent *)event
{
	return (event.modifierFlags & NSEventModifierFlagShift) != 0;
}

+ (BOOL)isDeleteClick:(nonnull NSEvent *)event
{
	return (event.modifierFlags & NSEventModifierFlagCommand) != 0;
}

+ (BOOL)isContextMenu:(nonnull NSEvent *)event
{
	return (event.modifierFlags & NSEventModifierFlagControl) != 0;
}

+ (BOOL)isFineDragForFxModifiers:(FxModifierKeys)modifiers
{
	return (modifiers & kFxModifierKey_OPTION) != 0;
}

+ (BOOL)isConstrainForFxModifiers:(FxModifierKeys)modifiers
{
	return (modifiers & kFxModifierKey_SHIFT) != 0;
}

+ (BOOL)isDeleteClickForFxModifiers:(FxModifierKeys)modifiers
{
	return (modifiers & kFxModifierKey_COMMAND) != 0;
}

+ (BOOL)isContextMenuForFxModifiers:(FxModifierKeys)modifiers
{
	return (modifiers & kFxModifierKey_CONTROL) != 0;
}

@end
