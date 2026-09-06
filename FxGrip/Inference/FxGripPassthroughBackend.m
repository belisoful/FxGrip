/*!
	@file       FxGripPassthroughBackend.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPassthroughBackend
	@abstract   Implements the mock backend that returns its inputs as outputs, running no model.
	@discussion Introduced in FxGrip 0.1.0. The backend is always ready. With no output map, the run
	            returns the request's inputs verbatim. With an output map, the run copies each named
	            input to its mapped output name and fails when a mapped input is absent.
*/

#import "FxGripPassthroughBackend.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The mock inference backend that returns its inputs as outputs, running no model.
	@discussion	Introduced in FxGrip 0.1.0. The backend is always ready and keeps FxGrip's ML effects
				building and testing green with no weights.
*/
@implementation FxGripPassthroughBackend

+ (instancetype)backend
{
	return NARC_AUTORELEASE([[self alloc] init]);
}

- (void)dealloc
{
	NARC_RELEASE(_outputMap);
	SUPER_DEALLOC();
}

- (BOOL)isReady
{
	return YES;
}

- (NSString *)backendIdentifier
{
	return @"passthrough";
}

/*!
	@method		runInferenceForRequest:error:
	@abstract	Returns the request's inputs as outputs, applying outputMap when it is set.
	@discussion	Introduced in FxGrip 0.1.0. A nil outputMap echoes the inputs verbatim. A set
				outputMap copies each mapped input to its output name, and a mapped input absent from
				the request fails the run with an FxGrip-domain error. */
- (nullable FxGripInferenceResult *)runInferenceForRequest:(FxGripInferenceRequest *)request
													error:(NSError **)outError
{
	if (self.outputMap == nil) {
		return [FxGripInferenceResult resultWithOutputs:request.inputs];
	}

	NSMutableDictionary<NSString *, id> *outputs = [NSMutableDictionary dictionaryWithCapacity:self.outputMap.count];
	for (NSString *outputName in self.outputMap) {
		NSString *inputName = self.outputMap[outputName];
		id value = [request inputForKey:inputName];
		if (value == nil) {
			if (outError != NULL) {
				NSString *reason = [NSString stringWithFormat:@"passthrough output '%@' maps to missing input '%@'",
									outputName, inputName];
				*outError = [NSError errorWithDomain:FxGripPlugErrorDomain
												code:kFxGripError_InferenceMissingInput
											userInfo:@{ NSLocalizedDescriptionKey: reason }];
			}
			return nil;
		}
		outputs[outputName] = value;
	}
	return [FxGripInferenceResult resultWithOutputs:outputs];
}

@end
