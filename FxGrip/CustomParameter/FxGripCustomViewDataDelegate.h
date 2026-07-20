//
//  FxGripMutableParameter.h
//  PlugIn
//
//  Created by Apple on 10/22/18.
//  Copyright © 2019-2023 Apple Inc. All rights reserved.
//

#ifndef FxGripCustomViewDataDelegate_h
#define FxGripCustomViewDataDelegate_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>


// This is the protocol for Custom Data to hijack the standard api get/set bool, int, float, string, etc.
@protocol FxGripCustomViewDataDelegate

- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value;

@end

#endif
