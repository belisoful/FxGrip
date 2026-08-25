//
//  FxTileableEffectBase+CustomUI.h
//  FxGrip
//

#ifndef FxTileableEffectBase_CustomUI_h
#define FxTileableEffectBase_CustomUI_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FxTileableEffectBase.h"

/*!
	@category   FxTileableEffectBase (CustomUI)
	@abstract   The custom parameter view host.
	@discussion Introduced in FxGrip 1.0. The base implements
				createViewForParameterID: but claims no protocol: a plugin with custom
				controls declares FxCustomParameterViewHost_v2 conformance on its own
				subclass, and a plugin without them advertises nothing to the host.

				The host application calls createViewForParameterID: during parameter
				setup for each parameter flagged kFxParameterFlag_CUSTOM_UI. The view
				comes from the runtime parameter instance's newParameterView, and the
				created view is attached to the parameter (attachCustomView:) so data
				pushes can reach it.
*/
@interface FxTileableEffectBase (CustomUI)

/*! Creates the custom view for a parameter; nil when the parameter's class provides
	none. The result is retained per the FxCustomParameterViewHost_v2 contract. */
- (NSView *_Nullable)createViewForParameterID:(UInt32)parameterID NS_RETURNS_RETAINED;

@end

#endif /* FxTileableEffectBase_CustomUI_h */
