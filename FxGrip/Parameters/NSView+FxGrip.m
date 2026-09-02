//
//  NSArray-Extension.m
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#import "NSView+FxGrip.h"
#import <objc/runtime.h>

#import "FxParameterFlags.h"

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
