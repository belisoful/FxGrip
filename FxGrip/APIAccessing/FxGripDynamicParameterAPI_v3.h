/*!
	@file       FxGripDynamicParameterAPI_v3.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDynamicParameterAPI_v3
	@abstract   The FxGrip wrapper for the host's FxDynamicParameterAPI_v3.
	@discussion Introduced in FxGrip 0.1.0. The wrapper forwards each dynamic-parameter call to the
	            host API and posts an FxGrip notification around the calls that change a parameter,
	            so extensions observe removals, name changes, bounds changes, and menu changes. It
	            mirrors FxPlug protocol version 3.
*/

#ifndef FxGripDynamicParameterAPI_v3_h
#define FxGripDynamicParameterAPI_v3_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripCommonAPI.h>

/*!
	@class		FxGripDynamicParameterAPI_v3
	@abstract	Wraps the host dynamic-parameter API and notifies FxGrip of parameter changes.
	@discussion	Introduced in FxGrip 0.1.0. The plug-in creates and removes parameters outside its
				-addParameters method and reads or writes parameter properties, such as the minimum
				and maximum values, at run time. Each mutating call posts an FxGrip notification
				after the host call succeeds. The host calls this API only in FxPlug 4 or later
				plug-ins.
*/
@interface FxGripDynamicParameterAPI_v3 : FxGripCommonAPI<FxDynamicParameterAPI_v3>

	/*! The wrapped host dynamic-parameter API. */
	@property (assign, readonly) id<FxDynamicParameterAPI_v3> _Nonnull api;

/*! @abstract Wraps a host dynamic-parameter API for an effect. */
- (nullable instancetype)initWithAPI:(id<FxDynamicParameterAPI_v3> _Nonnull)api effect:(nonnull id<FxGripEffectHost>)effect;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

