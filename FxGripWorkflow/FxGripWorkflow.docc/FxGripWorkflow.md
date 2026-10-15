# ``FxGripWorkflow``

The companion framework a Final Cut Pro workflow extension links to reach FxGrip plug-ins and the host.

## Overview

A Final Cut Pro workflow extension is an app extension of the `com.apple.FinalCut.WorkflowExtension`
point that Final Cut Pro shows in a floating window. FxGripWorkflow gives such an extension three
things:

- ``FxGripWorkflowViewController``, the base for the principal view controller the Info.plist
  names. It owns the two clients below, accepts FCPXML drops through ``FxGripWorkflowDropView``,
  starts FCPXML drags into Final Cut Pro, sends documents to the host for import, and checks the
  bundle's configuration.
- ``FxGripFinalCutHost``, the running Final Cut Pro. It reads the open libraries, events, projects,
  and sequences through the host's scripting dictionary, imports FCPXML documents, and forwards the
  host's timeline notification. Through the `FCPXHost` object of Apple's Workflow Extensions SDK,
  which the extension executable supplies, it reports the playhead, the active sequence, and the
  sequence time range, and moves the playhead.
- ``FxGripWorkflowClient``, the extension's side of the mailbox to the plug-in instances built on
  FxGrip. It announces the extension's presence, lists the live instances, sends them FCPXML
  documents to apply, and collects the documents they publish.

The framework links FxGrip for the FCPXML model and the mailbox, so it runs where Final Cut Pro is
installed. <doc:BuildingAWorkflowExtension> walks through the extension target.

### How the two sides meet

An FxPlug plug-in and a workflow extension are separate sandboxed processes. They share the App
Group container of the wrapper application, and `FxGripWorkflowMailbox` in FxGrip keeps instance
records, a per-plug-in inbox, and an outbox there. On the plug-in side, the `FxGripWorkflowRelay`
extension registers each instance, applies inbox documents through `FxGripFCPXMLAPI_v1`, and
reports whether an extension is present. On this side, the client refreshes the presence record
and watches the mailbox.

## Topics

### The principal view controller

- ``FxGripWorkflowViewController``
- ``FxGripWorkflowDropView``
- <doc:BuildingAWorkflowExtension>

### The host

- ``FxGripFinalCutHost``
- ``FxGripFinalCutLibrary``
- ``FxGripFinalCutEvent``
- ``FxGripFinalCutProject``
- ``FxGripFinalCutSequence``
- ``FxGripFinalCutTimecodeFormat``
- ``FxGripFinalCutTimelineObserving``
- ``FxGripFinalCutTimelineNotification``

### The plug-in instances

- ``FxGripWorkflowClient``
- ``FxGripWorkflowClientChangeHandler``

### Info.plist keys

- ``FxGripWorkflowPrincipalViewControllerClassKey``
- ``FxGripWorkflowExtensionAttributesKey``
- ``FxGripWorkflowContentViewMinimumWidthKey``
- ``FxGripWorkflowContentViewMinimumHeightKey``

### The framework's version

- ``FxGripWorkflowVersionNumber``
- ``FxGripWorkflowVersionString``
