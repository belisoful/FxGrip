/*!
	@file       FxGripTileableEffectNotificationTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffectNotificationTests
	@abstract   Unit tests for the FxTileableEffect notification name and key constants and the parameter-changed payload.
	@discussion Introduced in FxGrip 0.1.0. The tests assert that every notification name and userInfo key constant is non-empty and mutually distinct. They deliver a parameter-changed notification through a private priority notification center and confirm the id and CMTime payload round-trips to a direct observer and to an extension observer.
*/

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>

// The test target links only FxGrip and XCTest. NSPriorityNotificationCenter
// (BEFoundation) and the CoreMedia CMTime<->dictionary functions live in
// frameworks the test bundle does not link, but are loaded in-process through
// FxGrip. They are reached by name at runtime to avoid unlinked symbols.

static NSNotificationCenter *FxGripNotifTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

typedef CFDictionaryRef (*FxGripCMTimeCopyAsDictionaryFn)(CMTime, CFAllocatorRef);
typedef CMTime (*FxGripCMTimeMakeFromDictionaryFn)(CFDictionaryRef);

static NSDictionary *FxGripNotifTestTimeToDictionary(CMTime time)
{
	FxGripCMTimeCopyAsDictionaryFn fn = (FxGripCMTimeCopyAsDictionaryFn)dlsym(RTLD_DEFAULT, "CMTimeCopyAsDictionary");
	NSCAssert(fn != NULL, @"CoreMedia CMTimeCopyAsDictionary must be resolvable in-process");
	return (__bridge_transfer NSDictionary *)fn(time, kCFAllocatorDefault);
}

static CMTime FxGripNotifTestTimeFromDictionary(NSDictionary *dict)
{
	FxGripCMTimeMakeFromDictionaryFn fn = (FxGripCMTimeMakeFromDictionaryFn)dlsym(RTLD_DEFAULT, "CMTimeMakeFromDictionary");
	NSCAssert(fn != NULL, @"CoreMedia CMTimeMakeFromDictionary must be resolvable in-process");
	return fn((__bridge CFDictionaryRef)dict);
}

// Field comparison avoids linking CMTimeCompare; the tests use identical
// timescales so no normalization is required.
static BOOL FxGripNotifTestTimesEqual(CMTime a, CMTime b)
{
	return a.value == b.value && a.timescale == b.timescale && a.flags == b.flags && a.epoch == b.epoch;
}

static CMTime FxGripNotifTestMakeTime(int64_t value, int32_t timescale)
{
	CMTime t = { .value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0 };
	return t;
}

#pragma mark - Test doubles

@interface FxGripNotifTestStubEffect : NSObject
@property (nonatomic, assign) BOOL addedToDocument;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@end

@implementation FxGripNotifTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

@end

// Extension that captures the userInfo delivered to -extParameterChanged:.
@interface FxGripNotifParamChangeExtension : FxGripExtensionBase
@property (nonatomic, strong) NSDictionary *lastUserInfo;
@end

@implementation FxGripNotifParamChangeExtension
- (void)extParameterChanged:(NSNotification *)notification
{
	self.lastUserInfo = notification.userInfo;
}
@end

#pragma mark - Tests

@interface FxGripTileableEffectNotificationTests : XCTestCase
@end

@implementation FxGripTileableEffectNotificationTests

- (NSArray<NSString *> *)allNotificationConstants
{
	return @[
		FxGripTileableEffectLoadName,
		FxGripTileableEffectInitName,
		FxGripTileableEffectInitAPIManagerKey,
		FxGripTileableEffectPropertiesName,
		FxGripTileableEffectPropertiesKey,
		FxGripTileableEffectAddParametersName,
		FxGripTileableEffectParametersKey,
		FxGripTileableEffectFinishInitialSetupName,
		FxGripTileableEffectAddedToDocumentName,
		FxGripTileableEffectParameterChangedName,
		FxGripTileableEffectParameterChangedIDKey,
		FxGripTileableEffectParameterChangedAtTimeKey,
		FxGripTileableEffectFlushName,
		FxGripTileableEffectPluginStateName,
		FxGripTileableEffectPluginStateCoderKey,
		FxGripTileableEffectDestinationImageRectName,
		FxGripTileableEffectSourceTileRectName,
		FxGripTileableEffectScheduleInputsName,
		FxGripTileableEffectRenderDestinationImageName,
		FxGripTileableEffectRenderDestinationImageKey,
		FxGripTileableEffectRenderSourceImagesKey,
		FxGripTileableEffectRenderAtTimeKey,
		FxGripTileableEffectRemovedFromDocumentName,
		FxGripTileableEffectUnloadName,
	];
}

/*! @abstract Every notification name and key constant is non-nil and non-empty. */
- (void)testNotificationConstantsAreNonNilAndNonEmpty
{
	for (NSString *constant in [self allNotificationConstants]) {
		XCTAssertNotNil(constant);
		XCTAssertGreaterThan(constant.length, (NSUInteger)0);
	}
}

/*! @abstract The notification name and key constants hold mutually distinct values with no collisions. */
- (void)testNotificationConstantsAreMutuallyDistinct
{
	NSArray<NSString *> *constants = [self allNotificationConstants];
	NSSet<NSString *> *unique = [NSSet setWithArray:constants];
	XCTAssertEqual(unique.count, constants.count, @"notification names and keys must not collide");
}

/*! @abstract A parameter-changed notification posted through a priority center delivers its id and CMTime payload unchanged to a block observer. */
- (void)testParameterChangedPayloadRoundTripThroughPriorityCenter
{
	NSNotificationCenter *center = FxGripNotifTestMakePriorityCenter();
	id sender = [NSObject.alloc init];

	CMTime time = FxGripNotifTestMakeTime(1001, 30000);
	NSNumber *paramID = @(4207u);
	NSDictionary *timeDict = FxGripNotifTestTimeToDictionary(time);

	__block NSNumber *receivedID = nil;
	__block CMTime receivedTime = FxGripNotifTestMakeTime(0, 1);
	__block BOOL received = NO;

	id token = [center addObserverForName:FxGripTileableEffectParameterChangedName
								   object:sender
									queue:nil
							   usingBlock:^(NSNotification *note) {
		received = YES;
		receivedID = note.userInfo[FxGripTileableEffectParameterChangedIDKey];
		receivedTime = FxGripNotifTestTimeFromDictionary(note.userInfo[FxGripTileableEffectParameterChangedAtTimeKey]);
	}];

	[center postNotificationName:FxGripTileableEffectParameterChangedName
						  object:sender
						userInfo:@{
							FxGripTileableEffectParameterChangedIDKey: paramID,
							FxGripTileableEffectParameterChangedAtTimeKey: timeDict,
						}];

	XCTAssertTrue(received);
	XCTAssertEqualObjects(receivedID, paramID);
	XCTAssertTrue(FxGripNotifTestTimesEqual(receivedTime, time));

	[center removeObserver:token];
}

/*! @abstract A parameter-changed notification reaches a loaded extension's extParameterChanged: with its id and CMTime payload intact. */
- (void)testParameterChangedPayloadDeliveredToExtensionObserver
{
	FxGripNotifTestStubEffect *effect = [FxGripNotifTestStubEffect.alloc init];
	effect.notifier = FxGripNotifTestMakePriorityCenter();

	FxGripNotifParamChangeExtension *ext = [FxGripNotifParamChangeExtension.alloc init];
	[ext extLoadWithEffect:(id)effect];

	CMTime time = FxGripNotifTestMakeTime(5, 24);
	NSNumber *paramID = @(88u);
	NSDictionary *timeDict = FxGripNotifTestTimeToDictionary(time);

	[effect.notifier postNotificationName:FxGripTileableEffectParameterChangedName
								  object:effect
								userInfo:@{
									FxGripTileableEffectParameterChangedIDKey: paramID,
									FxGripTileableEffectParameterChangedAtTimeKey: timeDict,
								}];

	XCTAssertNotNil(ext.lastUserInfo);
	XCTAssertEqualObjects(ext.lastUserInfo[FxGripTileableEffectParameterChangedIDKey], paramID);

	CMTime recovered = FxGripNotifTestTimeFromDictionary(ext.lastUserInfo[FxGripTileableEffectParameterChangedAtTimeKey]);
	XCTAssertTrue(FxGripNotifTestTimesEqual(recovered, time));
}

/*! @abstract The render notification userInfo keys are distinct from the parameter-changed keys. */
- (void)testRenderNotificationKeysAreDistinctFromParameterKeys
{
	NSArray<NSString *> *renderKeys = @[
		FxGripTileableEffectRenderDestinationImageKey,
		FxGripTileableEffectRenderSourceImagesKey,
		FxGripTileableEffectRenderAtTimeKey,
	];
	NSArray<NSString *> *paramKeys = @[
		FxGripTileableEffectParameterChangedIDKey,
		FxGripTileableEffectParameterChangedAtTimeKey,
	];

	for (NSString *renderKey in renderKeys) {
		XCTAssertFalse([paramKeys containsObject:renderKey]);
	}
}

@end
