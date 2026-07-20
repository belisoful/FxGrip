//
//  FxGripParameterSettingAPI_v6.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripParameterSettingAPI_v6_h
#define FxGripParameterSettingAPI_v6_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameterSettingAPI_v5.h"

/*!
	@interface  FxGripParameterRetrievalAPI_v6:
	@abstract   Initializes the API manager for your plug-in.
	@discussion Accesses the apis with error checking.

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

