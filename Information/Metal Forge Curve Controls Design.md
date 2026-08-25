# Metal Forge Curve Controls Design

Requirements and design for FxGrip inspector controls that drive Metal Forge's curve filters.
Facts about Metal Forge are marked **VERIFIED** and cite `file:line` in
`/Users/user/Code/Metal Forge/`. FxGrip additions are marked **PROPOSED**.
Final Cut Pro behavior is a parity reference from product knowledge, not from code.

---

## 1. The Curve Model (VERIFIED)

All three curve filters share one curve-to-LUT builder, `MTFBuildCurveLUT`
(`Source/Filters/Color/MTFCurveLUT.h:32`).

### 1.1 Control points

- A curve is an array of `simd_float2` control points: `x` = input, `y` = output, each in
  [0,1] (`MTFImageColorCurves.h:135`, `MTFImageHueSatCurves.h:100`, `MTFImageAlphaCurves.h:71`).
- The point count is unbounded. There is no fixed or minimum count in the API.
- Points may be unsorted; the builder copies and sorts by ascending `x`
  (`MTFCurveLUT.m:28-30`).
- Duplicate `x` values (within 1e-9) are deduplicated, first wins (`MTFCurveLUT.m:32-36`).
- NULL points or fewer than 2 points → identity ramp `y = x` (`MTFCurveLUT.m:24-27`;
  test `MetalForgeTests/MTFImageFiltersTests.m:9005-9009`).
- Points collapsing to one distinct `x` → constant LUT at that point's `y`
  (`MTFCurveLUT.m:37-42`; test `:9018-9024`).

### 1.2 Interpolation

- Monotone cubic: Fritsch-Carlson PCHIP slopes per interval, evaluated with the cubic
  Hermite basis (`MTFCurveLUT.m:44-77`).
- At a local extremum (adjacent secant slopes of opposite sign or zero) the node slope is
  zero (`MTFCurveLUT.m:54-55`). The curve does not overshoot: a monotone control set
  produces a monotone LUT within the data range (test `:9026-9034`).
- End-node slopes equal the first and last secant slopes (`MTFCurveLUT.m:51-52`).
- There are no user tangents, handles, or tension parameters. The spline is fully
  determined by the points.
- Control points are interpolated exactly, including the endpoints (test `:9035-9037`).

### 1.3 Endpoint behavior

- Outside `[firstPoint.x, lastPoint.x]` the end `y` values are held flat
  (`MTFCurveLUT.m:65-66`, documented `MTFCurveLUT.h:26`).

### 1.4 Curve → LUT

- The builder fills `n` float entries; entry `i` samples the spline at `x = i/(n-1)`
  (`MTFCurveLUT.h:21-22`, `MTFCurveLUT.m:63-64`).
- Every filter uses `n = 256` (`MTFImageColorCurves.m:16`, `MTFImageHueSatCurves.m:16`,
  `MTFImageAlphaCurves.m` same pattern).
- Per-channel LUTs are packed contiguously into one host buffer, channel-major
  (`MTFImageColorCurves.m:66-69`), uploaded lazily to a shared `MTLBuffer` and invalidated
  whenever any curve changes (`MTFImageColorCurves.m:82,98,101-109`).
- Shaders sample the LUT with linear interpolation over `x` clamped to [0,1]
  (`MTFImageColorCurves.metal:39-46`, `MTFImageHueSatCurves.metal:30-37`,
  `MTFImageAlphaCurves.metal:19-26`).

### 1.5 Circular domain (hue)

- `MTFBuildCurveLUTPeriodic` (`MTFCurveLUT.h:35-50`, `.m:87-160`) builds hue-selector
  LUTs on a circular x domain of period 1: input x folds into [0, 1), the interval from
  the last point wraps across the seam back to the first with its width extended by the
  period, and every point's Fritsch-Carlson slope uses both wrapped neighbors. There is
  no one-sided endpoint slope; the result is C¹-continuous across x = 0/1 and
  `outLUT[0] == outLUT[n-1]`.
- Degenerate inputs (NULL, fewer than 2 distinct points) yield the same identity ramp or
  constant as the clamped builder, so default curves are unchanged.
- `MTFImageHueSatCurves.m:27` and `MTFImageAlphaCurves.m:46` route their hue-selector
  channels through the periodic builder; every other channel uses the clamped builder.
- The shader additionally wraps the *output* hue with `fract` after summing the remap
  and shifts (`MTFImageHueSatCurves.metal:124`).
- The editor treats a circular-domain curve as a closed loop of points; it enforces no
  seam continuity of its own, since the builder provides it. FxGrip's CPU port carries
  both builders (§4.5).

### 1.6 Identity and neutral conventions

- Remap channels (curve maps a value to itself): identity is the diagonal ramp, built by
  passing NULL points (`MTFImageColorCurves.m:80`, `MTFImageHueSatCurves.m:74`).
- Hue-shift target channels: the shader adds `value − 0.5`, so a flat 0.5 curve is no shift
  (`MTFImageHueSatCurves.metal:99-101,113`).
- Multiplier channels in HueSat and Alpha curves: the shader applies `2 × value`, so a flat
  0.5 curve is a 1× multiplier and the curve range [0,1] maps to a [0,2] gain
  (`MTFImageHueSatCurves.metal:102-107`, `MTFImageAlphaCurves.metal:79-84`; neutral reset
  `MTFImageHueSatCurves.m:76-77`).
- The `AlphaVs*` color multipliers in `MTFImageColorCurves` are the exception: identity is
  a flat **1.0** and the shader applies the value directly, no 2× scale
  (`MTFImageColorCurves.m:76-78`, `MTFImageColorCurves.metal:87-96`).

### 1.7 The input contract

Each filter accepts curves through the same shape of API, which is the contract FxGrip's
value class must feed:

```objc
- (void)setCurvePoints:(const simd_float2 *)points
                 count:(NSUInteger)count
            forChannel:(<filter>Channel)channel;   // fewer than 2 points resets to identity
- (void)resetChannel:(<filter>Channel)channel;
- (void)resetAllChannels;
```

(`MTFImageColorCurves.h:139-154`, `MTFImageHueSatCurves.h:104-119`,
`MTFImageAlphaCurves.h:75-90`.)

---

## 2. The Curve Set per Filter (VERIFIED)

### 2.1 MTFImageColorCurves — FCP-style color curves

Nine channels (`MTFImageColorCurves.h:31-44`), packed LUT of `9 × 256` floats
(`MTFImageColorCurvesInputs.h:20-23`):

| Channel | Semantics | Identity | Gate |
|---|---|---|---|
| Luma | Remaps Rec.709 luminance; RGB scaled by `Yn/Y` (chroma-preserving gain) | diagonal | always |
| Red, Green, Blue | Per-channel remap after the luma stage | diagonal | always |
| Alpha | Remaps alpha | diagonal | `alphaCurveEnabled` |
| AlphaVsLuma | RGB multiplier indexed by input alpha | flat 1.0 | `colorVsAlphaEnabled` |
| AlphaVsRed/Green/Blue | Per-channel multiplier indexed by input alpha | flat 1.0 | `colorVsAlphaEnabled` |

- Kernel order: luma gain → R/G/B curves × bias → optional preserve-luma rescale →
  optional alpha-indexed color multipliers → optional alpha curve × alphaBias → mix
  (`MTFImageColorCurves.metal:70-101`).
- `preserveLuma` rescales the R/G/B result back to the post-luma luminance so those curves
  shift only hue and saturation (`MTFImageColorCurves.metal:81-85`).
- Scalar companions: `mix` [0,1]; per-curve output gains `lumaBias`, `redBias`,
  `greenBias`, `blueBias`, `alphaBias`, each centered at 1 and described as "the slider
  beside the FCP curve" (`MTFImageColorCurves.h:88-121`).
- Luma weights are Rec.709 (`MTFImageColorCurves.m:125`).
- `alphaCurveEnabled`, `preserveLuma`, `colorVsAlphaEnabled` are Metal function constants;
  one cached pipeline per combination (`MTFImageColorCurves.m:20,44-64`).

### 2.2 MTFImageHueSatCurves — FCP-style hue/saturation curves

Sixteen channels: the full 4×4 `selectorVsTarget` cross of {hue, sat, luma, alpha}
(`MTFImageHueSatCurves.h:29-50`), packed LUT of `16 × 256` floats
(`MTFImageHueSatCurvesInputs.h:20-23`). Naming follows FCP order: the first axis is the
strip's horizontal selector, the second is the channel it adjusts.

| Target: hue | Target: sat | Target: luma | Target: alpha |
|---|---|---|---|
| HueVsHue (remap) | HueVsSat (×) | HueVsLuma (×) | HueVsAlpha (×) |
| SatVsHue (shift) | SatVsSat (×) | SatVsLuma (×) | SatVsAlpha (×) |
| LumaVsHue (shift) | LumaVsSat (×) | LumaVsLuma (remap) | LumaVsAlpha (×) |
| AlphaVsHue (shift) | AlphaVsSat (×) | AlphaVsLuma (×) | AlphaVsAlpha (remap) |

- Self curves remap on the diagonal; hue-target curves are shifts (0.5 = none); all others
  are 2× multipliers (0.5 = 1×) (`MTFImageHueSatCurves.h:21-27`).
- The nine hue/sat/luma curves always apply; the seven alpha-involving curves (row 4 and
  column 4) gate on `hueSatVsAlphaEnabled`, a function constant
  (`MTFImageHueSatCurves.h:77-87`, `.metal:110-120`).
- Color space is HSL ("luma" is HSL lightness) so the round-trip is exact and identity
  curves pass through (`MTFImageHueSatCurves.h:61-63`, `.metal:39-71`).
- Combination rules per pixel: output hue = HueVsHue remap + the three shifts, then
  `fract`; sat = S × product of the four sat multipliers, clamped [0,1]; luma =
  LumaVsLuma remap × the three luma multipliers, clamped [0,1]; alpha = AlphaVsAlpha remap
  × the three alpha multipliers, clamped [0,1] (`.metal:97-124`).
- Scalar companion: `mix` [0,1] (`MTFImageHueSatCurves.h:71-74`).

### 2.3 MTFImageAlphaCurves — alpha driven by image components

Seven channels (`MTFImageAlphaCurves.h:29-37`), packed LUT of `7 × 256` floats
(`MTFImageAlphaCurvesInputs.h:20-23`):

| Channel | Semantics | Identity |
|---|---|---|
| AlphaVsAlpha | Remap of input alpha | diagonal |
| AlphaVsLuma | Alpha × indexed by Rec.709 luma | flat 0.5 |
| AlphaVsRed/Green/Blue | Alpha × indexed by that channel | flat 0.5 |
| AlphaVsHue | Alpha × indexed by HSL hue | flat 0.5 |
| AlphaVsSat | Alpha × indexed by HSL saturation | flat 0.5 |

- Output alpha = remap × product of the six 2× multipliers, clamped [0,1]; RGB is
  untouched (`MTFImageAlphaCurves.metal:78-87`).
- This filter is the curve-driven "alpha from channel" tool. It is the FxGrip target for
  the user's "alpha vs hue/luma/saturation" requirement, with the reverse direction
  (color driven by alpha) covered by `colorVsAlphaEnabled` in ColorCurves and the alpha
  row of HueSatCurves.

### 2.4 Keying folder census

`Source/Filters/Keying/` contains no curve consumers. All are parametric:

- `MTFImageChromaKey` — key-color distance (YCbCr / color-difference / RGB / HSV metrics)
  mapped through `smoothstep(tolerance, tolerance + softness, d)` (`MTFImageChromaKey.h:29-46`).
- `MTFImageLumaKey` — luma low/high thresholds with softness (`MTFImageLumaKey.h:50-101`).
- `MTFImageDifferenceKey` — distance vs a clean plate, threshold + softness.
- `MTFImageDespill` — spill suppression, no matte curves.
- `MTFImageMatte` — matte post-processing: shrink/grow, feather, black/white point, gamma,
  clips (`MTFImageMatte.h:47-99`).

A curve control that refines a keyer's matte therefore chains `MTFImageAlphaCurves` (or
the alpha channels of the other two curve filters) after the keyer.

### 2.5 HDR and clamping

- LUT sampling clamps the index coordinate to [0,1]; HDR values above 1.0 read the last
  LUT entry by design of a [0,1]-domain curve (`HDR-CLAMP-CENSUS-2026-07-07.md:35,37`).
- ColorCurves writes its graded RGB unclamped; only `mix` is clamped
  (`HDR-CLAMP-CENSUS-2026-07-07.md:36`). Curve output above 1.0 requires bias > 1, since
  control-point `y` is documented [0,1].
- HueSatCurves clamps sat and lightness into [0,1] before HSL→RGB; the HSL model has no
  headroom (`HDR-CLAMP-CENSUS-2026-07-07.md:38-39`).
- All alpha outputs clamp to [0,1] (matte semantics) (`MTFImageAlphaCurves.metal:85`,
  `MTFImageHueSatCurves.metal:119`).

---

## 3. Final Cut Pro Control Parity

Parity targets per family. FCP behavior here is a product-knowledge reference.

### 3.1 MTFImageColorCurves ↔ FCP "Color Curves"

- Four square curve panes: Luma, Red, Green, Blue. Metal Forge adds Alpha and the four
  AlphaVs* multipliers; the same pane serves them.
- Pane interactions: click on the curve adds a point; drag moves a point; dragging a point
  off the pane (or a delete key) removes it; endpoints are draggable but not removable;
  double-click or a reset button restores the diagonal.
- Automatic tangents only. FCP color curves have no per-point handles, which matches PCHIP
  exactly: the user places points, the spline shapes itself, no overshoot.
- Eyedropper per pane: sampling the image adds a point at the sampled level's `x` on that
  channel.
- Backgrounds: neutral grid; the R/G/B panes tint their curve stroke. A histogram backdrop
  is optional polish.
- The per-curve slider beside each FCP pane maps to `lumaBias`/`redBias`/`greenBias`/
  `blueBias`/`alphaBias` (`MTFImageColorCurves.h:95`). "Preserve Luma" maps to
  `preserveLuma`; the FCP "Mix" slider (0-100) maps to `mix` as value/100
  (`MTFImageColorCurves.h:54-57`).

### 3.2 MTFImageHueSatCurves ↔ FCP "Hue/Saturation Curves"

- FCP ships six wide strips: HUE vs HUE, HUE vs SAT, HUE vs LUMA, LUMA vs SAT, SAT vs SAT,
  and COLOR vs SAT (a picked-color window). Metal Forge's 16-channel cross is a superset;
  the six FCP strips correspond to HueVsHue, HueVsSat, HueVsLuma, LumaVsSat, SatVsSat,
  and a windowed HueVsSat respectively. The alpha row and column extend past FCP.
- Strip form factor: wide and short, with the selector along x. Hue-selector strips render
  a hue-spectrum background; luma-selector strips render a black→white ramp;
  sat-selector strips render a gray→saturated ramp; alpha-selector strips render a
  transparent→opaque checker ramp.
- Hue-selector strips are circular: dragging a point past either edge wraps, and the curve
  must render seam-continuous (see §1.5).
- Shift strips (target: hue) center their neutral line at 0.5 and label the axis in
  degrees; multiplier strips center at 0.5 and label 0×-2×; remap strips draw the diagonal.
- Eyedropper on a strip adds three points: one at the sampled selector value moved by the
  user's subsequent drag, flanked by two neutral anchor points, the FCP gesture for
  isolating a band.
- COLOR vs SAT is a UI preset over HueVsSat: pick a hue, place a window of points around
  it (Open Question 4).

### 3.3 MTFImageAlphaCurves ↔ keyer graphs

- The FCP Keyer's "Color Selection" hue/sat graphs and "Luma" graph are the closest
  controls: a curve over a channel strip whose output is matte density.
- The same strip editor as §3.2 serves all seven channels: AlphaVsAlpha as a square remap
  pane, the six multipliers as strips with the matching backgrounds (luma ramp, R/G/B
  ramps, hue spectrum, sat ramp).
- AlphaVsHue is circular and needs the same seam handling as the hue-selector strips.

---

## 4. The FxGrip Design (PROPOSED)

FxGrip does not link MetalForge.framework. FxGrip stores and edits curves in a
framework-neutral value class; the plugin target converts to the §1.7 contract.

### 4.1 Value classes

**`FxGripCurveData`** — one curve. `NSObject <NSSecureCoding, NSCopying>`, immutable
snapshot semantics (a mutable variant is unnecessary; edits replace the value).

```objc
typedef NS_ENUM(NSInteger, FxGripCurveDomain) {
    FxGripCurveDomainLinear   = 0,   // clamped x, end values held
    FxGripCurveDomainCircular = 1,   // hue selector: seam-continuous, wrap dragging
};

typedef NS_ENUM(NSInteger, FxGripCurveRole) {
    FxGripCurveRoleRemap         = 0, // identity = diagonal
    FxGripCurveRoleShift         = 1, // neutral = flat 0.5 (target-hue shift)
    FxGripCurveRoleMultiplierHalf = 2, // neutral = flat 0.5 (shader applies 2x)
    FxGripCurveRoleMultiplierOne  = 3, // neutral = flat 1.0 (ColorCurves AlphaVs*)
};

@interface FxGripCurveData : NSObject <NSSecureCoding, NSCopying>
@property (readonly) FxGripCurveDomain domain;
@property (readonly) FxGripCurveRole   role;
@property (readonly) NSUInteger        pointCount;
- (CGPoint)pointAtIndex:(NSUInteger)index;              // sorted by x, each in [0,1]
+ (instancetype)identityCurveWithRole:(FxGripCurveRole)role
                               domain:(FxGripCurveDomain)domain;
+ (instancetype)curveWithPoints:(const CGPoint *)points count:(NSUInteger)count
                           role:(FxGripCurveRole)role domain:(FxGripCurveDomain)domain;
- (BOOL)isIdentity;
/*! The Metal Forge conversion: fills `buffer` with up to `capacity` simd-compatible
    (x,y) float pairs, returns the count written. The caller passes the result straight
    to -[MTF… setCurvePoints:count:forChannel:]. */
- (NSUInteger)copyCurvePointsFloat2:(simd_float2 *)buffer capacity:(NSUInteger)capacity;
/*! CPU evaluation identical to MTFBuildCurveLUT (PCHIP), for editor rendering and
    keyframe blending. */
- (void)buildLUT:(float *)outLUT count:(NSUInteger)n;
@end
```

- Points serialize as an `NSArray<NSNumber *>` of interleaved doubles under one key, so
  secure coding needs only `NSArray`/`NSNumber` in the allow-list.
- `copyCurvePointsFloat2:capacity:` is the named conversion to the Metal Forge input
  contract. FxGrip keeps `simd_float2` out of its public header by typing the buffer as
  `float (*)[2]` if simd inclusion is undesirable; the layout is identical.
- FxGrip ships a CPU copy of the PCHIP builder (`FxGripBuildCurveLUT`, mirroring
  `MTFCurveLUT.m:22-84`) so the editor preview and keyframe blending match the render
  exactly without linking MetalForge. The MetalForge test
  `testBuildCurveLUTClosedForm` (`MTFImageFiltersTests.m:9001-9040`) is the porting
  oracle; FxGripTests mirrors it.

**`FxGripCurveSetData`** — a filter's full curve set. Subclass of
`FxGripInterpolatingDictionary` keyed by mapping name (`NSString`), value
`FxGripCurveData`:

- Keys are the Metal Forge channel names in FCP order: `@"luma"`, `@"red"`, …,
  `@"hueVsHue"`, `@"satVsHue"`, …, `@"alphaVsAlpha"`. One registry per filter family
  declares key → (channel enum value, role, domain).
- An absent key means the neutral curve. Only edited curves are stored, keeping documents
  small and interpolation cheap.
- Scalar companions (`mix`, biases, `preserveLuma`) are **not** stored here; they map to
  native FxPlug float/bool parameters so the host keyframes and publishes them normally
  (Open Question 3 records the alternative).
- `+classesForParameter` extends the allow-list with `FxGripCurveData`
  (`FxGrip/CustomParameter/FxGripDictionary.h:59-61`).

### 4.2 The editor view family

One reusable editor, not one view per mapping.

**`FxGripCurveEditorView : NSView <FxGripCustomViewDataDelegate>`**

- Configured by a `FxGripCurveEditorStyle`: domain (linear/circular), role (fixes the
  neutral line and the vertical axis labels), aspect (square pane vs strip), and a
  background renderer (`FxGripCurveBackgroundRenderer` block or enum: none/grid, hue
  spectrum, luma ramp, sat ramp, channel ramp, alpha checker).
- Interactions: click-on-curve adds a point; drag moves; drag-off or Delete removes;
  endpoints in linear domain are pinned in `x`; double-click resets the curve; a context
  menu offers Reset Curve / Reset All.
- Circular domain: point dragging wraps in `x`, and rendering evaluates the periodic
  builder (§1.5), so the preview is seam-continuous by construction. The view commits
  the user's points unmodified; the builder owns the seam.
- Rendering evaluates the curve with `FxGripBuildCurveLUT` at view width resolution, so
  the drawn curve is exactly what the filter applies.
- `updateFromCustomData:` (`FxGrip/CustomParameter/FxGripCustomViewDataDelegate.h:19`)
  receives the current `FxGripCurveSetData`; the view re-reads its mapping's curve and
  redraws. The value's weak `parameterView`/`parameterEffect` back-references follow
  `FxGripCustomViewData` (`FxGrip/CustomParameter/FxGripCustomViewData.h:20-26`).

**`FxGripCurveSetEditorView`** — the inspector composite: a strip/pane per mapping with
disclosure per selector group, mirroring FCP's stacked strips. It multiplexes one
`FxGripCurveSetData` value across its child editors, so one custom parameter carries the
whole curve set and the host stores one keyframeable value per filter.
`createViewForParameterID:` (`FxGrip/GuruFxTileableEffect.m:315`) returns this composite
for the curve-set parameter ID.

### 4.3 Value flow

1. The user drags a point. The child editor produces a new `FxGripCurveData`; the
   composite produces a new `FxGripCurveSetData`.
2. The view opens `FxGripOOBParameterAccess` (`FxGrip/CustomParameter/FxGripOOBParameterAccess.h:25-45`)
   and writes the value through the parameter-setting wrapper
   (`setCustomParameterValue`/`setParameterValue:toParameter:`), inside
   `startAction`/`endAction`. Continuous drags coalesce: write on significant change and
   on mouse-up, so the host undo stack records the gesture, not every mouse move.
3. The host stores the custom value (keyframed when the parameter is animating).
4. At render, the plugin reads the custom value from `pluginState`, obtains
   `FxGripCurveSetData`, and for each stored key calls
   `copyCurvePointsFloat2:capacity:` and feeds
   `-[MTFImage… setCurvePoints:count:forChannel:]`; absent keys call `resetChannel:`.
   The adapter that maps key → channel enum lives in the plugin target (or in an optional
   `FxGripMetalForgeAdapter` category compiled only where MetalForge is linked).
5. The adapter caches the last-applied `FxGripCurveSetData` (pointer or hash compare) and
   skips the `setCurvePoints` pass when unchanged, preserving the filters' lazy LUT
   rebuild (`MTFImageColorCurves.m:101-109`).

### 4.4 Keyframed curve interpolation

`FxGripInterpolatingDictionary` interpolates dictionary values recursively: numbers lerp,
arrays interpolate elementwise by index, and unknown classes fall through to
`customInterpolateValue:…`, defaulting to a copy of the left value
(`FxGrip/CustomParameter/FxGripInterpolatingDictionary.m:57-166,170-173`). Elementwise
array interpolation silently drops elements when counts differ or classes mismatch
(`:59-61,81-89`), so raw point arrays are unsafe under varying point counts.

`FxGripCurveSetData` therefore overrides `customInterpolateValue:rightValue:path:withWeight:`
for `FxGripCurveData` pairs:

- Equal point counts → pairwise lerp of `(x, y)`. Points are sorted, so index
  correspondence is the FCP-style behavior: points travel between keyframes.
- Unequal point counts → curve-space blend: evaluate both curves with
  `FxGripBuildCurveLUT` on a fixed grid (33 samples), lerp the `y` values, and return a
  33-point curve. The blended frame renders correctly; the editor shows the dense curve
  read-only between such keyframes.
- Mismatched `role`/`domain` → return the left curve unchanged (the mapping's role never
  changes at runtime; this is a guard).

Pairwise lerp of control points is not the mathematical blend of the two splines; it is
the convention host curve editors use and it keeps points draggable across keyframes. The
curve-space fallback guarantees a defined result for every weight.

### 4.5 Parameter registration

- One custom parameter (kFxParameterFlag_CUSTOM_UI) per filter curve set, default value an
  empty `FxGripCurveSetData` (all neutral).
- Native float parameters for `mix` and the five biases; native toggles for
  `preserveLuma`, `alphaCurveEnabled`, `colorVsAlphaEnabled`, `hueSatVsAlphaEnabled`.
  Toggling the enables re-specializes the Metal pipeline (function constants,
  `MTFImageColorCurves.m:44-64`); this is a per-combination one-time cost.

---

## 5. Size and Performance

- The document stores control points only. A typical curve is 3-8 points (~50-130 bytes
  encoded); a fully edited 16-curve HueSat set stays under ~2 KB. LUTs are derived data
  and are never serialized.
- LUT memory per filter instance: ColorCurves 9 × 256 × 4 = 9 KB; HueSatCurves 16 × 256
  × 4 = 16 KB; AlphaCurves 7 × 256 × 4 = 7 KB. Rebuild cost is a few thousand double ops
  per changed curve; upload is one small `newBufferWithBytes:` re-created only when a
  curve changed (`MTFImageColorCurves.m:101-109`).
- 256-entry LUTs with linear shader sampling match the CPU oracle within 3e-4
  (`MTFImageFiltersTests.m:9092`); the editor uses the same builder so preview equals
  render.
- Static curves during playback: the adapter's value compare (§4.3 step 5) makes the
  per-frame cost zero. Keyframe-animated curves rebuild the changed channels each frame;
  worst case (all 16 HueSat channels animating) remains microseconds of CPU plus a 16 KB
  upload.
- The editor recomputes its preview polyline on point drag at view resolution; no GPU work
  occurs until the value is committed and a render is requested.

---

## 6. Open Questions

1. **Hue seam — RESOLVED (2026-08-06).** Metal Forge grew `MTFBuildCurveLUTPeriodic`
   (§1.5): a periodic Fritsch-Carlson mode whose closed-loop slopes make the seam
   C¹-continuous, consumed by the hue-selector channels of both curve filters. The
   editor treats circular-domain points as a closed loop and enforces nothing; the CPU
   port implements both builders.
2. **Keyframe point-count policy.** Enforce a stable count per curve while a parameter is
   animating (reject add/delete, FCP-style), or allow it and accept the §4.4 curve-space
   fallback between mismatched keyframes?
3. **Scalar placement.** §4.1 puts `mix`, biases, and enables in native parameters.
   The alternative stores them inside `FxGripCurveSetData` (single value, custom UI
   controls them). Native parameters win host keyframing and publishing; confirm.
4. **COLOR vs SAT strip.** Implement as a UI preset that writes HueVsSat points, or store
   it as its own mapping with pick-color + falloff metadata rendered into HueVsSat at
   conversion time? The preset is simpler; the stored form round-trips the picked color.
5. **Eyedropper source.** Adding a point from the image requires sampling the frame from
   the custom view. Candidate path: cache a thumbnail per render in `FxGripFrameData`
   (`FxGrip/CustomParameter/FxGripFrameData.h`) and sample it out-of-band. Confirm the
   caching point and color-space handling.
6. **HDR domain.** Curves are defined on [0,1]; input above 1.0 holds the last LUT entry
   (§2.5). Is an extended-domain mode (e.g. x in [0,2] for HDR luma) required for the
   first release, and if so it needs an upstream domain parameter in the filters as well.
7. **Adapter placement.** The key → channel adapter compiles in the plugin target versus
   an optional FxGrip category behind a MetalForge link check. The plugin target keeps
   FxGrip dependency-free; confirm.
