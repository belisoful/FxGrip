//
//  FxGripPointParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripPointParameter_h
#define FxGripPointParameter_h

#import "FxParameter.h"
#import "FxGripPointOptions.h"


/*!
	@class      FxGripPointParameter
	@abstract   A host point parameter with FxGripPointOptions design-time options.
	@discussion The value is the host's X and Y. The declaration's option keys (see
				FxGripPointOptions.h) are parsed once into options, which an effect passes to
				FxGripPointOSC to draw and constrain the point's on-screen control.
*/
@interface FxGripPointParameter : FxParameter <FxStateParameter>

/*! The parsed design-time options; the documented defaults when the declaration sets none. */
@property (readonly, nonnull) FxGripPointOptions *options;

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

- (FxGripPoint)valueAtTime:(CMTime)renderTime;
- (void)setValue:(FxGripPoint*_Nullable)value atTime:(CMTime)time;
- (void)setXValue:(double)xValue YValue:(double)yValue atTime:(CMTime)time;
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
