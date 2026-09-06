/*!
	@file       FxGripParameterGroupingAPI_v1.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterGroupingAPI_v1
	@abstract   Implements the parameter subgroup queries against the effect's parameter model.
	@discussion Introduced in FxGrip 0.1.0. Each query resolves the parameter through the effect
	            and inspects its FxGripSubParameters conformance for subgroup membership and
	            counts. Setting a parameter's subgroup is not supported.
*/

#import "FxGripParameterGroupingAPI_v1.h"
//#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTileableEffect.h"
#import "../Parameters/FxGripParameter.h"

/*!
	@abstract	FxGrip's implementation of the parameter grouping queries.
	@discussion	Introduced in FxGrip 0.1.0. Subgroup membership and counts read the parameter's
				FxGripSubParameters conformance; the subgroup type check uses the parameter-info
				API.
*/
@implementation FxGripParameterGroupingAPI_v1

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPI:(id<FxGripParameterGroupingAPI_v1> _Nullable)api
				   parameterInfoAPIv1:(id<FxGripParameterInfoAPI_v1>_Nullable)parameterInfoAPIv1 effect:(id<FxGripEffectHost>_Nonnull)effect
{
	self = [super initWithEffect:effect];
	
	if (self != nil)
	{
		_api = api;
		_parameterInfoAPIv1 = parameterInfoAPIv1;
	}
	return self;
}


/*! @abstract YES when the parameter's type is FxParameterType_Group. */
- (BOOL)isSubGroup:(FxParameterId)parameterID
{
	return [_parameterInfoAPIv1 parameterType:parameterID] == FxParameterType_Group;
}


/*! @abstract YES when the parameter conforms to FxGripSubParameters and holds at least one member. */
- (BOOL)hasSubParameters:(FxParameterId)parameterID
{
	id<FxGripParameter> param = self.effect[parameterID];
	if (!param) {
		return NO;
	}
	if (![param conformsToProtocol:@protocol(FxGripSubParameters)]) {
		return NO;
	}
	
	return ((id<FxGripSubParameters>)param).count > 0;
}

/*!
	@method     parameterSubCount
	@abstract   Returns the number of parameters in the SubGroup currently has
*/
- (UInt32)parameterSubCount:(FxParameterId)parameterID
{
	id<FxGripParameter> param = self.effect[parameterID];
	if (!param) {
		return NO;
	}
	if (![param conformsToProtocol:@protocol(FxGripSubParameters)]) {
		return NO;
	}
	return (UInt32)((id<FxGripSubParameters>)param).count;
	
	//return [_api parameterSubCount:parameterID];
}

/*!
	@method		parameterIDAtSubIndex:fromParameter:
	@abstract	Returns the ID of the subparameter at an index within a parameter.
	@param		index	The 0-based index into the parameter's subparameters.
	@param		parameterID	The parameter whose subparameters to index.
	@return		The subparameter's ID, or 0 when the parameter has no subparameter at the index.
*/
- (FxParameterId)parameterIDAtSubIndex:(UInt32)index fromParameter:(FxParameterId) parameterID
{
	id<FxGripParameter> param = self.effect[parameterID];
	if (!param) {
		return 0;
	}
	if (![param conformsToProtocol:@protocol(FxGripSubParameters)]) {
		return 0;
	}
	id<FxGripSubParameters> subGroup = (id<FxGripSubParameters>)param;
	if (index >= subGroup.count) {
		return 0;
	}
	return subGroup[index].parameterID;
	//return [_api parameterIDAtSubIndex:index fromParameter:parameterID];
}


/*!
	@method		getParameterSubGroup:
	@abstract	Returns the parent subgroup of a parameter.
	@param		parameterID	The parameter whose parent subgroup to return.
	@return		The parent subgroup's ID, or -1 when the parameter does not resolve.
*/
- (FxParameterId)getParameterSubGroup:(FxParameterId)parameterID
{
	id<FxGripParameter> param = self.effect[parameterID];
	if (!param) {
		return -1;
	}
	return param.parameterParentID;
}


/*! @abstract Setting a parameter's subgroup is not supported; always returns NO. */
- (BOOL)setParameterSubGroup:(FxParameterId)subGroupID toParameter:(FxParameterId)parameterID
{
	// Not supported
	return NO;
}

@end
