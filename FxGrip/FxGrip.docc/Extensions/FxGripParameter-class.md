# ``FxGrip/FxGripParameter-class``

The concrete root of a leaf parameter that carries a value and an optional view.

## Overview

A parameter class subclasses this. It extends ``FxGripParameterBase-class`` with the custom
inspector view surface, the secure-coding allow-list for a custom value, and the parameter's
description, tags, meta, and declared values.

### Vending a custom view

A parameter whose configuration sets `customui` vends a view. The host's view host calls
``newParameterView`` and hands the result to the host application, then attaches it through
``attachCustomView:`` so the parameter can push data to it. The base returns nil from
``newParameterView``, so a parameter with no custom UI needs no override.

The returned view is retained, matching the `FxCustomParameterViewHost_v2` contract.

### Coding a custom value

A parameter whose custom value is its own model type overrides ``customValueClasses`` with the
classes that value decodes. The custom-parameter path consults the class registered for the
configured type, so the allow-list follows the type rather than the instance.

<doc:CustomControls> covers the controls FxGrip ships, and <doc:CustomParameterData> covers the data
classes behind them.

## Topics

### Vending a custom view

- ``newParameterView``
- ``attachCustomView:``

### Coding a custom value

- ``customValueClasses``

### Describing the parameter

- ``paramDescription``
- ``customClass``
- ``customDataClasses``

### Tags and meta

- ``tags``
- ``meta``

### Declared values

- ``defaultValue``
- ``resetValue``
