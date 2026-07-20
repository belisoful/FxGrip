//
//  MasterFXAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//


#import "FxGripParameterGroupingAPI_v1.h"
//#import "NSDictionary+FxTileableEffect.h"
#import "FxTileableEffectBase.h"
#import "../Parameters/FxParameter.h"
//#import "GuruFxTileableEffect+Extensions.h"

@implementation FxGripParameterGroupingAPI_v1

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPI:(id<FxParameterGroupingAPI_v1> _Nullable)api
				   dynamicParamAPIv4:(id<FxDynamicParameterAPI_v4>_Nullable)dynamicParamAPIv4 effect:(id<FxTileableEffectBase>_Nonnull)effect
{
	self = [super initWithEffect:effect];
	
	if (self != nil)
	{
		_api = api;
		_dynamicParamAPIv4 = dynamicParamAPIv4;
	}
	return self;
}


- (BOOL)isSubGroup:(FxParameterId)parameterID
{
	return [_dynamicParamAPIv4 parameterType:parameterID] == FxParameterType_Group;
}


- (BOOL)hasSubParameters:(FxParameterId)parameterID
{
	id<FxParameter> param = self.effect[parameterID];
	if (!param) {
		return NO;
	}
	if (![param conformsToProtocol:@protocol(FxSubParameters)]) {
		return NO;
	}
	
	return ((id<FxSubParameters>)param).count > 0;
}

/*!
	@method     parameterSubCount
	@abstract   Returns the number of parameters in the SubGroup currently has
*/
- (UInt32)parameterSubCount:(FxParameterId)parameterID
{
	id<FxParameter> param = self.effect[parameterID];
	if (!param) {
		return NO;
	}
	if (![param conformsToProtocol:@protocol(FxSubParameters)]) {
		return NO;
	}
	return (UInt32)((id<FxSubParameters>)param).count;
	
	//return [_api parameterSubCount:parameterID];
}

/*!
	@method     parameterIDAtIndex:
	@abstract   Returns the ID of the parameter at the given index
	@param      index   The 0-based index of the parameter whose ID you wish to get
	@discussion During -addParameters: your plugin tells the host to create parameters. Later,
				while running, your plugin can create new parameters using the
				FxParameterCreationAPI (just like in -addParameters), or it can remove them
				using the -removeParameter: method of this protocol. Each parameter must have
				a unique ID within the plugin. This method allows you to retrieve the ID of a
				parameter at a given index in the list of parameters. The IDs need not be
				sequential or even increasing. You could for example have the following:
<pre>@textblock
				index   ID      parameter
				-----   --      ---------
				0       1       slider
				1       1000    checkbox
				2       10      popup menu
@/textblock</pre>
*/
	
- (FxParameterId)parameterIDAtSubIndex:(UInt32)index fromParameter:(FxParameterId) parameterID
{
	id<FxParameter> param = self.effect[parameterID];
	if (!param) {
		return 0;
	}
	if (![param conformsToProtocol:@protocol(FxSubParameters)]) {
		return 0;
	}
	id<FxSubParameters> subGroup = (id<FxSubParameters>)param;
	if (index >= subGroup.count) {
		return 0;
	}
	return subGroup[index].parameterID;
	//return [_api parameterIDAtSubIndex:index fromParameter:parameterID];
}


/*!
	 @method     getParameterSubGroup:withError:
	 @param      parameterID    - The parameter to return its parent SubGroup.
	 @abstract   This returns the Parent SubGroup of a particular parameterID.
 */
- (FxParameterId)getParameterSubGroup:(FxParameterId)parameterID
{
	id<FxParameter> param = self.effect[parameterID];
	if (!param) {
		return -1;
	}
	return param.parameterParentID;
}


- (BOOL)setParameterSubGroup:(FxParameterId)subGroupID toParameter:(FxParameterId)parameterID
{
	// Not supported
	return NO;
}

@end
