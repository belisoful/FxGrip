//
//  FxTileableEffectNotificationTests.m
//  FxGripTests
//
//  Unit tests for the FxTileableEffect notification contract: the name/key
//  constants and the userInfo payload shape carried by the parameter-changed
//  notification.
//

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxExtension.h>
#import <FxGrip/FxTileableEffectBase+Notifications.h>

// The test target links only FxGrip and XCTest. NSPriorityNotificationCenter
// (BEFoundation) and the CoreMedia CMTime<->dictionary functions live in
// frameworks the test bundle does not link, but are loaded in-process through
// FxGrip. They are reached by name at runtime to avoid unlinked symbols.

static NSNotificationCenter *FxNotifTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

typedef CFDictionaryRef (*FxCMTimeCopyAsDictionaryFn)(CMTime, CFAllocatorRef);
typedef CMTime (*FxCMTimeMakeFromDictionaryFn)(CFDictionaryRef);

static NSDictionary *FxNotifTestTimeToDictionary(CMTime time)
{
	FxCMTimeCopyAsDictionaryFn fn = (FxCMTimeCopyAsDictionaryFn)dlsym(RTLD_DEFAULT, "CMTimeCopyAsDictionary");
	NSCAssert(fn != NULL, @"CoreMedia CMTimeCopyAsDictionary must be resolvable in-process");
	return (__bridge_transfer NSDictionary *)fn(time, kCFAllocatorDefault);
}

static CMTime FxNotifTestTimeFromDictionary(NSDictionary *dict)
{
	FxCMTimeMakeFromDictionaryFn fn = (FxCMTimeMakeFromDictionaryFn)dlsym(RTLD_DEFAULT, "CMTimeMakeFromDictionary");
	NSCAssert(fn != NULL, @"CoreMedia CMTimeMakeFromDictionary must be resolvable in-process");
	return fn((__bridge CFDictionaryRef)dict);
}

// Field comparison avoids linking CMTimeCompare; the tests use identical
// timescales so no normalization is required.
static BOOL FxNotifTestTimesEqual(CMTime a, CMTime b)
{
	return a.value == b.value && a.timescale == b.timescale && a.flags == b.flags && a.epoch == b.epoch;
}

static CMTime FxNotifTestMakeTime(int64_t value, int32_t timescale)
{
	CMTime t = { .value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0 };
	return t;
}

#pragma mark - Test doubles

@interface FxNotifTestStubEffect : NSObject
@property (nonatomic, assign) BOOL addedToDocument;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@end

@implementation FxNotifTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

@end

// Extension that captures the userInfo delivered to -extParameterChanged:.
@interface FxNotifParamChangeExtension : FxExtensionBase
@property (nonatomic, strong) NSDictionary *lastUserInfo;
@end

@implementation FxNotifParamChangeExtension
- (void)extParameterChanged:(NSNotification *)notification
{
	self.lastUserInfo = notification.userInfo;
}
@end

#pragma mark - Tests

@interface FxTileableEffectNotificationTests : XCTestCase
@end

@implementation FxTileableEffectNotificationTests

- (NSArray<NSString *> *)allNotificationConstants
{
	return @[
		FxTileableEffectLoadName,
		FxTileableEffectInitName,
		FxTileableEffectInitAPIManagerKey,
		FxTileableEffectPropertiesName,
		FxTileableEffectPropertiesKey,
		FxTileableEffectAddParametersName,
		FxTileableEffectParametersKey,
		FxTileableEffectFinishInitialSetupName,
		FxTileableEffectAddedToDocumentName,
		FxTileableEffectParameterChangedName,
		FxTileableEffectParameterChangedIDKey,
		FxTileableEffectParameterChangedAtTimeKey,
		FxTileableEffectFlushName,
		FxTileableEffectPluginStateName,
		FxTileableEffectPluginStateCoderKey,
		FxTileableEffectDestinationImageRectName,
		FxTileableEffectSourceTileRectName,
		FxTileableEffectScheduleInputsName,
		FxTileableEffectRenderDestinationImageName,
		FxTileableEffectRenderDestinationImageKey,
		FxTileableEffectRenderSourceImagesKey,
		FxTileableEffectRenderAtTimeKey,
		FxTileableEffectRemovedFromDocumentName,
		FxTileableEffectUnloadName,
	];
}

- (void)testNotificationConstantsAreNonNilAndNonEmpty
{
	for (NSString *constant in [self allNotificationConstants]) {
		XCTAssertNotNil(constant);
		XCTAssertGreaterThan(constant.length, (NSUInteger)0);
	}
}

- (void)testNotificationConstantsAreMutuallyDistinct
{
	NSArray<NSString *> *constants = [self allNotificationConstants];
	NSSet<NSString *> *unique = [NSSet setWithArray:constants];
	XCTAssertEqual(unique.count, constants.count, @"notification names and keys must not collide");
}

- (void)testParameterChangedPayloadRoundTripThroughPriorityCenter
{
	NSNotificationCenter *center = FxNotifTestMakePriorityCenter();
	id sender = [NSObject.alloc init];

	CMTime time = FxNotifTestMakeTime(1001, 30000);
	NSNumber *paramID = @(4207u);
	NSDictionary *timeDict = FxNotifTestTimeToDictionary(time);

	__block NSNumber *receivedID = nil;
	__block CMTime receivedTime = FxNotifTestMakeTime(0, 1);
	__block BOOL received = NO;

	id token = [center addObserverForName:FxTileableEffectParameterChangedName
								   object:sender
									queue:nil
							   usingBlock:^(NSNotification *note) {
		received = YES;
		receivedID = note.userInfo[FxTileableEffectParameterChangedIDKey];
		receivedTime = FxNotifTestTimeFromDictionary(note.userInfo[FxTileableEffectParameterChangedAtTimeKey]);
	}];

	[center postNotificationName:FxTileableEffectParameterChangedName
						  object:sender
						userInfo:@{
							FxTileableEffectParameterChangedIDKey: paramID,
							FxTileableEffectParameterChangedAtTimeKey: timeDict,
						}];

	XCTAssertTrue(received);
	XCTAssertEqualObjects(receivedID, paramID);
	XCTAssertTrue(FxNotifTestTimesEqual(receivedTime, time));

	[center removeObserver:token];
}

- (void)testParameterChangedPayloadDeliveredToExtensionObserver
{
	FxNotifTestStubEffect *effect = [FxNotifTestStubEffect.alloc init];
	effect.notifier = FxNotifTestMakePriorityCenter();

	FxNotifParamChangeExtension *ext = [FxNotifParamChangeExtension.alloc init];
	[ext extLoadWithEffect:(id)effect];

	CMTime time = FxNotifTestMakeTime(5, 24);
	NSNumber *paramID = @(88u);
	NSDictionary *timeDict = FxNotifTestTimeToDictionary(time);

	[effect.notifier postNotificationName:FxTileableEffectParameterChangedName
								  object:effect
								userInfo:@{
									FxTileableEffectParameterChangedIDKey: paramID,
									FxTileableEffectParameterChangedAtTimeKey: timeDict,
								}];

	XCTAssertNotNil(ext.lastUserInfo);
	XCTAssertEqualObjects(ext.lastUserInfo[FxTileableEffectParameterChangedIDKey], paramID);

	CMTime recovered = FxNotifTestTimeFromDictionary(ext.lastUserInfo[FxTileableEffectParameterChangedAtTimeKey]);
	XCTAssertTrue(FxNotifTestTimesEqual(recovered, time));
}

- (void)testRenderNotificationKeysAreDistinctFromParameterKeys
{
	NSArray<NSString *> *renderKeys = @[
		FxTileableEffectRenderDestinationImageKey,
		FxTileableEffectRenderSourceImagesKey,
		FxTileableEffectRenderAtTimeKey,
	];
	NSArray<NSString *> *paramKeys = @[
		FxTileableEffectParameterChangedIDKey,
		FxTileableEffectParameterChangedAtTimeKey,
	];

	for (NSString *renderKey in renderKeys) {
		XCTAssertFalse([paramKeys containsObject:renderKey]);
	}
}

@end
