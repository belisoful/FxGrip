//
//  FxGripDividerParameter.m
//  FxGrip
//

#import "FxGripDividerParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripDividerData.h"
#import "FXBox.h"
#import "FxGrip_ARC.h"

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

- (NSView *_Nullable)newParameterView
{
	FXBox *box = [FXBox.alloc initWithFrame:NSMakeRect(0, 22, 100, 1)];
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
