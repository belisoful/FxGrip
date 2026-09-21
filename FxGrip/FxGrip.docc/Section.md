# Section

A styled, full-width section title header in the inspector.

## Overview

The section is a structural control that draws a styled title spanning the
inspector width and no row label. A plugin declares it with the type string
`kFxParameterType_Section` (`section`). The class is ``FxGripSectionParameter``
and its backing view is ``FxGripSectionView``. The value is an
``FxGripSectionData`` carrying the title, size, color, and the style and layout
keys declared in `FxGripSection.h`. Creation adds the custom-UI, not-animatable,
full-view-width, and no-state flags.

## Value keys

| Key macro | Meaning | Default |
| --- | --- | --- |
| `kFxGripSectionKey_Title` (`kCustomAPI_StringKey`) | The title text. | The parameter name. |
| `kFxGripSectionKey_Size` (`kCustomAPI_FloatKey`) | The point size. | `12.0` (`kFxGripSectionDefaultSize`). |
| `kFxGripSectionKey_Color` (`kCustomAPI_RGBAKey`) | The title color, as an RGBA array. | The inherited label color. |
| `kFxGripSectionKey_Transform` (`"transform"`) | The letter-case transform, an `FxGripSectionTransform`. | `FxGripSectionTransformNone`. |
| `kFxGripSectionKey_Alignment` (`"alignment"`) | The text alignment, an `NSTextAlignment`. | `NSTextAlignmentLeft`. |
| `kFxGripSectionKey_FontName` (`"fontName"`) | The font family name. | The system font. |
| `kFxGripSectionKey_Weight` (`"weight"`) | The font weight trait, scaled by 1000. | Bold system font. |
| `kFxGripSectionKey_Width` (`"width"`) | The font width trait, scaled by 1000. | The font's default width. |
| `kFxGripSectionKey_MarginTop` (`"marginTop"`) | The space above the text, in points. | `3` (`kFxGripSectionDefaultMarginTop`). |
| `kFxGripSectionKey_MarginBottom` (`"marginBottom"`) | The space below the text, in points. | `0` (`kFxGripSectionDefaultMarginBot`). |
| `kFxGripSectionKey_Opacity` (`"opacity"`) | A `0…1` alpha multiplier applied to the color. | `1.0` (`kFxGripSectionDefaultOpacity`). |

## Letter-case transform

`FxGripSectionTransform` selects the case applied to the title before it draws.

| Case | Result |
| --- | --- |
| `FxGripSectionTransformNone` | The title draws as declared. |
| `FxGripSectionTransformUppercase` | The title is uppercased. |
| `FxGripSectionTransformLowercase` | The title is lowercased. |
| `FxGripSectionTransformCapitalize` | The title is title-cased. |

## Behavior

- Title omitted → the header uses the parameter name.
- Font name resolves → the header uses that font; otherwise the system font at the declared weight.
- Weight and width arrive as trait values scaled by 1000, so they survive the integer keys. `NSFontWeight` and `NSFontWidthTrait` span `-1.0…1.0`.
- Color declared → opacity multiplies its alpha.
- Color omitted, opacity declared → the inherited label color dims to the requested opacity.

The header spans the inspector width and sizes its height to the label plus the
two margins. The value accepts an ``FxGripSectionData`` or a plain dictionary of
the same shape.

## Example

```objc
@{
    kFxParameterProperty_Id:      @(kMySectionID),
    kFxParameterProperty_Name:    @"Color",
    kFxParameterProperty_Type:    kFxParameterType_Section,
    kFxParameterProperty_Default: @{
        kFxGripSectionKey_Title:      @"Color",
        kFxGripSectionKey_Transform:  @(FxGripSectionTransformUppercase),
        kFxGripSectionKey_Alignment:  @(NSTextAlignmentLeft),
        kFxGripSectionKey_Size:       @13.0,
        kFxGripSectionKey_MarginTop:  @6,
    },
}
```

## Topics

### Control

- ``FxGripSectionParameter``
- ``FxGripSectionData``
- ``FxGripSectionView``

### Related

- <doc:Divider>

### Configuration keys

- ``kFxGripSectionKey_Alignment``
- ``kFxGripSectionKey_Color``
- ``kFxGripSectionKey_FontName``
- ``kFxGripSectionKey_MarginBottom``
- ``kFxGripSectionKey_MarginTop``
- ``kFxGripSectionKey_Opacity``
- ``kFxGripSectionKey_Size``
- ``kFxGripSectionKey_Title``
- ``kFxGripSectionKey_Transform``
- ``kFxGripSectionKey_Weight``
- ``kFxGripSectionKey_Width``

### Defaults

- ``kFxGripSectionDefaultMarginBot``
- ``kFxGripSectionDefaultMarginTop``
- ``kFxGripSectionDefaultOpacity``
- ``kFxGripSectionDefaultSize``

### Types

- ``FxGripSectionTransform``
