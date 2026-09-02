//
//  FxGripTileableEffect+CustomUI.m
//  FxGrip
//

#import "FxGripTileableEffect+CustomUI.h"
#import "FxGripTileableEffect+Parameters.h"
#import "FxParameter.h"
#import "FxGrip_ARC.h"

@implementation FxGripTileableEffect (CustomUI)

- (NSView *_Nullable)createViewForParameterID:(UInt32)parameterID
{
	id parameter = self[(NSInteger)parameterID];
	if (![parameter respondsToSelector:@selector(newParameterView)]) {
		return nil;
	}
	NSView *view = [parameter newParameterView];
	if (view == nil) {
		NSLog(@"%s Error: parameter %u is flagged for custom UI and provides no view.", __func__, parameterID);
		return nil;
	}
	// A parameter that wraps its delegate view (the divider's box inside its container)
	// attaches the wrapped view itself; only an unattached parameter gets the returned one.
	if ([parameter respondsToSelector:@selector(attachCustomView:)]
		&& [parameter respondsToSelector:@selector(customView)]
		&& [parameter customView] == nil) {
		[parameter attachCustomView:view];
	}
	return view;
}

@end
