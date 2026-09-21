# AGENTS.md

## Project Overview

**FxGrip** is a macOS Objective-C framework for Apple's **FxPlug 4 SDK** that provides advanced features and functionality not built into Apple's implementation. It wraps the standard FxPlug API protocols and adds its own APIs (e.g. `FxPresetsAPI_v1`, `FxParameterTagsAPI_v1`), plugin registrars, parameter management, and host-integration extensions for Final Cut Pro and Motion plugins. The project uses Xcode for building and XCTest for unit testing.

The framework is **macOS-only** (FxPlug hosts are macOS applications). Two primary base classes are `FxGripTileableEffect` and `FxGripTileableGenerator` (see `FxGrip/FxGrip.docc`).

FxGrip itself is Objective-C. One companion framework, **`FxGripRealityKit`**, is **Swift-only**, because RealityKit publishes no Objective-C interface. See "Swift-only: FxGripRealityKit" below.

## Build & Test Commands

The `FxGrip` scheme builds and tests every target: the `FxGrip` framework, `FxGripTests`, the
Swift `FxGripRealityKit` framework, and `FxGripRealityKitTests`. The four commands below cover all
of them, so the Full Check stays at four commands.

```bash
# Build all targets (macOS)
xcodebuild -project FxGrip.xcodeproj -scheme FxGrip -configuration Debug -destination 'platform=macOS' build

# Run unit tests (macOS, arm64 native) — uses FxGrip.xctestplan
xcodebuild -project FxGrip.xcodeproj -scheme FxGrip -configuration Debug -destination 'platform=macOS' test

# Run unit tests on the x86_64 slice (Rosetta on Apple Silicon)
xcodebuild test -project FxGrip.xcodeproj -scheme FxGrip -configuration Debug -destination 'platform=macOS,arch=x86_64'

# Run unit tests under AddressSanitizer
xcodebuild test -project FxGrip.xcodeproj -scheme FxGrip -configuration Debug -destination 'platform=macOS' -enableAddressSanitizer YES

# Validate the DocC catalog
xcodebuild docbuild -project FxGrip.xcodeproj -scheme FxGrip -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

### Full Check (required before commit)

Code is commit-ready only when every check below passes.

1. Build + `test` on **macOS arm64** (`platform=macOS`)
2. `test` on the **macOS x86_64** slice (`platform=macOS,arch=x86_64`)
3. `test` under **AddressSanitizer** (`-enableAddressSanitizer YES`)
4. `docbuild` of the DocC catalog

### Diagnostic build flags

Off by default. Each is opt-in through the target's preprocessor macros and compiles out of a
Release build whatever its value.

| Flag | Effect |
| --- | --- |
| `FXGRIP_LOG_HOST_API_METHODS` | Logs every selector the host's API manager implements, once per effect instance. Use it to find out what a given host actually vends. |

```bash
xcodebuild -project FxGrip.xcodeproj -scheme FxGrip -configuration Debug -destination 'platform=macOS' GCC_PREPROCESSOR_DEFINITIONS='$(inherited) FXGRIP_LOG_HOST_API_METHODS=1' build
```

## SDK and Host Requirements

- **FxPlug SDK** — the project links `FxPlug.framework` from `/Library/Developer/SDKs/FxPlug.sdk/Library/Frameworks/`. The FxPlug 4 SDK must be installed at that path to build.
- **PluginManager.framework** — linked from `/Library/Developer/Frameworks/` (installed by the FxPlug SDK / Pro Apps).
- **Deployment target** — macOS 13.5 (framework target); build with a current Xcode.
- **No private Apple APIs** — plugins that ship this framework must not call private methods in Apple's APIs; FxPlug hosts (Final Cut Pro, Motion) run plugins out-of-process and Apple validates behavior.
- **FxPlug ships no clang module map.** `Modules/FxPlug/module.modulemap` supplies one for both `FxPlug` and `PluginManager`, using absolute paths into the SDK. The `FxGrip` target defines a module (`DEFINES_MODULE = YES`) so Swift can import it, and passes this file to the module verifier through `OTHER_MODULE_VERIFIER_FLAGS`. Keep `/Library/Developer/Frameworks` out of `FRAMEWORK_SEARCH_PATHS`: its `FxPlug.framework` and `PluginManager.framework` carry no headers and would shadow the SDK copies.

## Project Structure

- `FxGrip/` — Framework source (synchronized folder groups: files added on disk are picked up by Xcode automatically)
  - Root: umbrella header `FxGrip.h`, types, errors, registrars, `FxGripMetaManager`, `FxGripTileableEffect` (+ `Analyze`, `Parameters`, `Timing`, `Versioning` categories)
  - `FxGripAPIAccessing/` — wrappers around FxPlug host API protocols plus FxGrip-added APIs (`FxGripCommonAPI`, versioned parameter creation/retrieval/setting/grouping/tags/timing APIs, `FxGripPresetsAPI_v1`)
  - `FxGripParameters/` — parameter model (`FxParameter`, `FxGripParameter`, flags, parameter libraries)
  - `FxGripCustom/` — custom parameter data classes and delegates for custom views
  - `Extensions/` — host-integration extensions (`FxGripAboutMenu`, `FxGripDebugMenu`, `FxGripFactory`, `FxGripGoogleAnalytics`, `FxGripI18N`, `FxGripInstanceTracker`, `FxGripMeta`, `FxGripParameterData`, `FxGripRegression`)
  - `Utilities/` — `FxGripMTLDeviceCache`, `FxGripParameterUtility`, `FxGripPluginInfo`
  - `Resources/`, `FxGrip.docc/` — resources and DocC catalog
- `FxGripRealityKit/` — **Swift-only** RealityKit render engine for the 3D Space subsystem (separate framework target, macOS 15.0 floor, own DocC catalog)
- `FxGripRealityKitTests/` — Swift XCTest unit tests for that framework (synchronized group)
- `Modules/FxPlug/module.modulemap` — repo-owned clang module map for Apple's FxPlug SDK and PluginManager, which ship none; required for any Swift target that imports FxGrip
- `FxGripTests/` — XCTest unit tests (synchronized group: files added to this folder are compiled automatically)
- `FxGrip.xcodeproj/` — Xcode project file (targets: `FxGrip` framework, `FxGripTests` unit-test bundle)
- `FxGrip.xctestplan` — Test plan configuration (parallelizable)
- `Frameworks/` — vendored binary frameworks (see below)
- `Information/` — reference material (FCP preset XML samples)

### Vendored: BEFoundation.framework

`Frameworks/BEFoundation.framework` is a vendored **binary** build of the standalone upstream repo (`github.com/belisoful/BEFoundation`). Do not edit files inside the vendored framework. To change BEFoundation behavior, edit the upstream repo, build its Release framework, and replace the vendored copy.

## Code Conventions

- Objective-C header/implementation pattern (.h/.m files)
- Tests follow the naming pattern: `<ClassName>Tests.m`
- `if` statements always use a block (`{}`), never a single-line body.
- Uniform Access Principle / self-encapsulation: read and write state through accessors, not direct ivar access.
- Extract Method → Predicate/Guard Clause (Fowler) is preferred over nested conditionals.
- **Backward compatibility** — point releases must stay backward compatible. Minor releases may break, but minimize the breaks.
- Document the introducing version on new public methods and classes.
- **Category methods on Apple classes must not reuse Apple method names.** Apple attaches private same-named categories at runtime, and duplicate resolution is undefined. Public: descriptive non-Apple names; private helpers should avoid the "common name" or prefix with "fxg_". Verify the selector at runtime, not just in headers.
- Versioned API classes (`*API_v3` … `*API_v6`) mirror FxPlug protocol versions; add a new versioned class rather than changing the semantics of a shipped one.

## Swift-only: FxGripRealityKit

`FxGripRealityKit` is the one Swift target in the project. It exists because RealityKit publishes no
Objective-C interface: `RealityFoundation` ships a Swift module, and the `.h` files inside
`RealityKit.framework` are Metal shader headers. A RealityKit engine cannot be written in
Objective-C, so it is not a port of the SceneKit engine and does not mirror its architecture.

- **Scope** — Swift is confined to this framework and its tests. FxGrip stays Objective-C, and a
  plugin that requires Objective-C subclasses `FxGripSceneKitEffect` instead.
- **Deployment floor** — macOS 15.0, for `RealityRenderer`. FxGrip's own floor stays at 13.5, so
  linking `FxGripRealityKit` raises a plugin's floor. The target's floor makes `@available` gating
  unnecessary inside the module.
- **Objective-C exposure** — only the effect class is `@objc`, so a host registrar instantiates it by
  name. The rest of the API is Swift-native.
- **Main actor** — `RealityRenderer` and the entity graph are `@MainActor`. The host renders frames
  concurrently on many threads, so RealityKit work is scheduled onto the main actor and the render
  thread waits for it. Never touch a RealityKit type off the main actor.
- **Documentation** — Swift uses `///` doc comments, which DocC reads. The file-header block keeps the
  `/*! @file ... */` form the Objective-C sources use. The Documentation Style rules below apply
  unchanged.
- **Module map** — the target passes `Modules/FxPlug/module.modulemap` to the clang importer through
  `OTHER_SWIFT_FLAGS`. A new Swift target that imports FxGrip needs the same flag.
- **Designated initializer** — `FxGripTileableEffect` declares `initWithAPIManager:` with
  `NS_DESIGNATED_INITIALIZER`. Keep it that way. Swift applies a subclass's stored-property defaults
  only when the initializer it inherits is declared on the class; without the declaration every
  stored property in a Swift subclass reads as zeroed memory, and an object-typed one crashes the
  first code that touches it. `FxGripRealityKitEffectTests` covers this.

## Code Comments

The bar for a comment is high. Code should explain itself through clear naming and
structure; comments are reserved for what the code cannot express.

- Use HeaderDoc `/*! ... */` blocks for public types, methods, and properties — the
  established house style. Put multi-sentence rationale in the method's `@discussion`.
- Write an inline `//` comment ONLY when it documents something non-obvious the code cannot
  state on its own: a subtle invariant (e.g. "must run on the access queue"), an external
  constraint or platform quirk (e.g. an FxPlug host API that returns nil with no error), or
  a deliberate omission a maintainer might otherwise "fix".
- Do NOT narrate what the code obviously does, restate the method name, or leave
  historical / "FIX:" / "previously the code did X" / "regression" justifications. The diff
  and commit message carry that — not the source.
- Prefer one terse line over a paragraph. If a comment needs several lines, it usually
  belongs in the HeaderDoc `@discussion`, not inline.
- The same bar applies to test code: the test method name should describe intent; add a
  comment only for a non-obvious setup or invariant.

## Documentation Style (enforced)

HeaderDoc blocks and comments are technical documentation written with direct technical statements.
Language and National Variety: English — American.
Qualities of the writing: clear, thorough, easy to comprehend, not verbose (brevity), timeless, integrated, wholistic.
Tense: Present — tuned for ease of comprehension.

_Banned constructions_:
- **Antithesis / "not merely X — it Ys"**: no "does not just X, it Ys", "is not a Y, it's a Z", "rather than X, it Ys". State what it does, once.
- **Em-dash dramatic asides** used for emphasis or reveal ("— and that's the point"). Use a period or plain clause.
- **Editorializing / filler.**
- **Rule-of-three rhetorical lists** and build-up sentences. One fact per sentence.

The build enables `-Wdocumentation` and `-Wdocumentation-unknown-command`, so a doc comment
attached to a declaration must use only tags clang recognizes. HeaderDoc tags clang does not know —
`@field`, `@group`, `@description`, `@default` — warn; use `@discussion` with a markdown list
instead. A markdown list inside `@discussion` must sit at a single tab: the tab + 12-space
continuation indent used elsewhere is past markdown's four-space threshold, so the list renders as
a code block and its items are dropped. Read the generated page, not just the warning count. A file block that lands directly before a declaration is parsed as that declaration's
documentation, which is why the `*Library.m` fragments give their first method its own block. The
`FxPlugStub` target opts out, because it mirrors Apple's headers verbatim.

Prefer subject–verb–object declaratives, and bullet lists of `condition → result` where appropriate. Documentation informs and describes; it is not persuasive writing. Documentation additions, changes, and removals are integrated into the surrounding text at each level of detail.

## Adding New Source Files

1. Add .h and .m files to the appropriate `FxGrip/` subfolder (synchronized groups: the files are picked up automatically)
2. Add a corresponding test file to `FxGripTests/` (also synchronized — compiled automatically)
3. Mark new public headers `Public` in the target's build phases when they are part of the framework API
4. Add the public header to the umbrella `FxGrip.h`. Every `Public` header must appear there, or the module verifier fails.
5. Inside a framework header, import with angle brackets (`#import <FxGrip/FxGripTypes.h>`), never quotes. Quoted includes fail the module verifier.

Swift files go in `FxGripRealityKit/`, tests in `FxGripRealityKitTests/` (both synchronized). They have no umbrella header and no public-header marking. A `.metal` file in `FxGripRealityKit/` compiles into the framework's `default.metallib`, loaded with `makeDefaultLibrary(bundle:)`.

## Key Dependencies

- FxPlug.framework (FxPlug 4 SDK, `/Library/Developer/SDKs/FxPlug.sdk`)
- PluginManager.framework (`/Library/Developer/Frameworks`)
- BEFoundation.framework (vendored, `Frameworks/`)
- Foundation.framework / AppKit.framework / Cocoa.framework
- CoreMedia.framework, CoreImage.framework, Metal.framework, Accelerate.framework, WebKit.framework
- RealityKit.framework / RealityFoundation (Swift-only, `FxGripRealityKit` target, macOS 15.0+)
- XCTest.framework (for tests)

## Safeguards (Anti-Patterns)

Required without exception:

- **NEVER** run `git clone/mv/restore/rm/branch/commit/merge/rebase/reset/pull/push` without developer approval first.
- **NEVER** run `rm` on any path without developer approval first.
- **NEVER** erase or overwrite files for the task of unit testing — the changes being tested must be preserved.
- **NEVER** delete a file or folder until its associated task is completely finished.
