/*!
	@file       FxGripPassthroughBackend.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPassthroughBackend
	@abstract   The mock inference backend that returns its inputs as outputs, running no model.
	@discussion Introduced in FxGrip 0.1.0. The backend keeps FxGrip's ML effects building and
	            testing green with no weights. It is always ready. With no outputMap set, the result
	            echoes the request's inputs verbatim. A model whose outputs are named differently
	            from its inputs sets outputMap to route them.
*/

#ifndef FxGripPassthroughBackend_h
#define FxGripPassthroughBackend_h

#import <Foundation/Foundation.h>
#import "FxGripInferenceBackend.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripPassthroughBackend
	@abstract   The mock inference backend: it returns its inputs as outputs, running no model.
	@discussion Introduced in FxGrip 0.1.0. Keeps FxGrip's ML effects building and testing green
				with no weights, mirroring the framework's test-double conventions. It is always
				ready.

				With no outputMap set, the result echoes the request's inputs verbatim, so an
				effect whose input and output share a name (image-to-image) renders its source
				unchanged. A model whose outputs are named differently from its inputs sets
				outputMap to route them: for a keyer that consumes "rgb" and "hint" and produces
				"fg" and "matte", @{ @"fg": @"rgb", @"matte": @"hint" } makes the mock stand in.
				A mapped input that is absent from the request fails the run with an error.
*/
@interface FxGripPassthroughBackend : NSObject <FxGripInferenceBackend>

/*!
	@property   outputMap
	@abstract   Maps each output name to the input name it copies. nil echoes inputs verbatim.
*/
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *outputMap;

/*! Creates a ready passthrough backend with no output map. */
+ (instancetype)backend;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripPassthroughBackend_h */
