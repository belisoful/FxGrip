# Video Control

Play a whitelisted video or a bundled media file in the inspector, through an
AVKit player or an embedded hosted player page.

## Overview

``FxGripVideoViewParameter`` plays a video in the inspector, gated by a URL
whitelist. Its value is an ``FxGripDictionary`` carrying the URL, the whitelist,
the row height, and the autoplay and loop flags. ``FxGripVideoView`` is the
player view the parameter hosts. Creation adds the custom-UI, not-animatable,
full-view-width, and no-state flags. See <doc:CustomControls> for the custom
parameter model and <doc:WebContent> for the whitelist syntax and the
entitlement requirements.

The player is created only when the view enters a window, so no media session or
web content process starts until the control is shown.

## Configuration keys

The value carries the keys from `FxGripVideoView.h`:

| Key | Meaning |
| --- | --- |
| `kFxGripVideoKey_URL` | The URL to play (the string key, `kCustomAPI_StringKey`) |
| `kFxGripVideoKey_Whitelist` | An array of glob patterns; absent defaults to the common video-hosting domains |
| `kFxGripVideoKey_Height` | The row height in points (default `kFxGripVideoDefaultHeight`, 180) |
| `kFxGripVideoKey_Autoplay` | Starts playback when the player loads |
| `kFxGripVideoKey_Loop` | Repeats playback |

```objc
@{
    kFxParameterProperty_Id:      @(kMyVideoID),
    kFxParameterProperty_Name:    @"Clip",
    kFxParameterProperty_Type:    kFxParameterType_VideoView,
    kFxParameterProperty_Default: @{
        kFxGripVideoKey_URL:       @"https://videos.example.com/intro.mp4",
        kFxGripVideoKey_Whitelist: @[ @"videos.example.com" ],
        kFxGripVideoKey_Autoplay:  @NO,
    },
}
```

An absent whitelist defaults to the common video-hosting domains from
``FxGripURLWhitelist/defaultVideoWhitelist``. Lock it down to the specific
domains the control needs.

## Choosing the player

The control picks its player from the URL:

- A `file://` URL or a direct media URL (mp4, m4v, mov, m3u8, webm) → plays through an AVKit `AVPlayerView`.
- Any other whitelisted remote URL → loads in a `WKWebView`, so a hosted player page embeds.
- A remote URL that is off the whitelist → shows a placeholder.

The autoplay and loop keys apply to the AVKit path.

## Bundled media

For local media, set the URL to a `file://` URL. A file URL is not remote, so the
whitelist does not gate it, and a direct-media extension plays in the
`AVPlayerView`. Build the URL from a media file the plugin bundles:

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

## Entitlements

Remote content needs the host plugin's XPC service to carry the
`com.apple.security.network.client` entitlement, and a non-TLS `http` URL needs
an App Transport Security exception. A bundled `file://` URL needs neither.
FxGrip provides the control; the plugin declares the entitlements. See
<doc:WebContent> for the requirements in full.

## Topics

### Control

- ``FxGripVideoViewParameter``
- ``FxGripVideoView``

### Related

- ``FxGripURLWhitelist``
- <doc:WebContent>

### Configuration keys

- ``kFxGripVideoKey_Autoplay``
- ``kFxGripVideoKey_Height``
- ``kFxGripVideoKey_Loop``
- ``kFxGripVideoKey_URL``
- ``kFxGripVideoKey_Whitelist``

### Defaults

- ``kFxGripVideoDefaultHeight``
