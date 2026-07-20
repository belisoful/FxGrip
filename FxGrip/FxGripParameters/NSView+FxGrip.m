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

static char *FxViewParameterID = "FxParameterId";

- (void)setParameterID:(FxParameterId)paramID
{
	objc_setAssociatedObject(self, FxViewParameterID, [NSNumber numberWithInt:paramID], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (FxParameterId)parameterID
{
	NSNumber *pid = (NSNumber*)objc_getAssociatedObject(self, FxViewParameterID);
	if (pid != nil)
		return pid.intValue;
	return kFxParameterId_None;
}


@end
