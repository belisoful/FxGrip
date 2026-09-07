# Regression

Validate a plugin's plist properties at load time in DEBUG builds, reporting problems without blocking the load.

## Overview

``FxGripRegression`` is an extension in the notification-driven system described in
<doc:ExtensionArchitecture>. It runs a validation pass when it loads, checking the plugin's
plist properties and reporting each problem. The pass reports and continues; it never blocks
the plugin from loading. The loader installs the extension when `isRegression` reads the
`regression` plugin property as `YES`, in DEBUG builds.

## The checks

The extension overrides `extLoadWithEffect:`, calls `super`, and runs two checks:

- UUID → reports when the plist UUID string does not parse as a UUID, or the effect's resolved
  `pluginUUID` is absent. The report suggests generating one with `uuidgen`.
- version → the version is expected to be an integer Number. A digit String is accepted with a
  warning. Any other value is an error, reported through `-description` so an array or
  dictionary version reports instead of crashing.

Each check returns its result for logging, and the load succeeds whatever the checks report.

## Topics

### Extension

- ``FxGripRegression``
- <doc:ExtensionArchitecture>
