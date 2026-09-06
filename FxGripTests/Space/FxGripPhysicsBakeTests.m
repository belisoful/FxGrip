/*!
	@file       FxGripPhysicsBakeTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPhysicsBakeTests
	@abstract   Tests for FxGripPhysicsBake, the space-effect extension that owns the physics-bake parameter and frame-data store.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the extension exposes the physics-bake parameter id and a frame-data store, and that FxGripSpaceEffect vends the extension from its factory while reporting its absence until a subclass adds it.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripPhysicsBake.h>
#import <FxGrip/FxGripSpaceEffect.h>
#import <FxGrip/FxGripFrameData.h>
#import <FxGrip/FxGripTypes.h>

@interface FxGripPhysicsBakeTests : XCTestCase
@end

@implementation FxGripPhysicsBakeTests

/*! @abstract A physics-bake extension reports the physics-bake parameter id and holds an FxGripFrameData store. */
- (void)testExtensionOwnsThePhysicsBakeParameterAndFrameData
{
	FxGripPhysicsBake *bake = [FxGripPhysicsBake.alloc init];
	XCTAssertEqual(bake.parameterID, (FxParameterId)kFxParameterId_PhysicsBake);
	XCTAssertTrue([bake.frameData isKindOfClass:FxGripFrameData.class]);
}

/*! @abstract A space effect reports no physics bake until -newPhysicsBakeExtension vends an extension carrying the physics-bake parameter id. */
- (void)testEffectFactoryAndPresenceFlag
{
	FxGripSpaceEffect *effect = [FxGripSpaceEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertFalse(effect.hasPhysicsBake, @"the extension is not loaded until a subclass adds it");

	FxGripPhysicsBake *bake = [effect newPhysicsBakeExtension];
	XCTAssertNotNil(bake);
	XCTAssertEqual(bake.parameterID, (FxParameterId)kFxParameterId_PhysicsBake);
}

@end
