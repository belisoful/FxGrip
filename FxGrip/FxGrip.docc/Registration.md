# Registering Plug-ins

Register a plug-in's effects, generators, and on-screen controls with the FxPlug host through one of FxGrip's registrars.

## Overview

An FxPlug host loads a bundle through a principal class that conforms to
`PROPlugInRegistering`. The host asks that class for the plugin list and the plugin
group list. ``FxGripStaticRegistrar`` is the entry point: it implements
`PROPlugInRegistering`, validates each record, and freezes the results into
immutable, localized arrays.

A subclass supplies the records through the `FxGripStaticRegistrarSubclass` hooks,
and the base class stores them. FxGrip ships three subclasses, each sourcing the
records a different way:

- ``FxGripConfigRegistrar`` → reads the plugin and group lists from the bundle's
  `Info.plist`.
- ``FxGripClassRegistrar`` → reads a list of class names from the bundle's
  `Info.plist` and registers each named class.
- ``FxGripDynamicRegistrar`` → discovers conforming classes from the Objective-C
  runtime.

## The registration record

``FxGripStaticRegistrar`` collects plugins first, then groups, then rewrites any
plugin that names an on-screen control. It validates each plugin dictionary and
rejects one that is missing a required key or whose class is not loaded.

A plugin dictionary carries these required keys:

| Key | Constant | Value |
| --- | --- | --- |
| `uuid` | `kProPlugPlugIn_UuidProperty` | The plugin's UUID. |
| `className` | `kProPlugPlugIn_ClassNameProperty` | The plugin class name. |
| `displayName` | `kProPlugPlugIn_DisplayNameProperty` | The inspector display name. |
| `group` | `kProPlugPlugIn_GroupUUIDProperty` | The UUID of the containing group. |
| `protocolNames` | `kProPlugPlugIn_ProtocolNamesProperty` | The FxPlug protocol names. |
| `version` | `kProPlugPlugIn_VersionProperty` | An integer version; `1000` encodes v1.0.0.0. |

A group dictionary carries two keys, `uuid` and `groupName`
(`kProPlugPlugInX_RegGroupUUIDProperty` and `kProPlugPlugInX_RegGroupNameProperty`).
Every plugin's `group` UUID names a registered group.

`protocolNames` holds the FxPlug protocols the plugin implements, such as
`FxFilter`, `FxGenerator`, or `FxOnScreenControl`. A scalar value is wrapped in an
array.

``FxGripPluginData`` and ``FxGripPluginGroupData`` model these dictionaries with
typed accessors. Each named property reads and writes its entry under the matching
`kProPlugPlugIn_*` key, and keyed subscripting reaches entries with no named
property. ``FxGripPluginData`` coerces `protocolNames` and `supportedPlugins` to
arrays and a string `version` to a number as it stores them.

## The config registrar

``FxGripConfigRegistrar`` reproduces the host's static registration path with the
values supplied through the bundle's `Info.plist`. It reads the plugin list from
`ProPlugPlugInList` (`kProPlugPlugInList_Property`) and the group list from
`ProPlugPlugInGroupList` (`kProPlugPlugIn_GroupList_Property`). A missing list is
reported through the error argument.

```xml
<key>ProPlugPlugInGroupList</key>
<array>
    <dict>
        <key>uuid</key>       <string>29CB3EBF-60C2-4634-B29C-11C6FE8C9E9E</string>
        <key>groupName</key>  <string>My Effects</string>
    </dict>
</array>
<key>ProPlugPlugInList</key>
<array>
    <dict>
        <key>uuid</key>          <string>D401D6C0-A0D9-4FD8-BD82-B4C7DC410722</string>
        <key>className</key>     <string>MyEffect</string>
        <key>displayName</key>   <string>My Effect</string>
        <key>group</key>         <string>29CB3EBF-60C2-4634-B29C-11C6FE8C9E9E</string>
        <key>protocolNames</key>
        <array><string>FxFilter</string></array>
        <key>version</key>       <integer>1000</integer>
    </dict>
</array>
```

## The class registrar

``FxGripClassRegistrar`` sources its plugins from the bundle's
`FxGripRegisteredPlugins` key (`kProPlugPlugInX_FxRegisteredPlugins_Property`). The
value is an `NSString` of separated class names, an `NSArray`, or an `NSDictionary`.
The base class resolves and registers each named class through its
`registeredPlugInInformation:` method, so each class carries its own records.

## The dynamic registrar

``FxGripDynamicRegistrar`` scans every loaded class for conformance to
``FxGripRegisteredPlugin`` and registers the matches. It uses runtime introspection
rather than message sends, so a class that cannot receive messages is skipped
safely. Group discovery follows plugin discovery, because a plugin names the group
it belongs to. A group name resolves from the plugin class, then from the bundle's
group list, then from a numbered placeholder.

A conforming class returns its records from
`registeredPlugInInformation:`. The return value is a plugin dictionary, an array of
plugin dictionaries, or a dictionary carrying the plugin and group lists under
`kProPlugPlugInList_Property` and `kProPlugPlugIn_GroupList_Property`. The optional
`isRegisteredPlugIn` method returns `NO` to exclude a class, and `groupName` and
`groupNameForUUID:` supply group display names.

The host reaches the dynamic registrar through the bundle's `Info.plist`:
`ProPlugDynamicRegistration` (`kProPlugDynamicRegistration_Property`) enables it, and
`ProPlugDynamicRegistrationPrincipalClass`
(`kProPlugDynamicRegistrationPrincipalClass_Property`) names the principal class.
``FxGripPluginInfo`` reads these keys and loads the lists from the named registrar,
mirroring the host's own loading of the `Info.plist` lists.

## On-screen control linkage

An on-screen control registers as a second plugin entry whose `protocolNames` is
`FxOnScreenControl`. FxPlug ties a control to the effects it serves through the
control's `supportedPlugins` list. With FxGrip's registrar the effect's entry names
its control under the `osc` key (`kProPlugPlugInX_OSCUUIDsProperty`), which holds one
UUID string, an array, or a dictionary of UUIDs.

During registration ``FxGripStaticRegistrar`` reads each effect's `osc` value,
removes the `osc` key from the effect record, and adds the effect's UUID to each
named control's `supportedPlugins` (`kProPlugPlugIn_SupportedPluginsProperty`). A
control UUID that names no registered plugin logs an error and is skipped. See
<doc:OnScreenControls> for the control class and a full plist example with both
entries.

## Choosing a registrar

- Static plugin list in the `Info.plist` → ``FxGripConfigRegistrar``.
- A class name list in the `Info.plist`, each class owning its records →
  ``FxGripClassRegistrar``.
- No `Info.plist` list, plugins discovered from loaded classes →
  ``FxGripDynamicRegistrar``.
- A custom record source → subclass ``FxGripStaticRegistrar`` and implement the
  `FxGripStaticRegistrarSubclass` hooks.

## Topics

### Base registrar

- ``FxGripStaticRegistrar``
- ``FxGripStaticRegistrarSubclass``
- ``FxGripRegisteringPlugins``
- ``FxGripRegisteringGroups``

### Registrar subclasses

- ``FxGripConfigRegistrar``
- ``FxGripClassRegistrar``
- ``FxGripDynamicRegistrar``
- ``FxGripRegisteredPlugin``

### Record model

- ``FxGripPluginData``
- ``FxGripPluginGroupData``
- ``FxGripPluginInfo``

### Related articles

- <doc:Adoption>
- <doc:OnScreenControls>

### The registration lists

- ``kProPlugPlugInList_Property``
- ``kProPlugPlugIn_GroupList_Property``
- ``kProPlugPlugInX_FxRegisteredPlugins_Property``

### Identifying a plug-in

- ``kProPlugPlugIn_ClassNameProperty``
- ``kProPlugPlugIn_DisplayNameProperty``
- ``kProPlugPlugIn_UuidProperty``
- ``kProPlugPlugIn_VersionProperty``
- ``kProPlugPlugIn_InfoStringProperty``
- ``kProPlugPlugIn_GroupUUIDProperty``
- ``kProPlugPlugIn_SupportedPluginsProperty``
- ``kProPlugPlugInX_PriorUuidsProperty``

### The registration group

- ``kProPlugPlugInX_RegGroupNameProperty``
- ``kProPlugPlugInX_RegGroupUUIDProperty``

### The protocols a plug-in declares

- ``kProPlugPlugIn_ProtocolNamesProperty``
- ``kProPlugPlugIn_ProtocolFxBaseEffect``
- ``kProPlugPlugIn_ProtocolFxFilter``
- ``kProPlugPlugIn_ProtocolFxGenerator``
- ``kProPlugPlugIn_ProtocolFxOnScreenControl``

### Declaring parameters and properties

- ``kProPlugPlugInX_ParametersProperty``
- ``kProPlugPlugInX_EffectPropertiesProperty``
- ``kProPlugPlugInX_DefaultFontNameProperty``
- ``kProPlugPlugInX_OSCUUIDsProperty``

### Turning extensions on

- ``kProPlugPlugInX_AboutMenuProperty``
- ``kProPlugPlugInX_DebugMenuProperty``
- ``kProPlugPlugInX_DebugActivatorProperty``
- ``kProPlugPlugInX_GoogleAnalyticsProperty``
- ``kProPlugPlugInX_InternationalizeProperty``
- ``kProPlugPlugInX_ManagedMetaProperty``
- ``kProPlugPlugInX_ManagedParameterDataProperty``
- ``kProPlugPlugInX_PresetsProperty``
- ``kProPlugPlugInX_RegressionProperty``
- ``kProPlugPlugInX_TrackInstancesProperty``
- ``kProPlugPlugInX_FxFactoryProperty``

### Delocalization

- ``kProPlugPlugInX_DelocalizeMenusProperty``
- ``kProPlugPlugInX_DelocalizeNamesProperty``
- ``kProPlugPlugInX_DelocalizeValuesProperty``

### Dynamic registration

- ``kProPlugDynamicRegistration_Property``
- ``kProPlugDynamicRegistrationPrincipalClass_Property``
- ``FxGripPrincipalDelegate``
- ``kDefaultPluginID``
- ``kFxGripLibraryActivator``
