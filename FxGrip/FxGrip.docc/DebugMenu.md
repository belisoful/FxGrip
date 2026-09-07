# Debug Menu

Expose a debug popup and an optional activator toggle that reveal hidden parameters during development.

## Overview

``FxGripDebugMenu`` is an extension in the notification-driven system described in
<doc:ExtensionArchitecture>. The extension registers a debug Menu parameter
(`kFxParameterId_DebugMenu`) and, when the activator channel is enabled, a Toggle parameter
(`kFxParameterId_DebugActivator`). The menu commands reveal hidden parameters, toggle the
activator's value and visibility, and remove the debug controls.

The extension observes:

- Add parameters → registers the debug menu and, when enabled, the activator toggle.
- Get flags / set flags (pre) → transfers a parameter's HIDDEN bit while in debug mode.
- Parameter changed → reveals or hides the menu when the activator changes.
- The menu's action selector `manageDebuggerController:atTime:error:` dispatches the commands.

## Gating

Two channels resolve through a master gate and the Info.plist together.

- `allowsDebugFeatures` returns `YES` by default. A plugin overrides it to return `NO` in
  compiled code, forcing both channels off regardless of the Info.plist.
- `pluginDebugMenuEnabled` is `allowsDebugFeatures` and the Info.plist `debugMenu` key
  together.
- `pluginDebugActivatorEnabled` is `allowsDebugFeatures` and the Info.plist `debugActivator`
  key together.
- `hasDebugMenu` is `YES` when either channel is permitted; the loader gates on it.

Because the plist keys reach the framework only through the two channel getters, and both
consult `allowsDebugFeatures` first, a compiled override blocks a plist edit from re-enabling
the debug menu.

## Debug-mode flag transform

A parameter carries its saved visibility in the HIDDEN bit. While in debug mode, a hidden
parameter stays shown, so the extension parks the true visibility in a proxy bit and restores
it around each flags access.

- flags read, `IN_DEBUG_MODE` set → clears HIDDEN, then transfers a set `HIDDEN_PROXY` bit
  back to HIDDEN, so the read reports the saved visibility.
- flags write, `IN_DEBUG_MODE` set → clears `HIDDEN_PROXY`, then transfers a set HIDDEN bit
  into `HIDDEN_PROXY`, so a save records the true visibility while the parameter stays shown.

The read handler runs at `FxGripExtensionDefaultPriority + 2`, after ``FxGripParameterData``
restores the stored flag bits at the default priority.

## Menu commands

The menu is a single layout: each displayed row is paired with a command, and a selection
resolves against that layout. The commands are:

- unhide → sets or clears the debug-mode bit on every parameter that does not carry the
  `NO_DEBUG` flag, then rebuilds the menu.
- toggle activator visibility → flips the activator control's HIDDEN bit.
- toggle activator value → flips the activator's Bool value and shows or hides the menu to
  match.
- toggle all → hides both the activator control and the menu, leaving the activator as a
  Motion-riggable switch that still drives the menu's visibility.
- remove debug → leaves unhide mode, then removes the activator and the debug menu parameters.

The activator reveals the menu directly in the parameter-changed handler, not through its
target preset. A plugin may not load ``FxGripMeta``, which applies target presets, so the
reveal cannot depend on it.

## Topics

### Extension

- ``FxGripDebugMenu``
- ``FxGripParameterData``
- <doc:ExtensionArchitecture>
