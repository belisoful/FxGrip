# Modifier-Key Conventions

The shared modifier-key convention every draggable FxGrip control reads.

## Overview

``FxGripEventModifiers`` maps the four modifier keys to the actions Final Cut Pro and
macOS use, so an FxGrip control feels native and every control interprets the keys the
same way. Each draggable control reads its modifiers through this class, which defines the
convention once.

| Modifier | Action |
| --- | --- |
| Option | fine (slow) adjustment |
| Shift | constrain to horizontal or vertical |
| Command | delete the point or handle under the cursor |
| Control | contextual menu |

AppKit routes a Control-click through `menuForEvent:`, so a control that vends a
contextual menu receives the Control gesture there.

## AppKit events

A control that handles an `NSEvent` tests the event directly:

```objc
- (void)mouseDragged:(NSEvent *)event
{
    CGFloat step = [FxGripEventModifiers isFineDrag:event] ? 0.1 : 1.0;
    if ([FxGripEventModifiers isConstrain:event]) {
        // lock the drag to the dominant axis
    }
}

- (void)mouseDown:(NSEvent *)event
{
    if ([FxGripEventModifiers isDeleteClick:event]) {
        // remove the point under the cursor
    }
}
```

- `isFineDrag:` → YES for Option.
- `isConstrain:` → YES for Shift.
- `isDeleteClick:` → YES for Command.
- `isContextMenu:` → YES for Control.

## On-screen-control events

FxPlug delivers on-screen-control mouse and key events with an `FxModifierKeys` bitmask
rather than an `NSEvent`, so an on-screen-control part reads its modifiers through the
matching bitmask tests:

- `isFineDragForFxModifiers:`
- `isConstrainForFxModifiers:`
- `isDeleteClickForFxModifiers:`
- `isContextMenuForFxModifiers:`

```objc
- (void)mouseDown:(FxDragInfo *)dragInfo
      modifierKeys:(FxModifierKeys)modifiers
{
    if ([FxGripEventModifiers isDeleteClickForFxModifiers:modifiers]) {
        // delete the handle under the cursor
    }
}
```

## Where the convention applies

The curve editor and the on-screen controls both read their modifiers through this class,
so the same gesture means the same thing across the parameters. See <doc:CustomControls>
for the curve editor's gesture table and <doc:OnScreenControls> for the on-screen-control
parts that share the convention.

## Topics

### Convention

- ``FxGripEventModifiers``

### Related

- <doc:CustomControls>
- <doc:OnScreenControls>
