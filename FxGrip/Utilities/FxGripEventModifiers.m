//
//  FxGripEventModifiers.m
//  FxGrip
//

#import "FxGripEventModifiers.h"

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
