//
//  FxGripExtensionTests.m
//  FxGripTests
//
//  Unit tests for FxGripExtensionBase: initialization defaults, notification
//  priority, the setExtActive: guard, index/individuation behavior, and
//  observer registration performed by extLoadWithEffect:.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
// BEFoundation is present in-process because the loaded FxGrip framework links it.
static NSNotificationCenter *FxGripExtTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

#pragma mark - Test doubles

// Minimal stand-in for an effect. FxGripExtensionBase only reads -notifier (during
// extLoadWithEffect:) and -addedToDocument (during setExtActive:), so the stub
// implements just those two and is passed where id<FxGripTileableEffect> is expected.
@interface FxGripExtTestStubEffect : NSObject
@property (nonatomic, assign) BOOL addedToDocument;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@end

@implementation FxGripExtTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

@end

// Extension that observes FxGripTileableEffectInitName. extLoadWithEffect: registers
// an observer for -extInit: only because this subclass implements it.
@interface FxGripExtInitObservingExtension : FxGripExtensionBase
@property (nonatomic, assign) BOOL didReceiveInit;
@property (nonatomic, strong) NSNotification *lastInitNotification;
@end

@implementation FxGripExtInitObservingExtension
- (void)extInit:(NSNotification *)notification
{
	self.didReceiveInit = YES;
	self.lastInitNotification = notification;
}
@end

// Extension implementing none of the ext* selectors; extLoadWithEffect: must
// register no observers and posting must not reach it or crash.
@interface FxGripExtSilentExtension : FxGripExtensionBase
@end

@implementation FxGripExtSilentExtension
@end

// Extension that overrides the individuation getter so its key always carries the
// load index, including the index-zero first instance.
@interface FxGripExtIndividuatingExtension : FxGripExtensionBase
@end

@implementation FxGripExtIndividuatingExtension
- (BOOL)extIndividuate
{
	return YES;
}
@end

#pragma mark - Tests

@interface FxGripExtensionTests : XCTestCase
@end

@implementation FxGripExtensionTests

- (void)testInitReturnsNonNilInstance
{
	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	XCTAssertNotNil(ext);
}

- (void)testInitDefaults
{
	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];

	XCTAssertTrue(ext.extActive);
	XCTAssertEqual(ext.extKeyIndex, -1);
	XCTAssertEqualObjects(ext.extKey, NSStringFromClass(FxGripExtensionBase.class));
	XCTAssertEqual(ext.extDefaultPriority, FxGripExtensionDefaultPriority);
	XCTAssertFalse(ext.extIncludeWhenDisabled);
	XCTAssertFalse(ext.extIndividuate);
}

- (void)testExtKeyDefaultsToConcreteSubclassName
{
	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];
	XCTAssertEqualObjects(ext.extKey, NSStringFromClass(FxGripExtInitObservingExtension.class));
}

- (void)testNcPriorityReturnsDefaultPriority
{
	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	XCTAssertEqual([ext ncPriority:nil], FxGripExtensionDefaultPriority);
	XCTAssertEqual([ext ncPriority:FxGripTileableEffectInitName], FxGripExtensionDefaultPriority);
}

- (void)testNcPriorityTracksChangedDefaultPriority
{
	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	ext.extDefaultPriority = -18;
	XCTAssertEqual([ext ncPriority:nil], -18);

	ext.extDefaultPriority = 20;
	XCTAssertEqual([ext ncPriority:FxGripTileableEffectFlushName], 20);
}

- (void)testSetExtActiveTogglesWithNoEffectLoaded
{
	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];

	[ext setExtActive:NO];
	XCTAssertFalse(ext.extActive);

	[ext setExtActive:YES];
	XCTAssertTrue(ext.extActive);
}

- (void)testSetExtActiveSucceedsWhenEffectNotYetAddedToDocument
{
	FxGripExtTestStubEffect *effect = [FxGripExtTestStubEffect.alloc init];
	effect.notifier = FxGripExtTestMakePriorityCenter();
	effect.addedToDocument = NO;

	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	[ext extLoadWithEffect:(id)effect];

	[ext setExtActive:NO];
	XCTAssertFalse(ext.extActive);
}

- (void)testSetExtActiveRejectedAfterEffectAddedToDocument
{
	FxGripExtTestStubEffect *effect = [FxGripExtTestStubEffect.alloc init];
	effect.notifier = FxGripExtTestMakePriorityCenter();
	effect.addedToDocument = YES;

	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	[ext extLoadWithEffect:(id)effect];

	[ext setExtActive:NO];
	XCTAssertTrue(ext.extActive, @"setExtActive: must be ignored once the effect is added to the document");
}

- (void)testExtLoadWithIndexStoresIndexAndAppendsItWithoutIndividuation
{
	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];
	NSString *keyBeforeLoad = ext.extKey;

	[ext extLoadWithIndex:7];

	XCTAssertEqual(ext.extKeyIndex, 7);
	// A nonzero index suffixes the key whatever extIndividuate reports.
	XCTAssertFalse(ext.extIndividuate);
	XCTAssertEqualObjects(ext.extKey, [keyBeforeLoad stringByAppendingString:@"7"]);
}

- (void)testExtLoadWithIndexZeroKeepsBareClassNameByDefault
{
	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];

	[ext extLoadWithIndex:0];

	XCTAssertEqual(ext.extKeyIndex, 0);
	XCTAssertEqualObjects(ext.extKey, NSStringFromClass(FxGripExtInitObservingExtension.class));
}

- (void)testExtLoadWithIndexOneAppendsIndexToKey
{
	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];

	[ext extLoadWithIndex:1];

	XCTAssertEqual(ext.extKeyIndex, 1);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxGripExtInitObservingExtension.class) stringByAppendingString:@"1"]);
}

- (void)testExtLoadWithIndexTwoAppendsIndexToKey
{
	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];

	[ext extLoadWithIndex:2];

	XCTAssertEqual(ext.extKeyIndex, 2);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxGripExtInitObservingExtension.class) stringByAppendingString:@"2"]);
}

- (void)testIndividuatingExtensionAppendsZeroIndexToKey
{
	FxGripExtIndividuatingExtension *ext = [FxGripExtIndividuatingExtension.alloc init];
	XCTAssertTrue(ext.extIndividuate);

	[ext extLoadWithIndex:0];

	XCTAssertEqual(ext.extKeyIndex, 0);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxGripExtIndividuatingExtension.class) stringByAppendingString:@"0"]);
}

- (void)testIndividuatingExtensionAppendsNonzeroIndexOnce
{
	FxGripExtIndividuatingExtension *ext = [FxGripExtIndividuatingExtension.alloc init];

	[ext extLoadWithIndex:1];

	XCTAssertEqual(ext.extKeyIndex, 1);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxGripExtIndividuatingExtension.class) stringByAppendingString:@"1"]);
}

- (void)testExtIndividuateDefaultsToNo
{
	XCTAssertFalse([FxGripExtensionBase.alloc init].extIndividuate);
	XCTAssertFalse([FxGripExtSilentExtension.alloc init].extIndividuate);
}

- (void)testExtLoadWithIndexReturnValueMatchesIncludeWhenDisabled
{
	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	XCTAssertEqual([ext extLoadWithIndex:3], ext.extIncludeWhenDisabled);
}

- (void)testExtLoadWithEffectIndexZeroKeepsBareKeyAndSetsEffect
{
	FxGripExtTestStubEffect *effect = [FxGripExtTestStubEffect.alloc init];
	effect.notifier = FxGripExtTestMakePriorityCenter();

	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect index:0]);

	XCTAssertEqual(ext.extKeyIndex, 0);
	XCTAssertEqualObjects(ext.extKey, NSStringFromClass(FxGripExtInitObservingExtension.class));
	XCTAssertEqualObjects((id)ext.effect, effect);
}

- (void)testExtLoadWithEffectNonzeroIndexAppendsIndexAndSetsEffect
{
	FxGripExtTestStubEffect *effect = [FxGripExtTestStubEffect.alloc init];
	effect.notifier = FxGripExtTestMakePriorityCenter();

	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect index:1]);

	XCTAssertEqual(ext.extKeyIndex, 1);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxGripExtInitObservingExtension.class) stringByAppendingString:@"1"]);
	XCTAssertEqualObjects((id)ext.effect, effect);
}

- (void)testTwoInstancesOfOneClassLoadAtDistinctKeys
{
	FxGripExtInitObservingExtension *first = [FxGripExtInitObservingExtension.alloc init];
	FxGripExtInitObservingExtension *second = [FxGripExtInitObservingExtension.alloc init];

	[first extLoadWithIndex:0];
	[second extLoadWithIndex:1];

	XCTAssertNotEqualObjects(first.extKey, second.extKey);

	NSMutableDictionary *extensions = [NSMutableDictionary dictionary];
	extensions[first.extKey] = first;
	extensions[second.extKey] = second;

	XCTAssertEqual(extensions.count, 2u, @"instances of one class must not overwrite each other in the effect's extension dictionary");
	XCTAssertEqualObjects(extensions[first.extKey], first);
	XCTAssertEqualObjects(extensions[second.extKey], second);
}

- (void)testExtLoadWithEffectRegistersObserverForImplementedSelector
{
	FxGripExtTestStubEffect *effect = [FxGripExtTestStubEffect.alloc init];
	effect.notifier = FxGripExtTestMakePriorityCenter();

	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect]);

	[effect.notifier postNotificationName:FxGripTileableEffectInitName object:effect userInfo:nil];

	XCTAssertTrue(ext.didReceiveInit);
}

- (void)testExtLoadWithEffectRegistersNoObserverWhenInactive
{
	FxGripExtTestStubEffect *effect = [FxGripExtTestStubEffect.alloc init];
	effect.notifier = FxGripExtTestMakePriorityCenter();

	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];
	[ext setExtActive:NO];
	[ext extLoadWithEffect:(id)effect];

	[effect.notifier postNotificationName:FxGripTileableEffectInitName object:effect userInfo:nil];

	XCTAssertFalse(ext.didReceiveInit, @"an inactive extension registers no observers");
}

- (void)testExtLoadWithEffectForExtensionWithoutSelectorsDoesNotCrash
{
	FxGripExtTestStubEffect *effect = [FxGripExtTestStubEffect.alloc init];
	effect.notifier = FxGripExtTestMakePriorityCenter();

	FxGripExtSilentExtension *ext = [FxGripExtSilentExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect]);

	XCTAssertNoThrow([effect.notifier postNotificationName:FxGripTileableEffectInitName object:effect userInfo:nil]);
}

- (void)testExtLoadWithEffectSetsEffect
{
	FxGripExtTestStubEffect *effect = [FxGripExtTestStubEffect.alloc init];
	effect.notifier = FxGripExtTestMakePriorityCenter();

	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	[ext extLoadWithEffect:(id)effect];

	XCTAssertEqualObjects((id)ext.effect, effect);
}

@end
