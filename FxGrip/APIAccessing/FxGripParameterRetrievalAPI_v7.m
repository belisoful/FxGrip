/*!
	@file       FxGripParameterRetrievalAPI_v7.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterRetrievalAPI_v7
	@abstract   Implements the v7 addition over the v6 retrieval wrapper.
	@discussion Introduced in FxGrip 0.1.0. The class forwards imageSize:fromParameter:atTime:error:
	            to the wrapped host v7 API and inherits every v6 read.
*/

#import "FxGripParameterRetrievalAPI_v7.h"

/*!
	@abstract	FxGrip's wrapper around the host FxParameterRetrievalAPI_v7.
	@discussion	Introduced in FxGrip 0.1.0. Adds the image-size read to the inherited v6 wrapper.
*/
@implementation FxGripParameterRetrievalAPI_v7

/*!
	@method		imageSize:fromParameter:atTime:error:
	@abstract	Forwards the image-space frame size read to the host v7 API.
	@discussion	Introduced in FxGrip 0.1.0. The wrapped api is the host's v7 object at runtime,
				which inherits every v6 method.
	@return		YES when the host returns a size.
*/
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
