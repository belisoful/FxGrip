# Gating Web Content

Restrict which URLs the web view and video controls may load with a glob
whitelist, and declare the entitlements remote content needs.

## Overview

The ``FxGripWebViewParameter`` and ``FxGripVideoViewParameter`` controls display
remote content in the inspector. Web content runs with JavaScript enabled and no
bridge back to the plugin. An ``FxGripURLWhitelist`` restricts which URLs the
control may navigate to. A navigation to a URL that is off the whitelist is
blocked, including a navigation started by page script.

The whitelist is an allow-list of glob patterns. The web view defaults to `*`,
which allows every site; the video control defaults to the common video-hosting
domains. Lock the list down to the specific domains a control needs.

## Glob patterns

A pattern is a glob:

- `?` matches exactly one character.
- `*` matches any run of characters, including none.
- Every other character is literal.

``FxGripURLWhitelist/regexPatternForGlob:`` translates a glob to an anchored,
case-insensitive regular expression. `?` becomes `.`, `*` becomes `.*`, and
every other character is escaped.

## Matching

A URL is allowed when any pattern matches the URL's full absolute string or a
label-boundary suffix of its host.

Host-suffix matching lets a bare domain cover its subdomains without opening a
look-alike host:

- `youtube.com` allows `youtube.com` and `www.youtube.com`.
- `youtube.com` blocks `eviltube.com` and `youtube.com.evil.example`.

A full-URL pattern matches the scheme and path:

- `https://*.vimeo.com/video/*` allows `https://player.vimeo.com/video/12345`.
- The same pattern blocks the `http` scheme and any other path.

The allow-list has two ends. An empty list blocks every URL. The single pattern
`*` allows every URL. A nil URL is never allowed.

## Managing the list

Build a whitelist from a set of patterns, or seed one from a preset:

```objc
FxGripURLWhitelist *list = [FxGripURLWhitelist defaultVideoWhitelist];
[list addPattern:@"vimeo.com"];
[list removePattern:@"bitchute.com"];
BOOL ok = [list matchesURLString:@"https://player.vimeo.com/video/42"];
```

The list supports add, remove, contains, and remove-all, and a bulk replace
through ``FxGripURLWhitelist/setPatterns:``. Each pattern is trimmed of
surrounding whitespace, and duplicates are dropped. ``FxGripURLWhitelist`` is
secure-codable and copyable, so it rides in a parameter value or a preset.

A control reads its whitelist from the value's whitelist key, an array of glob
strings:

```objc
kFxParameterProperty_Default: @{
    kFxGripVideoKey_URL:       @"https://www.youtube.com/watch?v=abc",
    kFxGripVideoKey_Whitelist: @[@"youtube.com", @"youtu.be"],
    kFxGripVideoKey_Autoplay:  @YES,
}
```

## Choosing the player

The ``FxGripVideoViewParameter`` control picks its player from the URL:

- A `file://` URL or a direct media URL (mp4, m4v, mov, m3u8, webm) plays through
  an AVKit `AVPlayerView`.
- Any other whitelisted remote URL loads in a `WKWebView`, so a hosted player
  page embeds.
- A remote URL that is off the whitelist shows a placeholder.

The autoplay and loop keys apply to the AVKit path.

## Entitlements

FxGrip provides the controls. The plugin declares the entitlements, because they
live on the plugin's XPC service target rather than the framework.

| Content | Requirement |
| --- | --- |
| Remote `http`/`https` | `com.apple.security.network.client` on the XPC service |
| Non-TLS `http` | An App Transport Security exception in the plugin `Info.plist` |
| Bundled `file://` | None |

A remote load fails without the network entitlement. Prefer `https`, and add an
App Transport Security exception per domain rather than allowing arbitrary loads.
Reach a user-chosen local file through a security-scoped bookmark; BEFoundation's
`BESecurityScopedURLManager` manages the bookmarks.

## Topics

### Whitelist

- ``FxGripURLWhitelist``

### Controls

- ``FxGripWebViewParameter``
- ``FxGripVideoViewParameter``
