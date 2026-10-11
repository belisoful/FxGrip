# Building a Workflow Extension

Add a Final Cut Pro workflow extension target to a plug-in's wrapper application and connect it to the plug-in.

## Overview

A workflow extension ships inside the same wrapper application as the FxPlug plug-in. Apple's
Workflow Extensions SDK is optional: the extension point, the Info.plist keys, and the entitlements
below are what Final Cut Pro reads, and FxGripWorkflow supplies the rest.

## The extension target

Add a macOS app extension target to the wrapper application and set its Info.plist:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.FinalCut.WorkflowExtension</string>
    <key>ProExtensionPrincipalViewControllerClass</key>
    <string>MyWorkflowController</string>
    <key>ProExtensionAttributes</key>
    <dict>
        <key>ContentViewMinimumWidth</key>
        <integer>370</integer>
        <key>ContentViewMinimumHeight</key>
        <integer>400</integer>
    </dict>
</dict>
```

Final Cut Pro instantiates the named class and shows its view; the attributes set the window's
minimum content size. The target links `FxGripWorkflow.framework` and `FxGrip.framework`, and the
wrapper application embeds both.

## Entitlements

The extension is sandboxed. Library inspection goes through Apple Events to Final Cut Pro, which
needs:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.automation.apple-events</key>
<true/>
<key>com.apple.security.scripting-targets</key>
<dict>
    <key>com.apple.FinalCut</key>
    <array><string>com.apple.FinalCut.library.inspection</string></array>
    <key>com.apple.FinalCutTrial</key>
    <array><string>com.apple.FinalCut.library.inspection</string></array>
</dict>
<key>com.apple.security.application-groups</key>
<array><string>group.com.example.myplugin</string></array>
```

The wrapper application's Info.plist carries `NSAppleEventsUsageDescription`, which macOS shows
the first time the extension reaches Final Cut Pro. The App Group is the one the plug-in's
extension carries too; the mailbox lives in its container.
``FxGripWorkflowViewController/configurationProblemsForBundle:`` lists what is missing, so a
DEBUG build can log it at launch.

## The principal view controller

Subclass ``FxGripWorkflowViewController`` and override the two hooks:

```objc
@interface MyWorkflowController : FxGripWorkflowViewController
@end

@implementation MyWorkflowController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self registerForFCPXMLDropsOnView:(FxGripWorkflowDropView *)self.view];
}

- (void)workflowClientDidChange
{
    // self.client.instances lists the live plug-in instances; self.client.exports the
    // documents they published.
    [self.tableView reloadData];
}

- (void)workflowDidReceiveDocument:(FxGripFCPXMLDocument *)document
{
    // A clip dragged out of Final Cut Pro, parsed. Send its first filter to an instance:
    FxGripWorkflowInstanceRecord *instance = self.client.instances.firstObject;
    [self.client sendDocument:document toInstance:instance name:@"From the timeline" error:NULL];
}

@end
```

`viewDidLoad` starts the client, which writes the extension's presence record; the plug-in's
relay then reports its link as connected. A document sent to an instance lands in the plug-in's
inbox, and the relay applies it out of band at the host's current time.

## Reaching the host

```objc
NSError *error = nil;
NSArray<FxGripFinalCutLibrary *> *libraries = [self.host librariesWithError:&error];
FxGripFinalCutSequence *sequence = libraries.firstObject.projects.firstObject.sequence;
// sequence.frameDuration, sequence.duration, sequence.timecodeFormat

[self.host importDocument:document named:@"Grip Preset" completion:^(NSError *error) { }];
```

Library inspection is one Apple Event round trip, so run it off the main thread or on a user
action. Importing writes the document to a temporary `.fcpxml` file and opens it in Final Cut
Pro, which imports it into the open library. To drop a document into the timeline instead, start a
drag with ``FxGripWorkflowViewController/draggingItemForDocument:inView:image:``.

## The plug-in side

The plug-in opts in with the `workflow` plugin property:

```xml
<key>workflow</key>
<true/>
```

Its `FxGripWorkflowRelay` registers each instance when the effect joins a document and applies what
the extension sends. A Status control can show `workflowRelay.statusDescription`, which reads
"connected" while the extension's presence record is fresh.
