#!/bin/bash
#
# pluginkit-manager.sh — a thin, developer-friendly wrapper around the macOS
# `pluginkit(8)` CLI for managing PlugInKit app extensions (FxPlug plugins,
# and any other NSExtension-based plug-ins).
#
# It encapsulates the everyday tasks a plugin developer needs while iterating:
# listing what the system has registered, inspecting a single plug-in, forcing
# a build to register/unregister, and toggling the per-user election state
# (use / ignore / default) that decides whether a host will load it.
#
# pluginkit only ever manages plug-ins for the *current user*; it makes no
# permanent changes to the automatic registry (the OS re-discovers on its own).
#
# @todo Turn this script into a native macOS app:
#   • A window with a table/list of plug-ins, each row carrying a checkbox.
#   • The checkbox reflects whether the plug-in is currently registered /
#     "used" (election == use); checking/unchecking calls enable/disable.
#   • Drag-and-drop a .appex / plug-in bundle onto the window to add it as an
#     available plug-in (register it), or add it via an "Open…" file dialog.
#   • Select a row and Remove it — enabled only when the plug-in is NOT active
#     (unregister; guard the control so an in-use plug-in cannot be removed).
#   • Live-refresh the list (poll `pluginkit -mv` or watch the registry) so the
#     checkboxes stay in sync with the system state.
#   This shell script exists to prove out and document the underlying pluginkit
#   operations the app will drive.
#
# Underlying pluginkit reference (see `man 8 pluginkit`):
#   -m            match/scan registered plug-ins (list)
#   -v            verbose (repeatable)
#   -p PROTOCOL   match by extension point, e.g. FxPlug
#   -i IDENTIFIER match by bundle identifier
#   -A            include all versions (not just the highest)
#   -D            include all physical duplicates
#   -a FILE       explicitly add/register a plug-in bundle
#   -r FILE       explicitly remove/unregister a plug-in bundle
#   -e ELECTION   set election (use | ignore | default) on matching plug-ins
#
# Match-line election tags:
#   +  user elected to use          -  user elected to ignore
#   !  elected for debugger use      =  superseded by another plug-in
#   ?  unknown election state

set -euo pipefail

PROG="$(basename "$0")"
PLUGINKIT="/usr/bin/pluginkit"

# Default extension point for the bare `list` command. FxGrip ships FxPlug
# plugins, so that is the useful default; override with -p or use `list-all`.
DEFAULT_PROTOCOL="FxPlug"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

err()  { printf '%s: %s\n' "$PROG" "$*" >&2; }
die()  { err "$*"; exit 1; }

require_pluginkit() {
	[ -x "$PLUGINKIT" ] || die "pluginkit not found at $PLUGINKIT (macOS only)"
}

# Resolve a bundle path argument to an absolute path and sanity-check it.
resolve_bundle() {
	local path="$1"
	[ -n "$path" ]  || die "expected a plug-in bundle path"
	[ -e "$path" ]  || die "no such file: $path"
	# Absolute path so pluginkit records a stable location.
	( cd "$(dirname "$path")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$path")" )
}

usage() {
	cat <<EOF
$PROG — manage PlugInKit app extensions (FxPlug and other NSExtension plug-ins)

USAGE
    $PROG <command> [arguments]
    $PROG help [command]        Show this overview, or detailed help for one command.

LISTING
    list [-p PROTOCOL]         List plug-ins for a protocol (default: $DEFAULT_PROTOCOL).
    list-all                   List every registered plug-in (all protocols).
    protocols                  List the distinct extension points currently seen.
    info <bundleID>            Verbose detail for one plug-in (all versions/dupes).
    status <bundleID>          Print just the election state of a plug-in.
    paths [-p PROTOCOL]        List plug-ins as "state  bundleID  ->  path".

REGISTRATION (development)
    register <bundle-path>     Explicitly add/register a plug-in bundle.
    unregister <bundle-path>   Explicitly remove/unregister a plug-in bundle.

ELECTION (per-user enable/disable)
    enable  <bundleID>         Elect to USE the plug-in (host will load it).
    disable <bundleID>         Elect to IGNORE the plug-in (host will skip it).
    reset   <bundleID>         Reset election to DEFAULT (system decides).

OPTIONS
    -p PROTOCOL   Extension point to match (e.g. FxPlug). Applies to list/paths.
    -h, --help    Show this overview.

ELECTION STATES (leading tag in list/status output)
    +  use          user elected to load the plug-in
    -  ignore       user elected to skip the plug-in
    !  debugger     elected for debugger use
    =  superseded   a higher-priority plug-in with the same identifier wins
    ?  default      no explicit election; the system decides

EXIT STATUS
    0  success        1  usage error, or the requested plug-in/path was not found

For a walk-through of any single command, run:
    $PROG help <command>        (e.g. $PROG help register)

NOTES
    • pluginkit only manages plug-ins for the current user.
    • register/unregister are development aids only; automatic discovery may
      re-add or drop them on its own. The durable per-user control is election
      (enable/disable), which survives re-discovery.

SEE ALSO
    man 8 pluginkit
EOF
}

# Detailed, per-command help. Keeps each command's contract, the exact
# pluginkit invocation it runs, and a worked example in one place.
help_topic() {
	local topic="$1"
	case "$topic" in
	list)
		cat <<EOF
$PROG list [-p PROTOCOL]

    List every plug-in registered for one extension point, one per line, with
    the leading election tag. Defaults to the "$DEFAULT_PROTOCOL" protocol, which is
    the useful default for FxPlug plug-in development.

    Runs:  pluginkit -mv -p <PROTOCOL>

    -p PROTOCOL   Match a different extension point (see: $PROG protocols).

    Examples:
        $PROG list
        $PROG list -p com.apple.share-services
EOF
		;;
	list-all)
		cat <<EOF
$PROG list-all

    List every registered plug-in on the system, across all extension points.
    Useful when you do not know which protocol a plug-in registered under.

    Runs:  pluginkit -mv
EOF
		;;
	protocols)
		cat <<EOF
$PROG protocols

    Print the distinct extension points (NSExtensionPointName values) currently
    present in the registry, sorted and de-duplicated. Use one of these values
    as the argument to "list -p" or "paths -p".

    The extension point is not shown in the plain match output, so this reads
    the raw XML replies from the management daemon.

    Runs:  pluginkit --raw -m   (NSExtensionPointName values extracted)
EOF
		;;
	info)
		cat <<EOF
$PROG info <bundleID>

    Print full, verbose detail for a single plug-in: path, UUID, parent bundle,
    version, extension point, and election state. Includes every known version
    and every physical duplicate.

    Runs:  pluginkit -m -v -v -A -D -i <bundleID>

    Example:
        $PROG info com.example.MyPlugin
EOF
		;;
	status)
		cat <<EOF
$PROG status <bundleID>

    Print just the election state of one plug-in, decoded into words
    (use / ignore / debugger / superseded / default). This is the value a
    host consults to decide whether to load the plug-in.

    Runs:  pluginkit -m -i <bundleID>   (leading tag decoded)

    Example:
        $PROG status com.example.MyPlugin
EOF
		;;
	paths)
		cat <<EOF
$PROG paths [-p PROTOCOL]

    List matching plug-ins as "state  bundleID  ->  filesystem path", one per
    line. Handy for locating the bundle you want to pass to unregister, or for
    confirming which copy on disk a host will load.

    Runs:  pluginkit -mv -p <PROTOCOL>   (reformatted)

    -p PROTOCOL   Match a different extension point (default: $DEFAULT_PROTOCOL).

    Example:
        $PROG paths
        $PROG paths -p com.apple.share-services
EOF
		;;
	register)
		cat <<EOF
$PROG register <bundle-path>

    Explicitly add a plug-in bundle to the registry, even if it is not in a
    location eligible for automatic discovery. The path is resolved to an
    absolute path first so pluginkit records a stable location.

    Runs:  pluginkit -a <absolute-bundle-path>

    Note: this is a development aid. It does NOT make a permanent change; a
    later registry clean-up may remove an explicitly-added bundle, and
    automatic discovery may add it back on its own. To durably control whether
    a plug-in loads, use "enable" / "disable" (election).

    Example:
        $PROG register ./build/Debug/MyPlugin.app/Contents/PlugIns/MyPlugin.appex
EOF
		;;
	unregister)
		cat <<EOF
$PROG unregister <bundle-path>

    Explicitly remove a plug-in bundle from the registry.

    Runs:  pluginkit -r <absolute-bundle-path>

    Note: development aid only. If the bundle is still present on disk in a
    discoverable location, automatic discovery may re-add it. To keep a
    present-on-disk plug-in from loading, use "disable" instead.

    Example:
        $PROG unregister ./build/Debug/MyPlugin.app/Contents/PlugIns/MyPlugin.appex
EOF
		;;
	enable)
		cat <<EOF
$PROG enable <bundleID>

    Set the per-user election for a plug-in to "use", so a host will load it.
    This is the durable per-user control; it survives automatic re-discovery.

    Runs:  pluginkit -e use -i <bundleID>

    Example:
        $PROG enable com.example.MyPlugin
EOF
		;;
	disable)
		cat <<EOF
$PROG disable <bundleID>

    Set the per-user election for a plug-in to "ignore", so hosts skip it even
    though it remains registered on disk. Reverse with "enable" or "reset".

    Runs:  pluginkit -e ignore -i <bundleID>

    Example:
        $PROG disable com.example.MyPlugin
EOF
		;;
	reset)
		cat <<EOF
$PROG reset <bundleID>

    Clear any explicit election and return the plug-in to the system default,
    letting PlugInKit decide whether to load it.

    Runs:  pluginkit -e default -i <bundleID>

    Example:
        $PROG reset com.example.MyPlugin
EOF
		;;
	*)
		err "no help for unknown command: $topic"
		echo
		usage
		return 1
		;;
	esac
}

cmd_help() {
	if [ $# -eq 0 ]; then
		usage
	else
		help_topic "$1"
	fi
}

# ---------------------------------------------------------------------------
# commands
# ---------------------------------------------------------------------------

cmd_list() {
	local protocol="$DEFAULT_PROTOCOL"
	while [ $# -gt 0 ]; do
		case "$1" in
			-p) protocol="${2:-}"; [ -n "$protocol" ] || die "-p needs a protocol"; shift 2 ;;
			*)  die "unexpected argument: $1" ;;
		esac
	done
	printf 'Registered plug-ins for protocol: %s\n' "$protocol"
	"$PLUGINKIT" -mv -p "$protocol" || die "no plug-ins matched protocol '$protocol'"
}

cmd_list_all() {
	printf 'All registered plug-ins:\n'
	"$PLUGINKIT" -mv
}

cmd_protocols() {
	# The extension point is only present in the raw XML replies, not in the
	# plain match lines; pull NSExtensionPointName values from the raw dump.
	"$PLUGINKIT" --raw -m 2>/dev/null \
		| sed -n 's/.*NSExtensionPointName[[:space:]]*=[[:space:]]*"\{0,1\}\([^";]*\)"\{0,1\};.*/\1/p' \
		| sort -u \
		|| die "could not read extension points"
}

cmd_info() {
	local id="${1:-}"
	[ -n "$id" ] || die "info needs a bundle identifier"
	# -v -v for maximum detail; -A/-D so every version and duplicate shows.
	"$PLUGINKIT" -m -v -v -A -D -i "$id" \
		|| die "no plug-in registered with identifier '$id'"
}

cmd_status() {
	local id="${1:-}"
	[ -n "$id" ] || die "status needs a bundle identifier"
	local line
	line="$("$PLUGINKIT" -m -i "$id" 2>/dev/null | head -n1)" \
		|| die "no plug-in registered with identifier '$id'"
	[ -n "$line" ] || die "no plug-in registered with identifier '$id'"
	local tag="${line:0:1}"
	local state
	case "$tag" in
		'+') state="use (enabled)" ;;
		'-') state="ignore (disabled)" ;;
		'!') state="use for debugger" ;;
		'=') state="superseded by another plug-in" ;;
		'?') state="unknown / default" ;;
		*)   state="default (no explicit election)" ;;
	esac
	printf '%-40s %s\n' "$id" "$state"
}

cmd_paths() {
	local protocol="$DEFAULT_PROTOCOL"
	while [ $# -gt 0 ]; do
		case "$1" in
			-p) protocol="${2:-}"; [ -n "$protocol" ] || die "-p needs a protocol"; shift 2 ;;
			*)  die "unexpected argument: $1" ;;
		esac
	done
	# Verbose match line: "<flags> id(version)<TAB>UUID<TAB>date<TAB>path".
	# The election tag is column 1; the id is the last whitespace token of the
	# first field; the path is the final tab-separated field.
	"$PLUGINKIT" -mv -p "$protocol" 2>/dev/null | awk -F '\t' '
		NF >= 4 {
			tag = substr($0, 1, 1); if (tag == " ") { tag = "?" }
			n = split($1, f, /[[:space:]]+/); id = f[n]
			sub(/\([^)]*\)$/, "", id)
			printf "%s  %-40s  ->  %s\n", tag, id, $NF
		}
	' || die "could not list paths for protocol '$protocol'"
}

cmd_register() {
	local path
	path="$(resolve_bundle "${1:-}")"
	printf 'Registering: %s\n' "$path"
	"$PLUGINKIT" -a "$path" && printf 'Registered.\n'
}

cmd_unregister() {
	local path
	path="$(resolve_bundle "${1:-}")"
	printf 'Unregistering: %s\n' "$path"
	"$PLUGINKIT" -r "$path" && printf 'Unregistered.\n'
}

cmd_election() {
	local election="$1" id="${2:-}"
	[ -n "$id" ] || die "'$election' needs a bundle identifier"
	"$PLUGINKIT" -e "$election" -i "$id" \
		&& printf "Election set to '%s' for %s\n" "$election" "$id"
}

# ---------------------------------------------------------------------------
# dispatch
# ---------------------------------------------------------------------------

main() {
	require_pluginkit
	local command="${1:-}"
	[ $# -gt 0 ] && shift || true
	case "$command" in
		list)        cmd_list "$@" ;;
		list-all)    cmd_list_all "$@" ;;
		protocols)   cmd_protocols "$@" ;;
		info)        cmd_info "$@" ;;
		status)      cmd_status "$@" ;;
		paths)       cmd_paths "$@" ;;
		register)    cmd_register "$@" ;;
		unregister)  cmd_unregister "$@" ;;
		enable)      cmd_election use "$@" ;;
		disable)     cmd_election ignore "$@" ;;
		reset)       cmd_election default "$@" ;;
		help)        cmd_help "$@" ;;
		-h|--help|'') usage ;;
		*)           err "unknown command: $command"; echo; usage; exit 1 ;;
	esac
}

main "$@"
