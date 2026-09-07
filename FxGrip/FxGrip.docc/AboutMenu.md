# About Menu

Build a plugin's About popup from a configuration dictionary of links, text lines, separators, and a warning dialog gated by an agreement parameter.

## Overview

``FxGripAboutMenu`` is an extension in the notification-driven system described in
<doc:ExtensionArchitecture>. The effect installs it when it resolves an About menu
configuration. `hasAboutMenu` gates the loader, and `aboutMenuConfiguration` reads the
`aboutMenu` plugin property. A plugin overrides `aboutMenuConfiguration` to supply the
configuration in code, and overrides `aboutMenuItems:` to extend or reorder the entries at
runtime.

The extension observes three points in the lifecycle:

- Add parameters → it registers a Menu parameter (`kFxParameterId_AboutMenu`) whose items are
  the baseline layout. The parameter is not animatable and carries no state.
- Parameter changed → it rebuilds the popup when a gating parameter changes.
- The menu's action selector `manageAboutMenu:atTime:error:` dispatches the selected row to
  its action.

The extension posts `FxGripAboutMenuLinkName` after it opens a link, with the opened URL
string under `FxGripAboutMenuLinkURLKey`.

## Configuration keys

The `aboutMenu` dictionary holds these entries.

| Key | Value | Effect |
| --- | --- | --- |
| `FxGripAboutMenuItemsKey` | array of entry dictionaries | the rows the menu presents |
| `FxGripAboutMenuNameKey` | string | the popup parameter's name |
| `FxGripAboutMenuMainTextKey` | string | a non-actionable line shown above the entries |
| `FxGripAboutMenuAgreementIdKey` | number (`FxParameterId`) | an agreement parameter that gates the warning rows |
| `FxGripAboutMenuAgreementAcceptedValueKey` | number | the value at or above which the agreement is accepted; default 1 |
| `FxGripAboutMenuWarningKey` | array of strings | warning lines shown until the agreement is accepted |
| `FxGripAboutMenuWarningDialogTextKey` | string | the text shown in the warning dialog |
| `FxGripAboutMenuFallbackUrlKey` | string | a URL appended to every link's fallback chain |

Each entry dictionary carries a label and a kind, plus link and gating keys.

| Key | Value | Effect |
| --- | --- | --- |
| `FxGripAboutEntryLabelKey` | string | the row's label |
| `FxGripAboutEntryKindKey` | kind string | the row kind; default is a link |
| `FxGripAboutEntryUrlKey` | string | the primary URL for a link row |
| `FxGripAboutEntryFallbacksKey` | array of strings | ordered fallback URLs tried when the primary fails |
| `FxGripAboutEntryDisplayIdKey` | number (`FxParameterId`) | a Bool parameter that gates the row's display |

The kind is one of `FxGripAboutEntryKindLink`, `FxGripAboutEntryKindSeparator`,
`FxGripAboutEntryKindText`, or `FxGripAboutEntryKindDialog`.

## Layout and gating

The extension resolves the configuration into an ordered layout in one pass. A row pairs a
label with an action, and a link row also carries the ordered URLs to try. The baseline
layout built at parameter-add time includes every gated entry and treats the agreement as
accepted. The live layout consults the gates:

- warning lines present and agreement not accepted → the warning rows precede the menu, each
  a dialog row.
- an entry with a display gate whose Bool value is `NO` → the entry is dropped.
- a host read that fails → the row is treated as accepted, so a transient API failure never
  locks a plugin out of its own About menu.

A change to the agreement parameter or any entry display gate rebuilds the popup.

## Links

A link row opens the first URL that succeeds, falling through its ordered list. The list is
the entry's primary URL, then its fallbacks, then the configuration's global fallback. The
host completion runs off the main thread, so the fall-through recurses and the broadcast hops
back to the main queue. A successful open posts `FxGripAboutMenuLinkName`.

## Example

```objc
- (NSDictionary *)aboutMenuConfiguration
{
    return @{
        FxGripAboutMenuNameKey:     @"About",
        FxGripAboutMenuMainTextKey: @"My Plugin 1.0",
        FxGripAboutMenuItemsKey: @[
            @{ FxGripAboutEntryLabelKey: @"Documentation",
               FxGripAboutEntryUrlKey:   @"https://example.com/docs",
               FxGripAboutEntryFallbacksKey: @[ @"https://example.com" ] },
            @{ FxGripAboutEntryKindKey: FxGripAboutEntryKindSeparator },
            @{ FxGripAboutEntryLabelKey: @"Release Notes",
               FxGripAboutEntryKindKey:  FxGripAboutEntryKindText },
        ],
        FxGripAboutMenuFallbackUrlKey: @"https://example.com",
    };
}
```

## Topics

### Extension

- ``FxGripAboutMenu``
- <doc:ExtensionArchitecture>
