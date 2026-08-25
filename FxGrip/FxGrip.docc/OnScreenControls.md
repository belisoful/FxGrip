# On-Screen Controls

Build a Final Cut Pro / Motion on-screen control from composable parts bound to
the effect's parameters.

## Overview

An FxPlug on-screen control (OSC) is its own plugin: a class implementing
`FxOnScreenControl_v4`, registered beside the effect it serves.
``FxOnScreenControlBase`` implements the whole protocol — the Metal drawing
scaffold, coordinate conversion, hit-test dispatch, and drag routing — so a
control subclass only declares which parts it is made of.

A part (``FxGripOSCPart``) binds one interactive shape to parameter IDs: it
draws itself, answers hit tests, and writes the parameters when dragged. The
base hit-tests parts topmost-first (the last part added wins an overlapping
hit), draws them in order, and routes a drag to the active part. Parameter
writes go through the wrapped setting APIs without `startAction:`/`endAction:`
bracketing; the host expects an OSC to change parameters directly.

## The control class

A complete OSC for an effect with a rectangle (two point parameters) and a
movable, resizable, rotatable circle:

```objc
@interface MyShapeOSC : FxOnScreenControlBase
@end

@implementation MyShapeOSC

- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
    self = [super initWithAPIManager:apiManager];
    if (self != nil) {
        [self addParts:[FxGripOSCRectPart rectPartsWithOptions:FxGripOSCShapeOptionBody
                                                               | FxGripOSCShapeOptionCornerHandles
                                                   firstPartID:1
                                          lowerLeftParameterID:kLowerLeftID
                                         upperRightParameterID:kUpperRightID
                                              angleParameterID:0]];
        [self addParts:[FxGripOSCCirclePart circlePartsWithOptions:FxGripOSCShapeOptionsAll
                                                       firstPartID:10
                                                 centerParameterID:kCircleCenterID
                                                 radiusParameterID:kCircleRadiusID
                                                  angleParameterID:kCircleAngleID]];
    }
    return self;
}

@end
```

The flag constructors compose a shape's parts and number them sequentially from
`firstPartID`, counting only the parts the flags include. Each family documents
its inclusion order; read `partID` off the returned parts when handles are
optional. Alternatives at every altitude remain available: the explicit-ID
composites (`circlePartsWithBodyID:radiusHandleID:...`), single parts
(`addPart:`), or overriding the base hooks
(`hitTestObjectPoint:canvasPoint:atTime:`,
`dragActivePart:toObjectPoint:objectDelta:modifiers:atTime:`,
`drawOSC:commandEncoder:canvasSize:activePart:atTime:`) for behavior no part
provides.

## Registration

The OSC registers as a second plugin entry whose `protocolNames` is
`FxOnScreenControl`, tied to the effect by UUID. With FxGrip's registrar the
effect's entry declares its OSC under the `"osc"` key and the registrar fills
the OSC entry's `supportedPlugins`:

```plist
<key>ProPlugPlugInList</key>
<array>
    <dict>
        <key>className</key>   <string>MyEffect</string>
        <key>uuid</key>        <string>D401D6C0-A0D9-4FD8-BD82-B4C7DC410722</string>
        <key>group</key>       <string>29CB3EBF-60C2-4634-B29C-11C6FE8C9E9E</string>
        <key>protocolNames</key>
        <array><string>FxFilter</string></array>
        <key>osc</key>
        <array><string>7A0E42F1-58D3-4E19-9F1B-3C60A51E2C44</string></array>
    </dict>
    <dict>
        <key>className</key>   <string>MyShapeOSC</string>
        <key>uuid</key>        <string>7A0E42F1-58D3-4E19-9F1B-3C60A51E2C44</string>
        <key>group</key>       <string>29CB3EBF-60C2-4634-B29C-11C6FE8C9E9E</string>
        <key>protocolNames</key>
        <array><string>FxOnScreenControl</string></array>
    </dict>
</array>
```

The effect itself needs nothing beyond its parameters: the host instantiates
the OSC class with its own API manager whenever the effect is selected. The
parameters the parts bind to are the effect's ordinary point, float, and angle
parameters — position parameters in normalized object space, pixel sizes as
float sliders, angles in radians (the FxPlug angle-slider convention).

## Conventions the parts share

- **Position parameters** are object-space points (`getXValue:YValue:`);
  normalized 0-1 over the input image.
- **Sizes** (circle radius, box width and height) are input-image pixels.
- **Angles** default to radians; set `radiansPerUnit` to `M_PI / 180.0` for a
  parameter stored in degrees.
- **Handle radii** are canvas pixels, so grab targets keep their size at every
  zoom.
- **Rotation** is rigid in the input-pixel frame; rotated shapes keep their
  angles on non-square images.
- Setting `angleParameterID` to `0` (the default) leaves a shape axis-aligned,
  and flag constructors omit rotation handles.

## Topics

### Base class

- ``FxOnScreenControlBase``

### Parts

- ``FxGripOSCPart``
- ``FxGripOSCPointHandlePart``
- ``FxGripOSCRectPart``
- ``FxGripOSCRectCornerPart``
- ``FxGripOSCRectRotationHandlePart``
- ``FxGripOSCBoxPart``
- ``FxGripOSCBoxCornerPart``
- ``FxGripOSCCirclePart``
- ``FxGripOSCCircleRadiusHandlePart``
- ``FxGripOSCRotationHandlePart``
- ``FxGripOSCLinePart``
- ``FxGripOSCAngleDialPart``
- ``FxGripOSCPolylinePart``
- ``FxGripOSCBezierVertexHandlePart``
- ``FxGripOSCTangentHandlePart``

### Display and readout parts

- ``FxGripOSCCurvePart``
- ``FxGripOSCHUDPart``

### Editable polygon

- ``FxGripOSCEditablePolygonPart``
- ``FxGripPointListData``
