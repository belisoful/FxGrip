//
//  FxGripSceneKitPhysicsBackend.m
//  FxGrip
//

#import "FxGripSceneKitPhysicsBackend.h"
#import "FxGrip_ARC.h"

static const CFTimeInterval FxGripDefaultPhysicsTimeStep = 1.0 / 60.0;

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

- (void)setTimeStep:(CFTimeInterval)timeStep
{
	if (_timeStep != timeStep) {
		_timeStep = timeStep;
		[self resetSimulationCache];
	}
}

- (void)setSimulationStartTime:(CFTimeInterval)simulationStartTime
{
	if (_simulationStartTime != simulationStartTime) {
		_simulationStartTime = simulationStartTime;
		[self resetSimulationCache];
	}
}

- (void)setSimulationStore:(id<FxGripPhysicsSimulationStore>)simulationStore
{
	if (_simulationStore != simulationStore) {
		NARC_RELEASE(_simulationStore);
		_simulationStore = NARC_RETAIN(simulationStore ?: [[FxGripPhysicsMemoryStore alloc] init]);
	}
}

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
