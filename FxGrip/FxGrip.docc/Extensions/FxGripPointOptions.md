# ``FxGrip/FxGripPointOptions``

The parsed design-time options of a point parameter.

## Overview

A point parameter's declaration configures its on-screen control. This value object reads those
keys once, in ``initWithConfiguration:``, and answers typed properties.

Every key is optional. A key that is absent, or that carries the wrong type, takes the documented
default, so a nil configuration yields a fully default control. The `kFxGripPointKey_*` constants
name the keys and the `kFxGripPointDefault*` constants carry the defaults.

The point's value itself stays a host point of an X and a Y. Nothing here changes the stored value.

### Constraining movement

``constraint`` limits the direction the control moves, and ``divider`` draws the guide for an
axis-constrained point. A distance constraint measures from ``distanceFromX`` and ``distanceFromY``,
reaching as far as ``maxDistance``, and ``distanceShiftOneAxis`` locks such a drag to one axis while
Shift is held. An unrecognized constraint or divider reads as the unconstrained case.

<doc:EventModifiers> covers the modifier keys FxGrip's controls share.

### Drawing the control

``controlSize`` of 0.0 leaves the on-screen control at its own size. ``pinDistance`` of 0.0 draws no
pin, which is what ``displayAsPin`` reports.

<doc:OnScreenControls> covers the on-screen control system.

## Topics

### Creating the options

- ``initWithConfiguration:``

### The value range

- ``defaultX``
- ``defaultY``
- ``rangeMinX``
- ``rangeMaxX``
- ``rangeMinY``
- ``rangeMaxY``
- ``coordinateMapping``
- ``compensateFrameMargin``

### The control's appearance

- ``controlSize``
- ``controlColor``
- ``displayAsPin``
- ``pinDistance``
- ``pinAngle``

### The control's label

- ``displayName``
- ``nameOnlyWhenAbove``

### Dragging

- ``mouseSpeed``
- ``mouseSpeedShiftOnly``

### The background image

- ``backgroundImageName``
- ``backgroundImageSize``
- ``backgroundImageX``
- ``backgroundImageY``

### Constraining movement

- ``constraint``
- ``divider``
- ``distanceFromX``
- ``distanceFromY``
- ``maxDistance``
- ``distanceShiftOneAxis``
