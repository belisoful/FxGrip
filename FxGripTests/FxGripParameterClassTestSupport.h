//
//  FxGripParameterClassTestSupport.h
//  FxGripTests
//
//  Test doubles shared by the parameter-class suites. Each parameter class reaches the
//  host only through `effect.apiManager.paramCreateAPIv5`, so the stub creation API
//  records the method name and every argument it received. The stub effect exposes the
//  members the parameter classes read: the API manager, the color-gamut answers, the
//  default font name, and the group recursion hook.
//

#ifndef FxGripParameterClassTestSupport_h
#define FxGripParameterClassTestSupport_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxParameterFlags.h>

NS_ASSUME_NONNULL_BEGIN

/*! Builds an isolated NSPriorityNotificationCenter by name; BEFoundation is not linked. */
NSNotificationCenter *FxGripParamClassTestMakePriorityCenter(void);

#pragma mark - Creation API

/*!
	Stands in for the host's FxParameterCreationAPI_v5. Every call appends a dictionary
	naming the method and each argument, so what a parameter class derives from its
	configuration is observable.
*/
@interface FxGripParamClassTestCreationAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *calls;
@property (nonatomic, assign) BOOL succeeds;
/*! Method names, as recorded, that are refused even while -succeeds stays YES. */
@property (nonatomic, strong) NSMutableSet<NSString *> *refusedMethods;
@property (nonatomic, readonly, nullable) NSDictionary *lastCall;
@end

#pragma mark - Retrieval / setting / dynamic APIs

/*!
	Answers the value and flag getters with the values staged on it, and records every
	read as a dictionary naming the accessor, the parameter ID, and the time asked for.
*/
@interface FxGripParamClassTestRetrievalAPI : NSObject
@property (nonatomic, assign) FxParameterFlags flags;
@property (nonatomic, assign) BOOL succeeds;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *getFlagsParameterIDs;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *reads;
@property (nonatomic, readonly, nullable) NSDictionary *lastRead;

@property (nonatomic, assign) double floatValue;
@property (nonatomic, assign) int intValue;
@property (nonatomic, assign) BOOL boolValue;
@property (nonatomic, copy, nullable) NSString *stringValue;
@property (nonatomic, copy, nullable) NSString *fontName;
@property (nonatomic, strong, nullable) id customValue;
@property (nonatomic, assign) double red;
@property (nonatomic, assign) double green;
@property (nonatomic, assign) double blue;
@property (nonatomic, assign) double alpha;
@property (nonatomic, assign) double x;
@property (nonatomic, assign) double y;

// Histogram: the five values every channel answers, and the channels that refuse.
@property (nonatomic, assign) double blackIn;
@property (nonatomic, assign) double blackOut;
@property (nonatomic, assign) double whiteIn;
@property (nonatomic, assign) double whiteOut;
@property (nonatomic, assign) double gamma;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *refusedHistogramChannels;

// Gradient: the byte written into every sample slot.
@property (nonatomic, assign) unsigned char gradientFill;
@end

/*! Records every write the parameter performs. */
@interface FxGripParamClassTestSettingAPI : NSObject
@property (nonatomic, assign) BOOL succeeds;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *setFlagsCalls;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *writes;
@property (nonatomic, readonly, nullable) NSDictionary *lastWrite;
@end

/*! Answers the name getter and records the name writes. */
@interface FxGripParamClassTestDynamicAPI : NSObject
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, strong, nullable) NSError *nameError;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *setNameCalls;
@end

/*! Answers the image-parameter timing queries with the staged times. */
@interface FxGripParamClassTestTimingAPI : NSObject
@property (nonatomic, assign) CMTime startTime;
@property (nonatomic, assign) CMTime durationTime;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *queries;
@end

#pragma mark - API manager

@interface FxGripParamClassTestAPIManager : NSObject
@property (nonatomic, assign) unsigned long long sessionID;
@property (nonatomic, strong, nullable) FxGripParamClassTestCreationAPI *paramCreateAPIv5;
@property (nonatomic, strong, nullable) FxGripParamClassTestRetrievalAPI *paramGetAPIv6;
@property (nonatomic, strong, nullable) FxGripParamClassTestSettingAPI *paramSetAPIv5;
@property (nonatomic, strong, nullable) FxGripParamClassTestSettingAPI *paramSetAPIv6;
@property (nonatomic, strong, nullable) FxGripParamClassTestDynamicAPI *dynamicParamAPIv3;
@property (nonatomic, strong, nullable) FxGripParamClassTestTimingAPI *timingAPIv4;
@end

#pragma mark - Effect

/*!
	FxGripTileableEffect's designated initializer registers into the process-wide
	notification center and needs a live host, so the parameter classes are exercised
	against this stub. It responds to exactly the messages the parameter classes send.
*/
@interface FxGripParamClassTestEffect : NSObject
@property (nonatomic, strong) FxGripParamClassTestAPIManager *apiManager;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, copy) NSString *defaultFontName;
@property (nonatomic, assign) BOOL isLinearColorParameters;
@property (nonatomic, assign) BOOL isGammaColorParameters;

// Group recursion.
@property (nonatomic, strong) NSMutableArray<NSNumber *> *addedGroupIDs;
@property (nonatomic, assign) BOOL groupRecursionSucceeds;
@property (nonatomic, strong, nullable) NSError *groupRecursionError;
/*! Appended to -addedGroupIDs at the moment the recursion runs, for ordering assertions. */
@property (nonatomic, strong) NSMutableArray<NSString *> *creationOrder;

// Backs -objectForKeyedSubscript: so a parameter can look up a sibling.
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id> *parameters;

- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError *_Nullable *_Nullable)error;
- (nullable id)objectForKeyedSubscript:(nullable id)key;
- (nullable id)objectAtIndexedSubscript:(NSInteger)index;

/*! Convenience: the single recorded creation call. */
@property (nonatomic, readonly, nullable) NSDictionary *creationCall;
@property (nonatomic, readonly) NSArray<NSDictionary *> *creationCalls;
@end

#pragma mark - Configuration helper

/*!
	Builds a parameter configuration. The dictionary accessors in
	NSDictionary+FxGripTileableEffect return their fallback unless "id", "type", and "name"
	are all present, so every configuration under test carries the three.
*/
NSMutableDictionary *FxGripParamClassTestConfig(FxParameterId parameterID,
										   NSString *type,
										   NSString *name,
										   NSDictionary *_Nullable extra);

/*! Builds a CMTime without calling CoreMedia, which the test bundle does not link. */
CMTime FxGripParamClassTestTime(int64_t value, int32_t timescale);

NS_ASSUME_NONNULL_END

#endif	/* FxGripParameterClassTestSupport_h */
