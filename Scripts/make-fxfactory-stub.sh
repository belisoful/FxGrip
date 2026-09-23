#!/bin/bash
#
# make-fxfactory-stub.sh
#
# Builds a link-only stub of FxFactory.framework for FxGrip's CI, and optionally publishes it to
# the private belisoful/FxFactory-SDK repository.
#
# The stub holds the framework's public headers, its module map, its Info.plist, and a
# text-based stub (.tbd) in place of the binary. FxGrip weak-links FxFactory, so a build compiles
# and links against the stub, and at runtime the FxFactory symbols resolve to NULL, the same as on
# a Mac without FxFactory.
#
# Usage:
#   Scripts/make-fxfactory-stub.sh [--source <FxFactory.framework>] [--output <dir>]
#                                  [--publish <FxFactory-SDK clone>]
#
#   --source    Framework to stub. Default: /Library/Frameworks/FxFactory.framework, which the
#               FxFactory app installs and updates.
#   --output    Directory that receives <version>/FxFactory.framework.
#               Default: build/FxFactory-stub under the repository root.
#   --publish   Local clone of belisoful/FxFactory-SDK. Replaces its FxFactory.framework with the
#               stub, commits, tags v<version>, and pushes main and the tag.
#
# Upgrading: update FxFactory, launch it once so it installs the new framework, then run
#   Scripts/make-fxfactory-stub.sh --publish <clone>
# and set the FxGrip Actions variable FXFACTORY_VERSION to the new version.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_framework="/Library/Frameworks/FxFactory.framework"
output_root="$repo_root/build/FxFactory-stub"
publish_clone=""

usage() {
	sed -n '/^# Usage:/,/^# Upgrading:/p' "$0" | sed '$d; s/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--source) source_framework="$2"; shift 2 ;;
		--output) output_root="$2"; shift 2 ;;
		--publish) publish_clone="$2"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
	esac
done

info_plist="$source_framework/Resources/Info.plist"
if [[ ! -f "$info_plist" ]]; then
	echo "error: $source_framework is not an FxFactory framework (no Resources/Info.plist)." >&2
	exit 1
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")"
stub="$output_root/$version/FxFactory.framework"

if [[ -e "$stub" ]]; then
	echo "error: $stub already exists. Remove it or pass a different --output." >&2
	exit 1
fi

echo "Stubbing FxFactory $version from $source_framework"

mkdir -p "$stub/Versions/A/Resources"
cp -R "$source_framework/Versions/A/Headers" "$stub/Versions/A/Headers"
cp -R "$source_framework/Versions/A/Modules" "$stub/Versions/A/Modules"
cp "$info_plist" "$stub/Versions/A/Resources/Info.plist"
xcrun tapi stubify "$source_framework/Versions/A/FxFactory" -o "$stub/Versions/A/FxFactory.tbd"

ln -s A "$stub/Versions/Current"
for entry in Headers Modules Resources FxFactory.tbd; do
	ln -s "Versions/Current/$entry" "$stub/$entry"
done

echo "Stub written to $stub"

if [[ -z "$publish_clone" ]]; then
	exit 0
fi

if ! git -C "$publish_clone" rev-parse --git-dir >/dev/null 2>&1; then
	echo "error: $publish_clone is not a git clone of belisoful/FxFactory-SDK." >&2
	exit 1
fi
if git -C "$publish_clone" rev-parse -q --verify "refs/tags/v$version" >/dev/null; then
	echo "error: tag v$version already exists in $publish_clone." >&2
	exit 1
fi

git -C "$publish_clone" pull --ff-only --quiet
git -C "$publish_clone" rm -r -q --ignore-unmatch FxFactory.framework
cp -R "$stub" "$publish_clone/FxFactory.framework"
git -C "$publish_clone" add FxFactory.framework
git -C "$publish_clone" commit -q -m "Add FxFactory $version stub"
git -C "$publish_clone" tag -a "v$version" -m "FxFactory $version stub"
git -C "$publish_clone" push -q origin HEAD "v$version"

echo "Published FxFactory $version stub as tag v$version."
