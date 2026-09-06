//
//  FxGripInferenceBridgeTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripInferenceBridge.h>
#import <FxGrip/FxGripInferenceRequest.h>
#import <FxGrip/FxGripInferenceResult.h>
#import <FxGrip/FxGripInferenceBackend.h>

#pragma mark - InferKit stand-ins

// FxGrip does not link InferKit. These doubles mimic the InferKit contract the bridge relies on
// (the shared requestWithInputs:parameters: factory, the outputs accessor, and the backend
// selectors), so the adapter path is exercised without the framework present.

@interface FxGripBridgeKitResult : NSObject
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *outputs;
@end
@implementation FxGripBridgeKitResult
@end

@interface FxGripBridgeKitRequest : NSObject
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *inputs;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *parameters;
+ (instancetype)requestWithInputs:(NSDictionary<NSString *, id> *)inputs
					   parameters:(NSDictionary<NSString *, id> *)parameters;
@end
@implementation FxGripBridgeKitRequest
+ (instancetype)requestWithInputs:(NSDictionary<NSString *, id> *)inputs
					   parameters:(NSDictionary<NSString *, id> *)parameters
{
	FxGripBridgeKitRequest *request = [self new];
	request.inputs = inputs;
	request.parameters = parameters;
	return request;
}
@end

@interface FxGripBridgeKitBackend : NSObject
@property (nonatomic) BOOL ready;
@property (nonatomic) NSInteger runCount;
@property (nonatomic, strong, nullable) id lastRequest;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *outputsToReturn;
@property (nonatomic, strong, nullable) NSError *errorToReturn;
@property (nonatomic) BOOL prepareCalled;
@end
@implementation FxGripBridgeKitBackend
- (BOOL)isReady { return self.ready; }
- (NSString *)backendIdentifier { return @"test-kit"; }
- (id)runInferenceForRequest:(id)request error:(NSError **)error
{
	self.runCount++;
	self.lastRequest = request;
	if (self.errorToReturn != nil) {
		if (error != NULL) {
			*error = self.errorToReturn;
		}
		return nil;
	}
	FxGripBridgeKitResult *result = [FxGripBridgeKitResult new];
	result.outputs = self.outputsToReturn ?: @{};
	return result;
}
- (BOOL)prepareWithError:(NSError **)error
{
	self.prepareCalled = YES;
	return YES;
}
@end

#pragma mark - Tests

@interface FxGripInferenceBridgeTests : XCTestCase
@end

@implementation FxGripInferenceBridgeTests

#pragma mark Presence check

- (void)testRequiredClassNamesAreTheInferKitValueTypes
{
	XCTAssertEqualObjects(FxGripInferenceBridge.requiredInferKitClassNames,
						  (@[ @"NFKInferenceRequest", @"NFKInferenceResult" ]));
}

- (void)testInferKitReportedUnavailableWhenNotLinked
{
	XCTAssertFalse(FxGripInferenceBridge.isInferKitAvailable);
	XCTAssertEqualObjects(FxGripInferenceBridge.missingInferKitClassNames,
						  FxGripInferenceBridge.requiredInferKitClassNames);
}

- (void)testAbsentClassNamesDetectsLoadedAndMissing
{
	NSArray<NSString *> *allPresent = @[ @"NSString", @"NSArray" ];
	NSArray<NSString *> *oneMissing = @[ @"NSString", @"FxGripNoSuchClass_x" ];
	XCTAssertEqualObjects([FxGripInferenceBridge absentClassNamesIn:allPresent], @[]);
	XCTAssertEqualObjects([FxGripInferenceBridge absentClassNamesIn:oneMissing], (@[ @"FxGripNoSuchClass_x" ]));
}

#pragma mark Bridging guards

- (void)testPublicBridgeIsANoOpWithoutInferKit
{
	FxGripBridgeKitBackend *backend = [FxGripBridgeKitBackend new];
	XCTAssertNil([FxGripInferenceBridge backendBridgingInferKitBackend:backend]);
	XCTAssertNil([FxGripInferenceBridge backendWithInferKitBackendClassNamed:@"NFKPassthroughBackend"]);
}

- (void)testBridgingRejectsNilAndNonBackends
{
	XCTAssertNil([FxGripInferenceBridge backendBridgingInferKitBackend:nil requestClass:FxGripBridgeKitRequest.class]);
	FxGripBridgeKitBackend *backend = [FxGripBridgeKitBackend new];
	XCTAssertNil([FxGripInferenceBridge backendBridgingInferKitBackend:backend requestClass:Nil]);
	XCTAssertNil([FxGripInferenceBridge backendBridgingInferKitBackend:[NSObject new] requestClass:FxGripBridgeKitRequest.class],
				 @"an object without runInferenceForRequest:error: is not bridged");
}

#pragma mark Adapter behavior

- (void)testBridgedBackendForwardsReadinessAndIdentity
{
	FxGripBridgeKitBackend *backend = [FxGripBridgeKitBackend new];
	backend.ready = YES;
	id<FxGripInferenceBackend> bridged =
		[FxGripInferenceBridge backendBridgingInferKitBackend:backend requestClass:FxGripBridgeKitRequest.class];
	XCTAssertNotNil(bridged);
	XCTAssertTrue(bridged.isReady);
	XCTAssertEqualObjects(bridged.backendIdentifier, @"test-kit");
}

- (void)testBridgedRunConvertsRequestAndResult
{
	FxGripBridgeKitBackend *backend = [FxGripBridgeKitBackend new];
	backend.ready = YES;
	id sentinel = [NSObject new];
	backend.outputsToReturn = @{ @"image": sentinel };
	id<FxGripInferenceBackend> bridged =
		[FxGripInferenceBridge backendBridgingInferKitBackend:backend requestClass:FxGripBridgeKitRequest.class];

	id inputTexture = [NSObject new];
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:@{ @"image": inputTexture }
																	 parameters:@{ @"seed": @7 }];
	NSError *error = nil;
	FxGripInferenceResult *result = [bridged runInferenceForRequest:request error:&error];

	XCTAssertNotNil(result);
	XCTAssertNil(error);
	XCTAssertEqual(backend.runCount, 1);
	XCTAssertEqualObjects([result outputForKey:@"image"], sentinel, @"the InferKit output flows back");

	FxGripBridgeKitRequest *forwarded = (FxGripBridgeKitRequest *)backend.lastRequest;
	XCTAssertEqualObjects(forwarded.inputs[@"image"], inputTexture, @"inputs pass through unchanged");
	XCTAssertEqualObjects(forwarded.parameters[@"seed"], @7, @"parameters pass through unchanged");
}

- (void)testBridgedRunPropagatesBackendFailure
{
	FxGripBridgeKitBackend *backend = [FxGripBridgeKitBackend new];
	backend.errorToReturn = [NSError errorWithDomain:@"test" code:123 userInfo:nil];
	id<FxGripInferenceBackend> bridged =
		[FxGripInferenceBridge backendBridgingInferKitBackend:backend requestClass:FxGripBridgeKitRequest.class];
	NSError *error = nil;
	FxGripInferenceResult *result = [bridged runInferenceForRequest:[FxGripInferenceRequest requestWithInputs:@{}]
															 error:&error];
	XCTAssertNil(result);
	XCTAssertEqualObjects(error.domain, @"test");
	XCTAssertEqual(error.code, 123);
}

- (void)testBridgedPrepareForwardsToBackend
{
	FxGripBridgeKitBackend *backend = [FxGripBridgeKitBackend new];
	id<FxGripInferenceBackend> bridged =
		[FxGripInferenceBridge backendBridgingInferKitBackend:backend requestClass:FxGripBridgeKitRequest.class];
	XCTAssertTrue([bridged respondsToSelector:@selector(prepareWithError:)]);
	NSError *error = nil;
	XCTAssertTrue([bridged prepareWithError:&error]);
	XCTAssertTrue(backend.prepareCalled);
}

@end
