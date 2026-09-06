/*!
	@file       FxGripInferenceRequest.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInferenceRequest
	@abstract   The immutable input value for one inference run.
	@discussion Introduced in FxGrip 0.1.0. A request holds the model's named inputs and a separate
	            bag of scalar parameters. Inputs are the tensors or media a backend consumes, keyed
	            by the model's input names. Parameters are the scalar controls a backend reads, such
	            as seed and strength. The split lets one type describe an image pass and a text pass.
	            The value is immutable, so a change builds a new request.
*/

#ifndef FxGripInferenceRequest_h
#define FxGripInferenceRequest_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripInferenceRequest
	@abstract   The immutable input to one inference run: named inputs plus parameters.
	@discussion Introduced in FxGrip 0.1.0. A request carries the model's named inputs and a
				separate bag of parameters, keeping the two roles distinct:

				- inputs are the tensors or media a backend consumes, keyed by the model's
				  input names. Values are opaque to the request: a CVPixelBuffer, an
				  MLMultiArray, an FxGripImageBuffer, an NSString prompt, or NSData. The
				  backend interprets them.
				- parameters are scalar controls a backend reads, keyed by name: seed,
				  strength, step count, guidance scale, and similar. Values are typically
				  NSNumber or NSString.

				The split lets one request describe an image-to-image pass (inputs hold the
				plate and mask, parameters hold strength and seed) or a text pass (inputs
				hold the prompt) through the same type. The value is immutable; build a new
				request to change it.
*/
@interface FxGripInferenceRequest : NSObject <NSCopying>

/*! The model's named inputs. */
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *inputs;

/*! The scalar controls a backend reads. */
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *parameters;

/*! Creates a request with the given inputs and parameters. A nil parameters value becomes empty. */
+ (instancetype)requestWithInputs:(NSDictionary<NSString *, id> *)inputs
					   parameters:(nullable NSDictionary<NSString *, id> *)parameters;

/*! Creates a request with the given inputs and no parameters. */
+ (instancetype)requestWithInputs:(NSDictionary<NSString *, id> *)inputs;

/*! The designated initializer. A nil inputs or parameters value becomes an empty dictionary. */
- (instancetype)initWithInputs:(NSDictionary<NSString *, id> *)inputs
					parameters:(nullable NSDictionary<NSString *, id> *)parameters NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/*! The input for a key, or nil when absent. */
- (nullable id)inputForKey:(NSString *)key;

/*! The parameter for a key, or nil when absent. */
- (nullable id)parameterForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripInferenceRequest_h */
