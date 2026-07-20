//
//  NSString+Extension.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#ifndef NSView_FxGrip_h
#define NSView_FxGrip_h

#import <Foundation/Foundation.h>
#import <AppKit//NSView.h>
#import "FxGripTypes.h"

@interface NSView (FxGrip)

@property (readwrite, assign, nonatomic) FxParameterId parameterID;

@end

#endif
