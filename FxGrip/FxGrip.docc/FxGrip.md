# ``FxGrip``

FxGrip is a framework for FxPlug 4 that adds features and functionality beyond Apple's implementation.

## Overview

FxGrip wraps the standard FxPlug host API protocols and adds its own APIs, parameter model, plug-in registrars, and host-integration extensions for Final Cut Pro and Motion plug-ins. It is macOS-only, because FxPlug hosts are macOS applications.

Two base classes anchor the framework:

- ``FxGripTileableEffect-class`` — the effect base, an `FxTileableEffect` that drives the parameter subsystem, the extensions, presets, analysis, and the render pass.
- ``FxGripTileableGenerator`` — the generator counterpart, for a plug-in that produces an image with no source.

FxGrip is adoptable in layers. A plug-in links one utility, wraps the host API, adopts the parameter subsystem through a host, or subclasses the effect base for the whole framework. <doc:Adoption> maps the levels.

## Topics

### Getting started

- <doc:Adoption>
- <doc:EffectAndGenerator>

### Core concepts

- <doc:ExtensionArchitecture>
- <doc:PluginState>
- <doc:OutOfBandAccess>
- <doc:AnalysisPass>
- <doc:MetaAndTags>
- <doc:Timing>
- <doc:ColorAndGamut>
- <doc:TilingAndGeometry>
- <doc:Versioning>

### Parameters

- <doc:FxPlugParameters>
- <doc:StandardValueParameters>
- <doc:ParameterModel>
- <doc:ParameterFlags>

### Custom parameter controls

- <doc:CustomControls>
- <doc:CustomParameterData>
- <doc:Section>
- <doc:Divider>
- <doc:Banner>
- <doc:Capsule>
- <doc:Status>
- <doc:Progress>
- <doc:Switch>
- <doc:Random>
- <doc:Curve>
- <doc:LiveImage>
- <doc:WebView>
- <doc:Video>
- <doc:Analyzer>
- <doc:TrackingOpacity>

### On-screen controls

- <doc:OnScreenControls>

### 3D space

- <doc:Space3D>

### Object tracking

- <doc:ObjectTracking>

### Machine-learning effects

- <doc:Inference>

### Web and video content

- <doc:WebContent>

### Preset system

- <doc:Presets>

### Host APIs and registration

- <doc:APIAccessing>
- <doc:Registration>

### Extensions

- <doc:ExtensionArchitecture>
- <doc:ExtensionSystem>
- <doc:ParameterExtensions>
- <doc:I18N>
- <doc:Meta>
- <doc:ParameterData>
- <doc:AboutMenu>
- <doc:DebugMenu>
- <doc:GoogleAnalytics>
- <doc:InstanceTracker>
- <doc:Regression>
- <doc:Analysis>
- <doc:MLCache>
- <doc:Window>

### Utility classes

- <doc:Utilities>
- <doc:ImageBuffer>
- <doc:TextAndWatermark>
- <doc:EventModifiers>

### Primary classes

- ``FxGripTileableEffect-class``
- ``FxGripTileableGenerator``
- ``FxGripAPIAccessing-class``
- ``FxGripEffectHost``
- ``FxGripPluginHost``

### Error codes

- ``FxGripPlugErrorDomain``
- ``FxGripPlugErrorDomainConstant``
- ``kFxGripError_Exception``
- ``kFxGripError_NoClassFound``
- ``kFxGripError_NonconformingClass``
- ``kFxGripError_NoSingleton``
- ``kFxGripError_NoneFound``
- ``kFxGripError_NoConfigGroups``
- ``kFxGripError_NoConfigPlugins``
- ``kFxGripError_Preset``
- ``kFxGripError_WindowAPIUnavailable``
- ``kFxGripError_WatermarkNoDevice``
- ``kFxGripError_WatermarkRender``
- ``kFxGripError_SpaceMissingScene``
- ``kFxGripError_SpaceRenderFailure``
- ``kFxGripError_InferenceNotReady``
- ``kFxGripError_InferenceMissingInput``
- ``kFxGripError_InferenceBackendFailure``

### The framework's version

- ``FxGripVersionNumber``
- ``FxGripVersionString``
