/*!
	@file       FxGripTrackingOpacityParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTrackingOpacityParameter
	@abstract   A read-only percent slider the framework drives to 0% during an analysis pass.
	@discussion Introduced in FxGrip 0.1.0. The parameter rests at 100% and the framework lowers
	            it to 0% while an analysis pass runs. An effect links a layer's opacity to the
	            parameter so the layer contributes nothing to the analyzed frame. Creation adds
	            the disabled and not-animatable flags because the value is framework driven. The
	            class mirrors the FxFactory Tracking Opacity parameter.
*/

#ifndef FxGripTrackingOpacityParameter_h
#define FxGripTrackingOpacityParameter_h

#import "FxGripPercentParameter.h"

/*! The value the framework drives the slider to while an analysis pass runs. */
#define kFxGripTrackingOpacityAnalyzing	(0.0)
/*! The slider's resting value at every time outside an analysis pass. */
#define kFxGripTrackingOpacityResting	(1.0)

/*!
	@class      FxGripTrackingOpacityParameter
	@abstract   A read-only percent slider driven to 0% during an analysis pass.
	@discussion Introduced in FxGrip 0.1.0. The value rests at 100% and the framework drives it
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

/*!
	@method		parameterTypeString
	@abstract	The registry type string that maps a declaration to this parameter class.
	@return		kFxParameterType_TrackingOpacity. */
+ (nullable NSString*)parameterTypeString;

/*!
	@method		parameterType
	@abstract	The parameter type enumerator for this class.
	@return		FxParameterType_TrackingOpacity. */
+ (FxParameterType)parameterType;

/*!
	@method		addParameter:toEffect:
	@abstract	Creates the tracking-opacity percent slider on the effect.
	@param		parameter	The declaration dictionary supplying name, ID, and default value.
	@param		effect		The effect host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The slider spans 0 to 1 and rests at 100% unless the
				declaration lowers the default. Creation adds the disabled and not-animatable
				flags. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif
