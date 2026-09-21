# ``FxGrip/FxGripCustomCreationAPI_v1-protocol``

Creates FxGrip's custom inspector controls, in the shape of Apple's creation APIs.

## Overview

This is the counterpart of `FxParameterCreationAPI` for the controls FxGrip adds. Each method
mirrors Apple's `addFloatSliderWithName:…` shape, builds the control's configuration dictionary, and
registers it through the effect host.

Call these during the plug-in's `addParameters`, the way Apple's creation API is called. Every
method answers YES when the host accepted the parameter.

``FxGripAPIAccessing-protocol`` vends the implementation as `customCreationAPIv1`, so a plug-in that
only wraps its API manager creates FxGrip controls with no further adoption. The accessor answers
nil when the manager carries no effect host, because the API registers through one.

<doc:CustomControls> shows what each control looks like, and <doc:Adoption> covers the adoption
levels.

## Topics

### Laying out the inspector

- ``addSectionWithName:parameterID:parameterFlags:``
- ``addDividerWithParameterID:parameterFlags:``
- ``addBannerWithName:parameterID:title:subtitle:parameterFlags:``
- ``addCapsuleWithName:parameterID:title:parameterFlags:``

### Reporting progress and state

- ``addStatusWithName:parameterID:state:label:parameterFlags:``
- ``addProgressWithName:parameterID:state:label:fraction:parameterFlags:``

### Taking a value

- ``addSwitchWithName:parameterID:defaultValue:parameterFlags:``
- ``addRandomWithName:parameterID:defaultValue:minimum:maximum:step:parameterFlags:``

### Showing web and video content

- ``addWebViewWithName:parameterID:URL:whitelist:height:parameterFlags:``
- ``addVideoViewWithName:parameterID:URL:whitelist:height:autoplay:loop:parameterFlags:``

### Showing the render

- ``addLiveImageWithName:parameterID:labels:height:parameterFlags:``
