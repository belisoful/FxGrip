# Workflow Extensions

Link a plug-in's instances with a Final Cut Pro workflow extension through a shared mailbox.

## Overview

A Final Cut Pro workflow extension is an app extension Final Cut Pro shows in a floating window.
It can read the open libraries, import FCPXML, and accept and start FCPXML drags, which is what a
plug-in cannot do from its inspector. FxGrip connects the two sides so an extension can push a
captured effect into a plug-in instance and collect what an instance captured.

The plug-in and the extension are separate sandboxed processes. A sandboxed process can neither
register a Mach service nor attach a userInfo to a distributed notification, so they share files
in the App Group container of their wrapper application, and nudge each other with a name-only
distributed notification:

- ``FxGripWorkflowMailbox`` is the shared folder: one ``FxGripWorkflowInstanceRecord`` per live
  plug-in instance, an inbox per plug-in for documents to apply, an outbox for documents a plug-in
  published, and the extension's presence record. A message is one property-list file written
  atomically.
- ``FxGripWorkflowRelay`` is the plug-in-side extension. The loader installs it when the `workflow`
  plugin property (``kProPlugPlugInX_WorkflowProperty``) is `YES` or a settings dictionary.
- `FxGripWorkflowClient` and `FxGripWorkflowViewController`, in the `FxGripWorkflow` companion
  framework, are the extension side. `FxGripFinalCutHost` there reaches Final Cut Pro through
  Apple Events and through the `FCPXHost` object of Apple's Workflow Extensions SDK, whose library
  the extension executable links.

The relay never runs on a render path. It applies documents out of band on the main thread and
reads nothing during a render.

## The relay

When the effect joins a document the relay writes its instance record: the plug-in UUID, display
name, version, session identifier, document identifier, host, and timeline range. A heartbeat
refreshes the record, and a parameter change refreshes the timeline range. The relay watches the
plug-in's inbox and, for each message addressed to its session or to every instance, opens an
out-of-band access, applies the document through ``FxGripFCPXMLAPI_v1-class`` at the host's current
time, and posts ``FxGripWorkflowRelayDidApplyDocumentName``. An addressed message is consumed; a
broadcast stays for the other instances, and the extension clears it.

```objc
// Opt in, with defaults.
kProPlugPlugInX_WorkflowProperty: @YES

// Opt in with settings.
kProPlugPlugInX_WorkflowProperty: @{
    @"applyOnReceive":   @YES,   // apply inbox documents on arrival
    @"heartbeatInterval": @15,   // seconds between record refreshes
    @"matchNames":       @YES,   // match a param by name when its key names no parameter
    @"undo":             @YES,   // one undo group per applied document
    @"keyframes":        @YES,   // apply keyframe animations
}
```

A `documentHandler` block vets each document before it applies; answering NO leaves the message in
place. `publishCaptureNamed:options:error:` captures the effect and drops the document in the
outbox for the extension.

## The link status

``FxGripWorkflowRelay/status`` is the capability indicator a Status control shows:

- `FxGripWorkflowLinkStatusUnavailable` → the process has no App Group container; the plug-in's
  extension carries no `com.apple.security.application-groups` entitlement.
- `FxGripWorkflowLinkStatusIdle` → the mailbox exists and no extension has reported itself
  within the presence window.
- `FxGripWorkflowLinkStatusConnected` → an extension refreshed its presence record recently.

``FxGripWorkflowRelayStatusChangedName`` is posted on the effect's notifier when the status moves,
and `statusDescription` is the sentence to show.

## Entitlements

Both the plug-in's extension and the workflow extension carry
`com.apple.security.application-groups` with the same group. The workflow extension adds the Apple
Events entitlements that library inspection needs; the `FxGripWorkflow` documentation lists them
with the extension target's build settings.

## Topics

### The plug-in side

- ``FxGripWorkflowRelay``
- ``FxGripWorkflowLinkStatus``
- ``FxGripWorkflowDocumentHandler``
- ``kProPlugPlugInX_WorkflowProperty``

### The mailbox

- ``FxGripWorkflowMailbox``
- ``FxGripWorkflowInstanceRecord``
- ``FxGripWorkflowMessage``
- ``FxGripWorkflowMailboxDidChangeNotification``

### Notifications

- ``FxGripWorkflowRelayDidApplyDocumentName``
- ``FxGripWorkflowRelayStatusChangedName``
- ``FxGripWorkflowRelayMessageIdentifierKey``
- ``FxGripWorkflowRelayStatusKey``
