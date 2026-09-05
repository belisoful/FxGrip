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

#import <FxGrip/FxGripPluginData.h>
#import <FxGrip/FxGripPluginGroupData.h>
#import <FxGrip/FxGripRegisteredPlugin.h>
#import <FxGrip/FxGripClassRegistrar.h>
#import <FxGrip/FxGripConfigRegistrar.h>
#import <FxGrip/FxGripDynamicRegistrar.h>
#import <FxGrip/FxGripStaticRegistrar.h>


#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxParameterExtension.h>
#import <FxGrip/FxGripCustomExtension.h>
#import <FxGrip/FxGripToggleExtension.h>
// FxGripFxFactory is not published: its implementation is excluded from the target and
// its header imports the third-party FxFactory SDK, so a client without that SDK could
// not compile the umbrella. Re-publish only with a working, ported implementation.
#import <FxGrip/FxGripI18N.h>
#import <FxGrip/FxGripInstanceTracker.h>
#import <FxGrip/FxGripMeta.h>
#import <FxGrip/FxGripAnalysis.h>
#import <FxGrip/FxGripMLCache.h>
#import <FxGrip/FxGripWindow.h>
#import <FxGrip/FxGripExtensionSystem.h>
#import <FxGrip/FxGripParameterData.h>
#import <FxGrip/FxGripRegression.h>

#import <FxGrip/FxMatrix+FxGrip.h>
#import <FxGrip/FxGripEffectHost.h>
#import <FxGrip/FxGripPluginHost.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Analyze.h>
#import <FxGrip/FxGripTileableEffect+ColorGamut.h>
#import <FxGrip/FxGripTileableEffect+CustomUI.h>
#import <FxGrip/FxGripTileableEffect+Extensions.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <FxGrip/FxGripTileableEffect+OOBParameterAccess.h>
#import <FxGrip/FxGripTileableEffect+Parameters.h>
#import <FxGrip/FxGripTileableEffect+PluginProperties.h>
#import <FxGrip/FxGripTileableEffect+ProjectProperties.h>
#import <FxGrip/FxGripTileableEffect+Timing.h>
#import <FxGrip/FxGripTileableEffect+Versioning.h>
#import <FxGrip/FxGripTileableGenerator.h>
#import <FxGrip/FxTileImage+FxGrip.h>
#import <FxGrip/FxGripTextImage.h>
#import <FxGrip/FxGripTimecode.h>
#import <FxGrip/FxGripWatermark.h>

#import <FxGrip/FxGripImageBuffer.h>
#import <FxGrip/FxGripImageCompression.h>
#import <FxGrip/FxGripMTLDeviceCache.h>
#import <FxGrip/FxGripEventModifiers.h>

#import <FxGrip/FxGripColorGamut.h>
#import <FxGrip/FxGripPluginInfo.h>
#import <FxGrip/FxGripRect.h>
#import <FxGrip/FxGripURLWhitelist.h>
#import <FxGrip/FxGripPrincipalDelegate.h>
#import <FxGrip/NSArray+FxPlug.h>
#import <FxGrip/NSCoder+FxPlug.h>
#import <FxGrip/NSDictionary+FxGripTileableEffect.h>

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
#import <FxGrip/FxGripPointOptions.h>
#import <FxGrip/FxGripPresetsParameter.h>
#import <FxGrip/FxGripPushButtonParameter.h>
#import <FxGrip/FxGripRGBParameter.h>
#import <FxGrip/FxGripStringParameter.h>
#import <FxGrip/FxGripSwitchParameter.h>
#import <FxGrip/FxGripToggleParameter.h>
#import <FxGrip/FxGripAllParameters.h>

#import <FxGrip/FxGripDividerParameter.h>
#import <FxGrip/FxGripSection.h>
#import <FxGrip/FxGripSectionParameter.h>
#import <FxGrip/FxGripRandom.h>
#import <FxGrip/FxGripRandomParameter.h>
#import <FxGrip/FxGripBanner.h>
#import <FxGrip/FxGripBannerParameter.h>
#import <FxGrip/FxGripCapsule.h>
#import <FxGrip/FxGripCapsuleParameter.h>
#import <FxGrip/FxGripStatusParameter.h>
#import <FxGrip/FxGripProgressParameter.h>
#import <FxGrip/FxGripWebView.h>
#import <FxGrip/FxGripWebViewParameter.h>
#import <FxGrip/FxGripVideoView.h>
#import <FxGrip/FxGripVideoViewParameter.h>
#import <FxGrip/FxGripLiveImage.h>
#import <FxGrip/FxGripLiveFrame.h>
#import <FxGrip/FxGripLiveImageParameter.h>
#import <FxGrip/FxGripTrackingOpacityParameter.h>
#import <FxGrip/FxGripAnalyzerParameter.h>
#import <FxGrip/FxGripObjectTracker.h>
#import <FxGrip/FxGripObjectTrackerData.h>
#import <FxGrip/FxGripObjectTrackerParameter.h>
#import <FxGrip/FxGripObjectTrackerOSC.h>


#import <FxGrip/FxGripCustomDataClasses.h>
#import <FxGrip/FxGripCustomCommonDelegate.h>
#import <FxGrip/FxGripCustomViewData.h>
#import <FxGrip/FxGripCustomViewDataDelegate.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripCurveLUT.h>
#import <FxGrip/FxGripCurveData.h>
#import <FxGrip/FxGripCurveEditorView.h>
#import <FxGrip/FxGripCurveSetEditorView.h>
#import <FxGrip/FxGripCurveSetData.h>
#import <FxGrip/FxGripFrameData.h>
#import <FxGrip/FxGripPathData.h>
#import <FxGrip/FxGripPathGeometry.h>
#import <FxGrip/FxGripInterpolatingDictionary.h>
#import <FxGrip/FxGripMetaManager.h>
#import <FxGrip/FxGripMutableParameter.h>
#import <FxGrip/FxGripOOBParameterAccess.h>

#import <FxGrip/FxGripOSCShaderTypes.h>
#import <FxGrip/FxGripOnScreenControl.h>
#import <FxGrip/FxGripOSCPart.h>
#import <FxGrip/FxGripOSCPathPart.h>
#import <FxGrip/FxGripPointOSC.h>

#import <FxGrip/FxGripInferenceRequest.h>
#import <FxGrip/FxGripInferenceResult.h>
#import <FxGrip/FxGripInferenceBackend.h>
#import <FxGrip/FxGripPassthroughBackend.h>
#import <FxGrip/FxGripMLImageEffect.h>
#import <FxGrip/FxGripMLVideoEffect.h>
#import <FxGrip/FxGripMLImageGenerator.h>
#import <FxGrip/FxGripMLVideoGenerator.h>
#import <FxGrip/FxGripInferenceBridge.h>

#import <FxGrip/FxGripSpaceMotion.h>
#import <FxGrip/FxGripSpaceBackend.h>
#import <FxGrip/FxGripSceneKitMetalBackend.h>
#import <FxGrip/FxGripPhysicsSimulationStore.h>
#import <FxGrip/FxGripSceneKitPhysicsBackend.h>
#import <FxGrip/FxGripPhysicsBake.h>
#import <FxGrip/FxGripParticleSystem.h>
#import <FxGrip/FxGripSpaceEffect.h>
#import <FxGrip/SCNCamera+FxGrip.h>
#import <FxGrip/SCNLight+FxGrip.h>


#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripAPIAccessing.h>
#import <FxGrip/FxGripCommonAPI.h>
#import <FxGrip/FxGripDynamicParameterAPI_v3.h>
#import <FxGrip/FxGripParameterInfoAPI_v1.h>
#import <FxGrip/FxGripParameterBoundsAPI_v1.h>
#import <FxGrip/FxGripMetaAPI_v1.h>
#import <FxGrip/FxGripParameterCreationAPI_v5.h>
#import <FxGrip/FxGripParameterCreationAPI_v6.h>
#import <FxGrip/FxGripParameterRetrievalAPI_v6.h>
#import <FxGrip/FxGripParameterRetrievalAPI_v7.h>
#import <FxGrip/FxGripParameterSettingAPI_v5.h>
#import <FxGrip/FxGripParameterSettingAPI_v6.h>
#import <FxGrip/FxGripParameterTagsAPI_v1.h>
#import <FxGrip/FxGripPreset.h>
#import <FxGrip/FxGripPresetsAPI_v1.h>
#import <FxGrip/FxGripTimingAPI_v4.h>
#import <FxGrip/FxGripCustomCreationAPI_v1.h>
