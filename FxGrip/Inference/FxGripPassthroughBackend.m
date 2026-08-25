//
//  FxGripPassthroughBackend.m
//  FxGrip
//

#import "FxGripPassthroughBackend.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"

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
