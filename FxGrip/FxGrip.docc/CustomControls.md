# Custom Parameter Controls

Add a status light, a progress bar, a section header, a banner, a badge, a
randomizer, a curve editor, a web view, a video player, or a live image strip
to the inspector by declaring a parameter of the matching custom type.

## Overview

A custom control is a parameter whose type resolves to an FxGrip parameter class
rather than a standard FxPlug control. The plugin declares the parameter in its
configuration with a custom `type` string. At creation the class adds a custom
parameter to the host and sets the flags the control needs. When the inspector
asks for the control's view, the class vends an `NSView` that reads the
parameter value and redraws.

Each control stores its state in a value object. Most controls use
``FxGripDictionary``, a keyed value that carries typed entries (a boolean, an
integer, a float, a string, an RGBA color). The section, divider, and curve
editor use their own data classes. FxGrip ships the value keys as macros in each
control's public header, so a configuration writes the same keys the view reads.

The images below are rendered from the live controls by the
`FxGripTests/FxGripDocImageGen` generator.

## The roster

| Control | Type string | Class | Value |
| --- | --- | --- | --- |
| Section header | `section` | ``FxGripSectionParameter`` | section data |
| Divider | `divider` | ``FxGripDividerParameter`` | divider data |
| Banner | `banner` | ``FxGripBannerParameter`` | ``FxGripDictionary`` |
| Capsule | `capsule` | ``FxGripCapsuleParameter`` | ``FxGripDictionary`` |
| Status light | `status` | ``FxGripStatusParameter`` | ``FxGripDictionary`` |
| Progress | `progress` | ``FxGripProgressParameter`` | ``FxGripDictionary`` |
| Switch | `switch` | ``FxGripSwitchParameter`` | ``FxGripDictionary`` |
| Random | `random` | ``FxGripRandomParameter`` | ``FxGripDictionary`` |
| Presets | `presets` | ``FxGripPresetsParameter`` | menu |
| Curve editor | custom view | ``FxGripCurveSetEditorView`` | ``FxGripCurveSetData`` |
| Web view | `webview` | ``FxGripWebViewParameter`` | ``FxGripDictionary`` |
| Video | `videoview` | ``FxGripVideoViewParameter`` | ``FxGripDictionary`` |
| Live image | `liveimage` | ``FxGripLiveImageParameter`` | ``FxGripDictionary`` |

## Structural controls

The section and divider span the inspector width and draw no row label. Creation
adds the custom-UI, not-animatable, full-view-width, and no-state flags.

### Section header

![A section header drawing an uppercased title](section)

A styled title header. The value carries the title (string key), point size
(float key), color (RGBA key), and the transform, alignment, font name, weight,
width, and margin keys from `FxGripSection.h`. A configuration that omits the
title uses the parameter name.

```objc
@{
    kFxParameterProperty_Id:      @(kMySectionID),
    kFxParameterProperty_Name:    @"Color",
    kFxParameterProperty_Type:    kFxParameterType_Section,
    kFxParameterProperty_Default: @{
        kFxGripSectionKey_Title:     @"Color",
        kFxGripSectionKey_Transform: @(FxGripSectionTransformUppercase),
        kFxGripSectionKey_Alignment: @(NSTextAlignmentLeft),
        kFxGripSectionKey_Size:      @13.0,
    },
}
```

### Divider

![A thin horizontal rule](divider)

A horizontal rule. Its `FxGripDividerData` carries the width fraction and the
top and bottom margins.

```objc
@{
    kFxParameterProperty_Id:   @(kMyDividerID),
    kFxParameterProperty_Name: @"",
    kFxParameterProperty_Type: kFxParameterType_Divider,
}
```

## Display controls

Display controls are read-only. The effect reports state by setting the
parameter value; `updateFromCustomData:` redraws the control. Creation adds the
custom-UI and no-state flags.

### Status light

![A green status light labeled Ready](status)

A colored dot paired with a label. The integer value sets the dot's `BEDotState`
(off gray, ok green, warning yellow, error red, active blue); the string value
sets the label. The dot is a BEFoundation `BEDotView`.

```objc
@{
    kFxParameterProperty_Id:      @(kMyStatusID),
    kFxParameterProperty_Name:    @"State",
    kFxParameterProperty_Type:    kFxParameterType_Status,
    kFxParameterProperty_Default: @{
        kCustomAPI_IntKey:    @(BEDotStateOk),
        kCustomAPI_StringKey: @"Ready",
    },
}
```

### Progress

![A blue dot, an Exporting label, and a bar at 62 percent](progress)

A bar added to the same dot and label. The float value drives the bar: a value
in `0…1` sets a determinate fraction, and a negative value shows an
indeterminate animation. The integer value sets the dot state and the string
value sets the label.

```objc
@{
    kFxParameterProperty_Id:      @(kMyProgressID),
    kFxParameterProperty_Name:    @"Export",
    kFxParameterProperty_Type:    kFxParameterType_Progress,
    kFxParameterProperty_Default: @{
        kCustomAPI_IntKey:    @(BEDotStateActive),
        kCustomAPI_StringKey: @"Exporting",
        kCustomAPI_FloatKey:  @0.62,
    },
}
```

### Banner

![A full-width banner with a bold title and a subtitle](banner)

A full-width colored strip with a bold title and an optional subtitle. Its value
carries the title (string key), subtitle, title point size (float key),
background color (RGBA key), text color, and corner radius from `FxGripBanner.h`.
An omitted title uses the parameter name. An omitted fill color uses the accent
color. The banner adds the not-animatable and full-view-width flags.

```objc
@{
    kFxParameterProperty_Id:      @(kMyBannerID),
    kFxParameterProperty_Name:    @"Status",
    kFxParameterProperty_Type:    kFxParameterType_Banner,
    kFxParameterProperty_Default: @{
        kFxGripBannerKey_Title:    @"Rendering",
        kFxGripBannerKey_Subtitle: @"Frame 120 of 240",
    },
}
```

### Capsule

![A gray pill badge reading Beta](capsule)

A pill badge sized to its text that keeps its row label. Its value carries the
text (string key), point size (float key), fill color (RGBA key), text color,
and corner radius from `FxGripCapsule.h`. A corner radius below zero draws a full
pill.

```objc
@{
    kFxParameterProperty_Id:      @(kMyCapsuleID),
    kFxParameterProperty_Name:    @"Stage",
    kFxParameterProperty_Type:    kFxParameterType_Capsule,
    kFxParameterProperty_Default: @{
        kFxGripCapsuleKey_Title: @"Beta",
    },
}
```

## Interactive controls

Interactive controls write the value back when the user changes them. The write
runs outside a host call, so it goes through an out-of-band access context.

### Switch

![An on switch](switch)

A boolean presented as an `NSSwitch`. Toggling writes the boolean under the bool
key.

```objc
@{
    kFxParameterProperty_Id:      @(kMySwitchID),
    kFxParameterProperty_Name:    @"Enabled",
    kFxParameterProperty_Type:    kFxParameterType_Switch,
    kFxParameterProperty_Default: @{ kCustomAPI_BoolKey: @YES },
}
```

### Random

![An integer field, a stepper, and a reload button](random)

An editable integer field, an up-down stepper, and a reload button, left to
right. Editing the field or the stepper writes the integer; reload draws a
uniform integer in the configured range and writes it. The value carries the
integer under the int key, and the configuration may declare the min, max, and
step keys from `FxGripRandom.h`.

```objc
@{
    kFxParameterProperty_Id:      @(kMyRandomID),
    kFxParameterProperty_Name:    @"Seed",
    kFxParameterProperty_Type:    kFxParameterType_Random,
    kFxParameterProperty_Default: @{
        kFxGripRandomKey_Value: @1234,
        kFxGripRandomKey_Min:   @1,
        kFxGripRandomKey_Max:   @100000,
        kFxGripRandomKey_Step:  @1,
    },
}
```

### Presets

The presets control is a host popup menu (``FxGripPresetsParameter`` extends
``FxGripMenuParameter``), so the host draws it and no view is generated.

```objc
@{
    kFxParameterProperty_Id:   @(kMyPresetsID),
    kFxParameterProperty_Name: @"Preset",
    kFxParameterProperty_Type: kFxParameterType_Presets,
}
```

## Curve editor

![A curve editor with an S-curve over a grid](curve)

The curve editor edits a tone or remap curve on a grid with draggable control
points. ``FxGripCurveEditorView`` edits one ``FxGripCurveData``;
``FxGripCurveSetEditorView`` stacks a strip per mapping and edits an
``FxGripCurveSetData``. A curve is created from its points, or from the role's
neutral shape.

```objc
CGPoint points[] = { {0.0, 0.0}, {0.3, 0.12}, {0.7, 0.88}, {1.0, 1.0} };
FxGripCurveData *curve = [FxGripCurveData curveWithPoints:points
                                                    count:4
                                                     role:FxGripCurveRoleRemap
                                                   domain:FxGripCurveDomainLinear];

FxGripCurveSetData *set = [FxGripCurveSetData new];
[set setCurve:curve forKey:@"luma"];
```

### Line color and background

![A curve over the hue spectrum](curve-hue)
![A red channel curve over the red ramp](curve-color)

The `background` styles the strip behind the curve: a grid, the hue spectrum, a
luma, saturation, red, green, or blue ramp, or an alpha checker. The `lineColor`
sets a solid stroke — red, green, blue, or an arbitrary color, defaulting to white
(a nil restores white).

```objc
editor.background = FxGripCurveBackgroundRedRamp;
editor.lineColor  = NSColor.redColor;   // white, red, green, blue, or any NSColor
```

### Hue line and vertical gradients

![A curve line stroked as the hue spectrum](curve-line-hue)
![Hue at the top fading to the base](curve-v-huefade)
![A two-color vertical fade](curve-v-twocolor)
![A hue band through the center](curve-v-hueband)
![Black over the hue spectrum over white](curve-v-blackhuewhite)

Set `lineStyle` to `FxGripCurveLineStyleHue` to stroke the line itself as the hue
spectrum. For a two-dimensional background, set the top, center, and bottom stops:
each ``FxGripCurvePaint`` is a color, the hue spectrum, or none (transparent, fading
to the base). A nil center makes a two-stop top-to-bottom fade; a nil top or bottom
drops that end. Any stop set overrides `background`. A black top, a hue center, and a
white bottom make a hue-versus-value field: pure hue at the center, shaded above,
tinted below.

```objc
editor.lineStyle = FxGripCurveLineStyleHue;                  // a rainbow line

editor.topPaint    = [FxGripCurvePaint huePaint];            // hue across the top
editor.centerPaint = [FxGripCurvePaint nonePaint];           // fades through the middle
editor.bottomPaint = [FxGripCurvePaint paintWithColor:NSColor.systemTealColor];

editor.topPaint    = [FxGripCurvePaint paintWithColor:NSColor.blackColor];
editor.centerPaint = [FxGripCurvePaint huePaint];            // shade above, tint below
editor.bottomPaint = [FxGripCurvePaint paintWithColor:NSColor.whiteColor];
```

### Interaction and the point readout

The editor follows Final Cut Pro and macOS conventions, shared across the
parameters through ``FxGripEventModifiers``:

| Gesture | Action |
| --- | --- |
| Click | add a point |
| Drag | move the point |
| Option-drag | fine (slow) adjustment |
| Shift-drag | constrain to horizontal or vertical |
| Command-click | delete the point |
| Delete key | delete the selected point |
| Control-click | contextual menu |

![The point value in a floating chip](curve-readout-chip)
![The point value on the axes](curve-readout-axis)
![The point value in a corner](curve-readout-corner)

`pointReadoutStyle` shows a point's exact value: `floatingChip` beside the point,
`axis` on crosshair guides at each edge, `corner` in a fixed corner, or
`systemTooltip`. `pointReadoutUnits` chooses `normalized`, `eightBit`, `percent`,
or `domainAware` (hue in degrees, otherwise 0–255). `pointReadoutTrigger` shows it
for the active point, or also on hover, or on Command-hover.

```objc
editor.pointReadoutStyle   = FxGripCurveReadoutStyleFloatingChip;
editor.pointReadoutUnits   = FxGripCurveReadoutUnitsEightBit;
editor.pointReadoutTrigger = FxGripCurveReadoutTriggerActiveAndModifierHover;  // Command-hover
```

## Web and video controls

The web view and video controls display remote content and gate it with an
``FxGripURLWhitelist``. They span the inspector width and add the custom-UI,
not-animatable, full-view-width, and no-state flags. The player is created only
when the control enters a window. Web content and video hosting need entitlements
the plugin declares. See <doc:WebContent> for the whitelist syntax and the
entitlement requirements.

### Web view

![A web view showing an embedded help page](webview)

A `WKWebView` gated by the whitelist, with JavaScript enabled and no bridge back
to the plugin. A navigation to an off-whitelist URL is blocked and a placeholder
is shown. The value carries the URL (string key), the whitelist (an array of glob
patterns), and the row height, from `FxGripWebView.h`.

```objc
@{
    kFxParameterProperty_Id:      @(kMyWebID),
    kFxParameterProperty_Name:    @"Docs",
    kFxParameterProperty_Type:    kFxParameterType_WebView,
    kFxParameterProperty_Default: @{
        kFxGripWebViewKey_URL:       @"https://example.com/help",
        kFxGripWebViewKey_Whitelist: @[ @"example.com", @"*.example.com" ],
    },
}
```

### Video

![A video parameter showing an embedded player with a play button and scrubber](video)

A whitelisted direct-media URL (mp4, m4v, mov, m3u8, webm) or a local file plays
in an `AVPlayerView`. Any other whitelisted URL loads a hosted player page in a
`WKWebView`, shown above. The URL, whitelist, row height, autoplay, and loop keys
come from `FxGripVideoView.h`; an absent whitelist defaults to the common
video-hosting domains.

```objc
@{
    kFxParameterProperty_Id:      @(kMyVideoID),
    kFxParameterProperty_Name:    @"Clip",
    kFxParameterProperty_Type:    kFxParameterType_VideoView,
    kFxParameterProperty_Default: @{
        kFxGripVideoKey_URL:      @"https://videos.example.com/intro.mp4",
        kFxGripVideoKey_Autoplay: @NO,
    },
}
```

For local media, set the URL to a `file://` URL. A file URL is not remote, so the
whitelist does not gate it, and its extension is a direct-media type, so it plays
in the `AVPlayerView`. Build the URL from a media file the plugin bundles:

```objc
NSURL *media = [[NSBundle bundleForClass:self.class] URLForResource:@"intro"
                                                      withExtension:@"mp4"];
@{
    kFxParameterProperty_Id:      @(kMyVideoID),
    kFxParameterProperty_Name:    @"Clip",
    kFxParameterProperty_Type:    kFxParameterType_VideoView,
    kFxParameterProperty_Default: @{
        kFxGripVideoKey_URL:      media.absoluteString,   // file:///…/intro.mp4
        kFxGripVideoKey_Autoplay: @YES,
        kFxGripVideoKey_Loop:     @YES,
    },
}
```


## Live image

![Four live image slots labeled Channel A through D](liveimage)

A strip of image slots fed from the render pass. The FxPlug host runs the render
pass and the custom parameter views in the same plugin process, so an image the
effect holds at render reaches the inspector without a trip through the host's
parameter store. The value carries only the configuration: the slot labels (one
slot per label), the row height, the info caption, the checkerboard, a vertical
flip, and the snapshot size, from `FxGripLiveImage.h`. The pixels never enter the
host document. Creation adds the custom-UI, not-animatable, full-view-width, and
no-state flags.

```objc
@{
    kFxParameterProperty_Id:      @(kMyChannelsID),
    kFxParameterProperty_Name:    @"Channels",
    kFxParameterProperty_Type:    kFxParameterType_LiveImage,
    kFxParameterProperty_Default: @{
        kFxGripLiveImageKey_Labels: @[ @"Channel A", @"Channel B", @"Channel C", @"Channel D" ],
        kFxGripLiveImageKey_Height: @96.0,
    },
}
```

### Publishing

The runtime parameter is the effect's parameter for the ID. The effect publishes
from the render pass, on any thread, and the call returns before the copy runs.
A slot shows its latest ``FxGripLiveFrame``; a view attached later shows the
stored frames.

```objc
FxGripLiveImageParameter *channels = (FxGripLiveImageParameter *)self[kMyChannelsID];
[channels publishTextures:@[ channelA, channelB, channelC, channelD ]];   // one command buffer
[channels publishTexture:bufferA inSlot:0];                               // one slot
[channels publishImageTile:sourceImages.firstObject inSlot:1];            // an FxImageTile
[channels publishImageBuffer:cachedFrame inSlot:2];                       // an FxGripImageBuffer
```

A Metal texture is copied on the GPU into a CPU-readable staging texture,
downscaled through its mipmap chain until its longest side is at most the
snapshot size (640 pixels by default), and read back when the command buffer
completes. A slot whose previous copy is still in flight drops the new texture,
so a fast render never queues behind the inspector. The supported texture
formats are the RGBA and BGRA 8-bit, RGBA 16-bit, RGBA half and float, and the
single-channel 8-bit, half, and float formats.

Set the flip key when a source stores its bottom row first, as a raw FxPlug tile
texture does. The info caption shows each frame's dimensions and pixel format
beside the slot label.

## Topics

### Structural

- ``FxGripSectionParameter``
- ``FxGripDividerParameter``

### Display

- ``FxGripStatusParameter``
- ``FxGripProgressParameter``
- ``FxGripBannerParameter``
- ``FxGripCapsuleParameter``

### Interactive

- ``FxGripSwitchParameter``
- ``FxGripRandomParameter``
- ``FxGripPresetsParameter``

### Curve editor

- ``FxGripCurveEditorView``
- ``FxGripCurveSetEditorView``
- ``FxGripCurveData``
- ``FxGripCurveSetData``

### Web and video

- ``FxGripWebViewParameter``
- ``FxGripVideoViewParameter``
- <doc:WebContent>

### Live image

- ``FxGripLiveImageParameter``
- ``FxGripLiveImageView``
- ``FxGripLiveFrame``
```
