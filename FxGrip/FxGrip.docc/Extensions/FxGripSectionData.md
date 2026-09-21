# ``FxGrip/FxGripSectionData``

The mutable-dictionary custom value of a section parameter.

## Overview

A section carries many typed values in one custom parameter. This value holds them in a dictionary
and serves them through the same accessor shapes the host's retrieval and setting APIs use, so a
caller reads and writes a section the way it reads and writes any parameter.

### Locking

``isLocked`` fixes the section's shape. A locked value still accepts a write to a key it already
holds, and refuses a write that would introduce a new one. A declaration therefore pins which keys
exist while leaving their values editable.

### Interpolation

A value whose type supports interpolation is blended between keyframes. The rest are copied. A key
named in ``exemptKeys`` is held out of interpolation whatever its type, which is how a section keeps
a discrete value from drifting between keyframes.

<doc:Section> covers the control, and <doc:CustomParameterData> covers the data classes behind
FxGrip's custom parameters.

## Topics

### Creating the value

- ``init``
- ``initWithDictionary:``

### The backing store

- ``data``
- ``exemptKeys``
- ``isLocked``
- ``locked``

### Booleans and numbers

- ``getBoolValue:forKey:``
- ``setBoolValue:forKey:``
- ``getIntValue:forKey:``
- ``setIntValue:forKey:``
- ``getFloatValue:forKey:``
- ``setFloatValue:forKey:``

### Colors

- ``getRedValue:greenValue:blueValue:forKey:``
- ``setRedValue:greenValue:blueValue:forKey:``
- ``getRedValue:greenValue:blueValue:alphaValue:forKey:``
- ``setRedValue:greenValue:blueValue:alphaValue:forKey:``

### Points

- ``getXValue:YValue:forKey:``
- ``setXValue:YValue:forKey:``

### Strings

- ``getStringParameterValue:forKey:``
- ``setStringParameterValue:forKey:``

### Histograms

- ``getHistogramBlackIn:blackOut:whiteIn:whiteOut:gamma:forChannel:forKey:``
- ``setHistogramBlackIn:blackOut:whiteIn:whiteOut:gamma:forChannel:forKey:``

### Paths

- ``getPathID:forKey:``
- ``setPathID:forKey:``
