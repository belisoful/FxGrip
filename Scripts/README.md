# Scripts

Developer tooling for the FxGrip project.

## `pluginkit-manager.sh`

A thin, developer-friendly wrapper around the macOS `pluginkit(8)` CLI for
managing PlugInKit app extensions — FxPlug plug-ins, and any other
NSExtension-based plug-in. It encapsulates the everyday tasks a plugin
developer needs while iterating: listing what the system has registered,
inspecting a single plug-in, forcing a build to register or unregister, and
toggling the per-user *election* state that decides whether a host will load
the plug-in.

`pluginkit` only ever manages plug-ins for the **current user**, and makes no
permanent change to the automatic registry — the OS re-discovers plug-ins on
its own.

### Requirements

- macOS (the script drives `/usr/bin/pluginkit`).
- No elevated privileges. Election and explicit register/unregister apply to
  the current user only.

### Usage

```bash
Scripts/pluginkit-manager.sh <command> [arguments]
Scripts/pluginkit-manager.sh help [command]
```

Run `help` with no argument for the overview, or `help <command>` for a
detailed walk-through of one command (its contract, the exact `pluginkit`
invocation it runs, and an example).

### Commands

**Listing / inspection**

| Command | What it does |
| --- | --- |
| `list [-p PROTOCOL]` | List plug-ins for a protocol (default: `FxPlug`). |
| `list-all` | List every registered plug-in, across all protocols. |
| `protocols` | List the distinct extension points currently present. |
| `info <bundleID>` | Verbose detail for one plug-in (all versions + duplicates). |
| `status <bundleID>` | Print just the election state, decoded into words. |
| `paths [-p PROTOCOL]` | List plug-ins as `state  bundleID  ->  path`. |

**Registration (development)**

| Command | What it does |
| --- | --- |
| `register <bundle-path>` | Explicitly add/register a plug-in bundle (`pluginkit -a`). |
| `unregister <bundle-path>` | Explicitly remove/unregister a plug-in bundle (`pluginkit -r`). |

**Election (per-user enable/disable)**

| Command | What it does |
| --- | --- |
| `enable <bundleID>` | Elect to **use** the plug-in — a host will load it. |
| `disable <bundleID>` | Elect to **ignore** the plug-in — a host will skip it. |
| `reset <bundleID>` | Reset election to **default** — the system decides. |

### Election states

Each `list` / `status` line begins with a tag indicating the per-user election:

| Tag | State | Meaning |
| --- | --- | --- |
| `+` | use | User elected to load the plug-in. |
| `-` | ignore | User elected to skip the plug-in. |
| `!` | debugger | Elected for debugger use. |
| `=` | superseded | A higher-priority plug-in with the same identifier wins. |
| `?` | default | No explicit election; the system decides. |

### Examples

```bash
# List the FxPlug plug-ins the system knows about
Scripts/pluginkit-manager.sh list

# Where does a plug-in live on disk, and is it active?
Scripts/pluginkit-manager.sh paths
Scripts/pluginkit-manager.sh status com.example.MyPlugin

# Register a freshly-built plug-in, then confirm and enable it
Scripts/pluginkit-manager.sh register ./build/Debug/MyPlugin.app/Contents/PlugIns/MyPlugin.appex
Scripts/pluginkit-manager.sh info com.example.MyPlugin
Scripts/pluginkit-manager.sh enable com.example.MyPlugin

# Temporarily hide a plug-in from hosts without removing it
Scripts/pluginkit-manager.sh disable com.example.MyPlugin
```

### Notes and caveats

- **`register` / `unregister` are not permanent.** Automatic discovery may
  re-add a bundle that is still on disk, and registry clean-ups may drop one
  that was added explicitly. The durable per-user control is **election**
  (`enable` / `disable`), which survives re-discovery.
- The extension point (protocol) is not present in the plain match output, so
  `protocols` reads it from `pluginkit --raw` XML.

### Exit status

- `0` — success.
- `1` — usage error, or the requested plug-in / path was not found.

### Roadmap

The script header carries an `@todo` describing a native macOS app that would
drive these same `pluginkit` operations from a GUI: a window listing plug-ins
with checkboxes (checked = currently used), drag-and-drop or an Open… dialog to
add an available plug-in, and a Remove action gated to inactive plug-ins only,
with the list live-refreshing to stay in sync with system state.
