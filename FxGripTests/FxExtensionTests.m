//
//  FxExtensionTests.m
//  FxGripTests
//
//  Unit tests for FxExtensionBase: initialization defaults, notification
//  priority, the setExtActive: guard, index/individuation behavior, and
//  observer registration performed by extLoadWithEffect:.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxExtension.h>
#import <FxGrip/FxTileableEffectBase+Notifications.h>

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
// BEFoundation is present in-process because the loaded FxGrip framework links it.
static NSNotificationCenter *FxExtTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

#pragma mark - Test doubles

// Minimal stand-in for an effect. FxExtensionBase only reads -notifier (during
// extLoadWithEffect:) and -addedToDocument (during setExtActive:), so the stub
// implements just those two and is passed where id<FxTileableEffectBase> is expected.
@interface FxExtTestStubEffect : NSObject
@property (nonatomic, assign) BOOL addedToDocument;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@end

@implementation FxExtTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

@end

// Extension that observes FxTileableEffectInitName. extLoadWithEffect: registers
// an observer for -extInit: only because this subclass implements it.
@interface FxExtInitObservingExtension : FxExtensionBase
@property (nonatomic, assign) BOOL didReceiveInit;
@property (nonatomic, strong) NSNotification *lastInitNotification;
@end

@implementation FxExtInitObservingExtension
- (void)extInit:(NSNotification *)notification
{
	self.didReceiveInit = YES;
	self.lastInitNotification = notification;
}
@end

// Extension implementing none of the ext* selectors; extLoadWithEffect: must
// register no observers and posting must not reach it or crash.
@interface FxExtSilentExtension : FxExtensionBase
@end

@implementation FxExtSilentExtension
@end

// Extension that overrides the individuation getter so its key always carries the
// load index, including the index-zero first instance.
@interface FxExtIndividuatingExtension : FxExtensionBase
@end

@implementation FxExtIndividuatingExtension
- (BOOL)extIndividuate
{
	return YES;
}
@end

#pragma mark - Tests

@interface FxExtensionTests : XCTestCase
@end

@implementation FxExtensionTests

- (void)testInitReturnsNonNilInstance
{
	FxExtensionBase *ext = [FxExtensionBase.alloc init];
	XCTAssertNotNil(ext);
}

- (void)testInitDefaults
{
	FxExtensionBase *ext = [FxExtensionBase.alloc init];

	XCTAssertTrue(ext.extActive);
	XCTAssertEqual(ext.extKeyIndex, -1);
	XCTAssertEqualObjects(ext.extKey, NSStringFromClass(FxExtensionBase.class));
	XCTAssertEqual(ext.extDefaultPriority, FxExtensionDefaultPriority);
	XCTAssertFalse(ext.extIncludeWhenDisabled);
	XCTAssertFalse(ext.extIndividuate);
}

- (void)testExtKeyDefaultsToConcreteSubclassName
{
	FxExtInitObservingExtension *ext = [FxExtInitObservingExtension.alloc init];
	XCTAssertEqualObjects(ext.extKey, NSStringFromClass(FxExtInitObservingExtension.class));
}

- (void)testNcPriorityReturnsDefaultPriority
{
	FxExtensionBase *ext = [FxExtensionBase.alloc init];
	XCTAssertEqual([ext ncPriority:nil], FxExtensionDefaultPriority);
	XCTAssertEqual([ext ncPriority:FxTileableEffectInitName], FxExtensionDefaultPriority);
}

- (void)testNcPriorityTracksChangedDefaultPriority
{
	FxExtensionBase *ext = [FxExtensionBase.alloc init];
	ext.extDefaultPriority = -18;
	XCTAssertEqual([ext ncPriority:nil], -18);

	ext.extDefaultPriority = 20;
	XCTAssertEqual([ext ncPriority:FxTileableEffectFlushName], 20);
}

- (void)testSetExtActiveTogglesWithNoEffectLoaded
{
	FxExtensionBase *ext = [FxExtensionBase.alloc init];

	[ext setExtActive:NO];
	XCTAssertFalse(ext.extActive);

	[ext setExtActive:YES];
	XCTAssertTrue(ext.extActive);
}

- (void)testSetExtActiveSucceedsWhenEffectNotYetAddedToDocument
{
	FxExtTestStubEffect *effect = [FxExtTestStubEffect.alloc init];
	effect.notifier = FxExtTestMakePriorityCenter();
	effect.addedToDocument = NO;

	FxExtensionBase *ext = [FxExtensionBase.alloc init];
	[ext extLoadWithEffect:(id)effect];

	[ext setExtActive:NO];
	XCTAssertFalse(ext.extActive);
}

- (void)testSetExtActiveRejectedAfterEffectAddedToDocument
{
	FxExtTestStubEffect *effect = [FxExtTestStubEffect.alloc init];
	effect.notifier = FxExtTestMakePriorityCenter();
	effect.addedToDocument = YES;

	FxExtensionBase *ext = [FxExtensionBase.alloc init];
	[ext extLoadWithEffect:(id)effect];

	[ext setExtActive:NO];
	XCTAssertTrue(ext.extActive, @"setExtActive: must be ignored once the effect is added to the document");
}

- (void)testExtLoadWithIndexStoresIndexAndAppendsItWithoutIndividuation
{
	FxExtInitObservingExtension *ext = [FxExtInitObservingExtension.alloc init];
	NSString *keyBeforeLoad = ext.extKey;

	[ext extLoadWithIndex:7];

	XCTAssertEqual(ext.extKeyIndex, 7);
	// A nonzero index suffixes the key whatever extIndividuate reports.
	XCTAssertFalse(ext.extIndividuate);
	XCTAssertEqualObjects(ext.extKey, [keyBeforeLoad stringByAppendingString:@"7"]);
}

- (void)testExtLoadWithIndexZeroKeepsBareClassNameByDefault
{
	FxExtInitObservingExtension *ext = [FxExtInitObservingExtension.alloc init];

	[ext extLoadWithIndex:0];

	XCTAssertEqual(ext.extKeyIndex, 0);
	XCTAssertEqualObjects(ext.extKey, NSStringFromClass(FxExtInitObservingExtension.class));
}

- (void)testExtLoadWithIndexOneAppendsIndexToKey
{
	FxExtInitObservingExtension *ext = [FxExtInitObservingExtension.alloc init];

	[ext extLoadWithIndex:1];

	XCTAssertEqual(ext.extKeyIndex, 1);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxExtInitObservingExtension.class) stringByAppendingString:@"1"]);
}

- (void)testExtLoadWithIndexTwoAppendsIndexToKey
{
	FxExtInitObservingExtension *ext = [FxExtInitObservingExtension.alloc init];

	[ext extLoadWithIndex:2];

	XCTAssertEqual(ext.extKeyIndex, 2);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxExtInitObservingExtension.class) stringByAppendingString:@"2"]);
}

- (void)testIndividuatingExtensionAppendsZeroIndexToKey
{
	FxExtIndividuatingExtension *ext = [FxExtIndividuatingExtension.alloc init];
	XCTAssertTrue(ext.extIndividuate);

	[ext extLoadWithIndex:0];

	XCTAssertEqual(ext.extKeyIndex, 0);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxExtIndividuatingExtension.class) stringByAppendingString:@"0"]);
}

- (void)testIndividuatingExtensionAppendsNonzeroIndexOnce
{
	FxExtIndividuatingExtension *ext = [FxExtIndividuatingExtension.alloc init];

	[ext extLoadWithIndex:1];

	XCTAssertEqual(ext.extKeyIndex, 1);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxExtIndividuatingExtension.class) stringByAppendingString:@"1"]);
}

- (void)testExtIndividuateDefaultsToNo
{
	XCTAssertFalse([FxExtensionBase.alloc init].extIndividuate);
	XCTAssertFalse([FxExtSilentExtension.alloc init].extIndividuate);
}

- (void)testExtLoadWithIndexReturnValueMatchesIncludeWhenDisabled
{
	FxExtensionBase *ext = [FxExtensionBase.alloc init];
	XCTAssertEqual([ext extLoadWithIndex:3], ext.extIncludeWhenDisabled);
}

- (void)testExtLoadWithEffectIndexZeroKeepsBareKeyAndSetsEffect
{
	FxExtTestStubEffect *effect = [FxExtTestStubEffect.alloc init];
	effect.notifier = FxExtTestMakePriorityCenter();

	FxExtInitObservingExtension *ext = [FxExtInitObservingExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect index:0]);

	XCTAssertEqual(ext.extKeyIndex, 0);
	XCTAssertEqualObjects(ext.extKey, NSStringFromClass(FxExtInitObservingExtension.class));
	XCTAssertEqualObjects((id)ext.effect, effect);
}

- (void)testExtLoadWithEffectNonzeroIndexAppendsIndexAndSetsEffect
{
	FxExtTestStubEffect *effect = [FxExtTestStubEffect.alloc init];
	effect.notifier = FxExtTestMakePriorityCenter();

	FxExtInitObservingExtension *ext = [FxExtInitObservingExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect index:1]);

	XCTAssertEqual(ext.extKeyIndex, 1);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxExtInitObservingExtension.class) stringByAppendingString:@"1"]);
	XCTAssertEqualObjects((id)ext.effect, effect);
}

- (void)testTwoInstancesOfOneClassLoadAtDistinctKeys
{
	FxExtInitObservingExtension *first = [FxExtInitObservingExtension.alloc init];
	FxExtInitObservingExtension *second = [FxExtInitObservingExtension.alloc init];

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
	FxExtTestStubEffect *effect = [FxExtTestStubEffect.alloc init];
	effect.notifier = FxExtTestMakePriorityCenter();

	FxExtInitObservingExtension *ext = [FxExtInitObservingExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect]);

	[effect.notifier postNotificationName:FxTileableEffectInitName object:effect userInfo:nil];

	XCTAssertTrue(ext.didReceiveInit);
}

- (void)testExtLoadWithEffectRegistersNoObserverWhenInactive
{
	FxExtTestStubEffect *effect = [FxExtTestStubEffect.alloc init];
	effect.notifier = FxExtTestMakePriorityCenter();

	FxExtInitObservingExtension *ext = [FxExtInitObservingExtension.alloc init];
	[ext setExtActive:NO];
	[ext extLoadWithEffect:(id)effect];

	[effect.notifier postNotificationName:FxTileableEffectInitName object:effect userInfo:nil];

	XCTAssertFalse(ext.didReceiveInit, @"an inactive extension registers no observers");
}

- (void)testExtLoadWithEffectForExtensionWithoutSelectorsDoesNotCrash
{
	FxExtTestStubEffect *effect = [FxExtTestStubEffect.alloc init];
	effect.notifier = FxExtTestMakePriorityCenter();

	FxExtSilentExtension *ext = [FxExtSilentExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect]);

	XCTAssertNoThrow([effect.notifier postNotificationName:FxTileableEffectInitName object:effect userInfo:nil]);
}

- (void)testExtLoadWithEffectSetsEffect
{
	FxExtTestStubEffect *effect = [FxExtTestStubEffect.alloc init];
	effect.notifier = FxExtTestMakePriorityCenter();

	FxExtensionBase *ext = [FxExtensionBase.alloc init];
	[ext extLoadWithEffect:(id)effect];

	XCTAssertEqualObjects((id)ext.effect, effect);
}

@end
