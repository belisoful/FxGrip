//
//  FxGripParameterGroupingAPI_v1.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripParameterGroupingAPI_v1_h
#define FxGripParameterGroupingAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripTypes.h"
#import "FxGripCommonAPI.h"
#import "FxGripDynamicParameterAPI_v4.h"


#define FxPlugRootGroupID 0

/*!
	@protocol  FxParameterGroupingAPI_v1
	@abstract   Allows your plugin to access grouping information
	@discussion	This is for getting the parent SubGroup of a parameter and the parameters within a subgroup
*/

@protocol FxParameterGroupingAPI_v1 <NSObject>
- (BOOL)isSubGroup:(FxParameterId) parameterID;   // <-iow, can it act as a SubGroup Parameter?
- (BOOL)hasSubParameters:(FxParameterId) parameterID;   // <-does parameterID have 1 or more subparameters.

- (UInt32)parameterSubCount:(FxParameterId) parameterID;  //. <- indexes similar to dynamic parameter API
- (FxParameterId) parameterIDAtSubIndex:(UInt32) index fromParameter:(FxParameterId) parameterID;

-(FxParameterId)getParameterSubGroup:(FxParameterId) parameterID; //the ID of the SubGroup containing parameterID
-(BOOL)setParameterSubGroup:(FxParameterId)subGroupID toParameter:(FxParameterId) parameterID;
@end


/*!
	@interface  FxParameterGroupingAPI_v1
	@abstract   Allows your plugin to access grouping information
	@discussion For getting and setting the parent SubGroup of a parameter or geting the paremeters in a SubGroup
*/
@interface FxGripParameterGroupingAPI_v1 : FxGripCommonAPI<FxParameterGroupingAPI_v1>

	@property (assign, readonly) id<FxParameterGroupingAPI_v1> _Nonnull api;
	@property (strong, readonly) id<FxDynamicParameterAPI_v4> _Nullable dynamicParamAPIv4;
	//@property (assign, readonly) id<FxParameterGroupingAPI_v1> _Nonnull api;
		//  The FxParameterGroupingAPI_v1 is not created by apple yet.

- (nullable instancetype)initWithAPI:(id<FxParameterGroupingAPI_v1> _Nullable)api
				   dynamicParamAPIv4:(id<FxDynamicParameterAPI_v4>_Nullable)dynamicParamAPIv4 effect:(id<FxGripEffectHost>_Nonnull)effect;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

