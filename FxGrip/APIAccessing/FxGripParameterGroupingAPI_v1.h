/*!
	@file       FxGripParameterGroupingAPI_v1.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterGroupingAPI_v1
	@abstract   The API that reports and edits a parameter's subgroup membership.
	@discussion Introduced in FxGrip 0.1.0. The API answers whether a parameter acts as a
	            subgroup, counts and indexes a subgroup's members, and reads the subgroup that
	            contains a parameter. FxGrip resolves the queries from its own parameter model,
	            because no FxPlug host vends a grouping API. FxGripParameterGroupingAPI_v1 (the
	            class) is the implementation.
*/

#ifndef FxGripParameterGroupingAPI_v1_h
#define FxGripParameterGroupingAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripTypes.h"
#import "FxGripCommonAPI.h"
#import "FxGripParameterInfoAPI_v1.h"


#define FxPlugRootGroupID 0

/*!
	@protocol	FxGripParameterGroupingAPI_v1
	@abstract	Read and write access to parameter subgroup relationships.
	@discussion	Introduced in FxGrip 0.1.0. The protocol reports the parent subgroup of a
				parameter and enumerates the parameters within a subgroup.
*/

@protocol FxGripParameterGroupingAPI_v1 <NSObject>
/*! YES when the parameter can act as a subgroup. */
- (BOOL)isSubGroup:(FxParameterId) parameterID;   // <-iow, can it act as a SubGroup Parameter?
/*! YES when the parameter holds one or more subparameters. */
- (BOOL)hasSubParameters:(FxParameterId) parameterID;   // <-does parameterID have 1 or more subparameters.

/*! The number of subparameters the parameter holds. */
- (UInt32)parameterSubCount:(FxParameterId) parameterID;  //. <- indexes similar to dynamic parameter API
/*! The ID of the subparameter at an index within a parameter, or 0 when none. */
- (FxParameterId) parameterIDAtSubIndex:(UInt32) index fromParameter:(FxParameterId) parameterID;

/*! The ID of the subgroup that contains the parameter. */
-(FxParameterId)getParameterSubGroup:(FxParameterId) parameterID; //the ID of the SubGroup containing parameterID
/*! Sets the parameter's parent subgroup. */
-(BOOL)setParameterSubGroup:(FxParameterId)subGroupID toParameter:(FxParameterId) parameterID;
@end


/*!
	@class		FxGripParameterGroupingAPI_v1
	@abstract	FxGrip's implementation of FxGripParameterGroupingAPI_v1.
	@discussion	Introduced in FxGrip 0.1.0. The class resolves grouping queries from the effect's
				parameter model and the parameter-info API. No FxPlug host vends a grouping API,
				so the wrapped api is nil in practice. Setting a parameter's subgroup is not
				supported and returns NO.
*/
@interface FxGripParameterGroupingAPI_v1 : FxGripCommonAPI<FxGripParameterGroupingAPI_v1>

	/*! The wrapped host grouping API, nil because no host vends one. */
	@property (assign, readonly) id<FxGripParameterGroupingAPI_v1> _Nonnull api;
	/*! The parameter-info API used to resolve parameter types. */
	@property (strong, readonly) id<FxGripParameterInfoAPI_v1> _Nullable parameterInfoAPIv1;
	//@property (assign, readonly) id<FxGripParameterGroupingAPI_v1> _Nonnull api;
		//  The FxGripParameterGroupingAPI_v1 is not created by apple yet.

/*!
	@method		initWithAPI:parameterInfoAPIv1:effect:
	@abstract	Initializes the grouping API wrapper.
	@param		api	The wrapped host grouping API, or nil.
	@param		parameterInfoAPIv1	The parameter-info API used to resolve parameter types.
	@param		effect	The effect host the API queries.
*/
- (nullable instancetype)initWithAPI:(id<FxGripParameterGroupingAPI_v1> _Nullable)api
				   parameterInfoAPIv1:(id<FxGripParameterInfoAPI_v1>_Nullable)parameterInfoAPIv1 effect:(id<FxGripEffectHost>_Nonnull)effect;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

