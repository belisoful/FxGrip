//
//  FxGripAnalyzerParameter.m
//  FxGrip
//

#import "FxGripAnalyzerParameter.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Analyze.h"
#import "FxGripAnalysis.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripParameterUtility.h"

@implementation FxGripAnalyzerParameter
{
	FxAnalysisLocation _location;
	BOOL _backward;
}

- (instancetype _Nullable)initWithDictionary:(NSDictionary*)dictionary effect:(nonnull id<FxGripEffectHost>)effect
{
	self = [super initWithDictionary:dictionary effect:effect];
	if (self != nil) {
		_location = kFxAnalysisLocation_GPU;
		NSNumber *location = dictionary[kFxGripAnalyzerKey_Location];
		if ([location isKindOfClass:NSNumber.class] && location.integerValue == kFxAnalysisLocation_CPU) {
			_location = kFxAnalysisLocation_CPU;
		}
		NSNumber *backward = dictionary[kFxGripAnalyzerKey_Backward];
		_backward = [backward isKindOfClass:NSNumber.class] && backward.boolValue;
	}
	return self;
}

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Analyzer;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Analyzer;
}

- (void)defaultParameterAction
{
	// The analysis category and the hasAnalysis guard both live on FxGripTileableEffect; a
	// host that is not that effect, or one that does not conform to FxAnalyzer, has no pass.
	if (![self.effect isKindOfClass:FxGripTileableEffect.class]) {
		return;
	}
	FxGripTileableEffect *effect = (FxGripTileableEffect*)self.effect;
	if (!effect.hasAnalysis) {
		return;
	}

	NSError *error = nil;
	BOOL started = _backward ? [effect startBackwardAnalysisAtLocation:_location error:&error]
							 : [effect startForwardAnalysisAtLocation:_location error:&error];
	if (!started && error != nil) {
		NSLog(@"%s Error: analysis failed to start: %@", __func__, error);
	}
}

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	// A declared "selector" hook keeps the "click" prefix requirement of the push button.
	NSString *declaredSelector = parameter.parameterSelector;
	if (declaredSelector && ![declaredSelector.lowercaseString hasPrefix:kFxParameterProperty_SelectorPrefix]) {
		return NO;
	}

	// The button title falls back to the parameter name, then to "Analyze".
	NSString *title = parameter[kFxParameterProperty_ButtonTitle];
	if (![title isKindOfClass:NSString.class] || title.length == 0) {
		title = parameter.parameterName;
	}
	if (title.length == 0) {
		title = kFxGripAnalyzerDefaultTitle;
	}

	SEL selector = NSSelectorFromString([FxGripParameterUtility clickSelectorNameForParameter:parameter.parameterID]);
	return [effect.apiManager.paramCreateAPIv5 addPushButtonWithName: title
														 parameterID: parameter.parameterID
															selector: selector
													  parameterFlags: parameter.parameterFlags];
}

@end
