# ``FxGripRealityKit/FxGripRealityKitParticleSystem``

A deterministic, FxGrip-owned particle system simulated on the CPU.

## Overview

RealityKit's own `ParticleEmitterComponent` has no seed and exposes no per-particle state, so it
neither reproduces a frame the host renders out of order nor carries an inter-particle force. This
system is the deterministic path.

The state at step *k* is a function of the ``configuration`` and *k* alone. Per-particle variation
comes from `FxGripParticleRand`, keyed by the configuration's seed and the particle's birth index,
so the same seed gives the same particles here and in the SceneKit engine.

### Stepping

The system steps on a fixed grid from a fixed start. The host renders frames out of order, so
whether a step is a resume or a restart depends only on where the request lands.

- a later step → the system resumes from ``currentStep`` and simulates only the gap.
- an earlier step, a changed configuration, or a changed force → the system restarts from zero.

Either way a frame sees the state one step sequence produces from an empty system.
``totalSimulationSteps`` counts the steps actually taken, so a test can prove a resume repeated
nothing.

### Reading the particles

The per-particle arrays are parallel and ``particleCount`` entries long. ``renderedColors`` and
``renderedSizes`` carry the values after the configuration's life-curve is applied, which is what
``FxGripRealityKitParticleGeometry`` draws.

## Topics

### Creating a system

- ``init()``
- ``FxGripRealityKitParticleSystem/Configuration``
- ``configuration``

### Stepping the simulation

- ``advance(to:)``
- ``advance(toStep:)``
- ``stepIndex(for:)``
- ``reset()``
- ``currentStep``
- ``timeStep``
- ``simulationStartTime``
- ``totalSimulationSteps``

### Reading particle state

- ``particleCount``
- ``capacity``
- ``positions``
- ``velocities``
- ``ages``
- ``lifeSpans``
- ``lifeFractions``
- ``birthIndices``

### Reading appearance

- ``sizes``
- ``colors``
- ``angles``
- ``renderedSizes``
- ``renderedColors``
- ``material``

### Seeding state directly

- ``setParticles(positions:velocities:ages:lifeSpans:sizes:colors:angles:)``

### Inter-particle force

- ``particleInteraction``
