# Extension Architecture

Extensions add behavior to an effect by observing prioritized notifications that the effect and its API wrappers post at each stage of the FxPlug lifecycle.

## Overview

FxGrip decomposes plugin behavior into extensions. An extension is an object that conforms to the `FxGripExtension` protocol, usually by subclassing `FxGripExtension` (declared in `FxGripExtension.h`). The effect owns its extensions in the `extensions` dictionary, keyed by `extKey`.

Dispatch is direct. Every notification observer is a selector registered with `NSPriorityNotificationCenter` (BEFoundation). When an extension loads, `-[FxGripExtensionBase extLoadWithEffect:]` walks a table that maps each notification name to an `ext…:` selector and registers an observer for each selector the extension actually implements. Posting a notification calls the implemented selectors in priority order. There is no per-event forwarding layer between the effect and the extension.

Two producers post notifications:

- `FxGripTileableEffect` (`FxGripTileableEffect.m`) → lifecycle notifications (`FxTileableEffect…Name`, declared in `FxGripTileableEffect+Notifications.h`).
- The `FxGrip…API_v…` wrapper classes in `FxGripAPIAccessing/` → parameter API notifications (`FxGripNotifyAPI_…Name`, declared in `FxGripAPINotifications.h`).

All notifications are posted with the effect instance as the notification `object`, so an extension observes only its own effect even though every effect shares `NSPriorityNotificationCenter.defaultCenter`. Exception: `FxGripDynamicParameterAPI_v3` posts its set-name and set-menu notifications with the parameter object (`self.effect[parameterID]`) as the notification object; observers registered against the effect do not receive those four posts.

The effect participates in its own extension system. `FxGripTileableEffect` inherits from `FxGripExtensionBase`, and `-loadExtensions` adds the effect itself to the extension list when the concrete subclass conforms to `FxGripExtension`. A subclass can therefore implement `ext…:` selectors directly instead of writing a separate extension class. The effect's own `extKey` is `FxGripTileableEffectExtKey` (`@"FxTileableEffect"`).

### Deprecated trampoline dispatch

Event dispatch registers each extension's handler selectors directly with the notification center in `FxGripExtension.m`; no per-event forwarding methods exist.

## Lifecycle sequence

The host drives the effect through the FxPlug protocol; each stage posts one notification. The userInfo dictionary is an `NSMutableDictionary` wherever observers are expected to write results back (see <doc:ExtensionArchitecture#Error-round-trip>).

1. **Load** — `-initWithAPIManager:` calls `-loadExtensions` (subclass override point) and `-initializeExtensions` (`FxGripTileableEffect+Extensions.m`). The extension list is sorted by `ncPriority:FxGripTileableEffectLoadName`; `FxGripTileableEffectLoadName` is a sort key only and is never posted. Each extension then receives `extLoadWithEffect:` / `extLoadWithIndex:`, which registers its notification observers. The load method's return value decides retention: `YES` → the extension enters the `extensions` dictionary; `NO` → it is dropped. Retention matters because `NSPriorityNotificationCenter` holds observers weakly; the `extensions` dictionary is the strong reference that keeps an extension alive and receiving notifications. Duplicate classes receive ascending indexes; an extension with `extIndividuate` set appends its index to `extKey`.
2. **Init** — still inside `-initWithAPIManager:`, the effect posts `FxGripTileableEffectInitName`. userInfo: `FxGripTileableEffectInitAPIManagerKey` → the `FxGripAPIAccessing` instance. Observer selector: `extInit:`.
3. **Properties** — `-properties:error:` posts `FxGripTileableEffectPropertiesName`. userInfo: `FxGripTileableEffectPropertiesKey` → the `NSMutableDictionary` of effect properties (read back through `userInfo.fxEffectProperties`). Observer: `extProperties:`.
4. **Add parameters** — `-addParametersWithError:` posts `FxGripTileableEffectAddParametersName`. userInfo: `FxGripTileableEffectParametersKey` → an `NSMutableArray` of mutable parameter-configuration dictionaries (`userInfo.fxEffectParameters`). Observers append or edit configuration dictionaries; a post-block flattens the array through `FxGripParameterUtility` after each observer runs. The effect then constructs the parameters through the creation API, which fires the per-parameter `FxGripNotifyAPI_ParameterAddPre` / `FxGripNotifyAPI_ParameterAdd` notifications, and finishes with a flush. Observer: `extAddParameters:`.
5. **Finish initial setup** — `-finishInitialSetup:` posts `FxGripTileableEffectFinishInitialSetupName` with an empty mutable userInfo. Observer: `extFinishInitialSetup:`.
6. **Added to document** — `-pluginInstanceAddedToDocument` posts `FxGripTileableEffectAddedToDocumentName` with no userInfo, then flushes. The effect's own high-priority observer reconstructs parameter objects from stored configuration during this notification. Observer: `extAddedToDocument:`.
7. **Parameter changed** — `-parameterChanged:atTime:error:` posts `FxGripTileableEffectParameterChangedName`, then flushes. userInfo:
    - `FxGripTileableEffectParameterChangedIDKey` → `NSNumber` wrapping the changed `FxParameterId`.
    - `FxGripTileableEffectParameterChangedAtTimeKey` → the change `CMTime` encoded as an `NSDictionary` (`CMTimeCopyAsDictionary`); decode with `CMTimeMakeFromDictionary`. Present only when encoding succeeds.
    Observer: `extParameterChanged:`.
8. **Flush** — `-extensionsFlush` (`FxGripTileableEffect+Extensions.m`) posts `FxGripTileableEffectFlushName` with an empty mutable userInfo. The effect calls it after adding parameters, after joining the document, and after each parameter change; extensions write pending state to the host during this notification. Observer: `extFlush:`.
9. **Plugin state** — `-pluginState:atTime:quality:error:` posts `FxGripTileableEffectPluginStateName`. userInfo: `FxGripTileableEffectPluginStateCoderKey` → the live `NSKeyedArchiver` (read back through `userInfo.fxCoder`; `renderTime` and `qualityLevel` are set on the coder via `NSCoder+FxPlug.h`). Observers encode render-time state into the archiver. When the subclass conforms to `FxGripTileableEffectCoderState`, the subclass `-pluginCoder:atTime:quality:error:` runs before the notification. Observer: `extPluginState:`.
10. **Render geometry** — `-destinationImageRect:…` posts `FxGripTileableEffectDestinationImageRectName` and `-sourceTileRect:…` posts `FxGripTileableEffectSourceTileRectName`, each with `FxGripTileableEffectPluginStateCoderKey` → an `NSKeyedUnarchiver` over the plugin state. `-sourceTileRect:…` returns before posting when `changesOutputSize` is `NO`. `-scheduleInputs:withPluginState:atTime:error:` posts `FxGripTileableEffectScheduleInputsName` with the same coder key; the schedule branch runs only when the subclass conforms to `FxGripTileableEffectCoderState`. Observers: `extDestinationRect:`, `extSourceRect:`, `extSchedule:`.
11. **Render** — `-renderDestinationImage:sourceImages:pluginState:atTime:error:` posts `FxGripTileableEffectRenderDestinationImageName` after the subclass coder-based render succeeds. The post sits inside the branch gated on `FxGripTileableEffectCoderState` conformance: a subclass that does not adopt the coder-state protocol renders nothing through this path and no notification is posted. userInfo:
    - `FxGripTileableEffectPluginStateCoderKey` → the `NSKeyedUnarchiver` over the plugin state.
    - `FxGripTileableEffectRenderDestinationImageKey` → the destination `FxImageTile`.
    - `FxGripTileableEffectRenderSourceImagesKey` → `NSArray<FxImageTile *>` of source tiles. Present only when the host supplies source images.
    - `FxGripTileableEffectRenderAtTimeKey` → the render `CMTime` encoded as an `NSDictionary`. Present only when encoding succeeds.
    Observer: `extRenderDestinationImage:`.
12. **Removed from document / unload** — `-dealloc` posts `FxGripTileableEffectRemovedFromDocumentName` (only when the effect joined a document) and then `FxGripTileableEffectUnloadName`, both with `reverse:YES` so the lowest-priority observers run first, mirroring setup order. Observers: `extRemovedFromDocument:`, `extUnload:`.

## API notifications

The versioned API wrappers in `FxGripAPIAccessing/` post an `FxGripNotifyAPI_…Name` notification around each host parameter call so extensions can observe and rewrite parameter traffic. The userInfo layout is uniform:

- `FxGripNotifyAPI_ParameterIDKey` (also stored at top level under `kFxParameterProperty_Id`) → `NSNumber` parameter ID.
- `FxGripNotifyAPI_ParameterKey` (`userInfo.fxParameter` / `userInfo.mutableFxParameter`) → the parameter property dictionary, using the `kFxParameterProperty_…` keys (`NSDictionary+FxGripTileableEffect.h`).
- `FxGripNotifyAPI_ResultKey` (`userInfo.fxResult`) → observer-supplied override result.
- `FxGripNotifyAPI_ErrorKey` (`userInfo.fxError`) → observer-supplied `NSError`.

Three posting patterns cover the API surface:

- `…Pre` notification → posted before the host call with a mutable nested parameter dictionary. Observers rewrite values in `mutableFxParameter` (for example `FxGripI18N` localizes names), set `fxError` to veto the call, or set `fxResult` to short-circuit it. `FxGripParameterCreationAPI_v5` posts `FxGripNotifyAPI_ParameterSetNamePreName` then `FxGripNotifyAPI_ParameterAddPreName` in its `preprocess:` step; `FxGripParameterSettingAPI_v5` and `FxGripParameterRetrievalAPI_v6` post `SetFlagsPre` / `GetFlagsPre` and honor `fxResult` as the return value.
- Post notification → posted after a successful host call with an immutable copy of the parameter dictionary. Observers record state; `FxGripParameterData` mirrors every added parameter this way.
- Get notification → posted after the host call with a mutable dictionary; the wrapper reads the possibly rewritten value back out (`FxGripNotifyAPI_ParameterGetNameName`, `FxGripNotifyAPI_ParameterGetStringValueName`, `FxGripNotifyAPI_ParameterGetFlagsName`, `FxGripNotifyAPI_ParameterGetMenuName`).

`FxGripNotifyAPI_ParameterRemoveName` is posted with `reverse:YES` so teardown runs opposite to creation order. The full name → selector table lives in `-[FxGripExtensionBase extLoadWithEffect:]`; each `FxGripNotifyAPI_…Name` maps 1:1 to an `extAPIParameter…:` selector (`FxGripNotifyAPI_ParameterAddName` → `extAPIParameterAdd:`, and so on).

`FxGripI18N.m` is the worked consumer example: it localizes names, string values, and menu items on the `…Pre` and `Add` notifications and reverses the mapping on the `Get…` notifications.

## Priority and ordering

`NSPriorityNotificationCenter` delivers each notification to observers in ascending priority value: -20 is first, 10 (`FxGripExtensionDefaultPriority`) is the default, 20 is last. `reverse:YES` inverts the order. A post-block, when supplied, runs after each observer.

`FxGripExtensionBase` conforms to `NSNotificationObjectPriorityItem`. `-ncPriority:` returns `extDefaultPriority` for every notification name; an extension overrides it to reorder specific notifications. `FxGripParameterData` is the model: it answers -20 for `FxGripNotifyAPI_ParameterAddName`, -18 for `FxGripTileableEffectAddedToDocumentName`, and -15 for `FxGripTileableEffectFlushName` so its parameter mirror is current before other observers read it. The center queries `ncPriority:` at delivery-sort time, so priorities may change at runtime.

The effect reserves high-priority slots for its own bookkeeping block observers (`FxGripTileableEffect.m`):

- priority -18 → parameter capture (`FxGripNotifyAPI_ParameterAddPreName`, `FxGripNotifyAPI_ParameterAddName`, `FxGripNotifyAPI_ParameterRemoveName`).
- priority -17 → parameter reconstruction on `FxGripTileableEffectAddedToDocumentName`.
- priority -14 → parameter flush on `FxGripTileableEffectFlushName`.

Extension observers that must run after the parameter model is current use priorities greater than -14; observers that must precede parameter capture use values below -18.

`-initializeExtensions` also uses priority for load order: extensions are sorted by `ncPriority:FxGripTileableEffectLoadName` before `extLoadWithEffect:` runs, which fixes observer insertion order among equal-priority observers.

## Authoring an extension

1. Subclass `FxGripExtension` (or subclass `FxGripExtensionBase` and declare `FxGripExtension` conformance).
2. Implement only the optional `ext…:` selectors the extension needs. Observer registration is driven by `respondsToSelector:`, so unimplemented events cost nothing.
3. Override `-loadExtensions` in the effect subclass, call `super`, and append an instance:

```objc
- (NSMutableArray<id<FxGripExtension>> *)loadExtensions
{
    NSMutableArray<id<FxGripExtension>> *extensions = [super loadExtensions];
    [extensions addObject:[MyExtension.alloc init]];
    return extensions;
}
```

4. Read event data from `notification.userInfo` through the category accessors: `fxParameter` / `mutableFxParameter` and `fxResult` / `fxError` (`FxGripAPINotifications.h`), `fxEffectProperties` / `fxEffectParameters` / `fxCoder` (`FxGripTileableEffect+Notifications.h`), and the `kFxParameterProperty_…` accessors on the parameter dictionary (`NSDictionary+FxGripTileableEffect.h`).
5. Configure behavior on the instance before the effect joins a document:
    - `setExtActive:NO` → the extension registers no observers; the call is rejected once `addedToDocument` is set, because observers are registered at `extLoadWithEffect:` time.
    - `extIncludeWhenDisabled` → an inactive extension stays in the `extensions` dictionary and remains reachable by key.
    - `extIndividuate` → multiple instances of one class receive distinct keys (`MyExtension0`, `MyExtension1`, …).
    - `extDefaultPriority`, or an `ncPriority:` override → delivery order (see above).
6. Reach the extension later through `extensionForKey:`, `extensionForClass:`, or `extensionForProtocol:` (`FxGripTileableEffect+Extensions.h`), or through the effect's keyed subscript (`effect[@"MyExtension"]`). The stock extensions follow the convention of adding a convenience category on `FxGripTileableEffect` (for example `-[FxGripTileableEffect (I18N) i18n]`).

An extension reads its owning effect through `self.effect`, which `extLoadWithEffect:` assigns. `self.effect` is `nil` inside the extension's `-init`; defer any effect-dependent setup to `extLoadWithEffect:` (override it and call `super`, as `FxGripRegression.m` does) or to `extInit:`.

## Error round trip

Lifecycle notifications whose FxPlug entry points take an `NSError **` post a mutable userInfo. The convention:

- observer detects a failure → it stores an `NSError` with `userInfo.fxError = error` (the `NSMutableDictionary (FxGripAPINotificationUserInfo)` setter).
- effect method, after the post → reads `userInfo.fxError`, copies it to `*error`, and returns `NO`.
- API wrapper `…Pre`, after the post → reads `userInfo.fxError` and skips the host call when set.

`fxResult` complements `fxError` on the `…Pre` API notifications: setting it makes the wrapper return that value without calling the host, which lets an extension take over a get or set entirely (as `FxGripParameterData` can for flags).

The `parameterChanged`, `pluginState`, geometry, and render notifications all follow this round trip; `extensionsFlush` returns the collected `fxError` from the flush notification to its caller.
