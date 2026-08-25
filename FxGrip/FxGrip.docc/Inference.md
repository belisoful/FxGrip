# Machine-Learning Effects

Render an effect's image through a machine-learning model, with InferKit as the engine.

## Overview

FxGrip is the FxPlug harness for a machine-learning effect: it owns the render-thread
orchestration, the per-frame result cache, and the seam a model runs behind. The engine that
runs the model is [InferKit](https://github.com/belisoful/InferKit), a separate cross-platform
inference toolkit a plugin links directly. FxGrip does not link InferKit; it detects it at
runtime.

An effect subclasses ``FxGripMLImageEffect``. The template turns the source tile into the
backend's image input, runs the backend off the render thread, and writes the image output to
the destination tile. With no engine present, the default ``FxGripPassthroughBackend`` renders
the source unchanged, so builds, tests, and timelines stay green without weights.

A plugin that links InferKit hands the effect an InferKit backend (a Core ML runner, a remote
client, or its own `NFKInferenceBackend` adopter):

```objc
NFKCoreMLBackend *engine = [NFKCoreMLBackend backendWithModelURL:modelURL];
[effect useInferKitBackend:engine];
```

``FxGripInferenceBridge`` performs the runtime detection and the wrapping:
`isInferKitAvailable` checks for the InferKit classes by name, and
`backendBridgingInferKitBackend:` adapts any InferKit backend to the effect's
``FxGripInferenceBackend`` seam. When InferKit is absent, the bridge returns nil and the
effect keeps its passthrough.

### The seam

``FxGripInferenceBackend`` is the deliberately small synchronous contract the harness drives:
readiness, an identifier, and one run method over an ``FxGripInferenceRequest`` (named inputs
plus scalar parameters) returning an ``FxGripInferenceResult`` (named outputs). The
dictionaries pass through the bridge verbatim, so InferKit's input, parameter, and output key
vocabulary flows unchanged.

InferKit's larger surface — async jobs, video and audio assets, typed results, tokenizers, the
Hugging Face hub — belongs to the plugin's direct use of InferKit. A long-running generation
fits FxPlug's analysis pass or a status and progress parameter rather than a per-frame render.

### Whole-clip generation

``FxGripMLVideoEffect`` is the template for a model that produces a movie rather than a frame.
beginGenerationAtTime: runs the backend once on a background queue; the state moves through
generating to ready or failed, and generationStateDidChange lets a subclass mirror the state
into a status or progress parameter or drive the run from the analysis pass. While the clip is
not ready the effect renders its source, so the timeline stays responsive; once ready, each
frame samples the generated clip through
renderFrameFromGeneratedClip:toDestinationTile:atTime:error:. The clip output is read as an
NSURL, a path string, or any object with a fileURL, which admits an InferKit video asset.

``FxGripMLImageGenerator`` and ``FxGripMLVideoGenerator`` are the generator counterparts: no
source clip, the generator tile geometry, and a placeholder seam in place of the
source-unchanged fallback.

### A worked example

A text-to-video effect: a prompt, a Generate push-button, and a status and progress control
that mirror the generation lifecycle. The class compiles as `FxMLVideoExampleEffect` in the
test suite, which keeps this listing honest.

```objc
enum : UInt32 {
    kExamplePromptID = 1, kExampleGenerateID = 2, kExampleStatusID = 3, kExampleProgressID = 4,
};

@implementation FxMLVideoExampleEffect

// Declared alongside the effect's other parameters: a string prompt, a push button, and the
// status and progress custom controls with idle defaults.

/*! The prompt parameter feeds the generation request. */
- (NSDictionary<NSString *, id> *)generationInputsAtTime:(CMTime)time
{
    NSString *prompt = nil;
    [self.apiManager.paramGetAPIv6 getStringParameterValue:&prompt fromParameter:kExamplePromptID];
    return prompt.length > 0 ? @{ @"prompt": prompt } : @{};
}

/*! The Generate button starts the run; every other click keeps the base behavior. */
- (BOOL)parameterClicked:(FxParameterId)parameterID
{
    if (parameterID == kExampleGenerateID) {
        [self beginGenerationAtTime:[FxGripOOBParameterAccess access:self].currentTime];
        return YES;
    }
    return [super parameterClicked:parameterID];
}

/*! Mirrors the lifecycle into the status and progress controls. The hook fires off the host's
    calls, so the writes run inside an out-of-band access context. */
- (void)generationStateDidChange
{
    NSInteger dot = BEDotStateOff;
    NSString *label = @"Idle";
    double fraction = 0.0;
    switch (self.generationState) {
        case FxGripMLVideoStateGenerating:
            dot = BEDotStateActive;
            label = @"Generating…";
            fraction = self.generationProgress;   // negative shows the indeterminate bar
            break;
        case FxGripMLVideoStateReady:
            dot = BEDotStateOk;
            label = @"Clip ready";
            fraction = 1.0;
            break;
        case FxGripMLVideoStateFailed:
            dot = BEDotStateError;
            label = self.generationError.localizedDescription ?: @"Failed";
            break;
        case FxGripMLVideoStateIdle:
            break;
    }

    FxGripOOBParameterAccess *__attribute__((unused)) access = [FxGripOOBParameterAccess access:self];
    CMTime time = access.currentTime;
    [self.apiManager.paramSetAPIv5 setCustomParameterValue:
         [FxGripDictionary dictionaryWithDictionary:@{ kCustomAPI_IntKey:    @(dot),
                                                       kCustomAPI_StringKey: label }]
                                               toParameter:kExampleStatusID
                                                    atTime:time];
    [self.apiManager.paramSetAPIv5 setCustomParameterValue:
         [FxGripDictionary dictionaryWithDictionary:@{ kCustomAPI_IntKey:    @(dot),
                                                       kCustomAPI_StringKey: label,
                                                       kCustomAPI_FloatKey:  @(fraction) }]
                                               toParameter:kExampleProgressID
                                                    atTime:time];
}

@end
```

### Caching

Inference is too slow to run per frame, and a model's output is a pure function of the frame
and parameters. ``FxGripMLImageEffect`` caches each output by frame through the
``FxGripMLCache`` extension, which stores results in the project media folder so an expensive
result survives a reopen. Switching the backend or changing a parameter clears the cache.

## Topics

### Effect templates

- ``FxGripMLImageEffect``
- ``FxGripMLVideoEffect``
- ``FxGripMLImageGenerator``
- ``FxGripMLVideoGenerator``
- ``FxGripMLCache``

### The seam

- ``FxGripInferenceBackend``
- ``FxGripInferenceRequest``
- ``FxGripInferenceResult``
- ``FxGripPassthroughBackend``

### InferKit

- ``FxGripInferenceBridge``
