/*!
	@file       FxGripAnalysisTests.m
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripAnalysisTests
	@abstract   Unit tests for the analysis storage extension's parameter registration and document load.
	@discussion Introduced in FxGrip 0.1.0. A stub retrieval API stands in for the host so the
	            document-load path resolves a stored FxGripFrameData, adopts it when the document
	            carries one, and keeps the existing store when it does not. The accepted value
	            classes and the hidden AnalysisData parameter are covered against the same stub.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripAnalysis.h>
#import <FxGrip/FxGripImageBuffer.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>

// FxGripAnalysis.h publishes the class without its notification handlers; the handlers the
// tests drive are declared here. The implementation comes from the linked framework.
@interface FxGripAnalysis (FxGripAnalysisTestAccess)
- (void)extAddParameters:(nonnull NSNotification *)notification;
- (void)extAddedToDocument:(nonnull NSNotification *)notification;
@end

/*! Stands in for the host's custom-value readback. */
@interface FxGripAnalysisTestStubGetAPI : NSObject
@property (nonatomic, strong) NSObject<NSSecureCoding, NSCopying> *storedValue;
@property (nonatomic, assign) BOOL readSucceeds;
@property (nonatomic, assign) FxParameterId readParameter;
@end

@implementation FxGripAnalysisTestStubGetAPI

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

/*! Vends the stub retrieval API the extension reads the stored analysis store through. */
@interface FxGripAnalysisTestStubAPIManager : NSObject
@property (nonatomic, strong) FxGripAnalysisTestStubGetAPI *paramGetAPIv6;
@end

@implementation FxGripAnalysisTestStubAPIManager

- (instancetype)init
{
	self = [super init];
	if (self) {
		_paramGetAPIv6 = [FxGripAnalysisTestStubGetAPI.alloc init];
	}
	return self;
}

@end

/*! Stands in for the effect the extension binds to. */
@interface FxGripAnalysisTestStubEffect : NSObject
@property (nonatomic, strong, readonly) NSNotificationCenter *notifier;
@property (nonatomic, strong) FxGripAnalysisTestStubAPIManager *apiManager;
@end

@implementation FxGripAnalysisTestStubEffect

- (instancetype)init
{
	self = [super init];
	if (self) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_notifier = [[cls alloc] init];
		_apiManager = [FxGripAnalysisTestStubAPIManager.alloc init];
	}
	return self;
}

- (id)effectBase { return self; }

@end

@interface FxGripAnalysisExtensionTests : XCTestCase
@property (nonatomic, strong) FxGripAnalysis *extension;
@property (nonatomic, strong) FxGripAnalysisTestStubEffect *effect;
@end

@implementation FxGripAnalysisExtensionTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripAnalysisTestStubEffect.alloc init];
	self.extension = [FxGripAnalysis.alloc init];
	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect]);
}

- (void)tearDown
{
	self.extension = nil;
	self.effect = nil;
	[super tearDown];
}

- (FxGripAnalysisTestStubGetAPI *)getAPI { return self.effect.apiManager.paramGetAPIv6; }

- (void)runAddedToDocument
{
	[self.extension extAddedToDocument:[NSNotification notificationWithName:FxGripTileableEffectAddedToDocumentName
																	 object:self.effect
																   userInfo:nil]];
}

#pragma mark Parameter registration

/*! @abstract The extension registers a hidden, stateless custom parameter under the analysis data ID. */
- (void)testTheExtensionRegistersAHiddenStatelessCustomParameter
{
	NSMutableArray<NSMutableDictionary *> *parameters = NSMutableArray.new;
	[self.extension extAddParameters:[NSNotification notificationWithName:FxGripTileableEffectAddParametersName
																   object:self.effect
																 userInfo:@{FxGripTileableEffectParametersKey: parameters}]];

	XCTAssertEqual(parameters.count, (NSUInteger)1);
	NSMutableDictionary *parameter = parameters.firstObject;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Id], @(kFxParameterId_AnalysisData));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], kFxParameterType_Custom);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Name], @"Analysis Data");
	XCTAssertEqual((id)parameter[kFxParameterProperty_Factory], (id)self.extension);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Flags],
						  (@[kParameterFlagString_DONT_DISPLAY, kParameterFlagString_HIDDEN,
							 kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOVALUE,
							 kParameterFlagString_NO_DEBUG, kParameterFlagString_NO_STATE]));
}

/*! @abstract The extension takes the analysis data parameter ID at initialization. */
- (void)testTheExtensionTakesTheAnalysisDataParameterID
{
	XCTAssertEqual(self.extension.parameterID, (FxParameterId)kFxParameterId_AnalysisData);
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

#pragma mark The document load

/*! @abstract A document load replaces the in-memory store with the frame data the document carries. */
- (void)testADocumentLoadAdoptsTheStoredFrameData
{
	FxGripFrameData *inMemory = self.extension.frameData;
	FxGripFrameData *stored = [FxGripFrameData.alloc init];
	self.getAPI.storedValue = stored;
	self.getAPI.readSucceeds = YES;

	[self runAddedToDocument];

	XCTAssertEqual(self.getAPI.readParameter, (FxParameterId)kFxParameterId_AnalysisData);
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

/*! @abstract A stored value of the wrong class does not become the store. */
- (void)testAStoredValueOfTheWrongClassDoesNotBecomeTheStore
{
	self.getAPI.storedValue = (NSObject<NSSecureCoding, NSCopying> *)@"not frame data";

	[self runAddedToDocument];

	XCTAssertTrue([self.extension.frameData isKindOfClass:FxGripFrameData.class]);
}

@end
