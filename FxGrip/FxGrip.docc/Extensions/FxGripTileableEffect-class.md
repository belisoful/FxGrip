# ``FxGrip/FxGripTileableEffect-class``

The concrete base class an FxGrip tileable effect plug-in subclasses.

## Overview

The class drives the whole framework. It owns the parameter subsystem, loads and orders the
extensions, resolves the plug-in's identity from its registration record, and hands the render pass
either FxPlug's `pluginState` data or an `NSCoder`.

A plug-in that produces an image with no source subclasses ``FxGripTileableGenerator`` instead.

### Setup order

Setup runs in stages, and a property reports each one as it completes. An extension or a category
reads these to tell what is ready.

- ``addingParameters`` → the `addParameters` pass is running.
- ``addedParameters`` → every declared parameter exists and has been validated.
- ``finishedSetup`` → the effect finished its initial setup.
- ``addedToDocument`` → the host has placed the effect in a document.

### Declaring parameters

``parametersConfiguration`` returns the declaration a subclass writes, and
``addParametersWithGroupID:error:`` walks it, one group at a time. A parameter reached afterward
through `effect[parameterID]`, which is ``objectAtIndexedSubscript:``.

A parameter type that FxGrip does not ship registers through ``registerParameterType:``, and the
type-to-class map resolves it during the add.

<doc:FxPlugParameters> covers the declaration dictionary, and <doc:ParameterModel> covers the
parameter objects.

### The render pass

The effect implements ``FxGripTileableEffectCoderStateWeak``, so a subclass takes the render
callbacks in either form. The `pluginState` form is FxPlug's own. The `pluginCoder` form replaces
the opaque `NSData` with an `NSCoder`, so the subclass writes typed values and reads them back in
each stage.

``pluginStateCompression`` applies a lossless codec to the encoded state, gated by
``pluginStateCompressionThreshold``. The decode side detects the codec from the blob, so the setting
is safe to change per instance. <doc:PluginState> covers the state and its wire format.

### Extensions

An extension adds host integration without the subclass naming it. ``loadExtensions`` is the hook a
subclass overrides to load its own, and each `newXxxExtension` method is the seam FxGrip's own
extensions come through. ``extensionsFlush`` runs the pending flush across all of them.

<doc:ExtensionArchitecture> covers the ordering, and <doc:ExtensionSystem> covers the system.

## Topics

### Creating the effect

- ``init``
- ``initWithAPIManager:``

### Declaring the plug-in's properties

- ``properties:error:``
- ``finishedProperties``
- ``propertiesFromConfiguration``
- ``isEffectPropertiesInInfo``
- ``needsFullBuffer``
- ``variesWhenParamsAreStatic``
- ``changesOutputSize``
- ``mayRemapTime``
- ``drawsInScreenSpace``
- ``usesNonmatchingTextureLayout``
- ``desiredProcessingColorInfo``
- ``pixelTransformSupport``

### Following the setup stages

- ``addingParameters``
- ``addedParameters``
- ``finishedSetup``
- ``addedToDocument``

### Identifying the plug-in

- ``pluginUUID``
- ``pluginVersion``
- ``pluginStringVersion``
- ``pluginDisplayName``
- ``pluginGroupUUID``
- ``pluginInfoString``
- ``pluginProperties``
- ``sessionID``

### Reaching the host

- ``apiManager``
- ``notifier``
- ``effect``

### Declaring parameters

- ``parametersConfiguration``
- ``addParametersWithGroupID:error:``
- ``configurationForParameter:``
- ``parameterForDictionary:``
- ``defaultFontName``

### Reaching a parameter

- ``objectAtIndexedSubscript:``
- ``parameters``
- ``parameterCount``
- ``countByEnumeratingWithState:objects:count:``

### Registering a parameter type

- ``registerParameterType:``
- ``loadTypeToClassMap``
- ``parameterClassWithType:``
- ``parameterClassWithTypeString:``
- ``parameterStringWithType:``
- ``parameterTypeWithString:``

### Responding to a parameter

- ``parameterClicked:``
- ``createViewForParameterID:``

### Reading parameters outside a render

- ``startContext``
- ``startContextFlush``

### Encoding the plug-in state

- ``pluginStateCompression``
- ``pluginStateCompressionThreshold``

### Loading extensions

- ``loadExtensions``
- ``initializeExtensions``
- ``extensions``
- ``extensionsFlush``

### Finding an extension

- ``objectForKeyedSubscript:``
- ``extensionForKey:``
- ``extensionForClass:``
- ``extensionForProtocol:``
- ``extensionsForKey:``
- ``extensionsForClass:``
- ``extensionsForProtocol:``
- ``hasExtensionKey:``
- ``hasExtensionClass:``
- ``hasExtensionProtocol:``

### Creating FxGrip's own extensions

- ``newAboutMenuExtension``
- ``newAnalysisExtension``
- ``newDebugMenuExtension``
- ``newFxInstanceTracker``
- ``newGoogleAnalyticsExtension``
- ``newI18NExtension``
- ``newMetaExtension``
- ``newMLCacheExtension``
- ``newParameterDataExtension``
- ``newPhysicsBakeExtension``
- ``newRegressionExtension``
- ``newWindowExtension``

### Testing which extensions loaded

- ``hasAboutMenu``
- ``hasAnalysis``
- ``hasDebugMenu``
- ``hasMeta``
- ``hasMLCache``
- ``hasPhysicsBake``
- ``hasWindowExtension``
- ``isGoogleAnalyticsInstalled``
- ``isInternationalized``
- ``isRegression``
- ``isTrackingInstances``

### Reaching an extension's object

- ``aboutMenu``
- ``analysisData``
- ``debugMenu``
- ``googleAnalytics``
- ``i18n``
- ``instanceTracker``
- ``meta``
- ``mlCacheData``
- ``parameterData``
- ``physicsBakeData``
- ``regression``
- ``windowExtension``

### The about and debug menus

- ``aboutMenuConfiguration``
- ``aboutMenuItems:``
- ``allowsDebugFeatures``
- ``pluginDebugActivatorEnabled``
- ``pluginDebugMenuEnabled``

### Tracking instances

- ``instances``
- ``instanceCount``
- ``instanceAtIndex:``
- ``gaIdentifier``

### Frame timing

- ``frameDuration``
- ``sampleDuration``
- ``retimingSpeed``
- ``isInterlacedClip``
- ``frameForTime:``
- ``timeByOffsettingTime:byFrames:``

### Drop frame and timecode

- ``isTimelineDropFrame``
- ``isInputDropFrame``
- ``isDropFrameOfImageParameter:``
- ``timelineTimecodeStringForTime:``
- ``inputTimecodeStringForTime:``

### The effect on the timeline

- ``effectStartTime``
- ``effectStartFrame``
- ``effectStartTimeInTimeline``
- ``effectDurationTime``
- ``effectDurationFrames``
- ``effectInPointOfTimeLine``
- ``effectOutPointOfTimeLine``

### The input clip

- ``inputStartTime``
- ``inputStartFrame``
- ``inputStartTimeInTimeline``
- ``inputDurationTime``
- ``inputDurationFrames``

### The timeline frame rate

- ``timelineFps``
- ``timelineFpsNumerator``
- ``timelineFpsDenominator``
- ``timelineFrameDuration``
- ``timelineFrameDurationFloat``
- ``timelineFrameRate``

### Converting between time bases

- ``timelineTime:fromInputTime:``
- ``inputTime:fromTimelineTime:``

### Requesting a source tile

- ``sourceTileRequestAtTime:``
- ``sourceTileRequestAtTime:frameOffset:``

### Color and gamut

- ``colorPrimaries``
- ``isRec709Gamut``
- ``isRec2020Gamut``
- ``isGammaColorParameters``
- ``isLinearColorParameters``
- ``colorLuminanceWeights``
- ``rgbToXYZMatrix``
- ``xyzToRGBMatrix``
- ``gamutMatrixToPrimaries:``
- ``gamutMatrixFromPrimaries:``

### Analyzing frames

- ``analysisState``
- ``analyzeImageTile:atTime:frameIndex:error:``
- ``analysisFrameIndexForTime:``
- ``analysisRecordAtTime:``
- ``saveAnalysisData``
- ``startForwardAnalysisAtLocation:error:``
- ``startBackwardAnalysisAtLocation:error:``

### Measuring a tile

- ``averageColorOfImageTile:red:green:blue:alpha:``
- ``averageLuminanceOfImageTile:``

### Object tracking

- ``objectTrackerTransform:forParameter:atTime:``

### The host project

- ``isProjectFinalCutPro``
- ``isProjectMotion``
- ``projectAspectRatio``
- ``projectAspectRatioWithError:``
- ``projectDocumentID``
- ``projectDocumentIDWithError:``
- ``projectMediaFolder``
- ``projectMediaFolderWithError:``

### Versioning

- ``installedVersion``
- ``checkVersion:``
- ``upgradeFromVersion:currentVersion:error:``
