/*!
	@file       FxGripParameterCreationAPI_v6.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterCreationAPI_v6
	@abstract   The FxGrip wrapper for the host's FxParameterCreationAPI_v6.
	@discussion Introduced in FxGrip 0.1.0. The wrapper subclasses the v5 wrapper and adds the one
	            method v6 introduces, a tagged popup menu whose entries carry stable tags so
	            reordering does not break saved projects. Every v5 method is inherited. It mirrors
	            FxPlug protocol version 6.
*/

#ifndef FxGripParameterCreationAPI_v6_h
#define FxGripParameterCreationAPI_v6_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameterCreationAPI_v5.h"

/*!
	@interface  FxGripParameterCreationAPI_v6
	@abstract   The FxGrip wrapper for the host's FxParameterCreationAPI_v6.
	@discussion Introduced in FxGrip 0.1.0. Extends the v5 wrapper with the one method v6 adds:
				addTaggedPopupMenuWithName:parameterID:defaultValue:menuEntries:parameterFlags:,
				a popup whose entries carry stable tags so reordering does not break saved
				projects. Like the other creation methods, it preprocesses the parameter through
				the extensions and posts the parameter-add notification. Every v5 method is
				inherited.
*/
@interface FxGripParameterCreationAPI_v6 : FxGripParameterCreationAPI_v5 <FxParameterCreationAPI_v6>

/*!
	@method     addTaggedPopupMenuWithName:parameterID:defaultValue:menuEntries:parameterFlags:
	@abstract   Adds a popup menu whose entries carry stable tags.
*/
- (BOOL)addTaggedPopupMenuWithName:(NSString *)name
					   parameterID:(UInt32)parameterID
					  defaultValue:(UInt32)defaultValue
					   menuEntries:(NSArray<FxTaggedMenuEntry *> *)entries
					parameterFlags:(FxParameterFlags)flags;

@end

#endif /* FxGripParameterCreationAPI_v6_h */
