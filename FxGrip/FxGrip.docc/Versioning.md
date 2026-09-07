# Versioning

Compare the plugin version to the version stored in the project and migrate the stored data when the plugin is newer.

## Overview

A plugin evolves after a project saves an instance of it. The stored parameters, meta, and analysis data belong to the plugin version that created them, and a newer plugin may read them differently. `FxGripTileableEffect (Versioning)` reconciles the two. It reads the plugin's declared version and the version stored in the project, and when the plugin is newer it runs a subclass migration hook and records the new version.

The category reads two versions:

- `pluginVersion` → the plugin's integer version from its registration record (`kProPlugPlugIn_VersionProperty`); 1 when absent.
- `installedVersion` → the version stored in the project at creation, from FxPlug's `FxVersioningAPI` (`versionAtCreation`); 0 when the API is unavailable.

`pluginStringVersion` reads the plugin's short version string from `CFBundleShortVersionString` for display.

## The upgrade path

`checkVersion:` drives the reconciliation. It reads the installed version, and when the plugin version is greater it runs the migration hook and records the plugin version through the versioning API:

- installed version is 0, or equal to the plugin version → no upgrade runs.
- plugin version is greater than the installed version → run `upgradeFromVersion:currentVersion:error:`, then record the plugin version with `updateVersionAtCreation:`.
- the versioning API is unavailable → the method returns NO and sets an `kFxError_APIUnavailable` error.

`checkVersion:` returns YES only when an upgrade runs and records the new version. The new version is recorded only after the migration hook succeeds, so a failed migration leaves the stored version unchanged and the upgrade runs again on the next open.

## The migration hook

`upgradeFromVersion:currentVersion:error:` migrates the project's stored data from the installed version to the current version. The base implementation returns YES and migrates nothing. A subclass overrides it to convert its stored data:

```objc
- (BOOL)upgradeFromVersion:(unsigned int)fromVersion
            currentVersion:(unsigned int)currentVersion
                     error:(NSError **)error
{
    if (fromVersion < 2) {
        // Convert a v1 stored value to the v2 representation.
    }
    return YES;
}
```

The stored data a migration touches is the same data the render reads back through the plugin state, so a migration rewrites values the render decodes (see <doc:PluginState>). The migration runs where the parameter API is valid, so it reads and writes parameters through the host directly.

## Topics

### Base class

- ``FxGripTileableEffect-class``

### Related articles

- <doc:PluginState>
