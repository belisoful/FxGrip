/*!
	@file       FxGripParameterCreationAPI_v5.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterCreationAPI_v5
	@abstract   The FxGrip wrapper for the host's FxParameterCreationAPI_v5.
	@discussion Introduced in FxGrip 0.1.0. Each add method builds the parameter's payload, sends it
	            through the extension preprocess step, forwards it to the host creation API, and
	            posts the parameter-add notification. The subgroup methods maintain a stack so a new
	            parameter records its parent group. It mirrors FxPlug protocol version 5.
*/

#ifndef FxGripParameterCreationAPI_v5_h
#define FxGripParameterCreationAPI_v5_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripCommonAPI.h"

/*!
	@class		FxGripParameterCreationAPI_v5
	@abstract	Wraps the host parameter-creation API and notifies FxGrip of each added parameter.
	@discussion	Introduced in FxGrip 0.1.0. The add methods mirror Apple's FxParameterCreationAPI_v5
				method for method. Each one packages the parameter's properties, runs the extension
				preprocess step that lets observers amend or reject the parameter, calls the host
				API, and posts FxGripNotifyAPI_ParameterAddName on success. startParameterSubGroup:
				pushes the group ID onto subGroupStack and endParameterSubGroup pops it, so the
				parent ID travels with each parameter.
*/

@interface FxGripParameterCreationAPI_v5 : FxGripCommonAPI<FxParameterCreationAPI_v5>

	/*! The wrapped host creation API. */
	@property (assign, readonly, nullable) id<FxParameterCreationAPI_v5> api;
	/*! The stack of open subgroup IDs; the last entry is the parent for the next parameter, with @0 as the root floor. */
	@property (retain, readonly, nonnull) NSMutableArray<NSNumber*> *subGroupStack;

/*! @abstract Wraps a host creation API for an effect. */
- (nullable instancetype)initWithAPI:(id<FxParameterCreationAPI_v5> _Nonnull)api effect:(nonnull id<FxGripEffectHost>)effect;

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

