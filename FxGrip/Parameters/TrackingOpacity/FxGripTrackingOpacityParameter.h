//
//  FxGripTrackingOpacityParameter.h
//  FxGrip
//

#ifndef FxGripTrackingOpacityParameter_h
#define FxGripTrackingOpacityParameter_h

#import "FxGripPercentParameter.h"

// The value the framework drives the slider to while an analysis pass runs, and its resting
// value at every other time.
#define kFxGripTrackingOpacityAnalyzing	(0.0)
#define kFxGripTrackingOpacityResting	(1.0)

/*!
	@class      FxGripTrackingOpacityParameter
	@abstract   A read-only percent slider driven to 0% during an analysis pass.
	@discussion Introduced in FxGrip 1.0. The value rests at 100% and the framework drives it
				to 0% while an analysis pass runs. An effect links a layer's opacity to this
				parameter so the layer contributes nothing to the analyzed frame, which keeps
				host-drawn overlays (for example Final Cut Pro titles) out of the analysis.

				Creation adds the disabled and not-animatable flags: the value is framework
				driven, not user edited. The parameter is published so other parameters can
				link to it; the driver that lowers it during analysis pairs with the object
				tracker and the [[fxgrip-frame-analysis]] pass. This mirrors the FxFactory
				Tracking Opacity parameter.
*/
@interface FxGripTrackingOpacityParameter : FxGripPercentParameter

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif
