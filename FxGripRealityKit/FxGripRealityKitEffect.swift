/*!
	@file       FxGripRealityKitEffect.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitEffect
	@abstract   The RealityKit engine subclass of the 3D Space effect base.
	@discussion Introduced in FxGrip 0.1.0. This file declares the base that a RealityKit plugin
	            subclasses. RealityKit publishes no Objective-C interface, so this engine is written
	            in Swift and reaches FxGrip through the FxGrip module.
*/

import CoreMedia
import Foundation
import FxGrip
import Metal
import RealityKit

/// A 3D Space effect that renders a RealityKit scene through the host camera and lights.
///
/// Introduced in FxGrip 0.1.0. `FxGripSpaceEffect` captures the host camera, the host lights, and
/// the view-matrix samples that carry camera velocity into plugin state, then hands each frame to
/// its engine subclass. This class is the RealityKit engine. `FxGripSceneKitEffect` is the SceneKit
/// engine, and the two share that base.
///
/// The engine is Swift because RealityKit is Swift. `RealityFoundation` publishes no Objective-C
/// interface, and the headers in `RealityKit.framework` are Metal shader headers. A plugin that
/// subclasses this class is therefore a Swift plugin. A plugin that needs Objective-C subclasses
/// `FxGripSceneKitEffect` instead.
///
/// The deployment floor is macOS 15, the release that introduced `RealityRenderer`, which is the
/// only offscreen render path RealityKit offers. FxGrip itself runs on macOS 13.5, so a plugin that
/// links this module raises its own floor to macOS 15.
///
/// The render seam is inherited and not yet overridden. Until the engine's render driver lands, the
/// base render runs, which copies the source tile through unchanged.
@objc(FxGripRealityKitEffect)
open class FxGripRealityKitEffect: FxGripSpaceEffect {
}
