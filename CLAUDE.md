# AGENTS.md

## Project Overview

**FxGrip** is a macOS Objective-C framework for Apple's **FxPlug 4 SDK** that provides advanced features and functionality not built into Apple's implementation. It wraps the standard FxPlug API protocols and adds its own APIs (e.g. `FxPresetsAPI_v1`, `FxParameterTagsAPI_v1`), plugin registrars, parameter management, and host-integration extensions for Final Cut Pro and Motion plugins. The project uses Xcode for building and XCTest for unit testing.

The framework is **macOS-only** (FxPlug hosts are macOS applications). Two primary base classes are `FxTileableEffectBase` and `FxTileableGeneratorBase` (see `FxGrip/FxGrip.docc`).

## Build & Test Commands

```bash
# Build the framework (macOS)
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

## SDK and Host Requirements

- **FxPlug SDK** — the project links `FxPlug.framework` from `/Library/Developer/SDKs/FxPlug.sdk/Library/Frameworks/`. The FxPlug 4 SDK must be installed at that path to build.
- **PluginManager.framework** — linked from `/Library/Developer/Frameworks/` (installed by the FxPlug SDK / Pro Apps).
- **Deployment target** — macOS 13.5 (framework target); build with a current Xcode.
- **No private Apple APIs** — plugins that ship this framework must not call private methods in Apple's APIs; FxPlug hosts (Final Cut Pro, Motion) run plugins out-of-process and Apple validates behavior.

## Project Structure

- `FxGrip/` — Framework source (synchronized folder groups: files added on disk are picked up by Xcode automatically)
  - Root: umbrella header `FxGrip.h`, types, errors, registrars, `GuruFxMetaManager`, `GuruFxTileableEffect` (+ `Analyze`, `Parameters`, `Timing`, `Versioning` categories)
  - `FxGripAPIAccessing/` — wrappers around FxPlug host API protocols plus FxGrip-added APIs (`FxGripCommonAPI`, versioned parameter creation/retrieval/setting/grouping/tags/timing APIs, `FxGripPresetsAPI_v1`)
  - `FxGripParameters/` — parameter model (`FxParameter`, `FxGripParameter`, flags, parameter libraries)
  - `FxGripCustom/` — custom parameter data classes and delegates for custom views
  - `Extensions/` — host-integration extensions (`FxGripAboutMenu`, `FxGripDebugMenu`, `FxGripFactory`, `FxGripGoogleAnalytics`, `FxGripI18N`, `FxGripInstanceTracker`, `FxGripMeta`, `FxGripParameterData`, `FxGripRegression`)
  - `Utilities/` — `FxGripMTLDeviceCache`, `FxGripParameterUtility`, `FxGripPluginInfo`
  - `Resources/`, `FxGrip.docc/` — resources and DocC catalog
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

Prefer subject–verb–object declaratives, and bullet lists of `condition → result` where appropriate. Documentation informs and describes; it is not persuasive writing. Documentation additions, changes, and removals are integrated into the surrounding text at each level of detail.

## Adding New Source Files

1. Add .h and .m files to the appropriate `FxGrip/` subfolder (synchronized groups: the files are picked up automatically)
2. Add a corresponding test file to `FxGripTests/` (also synchronized — compiled automatically)
3. Mark new public headers `Public` in the target's build phases when they are part of the framework API
4. Add the public header to the umbrella `FxGrip.h`

## Key Dependencies

- FxPlug.framework (FxPlug 4 SDK, `/Library/Developer/SDKs/FxPlug.sdk`)
- PluginManager.framework (`/Library/Developer/Frameworks`)
- BEFoundation.framework (vendored, `Frameworks/`)
- Foundation.framework / AppKit.framework / Cocoa.framework
- CoreMedia.framework, CoreImage.framework, Metal.framework, Accelerate.framework, WebKit.framework
- XCTest.framework (for tests)

## Safeguards (Anti-Patterns)

Required without exception:

- **NEVER** run `git clone/mv/restore/rm/branch/commit/merge/rebase/reset/pull/push` without developer approval first.
- **NEVER** run `rm` on any path without developer approval first.
- **NEVER** erase or overwrite files for the task of unit testing — the changes being tested must be preserved.
- **NEVER** delete a file or folder until its associated task is completely finished.
