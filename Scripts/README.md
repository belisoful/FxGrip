# Scripts

Developer tooling for the FxGrip project.

## `make-fxfactory-stub.sh`

Builds a link-only stub of `FxFactory.framework` for CI: the public headers, the module map, the
Info.plist, and a text-based stub (`.tbd`) made with `tapi stubify` in place of the binary. FxGrip
weak-links FxFactory, so a CI build compiles and links against the stub, and the FxFactory symbols
resolve to NULL at runtime.

```bash
# Write build/FxFactory-stub/<version>/FxFactory.framework from the installed framework
Scripts/make-fxfactory-stub.sh

# Build the stub, then commit, tag v<version>, and push it to a clone of belisoful/FxFactory-SDK
Scripts/make-fxfactory-stub.sh --publish ~/Code/FxFactory-SDK
```

To upgrade, update FxFactory, launch it once so it installs the new framework, run the script
with `--publish`, and set the Actions variable `FXFACTORY_VERSION` to the new version.

## `make-fcpxml-schema.py`

Regenerates `FxGrip/FCPXML/FxGripFCPXMLSchemaTable.m`, the FCPXML element and attribute table
`FxGripFCPXMLSchema` reads, from the DTDs inside the installed Final Cut Pro
(`Contents/Frameworks/Interchange.framework/Resources/FCPXMLv1_N.dtd`). The table records, for every
element, the version that introduced it, the version that removed it, its allowed children, and its
attributes with their kind, enumeration, default, required flag, and introducing version.

```bash
# Regenerate from the installed Final Cut Pro
Scripts/make-fcpxml-schema.py

# Read the DTDs from another folder and keep a JSON copy of the merged table
Scripts/make-fcpxml-schema.py --dtd-dir /path/to/dtds --json /tmp/fcpxml-schema.json
```

Run it after a Final Cut Pro update adds a DTD version, then update the latest-version pin in
`FxGripTests/FCPXML/FxGripFCPXMLSchemaTests.m`.

## `fxgrip-slang.sh`

Compiles a Slang compute kernel written against `GripKernel.slang` into the Metal source and the
reflection JSON that `FxGripKernelEffect` loads at runtime. It runs the command the Kernels DocC
article specifies:

```bash
slangc -I <module dir> <kernel>.slang -target metal -entry fxGripKernel -stage compute \
       -line-directive-mode standard -reflection-json <kernel>.json -o <kernel>.metal
```

`slangc` comes from `$FXGRIP_SLANGC`, then the `PATH`. The module directory comes from
`$FXGRIP_KERNEL_MODULE_DIR`, then `FxGrip/Shader` in this checkout, then
`FxGrip.framework/Resources` in `$BUILT_PRODUCTS_DIR`. The framework ships `GripKernel.slang` in its
`Resources` folder, so a plug-in project that links FxGrip passes
`-I "$BUILT_PRODUCTS_DIR/FxGrip.framework/Resources"`. The script compiles from the kernel's own
directory, so the emitted `#line` directives name `<kernel>.slang` without a path.

```bash
# Write Blur.metal and Blur.json beside Blur.slang
Scripts/fxgrip-slang.sh Blur.slang

# Write the three files into one directory, with another entry point
Scripts/fxgrip-slang.sh --entry blurKernel --output-dir build/kernels --copy-source Blur.slang
```

### The Xcode build rule

A plug-in project builds each kernel at compile time and bundles the three files as resources.
Xcode feeds a build rule's output files to its other rules, so a `.metal` written to
`$(DERIVED_FILE_DIR)` compiles into `default.metallib` and a `.json` there is dropped with "no rule
to process file". Writing the outputs into the product's `Resources` folder avoids both: the files
land in the bundle as they are, and the `.metal` text stays a resource the framework compiles at
runtime.

1. In the target's Build Rules, add a rule that processes "Source files with names matching"
	`*.slang` using a custom script.
2. Script:
	```bash
	"${FXGRIP_ROOT}/Scripts/fxgrip-slang.sh" \
		--output-dir "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" \
		--copy-source "${INPUT_FILE_PATH}"
	```
	where `FXGRIP_ROOT` is a build setting naming the FxGrip checkout, or the script is copied into
	the plug-in project. Set `FXGRIP_SLANGC` in the target's build settings, or put `slangc` on the
	`PATH` Xcode runs scripts with.
3. Output files:
	```
	$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/$(INPUT_FILE_BASE).slang
	$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/$(INPUT_FILE_BASE).metal
	$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/$(INPUT_FILE_BASE).json
	```
4. Add each `.slang` file to the target's Compile Sources phase, which is where the rule runs.
	The rule copies the `.slang` into the bundle, so the file is not also listed in Copy Bundle
	Resources.

The kernel effect subclass then names the kernel by its bundled URL:

```objc
- (NSURL *)kernelURL
{
    return [[NSBundle bundleForClass:self.class] URLForResource:@"Blur" withExtension:@"slang"];
}
```

A kernel that fails to compile fails the build with `slangc`'s diagnostics, which name the Slang
source lines.

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
