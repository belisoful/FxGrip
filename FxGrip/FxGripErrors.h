/*!
	@file       FxGripErrors.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripErrors
	@abstract   The FxGrip error domain and the error codes the framework returns to FxPlug hosts.
	@discussion Introduced in FxGrip 0.1.0. Every code is an offset from kFxError_ThirdPartyDeveloperStart,
	            the range Apple reserves for third-party FxPlug developers, so the codes never collide
	            with Apple's. FxGripPlugErrorDomain resolves to the host FxPlug domain when the host
	            classes are present and to a private FxGrip domain otherwise, so errors are usable
	            both in a host and in unit tests.
*/

#ifndef FxGripErrors_h
#define FxGripErrors_h

//#import <FxPlug/FxPlugSDK.h>
#import <FxPlug/FxTypes.h>

/*! The literal FxGrip error-domain string used when no FxPlug host is present. */
#define FxGripPlugErrorDomainConstant	(@"FxGripPlugErrorDomain")
/*! The active error domain: the FxPlug host domain when hosted, the FxGrip domain otherwise. */
#define FxGripPlugErrorDomain ((NSClassFromString(@"FxBaseEffect")) ? (FxPlugErrorDomain) : FxGripPlugErrorDomainConstant)

/*! No singleton instance is available for the requested operation. */
#define kFxGripError_NoSingleton		(kFxError_ThirdPartyDeveloperStart + 19000)
/*! An Objective-C exception was caught and converted into an error. */
#define kFxGripError_Exception			(kFxError_ThirdPartyDeveloperStart + 19001)
/*! A lookup that expected at least one match found none. */
#define kFxGripError_NoneFound			(kFxError_ThirdPartyDeveloperStart + 19102)

/*! No class was found for the requested name or role. */
#define kFxGripError_NoClassFound 		(kFxError_ThirdPartyDeveloperStart + 19100)
/*! A resolved class does not conform to the required protocol. */
#define kFxGripError_NonconformingClass (kFxError_ThirdPartyDeveloperStart + 19101)

/*! The plugin configuration declares no groups. */
#define kFxGripError_NoConfigGroups		(kFxError_ThirdPartyDeveloperStart + 30000)
/*! The plugin configuration declares no plugins. */
#define kFxGripError_NoConfigPlugins	(kFxError_ThirdPartyDeveloperStart + 30001)

/*! A preset read or write operation failed. */
#define kFxGripError_Preset				(kFxError_ThirdPartyDeveloperStart + 31000)

/*! The inference backend is not ready to run. */
#define kFxGripError_InferenceNotReady		(kFxError_ThirdPartyDeveloperStart + 32000)
/*! A required inference input is missing. */
#define kFxGripError_InferenceMissingInput	(kFxError_ThirdPartyDeveloperStart + 32001)
/*! The inference backend failed while running. */
#define kFxGripError_InferenceBackendFailure (kFxError_ThirdPartyDeveloperStart + 32002)

/*! The host window API required by the operation is unavailable. */
#define kFxGripError_WindowAPIUnavailable	(kFxError_ThirdPartyDeveloperStart + 33000)

/*! No Metal device is available to render the watermark. */
#define kFxGripError_WatermarkNoDevice		(kFxError_ThirdPartyDeveloperStart + 34000)
/*! The watermark render pass failed. */
#define kFxGripError_WatermarkRender		(kFxError_ThirdPartyDeveloperStart + 34001)

/*! The 3D Space subsystem found no scene to render. */
#define kFxGripError_SpaceMissingScene		(kFxError_ThirdPartyDeveloperStart + 35000)
/*! The 3D Space render pass failed. */
#define kFxGripError_SpaceRenderFailure		(kFxError_ThirdPartyDeveloperStart + 35001)

#endif
