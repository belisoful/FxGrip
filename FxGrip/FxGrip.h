//
//  FxGrip.h
//  FxGrip
//
//  Created by ~ ~ on 12/29/24.
//

#import <Foundation/Foundation.h>

//! Project version number for FxGrip.
FOUNDATION_EXPORT double FxGripVersionNumber;

//! Project version string for FxGrip.
FOUNDATION_EXPORT const unsigned char FxGripVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <FxGrip/PublicHeader.h>

#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxParameterFlags.h>

#import <FxGrip/FxPluginData.h>
#import <FxGrip/FxPluginGroupData.h>
#import <FxGrip/FxRegisteredPlugin.h>
#import <FxGrip/FxGripClassRegistrar.h>
#import <FxGrip/FxGripConfigRegistrar.h>
#import <FxGrip/FxGripDynamicRegistrar.h>
#import <FxGrip/FxGripStaticRegistrar.h>


#import <FxGrip/FxExtension.h>
#import <FxGrip/FxParameterExtension.h>
#import <FxGrip/FxGripCustomExtension.h>
#import <FxGrip/FxGripToggleExtension.h>
#import <FxGrip/FxGripFactory.h>
#import <FxGrip/FxGripI18N.h>
#import <FxGrip/FxGripInstanceTracker.h>
#import <FxGrip/FxGripParameterData.h>
#import <FxGrip/FxGripRegression.h>

#import <FxGrip/FxMatrix+FxGrip.h>
#import <FxGrip/FxTileableEffectBase.h>
#import <FxGrip/FxTileableEffectBase+ColorGamut.h>
#import <FxGrip/FxTileableEffectBase+Extensions.h>
#import <FxGrip/FxTileableEffectBase+Notification.h>
#import <FxGrip/FxTileableEffectBase+OOBParameterAccess.h>
#import <FxGrip/FxTileableEffectBase+Parameters.h>
#import <FxGrip/FxTileableEffectBase+PluginProperties.h>
#import <FxGrip/FxTileableEffectBase+ProjectProperties.h>
#import <FxGrip/FxTileableEffectBase+Timing.h>
#import <FxGrip/FxTileableEffectBase+Versioning.h>
#import <FxGrip/FxTileableGeneratorBase.h>
#import <FxGrip/FxTileImage+FxGrip.h>

#import <FxGrip/FxGripMTLDeviceCache.h>

#import <FxGrip/FxGripPluginInfo.h>
#import <FxGrip/FxGripPrincipalDelegate.h>
#import <FxGrip/NSArray+FxPlug.h>
#import <FxGrip/NSCoder+FxPlug.h>
#import <FxGrip/NSDictionary+FxTileableEffect.h>

#import <FxGrip/FxParameter.h>
#import <FxGrip/NSView+FxGrip.h>

#import <FxGrip/FxGripAngleParameter.h>
#import <FxGrip/FxGripColorParameter.h>
#import <FxGrip/FxGripCustomParameter.h>
#import <FxGrip/FxGripFloatParameter.h>
#import <FxGrip/FxGripFontMenuParameter.h>
#import <FxGrip/FxGripGradientParameter.h>
#import <FxGrip/FxGripGroupParameter.h>
#import <FxGrip/FxGripHelpParameter.h>
#import <FxGrip/FxGripHistogramParameter.h>
#import <FxGrip/FxGripImageRefParameter.h>
#import <FxGrip/FxGripIntParameter.h>
#import <FxGrip/FxGripMenuParameter.h>
#import <FxGrip/FxGripPathParameter.h>
#import <FxGrip/FxGripPercentParameter.h>
#import <FxGrip/FxGripPointParameter.h>
#import <FxGrip/FxGripPushButtonParameter.h>
#import <FxGrip/FxGripRGBParameter.h>
#import <FxGrip/FxGripStringParameter.h>
#import <FxGrip/FxGripToggleParameter.h>
#import <FxGrip/FxGripAllParameters.h>

#import <FxGrip/FxGripDividerParameter.h>


#import <FxGrip/FxGripCustomCommonDelegate.h>
#import <FxGrip/FxGripCustomViewData.h>
#import <FxGrip/FxGripCustomViewDataDelegate.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripInterpolatingDictionary.h>
#import <FxGrip/FxGripMutableParameter.h>
#import <FxGrip/FxGripOOBParameterAccess.h>


#import <FxGrip/FxAPINotifications.h>
#import <FxGrip/FxGripAPIAccessing.h>
#import <FxGrip/FxGripCommonAPI.h>
#import <FxGrip/FxGripDynamicParameterAPI_v3.h>
#import <FxGrip/FxGripDynamicParameterAPI_v4.h>
#import <FxGrip/FxGripParameterCreationAPI_v5.h>
#import <FxGrip/FxGripParameterRetrievalAPI_v6.h>
#import <FxGrip/FxGripParameterSettingAPI_v5.h>
#import <FxGrip/FxGripParameterSettingAPI_v6.h>
