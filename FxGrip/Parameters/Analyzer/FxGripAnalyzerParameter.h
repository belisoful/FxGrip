/*!
	@file       FxGripAnalyzerParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripAnalyzerParameter
	@abstract   A push button that starts the effect's frame-analysis pass.
	@discussion Introduced in FxGrip 0.1.0. Clicking the button drives the FxGrip analysis pass,
	            which stores per-frame records in the effect's analysisData. The configuration sets
	            the button title, the analysis location, and the pass direction. The click reaches
	            defaultParameterAction, which starts the forward or backward pass. The effect must
	            conform to the FxPlug FxAnalyzer protocol for the click to act.
*/

#ifndef FxGripAnalyzerParameter_h
#define FxGripAnalyzerParameter_h

#import "FxGripPushButtonParameter.h"

// The button's location key selects the analysis image path (GPU is the default). The
// backward key runs the pass in reverse. The title key reuses the push-button title key.

/*! The configuration key selecting the analysis image path; GPU is the default. */
#define kFxGripAnalyzerKey_Location		@"analysisLocation"
/*! The configuration key that runs the analysis pass in reverse. */
#define kFxGripAnalyzerKey_Backward		@"analyzeBackward"
/*! The button title used when the configuration and parameter name supply none. */
#define kFxGripAnalyzerDefaultTitle		@"Analyze"

/*!
	@class      FxGripAnalyzerParameter
	@abstract   A button that starts the effect's frame-analysis pass.
	@discussion Introduced in FxGrip 0.1.0. The button starts a forward analysis of the source
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

/*!
	@method		parameterTypeString
	@abstract	The registry type string that maps a declaration to this parameter class.
	@return		kFxParameterType_Analyzer. */
+ (nullable NSString*)parameterTypeString;

/*!
	@method		parameterType
	@abstract	The parameter type enumerator for this class.
	@return		FxParameterType_Analyzer. */
+ (FxParameterType)parameterType;

/*!
	@method		addParameter:toEffect:
	@abstract	Creates the analyzer push button on the effect.
	@param		parameter	The declaration dictionary supplying the title, ID, and flags.
	@param		effect		The effect host that receives the parameter.
	@return		YES when the host creates the parameter; NO when a declared selector lacks the click prefix.
	@discussion	Introduced in FxGrip 0.1.0. The title falls back to the parameter name, then to
				"Analyze". */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method		defaultParameterAction
	@abstract	Starts the effect's analysis pass in the configured direction.
	@discussion	Introduced in FxGrip 0.1.0. The action does nothing when the host is not an
				FxGripTileableEffect or reports no analysis. */
- (void)defaultParameterAction;

@end

#endif
