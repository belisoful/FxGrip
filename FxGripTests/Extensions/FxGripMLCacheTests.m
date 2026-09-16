/*!
	@file       FxGripMLCacheTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripMLCacheTests
	@abstract   Unit tests for the ML inference cache extension's parameter, frame data, and document load.
	@discussion Introduced in FxGrip 0.1.0. A stub retrieval API stands in for the host so the
	            document-load path resolves a stored FxGripFrameData, replaces the in-memory store
	            when the document carries one, and keeps the existing store when it does not. A real
	            effect that installs the extension covers the effect-side cache accessors.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripMLCache.h>
#import <FxGrip/FxGripImageBuffer.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Extensions.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>

// FxGripMLCache.h publishes the class without its notification handlers; the handlers the
// tests drive are declared here. The implementation comes from the linked framework.
@interface FxGripMLCache (FxGripMLCacheTestAccess)
- (void)extAddParameters:(nonnull NSNotification *)notification;
- (void)extAddedToDocument:(nonnull NSNotification *)notification;
@end

/*! Stands in for the host's custom-value readback. */
@interface FxGripMLCacheTestStubGetAPI : NSObject
@property (nonatomic, strong) NSObject<NSSecureCoding, NSCopying> *storedValue;
@property (nonatomic, assign) BOOL readSucceeds;
@property (nonatomic, assign) FxParameterId readParameter;
@end

@implementation FxGripMLCacheTestStubGetAPI

- (BOOL)getCustomParameterValue:(NSObject<NSSecureCoding, NSCopying> *_Nullable *_Nonnull)value
				  fromParameter:(UInt32)parameterID
						 atTime:(CMTime)time
{
	self.readParameter = parameterID;
	if (value) {
		*value = self.storedValue;
	}
	return self.readSucceeds;
}

@end

/*! Vends the stub retrieval API the extension reads the stored cache through. */
@interface FxGripMLCacheTestStubAPIManager : NSObject
@property (nonatomic, strong) FxGripMLCacheTestStubGetAPI *paramGetAPIv6;
@end

@implementation FxGripMLCacheTestStubAPIManager

- (instancetype)init
{
	self = [super init];
	if (self) {
		_paramGetAPIv6 = [FxGripMLCacheTestStubGetAPI.alloc init];
	}
	return self;
}

@end

/*! Stands in for the effect the extension binds to. */
@interface FxGripMLCacheTestStubEffect : NSObject
@property (nonatomic, strong, readonly) NSNotificationCenter *notifier;
@property (nonatomic, strong) FxGripMLCacheTestStubAPIManager *apiManager;
@end

@implementation FxGripMLCacheTestStubEffect

- (instancetype)init
{
	self = [super init];
	if (self) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_notifier = [[cls alloc] init];
		_apiManager = [FxGripMLCacheTestStubAPIManager.alloc init];
	}
	return self;
}

- (id)effectBase { return self; }

@end

/*! A real effect that installs the ML cache extension. */
@interface FxGripMLCacheTestHostEffect : FxGripTileableEffect
@end

@implementation FxGripMLCacheTestHostEffect

- (NSMutableArray<id<FxGripExtension>> *)loadExtensions
{
	NSMutableArray<id<FxGripExtension>> *extensions = [super loadExtensions];
	[extensions addObject:(id<FxGripExtension>)[self newMLCacheExtension]];
	return extensions;
}

@end

/*! A real effect that installs no ML cache extension. */
@interface FxGripMLCacheTestPlainEffect : FxGripTileableEffect
@end

@implementation FxGripMLCacheTestPlainEffect
@end

@interface FxGripMLCacheExtensionTests : XCTestCase
@property (nonatomic, strong) FxGripMLCache *extension;
@property (nonatomic, strong) FxGripMLCacheTestStubEffect *effect;
@end

@implementation FxGripMLCacheExtensionTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripMLCacheTestStubEffect.alloc init];
	self.extension = [FxGripMLCache.alloc init];
	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect]);
}

- (void)tearDown
{
	self.extension = nil;
	self.effect = nil;
	[super tearDown];
}

- (FxGripMLCacheTestStubGetAPI *)getAPI { return self.effect.apiManager.paramGetAPIv6; }

- (void)runAddedToDocument
{
	[self.extension extAddedToDocument:[NSNotification notificationWithName:FxGripTileableEffectAddedToDocumentName
																	 object:self.effect
																   userInfo:nil]];
}

#pragma mark Parameter registration

/*! @abstract The extension registers a hidden, stateless custom parameter under the ML cache ID. */
- (void)testTheExtensionRegistersAHiddenStatelessCustomParameter
{
	NSMutableArray<NSMutableDictionary *> *parameters = NSMutableArray.new;
	[self.extension extAddParameters:[NSNotification notificationWithName:FxGripTileableEffectAddParametersName
																   object:self.effect
																 userInfo:@{FxGripTileableEffectParametersKey: parameters}]];

	XCTAssertEqual(parameters.count, (NSUInteger)1);
	NSMutableDictionary *parameter = parameters.firstObject;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Id], @(kFxParameterId_MLCache));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], kFxParameterType_Custom);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Name], @"ML Cache");
	XCTAssertEqual((id)parameter[kFxParameterProperty_Factory], (id)self.extension);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Flags],
						  (@[kParameterFlagString_DONT_DISPLAY, kParameterFlagString_HIDDEN,
							 kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOVALUE,
							 kParameterFlagString_NO_DEBUG, kParameterFlagString_NO_STATE]));
}

/*! @abstract The extension takes the ML cache parameter ID at initialization. */
- (void)testTheExtensionTakesTheMLCacheParameterID
{
	XCTAssertEqual(self.extension.parameterID, (FxParameterId)kFxParameterId_MLCache);
}

/*! @abstract The accepted value classes cover the frame data, its image buffers, and its own parameter classes. */
- (void)testTheAcceptedValueClassesCoverTheFrameDataAndItsBuffers
{
	NSSet *classes = self.extension.dataClasses;

	XCTAssertTrue([classes containsObject:FxGripFrameData.class]);
	XCTAssertTrue([classes containsObject:FxGripImageBuffer.class]);
	for (Class dataClass in FxGripFrameData.classesForParameter) {
		XCTAssertTrue([classes containsObject:dataClass],
					  @"the frame data's own parameter class %@ is accepted too", dataClass);
	}
}

#pragma mark Frame data

/*! @abstract The frame data is created on demand and the same store is returned on every read. */
- (void)testTheFrameDataIsCreatedOnDemandAndKept
{
	FxGripFrameData *data = self.extension.frameData;

	XCTAssertNotNil(data);
	XCTAssertEqual(self.extension.frameData, data, @"the store is created once");
}

/*! @abstract A document load replaces the in-memory store with the frame data the document carries. */
- (void)testADocumentLoadAdoptsTheStoredFrameData
{
	FxGripFrameData *inMemory = self.extension.frameData;
	FxGripFrameData *stored = [FxGripFrameData.alloc init];
	self.getAPI.storedValue = stored;
	self.getAPI.readSucceeds = YES;

	[self runAddedToDocument];

	XCTAssertEqual(self.getAPI.readParameter, (FxParameterId)kFxParameterId_MLCache);
	XCTAssertEqual(self.extension.frameData, stored);
	XCTAssertNotEqual(self.extension.frameData, inMemory);
}

/*! @abstract A document carrying no frame data leaves the existing store in place. */
- (void)testADocumentWithoutFrameDataKeepsTheExistingStore
{
	FxGripFrameData *inMemory = self.extension.frameData;
	self.getAPI.storedValue = nil;

	[self runAddedToDocument];

	XCTAssertEqual(self.extension.frameData, inMemory);
}

/*! @abstract A document load before the store exists creates one rather than leaving it nil. */
- (void)testADocumentLoadBeforeAnyAccessCreatesTheStore
{
	self.getAPI.storedValue = (NSObject<NSSecureCoding, NSCopying> *)@"not frame data";

	[self runAddedToDocument];

	XCTAssertTrue([self.extension.frameData isKindOfClass:FxGripFrameData.class],
				  @"a value of the wrong class does not become the store");
}

#pragma mark The effect-side accessors

/*! @abstract An effect that installs the extension reports the cache and vends its frame data. */
- (void)testAnEffectThatInstallsTheExtensionVendsItsCache
{
	FxGripMLCacheTestHostEffect *effect = [FxGripMLCacheTestHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];

	XCTAssertTrue(effect.hasMLCache);
	XCTAssertNotNil(effect.mlCacheData);
	XCTAssertEqual(effect.mlCacheData,
				   ((FxGripMLCache *)[effect extensionForClass:FxGripMLCache.class]).frameData);
	XCTAssertTrue([[effect newMLCacheExtension] isKindOfClass:FxGripMLCache.class]);
}

/*! @abstract An effect that installs no cache extension reports none and vends no frame data. */
- (void)testAnEffectWithoutTheExtensionVendsNoCache
{
	FxGripMLCacheTestPlainEffect *effect = [FxGripMLCacheTestPlainEffect.alloc initWithAPIManager:(id _Nonnull)nil];

	XCTAssertFalse(effect.hasMLCache);
	XCTAssertNil(effect.mlCacheData);
}

@end
