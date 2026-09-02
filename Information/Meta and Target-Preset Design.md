# Meta and Target-Preset Design

Reference for two FxGrip subsystems as they stand in the current source (2026-09-01):

- the **meta/tag subsystem** — per-parameter tags and user metadata, stored per effect
  instance and persisted with the document;
- the **preset system** — target presets (menu/toggle rigging), a file-preset layer, and a
  browse-and-apply menu parameter, all sharing one application core on the tags API.

Class and file names, method signatures, and behavior describe the shipping code. This
document informs; it is not a change log. It carries no port history.

---

## 1. Overview

The subsystems compose in four layers:

- `FxGripMetaManager` (`CustomParameter/`) holds the per-instance record store: for each
  parameter, a tag list and a user-metadata dictionary, plus a tag reverse index. It is the
  value of a hidden custom parameter and round-trips through `NSSecureCoding`.
- `FxGripMeta` (`Extensions/`) is the effect extension that owns the manager, registers the
  hidden parameter, seeds records from configuration, persists on flush, and drives the
  target-preset trigger.
- The API layer wraps the manager for host and framework callers:
  `FxGripMetaAPI_v1` (metadata), `FxGripParameterTagsAPI_v1` (tags plus the preset core).
- The preset system sits on the tags API. Target presets, bundled `.fxpreset` files, and
  user-saved files resolve to one canonical shape and apply through one method,
  `applyPreset:atTime:options:presetFlags:source:tag:`. `FxGripPresetsAPI_v1` is the file
  layer; `FxGripPresetsParameter` is the popup that browses and applies presets.

A tag does double duty: it addresses a preset definition, and it selects which parameters a
file preset may touch.

---

## 2. `FxGripMetaManager`

`CustomParameter/FxGripMetaManager.{h,m}`. Introduced in FxGrip 1.0.

### 2.1 Class and storage model

```objc
@interface FxGripMetaManager : NSObject <NSSecureCoding, NSCopying, FxGripCustomDataClasses>
```

The manager is the value of the hidden custom parameter `kFxParameterId_InstanceMeta`
(9995), one instance per effect instance. State:

| Ivar | Type | Content |
|---|---|---|
| `_data` | `NSMutableDictionary<NSString*, NSObject*>` | Root archive. Exactly two keys. |
| `__tags` | `NSMutableDictionary<NSString*, NSMutableArray<NSNumber*>*>` | Tag reverse index: tag string → parameter-ID array. Aliases `_data[kFxMetaProperty_Tags]`. |
| `__parameters` | `NSMutableDictionary<NSNumber*, NSMutableDictionary<NSString*, id>*>` | Record store: `@(pid)` → record. Aliases `_data[kFxMetaProperty_Parameters]`. |
| `_metaLock` | `NSRecursiveLock` | Guards every public method. |
| `_effect` | `__weak FxGripTileableEffect *` | Owning effect. Not archived. |
| `_unsaved` | `BOOL` | Dirty flag for deferred persistence. |

`realiasData` guarantees both root keys exist as mutable dictionaries and repoints the two
aliases after any decode or copy.

Each per-parameter record holds:

- `kFxMetaProperty_ParamId` → `NSNumber` (the parameter ID);
- `kFxMetaProperty_ParamTags` → `NSMutableArray<NSString*>` (order-preserving tag list);
- `kFxMetaProperty_ParamMeta` → `NSMutableDictionary<NSString*, id>` (user metadata);
- additive keys written by `FxGripMeta`, such as `kFxParameterProperty_ResetValue` and any
  `kFxParameterProperty_TargetPrefix` (`"target"`) key.

Parameter type and flags are not stored here. `FxGripParameterData` owns them.

### 2.2 Secure coding, copying, equality

- `+supportsSecureCoding` returns `YES`.
- `encodeWithCoder:` encodes `_data` with keyed coding under the key `"data"`.
- `initWithCoder:` decodes with `decodeObjectOfClasses:forKey:@"data"` using the
  `+classesForParameter` allow-list, deep-copies the result with `mutableCopyRecursive`,
  then re-aliases. The effect pointer is not encoded; a caller sets it with `setEffect:`.
- `+classesForParameter` is the secure-decode allow-list: `NSMutableDictionary`,
  `NSDictionary`, `NSMutableArray`, `NSArray`, `NSMutableString`, `NSString`,
  `NSMutableSet`, `NSSet`, `NSMutableOrderedSet`, `NSOrderedSet`, `NSNumber`,
  `NSDecimalNumber`, `NSColor`, `NSDate`, `NSNull`, `NSMutableData`, `NSData`, `NSValue`,
  `NSURL`, `NSUUID`, `FxTime`, `FxGripDictionary`, `FxGripInterpolatingDictionary`. The
  instance method forwards to the class method.
- `copyWithZone:` deep-copies `_data` with `mutableCopyRecursive`, re-aliases, and preserves
  both the effect reference and the `unsaved` flag.
- `isEqual:` compares `_data`. `hash` is `_data.hash`.

### 2.3 Record management

| Method | Behavior |
|---|---|
| `addParameter:` | Rejects (logs, returns NO) when an existing record already carries `kFxMetaProperty_ParamId`. Adopts a pre-seeded record that lacks the ID, promoting an immutable record to mutable. Writes the ID, creates the `ParamTags` array and `ParamMeta` dictionary, sets `unsaved`. |
| `removeParameter:` | Removes the record, scrubs the parameter ID from every reverse-index entry, drops emptied tag entries, sets `unsaved`. |
| `parameterExists:` | Locked existence check. |
| `parameterData:` | Returns the live mutable record, not a copy. |
| `parameterIDs` | The stored parameter IDs. |

A caller that mutates the live record returned by `parameterData:` marks `unsaved` itself;
the direct write does not.

### 2.4 Tag API

Every failure uses domain `FxGripPlugErrorDomain`, code
`kFxError_ThirdPartyDeveloperStart + parameterID`. Two canned messages:
`"No tags container for parameter (%u)."` and `"No record for parameter (%u)."`.

| Method | Behavior | Missing container |
|---|---|---|
| `tags` | All distinct tag strings. | — |
| `tagCount` | Distinct-tag count. | — |
| `tagCount:` | Per-parameter tag count. | −1 |
| `parameterTags:` | A copy of the tag array. | nil |
| `parameter:hasTag:error:` | `containsObject:`. | sets `*error`, returns NO |
| `setTags:toParameter:` | Removes all tags, then adds each supplied tag. | error |
| `addTag:toParameter:` | Idempotent add; updates the reverse index; sets `unsaved`. | error |
| `removeTag:fromParameter:` | Removes from both sides; drops the tag when its array empties; sets `unsaved`. | error |
| `removeAllTags:` | Scrubs each tag's reverse-index entry, then empties the container. | error |
| `parametersWithTag:` | A copy of the tag's parameter-ID array. | nil for an unknown tag |

The reverse index is maintained inline on every mutation. `parameterTags:` and
`parametersWithTag:` return copies, so external mutation never reaches the stored arrays.

### 2.5 Meta API

Every failure uses the same domain and code. Missing records yield the no-record error.

| Method | Behavior | Missing record |
|---|---|---|
| `metaCountFromParameter:` | Metadata entry count. | −1 |
| `getMeta:fromParameter:` | Assigns `*meta` a copy, returns nil on success. | error |
| `setMeta:toParameter:` | Replaces the metadata with a mutable copy; sets `unsaved`. | error |
| `getMetaKeys:fromParameter:` | Assigns `*keys` the key list. | error (or a nil out-pointer error) |
| `removeAllMeta:` | Empties the metadata; sets `unsaved` when non-empty. | error |
| `parameter:hasMetaKey:error:` | Key presence. | sets `*error`, returns NO |
| `getMeta:forKey:fromParameter:` | Assigns `*value` when present; a nil `value` pointer performs a pure existence check. Returns whether the key exists. | NO |
| `setMeta:forKey:toParameter:` | Writes the value; sets `unsaved`. Returns YES. | NO |
| `removeMetaKey:fromParameter:` | Removes; returns whether the key existed; sets `unsaved` on removal. | NO |

Every metadata mutation marks `unsaved`, so a metadata-only edit persists.

### 2.6 Persistence

`saveMeta`, under the lock:

- `unsaved` is NO → return YES (nothing to write).
- `effect.apiManager.paramSetAPIv5` is nil → leave `unsaved` set and return NO. A later
  flush retries.
- otherwise → `setCustomParameterValue:self toParameter:kFxParameterId_InstanceMeta
  atTime:kCMTimeZero`, then clear `unsaved`, return YES.

`unsaved` and `setUnsaved:` are locked. The manager persists itself as the InstanceMeta
custom-parameter value.

### 2.7 Locking

`lock` always succeeds. `lockWithinTime:` takes a single `tryLock` when the time is
non-positive, otherwise waits up to the given seconds with `lockBeforeDate:`. `unlock`
releases. The lock is recursive, so nested calls such as `setTags:` invoking `addTag:` are
safe. Coverage is full across every public method, and the public triple lets a caller
compose a multi-step atomic edit.

---

## 3. The `FxGripMeta` extension

`Extensions/FxGripMeta.{h,m}`. `FxGripMeta : FxGripCustomExtension`.

### 3.1 `meta` and `hasMeta`

`FxGripTileableEffect (Meta)` category:

- `meta` → the loaded extension's `manager`, nil when meta is not managed.
- `hasMeta` → whether the `FxGripMeta` extension is loaded (`extensionForClass:` non-nil).
- `newMetaExtension` → a fresh `FxGripMeta`.

Extension activation follows the standard `FxGripExtension` path driven by the plist, so
meta management stays opt-in.

### 3.2 Lifecycle

| Handler | Priority | Behavior |
|---|---|---|
| `extLoadWithEffect:` | — | Installs a one-time observer on `FxGripTileableEffectResolveMetaName` that writes `manager` into the notification userInfo. This bridges meta resolution for a plain host. |
| `extAddParameters:` | −20 | Registers the hidden InstanceMeta parameter (see below). |
| `extAddedToDocument:` | −18 | Loads the stored manager through `paramGetAPIv6 getCustomParameterValue:` at ID 9995. A decoded manager gets `setEffect:` and `setUnsaved:NO`, and any pre-load seeded records merge into it. Otherwise a fresh manager stands. |
| `extAPIParameterAdd:` | — | Seeds a record for the new parameter, then flushes when not flag-cached. |
| `extAPIParameterRemove:` | — | Removes the record, then flushes under the same guard. |
| `extParameterChanged:` | −10 | The target-preset trigger (see 3.4). |
| `extFlush:` | −14 | `saveMeta`, one step after `FxGripParameterData` so the meta write lands last. |
| `valueAtTime:` | — | Returns the manager as the custom-parameter value. |

The InstanceMeta parameter registers with name `"Plugin Data"`, ID 9995, type Custom, and
flags `DONT_DISPLAY`, `HIDDEN`, `NOT_ANIMATABLE`, `PRESETNOMETA`, `PRESETNOVALUE`,
`NO_DEBUG`, `NO_STATE`.

### 3.3 Record seeding (per-instance preset capabilities)

Target-preset capabilities live in the instance record, not only in the static
configuration, so a document can carry per-instance customization. `seedRecordForParameter:`
reads the configuration and transfers, additively:

- **tags** → `addTag:` for each configured tag (add is deduped);
- **metadata** → `setMeta:forKey:` for each configured key that the record lacks;
- **record keys** → each configuration key that begins with `"target"` or equals
  `"resetvalue"`, written only when the record lacks it.

Existing entries always win, including customization restored from a document. Seeding
writes the live record directly, so it raises `setUnsaved:` by hand; a configuration that
carries only target or reset keys still flushes. Removing a record entry restores the
configuration default at the next seed.

### 3.4 The target-preset trigger

`extParameterChanged:` observes `FxGripTileableEffectParameterChangedName` at priority −10,
after the per-parameter change handlers. For the changed parameter, in order:

1. `applyTargetPresetForParameter:atTime:options:` with `Values | Flags | Tags | Meta`;
2. the record's `kFxParameterProperty_ResetValue`, when present, through
   `+[FxGripPreset setParameterValue:toParameter:atTime:withAPI:]` on the v5 setting API;
3. `applyTargetPresetForParameter:atTime:options:` with `Names` only.

Names apply last because Final Cut Pro misreports a String parameter's value when a name
changes earlier in the same pass. The handler reads the time from the notification userInfo,
defaulting to `kCMTimeZero`, and returns early when the tags API does not respond to the
trigger selector.

---

## 4. Meta and tag API surface

Both wrappers are FxGrip-implemented and reach the manager through the effect's host meta
accessor, guarded by whether meta is managed.

### 4.1 `FxGripMetaAPI_v1`

`APIAccessing/FxGripMetaAPI_v1.{h,m}`. `FxGripMetaAPI_v1 : FxGripCommonAPI<FxMetaAPI_v1>`.
Introduced in FxGrip 1.0. The nine metadata methods live here, split into their own protocol
so FxGrip does not extend Apple's dynamic-parameter protocol. `FxGripAPIAccessing` vends the
wrapper as `metaAPIv1`.

Each method forwards to the host meta manager. When meta is absent:
`metaCountFromParameter:` returns −1; the four `NSError*` methods return a no-meta error;
`parameter:hasMetaKey:error:` sets `*error` and returns NO; the three `BOOL` accessors
return NO. The no-meta error uses `FxGripPlugErrorDomain`, code
`kFxError_ThirdPartyDeveloperStart + parameterID`, message `"No meta manager for parameter
(%u)."`.

### 4.2 `FxGripParameterTagsAPI_v1`

`APIAccessing/FxGripParameterTagsAPI_v1.{h,m}`, protocol
`APIAccessing/FxParameterTagsAPI_v1.h`.
`FxGripParameterTagsAPI_v1 : FxGripCommonAPI<FxParameterTagsAPI_v1>`. Introduced in
FxGrip 1.0. `FxGripAPIAccessing` vends the wrapper as `paramTagsAPIv1`.

The protocol carries the ten tag methods and the preset-core methods. The ten tag methods
forward to the host meta manager with the same guard as the meta API: `tags` and
`parameterTags:` return nil, `tagCount` returns 0, `tagCount:` returns −1,
`parametersWithTag:` returns nil, `parameter:hasTag:error:` sets `*error` and returns NO,
and the four `NSError*` mutators return a no-meta error.

The preset-core methods are covered in section 5.

---

## 5. The preset core

The preset core lives on `FxGripParameterTagsAPI_v1`. It resolves definitions by tag and
applies them through one method, shared by target presets and file presets.

### 5.1 Canonical preset shape

A preset definition is an `NSDictionary` of up to five sections. Each section maps a
parameter-ID key to a payload.

| Section | Key | Payload |
|---|---|---|
| Names | `kFxParameterProperty_TargetPresetNames` (`"names"`) | new display name |
| Flags | `kFxParameterProperty_TargetPresetFlags` (`"flags"`) | flag spec: an array or a divider-split string, `+`/`-` prefixes |
| Tags | `kFxParameterProperty_TargetPresetTags` (`"tags"`) | tag spec, same parsing |
| Values | `kFxParameterProperty_TargetPresetValues` (`"values"`) | typed value (see 5.3) |
| Meta | `kFxParameterProperty_TargetPresetMeta` (`"meta"`) | `{metaKey: value}` |

`FxGripPresetOptions` gates the sections: `Names = 1<<0`, `Flags = 1<<1`, `Tags = 1<<2`,
`Values = 1<<3`, `Meta = 1<<4`, `All = NSUIntegerMax`.

Section keys accept both `NSString` and `NSNumber` parameter IDs. `FxGripSectionParameterIDs`
normalizes a section's key set to numbers, and `FxGripSectionEntry` looks up a value by
number and then by string. Plist-authored definitions carry string keys; code-built
definitions carry numbers; both resolve.

### 5.2 Definition resolution

`presetDefinitionForTag:` reads the plugin's `pluginPresets` table (the plist `"presets"`
table) and returns the entry for the tag.

`targetPresetForParameter:record:` resolves the definition for one parameter:

- the instance meta record wins when meta is managed (`parameterData:`);
- the configuration is the fallback (`FxGripHostConfigurationForParameter`);
- neither present → nil;
- the resolving dictionary is written to `*record` when the caller supplies the out-pointer;
- the record's `kFxParameterProperty_TargetPreset` value is read directly. A string value
  re-resolves through `presetDefinitionForTag:` and logs when the tag has no definition.

The record is read directly rather than through a dictionary accessor that requires a
`"name"` key, because records do not carry one.

### 5.3 Application

`applyPreset:atTime:options:presetFlags:source:tag:` applies a resolved definition. The
sections apply in a fixed order — values, flags, tags, meta, names — with names last for the
Final Cut Pro name/String ordering constraint. Each section runs only when its option bit is
set and its payload is present.

- **Values** → for each ID passing the tag boundary,
  `+[FxGripPreset setParameterValue:toParameter:atTime:withAPI:]` on the v5 setting API. The
  primitive dispatches on parameter type: RGBA copies alpha and the RGB channels, RGB copies
  the channels, Point copies `x`/`y`, String and FontMenu set the string, Toggle sets the
  bool, Int and Menu set the int, Custom recursive-merges the value dictionary into the
  current value, and any other numeric type sets a float.
- **Flags** → per ID, read the stored flag word from `FxGripParameterData` (which carries
  the FxGrip-internal bits), parse the `+`/`-` spec, and write through the v6 setting API
  only when a bit changes.
- **Tags** → per ID whose stored flags lack `PRESETNOTAGS`, parse the spec and call
  `addTag:` or `removeTag:`.
- **Meta** → per ID whose stored flags lack `PRESETNOMETA`, call `setMeta:forKey:` for each
  entry.
- **Names** → per ID, `setParameter:name:` on the v3 dynamic API.

A per-entry failure logs and continues. The method returns the first error, or nil when
every entry succeeds.

### 5.4 The tag boundary

The tag boundary keys off the definition's source, carried by the `source:` argument
(`FxGripPresetSource`: `Plugin` or `File`):

- source `Plugin` (the plist table or the instance record) → the boundary is off, and every
  section applies to the IDs the definition names. These IDs ship with the plugin and are
  current by construction.
- source `File` (a loaded `.fxpreset`), with a tag and without
  `kFxParameterPreset_IgnoreTagBoundary` → each ID must belong to `parametersWithTag:tag`. A
  saved preset may target IDs that a later plugin version reassigned, so the membership
  filter protects every section.

Membership is computed once per call.

### 5.5 The target-preset trigger entry

`applyTargetPresetForParameter:atTime:options:` is the menu/toggle trigger:

1. resolve the definition and record; a nil record → return NO.
2. read the configuration's parameter type; not Menu and not Toggle → return YES.
3. read the index: Menu through `getIntValue:`, Toggle through `getBoolValue:` mapped to 0
   or 1; an API failure → return NO.
4. a nil definition → return YES.
5. resolve the entry, name first: `menuEntryNameForParameter:configuration:index:` prefers
   the live menu from `FxGripParameterData` over the configuration items, and a resolved
   name indexes a dictionary definition by name. Otherwise an array definition uses a
   bounds-checked subscript, and a dictionary definition tries `@(index)`, the index string,
   then `kFxParameterProperty_Default`.
6. a non-dictionary entry → return YES.
7. apply with `source:FxGripPresetSourcePlugin`. The boundary tag is the record's
   `targetpreset` string when the definition resolved through a tag, otherwise nil.

The bounds check replaces the raw subscript that would raise `NSRangeException` for an
out-of-range menu value.

### 5.6 `getMetaKeys:forPreset:fromParameter:`

Resolves the tag definition, reads its `"meta"` section for the parameter, and returns the
metadata keys the definition carries for that ID. A nil out-pointer, an unresolved tag, or a
missing section each has a defined result (error, error, empty list).

### 5.7 Creation-time defaults

`+[FxGripParameterUtility applyTargetPresetDefaults:pluginPresets:]` applies target-preset
defaults while the parameter list is built. For each Menu or Toggle configuration with a
resolvable definition, it indexes by the configuration's default value and maps the
default-index names, flags, and tags into the configuration dictionaries.

`-addParametersWithError:` calls it inside the `FxGripTileableEffectAddParametersName`
post-block, immediately after `flattenDictionaryParameters:`, so extension-added parameters
participate and the initial UI state matches each default selection. This path runs before
any host API exists and stays outside the tags API.

---

## 6. The file-preset layer

`APIAccessing/FxGripPreset.{h,m}` and `APIAccessing/FxGripPresetsAPI_v1.{h,m}`.

### 6.1 `FxGripPreset`

The model carries the parameter payload (`parameterValues`, `parameterMeta`,
`parameterTags`), preset identity (`uuid`, `name`, `tag`, `createdTime`, `framework`,
`createdByParameterId`), and plugin identity (`pluginAuthor`, `pluginLocalizedName`,
`pluginUuid`, `pluginVersion`, `productId`). Object properties are `copy`.

- `presetSections` maps `parameterValues` → `"values"`, `parameterTags` → `"tags"`,
  `parameterMeta` → `"meta"`, so a file preset feeds the same core as a target preset. A
  section the preset does not carry is absent.
- `+setParameterValue:toParameter:atTime:withAPI:` and `+getParameterValue:…` are the typed
  apply and capture primitives. The setter resolves the type from the dynamic API and falls
  back to shape inference when the type is unknown; the getter reads the type from the
  dynamic API. Both cover RGBA, RGB, Point, String, FontMenu, Toggle, Int, Menu, Custom, and
  the numeric default.
- `savePresetToURL:` writes an XML property list; `+loadPresetFromURL:` reads one back into a
  new preset.

### 6.2 `FxGripPresetsAPI_v1`

`FxGripPresetsAPI_v1 : FxGripCommonAPI<FxPresetsAPI_v1>`. `FxGripAPIAccessing` vends it as
`presetsAPIv1`. Every method carries real logic.

| Method | Behavior |
|---|---|
| `generatePreset:fromLabel:` | Captures each parameter's value, tags, and metadata, skipping a section when the parameter's stored flags opt out (`PRESETNOVALUE`, `PRESETNOTAGS`, `PRESETNOMETA`). Fills identity fields: a fresh UUID, framework `"FxGrip"`, an ISO-8601 created time, and plugin identity. |
| `setPreset:options:atTime:` | Checks compatibility unless `IgnoreCompatibility`, then applies the preset's sections through the tags core. `setPreset:options:` delegates at `kCMTimeZero`. |
| `savePreset:remap:` / `loadPreset:remap:` | Run the save/open panel and write or read the file. |
| `pluginPresetURL`(`:`) / `userPresetURL`(`:`) | Locate the plugin and managed user preset folders, and their per-tag subfolders. |
| `presetsForTag:` | Merges plugin presets and user presets. |
| `pluginPresetsForTag:` / `userPresetsForTag:` | Enumerate the plugin and user sources. |
| `observeTag:observer:` | Watches the managed per-tag folder with a `BEPathWatcher`. |
| `compatiblePreset:` | Section 6.5. |

### 6.3 Storage model

Two sources, different lifecycles:

- **Plugin, shipped with the bundle.** `pluginPresetsForTag:` merges the plist `"presets"`
  table with `.fxpreset` files under `<bundle>/Contents/Resources/Presets/<tag>/`. A plist
  tag entry is either one definition dictionary (named after the tag) or a name-keyed table
  (one preset per named definition, sorted).
- **User-saved, in a managed folder.** `userPresetsForTag:` enumerates `.fxpreset` files
  under `~/Library/Application Support/<company>/<plugin name>/<tag>/`. Both folder levels
  are version-agnostic, derived from the plugin identity, and follow the Core Audio preset
  convention. The company and plugin names are sanitized for the filesystem. The URL
  accessors do not create the folder; the reveal and save actions create it on demand.

`.fxpreset` files are XML property lists. A file without a tag inherits the folder's tag; a
file without a name takes the filename minus extension.

### 6.4 FxFactory interchange

A written file carries two flat, sibling key sets in one property list, so FxFactory reads
FxGrip files and FxGrip reads FxFactory files:

- seven FxFactory keys (`FxFactoryPresetCreatedByParameterID`,
  `FxFactoryPresetParameterValues`, `FxFactoryPresetPlugInAuthor`,
  `FxFactoryPresetPlugInLocalizedName`, `FxFactoryPresetPlugInUUID`,
  `FxFactoryPresetPlugInVersion`, `FxFactoryPresetProductID`);
- seven FxGrip sibling keys (`FxGripPresetFramework`, `FxGripPresetUUID`,
  `FxGripPresetDisplayName`, `FxGripPresetTag`, `FxGripPresetCreatedTime`,
  `FxGripPresetParameterMeta`, `FxGripPresetParameterTags`).

`parameterValues`, `parameterMeta`, and `parameterTags` are written with string keys. A
reader ignores keys it does not know and drops values of the wrong class, so both directions
degrade to the shared subset. `pluginLocalizedName` is typed `id`: a per-language dictionary
round-trips verbatim, and the presets parameter flattens it to a display string when needed.

An FxFactory file carries none of the FxGrip sibling keys, so a read yields values and plugin
identity only, with no FxGrip tag, name, created time, metadata, or tags. The file layer
supplies the tag and name from the containing folder.

### 6.5 Compatibility and the remap gap

`compatiblePreset:` matches by plugin UUID: it accepts a case-insensitive match against the
effect's plugin UUID or any entry in the supported-plugins list, and rejects a preset with no
plugin UUID. `setPreset:options:atTime:` skips the check when
`kFxParameterPreset_IgnoreCompatibility` is set.

The colour-space and key-remap machinery is declared but not yet wired. `kFxFactoryPresetKeyMap`,
`kFxPresetProperty_RemapValues`, and `kFxPresetProperty_ColorSpace` have no consumer, and the
`remap:` argument of `savePreset:remap:` and `loadPreset:remap:` is ignored — both methods
write and read through the identity FxFactory-key mapping baked into `presetDictionary` and
`+loadPresetFromURL:`. Colour-space value remapping on load is a planned addition.

---

## 7. `FxGripPresetsParameter`

`Parameters/Presets/FxGripPresetsParameter.{h,m}`. `FxGripPresetsParameter :
FxGripMenuParameter`, type `FxParameterType_Presets` (124), type string `"presets"`. It is
the browse-and-apply popup.

- **Menu order:** `Default`, a separator, the user preset names, a separator, the plugin
  preset names, a separator, `Reveal User Presets in Finder...`, `Save Preset`. An empty
  section drops its separator. The tag is the parameter configuration's first tag.
- **Selection dispatch by name:** on change, the parameter resolves the selected entry name
  from the live menu (`FxGripParameterData` stored menus) so a drifted index still resolves.
  A preset name applies through `setPreset:options:atTime:` (user presets shadow plugin
  presets of the same name) and records the name in the instance meta under
  `kFxMetaProperty_SelectedPreset` (`"selectedPreset"`). `Default` records the state and
  applies nothing. `Reveal...` opens the managed folder in Finder. `Save Preset` captures
  the current state, stamps the tag, and runs the save panel.
- **Selection stability:** the host stores a menu selection as an int. The recorded name
  keeps a document stable across appended, removed, or reordered entries; restoration maps
  the name back to its current index and falls back to `Default`.
- **Live refresh:** the parameter watches the managed per-tag folder with a `BEPathWatcher`.
  A file change rebuilds the popup on the host through the v3 dynamic API's
  `setPopupMenuParameter:entries:defaultValue:` inside an out-of-band access context on the
  main queue, then remaps the recorded selection name to its new index. The parameter's
  notification priority is −8, after the meta trigger's target-preset pass at −10.

---

## 8. Constants and flags

### Reserved parameter IDs (`FxGripTypes.h`)

| Constant | Value |
|---|---|
| `kFxParameterId_MLCache` | 9993 |
| `kFxParameterId_AnalysisData` | 9994 |
| `kFxParameterId_InstanceMeta` | 9995 |
| `kFxParameterId_DebugActivator` | 9996 |
| `kFxParameterId_DebugMenu` | 9997 |
| `kFxParameterId_ParameterData` | 9998 |
| `kFxParameterId_ApplePluginData` | 9999 (not accessible) |

### Meta and target-preset keys (`FxGripTypes.h`)

- `kFxMetaProperty_Tags` `"tags"`, `kFxMetaProperty_Parameters` `"parameters"`,
  `kFxMetaProperty_ParamId` `"id"`, `kFxMetaProperty_ParamTags` `"tags"`,
  `kFxMetaProperty_ParamMeta` `"meta"`.
- `kFxParameterProperty_TargetPreset` `"targetpreset"`, with sections `…Names` `"names"`,
  `…Flags` `"flags"`, `…Tags` `"tags"`, `…Values` `"values"`, `…Meta` `"meta"`.
  `kFxParameterProperty_TargetPrefix` `"target"`.
- `FxGripPresetOptions` (section 5.1). `FxGripPresetSource`: `SourcePlugin = 0`,
  `SourceFile`.

### Preset flags (`Parameters/FxGripParameterFlags.h`)

- `kFxParameterFlag_PRESETNOMETA` and `kFxParameterFlag_PRESETNOTAGS` are the per-parameter
  opt-outs from preset metadata and tag handling. They apply to capture and application in
  both the target-preset and file paths.
- `kFxParameterFlag_CACHE`, `kFxParameterFlag_CACHEDIRTY`, `kFxParameterFlag_SAVING` are the
  FxGrip-internal deferred-write bits, above the Apple flag range. `RemoveTempFlags` strips
  the three. `FxGripParameterData` owns this machinery; `FxGripMetaManager` does not.

### Preset file keys (`APIAccessing/FxGripPreset.h`, `FxGripPresetsAPI_v1.h`)

- `kFxPreset_Extension` `"fxpreset"`; the `kFxPresetProperty_*` system keys; the
  `kFxFactoryPresetKey_*` file keys; the `kFxGripPresetKey_*` sibling file keys.
- `kFxFactoryPresetKeyMap`, `kFxPresetProperty_ColorSpace`, `kFxPresetProperty_RemapValues`
  are declared for the planned remap; no code path consumes them yet (section 6.5).

---

## 9. API wiring

`FxGripAPIAccessing` vends three FxGrip-implemented wrappers: `metaAPIv1`
(`FxMetaAPI_v1`), `paramTagsAPIv1` (`FxParameterTagsAPI_v1`), and `presetsAPIv1`
(`FxPresetsAPI_v1`).

`apiForProtocol:bypass:` gates a host-backed wrapper on a non-nil host API (`if (api && …)`).
The three FxGrip-implemented protocols bypass that gate: no host vends them, so gating on
`api` would leave them permanently unreachable. `FxGripMetaAPI_v1` is constructed with the
effect alone; `FxGripParameterTagsAPI_v1` and `FxGripPresetsAPI_v1` are constructed with the
effect and a normally-nil host API. `@protocol FxParameterTagsAPI_v1` is declared in exactly
one header.

---

## 10. Thread safety

- `FxGripMetaManager` guards every public method with its recursive lock, and the public
  `lock` / `lockWithinTime:` / `unlock` triple lets a caller compose a multi-step atomic
  edit. `saveMeta` performs its host write while holding the lock; the recursive lock lets a
  notification handler triggered by that write re-enter without deadlock.
- `FxGripMeta` serializes its own load and flush with `@synchronized (self)`, matching
  `FxGripParameterData`.
- The preset core holds no state of its own. It runs on the host's parameter-change thread
  and touches only the API wrappers, the configuration records, and the meta manager.
- The file layer's `BEPathWatcher` callbacks arrive on a GCD queue. A menu rebuild re-enters
  through the wrappers inside an out-of-band access context on the main queue.

---

## 11. Test coverage

XCTest files in `FxGripTests/`, one per class:

| File | Focus |
|---|---|
| `FxGripMetaManagerTests.m` | Records, tags with reverse-index scrubbing, per-key metadata, `unsaved` tracking, `saveMeta`, secure-coding round-trip, copy independence, equality. |
| `FxGripMetaTests.m` | The extension: InstanceMeta registration, record seeding on add and remove, document adoption and merge, the `parameterChanged` section/reset/name ordering, flush-once-per-mutation, API sentinels versus forwarding. |
| `FxGripParameterTagsAPI_v1Tests.m` | Definition resolution and record precedence, section ordering, option gating, the plugin/file tag boundary and `IgnoreTagBoundary`, `+`/`-` flag and tag specs, the `PRESETNOTAGS` / `PRESETNOMETA` opt-outs, name application, error continuation. |
| `FxGripPresetTests.m` | The value codec: per-type set and get, shape inference without a dynamic API, rejection of nil, `NSNull`, and mismatched values. |
| `FxGripPresetFileTests.m` | The file form: the fourteen-key property list, omission rules, string-key normalization, `presetSections`, plist round-trips, malformed input, and an FxFactory sample read. |
| `FxGripPresetsAPI_v1Tests.m` | `compatiblePreset:` matching, `setPreset:` routing through the core, option handling, capture under string keys, identity fields, and the opt-out flags. |
| `FxGripPresetsParameterTests.m` | The popup: tag selection, menu sections and separators, registration and default, apply on change, index no-ops, user-shadows-plugin resolution, stored-menu resolution. |
