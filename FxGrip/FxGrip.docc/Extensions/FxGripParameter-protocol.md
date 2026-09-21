# ``FxGrip/FxGripParameter-protocol``

A leaf parameter: a value, its bounds, and its optional custom view.

## Overview

The protocol extends ``FxGripParameterBase-protocol`` with everything that depends on a parameter
holding a value. A group parameter conforms to ``FxGripSubParameters``, which extends this in turn.

### Reading a value

``stringValue`` and ``boolValue`` read and write the value in the two forms every parameter type can
produce. A failed boolean read answers `kFxGripParameterErrorBool` rather than NO, so a caller tells
a false value from a failed read. A typed read goes through the retrieval API instead, which
<doc:APIAccessing> covers.

### Bounds and defaults

``minimum``, ``maximum``, ``sliderMinimum``, and ``sliderMaximum`` are read-only here and carry the
declared bounds as `NSNumber`, whatever the parameter's numeric type. A numeric parameter that
writes its bounds adopts ``FxGripParameterMinMaxInt`` or ``FxGripParameterMinMaxDouble``, which
declare them in the parameter's own type.

``defaultX`` and ``defaultY`` carry a point parameter's declared default, and ``menuItems`` carries a
menu parameter's titles.

### The custom view

A parameter with `flagCustomUI` set vends a view. ``customView`` reads the view currently attached.
``FxGripParameter-class`` creates it in `newParameterView` and records it in `attachCustomView:`.
<doc:CustomControls> covers the controls FxGrip ships.

### Clicks

``selector`` and ``selectorString`` name the method a click performs.
``defaultParameterAction`` is the parameter's own built-in behavior, which runs when the effect
subclass declares no click selector for the parameter.

## Topics

### Value flags

- ``flagNotAnimatable``
- ``flagDontSave``
- ``flagCustomUI``
- ``flagCurveEditorHidden``
- ``flagUseFullViewWidth``

### Reading and writing the value

- ``stringValue``
- ``boolValue``

### Bounds and defaults

- ``minimum``
- ``maximum``
- ``delta``
- ``sliderMinimum``
- ``sliderMaximum``
- ``defaultX``
- ``defaultY``
- ``menuItems``

### The custom view

- ``customView``

### Responding to a click

- ``selector``
- ``selectorString``
- ``defaultParameterAction``

### Responding to a change

- ``startChangedTime:error:``
- ``endChangedTime:error:``
- ``validate``
