/*!
	@file       FxGripParameterRetrievalAPI_v7.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterRetrievalAPI_v7
	@abstract   The FxGrip wrapper for the host's FxParameterRetrievalAPI_v7.
	@discussion Introduced in FxGrip 0.1.0. The wrapper extends the v6 wrapper with the one method
	            v7 adds, imageSize:fromParameter:atTime:error:. Every v6 method is inherited. The
	            class mirrors the FxPlug 4 v7 protocol version.
*/

#ifndef FxGripParameterRetrievalAPI_v7_h
#define FxGripParameterRetrievalAPI_v7_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameterRetrievalAPI_v6.h"

/*!
	@interface  FxGripParameterRetrievalAPI_v7
	@abstract   The FxGrip wrapper for the host's FxParameterRetrievalAPI_v7.
	@discussion Introduced in FxGrip 0.1.0. Extends the v6 wrapper with the one method v7 adds:
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
