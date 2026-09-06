/*!
	@file       FxGripImageRefParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripImageRefParameter
	@abstract   The parameter model for a host image well that references another clip.
	@discussion Introduced in FxGrip 0.1.0. The class registers an image reference parameter. It exposes the referenced clip's start time and duration through FxTimingAPI_v4 and its drop-frame setting through FxTimingAPI_v5.
*/

#ifndef FxGripImageRefParameter_h
#define FxGripImageRefParameter_h

#import "FxGripParameter.h"


/*!
	@class		FxGripImageRefParameter
	@abstract	The parameter model for a host image reference well.
	@discussion	Introduced in FxGrip 0.1.0. The class registers an image reference parameter and reports the referenced clip's timing.
*/
@interface FxGripImageRefParameter : FxGripParameter

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the image reference parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*! @abstract YES when the referenced image includes upstream filters. */
- (BOOL)includeFilters;

// TimingAPI_v4
/*! @abstract The start time of the referenced clip through FxTimingAPI_v4. */
- (CMTime)startTime;
/*! @abstract The duration of the referenced clip through FxTimingAPI_v4. */
- (CMTime)durationTime;

// TimingAPI_v5
/*! YES when the image well's clip requires drop-frame timecode. Motion always reports NO; a
	Motion template running in Final Cut Pro reports the clip setting. NO on hosts without
	FxTimingAPI_v5. Introduced in FxGrip 0.1.0. */
- (BOOL)isDropFrame;

@end

#endif
