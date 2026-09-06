/*!
	@file       FxGripInferenceResult.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInferenceResult
	@abstract   The immutable output value of one inference run.
	@discussion Introduced in FxGrip 0.1.0. A result holds the model's named outputs, keyed by the
	            model's output names. Values are the same media and tensor types a request carries,
	            opaque to the result. A backend returns one result, or nil with an NSError. The type
	            mirrors FxGripInferenceRequest.
*/

#ifndef FxGripInferenceResult_h
#define FxGripInferenceResult_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripInferenceResult
	@abstract   The immutable output of one inference run: the model's named outputs.
	@discussion Introduced in FxGrip 0.1.0. Mirrors FxGripInferenceRequest. Outputs are keyed
				by the model's output names; values are opaque to the result, the same media
				and tensor types a request carries. A backend returns one result, or nil with
				an NSError. An image effect reads the output it expects by name and composites
				it; a passthrough backend returns the inputs it was given, so an effect renders
				its source unchanged with no model present.
*/
@interface FxGripInferenceResult : NSObject <NSCopying>

/*! The model's named outputs. */
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *outputs;

/*! Creates a result with the given outputs. */
+ (instancetype)resultWithOutputs:(NSDictionary<NSString *, id> *)outputs;

/*! The designated initializer. A nil outputs value becomes an empty dictionary. */
- (instancetype)initWithOutputs:(NSDictionary<NSString *, id> *)outputs NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/*! The output for a key, or nil when absent. */
- (nullable id)outputForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripInferenceResult_h */
