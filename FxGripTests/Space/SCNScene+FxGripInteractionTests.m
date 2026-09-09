/*!
	@file       SCNScene+FxGripInteractionTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     SCNScene+FxGripInteractionTests
	@abstract   Tests for the scene-wide default force and its reconciliation.
	@discussion Introduced in FxGrip 0.1.0. The scene default is stored and copied, the reconciliation
	            applies it to systems that lack their own interaction, leaves systems that have their
	            own, and reaches systems on the root node as well as deeper nodes.
*/

#import <XCTest/XCTest.h>
#import <SceneKit/SceneKit.h>
#import <FxGrip/FxGripParticleInteraction.h>
#import <FxGrip/SCNParticleSystem+FxGripInteraction.h>
#import <FxGrip/SCNScene+FxGripInteraction.h>

@interface SCNScene_FxGripInteractionTests : XCTestCase
@end

@implementation SCNScene_FxGripInteractionTests

/*! @abstract The scene stores and copies its default interaction. */
- (void)testSceneDefaultStoredAndCopied
{
	SCNScene *scene = [SCNScene scene];
	XCTAssertNil(scene.particleInteraction);
	FxGripParticleInteraction *g = [FxGripParticleInteraction gravityWithStrength:2.0];
	scene.particleInteraction = g;
	XCTAssertNotNil(scene.particleInteraction);
	XCTAssertEqual(scene.particleInteraction.kind, FxGripParticleInteractionKindGravity);
	// Mutating the original does not change the stored copy.
	g.gravityStrength = 99.0;
	XCTAssertEqualWithAccuracy(scene.particleInteraction.gravityStrength, 2.0, 1e-9);
}

/*! @abstract Reconciliation installs the scene default on a system with no interaction of its own. */
- (void)testReconcileAppliesDefaultToBareSystem
{
	SCNScene *scene = [SCNScene scene];
	SCNParticleSystem *system = [SCNParticleSystem particleSystem];
	SCNNode *node = [SCNNode node];
	[node addParticleSystem:system];
	[scene.rootNode addChildNode:node];

	scene.particleInteraction = [FxGripParticleInteraction gravityWithStrength:1.0];
	XCTAssertNil(system.particleInteraction);
	[scene fxgrip_reconcileParticleInteractions];
	XCTAssertNotNil(system.particleInteraction);
	XCTAssertEqual(system.particleInteraction.kind, FxGripParticleInteractionKindGravity);
}

/*! @abstract Reconciliation leaves a system that already has its own interaction untouched. */
- (void)testReconcileKeepsOwnInteraction
{
	SCNScene *scene = [SCNScene scene];
	SCNParticleSystem *system = [SCNParticleSystem particleSystem];
	FxGripParticleInteraction *own = [FxGripParticleInteraction new];
	own.enabled = YES;
	own.kind = FxGripParticleInteractionKindElectric;
	system.particleInteraction = own;

	SCNNode *node = [SCNNode node];
	[node addParticleSystem:system];
	[scene.rootNode addChildNode:node];

	scene.particleInteraction = [FxGripParticleInteraction gravityWithStrength:1.0];
	[scene fxgrip_reconcileParticleInteractions];
	XCTAssertEqual(system.particleInteraction.kind, FxGripParticleInteractionKindElectric,
				   @"the system keeps its own interaction, not the scene default");
}

/*! @abstract Reconciliation reaches systems on the root node and on deeper nodes. */
- (void)testReconcileReachesRootAndDeepNodes
{
	SCNScene *scene = [SCNScene scene];
	SCNParticleSystem *onRoot = [SCNParticleSystem particleSystem];
	[scene.rootNode addParticleSystem:onRoot];

	SCNNode *deep = [SCNNode node];
	SCNNode *deeper = [SCNNode node];
	[deep addChildNode:deeper];
	SCNParticleSystem *onDeeper = [SCNParticleSystem particleSystem];
	[deeper addParticleSystem:onDeeper];
	[scene.rootNode addChildNode:deep];

	scene.particleInteraction = [FxGripParticleInteraction gravityWithStrength:1.0];
	[scene fxgrip_reconcileParticleInteractions];
	XCTAssertNotNil(onRoot.particleInteraction, @"a system on the root node is reconciled");
	XCTAssertNotNil(onDeeper.particleInteraction, @"a system on a deep node is reconciled");
}

/*! @abstract With no scene default, reconciliation changes nothing. */
- (void)testReconcileWithNoDefaultIsNoOp
{
	SCNScene *scene = [SCNScene scene];
	SCNParticleSystem *system = [SCNParticleSystem particleSystem];
	SCNNode *node = [SCNNode node];
	[node addParticleSystem:system];
	[scene.rootNode addChildNode:node];

	[scene fxgrip_reconcileParticleInteractions];
	XCTAssertNil(system.particleInteraction);
}

@end
