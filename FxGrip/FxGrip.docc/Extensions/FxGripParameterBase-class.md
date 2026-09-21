# ``FxGrip/FxGripParameterBase-class``

The concrete root of the parameter model.

## Overview

The class implements ``FxGripParameterBase-protocol`` over a stored configuration dictionary. It
resolves the parameter's flags, identity, and name through the effect's parameter APIs, registers
flag observers on the effect's notifier, and encodes the parameter type into the plugin state.

A parameter class subclasses ``FxGripParameter-class`` rather than this, unless it holds no value.

### The designated initializer

``initWithDictionary:effect:`` is the designated initializer, and it calls ``installNotifications``.
A subclass that observes more notifications overrides ``installNotifications`` and calls super. The
notifier holds selector observers weakly, and ``removeObservers`` unregisters them from `dealloc`.

### What a subclass must supply

The base declares no parameter type of its own, so `parameterType` and `addParameter:toEffect:` are
marked `NS_UNAVAILABLE` and do not appear on this page. A concrete parameter class overrides both:
one reports the `FxParameterType` the class registers, and the other builds the parameter from a
configuration dictionary and adds it to an effect. ``FxGripParameterBase-protocol`` declares them.

See <doc:ParameterModel> for the model and <doc:FxPlugParameters> for the configuration dictionary.

## Topics

### Creating a parameter

- ``initWithDictionary:effect:``

### Observing the effect

- ``installNotifications``
- ``removeObservers``

### Ordering

- ``loadIndex``

### Encoding into the plugin state

- ``encodeWithCoder:``
- ``initWithCoder:``
- ``supportsSecureCoding``
