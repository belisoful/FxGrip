/*!
	@file       NSView+FxGrip.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     NSView+FxGrip
	@abstract   Implements the category that tags an NSView with its parameter ID.
	@discussion Introduced in FxGrip 0.1.0. The parameterID accessors read and write an
	            associated object keyed by a static address. A view with no stored value
	            reports kFxParameterId_None.
*/

#import "NSView+FxGrip.h"
#import <objc/runtime.h>

#import "FxGripParameterFlags.h"

/*!
	@abstract	The category that associates a parameter ID with an NSView.
	@discussion	Introduced in FxGrip 0.1.0. The parameter ID is stored as a retained associated
				object, so the view keeps the tag without a subclass.
*/
@implementation NSView (FxGrip)

static char *FxGripViewParameterID = "FxParameterId";

- (void)setParameterID:(FxParameterId)paramID
{
	objc_setAssociatedObject(self, FxGripViewParameterID, [NSNumber numberWithInt:paramID], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (FxParameterId)parameterID
{
	NSNumber *pid = (NSNumber*)objc_getAssociatedObject(self, FxGripViewParameterID);
	if (pid != nil)
		return pid.intValue;
	return kFxParameterId_None;
}


@end
