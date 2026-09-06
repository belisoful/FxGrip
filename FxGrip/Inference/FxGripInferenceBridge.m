/*!
	@file       FxGripInferenceBridge.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInferenceBridge
	@abstract   Implements the runtime bridge from an InferKit backend to the FxGrip backend protocol.
	@discussion Introduced in FxGrip 0.1.0. The InferKit request, result, and backend share their
	            selectors with the FxGrip types, so a private adapter messages the InferKit objects
	            through the FxGrip declarations while the objects are InferKit instances at runtime.
	            The class methods probe for the InferKit classes by name and build the adapter only
	            when they are loaded.
*/

#import "FxGripInferenceBridge.h"
#import "FxGripInferenceRequest.h"
#import "FxGripInferenceResult.h"
#import "FxGrip_ARC.h"

// InferKit is not linked. The bridge resolves these classes by name at runtime. The value types the
// bridge constructs and reads are the required set; an InferKit backend is supplied by the host.
static NSString * const kFxGripInferKitRequestClassName = @"NFKInferenceRequest";
static NSString * const kFxGripInferKitResultClassName  = @"NFKInferenceResult";

#pragma mark - Adapter

/*!
	Wraps an InferKit backend object behind id<FxGripInferenceBackend>. The InferKit backend,
	request, and result share their selectors with the FxGrip types, so the adapter messages the
	InferKit objects through the FxGrip declarations imported here.
*/
@interface FxGripInferenceKitBackendAdapter : NSObject <FxGripInferenceBackend>
- (instancetype)initWithInferKitBackend:(id)backend requestClass:(Class)requestClass;
@end

/*!
	@abstract	Wraps an InferKit backend object behind id<FxGripInferenceBackend>.
	@discussion	Introduced in FxGrip 0.1.0. The adapter forwards isReady, backendIdentifier, and
				prepareWithError: to the InferKit backend. It converts an FxGripInferenceRequest to
				an InferKit request, runs the backend, and wraps the InferKit result's outputs in an
				FxGripInferenceResult.
*/
@implementation FxGripInferenceKitBackendAdapter
{
	id _backend;
	Class _requestClass;
}

- (instancetype)initWithInferKitBackend:(id)backend requestClass:(Class)requestClass
{
	self = [super init];
	if (self != nil) {
		_backend = NARC_RETAIN(backend);
		_requestClass = requestClass;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_backend);
	SUPER_DEALLOC();
}

- (BOOL)isReady
{
	return [_backend isReady];
}

- (NSString *)backendIdentifier
{
	return [_backend backendIdentifier];
}

/*! Converts the request to an InferKit request, runs the InferKit backend, and wraps its outputs. */
- (nullable FxGripInferenceResult *)runInferenceForRequest:(FxGripInferenceRequest *)request
													error:(NSError **)outError
{
	// The InferKit request factory and result accessor share their selectors with the FxGrip
	// types, so the compiler types these sends through the FxGrip declarations while the objects
	// are InferKit instances at runtime.
	id kitRequest = [_requestClass requestWithInputs:request.inputs parameters:request.parameters];
	id kitResult = [_backend runInferenceForRequest:kitRequest error:outError];
	if (kitResult == nil) {
		return nil;
	}
	NSDictionary<NSString *, id> *outputs = [kitResult outputs];
	return [FxGripInferenceResult resultWithOutputs:outputs];
}

- (BOOL)prepareWithError:(NSError **)outError
{
	if ([_backend respondsToSelector:@selector(prepareWithError:)]) {
		return [_backend prepareWithError:outError];
	}
	return YES;
}

@end

#pragma mark - FxGripInferenceBridge

/*!
	@abstract	Detects InferKit at runtime and adapts an InferKit backend to the FxGrip backend protocol.
	@discussion	Introduced in FxGrip 0.1.0. The class methods resolve the InferKit classes by name
				and build an adapter only when they are loaded. When InferKit is absent, the bridge
				methods return nil.
*/
@implementation FxGripInferenceBridge

/*! The InferKit class names the bridge needs loaded to run. */
+ (NSArray<NSString *> *)requiredInferKitClassNames
{
	return @[ kFxGripInferKitRequestClassName, kFxGripInferKitResultClassName ];
}

/*! The names in classNames with no loaded class, in the original order. */
+ (NSArray<NSString *> *)absentClassNamesIn:(NSArray<NSString *> *)classNames
{
	NSMutableArray<NSString *> *absent = [NSMutableArray arrayWithCapacity:classNames.count];
	for (NSString *name in classNames) {
		if (NSClassFromString(name) == Nil) {
			[absent addObject:name];
		}
	}
	return absent;
}

+ (NSArray<NSString *> *)missingInferKitClassNames
{
	return [self absentClassNamesIn:self.requiredInferKitClassNames];
}

+ (BOOL)isInferKitAvailable
{
	return self.missingInferKitClassNames.count == 0;
}

/*! Wraps an InferKit backend, resolving the InferKit request class by name. nil when unavailable. */
+ (nullable id<FxGripInferenceBackend>)backendBridgingInferKitBackend:(id)inferKitBackend
{
	if (![self isInferKitAvailable]) {
		return nil;
	}
	Class requestClass = NSClassFromString(kFxGripInferKitRequestClassName);
	return [self backendBridgingInferKitBackend:inferKitBackend requestClass:requestClass];
}

/*! Wraps an InferKit backend with an explicit request class. nil when the backend cannot run one. */
+ (nullable id<FxGripInferenceBackend>)backendBridgingInferKitBackend:(id)inferKitBackend
														requestClass:(Class)requestClass
{
	if (inferKitBackend == nil || requestClass == Nil) {
		return nil;
	}
	if (![inferKitBackend respondsToSelector:@selector(runInferenceForRequest:error:)]) {
		return nil;
	}
	FxGripInferenceKitBackendAdapter *adapter =
		[[FxGripInferenceKitBackendAdapter alloc] initWithInferKitBackend:inferKitBackend
															requestClass:requestClass];
	return NARC_AUTORELEASE(adapter);
}

/*! Instantiates a no-argument InferKit backend by class name and wraps it. nil on any failure. */
+ (nullable id<FxGripInferenceBackend>)backendWithInferKitBackendClassNamed:(NSString *)className
{
	if (![self isInferKitAvailable]) {
		return nil;
	}
	Class backendClass = NSClassFromString(className);
	if (backendClass == Nil) {
		return nil;
	}
	id backend = NARC_AUTORELEASE([[backendClass alloc] init]);
	return [self backendBridgingInferKitBackend:backend];
}

@end
