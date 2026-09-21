# Banner

A read-only, full-width message strip with a bold title, an optional subtitle, and an optional graphic.

## Overview

The banner is a display control that draws a colored strip across the inspector
width. A plugin declares it with the type string `kFxParameterType_Banner`
(`banner`). The class is ``FxGripBannerParameter`` and its backing view is
``FxGripBannerView``. The value is an ``FxGripDictionary`` carrying the title,
subtitle, colors, point size, corner radius, and image-mode keys declared in
`FxGripBanner.h`.

The effect reports state by setting the parameter value. `updateFromCustomData:`
reads the dictionary and redraws the strip. The banner is read-only, so creation
adds the custom-UI, not-animatable, full-view-width, and no-state flags.

## Value keys

| Key macro | Meaning | Default |
| --- | --- | --- |
| `kFxGripBannerKey_Title` (`kCustomAPI_StringKey`) | The title text. | The parameter name for a text banner. |
| `kFxGripBannerKey_FontSize` (`kCustomAPI_FloatKey`) | The title point size. | `12.0` (`kFxGripBannerDefaultFontSize`), bold system font. |
| `kFxGripBannerKey_FillColor` (`kCustomAPI_RGBAKey`) | The background fill color. | The control accent color. |
| `kFxGripBannerKey_Subtitle` (`"subtitle"`) | The subtitle text. | None. The subtitle is hidden. |
| `kFxGripBannerKey_TextColor` (`"textColor"`) | The title and subtitle color. | White. |
| `kFxGripBannerKey_CornerRadius` (`"cornerRadius"`) | The corner radius, in points. | `-1.0` (`kFxGripBannerSquareCorners`), square corners. |
| `kFxGripBannerKey_ImageName` (`"imageName"`) | A named or file image that switches the banner to a graphic. | None. |
| `kFxGripBannerKey_TemplateImage` (`"templateImage"`) | A boolean that tints a template image by the text color. | `NO`. |
| `kFxGripBannerKey_LinkURL` (`"linkURL"`) | A URL string that makes the banner clickable. | None. |
| `kFxGripBannerKey_ActionButton` (`"actionButton"`) | A boolean that shows a companion button opening the link. | `NO`. |

## Behavior

- Title omitted, no image → the title uses the parameter name.
- Title omitted, image present → the graphic stands alone with no title fallback.
- Corner radius below zero → square corners spanning the full width.
- Image name resolves → the graphic draws above the text, constrained to `kFxGripBannerMaxImageWidth` (148 points).
- Template image set → the graphic draws tinted by the text color, so a black-with-alpha asset adapts to a light or dark UI.
- Link URL set → the strip is clickable and shows the pointing-hand cursor.
- Action button set and a link is present → a companion button in the top-right corner opens the same link.

The strip sizes its height to the content plus padding. A named image is looked
up first, then a file at the same path.

## Example

```objc
@{
    kFxParameterProperty_Id:      @(kMyBannerID),
    kFxParameterProperty_Name:    @"Status",
    kFxParameterProperty_Type:    kFxParameterType_Banner,
    kFxParameterProperty_Default: @{
        kFxGripBannerKey_Title:        @"Rendering",
        kFxGripBannerKey_Subtitle:     @"Frame 120 of 240",
        kFxGripBannerKey_FontSize:     @13.0,
        kFxGripBannerKey_FillColor:    @[ @0.15, @0.35, @0.75, @1.0 ],
        kFxGripBannerKey_CornerRadius: @6.0,
    },
}
```

## Topics

### Control

- ``FxGripBannerParameter``
- ``FxGripBannerView``
- ``FxGripDictionary``

### Related

- <doc:Capsule>

### Configuration keys

- ``kFxGripBannerKey_ActionButton``
- ``kFxGripBannerKey_CornerRadius``
- ``kFxGripBannerKey_FillColor``
- ``kFxGripBannerKey_FontSize``
- ``kFxGripBannerKey_ImageName``
- ``kFxGripBannerKey_LinkURL``
- ``kFxGripBannerKey_Subtitle``
- ``kFxGripBannerKey_TemplateImage``
- ``kFxGripBannerKey_TextColor``
- ``kFxGripBannerKey_Title``

### Defaults and limits

- ``kFxGripBannerDefaultFontSize``
- ``kFxGripBannerMaxImageWidth``
- ``kFxGripBannerSquareCorners``
