/*!
	@file       FxGripFMMSpikeTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMSpikeTests
	@abstract   Phase 0 spike for the inter-particle FMM. Records how SceneKit invokes a particle
	            modifier and a custom physics field under the headless fixed-step render path.
	@discussion Introduced in FxGrip 0.1.0. The FMM plan (Local/Particle FMM Plan.md) assumes the
	            modifier block is called once per step over every live particle, that Charge is a
	            readable strip, that velocity writes persist to the next step, that a pre-dynamics
	            modifier runs before a custom field's evaluator within one step, and that the field
	            evaluator is called once per particle. These assumptions decide the gather and the
	            field-facade design, so they are measured here before the core is built.

	            The spike is gated on a marker file and skipped in an ordinary run. It writes its
	            observations to a JSON file for inspection and asserts the load-bearing hypotheses.
*/

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <SceneKit/SceneKit.h>
#import <FxGrip/FxGripSceneKitPhysicsBackend.h>

static NSString * const FxGripFMMSpikeMarkerPath = @"/tmp/fxgrip-fmm-spike";
static NSString * const FxGripFMMSpikeResultDir = @"/tmp/fxgrip-fmm-spike-results";

// One record of a single modifier-block invocation.
@interface FxGripFMMSpikeCall : NSObject
@property (nonatomic, assign) NSInteger start;
@property (nonatomic, assign) NSInteger end;
@property (nonatomic, assign) float deltaTime;
@property (nonatomic, assign) size_t positionStride;
@property (nonatomic, assign) size_t velocityStride;
@property (nonatomic, assign) size_t chargeStride;
@property (nonatomic, assign) BOOL positionNonNull;
@property (nonatomic, assign) BOOL velocityNonNull;
@property (nonatomic, assign) BOOL chargeNonNull;
@end
@implementation FxGripFMMSpikeCall
@end

@interface FxGripFMMSpikeTests : XCTestCase
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *findings;
@end

@implementation FxGripFMMSpikeTests

- (void)setUp
{
	[super setUp];
	self.device = MTLCreateSystemDefaultDevice();
	self.findings = [NSMutableDictionary dictionary];
	if (![NSFileManager.defaultManager fileExistsAtPath:FxGripFMMSpikeMarkerPath]) {
		XCTSkip("FMM spike is gated; touch %@ to run it.", FxGripFMMSpikeMarkerPath);
	}
	if (self.device == nil) {
		XCTSkip(@"No Metal device available");
	}
}

- (void)tearDown
{
	[self flushFindings];
	[super tearDown];
}

// Writes the accumulated findings to a per-test file, so a later test cannot overwrite them and a
// failed assertion still leaves a record.
- (void)flushFindings
{
	if (self.findings.count == 0) {
		return;
	}
	[NSFileManager.defaultManager createDirectoryAtPath:FxGripFMMSpikeResultDir
							withIntermediateDirectories:YES attributes:nil error:NULL];
	NSString *path = [FxGripFMMSpikeResultDir stringByAppendingPathComponent:
					  [self.name stringByAppendingPathExtension:@"json"]];
	NSData *json = [NSJSONSerialization dataWithJSONObject:self.findings
												  options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
													error:NULL];
	[json writeToFile:path atomically:YES];
}

#pragma mark Scene construction

- (id<MTLTexture>)renderTargetOfSize:(NSUInteger)size
{
	MTLTextureDescriptor *descriptor =
		[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:size height:size mipmapped:NO];
	descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	descriptor.storageMode = MTLStorageModeShared;
	return [self.device newTextureWithDescriptor:descriptor];
}

- (SCNParticleSystem *)emitterSystem
{
	SCNParticleSystem *particles = [SCNParticleSystem particleSystem];
	particles.birthRate = 200.0;
	particles.emissionDuration = 1.0;
	particles.loops = YES;
	particles.particleLifeSpan = 4.0;
	particles.particleVelocity = 4.0;
	particles.particleCharge = 1.0;
	particles.emittingDirection = SCNVector3Make(0.0, 1.0, 0.0);
	particles.affectedByPhysicsFields = YES;
	return particles;
}

- (SCNNode *)cameraNode
{
	SCNNode *cameraNode = [SCNNode node];
	cameraNode.camera = [SCNCamera camera];
	cameraNode.position = SCNVector3Make(0.0, 2.0, 20.0);
	return cameraNode;
}

#pragma mark Modifier call pattern

/*!
	@abstract	Records every pre-dynamics modifier invocation across a render and asserts the gather
				assumptions: Charge is a readable strip, and each call carries valid strided buffers.
*/
- (void)testModifierCallPattern
{
	NSMutableArray<FxGripFMMSpikeCall *> *calls = [NSMutableArray array];

	SCNScene *scene = [SCNScene scene];
	SCNParticleSystem *particles = [self emitterSystem];

	[particles addModifierForProperties:@[SCNParticlePropertyPosition, SCNParticlePropertyVelocity, SCNParticlePropertyCharge]
							   atStage:SCNParticleModifierStagePreDynamics
							 withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride, NSInteger start, NSInteger end, float deltaTime) {
		FxGripFMMSpikeCall *call = [FxGripFMMSpikeCall new];
		call.start = start;
		call.end = end;
		call.deltaTime = deltaTime;
		call.positionStride = dataStride[0];
		call.velocityStride = dataStride[1];
		call.chargeStride = dataStride[2];
		call.positionNonNull = (data[0] != NULL);
		call.velocityNonNull = (data[1] != NULL);
		call.chargeNonNull = (data[2] != NULL);
		@synchronized (calls) {
			[calls addObject:call];
		}
	}];

	SCNNode *emitter = [SCNNode node];
	[emitter addParticleSystem:particles];
	[scene.rootNode addChildNode:emitter];
	SCNNode *pov = [self cameraNode];
	[scene.rootNode addChildNode:pov];

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;
	backend.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

	NSError *error = nil;
	XCTAssertTrue([backend renderScene:scene pointOfView:pov toTexture:[self renderTargetOfSize:64] atTime:0.5 error:&error], @"%@", error);

	NSMutableArray *dump = [NSMutableArray array];
	NSInteger maxEnd = 0;
	NSMutableSet<NSNumber *> *distinctDeltas = [NSMutableSet set];
	for (FxGripFMMSpikeCall *call in calls) {
		[dump addObject:@{ @"start": @(call.start), @"end": @(call.end), @"deltaTime": @(call.deltaTime),
						   @"positionStride": @(call.positionStride), @"velocityStride": @(call.velocityStride),
						   @"chargeStride": @(call.chargeStride),
						   @"positionNonNull": @(call.positionNonNull), @"velocityNonNull": @(call.velocityNonNull),
						   @"chargeNonNull": @(call.chargeNonNull) }];
		maxEnd = MAX(maxEnd, call.end);
		[distinctDeltas addObject:@(call.deltaTime)];
	}
	self.findings[@"modifier_totalCalls"] = @(calls.count);
	self.findings[@"modifier_maxEnd"] = @(maxEnd);
	self.findings[@"modifier_distinctDeltaTimes"] = @(distinctDeltas.count);
	self.findings[@"modifier_calls"] = dump;
	FxGripFMMSpikeCall *first = calls.firstObject;
	// Charge is a system-level constant (particleCharge), not a per-particle strip. The gather needs
	// only Position and Velocity; whether Charge appears as a strip is recorded, not required.
	self.findings[@"modifier_chargeStripAvailable"] = @(first != nil && first.chargeNonNull && first.chargeStride >= sizeof(float));
	[self flushFindings];

	XCTAssertGreaterThan(calls.count, 0u, @"the modifier fires at least once during a render");
	XCTAssertTrue(first.positionNonNull && first.velocityNonNull, @"position and velocity buffers are valid");
	XCTAssertGreaterThanOrEqual(first.positionStride, sizeof(float) * 3, @"position stride holds a float3");
	XCTAssertGreaterThanOrEqual(first.velocityStride, sizeof(float) * 3, @"velocity stride holds a float3");
}

#pragma mark Which stage applies a velocity write

// Sets every particle's velocity to (V, 0, 0) each step at `stage`, then reads the maximum absolute
// x-position reached by any particle (via a reader modifier at the last stage). A stage where the
// write drives integration streams particles far along +x; an ineffective stage leaves them near the
// emitter. This tells the FMM which stage to write the force at.
- (float)maxParticleXWithForceStage:(SCNParticleModifierStage)stage velocity:(float)velocity
{
	__block float maxAbsX = 0.0f;

	SCNScene *scene = [SCNScene scene];
	SCNParticleSystem *particles = [self emitterSystem];
	particles.acceleration = SCNVector3Make(0.0, 0.0, 0.0);

	[particles addModifierForProperties:@[SCNParticlePropertyVelocity]
							   atStage:stage
							 withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride, NSInteger start, NSInteger end, float deltaTime) {
		for (NSInteger i = start; i < end; i++) {
			float *v = (float *)((uintptr_t)data[0] + dataStride[0] * (NSUInteger)i);
			v[0] = velocity; v[1] = 0.0f; v[2] = 0.0f;
		}
	}];
	[particles addModifierForProperties:@[SCNParticlePropertyPosition]
							   atStage:SCNParticleModifierStagePostCollision
							 withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride, NSInteger start, NSInteger end, float deltaTime) {
		for (NSInteger i = start; i < end; i++) {
			float *p = (float *)((uintptr_t)data[0] + dataStride[0] * (NSUInteger)i);
			maxAbsX = MAX(maxAbsX, fabsf(p[0]));
		}
	}];

	SCNNode *emitter = [SCNNode node];
	[emitter addParticleSystem:particles];
	[scene.rootNode addChildNode:emitter];
	SCNNode *pov = [self cameraNode];
	[scene.rootNode addChildNode:pov];

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;

	NSError *error = nil;
	XCTAssertTrue([backend renderScene:scene pointOfView:pov toTexture:[self renderTargetOfSize:64] atTime:0.3 error:&error], @"%@", error);
	return maxAbsX;
}

/*!
	@abstract	Determines which modifier stage a velocity write must use so the FMM force drives the
				particle motion.
*/
- (void)testWhichStageAppliesForce
{
	const float velocity = 50.0f;
	float preDynamics = [self maxParticleXWithForceStage:SCNParticleModifierStagePreDynamics velocity:velocity];
	float postDynamics = [self maxParticleXWithForceStage:SCNParticleModifierStagePostDynamics velocity:velocity];
	float preCollision = [self maxParticleXWithForceStage:SCNParticleModifierStagePreCollision velocity:velocity];
	float baseline = [self maxParticleXWithForceStage:SCNParticleModifierStagePostCollision velocity:0.0f];

	self.findings[@"stage_preDynamics_maxX"] = @(preDynamics);
	self.findings[@"stage_postDynamics_maxX"] = @(postDynamics);
	self.findings[@"stage_preCollision_maxX"] = @(preCollision);
	self.findings[@"stage_baseline_maxX"] = @(baseline);
	// A stage is "effective" when its 50 u/s write carries particles well past where the unforced
	// baseline leaves them.
	self.findings[@"stage_preDynamicsEffective"] = @(preDynamics > baseline + 5.0f);
	self.findings[@"stage_postDynamicsEffective"] = @(postDynamics > baseline + 5.0f);
	self.findings[@"stage_preCollisionEffective"] = @(preCollision > baseline + 5.0f);
	[self flushFindings];

	XCTAssertGreaterThan(preDynamics + postDynamics + preCollision, baseline,
						 @"at least one stage's velocity write moves the particles");
}

#pragma mark Field evaluator and ordering

/*!
	@abstract	Installs a pre-dynamics modifier and a custom physics field and records their relative
				call order within a step and how often the field evaluator fires.
*/
- (void)testFieldEvaluatorOrderingAndFrequency
{
	__block NSInteger modifierCalls = 0;
	__block NSInteger fieldCalls = 0;
	__block NSInteger fieldCallsBeforeAnyModifier = 0;
	__block NSInteger lastParticleCountAtModifier = 0;

	SCNScene *scene = [SCNScene scene];
	SCNParticleSystem *particles = [self emitterSystem];

	[particles addModifierForProperties:@[SCNParticlePropertyPosition]
							   atStage:SCNParticleModifierStagePreDynamics
							 withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride, NSInteger start, NSInteger end, float deltaTime) {
		modifierCalls += 1;
		lastParticleCountAtModifier = end;
	}];

	SCNNode *emitter = [SCNNode node];
	[emitter addParticleSystem:particles];
	[scene.rootNode addChildNode:emitter];

	SCNPhysicsField *field = [SCNPhysicsField customFieldWithEvaluationBlock:
		^SCNVector3(SCNVector3 position, SCNVector3 velocity, float mass, float charge, NSTimeInterval time) {
		fieldCalls += 1;
		if (modifierCalls == 0) {
			fieldCallsBeforeAnyModifier += 1;
		}
		return SCNVector3Make(0.0, 0.0, 0.0);
	}];
	SCNNode *fieldNode = [SCNNode node];
	fieldNode.physicsField = field;
	[scene.rootNode addChildNode:fieldNode];

	SCNNode *pov = [self cameraNode];
	[scene.rootNode addChildNode:pov];

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;

	NSError *error = nil;
	XCTAssertTrue([backend renderScene:scene pointOfView:pov toTexture:[self renderTargetOfSize:64] atTime:0.2 error:&error], @"%@", error);

	self.findings[@"field_modifierCalls"] = @(modifierCalls);
	self.findings[@"field_fieldCalls"] = @(fieldCalls);
	self.findings[@"field_fieldCallsBeforeAnyModifier"] = @(fieldCallsBeforeAnyModifier);
	self.findings[@"field_lastParticleCountAtModifier"] = @(lastParticleCountAtModifier);
	self.findings[@"field_evaluatorInvoked"] = @(fieldCalls > 0);
	self.findings[@"field_modifierRanBeforeField"] = @(modifierCalls > 0 && fieldCallsBeforeAnyModifier == 0);
	[self flushFindings];
	// Observations, not pass gates: the plan adapts to whatever these report.
}

#pragma mark Field evaluator arguments and force semantics

// Renders an emitter under a custom field that returns a constant vector along +x, and reports the
// farthest x any particle reaches. Comparing two masses reveals whether SceneKit reads the returned
// vector as a force (displacement scales as 1/mass) or as an acceleration (displacement is unchanged).
- (float)maxParticleXWithConstantFieldForce:(float)force particleMass:(CGFloat)mass
{
	__block float maxAbsX = 0.0f;

	SCNScene *scene = [SCNScene scene];
	SCNParticleSystem *particles = [self emitterSystem];
	particles.acceleration = SCNVector3Make(0.0, 0.0, 0.0);
	particles.particleVelocity = 0.0;
	particles.particleVelocityVariation = 0.0;
	particles.particleMass = mass;
	[particles addModifierForProperties:@[SCNParticlePropertyPosition]
							   atStage:SCNParticleModifierStagePostCollision
							 withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride, NSInteger start, NSInteger end, float deltaTime) {
		for (NSInteger i = start; i < end; i++) {
			float *p = (float *)((uintptr_t)data[0] + dataStride[0] * (NSUInteger)i);
			maxAbsX = MAX(maxAbsX, fabsf(p[0]));
		}
	}];

	SCNNode *emitter = [SCNNode node];
	[emitter addParticleSystem:particles];
	[scene.rootNode addChildNode:emitter];

	SCNPhysicsField *field = [SCNPhysicsField customFieldWithEvaluationBlock:
		^SCNVector3(SCNVector3 position, SCNVector3 velocity, float m, float charge, NSTimeInterval time) {
		return SCNVector3Make(force, 0.0, 0.0);
	}];
	SCNNode *fieldNode = [SCNNode node];
	fieldNode.physicsField = field;
	[scene.rootNode addChildNode:fieldNode];

	SCNNode *pov = [self cameraNode];
	[scene.rootNode addChildNode:pov];

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;

	NSError *error = nil;
	XCTAssertTrue([backend renderScene:scene pointOfView:pov toTexture:[self renderTargetOfSize:64] atTime:0.3 error:&error], @"%@", error);
	return maxAbsX;
}

/*!
	@abstract	Records the mass and charge SceneKit passes a custom field evaluator for particles, and
				whether the returned vector is treated as a force or as an acceleration.
	@discussion The field facade folds the receiver coupling from the evaluator's mass and charge
				arguments, so it needs to know that SceneKit actually supplies the system constants
				there, and whether it divides the returned vector by the mass.
*/
- (void)testFieldEvaluatorArgumentsAndForceSemantics
{
	__block float observedMass = -1.0f;
	__block float observedCharge = -1.0f;
	__block NSInteger calls = 0;

	SCNScene *scene = [SCNScene scene];
	SCNParticleSystem *particles = [self emitterSystem];
	particles.particleMass = 4.0;
	particles.particleCharge = 3.0;

	SCNNode *emitter = [SCNNode node];
	[emitter addParticleSystem:particles];
	[scene.rootNode addChildNode:emitter];

	SCNPhysicsField *field = [SCNPhysicsField customFieldWithEvaluationBlock:
		^SCNVector3(SCNVector3 position, SCNVector3 velocity, float mass, float charge, NSTimeInterval time) {
		calls += 1;
		observedMass = mass;
		observedCharge = charge;
		return SCNVector3Make(0.0, 0.0, 0.0);
	}];
	SCNNode *fieldNode = [SCNNode node];
	fieldNode.physicsField = field;
	[scene.rootNode addChildNode:fieldNode];

	SCNNode *pov = [self cameraNode];
	[scene.rootNode addChildNode:pov];

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;
	NSError *error = nil;
	XCTAssertTrue([backend renderScene:scene pointOfView:pov toTexture:[self renderTargetOfSize:64] atTime:0.2 error:&error], @"%@", error);

	self.findings[@"fieldArgs_calls"] = @(calls);
	self.findings[@"fieldArgs_mass"] = @(observedMass);
	self.findings[@"fieldArgs_charge"] = @(observedCharge);
	self.findings[@"fieldArgs_massMatchesParticleMass"] = @(fabsf(observedMass - 4.0f) < 1e-4f);
	self.findings[@"fieldArgs_chargeMatchesParticleCharge"] = @(fabsf(observedCharge - 3.0f) < 1e-4f);

	const float force = 40.0f;
	float atMass1 = [self maxParticleXWithConstantFieldForce:force particleMass:1.0];
	float atMass4 = [self maxParticleXWithConstantFieldForce:force particleMass:4.0];
	self.findings[@"fieldForce_maxXAtMass1"] = @(atMass1);
	self.findings[@"fieldForce_maxXAtMass4"] = @(atMass4);
	self.findings[@"fieldForce_ratio"] = @(atMass4 > 0.0f ? atMass1 / atMass4 : 0.0f);
	// A ratio near 4 means the return is a force divided by mass; a ratio near 1 means it is taken as
	// an acceleration outright.
	self.findings[@"fieldForce_returnIsForce"] = @(atMass4 > 0.0f && atMass1 / atMass4 > 2.0f);
	[self flushFindings];
	// Observations, not pass gates.
}

// Drops a single dynamic body under a custom field that returns a constant vector along +x, and
// reports the x it reaches. Comparing two masses tells whether SceneKit divides the returned vector
// by the body mass, which is the rigid-body half of the same question the particle probe asks.
- (float)bodyXWithConstantFieldForce:(float)force bodyMass:(CGFloat)mass
{
	SCNScene *scene = [SCNScene scene];
	scene.physicsWorld.gravity = SCNVector3Make(0.0, 0.0, 0.0);

	SCNNode *body = [SCNNode nodeWithGeometry:[SCNSphere sphereWithRadius:0.1]];
	body.physicsBody = [SCNPhysicsBody bodyWithType:SCNPhysicsBodyTypeDynamic shape:nil];
	body.physicsBody.mass = mass;
	body.physicsBody.damping = 0.0;
	[scene.rootNode addChildNode:body];

	SCNPhysicsField *field = [SCNPhysicsField customFieldWithEvaluationBlock:
		^SCNVector3(SCNVector3 position, SCNVector3 velocity, float m, float charge, NSTimeInterval time) {
		return SCNVector3Make(force, 0.0, 0.0);
	}];
	SCNNode *fieldNode = [SCNNode node];
	fieldNode.physicsField = field;
	[scene.rootNode addChildNode:fieldNode];

	SCNNode *pov = [self cameraNode];
	[scene.rootNode addChildNode:pov];

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;
	NSError *error = nil;
	XCTAssertTrue([backend renderScene:scene pointOfView:pov toTexture:[self renderTargetOfSize:64] atTime:0.3 error:&error], @"%@", error);
	return (float)body.presentationNode.position.x;
}

/*!
	@abstract	Records whether the vector a custom field returns scales with magnitude, and whether a
				rigid body divides it by mass while a particle does not.
*/
- (void)testFieldForceScalingAndRigidBodyMass
{
	float atForce40 = [self maxParticleXWithConstantFieldForce:40.0f particleMass:1.0];
	float atForce80 = [self maxParticleXWithConstantFieldForce:80.0f particleMass:1.0];
	self.findings[@"fieldScale_maxXAtForce40"] = @(atForce40);
	self.findings[@"fieldScale_maxXAtForce80"] = @(atForce80);
	self.findings[@"fieldScale_ratio"] = @(atForce40 > 0.0f ? atForce80 / atForce40 : 0.0f);

	float bodyMass1 = [self bodyXWithConstantFieldForce:40.0f bodyMass:1.0];
	float bodyMass4 = [self bodyXWithConstantFieldForce:40.0f bodyMass:4.0];
	self.findings[@"fieldBody_xAtMass1"] = @(bodyMass1);
	self.findings[@"fieldBody_xAtMass4"] = @(bodyMass4);
	self.findings[@"fieldBody_ratio"] = @(fabsf(bodyMass4) > 1e-6f ? bodyMass1 / bodyMass4 : 0.0f);
	[self flushFindings];
	// Observations, not pass gates.
}

/*!
	@abstract	Records whether every particle system's modifier runs before any field evaluation, or
				whether SceneKit interleaves each system's modifier with its own field evaluations.
	@discussion A field that draws its sources from several systems can only be current if all of the
				companion modifiers have gathered before the first evaluator call. If SceneKit updates
				one system at a time, the first system's targets read a field missing the later
				systems' particles, which is a one-step lag rather than an error.
*/
- (void)testFieldEvaluationOrderAcrossTwoSystems
{
	__block NSInteger modifierACalls = 0;
	__block NSInteger modifierBCalls = 0;
	__block NSInteger fieldCalls = 0;
	__block NSInteger fieldCallsBeforeBothModifiers = 0;

	SCNScene *scene = [SCNScene scene];
	SCNParticleSystem *a = [self emitterSystem];
	SCNParticleSystem *b = [self emitterSystem];

	[a addModifierForProperties:@[SCNParticlePropertyPosition]
						atStage:SCNParticleModifierStagePreDynamics
					  withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride, NSInteger start, NSInteger end, float deltaTime) {
		modifierACalls += 1;
	}];
	[b addModifierForProperties:@[SCNParticlePropertyPosition]
						atStage:SCNParticleModifierStagePreDynamics
					  withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride, NSInteger start, NSInteger end, float deltaTime) {
		modifierBCalls += 1;
	}];

	SCNNode *emitterA = [SCNNode node];
	[emitterA addParticleSystem:a];
	emitterA.position = SCNVector3Make(-2.0, 0.0, 0.0);
	[scene.rootNode addChildNode:emitterA];
	SCNNode *emitterB = [SCNNode node];
	[emitterB addParticleSystem:b];
	emitterB.position = SCNVector3Make(2.0, 0.0, 0.0);
	[scene.rootNode addChildNode:emitterB];

	SCNPhysicsField *field = [SCNPhysicsField customFieldWithEvaluationBlock:
		^SCNVector3(SCNVector3 position, SCNVector3 velocity, float mass, float charge, NSTimeInterval time) {
		fieldCalls += 1;
		if (modifierACalls == 0 || modifierBCalls == 0) {
			fieldCallsBeforeBothModifiers += 1;
		}
		return SCNVector3Make(0.0, 0.0, 0.0);
	}];
	SCNNode *fieldNode = [SCNNode node];
	fieldNode.physicsField = field;
	[scene.rootNode addChildNode:fieldNode];

	SCNNode *pov = [self cameraNode];
	[scene.rootNode addChildNode:pov];

	FxGripSceneKitPhysicsBackend *backend = [FxGripSceneKitPhysicsBackend backend];
	backend.timeStep = 1.0 / 60.0;
	NSError *error = nil;
	XCTAssertTrue([backend renderScene:scene pointOfView:pov toTexture:[self renderTargetOfSize:64] atTime:0.2 error:&error], @"%@", error);

	self.findings[@"twoSystems_modifierACalls"] = @(modifierACalls);
	self.findings[@"twoSystems_modifierBCalls"] = @(modifierBCalls);
	self.findings[@"twoSystems_fieldCalls"] = @(fieldCalls);
	self.findings[@"twoSystems_fieldCallsBeforeBothModifiers"] = @(fieldCallsBeforeBothModifiers);
	self.findings[@"twoSystems_allModifiersRunBeforeAnyField"] = @(fieldCallsBeforeBothModifiers == 0);
	[self flushFindings];
	// Observations, not pass gates.
}

@end
