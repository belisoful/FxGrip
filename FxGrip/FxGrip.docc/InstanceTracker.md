# Instance Tracker

Track every live instance of a plugin by its UUID, and answer sibling and timeline-neighbor queries.

## Overview

``FxGripInstanceTracker`` is an extension in the notification-driven system described in
<doc:ExtensionArchitecture>. The extension keeps a process-wide registry of effect instances
keyed by plugin UUID. The loader installs it when `isTrackingInstances` reads the
`instanceTracker` plugin property as `YES`.

The registry holds non-retaining pointer values, so a tracked effect is never kept alive. An
array of live instances links every plugin instance and would form a retain cycle; do not
hold the result of `instances` beyond its immediate use.

## Registration

The extension observes two lifecycle points:

- Added to document → records the effect under its plugin UUID and captures the UUID and
  pointer for the dealloc-time removal.
- Removed from document → removes the effect from the registry.

The captured identity backs the removal in `dealloc`. The effect reference is weak and reads
nil by then, and the teardown notification does not arrive, because the notification center's
object filter is nil mid-dealloc. A registration whose UUID is nil is skipped, because a nil
key cannot address the registry. Registry mutation is synchronized, and removal is idempotent,
so the dealloc sweep and an explicit removal never conflict.

## Queries

The effect-side accessors read the shared registry by the effect's plugin UUID:

- `instances` → the live sibling instances of this effect's plugin UUID.
- `instanceCount` → the number of live instances.
- `instanceAtIndex:` → the instance at a registry index, or nil when out of range.

The extension answers timeline-neighbor queries against the sibling instances:

- `startTimeOfNextEffect:` → the nearest later timeline start time, or `kCMTimeInvalid` when
  none is later.
- `startTimeOfPreviousEffect:` → the nearest earlier timeline start time, or `kCMTimeInvalid`
  when none is earlier.

Each neighbor query opens a start-time access context on the sibling before reading its
`effectStartTimeInTimeline`, so the read runs outside a host call.

## Topics

### Extension

- ``FxGripInstanceTracker``
- <doc:ExtensionArchitecture>

### The extension key

- ``kInstanceTrackerKey``
