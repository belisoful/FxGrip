//
//  FxGripMutableParameter.h
//  PlugIn
//
//  Created by Apple on 10/22/18.
//  Copyright © 2019-2023 Apple Inc. All rights reserved.
//

#ifndef FxGripCustomDataClasses_h
#define FxGripCustomDataClasses_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>

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
