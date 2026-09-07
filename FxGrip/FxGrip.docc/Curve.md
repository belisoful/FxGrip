# Curve Editor

Edit a tone or remap curve, or a filter's full set of curves, on an FCP-style
grid with draggable control points.

## Overview

The curve editor draws and edits a curve on a strip with draggable control
points. ``FxGripCurveEditorView`` edits one ``FxGripCurveData``.
``FxGripCurveSetEditorView`` stacks a labeled strip per mapping and edits one
``FxGripCurveSetData``. A filter's parameter class builds the composite and
returns it from `createViewForParameterID:`, so one custom parameter carries the
filter's whole curve set. See <doc:CustomControls> for how a custom parameter
vends its view and for the shared gesture conventions.

The editor evaluates a curve with the same Fritsch-Carlson monotone cubic
builders the Metal Forge render uses (``FxGripCurveData/buildLUT:count:`` and the
`FxGripCurveLUT.h` C functions), so the drawn curve equals the applied curve.

## The curve value

``FxGripCurveData`` is one immutable cubic curve: a sorted list of control points
with a domain and a role. Points are sanitized at creation. The y coordinate
clamps to `[0, 1]`. The x coordinate clamps to `[0, 1]` in the linear domain and
folds into `[0, 1)` in the circular domain. Points sort by ascending x, and a
duplicate x drops (first wins). Editing replaces the value; there is no mutable
variant.

```objc
CGPoint points[] = { {0.0, 0.0}, {0.3, 0.12}, {0.7, 0.88}, {1.0, 1.0} };
FxGripCurveData *curve = [FxGripCurveData curveWithPoints:points
                                                   count:4
                                                    role:FxGripCurveRoleRemap
                                                  domain:FxGripCurveDomainLinear];
```

``FxGripCurveData/identityCurveWithRole:domain:`` returns the role's neutral
curve. ``FxGripCurveData/isIdentity`` reports whether the points equal that
neutral shape. ``FxGripCurveData/copyCurvePointsFloat2:capacity:`` writes the
points as `(x, y)` float pairs whose layout matches `simd_float2`, so the buffer
passes straight to a Metal Forge curve input.

### Role

The role fixes the curve's neutral shape:

- `FxGripCurveRoleRemap` → neutral on the diagonal.
- `FxGripCurveRoleShift` → neutral flat at 0.5.
- `FxGripCurveRoleMultiplierHalf` → neutral flat at 0.5, with the shader applying 2x.
- `FxGripCurveRoleMultiplierOne` → neutral flat at 1.0.

### Domain

The domain sets the x-axis evaluation:

- `FxGripCurveDomainLinear` → x clamps and the end values hold outside the point range.
- `FxGripCurveDomainCircular` → x evaluates on a period-1 circle, so the seam at x = 0/1 is continuous. This is the hue selector's domain.

## The curve set

``FxGripCurveSetData`` maps each channel name to an ``FxGripCurveData``. Keys are
the filter family's channel names (`luma`, `red`, `hueVsHue`, `satVsLuma`,
`alphaVsAlpha`). An absent key stands for that mapping's neutral curve, so only
edited curves are stored and the document stays small.
``FxGripCurveSetData/setCurve:forKey:`` stores a curve, and a nil or identity
curve removes the key.

```objc
FxGripCurveSetData *set = [FxGripCurveSetData new];
[set setCurve:curve forKey:@"luma"];
```

``FxGripCurveSetData`` subclasses ``FxGripInterpolatingDictionary``, so the host
keyframes it. Two curves with matching point count, role, and domain interpolate
pairwise. Any mismatch blends the two evaluated curves on a 33-sample grid, so a
point added mid-animation cannot drop the curve. See
<doc:CustomParameterData> for the interpolating value model.

## Building the composite

The parameter class declares each mapping in FCP strip order with
``FxGripCurveSetEditorView/addEditorForKey:title:role:domain:background:``. Each
call appends one labeled strip and returns it for further styling.

```objc
FxGripCurveSetEditorView *view = [FxGripCurveSetEditorView new];
FxGripCurveEditorView *luma = [view addEditorForKey:@"luma"
                                              title:@"Luma"
                                               role:FxGripCurveRoleRemap
                                             domain:FxGripCurveDomainLinear
                                         background:FxGripCurveBackgroundLumaRamp];
luma.lineColor = NSColor.whiteColor;
```

A strip's continuous edits update the working `curveSet`. Its commit writes the
set to the host through an out-of-band access context, so the host records the
gesture for undo. A committed identity curve removes the mapping's key.

## Backgrounds, line, and readout

### Background and grid

The `background` styles the strip behind the curve: a grid, the hue spectrum, a
luma, saturation, red, green, or blue ramp, or an alpha checker. `gridDivisions`
sets the alignment grid density to quarters, eighths (the default), or
sixteenths, with the finer lines dimmed by tier.

```objc
editor.background     = FxGripCurveBackgroundRedRamp;
editor.gridDivisions  = FxGripCurveGridDivisionsEighths;
```

### Line color and style

`lineColor` sets a solid stroke and defaults to white; setting nil restores
white. `lineStyle` chooses `FxGripCurveLineStyleSolid` or
`FxGripCurveLineStyleHue`, which strokes the line itself as the hue spectrum
along x. `lineWidth` sets the stroke width in view points, defaulting to
`kFxGripCurveLineWidthDefault` (1.0) and clamping to `[0.1, 8.0]`.

```objc
editor.lineStyle = FxGripCurveLineStyleHue;
editor.lineWidth = 1.5;
```

### Vertical gradient stops

`topPaint`, `centerPaint`, and `bottomPaint` build a vertical gradient over the
`background`. Each ``FxGripCurvePaint`` is a fixed color
(``FxGripCurvePaint/paintWithColor:``), the hue spectrum
(``FxGripCurvePaint/huePaint``), or none (``FxGripCurvePaint/nonePaint``), which
is transparent and fades to the strip base. A nil center makes a two-stop
top-to-bottom gradient. A nil top or bottom drops that end. All three nil falls
back to `background`.

```objc
editor.topPaint    = [FxGripCurvePaint paintWithColor:NSColor.blackColor];
editor.centerPaint = [FxGripCurvePaint huePaint];
editor.bottomPaint = [FxGripCurvePaint paintWithColor:NSColor.whiteColor];
```

### Point readout

`pointReadoutStyle` shows a point's exact value: `FloatingChip` beside the point,
`Axis` on crosshair guides at each edge, `Corner` in a fixed corner, or
`SystemTooltip`. `pointReadoutUnits` chooses `Normalized`, `EightBit`, `Percent`,
or `DomainAware`, which reads x as degrees for a circular domain and as 0–255
otherwise. `pointReadoutTrigger` shows the readout for the active point, or also
on hover, or on Command-hover.

```objc
editor.pointReadoutStyle   = FxGripCurveReadoutStyleFloatingChip;
editor.pointReadoutUnits   = FxGripCurveReadoutUnitsEightBit;
editor.pointReadoutTrigger = FxGripCurveReadoutTriggerActiveAndModifierHover;
```

## Interaction

The editor follows Final Cut Pro and macOS conventions through the shared
``FxGripEventModifiers`` keys. A click on the curve adds a point. A drag moves
it: a linear domain pins the first and last point in x, and a circular domain
wraps x. Option slows the drag to `slowDragScale` of mouse travel for fine
positioning; `slowDragScale` defaults to `kFxGripCurveSlowDragScaleDefault` (0.1)
and clamps to `[0.01, 1.0]`. Command-click, the Delete key, dragging far outside
the strip, and the context menu's Delete Point item remove a point; a linear
curve's pinned endpoints never delete. A double-click resets to the role's
identity, as does ``FxGripCurveEditorView/resetCurve``. The full gesture table is
in <doc:CustomControls>.

The ``FxGripCurveEditorDelegate`` reports edits: `didEditCurve:` fires
continuously during a drag, and `didCommitCurve:` fires on mouse-up and keyboard
edits, the boundary the out-of-band write and the host's undo entry coalesce to.

## Topics

### Editors

- ``FxGripCurveEditorView``
- ``FxGripCurveSetEditorView``
- ``FxGripCurveEditorDelegate``

### Values

- ``FxGripCurveData``
- ``FxGripCurveSetData``
- ``FxGripCurvePaint``

### Related

- <doc:CustomParameterData>
