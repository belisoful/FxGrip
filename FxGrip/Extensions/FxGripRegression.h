//
//  FxGripRegression.h
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripRegression_h
#define FxGripRegression_h

#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"


@interface FxGripRegression : FxGripExtension

- (BOOL)extLoadWithEffect:(nonnull id<FxGripTileableEffect>)effect;

@end



@interface FxGripTileableEffect (Regression)

@property (readonly, nullable, nonatomic) FxGripRegression* regression;

/*! YES when the plugin opts into the regression validation pass via the "regression"
	property; the loader gates on this (DEBUG builds only). */
@property (readonly, nonatomic) BOOL isRegression;

- (nonnull FxGripRegression*)newRegressionExtension;

@end

#endif
