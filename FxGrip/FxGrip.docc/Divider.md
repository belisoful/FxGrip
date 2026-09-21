# Divider

A horizontal divider line that spans the inspector width and draws no row label.

## Overview

The divider is a structural control that draws a centered horizontal rule. A
plugin declares it with the type string `kFxParameterType_Divider` (`divider`).
The class is ``FxGripDividerParameter`` and its backing view is
``FxGripDividerBox``, an `NSBox` separator centered in a full-width sizing
container. The value is an ``FxGripDividerData`` carrying the line's width
fraction and its top and bottom margins. Creation adds the custom-UI,
not-animatable, full-view-width, and no-state flags.

## Configuration keys

The declared default is a plain dictionary read by
`+[FxGripDividerData dataWithDictionary:]`. The keys are string literals.

| Key | Meaning | Default |
| --- | --- | --- |
| `"width"` | The line width as a fraction of the container width, `0…1`. | The golden-ratio fraction, phi − 1 (about 0.618). |
| `"margintop"` | The space above the line, in view points. | `7`. |
| `"marginbottom"` | The space below the line, in view points. | `12`. |

The line itself draws at `kFxGripBoxDividerHeight` (1 point). The parameter
height is the top margin, the line, and the bottom margin.

## Behavior

An absent key keeps its default. The value bridges to the standard retrieval
API: the float accessor maps to the width fraction, and the int accessor maps to
the total parameter height. Setting the parameter height splits the remaining
space evenly between the top and bottom margins.

## Example

```objc
@{
    kFxParameterProperty_Id:      @(kMyDividerID),
    kFxParameterProperty_Name:    @"",
    kFxParameterProperty_Type:    kFxParameterType_Divider,
    kFxParameterProperty_Default: @{
        @"width":        @0.9,
        @"margintop":    @8,
        @"marginbottom": @8,
    },
}
```

## Topics

### Control

- ``FxGripDividerParameter``
- ``FxGripDividerData``
- ``FxGripDividerBox``

### Related

### Types and metrics

- ``FxGripDividerSize``
- ``kFxGripBoxDividerHeight``
