//
//  FxGripSettingAPITestSupport.h
//  FxGripTests
//
//  Shared test doubles and a base XCTestCase for the parameter setting API wrappers. The
//  version-five and version-six setting wrappers are exercised against the same host,
//  dynamic, retrieval, and custom-value stubs; this unit holds them so the per-version test
//  files carry only their own assertions.
//

#import <XCTest/XCTest.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripParameterSettingAPI_v5.h>
#import <FxGrip/FxGripParameterSettingAPI_v6.h>

NS_ASSUME_NONNULL_BEGIN

extern const FxParameterId kSettingTestParameter;

// The wrappers box each time as a BEFoundation FxTime. The test target does not link
// BEFoundation, so the wrapped CMTime is read through a locally declared accessor
// rather than through the FxTime class symbol.
@protocol FxGripSettingTestTimeReading <NSObject>
@property (readonly) CMTime time;
@end

// CoreMedia is not linked either, so CMTime values are built without its symbols.
CMTime FxGripSettingTestTime(void);
CMTime FxGripSettingTestZeroTime(void);
BOOL FxGripSettingTestTimesEqual(CMTime lhs, CMTime rhs);

/*! Stands in for the host's FxParameterSettingAPI_v6, recording every forwarded call. */
@interface FxGripSettingTestStubAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *calls;
@property (nonatomic, assign) BOOL succeeds;
@property (nonatomic, assign) CMTime lastTime;
@end

/*! Answers the parameter type the setters branch on. */
@interface FxGripSettingTestDynamicAPI : NSObject
@property (nonatomic, assign) FxParameterType type;
@end

/*!
	The custom parameter value the interception branch mutates. It reports conformance to
	FxGripMutableParameter through -conformsToProtocol: so the protocol, which is not a
	public framework header, needs no local redeclaration.
*/
@interface FxGripSettingTestCustomValue : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *receivedSetters;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *receivedValues;
@property (nonatomic, assign) BOOL conforms;
@property (nonatomic, assign) BOOL setterSucceeds;
@end

/*! Conforms to FxGripMutableParameter but implements none of its setters. */
@interface FxGripSettingTestOpaqueValue : NSObject
@end

/*! Serves the custom parameter read the interception branch performs. */
@interface FxGripSettingTestRetrievalAPI : NSObject
@property (nonatomic, strong) id customValue;
@property (nonatomic, assign) BOOL succeeds;
@property (nonatomic, assign) NSUInteger readCount;
@property (nonatomic, assign) CMTime lastTime;
@property (nonatomic, assign) FxParameterFlags flags;
@property (nonatomic, assign) BOOL flagsSucceed;
@end

@interface FxGripSettingTestAPIManager : NSObject
@property (nonatomic, strong) FxGripSettingTestRetrievalAPI *retrievalAPI;
@end

/*!
	FxGripTileableEffect's designated initializer registers into the process-wide
	notification center, so the wrappers are exercised against a stub carrying an isolated
	notifier. The v6 flag helpers additionally read -apiManager.
*/
@interface FxGripSettingTestStubEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, strong) FxGripSettingTestAPIManager *apiManager;
@end

/*!
	Base test case wiring the stubs together and exposing the notification-observing and
	wrapper-construction helpers the version-specific test cases share.
*/
@interface FxGripSettingAPITestCase : XCTestCase
@property (nonatomic, strong) FxGripSettingTestStubEffect *effect;
@property (nonatomic, strong) FxGripSettingTestStubAPI *hostAPI;
@property (nonatomic, strong) FxGripSettingTestDynamicAPI *dynamicAPI;
@property (nonatomic, strong) FxGripSettingTestRetrievalAPI *retrievalAPI;
@property (nonatomic, strong) FxGripSettingTestCustomValue *customValue;
@property (nonatomic, strong) NSMutableArray<NSNotification *> *posted;
// The notifier holds its observers weakly, so every token is retained for the test.
@property (nonatomic, strong) NSMutableArray *observerTokens;

- (NSArray<NSNotificationName> *)recordedNotificationNames;
- (void)observeName:(NSNotificationName)name usingBlock:(void (^)(NSNotification *notification))block;
- (NSArray<NSNotificationName> *)postedNames;
- (nullable NSNotification *)notificationNamed:(NSNotificationName)name;
- (nullable NSDictionary *)payloadOf:(NSNotificationName)name;
- (nullable NSDictionary *)hostCall;
- (NSArray<NSString *> *)hostMethods;
- (FxGripParameterSettingAPI_v5 *)settingAPI;
- (FxGripParameterSettingAPI_v5 *)settingAPIWithoutDynamicAPI;
- (FxGripParameterSettingAPI_v6 *)settingAPIv6;
- (void)markParameterCustom;
- (CMTime)payloadTimeOf:(NSNotificationName)name;
@end

NS_ASSUME_NONNULL_END
