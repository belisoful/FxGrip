//
//  FxGripParameterRetrievalAPI_v7.m
//  FxGrip
//

#import "FxGripParameterRetrievalAPI_v7.h"

@implementation FxGripParameterRetrievalAPI_v7

- (BOOL)imageSize:(CGSize *)imageSize
	fromParameter:(UInt32)parameterID
		   atTime:(CMTime)time
			error:(NSError **)error
{
	// The wrapped api is the host's v7 object at runtime; v7 inherits every v6 method.
	return [(id<FxParameterRetrievalAPI_v7>)self.api imageSize:imageSize
											   fromParameter:parameterID
													  atTime:time
													   error:error];
}

@end
