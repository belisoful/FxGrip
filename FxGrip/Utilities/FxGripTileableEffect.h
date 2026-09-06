/*!
	@file       FxGripTileableEffect.h
	@copyright  Copyright © 2020-2023 Apple, Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect
	@abstract   The central base class for FxPlug tileable effects built on FxGrip.
	@discussion Introduced in FxGrip 0.1.0. FxGripTileableEffect wraps the FxPlug
	            FxTileableEffect protocol and adds FxGrip's parameter model, extension system,
	            priority notification center, and host-API accessors. A plugin subclasses this
	            class to inherit parameter creation from configuration, lifecycle notifications,
	            render-state compression, and the categories that add timing, color gamut,
	            custom UI, and out-of-band parameter access. The file declares the
	            FxGripTileableEffect protocol, its expanded and coder-state companion protocols,
	            and the concrete FxGripTileableEffect class.
*/

#ifndef FxGripTileableEffect_h
#define FxGripTileableEffect_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripParameter.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripParameterUtility.h>
#import <FxGrip/FxGripAPIAccessing.h>
#import <FxGrip/FxGripImageCompression.h>
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import <FxGrip/FxGripTypes.h>

@class FxGripOOBParameterAccess;




/*!
	@protocol	FxGripTileableEffectExpanded
	@abstract	The FxGrip-added state that every tileable effect exposes beyond FxTileableEffect.
	@discussion	Introduced in FxGrip 0.1.0. The protocol names the plugin identity, the host-API
				accessor, the notification center, the plugin properties, and the setup-progress
				flags an extension or category reads. The optional extensionsFlush returns an
				error when a pending extension flush fails.
*/
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

/*!
	@protocol	FxGripTileableEffect
	@abstract	The full contract a FxGrip tileable effect presents to its extensions and categories.
	@discussion	Introduced in FxGrip 0.1.0. The protocol composes FxTileableEffect,
				FxGripTileableEffectExpanded, and FxGripEffectHost, and adds plugin naming, the
				default font name, parameter subscripting, and fast enumeration. The optional
				section declares the color-gamut, out-of-band-parameter, and timing members that
				the matching categories implement.
*/
@protocol FxGripTileableEffect <FxTileableEffect, FxGripTileableEffectExpanded, FxGripEffectHost>

@property (readonly, nonnull, retain) NSString*		pluginDisplayName;
@property (readonly, nonnull, retain) NSString*		pluginGroupUUID;
@property (readonly, nonnull, retain) NSString*		pluginInfoString;

@property (readonly, retain, nonnull) NSString*		defaultFontName;

- (id<FxGripParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;
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
@property (readonly) BOOL isTimelineDropFrame;
@property (readonly) BOOL isInputDropFrame;

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


/*!
	@protocol	FxGripTileableEffectCoderStateWeak
	@abstract	The optional NSCoder-based render callbacks a coder-state effect may implement.
	@discussion	Introduced in FxGrip 0.1.0. The callbacks mirror the FxPlug render entry points and
				replace the opaque pluginState NSData with an NSCoder, so an effect encodes and
				decodes its render state through the coder. Every method is optional, so an effect
				adopts the coder path for the render stages it needs.
*/
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



/*!
	@protocol	FxGripTileableEffectCoderState
	@abstract	The required NSCoder-based render callbacks a full coder-state effect implements.
	@discussion	Introduced in FxGrip 0.1.0. The protocol promotes the coder, destination-bounds,
				source-tile, and render callbacks to required members, so a conforming effect
				provides the complete coder-based render path. The scheduleInputs callback stays
				optional.
*/
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





/*! The extension key identifying the main effect itself when it acts as an FxGripExtension. */
extern NSString * _Nonnull const FxGripTileableEffectExtKey;





/*!
	@class		FxGripTileableEffect
	@abstract	The concrete base class a FxGrip tileable effect plugin subclasses.
	@discussion	Introduced in FxGrip 0.1.0. The class implements the FxPlug properties and
				parameter callbacks, holds the extension dictionary, parameter dictionary, and
				priority notification center, and drives setup through the addingParameters,
				addedParameters, finishedSetup, and addedToDocument stages. It reads the plugin
				identity and properties from the registration record. Subclasses override
				loadExtensions, addParametersWithGroupID:error:, parametersConfiguration, and the
				render callbacks. The render state supports optional lossless compression through
				pluginStateCompression.
*/
//  @todo: this is FxGrip and so should be an FxGripTileableEffectBase
@interface FxGripTileableEffect : FxGripExtensionBase <FxGripTileableEffect, FxGripTileableEffectCoderStateWeak>
{
	NSMutableDictionary<id, Class> *__typeToClassMap;
}

/*! The host-API accessor the effect uses to reach FxPlug host services. */
@property (readonly, nonnull) id<FxGripAPIAccessing> apiManager;

/*! The priority notification center that carries the effect's lifecycle and parameter events. */
@property (readonly, nonnull, assign) NSPriorityNotificationCenter *notifier;
/*! The installed extensions, keyed by extension identifier. */
@property (readonly, nonnull, retain) NSDictionary<NSString*, id<FxGripExtension>> *extensions;
/*! The effect's parameters, keyed by parameter ID. */
@property (readonly, nonnull, retain) NSDictionary<NSNumber*, id<FxGripParameter>> *parameters;

//Plugin Properties
/*! The plugin's UUID from its registration record. */
@property (readonly, nonnull, retain) NSString*		pluginUUID;
/*! The identifier of the effect instance's render session. */
@property (readonly) UInt64 sessionID;
//The following is from the plist, or the dynamic registration class in the plist
/*! The plugin registration dictionary, from the plist or the dynamic registration class. */
@property (readonly, nonnull, retain) NSDictionary<NSString*, id> *pluginProperties;
/*! The plugin's display name from its registration record. */
@property (readonly, nonnull, retain) NSString*		pluginDisplayName;
/*! The plugin group's UUID from its registration record. */
@property (readonly, nonnull, retain) NSString*		pluginGroupUUID;
/*! The plugin's information string from its registration record. */
@property (readonly, nonnull, retain) NSString*		pluginInfoString;

// FxPlug FxTileableEffect Properties
@property (assign, readonly) BOOL finishedProperties; // True when `-properties:error:` is called
/*! Whether the effect requires the full source buffer instead of a tile. */
@property (assign, readwrite, nonatomic) BOOL needsFullBuffer;
/*! Whether the output varies over time while the parameters stay static. */
@property (assign, readwrite, nonatomic) BOOL variesWhenParamsAreStatic;
/*! Whether the effect changes the output image size. */
@property (assign, readwrite, nonatomic) BOOL changesOutputSize;
/*! The color space the effect wants its source and destination images processed in. */
@property (assign, readwrite, nonatomic) FxImageColorInfo desiredProcessingColorInfo;
/*! Whether the effect remaps the timeline time of its input. */
@property (assign, readwrite, nonatomic) BOOL mayRemapTime;
/*! Whether the effect's textures use a layout that does not match the host's default. */
@property (assign, readwrite, nonatomic) BOOL usesNonmatchingTextureLayout;
/*! Whether the effect draws in screen space instead of image space. */
@property (assign, readwrite, nonatomic) BOOL drawsInScreenSpace;
/*! The effect's support for pixel-transform rendering. */
@property (assign, readwrite, nonatomic) FxPixelTransformSupport pixelTransformSupport;

/*!
	@property   pluginStateCompression
	@abstract   The lossless codec applied to the render-time pluginState blob.
	@discussion Introduced in FxGrip 0.1.0. The default FxGripCompressionNone leaves the blob
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
	@discussion Introduced in FxGrip 0.1.0. Defaults to
				FxGripCompressionEnvelopeThresholdDefault. A small blob's compression saving
				does not repay the codec's per-call cost on the per-frame render path, so it
				passes through uncompressed. Has no effect while pluginStateCompression is
				FxGripCompressionNone.
*/
@property (assign, readwrite, nonatomic) NSUInteger pluginStateCompressionThreshold;

// Stack Location
/*! YES while the effect is inside its parameter-creation pass. */
@property (assign, readonly) BOOL addingParameters;
/*! YES once the effect has finished creating its parameters. */
@property (assign, readonly) BOOL addedParameters;
/*! YES once the effect has finished its initial setup. */
@property (assign, readonly) BOOL finishedSetup;
/*! YES once the effect has been added to a document. */
@property (assign, readonly) BOOL addedToDocument;

//	FxTileableEffect Implementation
/*!
	@method		properties:error:
	@abstract	Fills the FxPlug property dictionary the host reads during setup.
	@param		properties	On return, the effect's FxPlug property dictionary.
	@param		error		On failure, the error describing why the properties could not be built.
	@return		YES when the properties are supplied; NO on failure.
	@discussion	Introduced in FxGrip 0.1.0. The base implementation maps the effect's property
				settings, such as needsFullBuffer and pixelTransformSupport, into the FxPlug keys.
				The call marks finishedProperties YES. */
- (BOOL) properties:(NSDictionary *_Nullable *_Null_unspecified) properties
			  error:(NSError *_Nullable *_Null_unspecified) error;

//Parameters
/*! @abstract The number of parameters the effect currently holds. */
- (UInt32)parameterCount;

/*!
	@method		objectAtIndexedSubscript:
	@abstract	Returns the parameter at an ordinal position for subscript access.
	@param		index	The zero-based position of the parameter.
	@return		The parameter at that position, or nil when the index is out of range. */
- (id<FxGripParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;

/*!
	@method		objectForKeyedSubscript:
	@abstract	Returns the parameter for a key for subscript access.
	@param		key		The parameter ID or name that identifies the parameter.
	@return		The matching parameter, or nil when none matches. */
- (id _Nullable)objectForKeyedSubscript:(id _Nullable)key;

/*! @abstract Enumerates the effect's parameters for fast enumeration. */
- (NSUInteger) countByEnumeratingWithState: (nonnull NSFastEnumerationState *) enumerationState
								   objects: (id _Nullable __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;

// Sub-Class override implementations
/*! The font name a subclass supplies for parameters that default to the plugin's font. */
@property (readonly, retain, nonnull) NSString* defaultFontName;

/*!
	@method		loadExtensions
	@abstract	Returns the extensions to install on the effect during setup.
	@return		A mutable array of extensions, or nil when the effect installs none.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides this to add extensions, and
				calls super to keep the framework-installed extensions. */
- (nullable NSMutableArray<id<FxGripExtension>>*)loadExtensions;

/*!
	@method		addParametersWithGroupID:error:
	@abstract	Creates the effect's parameters within a parameter group.
	@param		groupID	The parameter group the created parameters are added under.
	@param		error	On failure, the error describing why a parameter could not be created.
	@return		YES when the parameters are created; NO on failure.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides this to build parameters in code,
				and calls super to keep the configuration-driven parameters. */
- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError*_Nonnull*_Nullable)error;

/*!
	@method     parametersConfiguration
	@abstract   Returns the parameter configuration records that seed addParametersWithError:.
	@discussion Introduced in FxGrip 0.1.0. The base implementation returns the `"parameters"`
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
	@discussion Introduced in FxGrip 0.1.0. The record carries the declared parameter
				properties (`kFxParameterProperty_*` keys) including tags, meta, reset
				value, and target-preset definitions.
*/
- (NSDictionary *_Nullable)configurationForParameter:(FxParameterId)parameterID;

/*!
	@method     parameterClicked:
	@abstract   Standardized dispatch for push-button and help-button clicks.
	@discussion Introduced in FxGrip 0.1.0. Button parameters register a synthesized
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




/*!
	@abstract	The category that reports whether the effect's FxPlug properties come from configuration.
	@discussion	Introduced in FxGrip 0.1.0. The category exposes propertiesFromConfiguration, which
				is YES when the properties callback fills the FxPlug property dictionary from the
				plugin's registration record rather than from subclass code.
*/
@interface FxGripTileableEffect (ConfigurationProperties)

/*! YES when the effect's FxPlug properties are populated from the plugin configuration record. */
@property (readonly) BOOL		propertiesFromConfiguration;

@end

#endif
