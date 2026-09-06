/*!
	@file       FxGripParameterSettingAPI_v6.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterSettingAPI_v6
	@abstract   Implements the v6 flag additions over the v5 setting wrapper.
	@discussion Introduced in FxGrip 0.1.0. Each method reads the parameter's current flags through
	            the retrieval API, adjusts the named bits, and writes the result through the
	            inherited v5 flag setter.
*/

#import "FxGripParameterSettingAPI_v6.h"
#import "FxGripParameterFlags.h"
#import "FxGripTileableEffect.h"

/*!
	@abstract	FxGrip's wrapper around the host FxParameterSettingAPI_v6.
	@discussion	Introduced in FxGrip 0.1.0. Adds bitwise flag add and remove over the inherited v5
				wrapper.
*/
@implementation FxGripParameterSettingAPI_v6

/*!
	@method		addFlags:toParameter:
	@abstract	Adds the passed-in flags to the parameter's current flags.
	@param		flags	The flags to add; other flags are left unchanged.
	@param		parameterID	The parameter whose flags to add to.
	@return		YES when the current flags read and the write both succeed.
*/
- (BOOL)addFlags:(FxParameterFlags)flags toParameter:(UInt32)parameterID
{
	FxParameterFlags pflags = kFxParameterFlag_DEFAULT;
	if(![self.effect.apiManager.paramGetAPIv6 getParameterFlags:&pflags fromParameter:parameterID])
		return NO;
	pflags |= flags;
	
	return [self setParameterFlags:pflags toParameter:parameterID];
}

/*!
	@method		removeFlags:fromParameter:
	@abstract	Removes the passed-in flags from the parameter's current flags.
	@param		flags	The flags to remove; other flags are left unchanged.
	@param		parameterID	The parameter whose flags to clear.
	@return		YES when the current flags read and the write both succeed.
*/
- (BOOL)removeFlags:(FxParameterFlags)flags fromParameter:(UInt32)parameterID
{
	FxParameterFlags pflags = kFxParameterFlag_DEFAULT;
	if(![self.effect.apiManager.paramGetAPIv6 getParameterFlags:&pflags fromParameter:parameterID])
		return NO;
	
	pflags &= ~flags;
	
	return [self setParameterFlags:pflags toParameter:parameterID];
}

@end
