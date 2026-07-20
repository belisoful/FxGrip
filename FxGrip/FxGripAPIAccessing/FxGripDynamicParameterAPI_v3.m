//
//  MasterFXAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//


#import "FxGripDynamicParameterAPI_v3.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxTileableEffectBase.h"
//#import "GuruFxTileableEffect+Extensions.h"
#import "FxAPINotifications.h"

@implementation FxGripDynamicParameterAPI_v3

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPI:(id<FxDynamicParameterAPI_v3> _Nonnull)api
								effect:(id<FxTileableEffectBase>)effect
{
	self = [super initWithEffect:effect];
	
	if (self != nil)
	{
		_api = api;
	}
	return self;
}

/*!
	@method     parameterCount
	@abstract   Returns the number of parameters your plugin currently has
*/
- (UInt32)parameterCount
{
	return [_api parameterCount];
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
- (UInt32)parameterIDAtIndex:(UInt32)index
{
	return [_api parameterIDAtIndex:index];
}

/*!
	@method     removeParameter:
	@abstract   Removes the parameter with the passed-in ID
	@param      parameterID the ID (not index) of the parameter you wish to remove
	@discussion Removes the parameter with the passed-in ID from your plugin's list of parameters.
				Returns any errors which it encountered.
*/
- (NSError*)removeParameter:(UInt32)parameterID
{
	NSError *error = [_api removeParameter:parameterID];
	
	if (!error) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID)
			}
		};
		[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterRemoveName object:self.effect userInfo:userInfo reverse:YES];
	}
	
	return error;
}

/*!
	@method     parameter:name:
	@abstract   Get a parameter's name
*/
- (NSError*)parameter:(UInt32)parameterID
				 name:(NSString**)parameterName
{
	NSError *error = [_api parameter:parameterID name:parameterName];
	
	if(!error) {
		NSMutableDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Name: *parameterName
			}.mutableCopy
		}.mutableCopy;
		[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterGetNameName object:self.effect userInfo:userInfo];
		*parameterName = userInfo.fxParameter.parameterName;
	}
	
	return error;
}

/*!
	@method     setParameter:name:
	@abstract   Set a parameter's name
*/
- (NSError*)setParameter:(UInt32)parameterID
					name:(NSString*)newName
{
	
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_Name: newName
		}.mutableCopy
	}.mutableCopy;
	
	id nObject = self.effect[parameterID];
	
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetNamePreName object:nObject userInfo:userInfo];
	newName = userInfo.fxParameter.parameterName;
	
	userInfo.parameterID = parameterID;
	userInfo.mutableFxParameter.parameterID = parameterID;
	
	if (userInfo.fxError) {
		return userInfo.fxError;
	}
	userInfo.fxParameter = userInfo.fxParameter.copy;
	NSError *error = [_api setParameter:parameterID name:newName];
	if (error) {
#if DEBUG
		NSLog(@"%@", error);
#endif
	} else {
		[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetNameName object:nObject userInfo:userInfo.copy];
	}
	return error;
}

/*!
	@method     parameter:floatMinimum:maximum:sliderMinimum:sliderMaximum:
	@abstract   Get a parameter's bounds as floating point values
*/
- (NSError*)parameter:(UInt32)parameterID
		 floatMinimum:(double*)min
			  maximum:(double*)max
		sliderMinimum:(double*)sliderMin
		sliderMaximum:(double*)sliderMax
{
	
	return [_api parameter:parameterID
			  floatMinimum:min
				   maximum:max
		     sliderMinimum:sliderMin
		  	 sliderMaximum:sliderMax];
}

/*!
	@method     setParameter:floatMinimum:maximum:sliderMinimum:sliderMaximum:
	@abstract   Set a parameter's bounds using floating point values
*/
- (NSError*)setParameter:(UInt32)parameterID
			floatMinimum:(double)min
				 maximum:(double)max
		   sliderMinimum:(double)sliderMin
		   sliderMaximum:(double)sliderMax
{
	NSError *error = [_api setParameter:parameterID
				 floatMinimum:min
					  maximum:max
			 	sliderMinimum:sliderMin
			 	sliderMaximum:sliderMax];
	
	if(!error) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Minimum: @(min),
				kFxParameterProperty_Maximum: @(max),
				kFxParameterProperty_SliderMinimum: @(sliderMin),
				kFxParameterProperty_SliderMaximum: @(sliderMax)
			}
		};
		[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetFloatBoundsName object:self.effect userInfo:userInfo];
	}
	return error;
}

/*!
	@method     parameter:intMinimum:maximum:sliderMinimum:sliderMaximum:
	@abstract   Get a parameter's bounds as integer values
*/
- (NSError*)parameter:(UInt32)parameterID
		   intMinimum:(int *)min
			  maximum:(int *)max
		sliderMinimum:(int *)sliderMin
		sliderMaximum:(int *)sliderMax
{
	return [_api parameter:parameterID
				intMinimum:min
				   maximum:max
			 sliderMinimum:sliderMin
			 sliderMaximum:sliderMax];
}

/*!
	@method     setParameter:intMinimum:maximum:sliderMinimum:sliderMaximum:
	@abstract   Set a parameter's bounds using integer values
*/
- (NSError*)setParameter:(UInt32)parameterID
			  intMinimum:(int)min
				 maximum:(int)max
		   sliderMinimum:(int)sliderMin
		   sliderMaximum:(int)sliderMax
{
	NSError *error = [_api setParameter:parameterID
				   intMinimum:min
					  maximum:max
				sliderMinimum:sliderMin
				sliderMaximum:sliderMax];
	
	if(!error) {
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Minimum: @(min),
				kFxParameterProperty_Maximum: @(max),
				kFxParameterProperty_SliderMinimum: @(sliderMin),
				kFxParameterProperty_SliderMaximum: @(sliderMax)
			}
		};
		[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetIntBoundsName object:self.effect userInfo:userInfo];
	}
	return error;
}

/*!
	@method     setPopupMenuParameter:entries:defaultValue:
	@abstract   Set the menu entries in a popup menu
*/
- (NSError*)setPopupMenuParameter:(UInt32)parameterID
						  entries:(NSArray<NSString*>*)newEntries
					 defaultValue:(UInt32)defaultIndex
{
	NSMutableDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_MenuItems:newEntries,
				kFxParameterProperty_Default: @(defaultIndex)
			}.mutableCopy
		}.mutableCopy;
	
	id nObject = self.effect[parameterID];
	
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetMenuPreName object:nObject userInfo:userInfo];
	
	userInfo.parameterID = parameterID;
	userInfo.mutableFxParameter.parameterID = parameterID;
	
	if (userInfo.fxError) {
		return userInfo.fxError;
	}
	NSDictionary *param = userInfo.fxParameter = userInfo.mutableFxParameter.copy;
	NSError *error = [_api setPopupMenuParameter:parameterID
										 entries:param.parameterMenuItems
									defaultValue:[param.parameterDefaultValue intValue]];
	if (error) {
#if DEBUG
		NSLog(@"%@", error);
#endif
	} else {
		// @todo self.effect.notify
		[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetMenuName object:nObject userInfo:userInfo.copy];
	}
	return error;
}

/*!
	 @method     setAsDefaultsAtTime:withError:
	 @param      time    - The time that contains the defaults you wish to set
	 @param      error   - A pointer to an NSError*. It will be filled out if the function
						   returns NO
	 @abstract   Tell the host app that the settings at the given time should be considered
				 the default settings for this parameter. If anything goes wrong, the return
				 value will be "NO" and if error is non-NULL, it will point to an error explaining
				 the problem.
 */
- (BOOL)setAsDefaultsAtTime:(CMTime)time
				  withError:(NSError**)error
{
	return [_api setAsDefaultsAtTime:(CMTime)time
						   withError:(NSError**)error];
}



@end
