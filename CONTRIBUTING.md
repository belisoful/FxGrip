# Contributing to FxGrip

## Setup

1. Install a current Xcode.
2. Download the FxPlug 4 SDK from [Apple Developer](https://developer.apple.com/download/all/?q=FxPlug) and run its installer. The SDK installs to `/Library/Developer/SDKs/FxPlug.sdk`.
3. Install [FxFactory](https://fxfactory.com/download/) and launch it once. It installs `/Library/Frameworks/FxFactory.framework`, which FxGrip weak-links.
4. Open `FxGrip.xcodeproj` and build the `FxGrip` scheme.

## Pull requests

- Branch from `main` and keep each pull request to one change.
- Add or update tests in `FxGripTests/` (or `FxGripRealityKitTests/` for Swift) alongside every source change. Test files follow the `<ClassName>Tests.m` pattern.
- Run the Full Check before you open the pull request. CI runs the same four checks.

```bash
xcodebuild -project FxGrip.xcodeproj -scheme FxGrip -configuration Debug -destination 'platform=macOS' test
xcodebuild test -project FxGrip.xcodeproj -scheme FxGrip -configuration Debug -destination 'platform=macOS,arch=x86_64'
xcodebuild test -project FxGrip.xcodeproj -scheme FxGrip -configuration Debug -destination 'platform=macOS' -enableAddressSanitizer YES
xcodebuild docbuild -project FxGrip.xcodeproj -scheme FxGrip -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

CI needs the FxPlug SDK and an FxFactory stub, which live in private repositories. Pull requests from forks receive no secrets, so their macOS jobs are skipped. A maintainer runs the checks before merging.

## Conventions

[AGENTS.md](AGENTS.md) is the project's coding standard. It covers code conventions, documentation style, comment rules, and how to add source files. Highlights:

- Objective-C with HeaderDoc `/*! ... */` blocks on public API. Swift is confined to `FxGripRealityKit`.
- `if` statements always use braces.
- Category methods on Apple classes never reuse Apple method names.
- New public headers are marked `Public` and added to the umbrella header `FxGrip.h`.
- No private Apple APIs.
- `Frameworks/BEFoundation.framework` is a vendored binary. Change it upstream in [belisoful/BEFoundation](https://github.com/belisoful/BEFoundation).
