/*!
	@file       FxGripDividerParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDividerParameter
	@abstract   Implements the horizontal divider custom parameter.
	@discussion Introduced in FxGrip 0.1.0. Creation builds a full-width custom parameter whose value
	            is an FxGripDividerData seeded from the declared configuration. The view is an
	            FxGripDividerBox attached as the data-push delegate, returned inside its sizing
	            container.
*/

#import "FxGripDividerParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripDividerData.h"
#import "FxGripDividerBox.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The horizontal divider custom parameter.
	@discussion	Introduced in FxGrip 0.1.0. Creation stores an FxGripDividerData value and adds the
				custom-UI, not-animatable, full-view-width, and no-state flags. */
@implementation FxGripDividerParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Divider;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Divider;
}

+ (NSSet<Class> *_Nullable)customValueClasses
{
	return [NSSet setWithObject:FxGripDividerData.class];
}

/*!
	@method		addParameter:toEffect:
	@abstract	Creates the divider custom parameter on the effect.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The declared configuration seeds the divider data. Creation
				adds the custom-UI, not-animatable, full-view-width, and no-state flags. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	id declared = parameter.parameterDefaultValue;
	NSDictionary *defaultValue = [declared isKindOfClass:NSDictionary.class] ? declared : @{};

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: @""
					   parameterID: parameter.parameterID
					  defaultValue: [FxGripDividerData dataWithDictionary:defaultValue]
					parameterFlags: parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI
									| kFxParameterFlag_NOT_ANIMATABLE
									| kFxParameterFlag_USE_FULL_VIEW_WIDTH
									| kFxParameterFlag_NOSTATE];
}

/*!
	@method		newParameterView
	@abstract	Creates the divider box, seeds it from the declared configuration, and returns its container.
	@return		The box's full-width container view.
	@discussion	Introduced in FxGrip 0.1.0. The box is attached as the custom view, so the parameter
				drives it directly through the data-push delegate. */
- (NSView *_Nullable)newParameterView
{
	FxGripDividerBox *box = [FxGripDividerBox.alloc initWithFrame:NSMakeRect(0, 22, 100, 1)];
	id declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		// The configuration declares width/margintop/marginbottom; the data class reads
		// that shape and the box reads the data class.
		[box updateFromCustomData:[FxGripDividerData dataWithDictionary:declared]];
	}
	// The box is the data-push delegate; the returned container wraps it, so the
	// parameter attaches the box itself and the view host leaves it in place.
	[self attachCustomView:box];
	return box.topView;
}

@end
