//
//  Fx3DBox.h
//  Fx3DBox
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//
#ifndef FxGripTileableEffect_h
#define FxGripTileableEffect_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxParameter.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripParameterUtility.h>
#import <FxGrip/FxGripAPIAccessing.h>
#import <FxGrip/FxGripImageCompression.h>
#import <BEFoundation/NSPriorityNotificationCenter.h>

#ifndef FxParameterId
typedef UInt32 FxParameterId;
#endif

@class FxGripOOBParameterAccess;




@protocol FxGripTileableEffectExpanded
@property (readonly, nonnull, retain) NSString *pluginUUID;
@property (readonly, nonnull, retain) id<FxGripAPIAccessing> apiManager;
@property (readonly, nonnull, assign) NSPriorityNotificationCenter *notifier;
@property (readonly, nonnull, retain) NSDictionary<NSString*, id> *pluginProperties;

@property (assign, readonly) BOOL addedToDocument;
@property (assign, readonly) BOOL addedParameters;

@optional
	- (nullable NSError*)extensionsFlush;
@end




#import "FxGripEffectHost.h"

@protocol FxGripTileableEffect <FxTileableEffect, FxGripTileableEffectExpanded, FxGripEffectHost>

@property (readonly, nonnull, retain) NSString*		pluginDisplayName;
@property (readonly, nonnull, retain) NSString*		pluginGroupUUID;
@property (readonly, nonnull, retain) NSString*		pluginInfoString;

@property (readonly, retain, nonnull) NSString*		defaultFontName;

- (id<FxParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;
- (id _Nullable)objectForKeyedSubscript:(id _Nullable)key;
- (NSUInteger) countByEnumeratingWithState: (nonnull NSFastEnumerationState *) enumerationState
								   objects: (_Nullable id __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;


@optional
// ColorGamut category
@property (readonly, assign) FxColorPrimaries colorPrimaries;
@property (readonly, assign) BOOL isRec2020Gamut;
@property (readonly, assign) BOOL isRec709Gamut;
@property (readonly, assign) BOOL isGammaColorParameters;
@property (readonly, assign) BOOL isLinearColorParameters;


- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError*_Nonnull*_Nullable)error;

// out of band
- (nonnull FxGripOOBParameterAccess *)startContext;
- (nonnull FxGripOOBParameterAccess *)startContextFlush;


//Timing
@property (readonly) CMTime frameDuration;
@property (readonly) Float64 retimingSpeed;

@property (readonly) CMTime sampleDuration;
@property (readonly) BOOL isInterlacedClip;

@property (readonly) CMTime effectStartTime;
@property (readonly) NSInteger effectStartFrame;
@property (readonly) CMTime effectStartTimeInTimeline;
@property (readonly) CMTime effectDurationTime;
@property (readonly) NSInteger effectDurationFrames;

@property (readonly) CMTime inputStartTime;
@property (readonly) NSInteger inputStartFrame;
@property (readonly) CMTime inputStartTimeInTimeline;
@property (readonly) CMTime inputDurationTime;
@property (readonly) NSInteger inputDurationFrames;

@property (readonly) CMTime effectInPointOfTimeLine;
@property (readonly) CMTime effectOutPointOfTimeLine;

@property (readonly) NSUInteger timelineFpsNumerator;
@property (readonly) NSUInteger timelineFpsDenominator;

@property (readonly) CMTime timelineFrameDuration;
@property (readonly) Float64 timelineFrameDurationFloat;
@property (readonly) CMTime timelineFrameRate;
@property (readonly) Float64 timelineFps;

- (NSInteger)frameForTime:(CMTime)time;

- (void)timelineTime:(nonnull CMTime*)timelineTime fromInputTime:(CMTime)time;
- (void)inputTime:(nonnull CMTime*)inputTime fromTimelineTime:(CMTime)time;


@end


@protocol FxGripTileableEffectCoderStateWeak

@optional

- (BOOL) pluginCoder:(NSCoder * _Nonnull)coder
			  atTime:(CMTime)renderTime
			 quality:(FxQuality)qualityLevel
			   error:(NSError * _Nullable * _Nullable)error;

- (BOOL)destinationImageRect:(nonnull FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> * _Null_unspecified)sourceImages
			destinationImage:(nonnull FxImageTile *)destinationImage
				 pluginCoder:(NSCoder * _Nonnull)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable * _Null_unspecified)outError;

- (BOOL)sourceTileRect:(nonnull FxRect*)sourceTileRect
	 sourceImageIndex:(NSUInteger)sourceImageIndex
		 sourceImages:(NSArray<FxImageTile*>*_Null_unspecified)sourceImages
  destinationTileRect:(FxRect)destinationTileRect
	 destinationImage:(FxImageTile*_Null_unspecified)destinationImage
		  pluginCoder:(NSCoder * _Nonnull)pluginCoder
			   atTime:(CMTime)renderTime
				error:(NSError*_Nullable *_Null_unspecified)outError;

- (BOOL)scheduleInputs:(NSArray<FxImageTileRequest*>* _Nullable * _Nullable)inputImageRequests
		   pluginCoder:(NSCoder* _Nullable)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError*_Nullable*_Nonnull)error;

- (BOOL)renderDestinationImage:(FxImageTile *_Nonnull)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
				   pluginCoder:(NSCoder * _Nonnull)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable * _Nullable)outError;
@end



@protocol FxGripTileableEffectCoderState <FxGripTileableEffectCoderStateWeak>

- (BOOL) pluginCoder:(NSCoder * _Nonnull)coder
			  atTime:(CMTime)renderTime
			 quality:(FxQuality)qualityLevel
			   error:(NSError * _Nullable * _Nullable)error;




- (BOOL)destinationImageRect:(nonnull FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *_Null_unspecified)sourceImages
			destinationImage:(nonnull FxImageTile *)destinationImage
				 pluginCoder:(NSCoder * _Nonnull)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *_Null_unspecified)outError;

- (BOOL)sourceTileRect:(nonnull FxRect*)sourceTileRect
	 sourceImageIndex:(NSUInteger)sourceImageIndex
		 sourceImages:(NSArray<FxImageTile*>*_Null_unspecified)sourceImages
  destinationTileRect:(FxRect)destinationTileRect
	 destinationImage:(FxImageTile*_Null_unspecified)destinationImage
		  pluginCoder:(NSCoder * _Nonnull)pluginCoder
			   atTime:(CMTime)renderTime
				error:(NSError*_Nullable *_Null_unspecified)outError;


- (BOOL)renderDestinationImage:(FxImageTile *_Nonnull)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
				   pluginCoder:(NSCoder * _Nonnull)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable * _Nullable)outError;

@optional
- (BOOL)scheduleInputs:(NSArray<FxImageTileRequest*>* _Nullable * _Nullable)inputImageRequests
		   pluginCoder:(NSCoder* _Nullable)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError*_Nullable*_Nonnull)error;
@end





extern NSString * _Nonnull const FxGripTileableEffectExtKey;





//  @todo: this is FxGrip and so should be an FxGripTileableEffectBase
@interface FxGripTileableEffect : FxGripExtensionBase <FxGripTileableEffect, FxGripTileableEffectCoderStateWeak>
{
	NSMutableDictionary<id, Class> *__typeToClassMap;
}

@property (readonly, nonnull) id<FxGripAPIAccessing> apiManager;

@property (readonly, nonnull, assign) NSPriorityNotificationCenter *notifier;
@property (readonly, nonnull, retain) NSDictionary<NSString*, id<FxGripExtension>> *extensions;
@property (readonly, nonnull, retain) NSDictionary<NSNumber*, id<FxParameter>> *parameters;

//Plugin Properties
@property (readonly, nonnull, retain) NSString*		pluginUUID;
@property (readonly) UInt64 sessionID;
//The following is from the plist, or the dynamic registration class in the plist
@property (readonly, nonnull, retain) NSDictionary<NSString*, id> *pluginProperties;
@property (readonly, nonnull, retain) NSString*		pluginDisplayName;
@property (readonly, nonnull, retain) NSString*		pluginGroupUUID;
@property (readonly, nonnull, retain) NSString*		pluginInfoString;

// FxPlug FxTileableEffect Properties
@property (assign, readonly) BOOL finishedProperties; // True when `-properties:error:` is called
@property (assign, readwrite, nonatomic) BOOL needsFullBuffer;
@property (assign, readwrite, nonatomic) BOOL variesWhenParamsAreStatic;
@property (assign, readwrite, nonatomic) BOOL changesOutputSize;
@property (assign, readwrite, nonatomic) FxImageColorInfo desiredProcessingColorInfo;
@property (assign, readwrite, nonatomic) BOOL mayRemapTime;
@property (assign, readwrite, nonatomic) BOOL usesNonmatchingTextureLayout;
@property (assign, readwrite, nonatomic) BOOL drawsInScreenSpace;
@property (assign, readwrite, nonatomic) FxPixelTransformSupport pixelTransformSupport;

/*!
	@property   pluginStateCompression
	@abstract   The lossless codec applied to the render-time pluginState blob.
	@discussion Introduced in FxGrip 1.0. The default FxGripCompressionNone leaves the blob
				uncompressed, matching the pre-1.0 wire format. Setting a lossless codec
				(LZFSE, LZ4, zlib, LZMA) enables size-gated compression: the encoded state is
				compressed only when it reaches pluginStateCompressionThreshold and the codec
				shrinks it, and it passes through uncompressed otherwise. The render side
				detects the codec from the blob and decompresses without further
				configuration, so the setting is safe to change per instance. A lossy codec is
				treated as FxGripCompressionNone, since the blob is not an image.
*/
@property (assign, readwrite, nonatomic) FxGripCompression pluginStateCompression;

/*!
	@property   pluginStateCompressionThreshold
	@abstract   The byte count below which pluginState is left uncompressed.
	@discussion Introduced in FxGrip 1.0. Defaults to
				FxGripCompressionEnvelopeThresholdDefault. A small blob's compression saving
				does not repay the codec's per-call cost on the per-frame render path, so it
				passes through uncompressed. Has no effect while pluginStateCompression is
				FxGripCompressionNone.
*/
@property (assign, readwrite, nonatomic) NSUInteger pluginStateCompressionThreshold;

// Stack Location
@property (assign, readonly) BOOL addingParameters;
@property (assign, readonly) BOOL addedParameters;
@property (assign, readonly) BOOL finishedSetup;
@property (assign, readonly) BOOL addedToDocument;

//	FxTileableEffect Implementation
- (BOOL) properties:(NSDictionary *_Nullable *_Null_unspecified) properties
			  error:(NSError *_Nullable *_Null_unspecified) error;

//Parameters
- (UInt32)parameterCount;
- (id<FxParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;
- (id _Nullable)objectForKeyedSubscript:(id _Nullable)key;
- (NSUInteger) countByEnumeratingWithState: (nonnull NSFastEnumerationState *) enumerationState
								   objects: (id _Nullable __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;

// Sub-Class override implementations
@property (readonly, retain, nonnull) NSString* defaultFontName;

- (nullable NSMutableArray<id<FxGripExtension>>*)loadExtensions;
- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError*_Nonnull*_Nullable)error;

/*!
	@method     parametersConfiguration
	@abstract   Returns the parameter configuration records that seed addParametersWithError:.
	@discussion Introduced in FxGrip 1.0. The base implementation returns the `"parameters"`
				array from the plugin's registration dictionary
				(`kProPlugPlugInX_ParametersProperty`), so a plugin declares its parameters
				in the plist or dynamic-registration record without writing creation code.
				A subclass overrides to build the records in code, or calls super and
				appends. Each record uses `kFxParameterProperty_*` keys.
*/
- (nonnull NSMutableArray<NSDictionary *> *)parametersConfiguration;

/*!
	@method     configurationForParameter:
	@abstract   Returns the parameter's configuration record from the flattened
				parameters configuration.
	@discussion Introduced in FxGrip 1.0. The record carries the declared parameter
				properties (`kFxParameterProperty_*` keys) including tags, meta, reset
				value, and target-preset definitions.
*/
- (NSDictionary *_Nullable)configurationForParameter:(FxParameterId)parameterID;

/*!
	@method     parameterClicked:
	@abstract   Standardized dispatch for push-button and help-button clicks.
	@discussion Introduced in FxGrip 1.0. Button parameters register a synthesized
				selector that encodes the parameter ID
				(`FxGripParameterUtility clickSelectorNameForParameter:`). The runtime
				resolves that selector to a trampoline that decodes the ID and calls this
				method, so one entry point serves every button and subclasses do not
				implement a method per button.

				The dispatch, wrapped in the action API's `startAction:` / `endAction:`
				when the effect is not an on-screen control:
				- posts `FxGripTileableEffectParameterClickedName` with
				  `FxGripTileableEffectParameterClickedIDKey` so extensions observe the click
				- performs the configuration-declared `"selector"` when the subclass
				  implements it
				- otherwise performs the parameter object's `defaultParameterAction`

				Subclasses may override to intercept every click; call super to keep the
				notification and dispatch behavior.
	@result     NO when a notification observer reports an error; YES otherwise.
*/
- (BOOL)parameterClicked:(FxParameterId)parameterID;

@end




@interface FxGripTileableEffect (ConfigurationProperties)

@property (readonly) BOOL		propertiesFromConfiguration;

@end

#endif
