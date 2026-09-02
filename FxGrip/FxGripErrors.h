//
//  FxGripErrors.h
//  FxGrip
//
//  Created by ~ ~ on 2/27/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripErrors_h
#define FxGripErrors_h

//#import <FxPlug/FxPlugSDK.h>
#import <FxPlug/FxTypes.h>

#define FxGripPlugErrorDomainConstant	(@"FxGripPlugErrorDomain")
#define FxGripPlugErrorDomain ((NSClassFromString(@"FxBaseEffect")) ? (FxPlugErrorDomain) : FxGripPlugErrorDomainConstant)

#define kFxGripError_NoSingleton		(kFxError_ThirdPartyDeveloperStart + 19000)
#define kFxGripError_Exception			(kFxError_ThirdPartyDeveloperStart + 19001)
#define kFxGripError_NoneFound			(kFxError_ThirdPartyDeveloperStart + 19102)

#define kFxGripError_NoClassFound 		(kFxError_ThirdPartyDeveloperStart + 19100)
#define kFxGripError_NonconformingClass (kFxError_ThirdPartyDeveloperStart + 19101)

#define kFxGripError_NoConfigGroups		(kFxError_ThirdPartyDeveloperStart + 30000)
#define kFxGripError_NoConfigPlugins	(kFxError_ThirdPartyDeveloperStart + 30001)

#define kFxGripError_Preset				(kFxError_ThirdPartyDeveloperStart + 31000)

#define kFxGripError_InferenceNotReady		(kFxError_ThirdPartyDeveloperStart + 32000)
#define kFxGripError_InferenceMissingInput	(kFxError_ThirdPartyDeveloperStart + 32001)
#define kFxGripError_InferenceBackendFailure (kFxError_ThirdPartyDeveloperStart + 32002)

#define kFxGripError_WindowAPIUnavailable	(kFxError_ThirdPartyDeveloperStart + 33000)

#define kFxGripError_WatermarkNoDevice		(kFxError_ThirdPartyDeveloperStart + 34000)
#define kFxGripError_WatermarkRender		(kFxError_ThirdPartyDeveloperStart + 34001)

#endif
