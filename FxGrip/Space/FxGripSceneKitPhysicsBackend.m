/*!
	@file       FxGripSceneKitPhysicsBackend.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSceneKitPhysicsBackend
	@abstract   Implements the fixed-step catch-up physics backend.
	@discussion Introduced in FxGrip 0.1.0. The simulation hook grid-aligns the render time to a step
	            index and simulates from the start to that index in fixed increments on the per-render
	            scene's physics world. In session-cache mode it replays a memoized step when present and
	            captures each computed step's body transforms otherwise. Changing the time step or start
	            time clears the cache.
*/

#import "FxGripSceneKitPhysicsBackend.h"
#import "FxGrip_ARC.h"

static const CFTimeInterval FxGripDefaultPhysicsTimeStep = 1.0 / 60.0;

/*!
	@abstract	An FxGripSceneKitMetalBackend that advances SceneKit physics deterministically.
	@discussion	Introduced in FxGrip 0.1.0. A step counter, guarded by a lock, records the physics steps
				taken for tests and diagnostics.
*/
@implementation FxGripSceneKitPhysicsBackend
{
	NSLock *_counterLock;
	NSUInteger _totalSimulationSteps;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_simulationStartTime = 0.0;
		_timeStep = FxGripDefaultPhysicsTimeStep;
		_simulationMode = FxGripPhysicsSimulationModeRecompute;
		_counterLock = [[NSLock alloc] init];
		_simulationStore = [[FxGripPhysicsMemoryStore alloc] init];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_counterLock);
	NARC_RELEASE(_simulationStore);
	SUPER_DEALLOC();
}

- (NSString *)backendIdentifier
{
	return @"scenekit-metal-physics";
}

#pragma mark Cache invalidation

/*! @abstract Sets the fixed physics step and clears the cache when the value changes. */
- (void)setTimeStep:(CFTimeInterval)timeStep
{
	if (_timeStep != timeStep) {
		_timeStep = timeStep;
		[self resetSimulationCache];
	}
}

/*! @abstract Sets the simulation start time and clears the cache when the value changes. */
- (void)setSimulationStartTime:(CFTimeInterval)simulationStartTime
{
	if (_simulationStartTime != simulationStartTime) {
		_simulationStartTime = simulationStartTime;
		[self resetSimulationCache];
	}
}

/*! @abstract Sets the simulation store, substituting a new memory store when passed nil. */
- (void)setSimulationStore:(id<FxGripPhysicsSimulationStore>)simulationStore
{
	if (_simulationStore != simulationStore) {
		NARC_RELEASE(_simulationStore);
		_simulationStore = NARC_RETAIN(simulationStore ?: [[FxGripPhysicsMemoryStore alloc] init]);
	}
}

/*! @abstract Clears the memoized trajectory by invalidating the simulation store. */
- (void)resetSimulationCache
{
	[_simulationStore invalidate];
}

- (NSUInteger)totalSimulationSteps
{
	[_counterLock lock];
	NSUInteger count = _totalSimulationSteps;
	[_counterLock unlock];
	return count;
}

- (void)countOneStep
{
	[_counterLock lock];
	_totalSimulationSteps += 1;
	[_counterLock unlock];
}

#pragma mark Capture and replay

/*! @abstract Reads each named physics body's presentation transform into a name-to-NSData map. */
- (NSDictionary<NSString *, NSData *> *)captureTransformsFromScene:(SCNScene *)scene
{
	NSMutableDictionary<NSString *, NSData *> *transforms = [NSMutableDictionary dictionary];
	[scene.rootNode enumerateChildNodesUsingBlock:^(SCNNode *node, BOOL *stop) {
		if (node.physicsBody != nil && node.name.length > 0) {
			simd_float4x4 matrix = node.presentationNode.simdTransform;
			transforms[node.name] = [NSData dataWithBytes:&matrix length:sizeof(matrix)];
		}
	}];
	return transforms;
}

/*! @abstract Writes stored transforms back onto the matching named physics bodies in the scene. */
- (void)applyTransforms:(NSDictionary<NSString *, NSData *> *)transforms toScene:(SCNScene *)scene
{
	[scene.rootNode enumerateChildNodesUsingBlock:^(SCNNode *node, BOOL *stop) {
		if (node.physicsBody == nil || node.name.length == 0) {
			return;
		}
		NSData *stored = transforms[node.name];
		if (stored.length == sizeof(simd_float4x4)) {
			simd_float4x4 matrix;
			[stored getBytes:&matrix length:sizeof(matrix)];
			node.simdTransform = matrix;
		}
	}];
}

#pragma mark Simulation

/*!
	@method		advanceSimulationForScene:renderer:toTime:
	@abstract	Advances the scene's physics to the step nearest `seconds` by fixed-step catch-up.
	@discussion	Introduced in FxGrip 0.1.0. The target time grid-aligns to a step index. In session-cache
				mode a cached step replays without simulating. Otherwise the world simulates from the
				start, one updateAtTime: per step, particle systems reset first, and each step's
				transforms are captured when caching. */
- (void)advanceSimulationForScene:(SCNScene *)scene
						renderer:(SCNRenderer *)renderer
						  toTime:(CFTimeInterval)seconds
{
	CFTimeInterval step = self.timeStep > 0.0 ? self.timeStep : FxGripDefaultPhysicsTimeStep;
	CFTimeInterval start = self.simulationStartTime;
	if (seconds < start) {
		seconds = start;
	}

	// Grid-align the target so a rendered pose matches its cached step exactly.
	NSInteger stepIndex = (NSInteger)lround((seconds - start) / step);
	if (stepIndex < 0) {
		stepIndex = 0;
	}

	BOOL caching = (self.simulationMode == FxGripPhysicsSimulationModeSessionCache);

	if (caching) {
		NSDictionary<NSString *, NSData *> *cached = [self.simulationStore transformsForStep:stepIndex];
		if (cached != nil) {
			[self applyTransforms:cached toScene:scene];
			return;
		}
	}

	scene.physicsWorld.timeStep = step;

	// Reset particle systems so the catch-up re-emits from the start rather than continuing a
	// previous render's state.
	[scene.rootNode enumerateChildNodesUsingBlock:^(SCNNode *node, BOOL *stop) {
		for (SCNParticleSystem *system in node.particleSystems) {
			[system reset];
		}
	}];

	// The first call establishes the baseline; each later call advances the world by one step.
	CFTimeInterval time = start;
	[renderer updateAtTime:time];
	[self countOneStep];
	if (caching) {
		[self.simulationStore setTransforms:[self captureTransformsFromScene:scene] forStep:0];
	}

	for (NSInteger k = 1; k <= stepIndex; k++) {
		time += step;
		[renderer updateAtTime:time];
		[self countOneStep];
		if (caching) {
			[self.simulationStore setTransforms:[self captureTransformsFromScene:scene] forStep:k];
		}
	}
}

@end
