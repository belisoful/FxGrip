//
//  FxGripParameterRetrievalAPI_v7.h
//  FxGrip
//

#ifndef FxGripParameterRetrievalAPI_v7_h
#define FxGripParameterRetrievalAPI_v7_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameterRetrievalAPI_v6.h"

/*!
	@interface  FxGripParameterRetrievalAPI_v7
	@abstract   The FxGrip wrapper for the host's FxParameterRetrievalAPI_v7.
	@discussion Introduced in FxGrip 1.0. Extends the v6 wrapper with the one method v7 adds:
				imageSize:fromParameter:atTime:error:, which reports an image-well parameter's
				frame size in image space, with pixel-aspect, fields, proxy, and user scaling
				removed. Every v6 method is inherited.
*/
@interface FxGripParameterRetrievalAPI_v7 : FxGripParameterRetrievalAPI_v6 <FxParameterRetrievalAPI_v7>

/*!
	@method     imageSize:fromParameter:atTime:error:
	@abstract   The image-space size of an image-well parameter's frame at a time.
*/
- (BOOL)imageSize:(CGSize *)imageSize
	fromParameter:(UInt32)parameterID
		   atTime:(CMTime)time
			error:(NSError **)error;

@end

#endif /* FxGripParameterRetrievalAPI_v7_h */
