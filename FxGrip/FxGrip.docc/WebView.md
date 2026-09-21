# Web View Control

Show a whitelisted web page in the inspector, with JavaScript enabled and no
bridge back to the plugin.

## Overview

``FxGripWebViewParameter`` shows a web page in the inspector, gated by a URL
whitelist. Its value is an ``FxGripDictionary`` carrying the URL, the whitelist,
and the row height. ``FxGripWebPageView`` is the `WKWebView` display the
parameter hosts. Creation adds the custom-UI, not-animatable, full-view-width,
and no-state flags. See <doc:CustomControls> for the custom parameter model and
<doc:WebContent> for the whitelist syntax and the entitlement requirements.

The `WKWebView` is created only when the view enters a window, so no web content
process starts until the control is shown.

## Configuration keys

The value carries the keys from `FxGripWebView.h`:

| Key | Meaning |
| --- | --- |
| `kFxGripWebViewKey_URL` | The URL to load (the string key, `kCustomAPI_StringKey`) |
| `kFxGripWebViewKey_Whitelist` | An array of glob patterns; absent defaults to `*` (all sites) |
| `kFxGripWebViewKey_Height` | The row height in points (default `kFxGripWebViewDefaultHeight`, 200) |

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

## Whitelist gating

Web content runs with JavaScript enabled and no bridge back to the plugin. An
``FxGripURLWhitelist`` restricts which URLs the view may navigate to. A
navigation to a URL that is off the whitelist is blocked, including a navigation
started by page script, and a placeholder is shown when the requested URL is
blocked.

An absent whitelist defaults to `*`, which allows every site. Lock the list down
to the specific domains the control needs. <doc:WebContent> describes the glob
syntax and the host-suffix matching.

## Entitlements

Remote content needs the host plugin's XPC service to carry the
`com.apple.security.network.client` entitlement, and a non-TLS `http` URL needs
an App Transport Security exception. FxGrip provides the control; the plugin
declares the entitlements. See <doc:WebContent> for the requirements in full.

## Topics

### Control

- ``FxGripWebViewParameter``
- ``FxGripWebPageView``

### Related

- ``FxGripURLWhitelist``
- <doc:WebContent>

### Configuration keys

- ``kFxGripWebViewKey_Height``
- ``kFxGripWebViewKey_URL``
- ``kFxGripWebViewKey_Whitelist``

### Defaults

- ``kFxGripWebViewDefaultHeight``
