//
//  FxHueSaturation.h
//  PlugIn
//
//  Created by Apple on 10/22/18.
//  Copyright © 2019-2023 Apple Inc. All rights reserved.
//

#ifndef FxGripInterpolatingDictionary_h
#define FxGripInterpolatingDictionary_h

#import "FxGripDictionary.h"

#define kInterpolatingDictionaryNonePrefix @"_"

/*!
	@class      FxGripInterpolatingDictionary
	@discussion This class is a NSMutableDictionary for Custom Values of a Custom Parameter.
				This can hold multiple different values and data.  It will interpolate between values that it knows how to interpolate
 				and copy everything else.  There is an array for keys that are exempt from interpolation.
 				The various Types of FxPlug data can be set without needing to regard translation through NSNumber.
				This also feeds various custom values to the Standard FxParameterRetrievalAPI-v6.
 */
@interface FxGripInterpolatingDictionary : FxGripDictionary <FxCustomParameterInterpolation_v2>

@end

#endif
