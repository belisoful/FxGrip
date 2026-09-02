//
//  FxGripAnalyzerParameter.h
//  FxGrip
//

#ifndef FxGripAnalyzerParameter_h
#define FxGripAnalyzerParameter_h

#import "FxGripPushButtonParameter.h"

// The button's location key selects the analysis image path (GPU is the default). The
// backward key runs the pass in reverse. The title key reuses the push-button title key.
#define kFxGripAnalyzerKey_Location		@"analysisLocation"
#define kFxGripAnalyzerKey_Backward		@"analyzeBackward"
#define kFxGripAnalyzerDefaultTitle		@"Analyze"

/*!
	@class      FxGripAnalyzerParameter
	@abstract   A button that starts the effect's frame-analysis pass.
	@discussion Introduced in FxGrip 1.0. The button starts a forward analysis of the source
				clip when clicked, driving the FxGrip analysis pass that stores per-frame
				records in the effect's analysisData. The configuration sets the button title
				(default "Analyze"), the analysis location (GPU or CPU), and whether the pass
				runs backward.

				The click routes through -[FxGripTileableEffect parameterClicked:] to this
				parameter's defaultParameterAction, which calls startForwardAnalysisAtLocation:
				(or the backward variant). The effect must conform to the FxPlug FxAnalyzer
				protocol; when it does not, the click does nothing. This wraps the
				[[fxgrip-frame-analysis]] subsystem in the FxFactory Analyzer button shape.
*/
@interface FxGripAnalyzerParameter : FxGripPushButtonParameter

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;
- (void)defaultParameterAction;

@end

#endif
