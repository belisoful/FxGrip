//
//  NSString+Extension.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#ifndef FXBox_h
#define FXBox_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FxGripCustomViewDataDelegate.h"
#import "FxGripDividerParameter.h"

@interface FXBox : NSBox <FxGripCustomViewDataDelegate>

@property (nonatomic, strong) NSView *topView;

@property (nonatomic, assign) FxGripDividerSize percentWidth;
@property (nonatomic, assign) uint16 marginTop;
@property (nonatomic, assign) uint16 marginBottom;
@property (nonatomic, assign) uint16 parameterHeight;

@end

#endif
