# ``FxGrip/FxGripAPIAccessing-class``

The wrapped API manager FxGrip gives an effect.

## Overview

The class implements ``FxGripAPIAccessing-protocol`` over the host's `PROAPIAccessing` manager, and
``FxGripTileableEffect-class`` creates one during its own initialization. A plug-in reads the manager
as `apiManager` and works through the protocol. The protocol's page documents the accessor pairs,
which APIs FxGrip wraps, and which APIs FxGrip implements itself.

The class also answers `apiForProtocol:`, so the host reaches it as an ordinary `PROAPIAccessing`
manager and every protocol the host resolves passes through FxGrip's layer.

Only the manager's own state appears here. Every API accessor is a protocol requirement, documented
once on ``FxGripAPIAccessing-protocol``.

## Topics

### Resolving an API

- ``apiForProtocol:``
- ``apiForProtocol:bypass:``

### Creating a manager

- ``initWithAPIManager:effect:``

### The manager's own state

- ``effect``
- ``apiAccessing``
- ``pluginUUID``
- ``sessionID``
