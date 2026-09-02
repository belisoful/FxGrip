> **OBSOLETED by [Meta and Target-Preset Design.md](Meta%20and%20Target-Preset%20Design.md)**
> (`Information/Meta and Target-Preset Design.md`).
>
> See the new file for the current design. This file is only for reference.

---

# Meta and Target-Preset Design

Design and implementation record for two FxGrip subsystems: the instance meta/tag
subsystem (`FxGripMetaManager`) and the target-preset system on `FxGripTileableEffect`.
Class and file names use the current FxGrip names throughout. This is a point-in-time
engineering document. Line numbers in sections 1 and 2 reference the original single-file
implementation (commit `faec2ea`, 2026-07-20) this design is built from; that
implementation predates the current layout, where `FxGripTileableEffect` is split into
categories under `FxGrip/Utilities/`, so those line numbers do not map to the current
source. Sections 1 and 2 describe the original behavior, including latent bugs; section 3
lists the fixes the implementation applies. Later sections pin their own line numbers where
stated.

Revision 2026-07-27: the meta subsystem (sections 3.2–3.5, port steps 1–8) is ported and
live in the working tree. Section 3.6 is replaced: the target-preset engine and the
file-preset subsystem merge into one preset core on the tag API. Section 4 steps 9–11 are
replaced by steps 9–15. Sections 1, 2, 3.1–3.5, and 5 stand as written; superseded
statements carry an explicit `[Superseded]` marker. Line numbers inside section 3.6 and the
revised step list reference the working tree as of 2026-07-27.

Reference implementation (commit `faec2ea`, since superseded by the current source):

- `FxGripMetaManager.h` / `FxGripMetaManager.m`
- `FxGripTileableEffect.m` (`filterParameters:` 1416–1719, `parameterTargetPreset:parameterData:` 1806–1837, `setParameterTargetPreset:atTime:options:` 1840–1985, `completeParameterChanged:atTime:error:` 2141–2195, `meta` getter 1058–1080)

Current landing zones (status as of 2026-07-27):

- `FxGrip/FxGripAPIAccessing/FxGripParameterTagsAPI_v1.m` (live; delegates to `effect.meta`; gains the preset core per section 3.6)
- `FxGrip/FxGripAPIAccessing/FxGripDynamicParameterAPI_v4.m` (nine meta methods live at 314–373)
- `FxGrip/FxGripAPIAccessing/FxGripPreset.m`, `FxGripPresetsAPI_v1.m` (stubs; inventory in 3.6.7)
- `FxGrip/FxGripAPIAccessing/FxGripAPIAccessing.m` 60–92 in the header (commented `FxGripAPITransaction` with `commit:` → `saveMeta`; superseded by the `FxGripMeta` flush)
- `FxGrip/CustomParameter/FxGripMetaManager.{h,m}` (live; the ported manager of section 3.2)
- `FxGrip/Extensions/FxGripMeta.m` (live; registers the InstanceMeta parameter and seeds records per section 5)
- `FxGrip/Parameters/FxParameter.h` (per-parameter `tags` / `meta` properties)
- `FxGrip/Utilities/FxGripTileableEffect.{h,m}` (`meta` / `hasMeta` category live in `FxGripMeta.m` 255–272; posts `FxGripTileableEffectParameterChangedName`; `configurationForParameter:` at `.m` 619)
- `FxGrip/Extensions/FxGripFactory.m` / `FxGripFactoryParameters.m` (intend to consume target presets for the licensing toggle; `@todo` at `FxGripFactoryParameters.m` 1057)

---

## 1. Meta subsystem: original implementation

### 1.1 Class and storage model

`FxGripMetaManager : NSObject <NSSecureCoding, NSCopying, FxCustomDataClasses>` is the
value of a hidden Custom parameter (`kFxParameterId_InstanceMeta`). It is compiled MRC
(explicit `retain` / `[super dealloc]`). One instance exists per effect instance; the
`effect` back-pointer is `assign` (non-retaining) and is restored with `setEffect:` after
decoding.

Instance state:

| Ivar | Type | Content |
|---|---|---|
| `_data` | `NSMutableDictionary<NSString*, NSObject*>` | Root archive. Exactly two keys at init. |
| `__tags` | `NSMutableDictionary<NSString*, NSMutableArray<NSNumber*>*>` | Reverse index: tag string → array of parameter IDs. Aliases `_data[kFxMetaProperty_Tags]`. |
| `__parameters` | `NSMutableDictionary<NSNumber*, NSMutableDictionary<NSString*, id>*>` | Parameter store: `@(paramID)` → record. Aliases `_data[kFxMetaProperty_Parameters]`. |
| `unsaved` | `BOOL` | Dirty bit for deferred persistence. |
| `mMetaLock` | `NSRecursiveLock` | Recursive lock; exposed via `lock` / `lockWithinTime:` / `unlock`. |
| `_tags` | `NSArray` (synthesized backing of `tags`) | Cached `[__tags allKeys]`. |
| `_lastModified` | `CFAbsoluteTime` | Declared, auto-synthesized, never written. Only referenced from commented-out clock-change code (.m 233–243). Vestigial. |

Per-parameter record keys (`kFxMetaProperty_*`, FxGripMetaManager.h 19–50):

| Key macro | String | Value |
|---|---|---|
| `kFxMetaProperty_Tags` | `"tags"` | (root key) reverse index |
| `kFxMetaProperty_Parameters` | `"parameters"` | (root key) parameter store |
| `kFxMetaProperty_ParamId` | `"id"` | `NSNumber` (FxParameterId) |
| `kFxMetaProperty_ParamType` | `"type"` | `NSNumber` (FxParameterType) |
| `kFxMetaProperty_ParamFlags` | `"flags"` | `NSNumber` (FxParameterFlags, includes cache bits) |
| `kFxMetaProperty_ParamTags` | `"tags"` | per-param tag container (see 1.4 type bug) |
| `kFxMetaProperty_ParamMeta` | `"meta"` | `NSMutableDictionary<NSString*, id>` of user meta |
| `kFxMetaProperty_ParamTargetPreset` | `"targetpreset"` (= `kFxParameterProperty_TargetPreset`) | target-preset definition |
| `kFxMetaProperty_ResetValue` | `"resetvalue"` (= `kFxParameterProperty_ResetValue`) | reset value |
| `kFxMetaProperty_ParamCustomClass` | `"customClass"` | class name string |
| `kFxMetaProperty_ParamCustomClasses` | `"customClasses"` | `NSOrderedSet<NSString*>` copy |
| `kFxMetaProperty_ParamValue` | `"value"` | deferred value write (only while `CACHEDIRTY`) |
| `kFxMetaProperty_ParamValueTime` | `"valuetime"` | `NSFxTime` for the deferred value |
| `kFxMetaProperty_ParamTargetId` | `"id"` | declared for targets; never consumed |
| `kFxMetaProperty_ParamTargetNames` | `"names"` | see target-preset section |
| `kFxMetaProperty_ParamTargetValues` | `"values"` | see target-preset section |
| `kFxMetaProperty_ParamTargetMetaKey` | `"metakey"` | declared; never consumed |
| `kFxMetaProperty_ParamTargetMetaValues` | `"metavalues"` | declared; never consumed |

### 1.2 Coding, copying, equality

- `+supportsSecureCoding` → YES.
- `encodeWithCoder:` encodes `_data` with unkeyed `encodeObject:` (.m 107–110); `initWithCoder:` uses unkeyed `[aDecoder decodeObject]` plus manual `retain`, then re-aliases `__tags` / `__parameters` from the decoded root (.m 91–105). The effect pointer is not encoded; callers must `setEffect:` after decode.
- `+classesForParameter` (.m 131–155) is the secure-decode allow-list surfaced to the host through the effect's `classesForCustomParameterID:` (`FxGripTileableEffect.m` 246–250 returns `FxGripMetaManager` unioned with this set). The set: `NSMutableDictionary, NSDictionary, NSMutableArray, NSArray, NSMutableString, NSString, NSMutableSet, NSSet, NSMutableOrderedSet, NSOrderedSet, NSNumber, NSDecimalNumber, NSColor, NSMutableData, NSData, NSValue, NSURL, NSUUID, NSFxTime`. The instance method `classesForParameter` returns nil (.m 812–814).
- `copyWithZone:` → `initWithMeta:` → `[metaManager.data mutableCopyRecursive]` (BEFoundation deep copy), fresh lock, same (assign) effect.
- `isEqual:` compares `_data` only.
- `initWithObjects:forKeys:count:` accepts pre-built root content and re-aliases the two root keys; effect is left nil (.m 162–179).
- A minimal dictionary facade (`count`, `objectForKey:`, `keyEnumerator`, `setObject:forKey:`, `removeObjectForKey:`) operates on `_data` under the lock (.m 181–218). These are the only methods that consistently take the lock; see 1.7.

### 1.3 Parameter CRUD and flags

| Method | Behavior | Error contract |
|---|---|---|
| `addParameter:type:flags:` (.m 255) | Rejects only if a record exists AND has an `"id"` key ("can be preset if no Param ID is set": a record pre-seeded without `"id"` is adopted). Promotes non-dictionary or immutable records to `NSMutableDictionary`. Writes `id`, `type`, `flags`, and initializes `"tags"` and `"meta"` (both as `NSMutableDictionary`; see 1.4). Sets `unsaved`. | `NSLog` + return NO on duplicate. |
| `addParameter:customClass:flags:` (.m 288) | Calls the above with `FxParameterType_Custom`; stores `dataClass.className` under `"customClass"`; builds `"customClasses"` as an immutable copy of an `NSMutableOrderedSet` = {className} ∪ `classesForParameter.toStringsFromClasses` (if the class conforms to `FxCustomDataClasses`) ∪ any prior `parameterCustomClasses` on the record. | NO propagated from base add. |
| `removeParameter:` (.m 312) | Removes record; sets `unsaved`. Does NOT clean the `__tags` reverse index (stale IDs remain under tags). | `NSLog` + NO if absent. |
| `parameterData:` (.m 427) | Returns the live mutable record (not a copy), under lock. | nil if absent. |
| `parameterData:forKey:` (.m 436) | Record lookup then key lookup. | nil. |
| `parameterType:` (.m 444) | `"type"` as int. | `FxParameterType_None` if record or key absent (logged). |
| `parameterExists:` (.m 463) | Record non-nil. | — |
| `metaInstalled` (.m 245) | `parameterExists:kFxParameterId_InstanceMeta` — whether the meta parameter itself has a record. | — |
| `getParameterFlags:fromParameter:` (.m 336) | Reads `"flags"` as `longLongValue`. `*flags` untouched on failure. | `NSLog` + NO if record or key absent. |
| `setParameterFlags:toParameter:` (.m 365) | Unless `kFxParameterFlag_SAVING` is passed, ORs in `kFxParameterFlag_CACHE` (marks "flags changed, host write pending"). If `SAVING` is passed, strips it (one-shot bypass used when the API layer itself is persisting flags). Sets `unsaved`, writes `"flags"`. | `NSLog` + NO if record absent. |
| `addFlags:toParameter:` (.m 389) | get → OR → set only if any bit is newly set. Returns NO when nothing changed (success starts NO and is set only inside the change branch). | NO on get failure (logged). |
| `removeFlags:fromParameter:` (.m 407) | get → AND-NOT → set only if any bit clears. Also sets `unsaved` directly. Same no-change → NO convention. | NO on get failure. |

Flag constants (`FxGrip/Parameters/FxGripParameterFlags.h`): `kFxParameterFlag_CACHE`
(flags changed, host write pending), `kFxParameterFlag_CACHEDIRTY` (a deferred value write
is pending under `"value"` / `"valuetime"`), `kFxParameterFlag_SAVING` (one-shot bypass of
the CACHE marking). `RemoveTempFlags()` strips all three. These are FxGrip-internal bits
above the Apple flag range and must never reach the host.

### 1.4 Tag API

All tag methods fetch `pTags = [self parameterData:parameterID forKey:kFxMetaProperty_ParamTags]`
and treat it as `NSMutableArray`.

**Type bug:** `addParameter:type:flags:` initializes `"tags"` as `NSMutableDictionary`
(.m 279). Every tag method then sends `containsObject:` / `addObject:` / `removeObject:` /
`removeAllObjects` — array selectors that `NSMutableDictionary` does not implement (except
`removeAllObjects`). A freshly added parameter raises "unrecognized selector" on the first
`addTag:`. The legacy subsystem only functioned for records whose `"tags"` came from
elsewhere as an array. The port must standardize on `NSMutableArray`.

| Method | Behavior | Error contract |
|---|---|---|
| `tags` (.m 526) | Caches `[__tags allKeys]` into `_tags` on first call; never invalidated afterward (stale after add/remove). | — |
| `tagCount` (.m 534) | `__tags.count`. | — |
| `tagCount:` (.m 539) | Per-param container count. | −1 if container absent. |
| `parameterTags:` (.m 549) | `[pTags copy]`. | nil if container absent. |
| `parameter:hasTag:error:` (.m 558) | `containsObject:`. | NO + optional out-error if container absent. |
| `setTags:toParameter:` (.m 572) | **Bug:** calls `removeAllTags:` and returns nil; the supplied tags are never added. The intended behavior is remove-all then add each. | nil always. |
| `addTag:toParameter:` (.m 578) | If not present: append to `pTags`, create `__tags[tag]` array on demand, append `@(parameterID)`, set `unsaved`. Idempotent. | error object if container absent. |
| `removeTag:fromParameter:` (.m 601) | Remove from both sides; deletes `__tags[tag]` when its array empties; sets `unsaved`. | error object if container absent. |
| `removeAllTags:` (.m 623) | For each tag: remove pid from reverse index (deleting emptied entries), then `removeAllObjects` on `pTags`; `unsaved` set per removed tag. | error object if container absent. |
| `parametersWithTag:` (.m 646) | `[__tags[tag] copy]`. | nil if tag unknown. |

Error objects share one shape: domain `FxPlugErrorDomain`, code
`kFxError_ThirdPartyDeveloperStart + parameterID`, description
`"No Mutable Array for parameter (<id>) tags."` (the text is copy-pasted even into meta
methods; the port should correct the messages while keeping domain and code).

### 1.5 Meta API

All operate on the record's `"meta"` dictionary.

| Method | Behavior | Error contract |
|---|---|---|
| `metaCountFromParameter:` (.m 659) | count of `"meta"`. | −1 if record absent. |
| `getMeta:fromParameter:` (.m 668) | **Bug:** on success it returns `[paramData["meta"] copy]` — the meta dictionary — as the `NSError*` result, and never assigns the `meta` out-parameter. Intended: `*meta = copy; return nil`. | error object if record absent. |
| `setMeta:toParameter:` (.m 679) | Replaces `"meta"` with `[meta mutableCopy]` (nil coerced to `@{}`). Does NOT set `unsaved`. | error object if record absent. |
| `getMetaKeys:fromParameter:` (.m 694) | `*keys = allKeys`. | error if record absent; separate error if `keys` out-pointer is nil. |
| `removeAllMeta:` (.m 711) | `removeAllObjects` on `"meta"`. No `unsaved`. | error object if record absent. |
| `parameter:hasMetaKey:error:` (.m 724) | key presence. | NO + optional out-error if record absent. |
| `getMeta:forKey:fromParameter:` (.m 742) | `*value = meta[key]` when present; `value` out-pointer may be nil (existence check). | NO if record or key absent (no error object). |
| `setMeta:forKey:toParameter:` (.m 760) | `meta[key] = value`. No `unsaved`. | NO if record absent. |
| `removeMetaKey:fromParameter:` (.m 773) | Removes; returns whether the key existed. No `unsaved`. | NO if record absent. |

Inconsistency to resolve in the port: parameter/flag/tag mutations mark `unsaved`; meta
value mutations never do, so meta-only edits are not persisted by `saveMeta`. The port
marks the manager dirty on every mutation.

### 1.6 Persistence: `unsaved` / `saveMeta` / deferred writes

`saveMeta` (.m 478–515), under lock, when `unsaved`:

1. Clears `unsaved`.
2. For each record: `flags = paramData.parameterFlags` (NSDictionary accessor; see the
   `isParameterDictionary` caveat in 2.1 — for records lacking `"name"` this returns
   `kFxParameterFlag_INVALID`).
3. If `flags & kFxParameterFlag_CACHEDIRTY`: **bug** — `flags &= kFxParameterFlag_CACHEDIRTY`
   keeps only that bit instead of clearing it (`&= ~` intended), which also guarantees the
   subsequent CACHE branch never runs for this record. Pops `"value"` / `"valuetime"`; calls
   `[FxGripPreset setParameterValue:newValue toParameter:pid atTime:newValueTime.time withAPI:paramSetAPIv5]`
   only when both value and time exist (a value without a time is silently dropped).
4. If `flags & kFxParameterFlag_CACHE`: same inversion **bug** (`flags &= kFxParameterFlag_CACHE`),
   then `[paramSetAPIv5 setParameterFlags:flags toParameter:pid]` — which writes a flags
   word containing only the internal CACHE bit to the host, destroying the parameter's real
   flags. Intended: clear the temp bits and write the remaining real flags.
5. `[paramSetAPIv5 setCustomParameterValue:self toParameter:kFxParameterId_InstanceMeta atTime:kCMTimeZero]`
   persists the whole manager.
6. Returns YES unconditionally.

Intended flush point in the new architecture: the commented `FxGripAPITransaction`
(`FxGripAPIAccessing.h` 112–135, `.m` 60–92) whose `commit:` calls
`[_apiManager.effect.meta saveMeta]` when `effect.hasMeta`, then ends the transaction.

`setUnsaved:` is a raw setter used by the API layer after host-driven loads.

### 1.7 Locking

`lock` (always YES), `lockWithinTime:` (`tryTime <= 0` → `tryLock`, else
`lockBeforeDate:`), `unlock` — all on the `NSRecursiveLock`. Coverage is inconsistent:
CRUD/flags/facade methods lock; every tag and meta method mutates `pTags` / `__tags` /
`"meta"` outside the lock (only the inner `parameterData:` call locks). The port locks the
full critical section of every public method and keeps the public tryable-lock triple for
multi-call atomicity by callers.

### 1.8 Effect-side attachment (legacy)

- `meta` getter (`FxGripTileableEffect.m` 1058–1080): `@synchronized(self)`; lazily reads
  the custom parameter through `paramGetAPIv6_Raw` (bypassing the FxGrip wrapper layer to
  avoid recursion), `setEffect:self` on success, else `initWithEffect:self`.
- `hasMeta` (1354–1357) → `self.properties.pluginManageMeta`, i.e. plist key
  `kProPlugPlugInX_ManagedMetaProperty` = `"manageMeta"`. The legacy comment claims
  "Default YES"; the shared accessor (`NSDictionary+FxTileableEffect.m` 230–238) returns NO
  when the key is absent. The port keeps the accessor's behavior (opt-in).
- `hasLoadedMeta` (1359–1362) → `_addedToDocument && hasMeta`.
- `classesForCustomParameterID:` special-cases `kFxParameterId_InstanceMeta` (246–250).
- The block that would seed meta records from the parameter configuration at creation
  (transfer of `transferParameterProperties` = {`Name` (DEBUG only), `selector`,
  `resetvalue`} plus every key with prefix `kFxParameterProperty_TargetPrefix` = `"target"`,
  and merge of the config's `"meta"` dictionary) exists only as commented code
  (1775–1788). It is the specification for how records acquire `"targetpreset"`,
  `"resetvalue"`, and initial meta.
- `kFxParameterId_InstanceMeta` has no active definition. The legacy file-header comment
  says 9998 ("parameter 9998: Plugin Data"); the commented define in
  `Parameters/FxGripParameter.h` 29 says 9997. Both collide with active ids (see 3.3).

---

## 2. Target-preset system: original implementation

A Menu or Toggle parameter can carry a target-preset definition under the key
`kFxParameterProperty_TargetPreset` = `"targetpreset"` (`FxGripTypes.h` 140). The
definition is one of:

- `NSString` — a tag naming an entry in the plugin plist presets dictionary
  (`self.properties.pluginPresets`, plist key `kProPlugPlugInX_PresetsProperty` = `"presets"`);
- `NSArray<NSDictionary*>` — element index = menu index / toggle value;
- `NSDictionary` — keys are numeric indices (`@(i)` or `"i"` string), with optional
  `"default"` fallback entry.

Each per-index preset dictionary may contain (`FxGripTypes.h` 141–144):

| Key | String | Payload |
|---|---|---|
| `kFxParameterProperty_TargetPresetNames` | `"names"` | `{pidString: newName}` |
| `kFxParameterProperty_TargetPresetFlags` | `"flags"` | `{pidString: flagSpec}` |
| `kFxParameterProperty_TargetPresetTags` | `"tags"` | `{pidString: tagSpec}` |
| `kFxParameterProperty_TargetPresetValues` | `"values"` | `{pidString: value}` |

`flagSpec` / `tagSpec` is an `NSArray<NSString*>` or a single string split by
`splitByHumanDividers` (whitespace, newline, `.`, `,`, `;` — `FxGripPluginInfo.separatorSet`).

**Flag/tag prefix semantics** (identical in all three implementations, e.g.
`FxGripTileableEffect.m` 1589–1605, 1936–1955; partial read-side already ported at
`NSDictionary+FxTileableEffect.m` 66–93):

- leading `"-"` → remove the named item (strip one character);
- leading `"+"` → add (strip one character);
- no prefix → add.
- Flag names map through `+[FxGripParameterUtility convertFlag:]`
  (`FxGripParameterUtility.m` 150–160): dictionary lookup of the lowercase flag string
  (`"hidden"`, `"disabled"`, `"notanimatable"`, …); unknown names return
  `kFxParameterFlag_DEFAULT` (0), so an unknown flag is a silent no-op on add and — note —
  `result &= ~0` is also a no-op on remove.

Working example (`Extensions/FxGripDebugMenu.m` 63–74): the debug-activator Toggle carries
`targetpreset: @[ {flags: {@"9997": "+hidden"}}, {flags: {@"9997": "-hidden"}} ]` —
toggle off hides the debug menu, toggle on reveals it.

Options mask (`FxGripTileableEffect.h` 93–99):
`PresetAll = -1`, `PresetName = 1<<0`, `PresetFlags = 1<<1`, `PresetTags = 1<<2`,
`PresetValues = 1<<3`.

### 2.1 Resolution: `parameterTargetPreset:parameterData:` (1806–1837)

```
paramData := hasMeta ? [self.meta parameterData:paramID] : nil   // config fallback commented out
if paramData == nil → return nil (out-param untouched)
*outParamData := paramData
targetPreset := paramData.parameterTargetPreset                   // "targetpreset" key
if targetPreset is NSString:
    targetPreset := self.properties.pluginPresets[tag]            // plist "presets"[tag]
    if nil → NSLog ERROR, return nil
return targetPreset
```

Caveat that makes the runtime path inert in the legacy snapshot: the accessors
`parameterTargetPreset`, `parameterType`, `parameterFlags` on `NSDictionary`
(`NSDictionary+FxTileableEffect.m`, macro `isParameterDictionary`, line 120) require the
dictionary to contain `"id"`, `"type"`, AND `"name"`. Meta records never receive `"name"`
in release builds (the transfer list includes `Name` only `#if DEBUG`, and the transfer
block itself is commented out), so resolution returns nil/None. The port must either not
route these reads through `isParameterDictionary`-guarded accessors or guarantee the record
shape satisfies them.

### 2.2 Runtime application: `setParameterTargetPreset:atTime:options:` (1840–1985)

Faithful stepwise pseudocode:

```
1  targetPreset := [self parameterTargetPreset:paramID parameterData:&paramData]
2  if paramData == nil → return NO
3  type := paramData.parameterType
4  if type is not Menu and not Toggle → return YES                 // silent no-op
5  acquire paramGetAPIv6, paramSetAPIv6, dynamicParamAPIv4; any nil → return NO
6  if Menu:   getIntValue:&intValue fromParameter:paramID atTime:time; fail → NO
   if Toggle: getBoolValue:&boolValue …; fail → NO; intValue := (int)boolValue
7  if targetPreset == nil or count == 0 → return YES
8  preset := [targetPreset objectForIndex:intValue]
      // NSArray: raw indexed subscript — an out-of-range menu value raises
      //   NSRangeException (NSDictionary+FxTileableEffect.m 60–63). Port must bounds-check.
      // NSDictionary: tries @(intValue) then "intValue" string (ibid. 123–129).
9  if preset == nil and targetPreset is NSDictionary:
      preset := targetPreset[@"default"]
10 if preset == nil → return YES
11 if (options & PresetName) and preset["names"] != nil:
      for pidStr in names:
          err := [dynamicParamAPIv4 setParameter:pidStr.intValue name:names[pidStr]]
          if err → NSLog ERROR, continue                            // per-entry, non-fatal
      // The method returns NSError; non-nil means failure. The legacy code reads as an
      // inverted if but is correct for an NSError return.
12 if (options & PresetFlags) and preset["flags"] != nil:
      for pidStr in flags:
          spec := flags[pidStr]; if NSString → splitByHumanDividers
          if ![paramGetAPIv6 getParameterFlags:&paramFlags fromParameter:pid] → log, continue
          changed := NO
          for flagString in spec:
              parse +/- prefix; bit := [FxGripParameterUtility convertFlag:name]
              add  and bit not set → set bit,  changed := YES
              remove and bit set   → clear bit, changed := YES
          if changed and ![paramSetAPIv6 setParameterFlags:paramFlags toParameter:pid] → log, continue
13 // "tags", "values", min/max sections: comment placeholders only (1967–1975);
   // never implemented on the runtime path. Their semantics exist only on the
   // creation-time path (2.3).
14 return YES
```

Ordering constraint carried in comments (1896, 2186–2188): setting a parameter's name and
then reading a String parameter's value glitches in Final Cut Pro. Names must therefore be
applied last, after all value work. The legacy call sites split this: value-affecting
options during the change, `PresetName` at the end of `completeParameterChanged:` (2174).

### 2.3 Creation-time application: `filterParameters:` (1416–1719)

Runs while building the parameter list, before any parameter is created. After flattening
groups into `tParamList` and building `paramDispatch` (`@(pid)` → mutable config dict),
for each Menu/Toggle parameter with a resolvable target preset:

1. `defaultValue` := the parameter's `"default"` int (0 if absent);
   `preset := [targetPreset objectForIndex:defaultValue]`; absent → skip (no `"default"`
   fallback on this path).
2. `"names"`: `paramDispatch[pid]["name"] = newName` (log + skip unknown pid).
3. `"flags"`: mutate `paramDispatch[pid].parameterFlagsArray` (the flag-string array) with
   the +/- prefix algorithm on strings, not bits.
4. `"tags"`: same +/- algorithm on `paramDispatch[pid]["tags"]`, creating the array on
   demand — the only place preset tags are applied anywhere in the legacy code.
5. `"values"`: switch on the target's `parameterType`:
   - RGBA: copy `"alpha"` if present, then fall through to RGB;
   - RGB: copy `"red"` / `"green"` / `"blue"` individually;
   - Point: copy `"x"` / `"y"`;
   - Custom: recursive-merge the value dictionary into the target's `"default"` dictionary
     (`mergeEntriesFromDictionary:`);
   - default: `paramDispatch[pid]["default"] = value`.

This guarantees the initial UI state matches the default menu/toggle selection.

### 2.4 Legacy call sites

- `completeParameterChanged:atTime:error:` 2172–2182: `PresetName` pass, then applies
  `paramData.parameterResetValue` through `setParameter:value:atTime:` (itself fully
  commented out, 1998–2061). Note: the method nils `parameter` at 2159 and returns NO at
  2161 before reaching this block — the runtime path is dead code in the legacy snapshot
  and this document reconstructs the intended behavior.
- `manageDebuggerController:` 2317–2319: `PresetFlags` after toggling the debug activator.
- 2089 (commented): intended `PresetAll ^ PresetName` from `handleParameterChanged:`.
- `FxParameter.m` 71/98 and `FxGripParameter.m` 63/90 carry the same two calls as comments
  inside `startChangedTime:` / `endChangedTime:` — the intended per-parameter hook points
  in the new model.

---

## 3. Migration design

### 3.1 Architectural fit

The new architecture already covers part of the legacy manager:

- `Extensions/FxGripParameterData.m` (active) captures `FxNotifyAPI_ParameterAdd` /
  `Remove` / `SetFlags` / `SetMenu` notifications, stores per-parameter records
  (`type`, `flags`, parent, menu items, selector) keyed by pid, persists them as the custom
  parameter `kFxParameterId_ParameterData` (9998), and implements the deferred-write
  pattern (`isCacheDirty` + `extFlush:` low-priority handler). This supersedes the
  `{id, type, flags}` portion of `FxGripMetaManager` and the `CACHE` flag mechanics.
- `FxParameter` objects (`Parameters/FxParameter.h` 225–226) expose per-parameter `tags`
  and `meta` containers seeded from the configuration dictionary.

The port therefore does not resurrect the monolithic manager as the source of truth for
types and flags. What remains to port: per-parameter tags with the reverse index, per-
parameter meta values, secure-coded persistence, the 23 stubbed API delegations, and the
target-preset engine.

### 3.2 FxGripMetaManager (new class)

Files: `FxGrip/CustomParameter/FxGripMetaManager.h` / `.m` (custom-parameter data classes
live in `CustomParameter/` beside `FxGripDictionary` and `FxGripInterpolatingDictionary`).
Public header: mark Public, add to `FxGrip.h`.

```objc
/// Introduced in FxGrip 1.0.
@interface FxGripMetaManager : NSObject <NSSecureCoding, NSCopying, FxCustomDataClasses>

@property (readonly, weak, nullable) FxGripTileableEffect *effect;
@property (readonly) BOOL unsaved;

- (nonnull instancetype)initWithEffect:(FxGripTileableEffect *_Nullable)effect;
- (void)setEffect:(FxGripTileableEffect *_Nonnull)effect;

// Record management (records carry only "id", "tags", "meta"; type/flags live in
// FxGripParameterData)
- (BOOL)addParameter:(FxParameterId)parameterID;
- (BOOL)removeParameter:(FxParameterId)parameterID;
- (BOOL)parameterExists:(FxParameterId)parameterID;
- (NSMutableDictionary *_Nullable)parameterData:(FxParameterId)parameterID;

// Tag API — signatures identical to <FxParameterTagsAPI_v1>
- (NSArray<NSString*> *_Nonnull)tags;
- (SInt32)tagCount;
- (SInt32)tagCount:(FxParameterId)parameterID;
- (NSArray<NSString*> *_Nullable)parameterTags:(FxParameterId)parameterID;
- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString *_Nullable)tag
            error:(NSError *_Nullable *_Nullable)error;
- (NSError *_Nullable)setTags:(NSArray<NSString*> *_Nonnull)tags toParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)addTag:(NSString *_Nullable)tag toParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)removeTag:(NSString *_Nullable)tag fromParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)removeAllTags:(FxParameterId)parameterID;
- (NSArray<NSNumber*> *_Nullable)parametersWithTag:(NSString *_Nullable)tag;

// Meta API — matches the FxGripDynamicParameterAPI_v4 header set
- (SInt32)metaCountFromParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)getMeta:(NSDictionary *_Nullable *_Nonnull)meta fromParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)setMeta:(NSDictionary *_Nonnull)meta toParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)getMetaKeys:(NSArray *_Nullable *_Nonnull)keys fromParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)removeAllMeta:(FxParameterId)parameterID;
- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString *_Nonnull)key
            error:(NSError *_Nullable *_Nullable)error;
- (BOOL)getMeta:(NSObject<NSSecureCoding,NSCopying> *_Nullable *_Nonnull)value
         forKey:(NSString *_Nullable)key fromParameter:(FxParameterId)parameterID;
- (BOOL)setMeta:(NSObject<NSSecureCoding,NSCopying> *_Nonnull)value
         forKey:(NSString *_Nullable)key toParameter:(FxParameterId)parameterID;
- (BOOL)removeMetaKey:(NSString *_Nullable)key fromParameter:(FxParameterId)parameterID;

// Persistence
- (BOOL)saveMeta;
- (void)setUnsaved:(BOOL)unsavedValue;

// Locking
- (BOOL)lock;
- (BOOL)lockWithinTime:(double)tryTime;
- (void)unlock;
@end
```

Legacy semantics kept:

- Root shape `{"tags": reverse-index, "parameters": {pid: record}}` and the
  `kFxMetaProperty_*` key strings — preserves archive shape for round-trips.
- Error convention: `FxPlugErrorDomain`, code `kFxError_ThirdPartyDeveloperStart + parameterID`.
- Sentinels: `tagCount:` / `metaCountFromParameter:` return −1 for a missing record.
- Live (non-copied) `parameterData:`; copied returns from `parameterTags:` /
  `parametersWithTag:` / `getMeta:fromParameter:`.
- `addTag:` idempotence; reverse-index entry deletion when emptied.
- `+classesForParameter` allow-list, same class set.
- Public recursive lock triple.
- `setEffect:` after decode; effect never encoded.

Legacy semantics fixed (deliberate behavior changes, all latent bugs):

- `"tags"` container is `NSMutableArray` (order-preserving), matching every consumer.
- `setTags:toParameter:` removes all then adds each supplied tag.
- `getMeta:fromParameter:` assigns the out-parameter and returns nil on success.
- Every mutation (including meta value writes) marks `unsaved`.
- `removeParameter:` also scrubs the pid from the reverse index.
- `tags` cache invalidates on any tag mutation (or is dropped in favor of computing
  `allKeys` per call).
- Keyed secure coding: `encodeObject:forKey:@"data"` /
  `decodeObjectOfClasses:forKey:` with the `classesForParameter` set.
- Full lock coverage on every public method.

Legacy semantics dropped:

- `"type"`, `"flags"`, `"customClass"`, `"customClasses"` record keys and the
  `getParameterFlags:` / `setParameterFlags:` / `addFlags:` / `removeFlags:` family —
  `FxGripParameterData` and the notification pipeline own these. `addParameter:type:flags:`
  and `addParameter:customClass:flags:` are not ported.
- `kFxParameterFlag_CACHE` / `SAVING` bookkeeping inside the manager — the flag write path
  already flows through `FxNotifyAPI_ParameterSetFlags` and `FxGripParameterData`
  (`RemoveTempFlags` applied at `FxGripParameterData.m` 222).
- Deferred `"value"` / `"valuetime"` writes and the `FxGripPreset setParameterValue:` call
  in `saveMeta`. If deferred value writes return, they belong in a transaction object, not
  in per-record cache bits. `saveMeta` reduces to: if `unsaved`, clear it and
  `setCustomParameterValue:self toParameter:kFxParameterId_InstanceMeta atTime:kCMTimeZero`
  via `effect.apiManager.paramSetAPIv5`.
- The `NSDictionary` facade (`objectForKey:` etc.) and `initWithObjects:forKeys:count:` —
  no consumer exists.
- `lastModified` — never functional.

### 3.3 Constants

Move to `FxGrip/FxGripTypes.h`:

- `kFxMetaProperty_Tags` `"tags"`, `kFxMetaProperty_Parameters` `"parameters"`,
  `kFxMetaProperty_ParamId` `"id"`, `kFxMetaProperty_ParamTags` `"tags"`,
  `kFxMetaProperty_ParamMeta` `"meta"`. The aliases of `kFxParameterProperty_*`
  (`targetpreset`, `resetvalue`, `customClass(es)`) are not re-declared; consumers use the
  `kFxParameterProperty_*` names directly. `"metakey"` / `"metavalues"` / target `"id"`
  are not ported (never consumed); reintroduce with the feature if it is ever built.
- `#define kFxParameterId_InstanceMeta (9995)` — new id. 9996/9997 belong to the debug
  activator/menu, 9998 to `FxGripParameterData`, 9999 to Apple. The legacy ids (9998 per
  the file comment, 9997 per the commented define) are both taken in the new layout.
  Documents saved by legacy builds stored the archive at 9998; FxGrip has not
  shipped, so no migration shim is provided. `kFxParameterId_Maximum` in
  `FxGripDynamicParameterAPI_v4.h` (9998) already excludes user parameters from this range.
- `FxGripPresetOptions`, prefixed members:
  `FxGripPresetAll = NSUIntegerMax`, `FxGripPresetNames = 1<<0`, `FxGripPresetFlags = 1<<1`,
  `FxGripPresetTags = 1<<2`, `FxGripPresetValues = 1<<3`.

### 3.4 Effect attachment: `meta` / `hasMeta`

Follow the `FxGripParameterData` pattern exactly (extension + accessor category in the
same file pair). Complete `Extensions/FxGripMeta.{h,m}` and return it to the build:

- `FxGripMeta : FxGripExtension` owns the `FxGripMetaManager`.
- `extAddParameters:` registers the InstanceMeta parameter (already written; converts to
  the `notification.userInfo.fxEffectParameters` form used by `FxGripParameterData.m`
  149–160; id `kFxParameterId_InstanceMeta`; flags
  `DONT_DISPLAY, HIDDEN, NOT_ANIMATABLE, PRESETNOMETA, NO_DEBUG, NO_STATE`).
- `extAddedToDocument:` loads the manager with
  `getCustomParameterValue:fromParameter:kFxParameterId_InstanceMeta` through
  `paramGetAPIv6` (the wrapper is safe here; the legacy `_Raw` bypass guarded against the
  original wrapper's own meta recursion, which no longer exists), calls `setEffect:`, and
  falls back to a fresh manager.
- `extAPIParameterAdd:` seeds a record for the new pid and transfers configuration state:
  the config dict's `"tags"` array and `"meta"` dictionary (this replaces the commented
  legacy transfer at `FxGripTileableEffect.m` 1775–1788; `"targetpreset"` and
  `"resetvalue"` stay readable from `__configParameters` / `FxParameter` and are not
  duplicated into the manager).
- `extAPIParameterRemove:` removes the record.
- `extFlush:` (low `ncPriority`, mirroring `FxGripParameterData.m` 132–146) calls
  `saveMeta` — this is the ported flush point that the commented
  `FxGripAPITransaction.commit:` described.
- Accessors, declared in `FxGripMeta.h`, implemented beside the extension:

```objc
@interface FxGripTileableEffect (Meta)
@property (readonly, nullable) FxGripMetaManager *meta;   // extension's manager
@property (readonly) BOOL hasMeta;                        // extension loaded and active
- (nonnull FxGripMeta *)newMetaExtension;
@end
```

`hasMeta` is `[self extensionForClass:FxGripMeta.class] != nil`; extension activation is
driven by the plist `manageMeta` boolean through the standard `FxGripExtension` activation
path, keeping the opt-in default.

### 3.5 API delegation (the 23 stubs)

`FxGripParameterTagsAPI_v1.m` — uncomment the prepared bodies: each method guards with the
existing `hasMeta(returnValue)` macro (extend it to check `self.effect.hasMeta`, not just
`self.effect`) and forwards to `self.effect.meta`. Guard-failure returns as already stubbed:
`tags` → nil, `tagCount` → 0, `tagCount:` → −1, `parameterTags:` → nil,
`parameter:hasTag:error:` → NO + error object, the four `NSError*` mutators → error object,
`parametersWithTag:` → nil (replace the stub's `@[]` for consistency with the manager).

`FxGripDynamicParameterAPI_v4.m` 308–378 — implement exactly the nine methods declared in
the header (`metaCountFromParameter:`, `getMeta:fromParameter:`, `setMeta:toParameter:`,
`getMetaKeys:fromParameter:`, `removeAllMeta:`, `parameter:hasMetaKey:error:`,
`getMeta:forKey:fromParameter:`, `setMeta:forKey:toParameter:`, `removeMetaKey:…`) as
forwards to `self.effect.meta`. Delete the four stub-only orphans
(`hasMeta:fromParameter:`, `parameterMetaCount:`, `removeMeta:fromParameter:`,
`getMetaKeys:forPreset:fromParameter:`) — `forPreset:` belongs to the separate
`FxGripPresetsAPI_v1` file-preset subsystem, which is out of scope here. Fix the two stub
signatures whose parameter types drifted from the header
(`setMeta:(id<...>*)value` → `(id<...>)value`; `error:(NSError*)` → `(NSError**)`).

`FxGripPreset.m` / `FxGripPresetsAPI_v1.m` remain a separate port (file-based plugin
presets). The only coupling removed by this design is `saveMeta`'s call into
`FxGripPreset setParameterValue:…`, which is dropped with the deferred-value mechanism.

`[Superseded 2026-07-27]` The paragraph above treats the file-preset subsystem as separate
and out of scope. Section 3.6 merges target presets and file presets into one core on the
tag API and reintroduces `getMetaKeys:forPreset:fromParameter:` there (3.6.4). The
deletion of the four `FxGripDynamicParameterAPI_v4` orphan stubs stands.

### 3.6 Unified preset core on the tag API (replaces the 2026-07-20 category design)

This section replaces the earlier `FxGripTileableEffect+TargetPresets` category proposal.
Line numbers reference the working tree as of 2026-07-27.

#### 3.6.1 Decision and rationale

Target presets (section 2) and the file-preset subsystem (`FxGripPreset`,
`FxGripPresetsAPI_v1`) are one system. The shared preset core lands on the tag API: the
`FxParameterTagsAPI_v1` protocol (`FxGripAPIAccessing/FxParameterTagsAPI_v1.h`) and its
implementation `FxGripParameterTagsAPI_v1`. Tags do double duty: a tag addresses a preset
definition, and a tag selects the parameters a preset applies to. Evidence:

- Both subsystems resolve definitions from the same tag-addressed table. Target-preset
  resolution reads `self.properties.pluginPresets[tag]`
  (`FxGripTileableEffect.m` 1823–1835; plist key `kProPlugPlugInX_PresetsProperty` =
  `"presets"`, accessor `NSDictionary+FxTileableEffect.m` 179–183).
  `FxGripPresetsAPI_v1 +pluginPresetsForTag:` is documented "get plist presets"
  (`FxGripPresetsAPI_v1.h` 90–91). Same table, same tag addressing.
- `kFxParameterPreset_IgnoreTagBoundary` ("ignores if a parameter doesn't need the preset
  tag to set its value", `FxGripPresetsAPI_v1.h` 21–22) defines the default boundary: a
  preset's per-parameter payload applies to a parameter only when the parameter carries
  the preset's tag. The membership query is `parametersWithTag:`, a tag-API method.
- `FxGripPreset` carries `parameterValues` / `parameterMeta` / `parameterTags`
  (`FxGripPreset.h` 44–46). Target presets carry `names` / `flags` / `tags` / `values`
  (`FxGripTypes.h` 141–145, gated by `FxGripPresetOptions`, `FxGripTypes.h` 162–168).
  The section sets overlap on tags and values; the core supports the union
  {names, flags, tags, values, meta}.
- `kFxParameterFlag_PRESETNOMETA` / `kFxParameterFlag_PRESETNOTAGS`
  (`FxGripParameterFlags.h` 82–83) are per-parameter opt-outs from preset meta and tag
  handling; they apply identically to capture and application in both subsystems.
- `+[FxGripPreset setParameterValue:toParameter:atTime:withAPI:]` (`FxGripPreset.h` 63)
  is the one typed apply primitive. The original deferred-value path (`FxGripMetaManager.m`
  499) already called this primitive, so `FxGripPreset` is its only concrete home.
- `getMetaKeys:forPreset:fromParameter:`, deleted from `FxGripDynamicParameterAPI_v4` as
  an orphan during the meta port, is a preset-core method under the merged design (3.6.4)
  and survives as a stub at `FxGripPreset.m` 44.

`FxParameterTagsAPI_v1` gains the preset methods in place. FxGrip has not shipped, so
extending v1 does not violate the versioned-API rule; after the first release the surface
freezes and later additions require a v2.

#### 3.6.2 Duplicate protocol resolution

Two headers declare `@protocol FxParameterTagsAPI_v1` under the same include guard
`FxParameterTagsAPI_v1_h`:

- `FxGrip/FxGripAPIAccessing/FxParameterTagsAPI_v1.h` — a Public header (project public
  headers list), imported by `FxGripParameterTagsAPI_v1.h`, `FxGripTimingAPI_v4.h`,
  `FxGripAPIAccessing.h`/`.m`, and `FxGripTests/FxGripMetaTests.m`. This copy survives.
- `FxGrip/Utilities/FxGripTagAPI.h` — an identical body minus the `FxGripTypes.h` import,
  with zero importers and no public-header entry. The shared guard keeps it inert in any
  translation unit that includes both. Delete it before extending the protocol so the two
  copies cannot diverge.

#### 3.6.3 Canonical preset shape

A preset definition is an `NSDictionary` of up to five sections. Each section maps a
parameter-ID string to a payload:

| Section key | Constant | Payload |
|---|---|---|
| `"names"` | `kFxParameterProperty_TargetPresetNames` | new display name |
| `"flags"` | `kFxParameterProperty_TargetPresetFlags` | flagSpec (array or divider string, `+`/`-` prefixes) |
| `"tags"` | `kFxParameterProperty_TargetPresetTags` | tagSpec (same parsing) |
| `"values"` | `kFxParameterProperty_TargetPresetValues` | typed value (section 2.3 step 5 shapes) |
| `"meta"` | `kFxParameterProperty_TargetPresetMeta` (new define) | `{metaKey: value}` |

`FxGripPresetOptions` gains `FxGripPresetMeta = 1 << 4`; `FxGripPresetAll` continues to
cover every section. `FxParameterPresetFlags` (`kFxParameterPreset_Ignore*`,
`FxGripPresetsAPI_v1.h` 15–26) stays the file-layer modifier set; the mapping is:

- `kFxParameterPreset_IgnoreMetaData` → the caller clears `FxGripPresetMeta`
- `kFxParameterPreset_IgnoreTagBoundary` → the core disables the tag boundary (3.6.4)
- `kFxParameterPreset_IgnoreCompatibility` → the file layer skips `compatiblePreset:`

`FxGripPreset` gains `- (NSDictionary *_Nonnull)presetSections;` mapping
`parameterValues` → `"values"`, `parameterTags` → `"tags"`, `parameterMeta` → `"meta"`, so
a file preset feeds the same core as a target preset.

#### 3.6.4 Core surface (protocol `FxParameterTagsAPI_v1`, class `FxGripParameterTagsAPI_v1`)

```objc
// Definition resolution by tag. Reads pluginProperties "presets"[tag] now; the file
// layer (3.6.7) adds user/plugin .fxpreset lookups behind the same method.
- (id _Nullable)presetDefinitionForTag:(NSString *_Nonnull)tag;

// Target-preset resolution for one parameter: instance record first (section 5),
// configuration fallback, string definitions resolved through presetDefinitionForTag:.
- (id _Nullable)targetPresetForParameter:(FxParameterId)parameterID
                                  record:(NSDictionary *_Nullable *_Nullable)record;

// The shared application core.
- (NSError *_Nullable)applyPreset:(NSDictionary *_Nonnull)preset
                           atTime:(CMTime)time
                          options:(FxGripPresetOptions)options
                      presetFlags:(FxParameterPresetFlags)presetFlags
                              tag:(NSString *_Nullable)tag;

// The target-preset trigger entry (3.6.5).
- (BOOL)applyTargetPresetForParameter:(FxParameterId)parameterID
                               atTime:(CMTime)time
                              options:(FxGripPresetOptions)options;

// Reintroduced from the deleted FxGripDynamicParameterAPI_v4 orphan: the meta keys the
// tag-addressed definition carries for one parameter (the resolved definition's "meta"
// section for that ID).
- (NSError *_Nullable)getMetaKeys:(NSArray<NSString*> *_Nullable *_Nonnull)keys
                        forPreset:(NSString *_Nonnull)tag
                    fromParameter:(FxParameterId)parameterID;
```

Resolution, `targetPresetForParameter:record:`:

```
r := effect.hasMeta ? [effect.meta parameterData:pid] : nil
r == nil → r := [effect configurationForParameter:pid]        // FxGripTileableEffect.m 619
r == nil → return nil
record out-parameter := r
def := r[kFxParameterProperty_TargetPreset]                    // "targetpreset"
def is NSString → def := [self presetDefinitionForTag:def]; nil → log, return nil
return def
```

The core reads `r["targetpreset"]` directly and does not route through the
`isParameterDictionary`-guarded accessors, which resolves the section 2.1 caveat (records
lack `"name"`). The instance-record-first order implements section 5.

Application, `applyPreset:atTime:options:presetFlags:tag:`. Section order within one call
is fixed: values, flags, tags, meta, names (names last per the 2.2 ordering constraint).
Each step runs only when its option bit is set and its section is present:

- `FxGripPresetValues` + `"values"` → for each ID passing the tag boundary:
  `+[FxGripPreset setParameterValue:value toParameter:pid atTime:time withAPI:paramSetAPIv5]`.
  The primitive dispatches on parameter type, mirroring section 2.3 step 5: RGBA copies
  `"alpha"` and falls through to the RGB channels; Point copies `"x"` / `"y"`; Custom
  recursive-merges the dictionary into the current value; every other type sets the value
  directly.
- `FxGripPresetFlags` + `"flags"` → per ID: read the stored flag word
  (`[effect.parameterData storedFlags:pid]`, `FxGripParameterData.h` 37, which carries the
  FxGrip-internal bits), parse the `+`/`-` flagSpec, skip unknown flag names
  (`convertFlag:` returning 0), write through `paramSetAPIv6 setParameterFlags:` only when
  bits change.
- `FxGripPresetTags` + `"tags"` → per ID whose flags lack `PRESETNOTAGS`: `+`/`-` parsing
  into `[effect.meta addTag:toParameter:]` / `removeTag:fromParameter:`.
- `FxGripPresetMeta` + `"meta"` → per ID passing the tag boundary and whose flags lack
  `PRESETNOMETA`: `[effect.meta setMeta:forKey:toParameter:]` per entry.
- `FxGripPresetNames` + `"names"` → per ID: `[dynamicParamAPIv4 setParameter:name:]`.

Tag boundary (decided, 3.6.9-3): the boundary keys off the definition's SOURCE, not the
section. Every section addresses parameters by explicit ID; the boundary is a safety
filter for ID lists that may have drifted, so it applies where the ID list is untrusted.

- source is the plist `"presets"` table or the instance record (rigging) → bypass the
  boundary for all five sections. These IDs ship with the plugin and are current by
  construction. Gating them would force every rigging target to carry the rig's tag
  redundantly, and a missing tag would silently disable the rig.
- source is a loaded `.fxpreset` file → apply the boundary to all five sections. A saved
  preset may target IDs that a later plugin version reassigned; `flags` and `tags` carry
  the worst drift damage (a hidden or disabled control the user cannot restore), so they
  receive the same protection as `values` and `meta`.
- `kFxParameterPreset_IgnoreTagBoundary` remains the per-apply escape hatch for the file
  path.

`applyPreset:` therefore takes the source alongside the tag. Membership is computed once
per call through `parametersWithTag:tag`.

Error contract: a per-entry failure logs and continues (legacy behavior); the method
returns the first error after all sections run, nil when every entry succeeds. Returning
the error is a deliberate change from the legacy unconditional YES.

Key lookup: section dictionaries key by ID string. The core normalizes lookups to accept
`NSString` and `NSNumber` keys (the `objectForIndex:` dual-lookup pattern,
`NSDictionary+FxTileableEffect.m` 123–130). This corrects the legacy creation-time values
bug at `FxGripTileableEffect.m` 1656–1712: the loop iterates string keys but subscripts
`presetValues[pid]` with an `NSNumber`, so plist-sourced values sections resolve to nil.

#### 3.6.5 Target-preset trigger

The trigger is thin: menu/toggle change → index → definition → core.
`applyTargetPresetForParameter:atTime:options:`:

```
1 def := [self targetPresetForParameter:pid record:&record]; record nil → return NO
2 type := [effect configurationForParameter:pid].parameterType
3 type not Menu and not Toggle → return YES                    // silent no-op
4 Menu → getIntValue:; Toggle → getBoolValue: cast to int; API failure → return NO
5 def nil or count 0 → return YES
6 preset := index lookup on def
      NSArray → bounds-checked subscript; out of range → nil (the raw subscript at
        NSDictionary+FxTileableEffect.m 60–63 raises NSRangeException and must be guarded)
      NSDictionary → @(i) then "i" string (ibid. 123–130)
7 preset nil and def is NSDictionary → preset := def[@"default"]
8 preset nil → return YES
9 resolvedTag := the string form of record["targetpreset"] when resolution went through
      presetDefinitionForTag:, nil for inline array/dictionary definitions
10 return [self applyPreset:preset atTime:time options:options
      presetFlags:kFxParameterPreset_Default tag:resolvedTag] == nil
```

Wiring: `FxGripMeta` observes `FxGripTileableEffectParameterChangedName` (posted by
`parameterChanged:` at `FxGripTileableEffect.m` 571–581) at a negative priority so the
per-parameter `startChangedTime:` handlers run first. The definitions live in the meta
record (section 5), the core lives on the tags API, and the extension already owns the
record lifecycle, so the trigger belongs there. The handler:

```
pid  := userInfo[FxGripTileableEffectParameterChangedIDKey].unsignedIntValue     // required
time := CMTime from userInfo[FxGripTileableEffectParameterChangedAtTimeKey]
        (kCMTimeZero when the key is absent)
[tagsAPI applyTargetPresetForParameter:pid atTime:time
        options:(FxGripPresetFlags | FxGripPresetTags | FxGripPresetValues)]
resetValue := record[kFxParameterProperty_ResetValue]          // instance record, section 5
resetValue → [FxGripPreset setParameterValue:resetValue toParameter:pid atTime:time
        withAPI:paramSetAPIv5]
[tagsAPI applyTargetPresetForParameter:pid atTime:time options:FxGripPresetNames]
```

Ordering contract: value work first, reset value next, names last. Setting a parameter
name and then reading a String parameter glitches in Final Cut Pro
(`FxGripTileableEffect.m` 2186–2188). The legacy `completeParameterChanged:` applies
`PresetName` before the reset value (2172–2182); the comment contract wins and the port
applies names last. Errors propagate through the existing `userInfo.fxError` convention.

Defensive changes from the legacy runtime, consolidated:

- `NSArray` out-of-range index → no preset, return YES (no `NSRangeException`)
- unknown index in an `NSDictionary` definition → `"default"` entry fallback
- unknown flag name → skipped explicitly (`convertFlag:` returning 0)
- `Tags` and `Values` branches implemented (legacy runtime left placeholders at
  1967–1975; semantics come from the creation-time path)
- string/number key normalization in every section lookup

Consumers unlocked: `FxGripDebugMenu` (uncomment `FxGripDebugMenu.m` ~218–221; route the
debug-activator toggle through `options:FxGripPresetFlags`) and the
`FxGripFactory` / `FxGripFactoryParameters` licensing toggle (`@todo` at
`FxGripFactoryParameters.m` 1057, target-preset intent stated at 16).

#### 3.6.6 Creation-time application

`+[FxGripParameterUtility applyTargetPresetDefaults:pluginPresets:]` ports
`filterParameters:` (section 2.3): for each Menu/Toggle configuration with a resolvable
definition, apply the default-index preset to the configuration dictionaries (names →
`"name"`, flags → the flag-string array, tags → the `"tags"` array created on demand,
values → the type dispatch into defaults). `addParametersWithError:` calls it inside the
existing `postBlock` after `flattenDictionaryParameters:` (`FxGripTileableEffect.m`
463–466), so extension-added parameters participate. This path runs before any host API
exists and stays outside the tags API. No `"default"` fallback on this path, matching
legacy. The string/number key fix (3.6.4) applies here as well.

#### 3.6.7 File-preset layer

`FxGripPresetsAPI_v1` retains the file duties and feeds the core. Current state:

- `FxGripPresetsAPI_v1.h` declares the full surface: `generatePreset:fromLabel:`,
  `setPreset:options:`, `savePreset:remap:` / `loadPreset:remap:`, `pluginPresetURL`(`:`),
  `+openMediaPresetFolder`(`:`), `+presetsForTag:` / `+pluginPresetsForTag:` /
  `+userPresetsForTag:`, `+observeTag:observer:`, `compatiblePreset:`. Every `.m` body is
  a stub returning nil / NO / `@[]`.
- `FxGripPreset.h` declares the model properties (42–58), `savePresetToURL:` /
  `+loadPresetFromURL:` (60–61), and the class primitives (63). `FxGripPreset.m` 34–207
  carries roughly thirty orphan stubs copied from other classes (tag, meta, and
  preset-file methods plus `initWithAPIManager:`), including
  `getMetaKeys:forPreset:fromParameter:` at 44. The port deletes the orphans; the class
  keeps the model, the URL round-trip, and the primitives at 210–221 (both currently
  return NO).
- Cleanups: the `assign` object properties become `copy`/`strong`; `kFxPreset_Extension`
  is defined in both headers (`FxGripPreset.h` 28, `FxGripPresetsAPI_v1.h` 43) and the
  `FxGripPreset.h` define survives; `kFxFactoryPresetKeyMap` (`FxGripPresetsAPI_v1.h`
  47–57) is syntactically invalid (missing commas, unbalanced braces) and is rebuilt when
  the FxFactory keys are pinned; both headers become Public umbrella entries when the
  layer lands.

Flow into the core:

- `setPreset:options:` → `compatiblePreset:` (plugin UUID and alternatives) unless
  `IgnoreCompatibility` → colour-space value remap per `kFxPresetProperty_RemapValues` /
  `kFxPresetProperty_ColorSpace` → `[tagsAPI applyPreset:preset.presetSections
  atTime:time options:(FxGripPresetValues | FxGripPresetTags | FxGripPresetMeta), minus
  FxGripPresetMeta when IgnoreMetaData, presetFlags:flags tag:preset.tag]`.
- `generatePreset:fromLabel:` captures values through `+getParameterValue:…withAPI:`;
  capture skips meta for parameters flagged `PRESETNOMETA` and tags for parameters
  flagged `PRESETNOTAGS`.
- `savePreset:remap:` / `loadPreset:remap:` serialize `.fxpreset` property lists with an
  optional key remap (system key → file key; `kFxFactoryPresetKeyMap` for FxFactory
  files). `pluginPresetURL` / `pluginPresetURL:` locate the plugin preset folder and the
  per-tag subfolder (user domain and plugin bundle); `openMediaPresetFolder` reveals them.
##### Project media folder: out of scope (decided 2026-07-31)

`FxProjectAPI mediaFolderURL:error:` provides a plug-in data folder inside a Motion
project's media folder, surfaced already as `projectMediaFolder`
(`FxGripTileableEffect+ProjectProperties`). It is the only such API; the protocol declares
three methods total and offers no unconditional variant. The URL is nil when the project
is unsaved or was saved without "Collect Media", an opt-in save option, so the folder is
absent for most projects. A preset source that is usually missing is less useful than no
source: availability is unpredictable and support begins with a question about a save
setting. The layer therefore ships without it. The accessor remains, so a later release
can add project-scoped presets without new plumbing.

##### Storage model (decided 2026-07-28)

Two sources, with different lifecycles:

**Premade, shipped with the plugin.** Two forms, both enumerable per tag:
- the Info.plist `"presets"` table, already serving rigging and creation-time defaults;
- `.fxpreset` files bundled in the plugin, located through `pluginPresetURL:tag`.

`+pluginPresetsForTag:` returns both. Bundle content is immutable at run time, so nothing
watches it.

**User-saved, in a managed folder plus files the user chooses (decided 2026-08-02).**
The managed user-preset folder is
`~/Library/Application Support/<company>/<plugin name>`, per user, with both folder
levels version-agnostic and derived from the plugin identity FxGrip already carries.
The shape follows the Core Audio convention
(`~/Library/Audio/Presets/<company>/<plugin name>`, as used by APU Spectrum Analyzer):
a company folder shared by all of a vendor's plugins, one subfolder per plugin, and no
version in the path so presets survive plugin updates. `Application Support` was chosen
over Apple's `ProApps/Effects Presets` domain (Apple's namespace; Final Cut Pro
enumerates it and its handling of foreign content is unverified) and over an invented
`~/Library/Video/Presets` (no OS or third-party precedent exists).

The managed folder makes user presets enumerable per tag. The save and open panels
remain for arbitrary locations, so presets are still ordinary documents the user can
name, place, back up, and share; the panels grant sandbox access through Powerbox.
`savePresetToURL:` and `+loadPresetFromURL:` on `FxGripPreset` are the primitives; the
API layer adds the folder enumeration and the panel flow. `BESecurityScopedURLManager`
(BEFoundation) creates and resolves security-scoped bookmarks when a panel-chosen file
must stay reachable across launches. Step-14 verification: confirm the FxPlug
out-of-process sandbox can read and write the Application Support path; if the host
container blocks it, the panel flow is the fallback.

Consequences for the declared surface:
- `+userPresetsForTag:` enumerates the managed folder's presets for a tag;
  `+presetsForTag:` merges the premade presets (plist plus bundled files) with them.
- `+observeTag:observer:` watches the managed folder. The `DirectoryWatcher` forward
  declaration (`FxGripPreset.h` 14) has no implementation anywhere in the repository and
  is still deleted; `BEPathWatcher` (BEFoundation) provides the watch.
- `+openMediaPresetFolder`(`:`) stays dropped with the project media folder decision
  above; revealing the managed folder rides on `pluginPresetURL`.

The 3.6.9-1 split is unchanged: rigging resolves the instance record and the plist
table only, so no saved file can alter existing menu behavior. Managed-folder presets
join the merged listing for browsing and user-initiated apply. Whether they also append
new entries to rigging menus follows the additive name-keyed rule (add, never redefine)
and is settled at step 14.

##### The presets menu parameter (decided 2026-08-02)

`FxGripPresetsParameter` (type `"presets"`, `FxParameterType_Presets`) is the browse and
apply surface: a popup menu built at creation time in the order

    Default, -, <user presets>, -, <plugin presets>, -,
    Reveal User Presets in Finder..., Save Preset

An empty preset section is omitted together with its separator. The parameter's tag is
the configuration's first entry under `tags`; the user and plugin sections list
`userPresetsForTag:` and `pluginPresetsForTag:` by name.

Selection dispatches by entry NAME, resolved through the live menu recorded by
`FxGripParameterData` so drifted entries keep resolving:
- a preset name → `setPreset:options:atTime:`; user presets shadow plugin presets of the
  same name, matching the menu order; on success the name is recorded in the instance
  record under `kFxMetaProperty_SelectedPreset`.
- `Default` → records the default state and applies nothing.
- `Reveal User Presets in Finder...` → creates the managed folder on demand, opens it in
  Finder, and restores the recorded selection.
- `Save Preset` → captures the current state through `generatePreset:fromLabel:`, stamps
  the tag, runs the save panel, and restores the recorded selection.

The host persists a menu selection as an int; the recorded NAME is what keeps a document
stable when entries are appended, removed, or reordered across plugin versions —
restoration maps the name to its current index and falls back to `Default`.

**Live refresh (decided 2026-08-02).** The parameter watches the managed per-tag user
folder with `BEPathWatcher` (target held weakly; the parameter retains the watcher). A
file added, removed, or renamed rebuilds the menu on the host through the v3 dynamic
API's `setPopupMenuParameter:entries:defaultValue:` inside an out-of-band access context
on the main queue, then remaps the recorded selection name to its new index. The watcher
attaches when the folder exists; the reveal and save actions attach it after creating
the folder, and a completed save refreshes explicitly because a watcher attached at that
moment missed the write event.

##### Interchange with FxFactory (decided 2026-07-28)

The on-disk format is FxFactory's, extended. A written file carries the seven FxFactory
keys under their exact names, so FxFactory reads FxGrip files and FxGrip reads FxFactory
files:

| FxGrip property | File key |
|---|---|
| `createdByParameterId` | `FxFactoryPresetCreatedByParameterID` |
| `parameterValues` | `FxFactoryPresetParameterValues` |
| `pluginAuthor` | `FxFactoryPresetPlugInAuthor` |
| `pluginLocalizedName` | `FxFactoryPresetPlugInLocalizedName` (per-language dictionary) |
| `pluginUuid` | `FxFactoryPresetPlugInUUID` |
| `pluginVersion` | `FxFactoryPresetPlugInVersion` |
| `productId` | `FxFactoryPresetProductID` |

FxGrip's seven additions have no FxFactory equivalent and ride alongside as flat
`FxGripPreset*` siblings, mirroring FxFactory's own convention: `FxGripPresetFramework`,
`FxGripPresetUUID`, `FxGripPresetDisplayName`, `FxGripPresetTag`,
`FxGripPresetCreatedTime`, `FxGripPresetParameterMeta`, `FxGripPresetParameterTags`.
A reader ignores keys it does not know, so both directions degrade to the shared subset.

Reading an FxFactory file therefore yields values only: no tag, no meta, no tags. The tag
such a preset applies under comes from the caller, and the apply runs with
`FxGripPresetValues` and `FxGripPresetSourceFile` (3.6.9-6).

Wiring gap: no host implements `FxParameterTagsAPI_v1` or the empty
`@protocol FxPresetsAPI_v1` (`FxGripPresetsAPI_v1.h` 29–30); both are FxGrip-implemented.
`apiForProtocol:` gates wrapper creation on a non-nil host API (`FxGripAPIAccessing.m`
349), so the tags wrapper is unreachable, and the declared `paramTagsAPIv1` accessor
(`FxGripAPIAccessing.h` 106) has no implementation in the `.m`. The port constructs
FxGrip-implemented wrappers with a nil host API, implements the accessor, and adds a
`presetsAPIv1` accessor for the file layer.

Reference samples: `Information/parameterXML.xml` and `Information/fcp xml preset.rtf`
are Motion `ozml` scene XML (DOCTYPE `ozxmlscene`, version 5.13) of a QR Code Basic
generator instance. They show the host-side serialization: a nested `<parameter>` tree
with `name` / `id` / `flags` / `default` / `value` attributes, flag words wider than 32
bits (73018703904 on "Plugin Data" id 9998), and the custom data parameter persisted as
encoded `<defaultVal>` / `<dataValue>` text. The samples confirm legacy builds stored the
meta archive at id 9998 (section 1.8) and document the format target presets ultimately
land in. They are not `.fxpreset` files; the flat ID-keyed `FxGripPreset` plist remains
FxGrip's own format, and no FxFactory sample exists in the repository (3.6.9-2).

#### 3.6.8 Flag and opt-out semantics

- `kFxParameterFlag_PRESETNOMETA` on a target parameter → the meta section skips it;
  `generatePreset:` does not capture its meta.
- `kFxParameterFlag_PRESETNOTAGS` on a target parameter → the tags section skips it;
  `generatePreset:` does not capture its tags.
- `kFxParameterPreset_IgnoreTagBoundary` → values and meta sections apply regardless of
  tag membership.
- `kFxParameterPreset_IgnoreMetaData` → the caller clears `FxGripPresetMeta` for the call.
- `kFxParameterPreset_IgnoreCompatibility` → `compatiblePreset:` is skipped.
- Opt-out flag words are read from `FxGripParameterData storedFlags:` (the store that
  carries the FxGrip-internal bits above the Apple flag range).

#### 3.6.9 Open questions

Decided 2026-07-28:

1. RESOLVED — precedence splits by operation. `presetDefinitionForTag:` (automatic
   rigging) resolves from the instance record and the plist `"presets"` table only; the
   merged plist-plus-user-file listing serves browsing and user-initiated apply. A saved
   preset therefore never changes a plugin's menu rigging. See 3.6.7.
3. RESOLVED — the tag boundary keys off the definition's source, not the section. Plist
   and instance rigging bypass it for all five sections; file-loaded presets apply it to
   all five. See the tag boundary rule in 3.6.4.

Remaining open:
2. MOSTLY RESOLVED 2026-07-28 from a real sample: `FxFactory Circle Preset.fxpreset` in
   the repository root (the `Information/` files are Motion scene XML; this one is the
   actual format). It is an XML property list with seven top-level keys, which fix
   `kFxFactoryPresetKeyMap` (currently syntactically broken, missing commas):

   | Key | Value |
   |---|---|
   | `FxFactoryPresetCreatedByParameterID` | integer (117 in the sample) |
   | `FxFactoryPresetParameterValues` | dictionary, keys are **parameter ID strings** |
   | `FxFactoryPresetPlugInAuthor` | string |
   | `FxFactoryPresetPlugInLocalizedName` | **dictionary keyed by language** (`English` → `Circle`) |
   | `FxFactoryPresetPlugInUUID` | string |
   | `FxFactoryPresetPlugInVersion` | string (`"1.0"`) |
   | `FxFactoryPresetProductID` | string (`"fxfactorypro"`) |

   Value encodings observed: scalars are plain numbers; color is
   `{red, green, blue, alpha, colorspace}` with `colorspace = 1`
   (`kFxFactorPresetColorSpace_sRGB_Color`); point is `{x, y}`; an image or path
   parameter is a relative resource path string (`"Curve/InverseQuadratic.png"`).
   Histogram encoding remains unobserved.

   Consequences for the port:
   - Parameter IDs are strings on disk, which confirms the core's string/number key
     normalization (3.6.4).
   - `FxGripPreset.pluginLocalizedName` is typed `NSString*` but the file carries a
     per-language dictionary; the file layer must map it (pick the current localization,
     retain the dictionary for round-trip).
   - The format carries **no** preset uuid, display name, tag, created time, framework,
     `parameterMeta`, or `parameterTags`. FxFactory presets are values-only, so the tag
     comes from the containing folder (`pluginPresetURL:tag`), not the file. An applied
     FxFactory preset therefore reaches `applyPreset:` with the folder's tag, the
     `FxGripPresetValues` option only, and `FxGripPresetSourceFile`.
   - `parameterMeta` / `parameterTags` are FxGrip extensions to the format, absent from
     FxFactory files.
   - The sample's `CreatedByParameterID` (117) is evidence for open question 4.
4. `kFxPresetProperty_CreatedByParameterId` semantics: which trigger path creates a
   preset from a push-button parameter.
5. The min/max/slider preset sections (legacy placeholder at `FxGripTileableEffect.m`
   1973): in scope or dropped.
6. RESOLVED 2026-07-28. The file layer's apply methods take an `atTime:` argument and
   document `kCMTimeZero` as the value for a user-initiated load. Two findings decide it:

   - The FxFactory format carries no time dimension. `FxFactory Circle Preset.fxpreset`
     holds one flat value per parameter ID, with no keyframes, no per-value timestamps,
     and no created time. A preset is static parameter values, not values at a time and
     not restorable animation.
   - FxPlug exposes no current-playhead accessor. Every `FxTimingAPI_v4` method is a
     bound (`startTimeForEffect:`, `inPointTimeOfTimelineForEffect:`) or a conversion
     (`timelineTime:` ↔ `inputTime:`). Time reaches a plug-in only as a host callback
     argument. A user-initiated load arrives through `parameterClicked:`, which takes no
     arguments by the FxPlug button contract, so no time exists at that point.

   Callers that hold a meaningful time (a render pass, a `parameterChanged:` handler, an
   on-screen control drag) pass it through. This matches the convention `applyPreset:` and
   `+[FxGripPreset setParameterValue:…atTime:]` already use, so one rule covers the engine.

   Limitation, documented rather than solved: writing at `kCMTimeZero` sets an animated
   parameter's keyframe at zero rather than at the playhead. Applying an untimed preset to
   an animated parameter is undefined at the source; `kFxParameterFlag_NOT_ANIMATABLE`
   marks parameters that should not be animated.
7. Whether an `NSArray` definition should honor a `"default"` fallback. Legacy and this
   design restrict the fallback to `NSDictionary` definitions.

### 3.7 Thread safety

`FxGripMetaManager` retains the `NSRecursiveLock` with full-method coverage; the public
`lock` / `lockWithinTime:` / `unlock` triple remains for callers composing multi-step
atomic edits. `saveMeta` runs its host write while holding the lock; the lock is
recursive, so re-entry from the same thread (notification handlers triggered by the write)
cannot deadlock. The `FxGripMeta` extension serializes its own load/flush with
`@synchronized (self)` like `FxGripParameterData`. The preset core (3.6) adds no state of
its own; it executes on the host's parameter-change thread and touches only the API
wrappers, the configuration records, and the meta manager. The file layer's
`BEPathWatcher` callbacks arrive on a GCD queue and must re-enter the core through the
same wrappers.

---

## 4. Port order and test strategy

Tests are XCTest files in `FxGripTests/` (synchronized group), one per class, named
`<ClassName>Tests.m`. Host API responses are mocked by subscribing to the effect's
`notifier` for the `FxNotifyAPI_*` names and filling `userInfo` (pattern in
`FxGripTileableEffectNotificationTests.m`). Each step ends with the Full Check (arm64 test,
x86_64 test, ASan test, docbuild).

Status 2026-07-27: steps 1–8 are landed in the working tree (constants, the manager, the
`FxGripMeta` extension with section-5 seeding, persistence, and the API delegations).
Steps 9–15 replace the former steps 9–11 and implement the section 3.6 unified design.

1. **Constants and enum.** Add `kFxParameterId_InstanceMeta` (9995), the five ported
   `kFxMetaProperty_*` defines, and `FxGripPresetOptions` to `FxGripTypes.h`. Fix the
   `__configParameters` array/dictionary assignment at `FxGripTileableEffect.m` 455.
   Tests: extend `FxGripPluginTests.m` (or a small `FxGripTypesTests.m`) asserting id
   uniqueness across 9995–9999 and that `parametersConfiguration`-driven setup populates
   `__configParameters` as a pid-keyed dictionary (observable through
   `parameterCount` / `objectForKeyedSubscript:`).

2. **FxGripMetaManager core.** Records, `addParameter:` / `removeParameter:` /
   `parameterExists:` / `parameterData:`.
   Tests (`FxGripMetaManagerTests.m`): duplicate add rejected; pre-seeded record without
   `"id"` adopted; remove scrubs the reverse index; sentinel returns for missing records;
   `parameterData:` returns the live record.

3. **Tag API.** Array-backed tags, reverse index, fixed `setTags:`.
   Tests: add/remove/removeAll round-trips both sides of the index; idempotent add;
   emptied reverse-index entries deleted; `setTags:` installs the supplied array;
   `tags` reflects mutations (cache invalidation); error domain/code/message for missing
   records; `parametersWithTag:` returns a copy (mutating it does not affect the index).

4. **Meta API.** Value dictionary CRUD with the fixed `getMeta:` out-parameter and
   `unsaved` marking.
   Tests: get/set/remove by key; `setMeta:toParameter:` deep-replaces; `getMeta:` assigns
   the out-param and returns nil on success; every mutator flips `unsaved`; −1 count
   sentinel.

5. **Coding and copying.** Keyed `NSSecureCoding`, `NSCopying`, `classesForParameter`.
   Tests: `NSKeyedArchiver` round-trip with `requiringSecureCoding:YES` preserves tags,
   meta, and the reverse index; decode of a hand-built legacy-shaped root dictionary;
   copy independence (`mutableCopyRecursive` depth); `isEqual:` on data.

6. **FxGripMeta extension + effect attachment.** Return `Extensions/FxGripMeta.m` to the
   build; implement lifecycle handlers; add the `(Meta)` category.
   Tests (`FxGripExtensionTests.m` additions or `FxGripMetaTests.m`): `hasMeta` tracks the
   `manageMeta` plist property; InstanceMeta parameter registered with the documented
   flags at id 9995; `extAPIParameterAdd:` seeds records and transfers config `"tags"` /
   `"meta"`; `extAddedToDocument:` adopts a mocked `getCustomParameterValue:` result and
   calls `setEffect:`; fallback to a fresh manager.

7. **Persistence.** `saveMeta` through `extFlush:`.
   Tests: mutation → flush posts `FxNotifyAPI_ParameterSetCustomValueName` for id 9995
   exactly once; second flush without mutation posts nothing; `setUnsaved:` gating.

8. **API delegation.** `FxGripParameterTagsAPI_v1` and the nine
   `FxGripDynamicParameterAPI_v4` meta methods.
   Tests (`FxGripParameterTagsAPI_v1Tests.m`, extend dynamic-API tests): each method
   forwards arguments and returns verbatim; guard behavior when `hasMeta` is NO matches
   the documented sentinel table; the four orphan stubs are gone (compile-time).

9. **Protocol consolidation and wiring.** Delete `Utilities/FxGripTagAPI.h` (3.6.2);
   extend `FxParameterTagsAPI_v1` with the section 3.6.4 method surface; add
   `FxGripPresetMeta = 1 << 4` and `kFxParameterProperty_TargetPresetMeta` to
   `FxGripTypes.h`; implement the `paramTagsAPIv1` accessor in `FxGripAPIAccessing.m` and
   construct FxGrip-implemented wrappers without a host API (move creation out of the
   `api &&` gate at `.m` 349).
   Tests (extend `FxGripAPIAccessingTests` and `FxGripParameterTagsAPI_v1Tests.m`):
   `paramTagsAPIv1` returns a live wrapper without a host API; the deleted header is gone
   (compile-time); option and property constants have the documented values.

10. **Typed apply primitive.** Implement `+[FxGripPreset
    setParameterValue:toParameter:atTime:withAPI:]` and
    `+getParameterValue:toParameter:atTime:withAPI:`; delete the orphan stubs at
    `FxGripPreset.m` 34–207.
    Tests (`FxGripPresetTests.m`): per-type set and get round-trips against mocked
    notifications (int, float, bool, string, RGB, RGBA alpha fall-through, Point,
    Custom recursive-merge, scalar default); nil value and unknown type return NO.

11. **Preset core.** `presetDefinitionForTag:`, `targetPresetForParameter:record:`,
    `applyPreset:atTime:options:presetFlags:tag:`, and
    `getMetaKeys:forPreset:fromParameter:` on `FxGripParameterTagsAPI_v1`.
    Tests: resolution precedence (instance record over configuration, string tag through
    `pluginProperties["presets"]`, unknown tag → nil + log); option gating per section
    (each bit applies only its section); fixed section order with names last (recorded
    notification sequence); tag boundary honored for values/meta and bypassed by
    `IgnoreTagBoundary`; `PRESETNOMETA` / `PRESETNOTAGS` opt-outs; unknown flag name
    skipped; flag write posts `FxNotifyAPI_ParameterSetFlagsName` only when bits change;
    string and number section keys both resolve; per-entry error logs, continues, and is
    returned as the first error.

12. **Target-preset trigger.** `applyTargetPresetForParameter:atTime:options:` plus the
    `FxGripMeta` observer for `FxGripTileableEffectParameterChangedName` with the ordering
    contract (values/flags/tags, then `resetvalue`, names last).
    Tests (`FxGripMetaTests.m` additions): array bounds-check → no-op; dictionary
    `@(i)` / `"i"` / `"default"` fallback; toggle value 0/1; Menu int value; non-Menu/
    Toggle → YES no-op; ordering captured by notification sequence; reset value applied
    between values and names; resolved-tag pass-through to the core; handler error →
    `userInfo.fxError`.

13. **Creation-time defaults.** `+[FxGripParameterUtility
    applyTargetPresetDefaults:pluginPresets:]` hooked into `addParametersWithError:`'s
    `postBlock` after `flattenDictionaryParameters:`.
    Tests (`FxGripParameterUtilityTests.m`): default menu index selects the preset; names
    rewrite `"name"`; flag strings mutated as strings; tags array created on demand and
    `+`/`-` applied; values dispatch per type (RGB, RGBA fall-through, Point, Custom
    merge, scalar default); string and number value keys both resolve; parameters added
    by extensions (debug menu) participate; missing target ID logs and skips; no
    `"default"` fallback on this path.

14. **File-preset layer.** `FxGripPresetsAPI_v1` implementation per 3.6.7: preset
    folders and URLs, `.fxpreset` save/load with key remap, `compatiblePreset:`,
    colour-space remap, `BEPathWatcher` observation, `setPreset:options:` and
    `generatePreset:fromLabel:` through the core; `presetDefinitionForTag:` extended to
    file lookups; headers marked Public and added to `FxGrip.h`; `kFxFactoryPresetKeyMap`
    rebuilt; `presetsAPIv1` accessor added.
    Tests (`FxGripPresetsAPI_v1Tests.m`): `.fxpreset` round-trip in a temporary folder;
    remap applied on save and inverted on load; UUID compatibility including
    `IgnoreCompatibility`; colour-space remap of values; capture honors `PRESETNOMETA` /
    `PRESETNOTAGS`; `setPreset:` reaches the core with the mapped options; watcher fires
    on a folder change.

15. **Consumers.** Re-enable the debug-menu preset call (`FxGripDebugMenu.m` ~218–221);
    wire the factory licensing toggle (`FxGripFactoryParameters.m` 1057).
    Tests (extend `FxGripExtensionTests.m`): the debug activator toggle hides and reveals the
    debug menu through the preset path.

Dependencies: 9 precedes 10–15; 11 needs 10 (the values branch calls the primitive); 12
needs 11; 13 needs only 9 and the utility hook and can run in parallel with 10–12; 14
needs 10 and 11; 15 needs 12. Open questions 3.6.9-1, -2, -3, and -6 are resolved, so no
open question blocks step 14. Questions 4, 5, and 7 remain and affect none of the steps.

---

## 5. Amendment (2026-07-26): per-instance preset capabilities

Requirement change: target-preset capabilities live in the instance file storage
(the InstanceMeta custom parameter), not only in the static configuration.

- `FxGripMeta extAPIParameterAdd:` seeds each record with the configuration's
  `"resetvalue"` and every `"target"`-prefixed key, in addition to tags and meta.
  Seeding is additive: an entry already present in the record, including a
  customization restored from the document, wins over the configuration value.
- Consequence for section 3.6: `targetPresetForParameter:` reads the instance record
  first and falls back to `configurationForParameter:`. Runtime preset customization
  writes to the record (`parameterData:`), marks the manager unsaved, and persists
  through the standard flush.
- Removing a record entry restores the configuration default at the next seed.

This supersedes the section 3.2/3.4 statement that `"targetpreset"` and `"resetvalue"`
are not duplicated into the manager.
