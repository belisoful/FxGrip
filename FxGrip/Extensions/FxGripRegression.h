//
//  FxGripRegression.h
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripRegression_h
#define FxGripRegression_h

#import "FxExtension.h"
#import "FxTileableEffectBase.h"


@interface FxGripRegression : FxExtension

- (BOOL)extLoadWithEffect:(nonnull id<FxTileableEffectBase>)effect;

@end



@interface FxTileableEffectBase (Regression)

@property (readonly, nullable, nonatomic) FxGripRegression* regression;

/*! YES when the plugin opts into the regression validation pass via the "regression"
	property; the loader gates on this (DEBUG builds only). */
@property (readonly, nonatomic) BOOL isRegression;

- (nonnull FxGripRegression*)newRegressionExtension;

@end

#endif
