//
//  FxGripToggle.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
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

- (nonnull FxGripRegression*)newRegressionExtension;

@end

#endif
