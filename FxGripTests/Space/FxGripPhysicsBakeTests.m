//
//  FxGripPhysicsBakeTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripPhysicsBake.h>
#import <FxGrip/FxGripSpaceEffect.h>
#import <FxGrip/FxGripFrameData.h>
#import <FxGrip/FxGripTypes.h>

@interface FxGripPhysicsBakeTests : XCTestCase
@end

@implementation FxGripPhysicsBakeTests

- (void)testExtensionOwnsThePhysicsBakeParameterAndFrameData
{
	FxGripPhysicsBake *bake = [FxGripPhysicsBake.alloc init];
	XCTAssertEqual(bake.parameterID, (FxParameterId)kFxParameterId_PhysicsBake);
	XCTAssertTrue([bake.frameData isKindOfClass:FxGripFrameData.class]);
}

- (void)testEffectFactoryAndPresenceFlag
{
	FxGripSpaceEffect *effect = [FxGripSpaceEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertFalse(effect.hasPhysicsBake, @"the extension is not loaded until a subclass adds it");

	FxGripPhysicsBake *bake = [effect newPhysicsBakeExtension];
	XCTAssertNotNil(bake);
	XCTAssertEqual(bake.parameterID, (FxParameterId)kFxParameterId_PhysicsBake);
}

@end
