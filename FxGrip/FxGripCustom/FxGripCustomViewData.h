//
//  FxGripMutableParameter.h
//  PlugIn
//
//  Created by Apple on 10/22/18.
//  Copyright © 2019-2023 Apple Inc. All rights reserved.
//

#ifndef FxGripCustomViewData_h
#define FxGripCustomViewData_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripCustomViewDataDelegate.h"

@protocol FxTileableEffectBase;


// This is the protocol for Custom Data to hijack the standard api get/set bool, int, float, string, etc.
@protocol FxGripCustomViewData


@property (assign) NSView*_Nullable parameterView;
@property (assign) id<FxTileableEffectBase>_Nullable parameterEffect;

@end

#endif
