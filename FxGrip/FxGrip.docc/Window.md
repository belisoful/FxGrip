# Host Window

Manage the plug-in's one host window: request it, install a content view, and track whether it is presented.

## Overview

``FxGripWindow`` is an extension in the notification-driven system described in
<doc:ExtensionArchitecture>. `FxRemoteWindowAPI` limits a plug-in instance to a single
host-created window: repeat requests return the same parent view, and the user can close the
window at any time. The extension owns that lifecycle. It requests the window through the
highest `FxRemoteWindowAPI` version the host vends, installs the content view into the host's
parent view when the window arrives, and tracks whether a window is presented.

The host shows its own affordance for an open plug-in window, the plug-in button near the
title bar, so presenting the window is the only integration a plug-in performs.

The host reply arrives asynchronously. State changes and the completion run on the caller's
thread of the host's reply; present from the main thread.

## Presenting

Two present methods request the window and install `contentView` on arrival:

- `presentWindowOfSize:completion:` → a fixed-size window through `FxRemoteWindowAPI`. The
  completion receives the host's parent view, or nil and an error when the host cannot create
  the window or vends no `FxRemoteWindowAPI`.
- `presentWindowWithMinimumSize:maximumSize:completion:` → a resizable window through
  `FxRemoteWindowAPI_v2`. The host caps the maximum at 80% of its own window. It falls back to
  a fixed-size window of the minimum size when the host vends only v1.

While a window is already presented, the host returns the same parent view.

## Content view

`contentView` is the view installed into the window. Setting it fills the host's parent view,
sizing to the bounds with a width-and-height-sizable autoresizing mask. Setting a new content
view while presented swaps it in place.

## Closing

- `closeWindow` → asks the host to close the window through `FxRemoteWindowAPI_v3` and returns
  `YES` when the request was made. A host that vends only v1 or v2 cannot close the window
  programmatically; the method clears the extension's state and returns `NO`, and the user
  closes the window.
- `noteWindowClosed` → clears the presented state after the user closes the window. The host
  does not notify the plug-in when the user closes the window. A plug-in that detects the
  closure calls this so the next present request starts clean.

`windowParentView` is the host's parent view, nil when no window is presented, and
`isWindowPresented` reports the presented state.

## Topics

### Extension

- ``FxGripWindow``
- <doc:ExtensionArchitecture>
