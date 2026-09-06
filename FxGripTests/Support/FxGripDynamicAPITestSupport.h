/*!
	@file       FxGripDynamicAPITestSupport.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDynamicAPITestSupport
	@abstract   Shared test doubles and a base XCTestCase for the dynamic parameter API wrappers.
	@discussion Introduced in FxGrip 0.1.0. The v3 forwarding wrapper, the parameter info queries, and
	            the single-bound convenience setters are exercised against the same host stub. This unit
	            holds the stub so the per-class test files carry only their own assertions.
*/

#import <XCTest/XCTest.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripDynamicParameterAPI_v3.h>
#import <FxGrip/FxGripParameterInfoAPI_v1.h>
#import <FxGrip/FxGripParameterBoundsAPI_v1.h>

NS_ASSUME_NONNULL_BEGIN

extern const FxParameterId kDynamicTestParameter;

// CoreMedia is not linked, so CMTime values are built without its symbols.
CMTime FxGripDynamicTestTime(void);
NSError *FxGripDynamicTestError(void);

/*! Stands in for the host's FxDynamicParameterAPI_v3, recording every forwarded call. */
@interface FxGripDynamicTestStubAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *calls;
@property (nonatomic, strong, nullable) NSError *nextError;
@property (nonatomic, copy, nullable) NSString *hostName;
@property (nonatomic, strong) NSArray<NSNumber *> *parameterIDs;
@property (nonatomic, assign) double floatMinimum;
@property (nonatomic, assign) double floatMaximum;
@property (nonatomic, assign) double floatSliderMinimum;
@property (nonatomic, assign) double floatSliderMaximum;
@property (nonatomic, assign) int intMinimum;
@property (nonatomic, assign) int intMaximum;
@property (nonatomic, assign) int intSliderMinimum;
@property (nonatomic, assign) int intSliderMaximum;
@property (nonatomic, assign) BOOL defaultsSucceed;
@property (nonatomic, assign) CMTime lastDefaultsTime;
@end

/*!
	FxGripTileableEffect's designated initializer registers into the process-wide
	notification center, so the wrappers are exercised against a stub carrying an isolated
	notifier. The name and menu setters also subscript the effect for the object they post
	against; the stub reports no parameter object.
*/
@interface FxGripDynamicTestStubEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, assign) BOOL hasMeta;
@end

/*!
	Base test case wiring the stub host to an isolated notifier and exposing the
	notification-observing and wrapper-construction helpers the per-class test cases share.
*/
@interface FxGripDynamicAPITestCase : XCTestCase
@property (nonatomic, strong) FxGripDynamicTestStubEffect *effect;
@property (nonatomic, strong) FxGripDynamicTestStubAPI *hostAPI;
@property (nonatomic, strong) NSMutableArray<NSNotification *> *posted;
// The notifier holds its observers weakly, so every token is retained for the test.
@property (nonatomic, strong) NSMutableArray *observerTokens;

- (NSArray<NSNotificationName> *)recordedNotificationNames;
- (void)observeName:(NSNotificationName)name usingBlock:(void (^)(NSNotification *notification))block;
- (NSArray<NSNotificationName> *)postedNames;
- (nullable NSNotification *)notificationNamed:(NSNotificationName)name;
- (NSArray<NSString *> *)hostMethods;
- (nullable NSDictionary *)hostCallNamed:(NSString *)method;
- (FxGripDynamicParameterAPI_v3 *)apiV3;
- (FxGripParameterInfoAPI_v1 *)apiInfo;
- (FxGripParameterBoundsAPI_v1 *)apiBounds;
@end

NS_ASSUME_NONNULL_END
