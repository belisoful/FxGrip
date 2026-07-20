//
//  FxGripParameterCreationAPI_v5.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripParameterCreationAPI_v5_h
#define FxGripParameterCreationAPI_v5_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripCommonAPI.h"

/*!
	@interface  FxGripParameterCreationAPI_v5:
	@abstract   Initializes the API manager for your plug-in.
	@discussion Accesses the apis with error checking.

 */

@interface FxGripParameterCreationAPI_v5 : FxGripCommonAPI<FxParameterCreationAPI_v5>

	@property (assign, readonly, nullable) id<FxParameterCreationAPI_v5> api;
	@property (retain, readonly, nonnull) NSMutableArray<NSNumber*> *subGroupStack;

- (nullable instancetype)initWithAPI:(id<FxParameterCreationAPI_v5> _Nonnull)api effect:(nonnull id<FxTileableEffectBase>)effect;

- (BOOL)addAngleSliderWithName:(nonnull NSString *)name
				   parameterID:(UInt32)parameterID
				defaultDegrees:(double)defaultDegrees
		   parameterMinDegrees:(double)minDegrees
		   parameterMaxDegrees:(double)maxDegrees
				parameterFlags:(FxParameterFlags)flags;

- (BOOL)addColorParameterWithName:(nonnull NSString *)name
					  parameterID:(UInt32)parameterID
					   defaultRed:(double)red
					 defaultGreen:(double)green
					  defaultBlue:(double)blue
					 defaultAlpha:(double)alpha
				   parameterFlags:(FxParameterFlags)flags;

- (BOOL)addColorParameterWithName:(nonnull NSString *)name
					  parameterID:(UInt32)parameterID
					   defaultRed:(double)red
					 defaultGreen:(double)green
					  defaultBlue:(double)blue
				   parameterFlags:(FxParameterFlags)flags;

- (BOOL)addCustomParameterWithName:(nonnull NSString *)name 				   parameterID:(UInt32)parameterID
					  defaultValue:(nonnull NSObject<NSSecureCoding,NSCopying> *)defaultValue
					parameterFlags:(FxParameterFlags)flags;

- (BOOL)addFloatSliderWithName:(nonnull NSString *)name
				   parameterID:(UInt32)parameterID
				  defaultValue:(double)defaultValue
				  parameterMin:(double)min
				  parameterMax:(double)max
					 sliderMin:(double)sliderMin
					 sliderMax:(double)sliderMax
						 delta:(double)sliderDelta
				parameterFlags:(FxParameterFlags)flags;


- (BOOL)addFontMenuWithName:(nonnull NSString *)name
				parameterID:(UInt32)parameterID
				   fontName:(nonnull NSString *)fontName
			 parameterFlags:(FxParameterFlags)flags;


- (BOOL)addGradientWithName:(nonnull NSString *)name
				parameterID:(UInt32)parameterID
			 parameterFlags:(FxParameterFlags)flags;

- (BOOL)addHelpButtonWithName:(nonnull NSString *)name
				  parameterID:(UInt32)parameterID
					 selector:(nonnull SEL)selector
			   parameterFlags:(FxParameterFlags)flags;

- (BOOL)addHistogramWithName:(nonnull NSString *)name
				 parameterID:(UInt32)parameterID
			  parameterFlags:(FxParameterFlags)flags;

- (BOOL)addImageReferenceWithName:(nonnull NSString *)name
					  parameterID:(UInt32)parameterID
				   parameterFlags:(FxParameterFlags)flags;

- (BOOL)addIntSliderWithName:(nonnull NSString *)name
				 parameterID:(UInt32)parameterID
				defaultValue:(int)defaultValue
				parameterMin:(int)min
				parameterMax:(int)max
				   sliderMin:(int)sliderMin
				   sliderMax:(int)sliderMax
					   delta:(int)sliderDelta
			  parameterFlags:(FxParameterFlags)flags;


- (BOOL)addPathPickerWithName:(nonnull NSString *)name
				  parameterID:(UInt32)parameterID
			   parameterFlags:(FxParameterFlags)flags;

- (BOOL)addPercentSliderWithName:(nonnull NSString *)name
					 parameterID:(UInt32)parameterID
					defaultValue:(double)defaultValue
					parameterMin:(double)min
					parameterMax:(double)max
					   sliderMin:(double)sliderMin
					   sliderMax:(double)sliderMax
						   delta:(double)sliderDelta
				  parameterFlags:(FxParameterFlags)flags;

- (BOOL)addPointParameterWithName:(nonnull NSString *)name
					  parameterID:(UInt32)parameterID
						 defaultX:(double)defaultX
						 defaultY:(double)defaultY
				   parameterFlags:(FxParameterFlags)flags;

- (BOOL)addPopupMenuWithName:(nonnull NSString *)name
				 parameterID:(UInt32)parameterID
				defaultValue:(UInt32)defaultValue
				 menuEntries:(nonnull NSArray *)entries
			  parameterFlags:(FxParameterFlags)flags;

- (BOOL)addPushButtonWithName:(nonnull NSString *)name
				  parameterID:(UInt32)parameterID
					 selector:(nonnull SEL)selector
			   parameterFlags:(FxParameterFlags)flags;

- (BOOL)addStringParameterWithName:(nonnull NSString *)name
					   parameterID:(UInt32)parameterID
					  defaultValue:(nonnull NSString *)defaultValue
					parameterFlags:(FxParameterFlags)flags;

- (BOOL)addToggleButtonWithName:(nonnull NSString *)name
					parameterID:(UInt32)parameterID
				   defaultValue:(BOOL)defaultValue
				 parameterFlags:(FxParameterFlags)flags;

- (BOOL)endParameterSubGroup;


- (BOOL)startParameterSubGroup:(nonnull NSString *)name
				   parameterID:(UInt32)parameterID
				parameterFlags:(FxParameterFlags)flags;

@end


#endif /* FxGripParameterCreationAPI_v5_h */

