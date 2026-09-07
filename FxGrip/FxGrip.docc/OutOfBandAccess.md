# Out-of-Band Parameter Access

Read and write host parameters from code that runs outside a host callback by bracketing it in an access context.

## Overview

FxPlug limits parameter retrieval and setting to certain host callbacks. The parameter-setup, parameter-change, and plugin-state callbacks may read parameters; code the host does not call cannot. A custom parameter view receives AppKit callbacks outside the host's managed plug-in call stack, and a generation hook runs off a background queue. Neither can reach the host parameters on its own.

``FxGripOOBParameterAccess`` opens the window. The class wraps FxPlug's `FxCustomParameterActionAPI_v4`, calling `startAction` when it becomes active and `endAction` when it deactivates or deallocates. Holding an instance for the duration of an edit opens an out-of-band window in which the standard parameter set and get APIs reach the host.

## When the access is needed

An out-of-band context is needed wherever the plug-in reads or writes a parameter from code the host did not call:

- an interactive custom control writes the user's edit back. A switch toggle, a random field edit, and a curve point drag all write from an AppKit callback (see <doc:CustomControls>).
- a push-button action reads a parameter to start work, or writes a status parameter to report it.
- a generation or inference hook writes progress into a status or progress parameter from a background queue (see <doc:Inference>).

Code that already runs inside a host callback does not open a context. The host has opened the window for the duration of the callback.

## The scoped lifetime

The context deactivates when the returned object is released, so a stack variable brackets an edit for its own scope. The `dealloc` closes an action still open. The `access:` factory returns an autoreleased instance, and the object stays alive to the end of the enclosing autorelease scope, which is the callback that opened it.

```objc
FxGripOOBParameterAccess *__attribute__((unused)) access = [FxGripOOBParameterAccess access:self];
CMTime time = access.currentTime;
[self.apiManager.paramSetAPIv5 setCustomParameterValue:value
                                           toParameter:kStateID
                                                atTime:time];
```

The `__attribute__((unused))` suppresses the unused-variable warning when the code reads no member off the accessor and holds it only to keep the action open. The effect base exposes the same context through `startContext` on `FxGripTileableEffect (OOBParameterAccess)`.

## The current time

The accessor's `currentTime` reads the host's current time from the action API. Code outside a host callback has no render time argument, so it reads the time to act on from the context:

```objc
- (BOOL)parameterClicked:(FxParameterId)parameterID
{
    if (parameterID == kGenerateID) {
        [self beginGenerationAtTime:[FxGripOOBParameterAccess access:self].currentTime];
        return YES;
    }
    return [super parameterClicked:parameterID];
}
```

A parameter written under the context is written at that time, so the write lands on the frame the inspector is showing.

## Flush on close

An edit that extensions must observe closes the context with a flush. `endAction` posts `FxGripTileableEffectFlushName` on the host's notifier before closing the action when the accessor's `flush` is set, which is what the effect base's `extensionsFlush` does inside a callback. Create the context with the flush variant, or `startContextFlush` on the effect base, when the edit changes state an extension writes to the host:

```objc
FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:self flush:YES];
// edit parameters; extensions observe the flush when access is released.
```

The `access:delay:` variants defer the `startAction` so the caller opens the window explicitly through the `active` property.

## Topics

### The access context

- ``FxGripOOBParameterAccess``

### Related articles

- <doc:CustomControls>
- <doc:Inference>
