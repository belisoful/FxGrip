/*!
	@file       FxGripCustomDataClasses.h
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCustomDataClasses
	@abstract   Protocol that reports the secure-coding classes of a custom parameter's stored objects.
	@discussion Introduced in FxGrip 0.1.0. The host archives and unarchives custom parameter values
	            on the plugin's behalf. A custom data class conforms to this protocol to supply the
	            allow-list of classes the host uses to decode the value.
*/

#ifndef FxGripCustomDataClasses_h
#define FxGripCustomDataClasses_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>

/*!
	@protocol	FxGripCustomDataClasses
	@abstract	Reports the secure-coding classes of the objects a custom parameter stores.
	@discussion	Introduced in FxGrip 0.1.0. The host needs the member classes of a custom parameter
				value to unarchive it from disk. A conforming class returns that class set.
*/
// This is the protocol for Custom Data to hijack the standard api get/set bool, int, float, string, etc.
@protocol FxGripCustomDataClasses

/*!
	@method     -classesForParameter
	@abstract   Returns the set of classes of the objects contained in the custom parameter with the given ID.
	@discussion When you make custom parameters and the host stores them for you, it needs to know
				the classes of the parameters to unarchive them from disk. This method returns the
				Objective-C set of classes of which they are members.
	@result     An NSSet of classes of the specified class.

 */
- (NSOrderedSet<Class>*)classesForParameter;

@end

#endif
