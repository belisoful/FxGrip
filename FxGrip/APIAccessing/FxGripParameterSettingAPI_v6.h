/*!
	@file       FxGripParameterSettingAPI_v6.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterSettingAPI_v6
	@abstract   The FxGrip wrapper for the host's FxParameterSettingAPI_v6.
	@discussion Introduced in FxGrip 0.1.0. The wrapper extends the v5 wrapper with the two methods
	            v6 adds, addFlags:toParameter: and removeFlags:fromParameter:. Both read the
	            current flags, adjust the named bits, and write the result through the v5 flag
	            setter. Every v5 method is inherited. The class mirrors the FxPlug 4 v6 protocol
	            version.
*/

#ifndef FxGripParameterSettingAPI_v6_h
#define FxGripParameterSettingAPI_v6_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameterSettingAPI_v5.h"

/*!
	@class		FxGripParameterSettingAPI_v6
	@abstract	FxGrip's wrapper around the host FxParameterSettingAPI_v6.
	@discussion	Introduced in FxGrip 0.1.0. Adds bitwise flag add and remove to the inherited v5
				wrapper, each reading the current flags before writing the adjusted set.
*/
@interface FxGripParameterSettingAPI_v6 : FxGripParameterSettingAPI_v5 <FxParameterSettingAPI_v6>

/*!
	@method     addFlags:toParameter:
	@abstract   Add the passed-in flags to the current parameter flags
	@param      flags   The new flags to add. Other flags will not be touched
	@param      parameterID     The parameter whose flags you want to add to.
	@result     Returns YES if it successfully added the flags to the parameter. Returns NO otherwise.
	@discussion Use this method to set one or more parameter flags without changing the value of other flags.
 */
- (BOOL)addFlags:(FxParameterFlags)flags
	 toParameter:(UInt32)parameterID;

/*!
	@method     removeFlags:fromParameter:
	@abstract   Remove the passed-in flags from the current parameter flags
	@param      flags   The new flags to remove. Other flags will not be touched
	@param      parameterID The ID of the parameter whose flags you wish to clear
	@result     Returns YES if the flags were successfully removed. Returns NO otherwise.
	@discussion Use this method to remove one or more paraemeter flags without changing the value of other flags.
 */
- (BOOL)removeFlags:(FxParameterFlags)flags
	 fromParameter:(UInt32)parameterID;

@end


#endif /* FxGripParameterSettingAPI_v6_h */

