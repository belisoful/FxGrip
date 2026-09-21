# Google Analytics

Log effect notifications as Google Analytics events through priority-ordered capture rules and an idle latch.

## Overview

``FxGripGoogleAnalytics`` is an extension in the notification-driven system described in
<doc:ExtensionArchitecture>. The extension observes the effect's whole notification stream
and logs a Google Analytics event for each notification a capture rule accepts. The loader
installs it when `isGoogleAnalyticsInstalled` is `YES`, which reads the `googleanalytics`
plugin property through `gaIdentifier`. A nil, empty, or `-`-prefixed identifier disables the
extension.

During `extInit:`, the extension attaches to the effect's notifier as a single observer for
every notification the effect posts, installs the default capture rules, and configures
Firebase. The Firebase classes are resolved by name at runtime, so a plugin that does not
link Firebase still builds and runs with telemetry disabled.

## Capture rules

A capture rule is a `BEPredicateRule` evaluated against the notification. Rules are sorted by
priority on first use after a change; lower priority values are evaluated first. The first
matching rule decides the outcome. The default outcome is deny, so an event logs only when a
rule explicitly accepts it. Omitting a catch-all reject rule can never fail open into logging
every event.

Add a rule from a predicate format string:

```objc
FxGripGoogleAnalytics *ga = self.googleAnalytics;
[ga addCaptureRule:@"name == %@" outcome:YES, FxGripTileableEffectParameterChangedName];
[ga addCaptureRule:@"name LIKE %@" outcome:YES priority:100, @"MyEvent*"];
```

`addCaptureRule:outcome:` adds at the default priority; `addCaptureRule:outcome:priority:`
sets an explicit priority. Both return the created rule for later removal with
`removeCaptureRule:`. `captureRules` returns a copy of the current rules.

The default rules capture the finish-setup and document lifecycle events, and deny the
extension's own `GA*` notifications, the `FxGripNotify*` API traffic, and everything else. The
name prefix that marks telemetry is `kFxGripGoogleAnalyticsNotificationPrefix`.

## The idle latch

A host fires a continuous interaction, such as a slider drag, as many `parameterChanged:`
callbacks in quick succession. `eventLatchInterval` coalesces a burst of identical events into
one log. The first event for a key logs immediately, and further events with the same key are
suppressed until the key has been idle for the interval. The key is the notification name
combined with the changed parameter ID when the notification carries one, so each control
counts once per interaction. A value of 0 or less disables the latch. The default is 0.5
seconds.

## Logging

An accepted, unlatched event logs to Firebase Analytics when `measurementID` is set. The
event carries the plugin UUID, the plugin display name, and the changed parameter ID when
present. A nil `measurementID` disables logging while the extension keeps evaluating rules and
updating the latch.

## Topics

### Extension

- ``FxGripGoogleAnalytics``
- <doc:ExtensionArchitecture>

### Notification naming

- ``kFxGripGoogleAnalyticsNotificationPrefix``
- ``kFxGripGoogleAnalyticsSelfRemovePredicate``
