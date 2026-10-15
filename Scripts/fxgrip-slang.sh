#!/bin/bash
#
# fxgrip-slang.sh
#
# Compiles a Slang compute kernel written against the GripKernel module into the Metal source and
# the reflection JSON that FxGrip's kernel effect loads at runtime. This is the command the Kernels
# DocC article and D-009 specify:
#
#   slangc -I <module dir> <kernel>.slang -target metal -entry <name> -stage compute
#          -line-directive-mode standard -reflection-json <kernel>.json -o <kernel>.metal
#
# Usage:
#   Scripts/fxgrip-slang.sh [--slangc <path>] [--module-dir <dir>] [--entry <name>]
#                           [--output-dir <dir>] [--copy-source] <kernel>.slang
#
#   --slangc       The slangc executable. Default: $FXGRIP_SLANGC, then slangc on the PATH.
#   --module-dir   The directory holding GripKernel.slang. Default: $FXGRIP_KERNEL_MODULE_DIR,
#                  then FxGrip/Shader beside this script (the FxGrip checkout), then the Resources
#                  folder of FxGrip.framework in $BUILT_PRODUCTS_DIR (an Xcode build that links the
#                  framework).
#   --entry        The compute entry point. Default: fxGripKernel.
#   --output-dir   The directory that receives <kernel>.metal and <kernel>.json. Default: the
#                  kernel's own directory.
#   --copy-source  Also copies <kernel>.slang into the output directory, so one directory holds
#                  the three files a kernel effect bundles.
#
# Xcode build rule: see Scripts/README.md. The script exits nonzero when slangc fails, so a build
# rule fails the build with slangc's diagnostics, which name the Slang source lines.

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
slangc="${FXGRIP_SLANGC:-}"
module_dir="${FXGRIP_KERNEL_MODULE_DIR:-}"
entry="fxGripKernel"
output_dir=""
copy_source="no"
kernel=""

usage() {
	sed -n '/^# Usage:/,/^# Xcode build rule:/p' "$0" | sed '$d; s/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--slangc) slangc="$2"; shift 2 ;;
		--module-dir) module_dir="$2"; shift 2 ;;
		--entry) entry="$2"; shift 2 ;;
		--output-dir) output_dir="$2"; shift 2 ;;
		--copy-source) copy_source="yes"; shift ;;
		-h|--help) usage; exit 0 ;;
		-*) echo "fxgrip-slang.sh: unknown option $1" >&2; usage >&2; exit 1 ;;
		*)
			if [[ -n "$kernel" ]]; then
				echo "fxgrip-slang.sh: one kernel per run" >&2; exit 1
			fi
			kernel="$1"; shift ;;
	esac
done

if [[ -z "$kernel" ]]; then
	usage >&2; exit 1
fi
if [[ ! -f "$kernel" ]]; then
	echo "fxgrip-slang.sh: no kernel at $kernel" >&2; exit 1
fi

if [[ -z "$slangc" ]]; then
	slangc="$(command -v slangc || true)"
fi
if [[ -z "$slangc" || ! -x "$slangc" ]]; then
	echo "fxgrip-slang.sh: slangc not found; set FXGRIP_SLANGC or pass --slangc" >&2; exit 1
fi

if [[ -z "$module_dir" ]]; then
	for candidate in "$script_dir/../FxGrip/Shader" "${BUILT_PRODUCTS_DIR:-}/FxGrip.framework/Resources"; do
		if [[ -f "$candidate/GripKernel.slang" ]]; then
			module_dir="$candidate"; break
		fi
	done
fi
if [[ -z "$module_dir" || ! -f "$module_dir/GripKernel.slang" ]]; then
	echo "fxgrip-slang.sh: GripKernel.slang not found; set FXGRIP_KERNEL_MODULE_DIR or pass --module-dir" >&2; exit 1
fi

kernel_dir="$(cd "$(dirname "$kernel")" && pwd)"
kernel_name="$(basename "$kernel")"
base="$(basename "$kernel_name" .slang)"
module_dir="$(cd "$module_dir" && pwd)"
if [[ -z "$output_dir" ]]; then
	output_dir="$kernel_dir"
fi
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

# Compiling from the kernel's directory keeps its #line directives to the file name, so the emitted
# source carries no build-machine paths.
cd "$kernel_dir"
"$slangc" -I "$module_dir" "$kernel_name" \
	-target metal -entry "$entry" -stage compute -line-directive-mode standard \
	-reflection-json "$output_dir/$base.json" -o "$output_dir/$base.metal"

if [[ "$copy_source" == "yes" && "$kernel_dir" != "$output_dir" ]]; then
	cp "$kernel_name" "$output_dir/$base.slang"
fi
