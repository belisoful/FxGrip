/*!
	@file       FxGripExtensionTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripExtensionTests
	@abstract   Tests FxGripExtensionBase initialization, priority, activation gating, keying, and observer registration.
	@discussion Introduced in FxGrip 0.1.0. Stub effects and observing subclasses exercise the base class in isolation.
	            The tests cover default state, notification priority, the setExtActive: document guard, index and
	            individuation keying, and the selective observer registration extLoadWithEffect: performs.
*/

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

/*! @abstract Verifies the base extension allocates and initializes to a non-nil instance. */
- (void)testInitReturnsNonNilInstance
{
	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	XCTAssertNotNil(ext);
}

/*! @abstract Verifies a fresh extension is active, has key index -1, keys to its class name, carries the default priority, and disables include-when-disabled and individuation. */
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

/*! @abstract Verifies the default key is the concrete subclass name. */
- (void)testExtKeyDefaultsToConcreteSubclassName
{
	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];
	XCTAssertEqualObjects(ext.extKey, NSStringFromClass(FxGripExtInitObservingExtension.class));
}

/*! @abstract Verifies ncPriority: returns the default priority for a nil name and for a known notification name. */
- (void)testNcPriorityReturnsDefaultPriority
{
	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	XCTAssertEqual([ext ncPriority:nil], FxGripExtensionDefaultPriority);
	XCTAssertEqual([ext ncPriority:FxGripTileableEffectInitName], FxGripExtensionDefaultPriority);
}

/*! @abstract Verifies ncPriority: reflects a changed extDefaultPriority value. */
- (void)testNcPriorityTracksChangedDefaultPriority
{
	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	ext.extDefaultPriority = -18;
	XCTAssertEqual([ext ncPriority:nil], -18);

	ext.extDefaultPriority = 20;
	XCTAssertEqual([ext ncPriority:FxGripTileableEffectFlushName], 20);
}

/*! @abstract Verifies setExtActive: toggles the flag both ways when no effect is loaded. */
- (void)testSetExtActiveTogglesWithNoEffectLoaded
{
	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];

	[ext setExtActive:NO];
	XCTAssertFalse(ext.extActive);

	[ext setExtActive:YES];
	XCTAssertTrue(ext.extActive);
}

/*! @abstract Verifies setExtActive: still applies while the loaded effect is not yet added to the document. */
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

/*! @abstract Verifies setExtActive: is ignored once the loaded effect is added to the document. */
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

/*! @abstract Verifies a nonzero load index is stored and appended to the key even when individuation is off. */
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

/*! @abstract Verifies load index zero stores the index but leaves the key as the bare class name by default. */
- (void)testExtLoadWithIndexZeroKeepsBareClassNameByDefault
{
	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];

	[ext extLoadWithIndex:0];

	XCTAssertEqual(ext.extKeyIndex, 0);
	XCTAssertEqualObjects(ext.extKey, NSStringFromClass(FxGripExtInitObservingExtension.class));
}

/*! @abstract Verifies load index one appends "1" to the key. */
- (void)testExtLoadWithIndexOneAppendsIndexToKey
{
	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];

	[ext extLoadWithIndex:1];

	XCTAssertEqual(ext.extKeyIndex, 1);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxGripExtInitObservingExtension.class) stringByAppendingString:@"1"]);
}

/*! @abstract Verifies load index two appends "2" to the key. */
- (void)testExtLoadWithIndexTwoAppendsIndexToKey
{
	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];

	[ext extLoadWithIndex:2];

	XCTAssertEqual(ext.extKeyIndex, 2);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxGripExtInitObservingExtension.class) stringByAppendingString:@"2"]);
}

/*! @abstract Verifies an individuating extension appends the index even at index zero. */
- (void)testIndividuatingExtensionAppendsZeroIndexToKey
{
	FxGripExtIndividuatingExtension *ext = [FxGripExtIndividuatingExtension.alloc init];
	XCTAssertTrue(ext.extIndividuate);

	[ext extLoadWithIndex:0];

	XCTAssertEqual(ext.extKeyIndex, 0);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxGripExtIndividuatingExtension.class) stringByAppendingString:@"0"]);
}

/*! @abstract Verifies an individuating extension appends a nonzero index a single time. */
- (void)testIndividuatingExtensionAppendsNonzeroIndexOnce
{
	FxGripExtIndividuatingExtension *ext = [FxGripExtIndividuatingExtension.alloc init];

	[ext extLoadWithIndex:1];

	XCTAssertEqual(ext.extKeyIndex, 1);
	XCTAssertEqualObjects(ext.extKey, [NSStringFromClass(FxGripExtIndividuatingExtension.class) stringByAppendingString:@"1"]);
}

/*! @abstract Verifies extIndividuate defaults to NO on the base class and on a plain subclass. */
- (void)testExtIndividuateDefaultsToNo
{
	XCTAssertFalse([FxGripExtensionBase.alloc init].extIndividuate);
	XCTAssertFalse([FxGripExtSilentExtension.alloc init].extIndividuate);
}

/*! @abstract Verifies extLoadWithIndex: returns the extIncludeWhenDisabled value. */
- (void)testExtLoadWithIndexReturnValueMatchesIncludeWhenDisabled
{
	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	XCTAssertEqual([ext extLoadWithIndex:3], ext.extIncludeWhenDisabled);
}

/*! @abstract Verifies extLoadWithEffect:index: at index zero keeps the bare key and stores the effect. */
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

/*! @abstract Verifies extLoadWithEffect:index: at a nonzero index appends the index and stores the effect. */
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

/*! @abstract Verifies two instances of one class load at distinct keys so neither overwrites the other in the extension dictionary. */
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

/*! @abstract Verifies extLoadWithEffect: registers an observer for extInit: so the posted init notification reaches the extension. */
- (void)testExtLoadWithEffectRegistersObserverForImplementedSelector
{
	FxGripExtTestStubEffect *effect = [FxGripExtTestStubEffect.alloc init];
	effect.notifier = FxGripExtTestMakePriorityCenter();

	FxGripExtInitObservingExtension *ext = [FxGripExtInitObservingExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect]);

	[effect.notifier postNotificationName:FxGripTileableEffectInitName object:effect userInfo:nil];

	XCTAssertTrue(ext.didReceiveInit);
}

/*! @abstract Verifies an inactive extension registers no observers, so the posted init notification does not reach it. */
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

/*! @abstract Verifies loading an extension that implements no ext* selectors registers nothing and posting does not throw. */
- (void)testExtLoadWithEffectForExtensionWithoutSelectorsDoesNotCrash
{
	FxGripExtTestStubEffect *effect = [FxGripExtTestStubEffect.alloc init];
	effect.notifier = FxGripExtTestMakePriorityCenter();

	FxGripExtSilentExtension *ext = [FxGripExtSilentExtension.alloc init];
	XCTAssertTrue([ext extLoadWithEffect:(id)effect]);

	XCTAssertNoThrow([effect.notifier postNotificationName:FxGripTileableEffectInitName object:effect userInfo:nil]);
}

/*! @abstract Verifies extLoadWithEffect: stores the effect on the extension. */
- (void)testExtLoadWithEffectSetsEffect
{
	FxGripExtTestStubEffect *effect = [FxGripExtTestStubEffect.alloc init];
	effect.notifier = FxGripExtTestMakePriorityCenter();

	FxGripExtensionBase *ext = [FxGripExtensionBase.alloc init];
	[ext extLoadWithEffect:(id)effect];

	XCTAssertEqualObjects((id)ext.effect, effect);
}

@end
