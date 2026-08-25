//
//  FxGripCustomCreationAPI_v1.h
//  FxGrip
//

#ifndef FxGripCustomCreationAPI_v1_h
#define FxGripCustomCreationAPI_v1_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripEffectHost.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@interface  FxGripCustomCreationAPI_v1
	@abstract   Creates FxGrip's custom parameters in the style of Apple's creation APIs.
	@discussion Introduced in FxGrip 1.0. The counterpart of FxParameterCreationAPI for the
				controls FxGrip adds to the inspector: each method mirrors Apple's
				addFloatSliderWithName:… shape, builds the parameter's configuration dictionary,
				and registers it through the effect host. The API is vended by
				FxGripAPIAccessing's customCreationAPIv1, so an existing plug-in that wraps its
				API manager (directly or through FxGripPluginHost) creates FxGrip controls with
				no other FxGrip adoption.

				Every method returns YES when the host accepted the parameter. Call during the
				plug-in's -addParameters, like Apple's creation API.
*/
@interface FxGripCustomCreationAPI_v1 : NSObject

- (nullable instancetype)initWithEffect:(id<FxGripEffectHost>)effect;

@property (readonly, nonnull, assign) id<FxGripEffectHost> effect;

/*! A styled section header spanning the inspector width. */
- (BOOL)addSectionWithName:(NSString *)name
			   parameterID:(UInt32)parameterID
			parameterFlags:(FxParameterFlags)flags;

/*! A horizontal rule spanning the inspector width. */
- (BOOL)addDividerWithParameterID:(UInt32)parameterID
				   parameterFlags:(FxParameterFlags)flags;

/*! A full-width colored strip with a bold title and an optional subtitle. */
- (BOOL)addBannerWithName:(NSString *)name
			  parameterID:(UInt32)parameterID
					title:(nullable NSString *)title
				 subtitle:(nullable NSString *)subtitle
		   parameterFlags:(FxParameterFlags)flags;

/*! A pill badge sized to its text. */
- (BOOL)addCapsuleWithName:(NSString *)name
			   parameterID:(UInt32)parameterID
					 title:(nullable NSString *)title
			parameterFlags:(FxParameterFlags)flags;

/*! A read-only status light: a colored dot (a BEDotState) with a label. */
- (BOOL)addStatusWithName:(NSString *)name
			  parameterID:(UInt32)parameterID
					state:(NSInteger)state
					label:(nullable NSString *)label
		   parameterFlags:(FxParameterFlags)flags;

/*! A status light with a progress bar; fraction 0…1, or negative for indeterminate. */
- (BOOL)addProgressWithName:(NSString *)name
				parameterID:(UInt32)parameterID
					  state:(NSInteger)state
					  label:(nullable NSString *)label
				   fraction:(double)fraction
			 parameterFlags:(FxParameterFlags)flags;

/*! A boolean presented as a switch. */
- (BOOL)addSwitchWithName:(NSString *)name
			  parameterID:(UInt32)parameterID
			 defaultValue:(BOOL)defaultValue
		   parameterFlags:(FxParameterFlags)flags;

/*! An integer field with a stepper and a reload button drawing uniformly in min…max. */
- (BOOL)addRandomWithName:(NSString *)name
			  parameterID:(UInt32)parameterID
			 defaultValue:(NSInteger)defaultValue
				  minimum:(NSInteger)minimum
				  maximum:(NSInteger)maximum
					 step:(NSInteger)step
		   parameterFlags:(FxParameterFlags)flags;

/*! A whitelisted web page embedded in the inspector. A nil whitelist allows every site. */
- (BOOL)addWebViewWithName:(NSString *)name
			   parameterID:(UInt32)parameterID
					   URL:(nullable NSString *)urlString
				 whitelist:(nullable NSArray<NSString *> *)whitelist
					height:(double)height
			parameterFlags:(FxParameterFlags)flags;

/*! A whitelisted video player. A direct-media or file URL plays natively; other URLs embed. */
- (BOOL)addVideoViewWithName:(NSString *)name
				 parameterID:(UInt32)parameterID
						 URL:(nullable NSString *)urlString
				   whitelist:(nullable NSArray<NSString *> *)whitelist
					  height:(double)height
					autoplay:(BOOL)autoplay
						loop:(BOOL)loop
			  parameterFlags:(FxParameterFlags)flags;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripCustomCreationAPI_v1_h */
