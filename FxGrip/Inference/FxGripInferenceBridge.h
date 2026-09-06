/*!
	@file       FxGripInferenceBridge.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInferenceBridge
	@abstract   The runtime bridge that adapts an optional InferKit backend to the FxGrip backend protocol.
	@discussion Introduced in FxGrip 0.1.0. InferKit is an optional dependency that FxGrip does not
	            link. The bridge finds the InferKit classes by name at runtime and reports their
	            presence through isInferKitAvailable. A host that links InferKit passes an InferKit
	            backend to the bridge, and the bridge returns an id<FxGripInferenceBackend> an FxGrip
	            ML effect uses like any other backend. When InferKit is absent, the bridge methods
	            return nil.
*/

#ifndef FxGripInferenceBridge_h
#define FxGripInferenceBridge_h

#import <Foundation/Foundation.h>
#import "FxGripInferenceBackend.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripInferenceBridge
	@abstract   Detects InferKit at runtime and adapts an InferKit backend to the FxGrip inference
				backend protocol.
	@discussion Introduced in FxGrip 0.1.0. InferKit is an optional dependency. FxGrip does not link
				it. The bridge finds the InferKit classes by name at runtime and drives them through
				the selectors the two frameworks share. A host that links InferKit creates an
				InferKit backend and passes it to backendBridgingInferKitBackend:, which returns an
				id<FxGripInferenceBackend> an FxGrip ML effect uses like any other backend. When
				InferKit is absent, isInferKitAvailable is NO and the bridge methods return nil, so
				the effect keeps its own backend.

				The bridge converts an FxGripInferenceRequest to an InferKit request, runs the
				InferKit backend synchronously, and wraps the InferKit result's outputs in an
				FxGripInferenceResult. The two frameworks expose the same inputs, parameters, and
				outputs shape, so the conversion copies the dictionaries without interpreting the
				values.
*/
@interface FxGripInferenceBridge : NSObject

/*! The InferKit class names the bridge needs loaded to run. */
@property (class, nonatomic, readonly) NSArray<NSString *> *requiredInferKitClassNames;

/*! YES when every class in requiredInferKitClassNames is loaded in the current runtime. */
@property (class, nonatomic, readonly, getter=isInferKitAvailable) BOOL inferKitAvailable;

/*! The required InferKit classes not currently loaded. Empty when isInferKitAvailable is YES. */
@property (class, nonatomic, readonly) NSArray<NSString *> *missingInferKitClassNames;

/*!
	@method     absentClassNamesIn:
	@abstract   Returns the names in classNames with no loaded class, in the original order.
	@discussion isInferKitAvailable and missingInferKitClassNames build on this presence primitive.
				A caller probes any class list, so a plugin checks the specific InferKit backend it
				needs before it uses it.
*/
+ (NSArray<NSString *> *)absentClassNamesIn:(NSArray<NSString *> *)classNames;

/*!
	@method     backendBridgingInferKitBackend:
	@abstract   Wraps an InferKit backend as an FxGrip inference backend.
	@discussion Returns nil when inferKitBackend is nil, InferKit is unavailable, or the object does
				not respond to runInferenceForRequest:error:. The wrapper forwards isReady,
				backendIdentifier, and prepareWithError: to the InferKit backend.
*/
+ (nullable id<FxGripInferenceBackend>)backendBridgingInferKitBackend:(id)inferKitBackend;

/*!
	@method     backendBridgingInferKitBackend:requestClass:
	@abstract   Wraps an InferKit backend using an explicit InferKit request class.
	@discussion backendBridgingInferKitBackend: resolves the request class through
				NSClassFromString(@"NFKInferenceRequest"). This variant takes the request class
				directly, for a custom request type or a test that runs without InferKit linked.
				Returns nil when inferKitBackend is nil, requestClass is Nil, or the backend does not
				respond to runInferenceForRequest:error:.
*/
+ (nullable id<FxGripInferenceBackend>)backendBridgingInferKitBackend:(id)inferKitBackend
														requestClass:(Class)requestClass;

/*!
	@method     backendWithInferKitBackendClassNamed:
	@abstract   Instantiates a no-argument InferKit backend by class name and wraps it.
	@discussion className is an InferKit backend class such as @"NFKPassthroughBackend". Returns nil
				when InferKit is unavailable, the class is not loaded, or instantiation fails. A
				backend that needs initialization arguments is created by the host and passed to
				backendBridgingInferKitBackend: instead.
*/
+ (nullable id<FxGripInferenceBackend>)backendWithInferKitBackendClassNamed:(NSString *)className;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripInferenceBridge_h */
