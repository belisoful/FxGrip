/*!
	@file       FxGripPathParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPathParameter
	@abstract   The parameter model for a host path picker.
	@discussion Introduced in FxGrip 0.1.0. The class registers a path picker whose value is an FxPathID. It reads the path identifier at a render time. The class conforms to FxGripStateParameter and encodes the identifier into the FxPlug plugin-state coder.
*/

#ifndef FxGripPathParameter_h
#define FxGripPathParameter_h

#import "FxGripParameter.h"


/*!
	@class		FxGripPathParameter
	@abstract	The parameter model for a host path picker.
	@discussion	Introduced in FxGrip 0.1.0. The class maps the declared configuration to a host path picker and reads its path identifier at a render time.
*/
@interface FxGripPathParameter : FxGripParameter <FxGripStateParameter>

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the path picker with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method		valueAtTime:
	@abstract	Reads the path identifier at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The path identifier, or nil when the retrieval API is unavailable. */
- (FxPathID _Nullable)valueAtTime:(CMTime)renderTime;
/*! @abstract Encodes the path identifier into the plugin-state coder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
