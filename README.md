# FxGrip

[![CI](https://github.com/belisoful/FxGrip/actions/workflows/ci.yml/badge.svg)](https://github.com/belisoful/FxGrip/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform: macOS](https://img.shields.io/badge/platform-macOS%2013.5%2B-lightgrey.svg)
![FxPlug 4.3.5](https://img.shields.io/badge/FxPlug-4.3.5-orange.svg)

FxGrip is an Objective-C framework for Apple's FxPlug 4 SDK. It adds features and functionality to Final Cut Pro and Motion plug-ins beyond Apple's implementation.

FxGrip wraps the FxPlug host API protocols and adds its own APIs, a parameter model, plug-in registrars, and host-integration extensions. It is macOS-only, because FxPlug hosts are macOS applications.

## Features

- **Effect and generator base classes.** `FxGripTileableEffect` and `FxGripTileableGenerator` drive the parameter subsystem, the extensions, presets, analysis, and the render pass.
- **Versioned host API wrappers.** Parameter creation, retrieval, setting, grouping, tags, and timing mirror each FxPlug protocol version.
- **FxGrip APIs.** Presets (`FxGripPresetsAPI_v1`, with FxFactory `.fxpreset` interoperability) and parameter tags (`FxGripParameterTagsAPI_v1`).
- **Custom parameter controls.** Sections, dividers, banners, switches, curves, live images, web views, video, and progress and status displays.
- **On-screen controls.** Cursors, curves, HUDs, and editable polygons.
- **Frame analysis.** An `FxAnalyzer` pass with per-frame data storage.
- **Extensions.** About and debug menus, internationalization, instance tracking, metadata, and regression support.
- **Inference.** Pluggable inference backends and an ML image-effect template.
- **3D space.** An engine-neutral scene base with a SceneKit engine and a Swift-only RealityKit engine (`FxGripRealityKit`, macOS 15+).

FxGrip is adoptable in layers. A plug-in links one utility, wraps the host API, adopts the parameter subsystem through a host, or subclasses the effect base for the whole framework. The DocC catalog's *Adoption* article maps the levels.

## Requirements

- macOS 13.5 or later (`FxGripRealityKit` requires macOS 15.0)
- A current Xcode
- [FxPlug 4 SDK](https://developer.apple.com/download/all/?q=FxPlug), installed at `/Library/Developer/SDKs/FxPlug.sdk`
- [FxFactory](https://fxfactory.com/download/), which installs `/Library/Frameworks/FxFactory.framework`

Apple distributes the FxPlug SDK to Apple Developer accounts. This repository includes neither the FxPlug SDK nor FxFactory.

## Building

```bash
xcodebuild -project FxGrip.xcodeproj -scheme FxGrip -configuration Debug -destination 'platform=macOS' build
```

The `FxGrip` scheme builds and tests every target: the `FxGrip` framework, the `FxGripRealityKit` framework, and both test bundles.

## Testing

```bash
xcodebuild -project FxGrip.xcodeproj -scheme FxGrip -configuration Debug -destination 'platform=macOS' test
```

Unit tests run without an FxPlug host. The `FxPlugStub` target stands in for the SDK's `FxPlug.framework`, which ships headers and a linker stub only.

A change is ready to merge when the Full Check in [AGENTS.md](AGENTS.md#full-check-required-before-commit) passes: arm64 build and test, x86_64 test, AddressSanitizer test, and DocC. CI runs the same four checks.

## Documentation

The DocC catalog is `FxGrip/FxGrip.docc`. Build it with:

```bash
xcodebuild docbuild -project FxGrip.xcodeproj -scheme FxGrip -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

In Xcode, choose **Product › Build Documentation**.

## Continuous integration

GitHub Actions runs the Full Check on every push to `main` and on every pull request. Neither Apple's FxPlug SDK nor Noise Industries' FxFactory framework can be redistributed, so CI installs each from its own private repository through a read-only deploy key:

| Repository | Contents | Secret |
| --- | --- | --- |
| `belisoful/FxPlug-SDK` | Apple's `FxPlugSDK.pkg` at the root, one commit per SDK version, tagged `v<version>` | `FXPLUG_SDK_DEPLOY_KEY` |
| `belisoful/FxFactory-SDK` | A link-only `FxFactory.framework` stub (headers, module map, `.tbd`), tagged `v<version>` | `FXFACTORY_SDK_DEPLOY_KEY` |

Pull requests from forks receive no secrets, so their macOS jobs are skipped and a maintainer runs them.

`Scripts/make-fxfactory-stub.sh` builds the FxFactory stub from the installed `/Library/Frameworks/FxFactory.framework`. With `--publish <clone>` it commits, tags, and pushes the stub to a clone of `belisoful/FxFactory-SDK`.

These Actions variables are optional overrides:

| Variable | Default | Effect |
| --- | --- | --- |
| `FXPLUG_SDK_REPOSITORY` | `belisoful/FxPlug-SDK` | Repository that holds the FxPlug SDK installers. |
| `FXPLUG_SDK_VERSION` | `4.3.5` | FxPlug SDK version to install. Selects the tag `v<version>`. |
| `FXFACTORY_REPOSITORY` | `belisoful/FxFactory-SDK` | Repository that holds the FxFactory stubs. |
| `FXFACTORY_VERSION` | `9.0.5` | FxFactory stub version to install. Selects the tag `v<version>`. |
| `XCODE_VERSION` | newest release Xcode on the runner | Xcode to select, e.g. `26.2`. |

The *Dependency watch* workflow checks https://fxfactory.com/download/ daily and opens an issue when an FxFactory release is newer than the newest stub. Apple lists FxPlug SDK releases only behind an Apple Developer sign-in, so a weekly scheduled Claude task on a maintainer's Mac checks the downloads page and opens an issue for a newer SDK.

## Dependencies

- **FxPlug.framework** and **PluginManager.framework** from the FxPlug SDK
- **FxFactory.framework**, weak-linked, from [FxFactory](https://fxfactory.com) (`FxGripFxFactory` licensing integration)
- **BEFoundation.framework**, vendored as a binary in `Frameworks/` from [belisoful/BEFoundation](https://github.com/belisoful/BEFoundation)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Report security issues as [SECURITY.md](SECURITY.md) describes.

## License

FxGrip is available under the MIT License. See [LICENSE](LICENSE).

FxPlug, Final Cut Pro, and Motion are trademarks of Apple Inc. FxGrip is not affiliated with Apple.
