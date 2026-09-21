# Timing and Timecode

Report frame durations and frame counts through the host, and format SMPTE timecode with
drop-frame support.

## Overview

FxGrip works with time at three levels. ``FxGripTimingAPI_v4`` wraps the host's
`FxTimingAPI_v4` protocol and forwards each query, guarding every out-parameter against a
NULL pointer. The `FxGripTileableEffect` `Timing` category reads the timing API and reports
frame durations, retiming speed, the effect and input start and duration in time and
frames, and formats timecode. ``FxGripTimecode`` formats a `CMTime` as SMPTE timecode with
no host dependency, for a footage popup or an on-screen readout.

## The host timing wrapper

``FxGripTimingAPI_v4`` mirrors the FxPlug 4 v4 timing protocol. It forwards the frame,
sample, effect, input, image-parameter, and timeline queries to the host API, and each
out-parameter query leaves the caller's storage untouched when passed a NULL pointer. The
wrapper also reports the input field order and the timeline frame-rate numerator and
denominator for the effect.

## The effect Timing category

The `Timing` category on `FxGripTileableEffect` reads the host timing API and returns
timing in the units an effect works in. Frame counts come from multiplying a time by the
timeline frame rate and flooring to the nearest.

### Durations and rates

- `frameDuration` → the duration of one frame after retiming, in timeline time.
- `retimingSpeed` → the clip's retiming speed; 1.0 is 100%, 0.5 is slowed to 50%.
- `sampleDuration` → the sample duration, equal to the frame duration for progressive
  clips and half for interlaced.
- `isInterlacedClip` → YES when the sample duration differs from the frame duration.
- `timelineFrameDuration`, `timelineFrameRate`, `timelineFps`,
  `timelineFrameDurationFloat`, `timelineFpsNumerator`, and `timelineFpsDenominator`
  report the timeline frame rate.

### Effect and input extents

The effect's extent is reported as `effectStartTime`, `effectStartFrame`,
`effectStartTimeInTimeline`, `effectDurationTime`, and `effectDurationFrames`. The filter
input's extent is reported by the matching `inputStartTime`, `inputStartFrame`,
`inputStartTimeInTimeline`, `inputDurationTime`, and `inputDurationFrames`.
`effectInPointOfTimeLine` and `effectOutPointOfTimeLine` report the timeline in and out
points.

### Time and frame conversion

`frameForTime:` returns the timeline frame index for a time. `timelineTime:fromInputTime:`
and `inputTime:fromTimelineTime:` convert between input and timeline time through the host
API. `timeByOffsettingTime:byFrames:` moves a time by whole frames at the effect's frame
duration, and a negative count moves earlier. The free function
``FxGripTimeByOffsettingFrames`` performs the same offset arithmetic against an explicit
frame duration.

### Source-tile requests

`sourceTileRequestAtTime:frameOffset:` builds a request for the effect's source clip at a
time offset by whole frames, for a temporal effect that samples neighboring frames;
leading filters are excluded. `sourceTileRequestAtTime:` is the same request with no
offset.

```objc
// Inside an FxGripTileableEffect subclass, sampling the previous frame:
FxImageTileRequest *previous =
    [self sourceTileRequestAtTime:renderTime frameOffset:-1];
```

### Drop-frame and timecode strings

The drop-frame reporters read `FxTimingAPI_v5`, so they return NO on a host that vends no
v5 timing API. `isTimelineDropFrame` reports whether the project displays timecode in
drop-frame format. `isInputDropFrame` reports whether the input clip requires drop-frame
timecode; Motion always reports NO, and a Motion template running in Final Cut Pro reports
the clip setting. `isDropFrameOfImageParameter:` reports the same for an image-well
parameter's clip. `timelineTimecodeStringForTime:` formats an input time as timeline
timecode at the timeline frame rate in the project's drop-frame mode, and returns
`--:--:--:--` when the host vends no timing API. `inputTimecodeStringForTime:` formats it
against the input clip's frame duration and drop-frame mode.

## Timecode formatting

``FxGripTimecode`` formats a `CMTime` as SMPTE timecode using exact integer arithmetic on
the CMTime fields, with every method a pure class method. A time within half a tick of its
own timescale below a frame boundary counts as that frame, so a host that quantizes times
to a coarse timescale still indexes correctly.

### Frame rates

``FxGripFrameRate`` lists the twelve standard rates in the order Apple's
FxTimeCodeGenerator example uses, so a popup built from `+frameRateMenuEntries` stores the
enum value directly. `+frameDurationForRate:` returns a rate's frame duration as an exact
`CMTime`, using a 1001 numerator for the fractional rates (29.97 → 1001/30000) and
defaulting to 30 fps for an unknown rate. `+rateSupportsDropFrame:` returns YES for 29.97,
59.94, and 119.88, and `+frameDurationSupportsDropFrame:` answers the same question for a
frame duration.

### Components and strings

`+frameIndexForTime:frameDuration:` returns the zero-based frame containing a time.
`+componentsForTime:frameDuration:dropFrame:` splits a time into an
``FxGripTimecodeComponents`` value: hours, minutes, seconds, frames, the nominal integer
rate, the effective drop-frame mode, and a `valid` flag. Drop-frame counting skips two
frame numbers per minute at 29.97, four at 59.94, and eight at 119.88, except in minutes
divisible by ten; other rates ignore the flag. `+stringForComponents:` formats the
components as `hh:mm:ss:ff`, uses a semicolon before the frames field in drop-frame mode
(`hh:mm:ss;ff`), uses three frame digits at 100 fps and above, and formats invalid
components as `--:--:--:--`. `+stringForTime:frameDuration:dropFrame:` runs the split and
format in one call.

```objc
CMTime frameDuration = [FxGripTimecode frameDurationForRate:FxGripFrameRate_29_97];
NSString *code = [FxGripTimecode stringForTime:time
                                 frameDuration:frameDuration
                                     dropFrame:YES];   // e.g. 00:01:00;02
```

## Topics

### Host wrapper

- ``FxGripTimingAPI_v4``

### The effect category

- ``FxGripTileableEffect-class``

### Timecode

- ``FxGripTimecode``
- ``FxGripFrameRate``
- ``FxGripTimecodeComponents``
- ``FxGripTimeByOffsettingFrames``

### Related

- <doc:TilingAndGeometry>
- <doc:Adoption>

### Watched timing properties

- ``kWatchFPSChange``
- ``kWatchInputStartTime``
- ``kWatchInputDuration``
