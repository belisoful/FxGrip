# FxPlug SDK Change Log

Symbol-level change log for the Apple FxPlug 4 SDK as consumed by FxGrip. Each version section records what the installer, the headers, the binaries, the Xcode template, and the bundled examples add, change, and remove relative to the previous version. Apple's release notes describe runtime fixes without naming symbols; this file records the facts the headers and installers show.

**Keep this file current.** When Apple ships a new FxPlug SDK, add a section for it before FxGrip adopts the new headers. The procedure is in [Maintenance](#maintenance). The standing instruction lives in the task list `Local/FxGrip Todo`.

## Sources and method

| Source | Location | Provides |
|---|---|---|
| SDK headers and `.tbd` stubs | `Local/Frameworks v4.3.3`, `v4.3.4`, `v4.3.5` | Header diff, dylib version, deployment target, exported symbols |
| SDK installers | `Local/FxPlug_SDK_4.3.3.dmg`, `4.3.4.dmg`, `4.3.5.dmg` | Build date, toolchain, framework `Info.plist`, Xcode template, examples |
| Apple release notes | `Local/FxPlug_SDK_4.3.5_Release_Notes_and_prior_change_notes.not_well_defined.pdf` | Runtime changes that headers do not show |

Method: `diff -ru` of the header directories, `diff` of the `.tbd` stubs, `lsbom` of the installer payload, `diff -rq` of the installer examples and Xcode template, and `plutil -p` of the framework `Info.plist`. The headers in `Local/Frameworks v*` are byte-identical to the headers in the matching installer payload (verified 2026-09-04).

Date convention: the version date is the installer build time encoded in the package version string (`4.3.x.1.<unix-time>`), expressed in UTC. Apple does not publish per-version release dates; the PDF footer reads "October 2023" for every version. Header file timestamps fall on the installer build day (4.3.3) or four to six days before it (4.3.4, 4.3.5).

Availability (2026-09-04): Apple's developer downloads list FxPlug SDK 4.3.4 and 4.3.5. FxPlug SDK 4.3.3 is no longer listed; the copies in `Local/` are the only reference for it.

## Version summary

| Version | Date (UTC) | FxPlug dylib | PluginManager dylib | Built with | Minimum macOS | FxPlug headers |
|---|---|---|---|---|---|---|
| 4.3.3 | 2025-05-28 | 44000.1.12 | 44000.1.2 | Xcode 16.1 (16B40), macOS 15.1 SDK | 11.0 | 24 |
| 4.3.4 | 2026-01-28 | 44000.5.20 | 44000.5.6 | Xcode 26.2 (17C52), macOS 26.2 SDK | 13.0 | 29 |
| 4.3.5 | 2026-06-17 | 45000.0.9 | 44000.5.6 | Xcode 26.4 (17E192), macOS 26.4 SDK | 13.0 | 29 |

Constants across all three versions:

- `PluginManager.framework` ships four headers (`PROAPIAccessing.h`, `PROPlugInBundleRegistration.h`, `PROPlugProtocols.h`, `PluginManager.h`). They are byte-identical in every version.
- `CFBundleVersion` is `18567.3` in every framework build. The `.tbd` `current_version` is the value that distinguishes builds.
- The `.tbd` export list is identical: 10 data globals (`_FxPlugErrorDomain`, `_kFxRect_Empty`, `_kFxRect_Infinite`, `_kKey_Character`, `_kKey_Command`, `_kKey_Modifiers`, four `_kKeyChar_*Arrow`), 5 classes (`FxImageTile`, `FxImageTileRequest`, `FxMatrix44`, `FxPrincipal`, `FxTaggedMenuEntry`), 1 function (`_FxRectsAreEqual`).
- `SDKSettings.plist` requires Xcode 15.0 (`MinimumSupportedToolsVersion`).
- Framework `compatibility_version` is 3.

## FxPlug 4.3.3 (2025-05-28)

Baseline for this log. Installer `FxPlug_SDK_4.3.3.dmg`, package version `4.3.3.1.1748474831`. Apple's release-notes PDF has no 4.3.3 entry; its history goes from 4.3.2 to 4.3.4.

### Requirements

- Minimum macOS 11.0 (`LSMinimumSystemVersion` and `.tbd` `min_deployment` for `x86_64-macos` and `arm64-macos`).
- Framework built with Xcode 16.1 against the macOS 15.1 SDK.

### API landscape

Declarations in each `FxPlug.framework` header. Later versions add to this table; nothing in it is removed through 4.3.5.

| Header | Declarations |
|---|---|
| `Fx3DAPI.h` | `Fx3DAPI_v5` |
| `FxAnalysis.h` | `FxAnalyzer`, `FxAnalysisAPI`, `FxAnalysisAPI_v2` |
| `FxColorGamutAPI.h` | `FxColorGamutAPI_v2` |
| `FxCommandAPI.h` | `FxCommandHandler`, `FxCommandAPI`, `FxCommandAPI_v2` |
| `FxCustomParameterUI.h` | `FxCustomParameterViewHost_v2`, `FxCustomParameterActionAPI_v4` |
| `FxDynamicParameterAPI.h` | `FxDynamicParameterAPI_v3` |
| `FxImageTile.h` | class `FxImageTile` |
| `FxImageTileRequest.h` | class `FxImageTileRequest`, enum `FxImageTileRequestSource` |
| `FxKeyframeAPI.h` | `FxKeyframeAPI_v3` |
| `FxLightingAPI.h` | `FxLightingAPI_v3`, struct `FxLight`, enum `FxLightType` |
| `FxMatrix.h` | class `FxMatrix44`, `typedef double Matrix44Data[4][4]` |
| `FxOnScreenControl.h` | `FxOnScreenControl_v4` |
| `FxOnScreenControlAPI.h` | `FxOnScreenControlAPI`, `FxOnScreenControlAPI_v2`, `FxOnScreenControlAPI_v3`, `FxOnScreenControlAPI_v4` |
| `FxParameterAPI.h` | `FxParameterCreationAPI_v5`, `FxParameterCreationAPI_v6`, `FxParameterRetrievalAPI_v6`, `FxParameterRetrievalAPI_v7`, `FxParameterSettingAPI_v5`, `FxParameterSettingAPI_v6`, `FxCustomParameterInterpolation_v2`, class `FxTaggedMenuEntry` |
| `FxPathAPI.h` | `FxPathAPI_v3` |
| `FxPlugSDK.h` | Umbrella header |
| `FxPrincipalAPI.h` | `FxPrincipalDelegate`, `FxPrincipalAPI`, class `FxPrincipal` |
| `FxProjectAPI.h` | `FxProjectAPI`, `FxProjectAPI_v2` |
| `FxRemoteWindowAPI.h` | `FxRemoteWindowAPI`, `FxRemoteWindowAPI_v2`, `FxRemoteWindowAPI_v3` |
| `FxTileableEffect.h` | `FxTileableEffect` |
| `FxTimingAPI.h` | `FxTimingAPI_v4` |
| `FxTypes.h` | Property keys, parameter flags, `FxPoint2D`, `FxPoint3D`, `FxRect`, error codes |
| `FxUndoAPI.h` | `FxUndoAPI` |
| `FxVersioningAPI.h` | `FxVersioningAPI` |

Build guards: `STUDIO_LITE` is the only lite-build macro. `FxTypes.h` imports `<OpenGL/OpenGL.h>` in normal builds and `<CoreGraphics/CoreGraphics.h>` in lite builds. `FxTimingAPI.h` and the umbrella gate several imports on `!STUDIO_LITE`, with `// FIXME iOS` markers in the umbrella.

### Features 4.3.3 does not have

- Drop-frame timecode queries. `FxTimingAPI_v4` is the newest timing protocol; no method reports whether the timeline or an input uses drop-frame timecode.
- Separate custom-parameter headers. Both custom-parameter protocols live in `FxCustomParameterUI.h`, which imports `<Cocoa/Cocoa.h>`.
- A separate header for `FxOnScreenControlAPI_v4`. The `setCursor:` protocol is declared inside `FxOnScreenControlAPI.h`.
- Platform-neutral AppKit aliases (`FxXPColor`, `FxXPView`, `FxXPViewController`, `FxXPWindow`). `FxLight.color` is typed `NSColor *`; `FxRemoteWindowAPI` reply blocks pass `NSView *`.
- The `NSCoder (FxCoding)` category for encoding `NSRect` and `NSPoint`.
- Nullability annotations on `FxMatrix44`.
- The `FLEXO_LITE` build guard.
- A timecode example (`FxTimeCodeGenerator`).
- macOS 13 as the floor; 4.3.3 still deploys to macOS 11.

## FxPlug 4.3.4 (2026-01-28)

Installer `FxPlug_SDK_4.3.4.dmg`, package version `4.3.4.1.1769575879`. Headers dated 2026-01-24.

### Requirements and binaries

- Minimum macOS raised from 11.0 to 13.0 in both frameworks (`LSMinimumSystemVersion`; `.tbd` `min_deployment` for both slices).
- Framework built with Xcode 26.2 (17C52) against the macOS 26.2 SDK.
- `FxPlug` dylib `current_version` 44000.1.12 → 44000.5.20. `PluginManager` 44000.1.2 → 44000.5.6.
- Exported symbols unchanged.
- Installer payload 131 → 136 entries. The delta is exactly the header changes below.

### Headers added (6)

| Header | Contents | Notes |
|---|---|---|
| `FxCustomParameterActionAPI.h` | `FxCustomParameterActionAPI_v4`: `startAction:`, `endAction:`, `currentTime` | Host API for custom inspector views. Moved verbatim from `FxCustomParameterUI.h`. Imports `FxTypes.h` and `NSCoder+FxCoding.h`; no Cocoa import. No include guard, matching the old header. |
| `FxCustomParameterViewHost.h` | `FxCustomParameterViewHost_v2`: `createViewForParameterID:` | Plug-in protocol for custom inspector views. Moved verbatim from `FxCustomParameterUI.h`. Imports `<Cocoa/Cocoa.h>`. Gains an include guard. |
| `FxOnScreenControlAPI_v4.h` | `FxOnScreenControlAPI_v4 <FxOnScreenControlAPI_v3>`: `setCursor:` | Moved out of `FxOnScreenControlAPI.h`. Imports `<AppKit/AppKit.h>` for `NSCursor`. |
| `FxPlatformTypes.h` | Imports `FxTypes_MacOS.h` when `TARGET_OS_OSX`, else `FxTypes_iOS.h` | Platform dispatch for the `FxXP*` aliases. `FxTypes_iOS.h` is not shipped; only the macOS branch compiles. |
| `FxTypes_MacOS.h` | `typedef NSColor FxXPColor`, `typedef NSView FxXPView`, `typedef NSViewController FxXPViewController`, `typedef NSWindow FxXPWindow` | Platform-neutral names for AppKit types in host API signatures. Imports `AppKit/NSColor.h`, `NSView.h`, `NSViewController.h`, `NSWindow.h`. |
| `NSCoder+FxCoding.h` | `NSCoder (FxCoding)`: `fxPlugEncodeRect:forKey:`, `fxPlugDecodeRectForKey:`, `fxPlugEncodePoint:forKey:`, `fxPlugDecodePointForKey:` | Geometry coding helpers. On non-macOS targets it also aliases `NSPoint`, `NSSize`, `NSRect` to the `CG*` types. First shipped in 4.3.4; the file comment is dated 2021. |

### Header removed (1)

- `FxCustomParameterUI.h`. Its two protocols move to `FxCustomParameterViewHost.h` and `FxCustomParameterActionAPI.h` with identical method signatures and documentation. Source that imports `<FxPlug/FxCustomParameterUI.h>` directly no longer compiles. Source that imports `<FxPlug/FxPlugSDK.h>` is unaffected.

### Headers changed (8)

`FxOnScreenControlAPI.h`

- `FxOnScreenControlAPI_v4` removed from this header (now in `FxOnScreenControlAPI_v4.h`).
- In `FxOnScreenControlAPI_v3`: `- (NSRect)objectBounds` → `- (CGRect)objectBounds`; `- (NSRect)inputBounds` → `- (CGRect)inputBounds`. `NSRect` is a typedef of `CGRect` on 64-bit macOS. No source or ABI change for macOS plug-ins.

`FxLightingAPI.h`

- `#import <Cocoa/Cocoa.h>` removed.
- `FxLight.color`: `__unsafe_unretained NSColor *` → `__unsafe_unretained FxXPColor *`. Same type on macOS.
- `FxLightingAPI_v3` wrapped in `#if !STUDIO_LITE && !FLEXO_LITE`. `FxLight` and `FxLightType` stay unconditional.

`FxRemoteWindowAPI.h`

- Adds `#import <FxPlug/FxTypes.h>`.
- Reply block parameter `NSView *parentView` → `FxXPView *parentView` in `remoteWindowOfSize:reply:` and `remoteWindowWithMinimumSize:maximumSize:reply:`. Same type on macOS.

`FxMatrix.h`

- Interface wrapped in `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END`.
- `Matrix44Data` parameters annotated `_Nonnull` on `initWithMatrix44Data:`, `initWithColorMatrix44Data:`, `setMatrix:`.
- Effect: the `FxMatrix44 *` parameters of `initWithFxMatrix:` and `initWithInverseOfFxMatrix:`, every `init` return value, and the `- (Matrix44Data *)matrix` return value become non-null by default. Swift imports the initializers as non-failable and `matrix()` as a non-optional pointer. Objective-C callers that pass `nil` get a `-Wnonnull` diagnostic. Apple's 4.3.4 note about a crash in `-[FxMatrix44 initWithFxMatrix:]` matches this contract.

`FxTypes.h`

- Removed the `STUDIO_LITE`-conditional import of `<OpenGL/OpenGL.h>` (normal) / `<CoreGraphics/CoreGraphics.h>` (lite). Adds `#import <FxPlug/FxPlatformTypes.h>`, which brings in the four AppKit headers listed above.
- Effect: `FxTypes.h` no longer provides OpenGL declarations. `FxImageTile.h` still imports `<OpenGL/OpenGL.h>` on macOS and the umbrella imports `FxImageTile.h`, so umbrella users see no change. Direct importers of `FxTypes.h` that use OpenGL types must import OpenGL themselves.
- The `kFxParameterFlag_CUSTOM_UI` documentation now references `FxCustomParameterViewHost.h`.

`FxImageTile.h`

- `<OpenGL/OpenGL.h>` import wrapped in `#if !TARGET_OS_IPHONE`.

`FxAnalysis.h`

- Body wrapped in `#if !STUDIO_LITE && !FLEXO_LITE` inside the include guard.

`FxTimingAPI.h`

- Guard `#if !STUDIO_LITE` → `#if !STUDIO_LITE && !FLEXO_LITE`.

`FxPlugSDK.h` (umbrella)

- Guard set is now `!STUDIO_LITE && !FLEXO_LITE`. The `// FIXME iOS` markers are gone.
- Gated block: `FxTileableEffect.h`, `FxOnScreenControlAPI_v4.h`, `FxCustomParameterViewHost.h`, `FxOnScreenControlAPI.h`, `FxImageTile.h`, `FxAnalysis.h`, `FxCommandAPI.h`, `FxProjectAPI.h`, `FxRemoteWindowAPI.h`, `FxPrincipalAPI.h`.
- Unconditional: `FxOnScreenControl.h`, `FxOnScreenControlAPI.h` (a second import, harmless under `#import`), `FxCustomParameterActionAPI.h`, `FxParameterAPI.h`, `FxDynamicParameterAPI.h`, `FxTimingAPI.h`, `Fx3DAPI.h`, `FxVersioningAPI.h`, `FxKeyframeAPI.h`, `FxUndoAPI.h`, `FxPathAPI.h`, `FxColorGamutAPI.h`, `FxLightingAPI.h`.
- Net effect for macOS plug-ins: every header is still imported. `FxLightingAPI.h`, `FxRemoteWindowAPI.h`, and `FxPrincipalAPI.h` are no longer gated at the umbrella level; `FxLightingAPI.h` gates its own protocol instead.

Copyright-only changes (2025 → 2026, no code change) in 14 headers: `Fx3DAPI.h`, `FxColorGamutAPI.h`, `FxCommandAPI.h`, `FxDynamicParameterAPI.h`, `FxImageTileRequest.h`, `FxKeyframeAPI.h`, `FxOnScreenControl.h`, `FxParameterAPI.h`, `FxPathAPI.h`, `FxPrincipalAPI.h`, `FxProjectAPI.h`, `FxTileableEffect.h`, `FxUndoAPI.h`, `FxVersioningAPI.h`.

### Compatibility

- Protocol set: no protocol added or removed. `FxOnScreenControlAPI_v4` changes file.
- Source: plug-ins that import only `FxPlugSDK.h` compile unchanged. Plug-ins that import `FxCustomParameterUI.h` directly must switch to the two new headers. Plug-ins that depend on `FxTypes.h` or `FxLightingAPI.h` for transitive OpenGL or Cocoa declarations must add explicit imports. `FxMatrix44` call sites that pass `nil` produce warnings.
- Binary: no exported-symbol change. Plug-ins built against 4.3.4 require macOS 13.0.

### Examples and Xcode template

- Examples: the same nine projects. Every target gains `MACOSX_DEPLOYMENT_TARGET = 13.0`; project-level settings that were 11.0 stay 11.0 and are overridden. `version.plist` build number 283 → 313. No source file changes.
- Template `FxPlug 4.xctemplate`: `version.plist` and `locversion.plist` only.
- Apple's 4.3.4 note describes a Swift 6 workaround (replace `@NSApplicationMain` with `@main`; add an `NSLock` to the Swift `MTLDeviceCache`; mark it `@unchecked Sendable`). The shipped `FxBrightness` example still uses `@NSApplicationMain` and its `FxMTLDeviceCache.swift` has no lock. The template's `MetalDeviceCache.swift` already had a lock in 4.3.3.

### Apple release notes (runtime, no header counterpart)

Fixes: invalid media-folder URL from `FxProjectAPI`; memory leaks in `FxAnalysisAPI`; crash scheduling frames in interlaced projects through `FxTimingAPI`; plug-in instance leak; incorrect analysis inputs; crash in `-[FxMatrix44 initWithFxMatrix:]`; host crash on `-setVersionAtCreation:`; render jitter while dragging on-screen controls. Performance improvement for custom data parameters. Analysis plug-ins on XPC protocol version 10 or earlier may lose performance on 8K clips in Motion.

## FxPlug 4.3.5 (2026-06-17)

Installer `FxPlug_SDK_4.3.5.dmg`, package version `4.3.5.1.1781735395`. Headers dated 2026-06-11.

### Requirements and binaries

- Minimum macOS 13.0 (unchanged).
- Framework built with Xcode 26.4 (17E192) against the macOS 26.4 SDK.
- `FxPlug` dylib `current_version` 44000.5.20 → 45000.0.9. The source train moves from 44000 to 45000 (`SourceVersion` 44000005001000000 → 45000000004000000). `PluginManager` stays at 44000.5.6.
- Exported symbols unchanged. Installer payload unchanged (136 entries).

### Headers added

None.

### Headers removed

None.

### Headers changed (1)

`FxTimingAPI.h`

- New protocol `FxTimingAPI_v5 <FxTimingAPI_v4>`:

```objc
- (BOOL)isTimelineDropFrame;
- (BOOL)isInputDropFrame:(FxImageTileRequestSource)source
             parameterID:(UInt32)parameterID;
```

- `isTimelineDropFrame` returns YES when the project displays timecode in drop-frame format.
- `isInputDropFrame:parameterID:` reports whether the filter input (`kFxImageTileRequestSourceEffectClip`) or an image-well parameter (`kFxImageTileRequestSourceParameter` with `parameterID`) requires drop-frame timecode. Motion does not track per-clip drop-frame state and always returns NO. A Motion template running in Final Cut Pro returns the correct value.
- Declared inside the existing `!STUDIO_LITE && !FLEXO_LITE` guard. Available to FxPlug 4 style plug-ins only.

The other 28 headers are byte-identical to 4.3.4, copyright lines included.

### Compatibility

- Source and binary compatible with 4.3.4.
- `FxTimingAPI_v5` inherits `FxTimingAPI_v4`. Request it with `apiForProtocol:@protocol(FxTimingAPI_v5)` and fall back to `FxTimingAPI_v4` when the host returns nil.

### Examples and Xcode template

- New example `FxTimeCodeGenerator`: one XPC service that registers three plug-ins. `FxTimeCodeGeneratorPlugIn` (generator) calls `isTimelineDropFrame`. `FxTimeCodeFilterPlugIn` (filter) calls `isInputDropFrame:kFxImageTileRequestSourceEffectClip parameterID:`. `FxTimeCodeImageWellPlugIn` (image well) calls `isInputDropFrame:kFxImageTileRequestSourceParameter parameterID:`. Renders with Metal (`FxTimeCode.metal`), uses `FxParameterCreationAPI_v5` and `FxParameterRetrievalAPI_v7`, and guards its `MetalDeviceCache` command-queue cache with an `NSLock`. `About FxPlug Examples.rtf` is not updated and does not list it.
- `FxSimpleColorCorrector` (`FxSimpleColorCorrectorView.m`): `mouseDown:` opens an `FxUndoAPI` undo group named "Update Color Wheel" and `mouseUp:` closes it, each inside a `startAction:`/`endAction:` pair. New `performKeyEquivalent:` routes Command-Z and Shift-Command-Z to `FxCommandAPI_v2` `performCommand:` with `kFxCommand_Undo` / `kFxCommand_Redo`.
- All ten example projects: the "Copy and Code Sign PluginManager.framework" run-script phase (`rsync` plus `codesign`) is replaced by a `PluginManager.framework` entry in the Copy Frameworks phase with `CodeSignOnCopy` and `RemoveHeadersOnCopy`.
- `version.plist` build number 313 → 59 (new 45000 train).
- Template `FxPlug 4.xctemplate`: `version.plist` and `locversion.plist` only.

### Apple release notes (runtime, no header counterpart)

Fixes: crash when a plug-in is deleted during analysis; assertion crash in the parameter handler; wrong input start time from remote timing; mutex lifetime crash in `setStateForPlugIn`; incorrect render after the user resizes a clip, title, transition, or generator; hang when cancelling analysis; texture-size discrepancy between Final Cut Pro 12 and 11.1.1; drop zones feeding auxiliary images always used the first frame; crash in nested parameter-change handling. On-screen control responsiveness improved in Final Cut Pro 12. The drop-frame method is the only note with a header counterpart.

## FxGrip impact (2026-09-04)

- `/Library/Developer/SDKs/FxPlug.sdk` matches 4.3.5. FxGrip's deployment target (macOS 13.5) satisfies the 13.0 floor.
- FxGrip references `FxTimingAPI_v4` (6 files), `FxOnScreenControlAPI_v4` (3), `FxCustomParameterActionAPI_v4` (7), `FxCustomParameterViewHost` (2), `FxLightingAPI_v3` (9), `FxRemoteWindowAPI` (5). All compile unchanged against 4.3.5.
- FxGrip has no references to the `FxXP*` aliases, `NSCoder (FxCoding)`, or the removed `FxCustomParameterUI.h`.
- `FxTimingAPI_v5` adopted 2026-09-04: `FxGripAPIAccessing` vends the host object as `timingAPIv5` (nil on older hosts). No FxGrip wrapper class: the two queries are pure pass-throughs with nothing for a wrapper to add. The `Timing` category adds `isTimelineDropFrame`, `isInputDropFrame`, `isDropFrameOfImageParameter:`, and two timecode-string helpers; `FxGripImageRefParameter` adds `isDropFrame`. `FxGripTimecode` ports the example's SMPTE drop-frame counting and frame-rate table as a hostless utility. `FxGripPluginInfo` and `FxGripPrincipalDelegate` add `hostIsMotion` for the Motion fallbacks the example documents.
- Not adopted from the example: its `MetalDeviceCache` lock (FxGripMTLDeviceCache already locks both the device list and the queue pool), its CoreText rasterizer (FxGripTextImage), and its struct-packed plugin state.
- Open work (tracked in `Local/FxGrip Todo`): adopt the example-level patterns (undo grouping in custom views, Copy Frameworks phase) where FxGrip ships equivalents.

## Maintenance

Update this file whenever Apple ships a new FxPlug SDK, before FxGrip adopts it.

1. Download the installer from the Apple Developer downloads page (`agents/Apple Developer Download - FxPlug.webloc`). Save it as `Local/FxPlug_SDK_<version>.dmg`. Keep older installers; Apple removes them from the download page.
2. Mount the image. Copy `Library/Developer/SDKs/FxPlug.sdk/Library/Frameworks/*` from the installer payload to `Local/Frameworks v<version>/`, and the `Examples` folder to `Local/Apple Examples v<version>/`.
3. Record the metadata. The last component of the package version is the build time.

   ```bash
   xar -xf "/Volumes/FxPlug SDK/FxPlugSDK.pkg" Distribution FxPlugSDK.pkg/PackageInfo FxPlugSDK.pkg/Payload FxPlugSDK.pkg/Bom
   date -u -r <unix-time> '+%Y-%m-%d'
   tar -xf FxPlugSDK.pkg/Payload
   plutil -p Library/Developer/Frameworks/FxPlug.framework/Versions/A/Resources/Info.plist
   lsbom -s FxPlugSDK.pkg/Bom | sort > files.txt
   ```

4. Diff against the previous version. Repeat the first two commands for `PluginManager.framework` and diff the extracted `Library/Developer/Xcode/Templates` tree.

   ```bash
   diff -ru "Local/Frameworks v<prev>/FxPlug.framework/Versions/A/Headers" "Local/Frameworks v<new>/FxPlug.framework/Versions/A/Headers"
   diff "Local/Frameworks v<prev>/FxPlug.framework/Versions/A/FxPlug.tbd" "Local/Frameworks v<new>/FxPlug.framework/Versions/A/FxPlug.tbd"
   diff -rq -x xcuserdata "Local/Apple Examples v<prev>" "Local/Apple Examples v<new>"
   ```

5. Add a `## FxPlug <version> (<date>)` section after the latest version section with the same subsections: Requirements and binaries; Headers added; Headers removed; Headers changed; Compatibility; Examples and Xcode template; Apple release notes. Record every added, removed, and changed declaration, and list copyright-only headers separately.
6. Update the Version summary table, the Availability line, and the FxGrip impact section. Replace the release-notes PDF in `Local/` with the one from the new installer.
7. Update FxGrip (`FxGripAPIAccessing` wrappers and any affected subsystem) per the task list.
