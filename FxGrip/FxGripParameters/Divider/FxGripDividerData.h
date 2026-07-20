//
//  FxHueSaturation.h
//  PlugIn
//
//  Created by Apple on 10/22/18.
//  Copyright © 2019-2023 Apple Inc. All rights reserved.
//

#ifndef FxGripDividerData_h
#define FxGripDividerData_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxCustomDataClasses.h"
#import "FxGripMutableParameter.h"
#import "FxGripCustomViewData.h"
#import "FxDivider.h"

/*!
	@class      FxGripInterpolatingDictionary
	@discussion This class is a NSMutableDictionary for Custom Values of a Custom Parameter.
				This can hold multiple different values and data.  It will interpolate between values that it knows how to interpolate
 				and copy everything else.  There is an array for keys that are exempt from interpolation.
 				The various Types of FxPlug data can be set without needing to regard translation through NSNumber.
				This also feeds various custom values to the Standard FxParameterRetrievalAPI-v6.
 */
@interface FxGripDividerData : NSObject <NSSecureCoding, NSCopying, FxGripMutableParameter, FxGripCustomViewData>


	@property (nonatomic, assign)  DividerSize percentWidth;
	@property (nonatomic, assign)  uint16 marginTop;
	@property (nonatomic, assign)  uint16 marginBottom;
	@property (nonatomic, assign)  uint16 parameterHeight;


+(instancetype)dataWithDictionary:(NSDictionary*)values;
- (instancetype)init;


// Set the width 0..1
- (BOOL)getFloatValue:(double*)floatValue;
- (BOOL)setFloatValue:(double)floatValue;

// sets the total high split between top and bottom
- (BOOL)getIntValue:(int*)intValue;
- (BOOL)setIntValue:(int)intValue;

@end

#endif
